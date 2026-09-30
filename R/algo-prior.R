# Algorithm: Prior fitting with mixed-effects models
# Functions for integrating external covariates to improve transcript quantification

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c(
    "transcript_id"
))

#' Fit mixed-effects prior model for transcript abundances
#'
#' Integrates external covariates to improve transcript quantification
#' using a mixed-effects model with gene-level random effects. This model
#' captures gene-level variation, allowing isoforms from the same gene
#' to have correlated abundances.
#'
#' @details
#' The model specification is:
#' \deqn{log(\beta_i) = X_i \cdot \theta + b_g + \epsilon_i}
#'
#' Where:
#' - \eqn{\beta_i}: abundance of transcript i
#' - \eqn{X_i}: covariate vector for transcript i (GC content, mappability, etc.)
#' - \eqn{\theta}: fixed effects coefficients
#' - \eqn{b_g \sim N(0, \tau^2)}: random effect for gene g
#' - \eqn{\epsilon_i \sim N(0, \sigma^2)}: residual error
#'
#' @param log_abundances Log-transformed transcript abundances
#' @param covariate_matrix External features matrix (e.g., GC content, mappability)
#' @param gene_ids Gene ID for each transcript
#'
#' @return List with fitted model and predictions data frame
#' @keywords internal
fit_prior_model_gpboost <- function(
    log_abundances,
    covariate_matrix,
    gene_ids
) {
    # Build design matrix
    X <- stats::model.matrix(~ ., data = as.data.frame(covariate_matrix))

    # Fit GP model with gene-level random effects
    gp_model <- gpboost::fitGPModel(
        group_data = as.factor(gene_ids),
        y = log_abundances,
        X = X,
        likelihood = "gaussian"
    )

    # Generate predictions
    pred <- stats::predict(
        gp_model,
        group_data_pred = as.factor(gene_ids),
        X_pred = X
    )
    predictions <- as.numeric(pred$mu)

    list(
        fit = gp_model,
        predictions = data.frame(pred_value = predictions)
    )
}

#' Fit mixed-effects prior model using lme4
#'
#' Alternative implementation using lme4 for mixed-effects modeling.
#' This can be used as a fallback when gpboost is not available.
#'
#' @param log_abundances Log-transformed transcript abundances
#' @param covariate_matrix External features matrix
#' @param gene_ids Gene ID for each transcript
#' @param transcript_to_gene_matrix Sparse matrix mapping transcripts to genes
#' @param gene_to_transcript_matrix Sparse matrix mapping genes to transcripts
#' @param verbose Print progress messages
#'
#' @return List with fitted model and predictions
#' @keywords internal
fit_prior_model_lme4 <- function(
    log_abundances,
    covariate_matrix,
    gene_ids,
    transcript_to_gene_matrix,
    gene_to_transcript_matrix,
    verbose = FALSE
) {
    # Calculate gene-level aggregates
    # Gene mean abundance: g_bar = (1/n_g) * sum_{i in g} log(beta_i)
    gene_mean_abundance <- as.numeric(
        Matrix::crossprod(transcript_to_gene_matrix, log_abundances)
    )

    # Map gene means back to transcripts for comparison
    transcript_gene_mean <- as.numeric(
        Matrix::crossprod(gene_to_transcript_matrix, gene_mean_abundance)
    )

    # Calculate number of isoforms per transcript
    isoforms_per_transcript <- 1 / Matrix::rowSums(transcript_to_gene_matrix)
    multi_isoform_mask <- isoforms_per_transcript > 1

    # Prepare data for mixed model
    model_data <- data.frame(
        gene_id = gene_ids,
        covariate_matrix,
        y = log_abundances
    )

    # Fit mixed effects model: y ~ covariates + (1|gene)
    mixed_model <- lme4::lmer(
        y ~ . - gene_id + (1 | gene_id),
        data = model_data
    )
    predictions <- stats::fitted(mixed_model)

    # Calculate gene-level predictions
    gene_mean_predictions <- as.numeric(
        Matrix::crossprod(transcript_to_gene_matrix, predictions)
    )

    transcript_gene_mean_predictions <- as.numeric(
        Matrix::crossprod(gene_to_transcript_matrix, gene_mean_predictions)
    )

    # For multi-isoform genes, assess within-gene prediction accuracy
    if (verbose && sum(multi_isoform_mask) > 0) {
        within_gene_correlation <- stats::cor(
            (predictions - transcript_gene_mean_predictions)[multi_isoform_mask],
            (log_abundances - transcript_gene_mean)[multi_isoform_mask]
        )
        cli::cli_alert_info(
            "Within-gene isoform correlation: {round(within_gene_correlation, 3)}"
        )
    }

    list(
        fit = mixed_model,
        predictions = data.frame(
            transcript = rownames(transcript_to_gene_matrix),
            obs_value = log_abundances,
            pred_value = predictions,
            genewise_mean_obs_value = transcript_gene_mean,
            genewise_mean_pred_value = transcript_gene_mean_predictions,
            num_isoforms = isoforms_per_transcript
        )
    )
}

#' Prepare covariate matrix for prior fitting
#'
#' Match and standardize external covariates to transcript order in index.
#'
#' @param prior_data Data frame with transcript_id column and covariate columns
#' @param transcripts Character vector of transcript IDs from index
#' @param trim_versions Whether to trim version numbers from transcript IDs
#'
#' @return Standardized covariate matrix with rows matching transcript order
#' @keywords internal
prepare_prior_covariates <- function(
    prior_data,
    transcripts,
    trim_versions = TRUE
) {
    prior_dt <- data.table::as.data.table(prior_data)

    if (trim_versions) {
        # Trim transcript versions in index and prior
        index_ids_trimmed <- sub("\\..*$", "", transcripts)
        prior_ids_trimmed <- sub("\\..*$", "", prior_dt$transcript_id)

        # Match trimmed IDs
        prior_matched <- prior_dt[match(index_ids_trimmed, prior_ids_trimmed), ]
    } else {
        prior_matched <- prior_dt[match(transcripts, prior_dt$transcript_id), ]
    }

    # Extract and standardize covariates
    # Standardization: X' = (X - mean(X)) / sd(X)
    covariate_matrix <- prior_matched[, -"transcript_id", with = FALSE]
    covariate_matrix <- as.matrix(covariate_matrix)
    covariate_matrix <- scale(covariate_matrix)

    rownames(covariate_matrix) <- transcripts
    covariate_matrix[is.na(covariate_matrix)] <- 0

    covariate_matrix
}

#' Update prior predictions during EM iteration
#'
#' Update transcript-specific prior means using mixed-effects model.
#'
#' @param transcript_abundances Current transcript abundances (beta)
#' @param covariate_matrix Standardized covariate matrix
#' @param index mpaqt_index object with gene mapping
#' @param method "gpboost" or "lme4"
#' @param verbose Print progress messages
#'
#' @return List with updated predictions and variance
#' @keywords internal
update_prior_predictions <- function(
    transcript_abundances,
    covariate_matrix,
    index,
    method = "gpboost",
    verbose = FALSE
) {
    # Get expressed transcripts
    expressed_mask <- transcript_abundances > 0
    n_expressed <- sum(expressed_mask)

    if (n_expressed < 10) {
        cli::cli_warn("Too few expressed transcripts ({n_expressed}) for prior fitting")
        return(list(
            predictions = rep(mean(log(transcript_abundances[expressed_mask])), length(transcript_abundances)),
            variance = 1
        ))
    }

    # Get gene IDs for expressed transcripts
    expressed_gene_ids <- index$genes[expressed_mask]

    # Fit model
    if (method == "gpboost") {
        res <- fit_prior_model_gpboost(
            log_abundances = log(transcript_abundances[expressed_mask]),
            covariate_matrix = covariate_matrix[expressed_mask, , drop = FALSE],
            gene_ids = expressed_gene_ids
        )
    } else {
        # lme4 requires gene mapping matrices
        if (is.null(index$t2g_normalized) || is.null(index$g2t_matrix)) {
            cli::cli_abort(c(
                "Gene mapping matrices required for lme4 method",
                "i" = "Use method = 'gpboost' or rebuild index with gene mappings"
            ))
        }

        res <- fit_prior_model_lme4(
            log_abundances = log(transcript_abundances[expressed_mask]),
            covariate_matrix = covariate_matrix[expressed_mask, , drop = FALSE],
            gene_ids = expressed_gene_ids,
            transcript_to_gene_matrix = index$t2g_normalized[expressed_mask, , drop = FALSE],
            gene_to_transcript_matrix = index$g2t_matrix,
            verbose = verbose
        )
    }

    # Build full prediction vector
    predictions <- rep(0, length(transcript_abundances))
    predictions[expressed_mask] <- res$predictions$pred_value
    predictions[!expressed_mask] <- mean(res$predictions$pred_value)

    # Calculate variance from prediction errors
    variance <- mean(
        (predictions[expressed_mask] - log(transcript_abundances[expressed_mask]))^2
    )

    list(
        predictions = predictions,
        variance = variance,
        model = res$fit
    )
}
