# Post-Quantification Module
# Core EM quantification with configurable priors, normalization, and output

#' Run Post-Quantification Phase
#'
#' Execute the core EM algorithm for transcript quantification with full
#' parameter control. This is the main quantification phase that integrates
#' short-read and optional long-read data.
#'
#' @param index An `mpaqt_index` object
#' @param sr_counts An `mpaqt_counts_sr` object with short-read EC counts
#' @param lr_counts An `mpaqt_counts_lr` object with long-read counts (optional)
#' @param prequant An `mpaqt_prequant` object with positional weights (optional)
#' @param prior_model Prior specification: NULL (none), "shrinkage" (empirical),
#'   "long_read" (from LR data), or a list with `mean` and `precision` vectors
#' @param normalize Normalization method: "tpm" (default), "depth", or "none"
#' @param max_iter Maximum EM iterations (default: 100)
#' @param tolerance Convergence tolerance (default: 1e-4)
#' @param prior_start Iteration to start using prior (default: 25)
#' @param convergence_start Iteration to start checking convergence (default: 25)
#' @param compute_uncertainty Compute uncertainty estimates (default: FALSE)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return An `mpaqt_quant_result` object with full quantification results
#'
#' @details
#' Post-quantification performs the main EM algorithm that estimates transcript
#' abundances. It can optionally use:
#'
#' - **Positional weights** from pre-quantification to correct for positional bias
#' - **Long-read data** for improved isoform disambiguation
#' - **Prior information** for regularization
#'
#' ## Prior Models
#'
#' - `NULL`: No prior, pure maximum likelihood
#' - `"shrinkage"`: Empirical Bayes shrinkage toward grand mean
#' - `"long_read"`: Use long-read counts as informative prior
#' - Custom list: User-specified prior mean and precision
#'
#' ## Normalization
#'
#' - `"tpm"`: Transcripts per million (standard)
#' - `"depth"`: Sequencing depth normalized (raw counts / total * 1e6)
#' - `"none"`: Return raw abundance estimates
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic quantification
#' result <- mpaqt_postquant(
#'     index = idx,
#'     sr_counts = sr
#' )
#'
#' # With long reads and bias correction
#' result <- mpaqt_postquant(
#'     index = idx,
#'     sr_counts = sr,
#'     lr_counts = lr,
#'     prequant = prequant
#' )
#'
#' # With custom prior
#' result <- mpaqt_postquant(
#'     index = idx,
#'     sr_counts = sr,
#'     prior_model = list(
#'         mean = gene_means,
#'         precision = 1/gene_vars
#'     )
#' )
#' }
mpaqt_postquant <- function(
    index,
    sr_counts,
    lr_counts = NULL,
    prequant = NULL,
    prior_model = NULL,
    normalize = "tpm",
    max_iter = 100L,
    tolerance = 1e-4,
    prior_start = 25L,
    convergence_start = 25L,
    compute_uncertainty = FALSE,
    verbose = TRUE
) {
    # Validate inputs
    if (is.character(index)) {
        index <- mpaqt_read_index(index)
    }
    validate_mpaqt_index(index)

    if (is.character(sr_counts)) {
        sr_counts <- mpaqt_read_short_read_counts(sr_counts)
    }
    validate_mpaqt_counts_sr(sr_counts)

    if (!is.null(lr_counts)) {
        if (is.character(lr_counts)) {
            lr_counts <- mpaqt_read_long_read_counts(lr_counts)
        }
        validate_mpaqt_counts_lr(lr_counts)
    }

    if (!is.null(prequant)) {
        validate_mpaqt_prequant(prequant)
    }

    validate_prior_model(prior_model)
    validate_normalize(normalize)

    # Setup
    if (verbose) cli::cli_h1("MPAQT Post-Quantification")

    # Determine features being used
    has_lr <- !is.null(lr_counts) && sum(lr_counts$counts) > 0
    has_prequant <- !is.null(prequant)
    has_prior <- !is.null(prior_model)

    features <- character()
    if (has_lr) features <- c(features, "long-read")
    if (has_prequant) features <- c(features, paste0(prequant$bias_type, "-bias"))
    if (has_prior) features <- c(features, "prior")

    if (verbose && length(features) > 0) {
        cli::cli_alert_info("Features: {.val {features}}")
    }

    # Prepare positional weights
    positional_weights <- NULL
    bias_quantiles <- NULL
    bias_type <- NULL

    if (has_prequant) {
        positional_weights <- prequant$weights
        bias_quantiles <- prequant$quantiles
        bias_type <- prequant$bias_type
    }

    # Prepare prior
    prior_predictions <- NULL
    covariate_matrix <- NULL
    use_prior <- FALSE

    if (has_prior) {
        prior_setup <- prepare_prior(
            prior_model = prior_model,
            index = index,
            lr_counts = if (has_lr) lr_counts$counts else NULL
        )
        prior_predictions <- prior_setup$predictions
        covariate_matrix <- prior_setup$covariate_matrix  # For mixed-effects model
        use_prior <- TRUE
    }

    # Extract count vectors
    sr_vec <- sr_counts$counts
    lr_vec <- if (has_lr) lr_counts$counts else NULL

    # Run EM algorithm
    if (verbose) cli::cli_progress_step("Running EM algorithm")

    em_result <- run_em_algorithm(
        index = index,
        sr_counts = sr_vec,
        lr_counts = lr_vec,
        positional_weights = positional_weights,
        bias_type = bias_type,
        max_iter = max_iter,
        tolerance = tolerance,
        use_prior = use_prior,
        prior_predictions = prior_predictions,
        covariate_matrix = covariate_matrix,
        prior_start = prior_start,
        convergence_start = convergence_start,
        verbose = verbose
    )

    # Normalize abundances
    abundances <- em_result$abundances
    normalized <- normalize_abundances(abundances, normalize)

    # Compute uncertainty if requested
    uncertainty <- NULL
    if (compute_uncertainty) {
        if (verbose) cli::cli_progress_step("Computing uncertainty estimates")
        uncertainty <- compute_abundance_uncertainty(
            index = index,
            abundances = abundances,
            fitted_values = em_result$fitted_values,
            sr_counts = sr_vec
        )
    }

    # Create enhanced result object
    result <- new_mpaqt_quant_result_enhanced(
        abundances = abundances,
        tpm = normalized$tpm,
        log_likelihood = em_result$log_likelihood,
        converged = em_result$converged,
        iterations = em_result$iterations,
        fitted_values = em_result$fitted_values,
        prior_variance = em_result$prior_variance,
        positional_weights = positional_weights,
        positional_bias_type = bias_type,
        lr_coverage_probs = em_result$lr_coverage_probs,
        lr_model = em_result$lr_model,
        prior_predictions = em_result$prior_predictions,
        normalization = normalize,
        normalized_counts = normalized$counts,
        uncertainty = uncertainty,
        parameters = list(
            max_iter = max_iter,
            tolerance = tolerance,
            prior_start = prior_start,
            convergence_start = convergence_start,
            prior_model_type = if (is.character(prior_model)) prior_model else "custom"
        ),
        sr_input = list(
            n_reads = sum(sr_vec),
            n_ec = length(sr_vec),
            sample_id = sr_counts$sample_id
        ),
        lr_input = if (has_lr) list(
            n_reads = sum(lr_vec),
            n_transcripts = sum(lr_vec > 0),
            sample_id = lr_counts$sample_id
        ) else NULL
    )

    if (verbose) {
        cli::cli_progress_done()

        if (em_result$converged) {
            cli::cli_alert_success(
                "Converged at iteration {em_result$iterations} (LL: {round(em_result$log_likelihood, 2)})"
            )
        } else {
            cli::cli_alert_warning(
                "Did not converge within {max_iter} iterations"
            )
        }

        n_expressed <- sum(abundances > 0)
        cli::cli_alert_info("{n_expressed} transcripts with non-zero abundance")
    }

    result
}

#' Prepare Prior for EM Algorithm
#'
#' @param prior_model Prior specification
#' @param index mpaqt_index object
#' @param lr_counts Long-read counts (optional)
#'
#' @return List with prior predictions
#' @keywords internal
prepare_prior <- function(prior_model, index, lr_counts) {
    n_transcripts <- length(index$transcripts)
    predictions <- rep(0, n_transcripts)

    if (is.null(prior_model)) {
        return(list(predictions = predictions))
    }

    if (is.character(prior_model)) {
        if (prior_model == "shrinkage") {
            # Empirical Bayes shrinkage - will be computed during EM
            return(list(predictions = predictions, type = "shrinkage"))
        } else if (prior_model == "long_read") {
            # Use long-read counts as prior mean
            if (is.null(lr_counts)) {
                cli::cli_warn("long_read prior requested but no LR counts provided")
                return(list(predictions = predictions))
            }
            # Log-transform with pseudocount
            predictions <- log(lr_counts + 1)
            return(list(predictions = predictions, type = "long_read"))
        }
    }

    # Handle data.frame prior (covariate matrix for mixed-effects model)
    if (is.data.frame(prior_model) && "transcript_id" %in% names(prior_model)) {
        covariate_matrix <- prepare_prior_covariates(
            prior_data = prior_model,
            transcripts = index$transcripts,
            trim_versions = TRUE
        )
        return(list(
            predictions = predictions,
            type = "mixed_effects",
            covariate_matrix = covariate_matrix
        ))
    }

    if (is.list(prior_model)) {
        if (!is.null(prior_model$mean)) {
            # Match to transcript order
            if (length(prior_model$mean) == n_transcripts) {
                predictions <- prior_model$mean
            } else if (!is.null(names(prior_model$mean))) {
                # Named vector - match by transcript ID
                matched <- match(index$transcripts, names(prior_model$mean))
                predictions[!is.na(matched)] <- prior_model$mean[matched[!is.na(matched)]]
            }
        }
        return(list(predictions = predictions, type = "custom"))
    }

    list(predictions = predictions)
}

#' Normalize Abundances
#'
#' @param abundances Raw abundance estimates
#' @param method Normalization method
#'
#' @return List with TPM and normalized counts
#' @keywords internal
normalize_abundances <- function(abundances, method = "tpm") {
    total <- sum(abundances)

    if (method == "tpm") {
        tpm <- abundances * 1e6 / total
        counts <- abundances
    } else if (method == "depth") {
        tpm <- abundances * 1e6 / total
        counts <- abundances * 1e6 / total
    } else {
        tpm <- abundances * 1e6 / total
        counts <- abundances
    }

    list(tpm = tpm, counts = counts)
}

#' Compute Abundance Uncertainty
#'
#' Estimate uncertainty in abundance estimates using Fisher information.
#'
#' @param index mpaqt_index object
#' @param abundances Estimated abundances
#' @param fitted_values Fitted EC counts
#' @param sr_counts Short-read counts
#'
#' @return Named numeric vector of standard errors
#' @keywords internal
compute_abundance_uncertainty <- function(
    index,
    abundances,
    fitted_values,
    sr_counts
) {
    n_transcripts <- length(abundances)
    se <- rep(NA_real_, n_transcripts)
    names(se) <- names(abundances)

    # Only compute for transcripts with positive abundance
    positive_idx <- which(abundances > 0)

    for (j in positive_idx) {
        p_data <- index$p_matrices[[j]]
        ec_idx <- p_data$i
        probs <- p_data$x

        # Fisher information (negative second derivative)
        y <- fitted_values[ec_idx]
        n <- sr_counts[ec_idx]

        # Avoid division by zero
        safe_y <- pmax(y, 1e-10)

        # Information from observed Fisher information
        info <- sum(probs^2 * n / safe_y^2)

        if (info > 0) {
            se[j] <- 1 / sqrt(info)
        }
    }

    se
}

#' Create Enhanced mpaqt_quant_result Object
#'
#' @param abundances Transcript abundances
#' @param tpm TPM values
#' @param log_likelihood Log-likelihood
#' @param converged Convergence status
#' @param iterations Number of iterations
#' @param fitted_values Fitted EC counts
#' @param prior_variance Prior variance
#' @param positional_weights Positional weights
#' @param positional_bias_type Bias type
#' @param lr_coverage_probs LR coverage probabilities
#' @param lr_model LR model object
#' @param prior_predictions Prior predictions
#' @param normalization Normalization method used
#' @param normalized_counts Normalized counts
#' @param uncertainty Uncertainty estimates
#' @param parameters Algorithm parameters
#' @param sr_input Short-read input metadata
#' @param lr_input Long-read input metadata
#'
#' @return Enhanced mpaqt_quant_result object
#' @keywords internal
new_mpaqt_quant_result_enhanced <- function(
    abundances,
    tpm,
    log_likelihood,
    converged,
    iterations,
    fitted_values,
    prior_variance,
    positional_weights = NULL,
    positional_bias_type = NULL,
    lr_coverage_probs = NULL,
    lr_model = NULL,
    prior_predictions = NULL,
    normalization = "tpm",
    normalized_counts = NULL,
    uncertainty = NULL,
    parameters = list(),
    sr_input = list(),
    lr_input = NULL
) {
    result <- new_mpaqt_quant_result(
        abundances = abundances,
        tpm = tpm,
        log_likelihood = log_likelihood,
        converged = converged,
        iterations = iterations,
        fitted_values = fitted_values,
        prior_variance = prior_variance,
        positional_weights = positional_weights,
        positional_bias_type = positional_bias_type,
        lr_coverage_probs = lr_coverage_probs,
        lr_model = lr_model,
        prior_predictions = prior_predictions,
        diagnostics = list()
    )

    # Add enhanced fields
    result$normalization <- normalization
    result$normalized_counts <- normalized_counts
    result$uncertainty <- uncertainty
    result$parameters <- parameters
    result$sr_input <- sr_input
    result$lr_input <- lr_input

    # Update attributes
    attr(result, "has_uncertainty") <- !is.null(uncertainty)
    attr(result, "normalization_method") <- normalization

    result
}

#' Combine Multiple Quantification Results
#'
#' Combine TPM values from multiple samples into a single matrix.
#'
#' @param ... mpaqt_quant_result objects
#' @param sample_names Optional sample names
#'
#' @return data.table with transcript_id and TPM columns for each sample
#' @export
combine_quant_results <- function(..., sample_names = NULL) {
    results <- list(...)

    if (length(results) == 0) {
        cli::cli_abort("No results provided")
    }

    # Get transcript IDs from first result
    transcript_ids <- names(results[[1]]$tpm)

    # Initialize data.table
    combined <- data.table::data.table(transcript_id = transcript_ids)

    # Add each sample
    for (i in seq_along(results)) {
        result <- results[[i]]

        if (!identical(names(result$tpm), transcript_ids)) {
            cli::cli_abort("Transcript IDs do not match across results")
        }

        # Determine sample name
        if (!is.null(sample_names) && length(sample_names) >= i) {
            name <- sample_names[i]
        } else if (!is.null(result$sr_input$sample_id)) {
            name <- result$sr_input$sample_id
        } else {
            name <- paste0("sample_", i)
        }

        combined[[name]] <- result$tpm
    }

    combined
}

#' Export Combined Results to CSV
#'
#' @param combined Combined results from combine_quant_results
#' @param path Output file path
#'
#' @return Invisible path
#' @export
export_combined_results <- function(combined, path) {
    data.table::fwrite(combined, path)
    cli::cli_alert_success("Exported {ncol(combined) - 1} samples to {.path {path}}")
    invisible(path)
}
