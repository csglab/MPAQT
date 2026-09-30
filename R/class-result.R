# S3 class: mpaqt_quant_result
# Stores quantification results from the EM algorithm

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c("abundance", "se"))

#' Create a new mpaqt_quant_result object
#'
#' Internal constructor for quantification result objects.
#'
#' @param abundances Named numeric vector of transcript abundances (beta)
#' @param tpm Named numeric vector of TPM values
#' @param log_likelihood Final log-likelihood value
#' @param converged Logical indicating convergence
#' @param iterations Number of EM iterations run
#' @param fitted_values Expected EC counts (fitted values)
#' @param prior_variance Prior variance (sigma^2)
#' @param positional_weights Positional bias weights (optional)
#' @param positional_bias_type Type of bias correction (optional)
#' @param lr_coverage_probs Long-read coverage probabilities (optional)
#' @param lr_model Long-read GLM model object (optional)
#' @param prior_predictions Transcript-specific prior predictions (optional)
#' @param diagnostics Additional diagnostic information (optional)
#'
#' @return An object of class `mpaqt_quant_result`
#' @keywords internal
new_mpaqt_quant_result <- function(
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
    diagnostics = list()
) {
    stopifnot(is.numeric(abundances))
    stopifnot(!is.null(names(abundances)))
    stopifnot(is.numeric(tpm))
    stopifnot(is.logical(converged))
    stopifnot(is.numeric(iterations))

    structure(
        list(
            abundances = abundances,
            tpm = tpm,
            log_likelihood = log_likelihood,
            converged = converged,
            iterations = as.integer(iterations),
            fitted_values = fitted_values,
            prior_variance = prior_variance,
            positional_weights = positional_weights,
            positional_bias_type = positional_bias_type,
            lr_coverage_probs = lr_coverage_probs,
            lr_model = lr_model,
            prior_predictions = prior_predictions,
            diagnostics = diagnostics
        ),
        class = c("mpaqt_quant_result", "list"),
        n_transcripts = length(abundances),
        has_long_reads = !is.null(lr_coverage_probs),
        has_bias_correction = !is.null(positional_weights),
        has_prior = !is.null(prior_predictions),
        created = Sys.time()
    )
}

#' Print method for mpaqt_quant_result
#'
#' @param x An mpaqt_quant_result object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible x
#' @export
print.mpaqt_quant_result <- function(x, ...) {
    cli::cli_h1("MPAQT Quantification Result")

    # Convergence status
    if (x$converged) {
        cli::cli_alert_success("Converged in {x$iterations} iterations")
    } else {
        cli::cli_alert_warning("Did not converge ({x$iterations} iterations)")
    }

    cli::cli_text("Transcripts: {.val {attr(x, 'n_transcripts')}}")
    cli::cli_text("Log-likelihood: {.val {round(x$log_likelihood, 2)}}")
    cli::cli_text("Prior variance: {.val {round(x$prior_variance, 4)}}")

    # Features used
    features <- character()
    if (attr(x, "has_long_reads")) features <- c(features, "long-read")
    if (attr(x, "has_bias_correction")) features <- c(features, paste0(x$positional_bias_type, "-bias"))
    if (attr(x, "has_prior")) features <- c(features, "prior")

    if (length(features) > 0) {
        cli::cli_text("Features: {.val {features}}")
    }

    invisible(x)
}

#' Summary method for mpaqt_quant_result
#'
#' @param object An mpaqt_quant_result object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible summary list
#' @export
summary.mpaqt_quant_result <- function(object, ...) {
    cat("MPAQT Quantification Summary\n")
    cat("============================\n\n")

    cat("Convergence:\n")
    cat("  Status:", if (object$converged) "Converged" else "Not converged", "\n")
    cat("  Iterations:", object$iterations, "\n")
    cat("  Final log-likelihood:", round(object$log_likelihood, 2), "\n")
    cat("  Prior variance:", round(object$prior_variance, 4), "\n\n")

    cat("Transcript abundances:\n")
    cat("  Total transcripts:", attr(object, "n_transcripts"), "\n")
    cat("  Non-zero:", sum(object$abundances > 0), "\n")
    cat("  Sum(beta):", format(sum(object$abundances), big.mark = ","), "\n\n")

    cat("TPM distribution:\n")
    nonzero_tpm <- object$tpm[object$tpm > 0]
    cat("  Min (non-zero):", round(min(nonzero_tpm), 4), "\n")
    cat("  Median:", round(median(nonzero_tpm), 4), "\n")
    cat("  Max:", round(max(nonzero_tpm), 4), "\n\n")

    cat("Features:\n")
    cat("  Long-read integration:", attr(object, "has_long_reads"), "\n")
    cat("  Positional bias:", attr(object, "has_bias_correction"), "\n")
    if (attr(object, "has_bias_correction")) {
        cat("    Type:", object$positional_bias_type, "\n")
        cat("    Bins:", length(object$positional_weights), "\n")
    }
    cat("  Prior integration:", attr(object, "has_prior"), "\n")

    invisible(list(
        converged = object$converged,
        iterations = object$iterations,
        log_likelihood = object$log_likelihood,
        prior_variance = object$prior_variance,
        n_transcripts = attr(object, "n_transcripts"),
        n_nonzero = sum(object$abundances > 0)
    ))
}

# =============================================================================
# Extractor functions
# =============================================================================

#' Extract TPM values from quantification result
#'
#' @param x An mpaqt_quant_result object
#' @param ... Additional arguments (unused)
#'
#' @return Named numeric vector of TPM values
#' @export
tpm <- function(x, ...) {
    UseMethod("tpm")
}

#' @rdname tpm
#' @export
tpm.mpaqt_quant_result <- function(x, ...) {
    x$tpm
}

#' Extract raw abundances from quantification result
#'
#' @param x An mpaqt_quant_result object
#' @param ... Additional arguments (unused)
#'
#' @return Named numeric vector of abundances
#' @export
abundances <- function(x, ...) {
    UseMethod("abundances")
}

#' @rdname abundances
#' @export
abundances.mpaqt_quant_result <- function(x, ...) {
    x$abundances
}

#' Extract coefficients (abundances) from quantification result
#'
#' Standard R interface for extracting model coefficients.
#'
#' @param object An mpaqt_quant_result object
#' @param ... Additional arguments (unused)
#'
#' @return Named numeric vector of abundances
#' @export
coef.mpaqt_quant_result <- function(object, ...) {
    object$abundances
}

#' Extract fitted values from quantification result
#'
#' Returns the expected EC counts from the model.
#'
#' @param object An mpaqt_quant_result object
#' @param ... Additional arguments (unused)
#'
#' @return Numeric vector of expected EC counts
#' @export
fitted.mpaqt_quant_result <- function(object, ...) {
    object$fitted_values
}

#' Aggregate transcript abundances to gene level
#'
#' @param result An mpaqt_quant_result object
#' @param index An mpaqt_index object (for gene mapping)
#' @param method Aggregation method: "sum" (default) or "mean"
#' @param value_type "tpm" or "abundances"
#'
#' @return Named numeric vector of gene-level values
#' @export
gene_abundances <- function(result, index, method = "sum", value_type = "tpm") {
    if (!inherits(result, "mpaqt_quant_result")) {
        cli::cli_abort("Expected an {.cls mpaqt_quant_result} object")
    }
    validate_mpaqt_index(index)

    values <- if (value_type == "tpm") result$tpm else result$abundances

    # Match transcripts
    if (!identical(names(values), index$transcripts)) {
        cli::cli_abort(c(
            "Transcript IDs do not match between result and index",
            "i" = "Ensure the result was generated using this index"
        ))
    }

    # Aggregate by gene
    gene_values <- tapply(values, index$genes, FUN = switch(method,
        sum = sum,
        mean = mean
    ))

    as.numeric(gene_values)
}

# =============================================================================
# I/O Functions
# =============================================================================

#' Save quantification result to disk
#'
#' @param result An mpaqt_quant_result object
#' @param path File path for the RDS file
#'
#' @return Invisible path
#' @keywords internal
save_mpaqt_result <- function(result, path) {
    if (!inherits(result, "mpaqt_quant_result")) {
        cli::cli_abort("Expected an {.cls mpaqt_quant_result} object")
    }
    saveRDS(result, path)
    invisible(path)
}

#' Load quantification result from disk
#'
#' @param path Path to the RDS file
#'
#' @return An mpaqt_quant_result object
#' @export
mpaqt_read_result <- function(path) {
    validate_file_exists(path, "Result file")

    result <- readRDS(path)

    # Handle legacy format
    if (!inherits(result, "mpaqt_quant_result")) {
        if (all(c("beta", "tpm", "LL", "converged") %in% names(result))) {
            cli::cli_alert_info("Converting legacy result format")
            result <- convert_legacy_result(result)
        } else {
            cli::cli_abort(c(
                "Invalid result file: {.path {path}}",
                "i" = "File does not contain valid MPAQT quantification result"
            ))
        }
    }

    result
}

#' Convert legacy result format
#'
#' @param legacy_result List in legacy format
#'
#' @return An mpaqt_quant_result object
#' @keywords internal
convert_legacy_result <- function(legacy_result) {
    new_mpaqt_quant_result(
        abundances = legacy_result$beta,
        tpm = legacy_result$tpm,
        log_likelihood = legacy_result$LL,
        converged = legacy_result$converged,
        iterations = legacy_result$iterations,
        fitted_values = legacy_result$fitted.values,
        prior_variance = legacy_result$sigma2,
        positional_weights = legacy_result$positional_weights,
        positional_bias_type = legacy_result$positional_bias_type,
        lr_coverage_probs = legacy_result$P2,
        lr_model = legacy_result$P2.fit,
        prior_predictions = legacy_result$preds,
        diagnostics = legacy_result$diagnostics %||% list()
    )
}

#' Export results to CSV
#'
#' @param result An mpaqt_quant_result object
#' @param path Output CSV file path
#' @param include_abundances Include raw abundances column
#' @param include_uncertainty Include standard errors (if available)
#'
#' @return Invisible path
#' @export
export_results_csv <- function(
    result,
    path,
    include_abundances = FALSE,
    include_uncertainty = FALSE
) {
    if (!inherits(result, "mpaqt_quant_result")) {
        cli::cli_abort("Expected an {.cls mpaqt_quant_result} object")
    }

    dt <- data.table::data.table(
        transcript_id = names(result$tpm),
        tpm = result$tpm
    )

    if (include_abundances) {
        dt[, abundance := result$abundances]
    }

    if (include_uncertainty && !is.null(result$uncertainty)) {
        dt[, se := result$uncertainty]
    }

    data.table::fwrite(dt, path)

    cli::cli_alert_success("Exported {nrow(dt)} transcripts to {.path {path}}")
    invisible(path)
}

# =============================================================================
# Additional Extractor Functions
# =============================================================================

#' Extract Uncertainty Estimates
#'
#' @param x An mpaqt_quant_result object
#' @param ... Additional arguments (unused)
#'
#' @return Named numeric vector of standard errors, or NULL if not computed
#' @export
uncertainty <- function(x, ...) {
    UseMethod("uncertainty")
}

#' @rdname uncertainty
#' @export
uncertainty.mpaqt_quant_result <- function(x, ...) {
    x$uncertainty
}

#' Check if Result Has Uncertainty Estimates
#'
#' @param result An mpaqt_quant_result object
#'
#' @return Logical indicating if uncertainty was computed
#' @export
has_uncertainty <- function(result) {
    if (!inherits(result, "mpaqt_quant_result")) {
        cli::cli_abort("Expected an {.cls mpaqt_quant_result} object")
    }
    !is.null(result$uncertainty)
}

#' Get Input Metadata
#'
#' @param result An mpaqt_quant_result object
#'
#' @return List with sr_input and lr_input metadata
#' @export
get_input_metadata <- function(result) {
    if (!inherits(result, "mpaqt_quant_result")) {
        cli::cli_abort("Expected an {.cls mpaqt_quant_result} object")
    }

    list(
        sr_input = result$sr_input,
        lr_input = result$lr_input
    )
}

#' Get Algorithm Parameters
#'
#' @param result An mpaqt_quant_result object
#'
#' @return List of parameters used in quantification
#' @export
get_parameters <- function(result) {
    if (!inherits(result, "mpaqt_quant_result")) {
        cli::cli_abort("Expected an {.cls mpaqt_quant_result} object")
    }

    result$parameters %||% list(
        max_iter = NA,
        tolerance = NA,
        prior_start = NA,
        convergence_start = NA
    )
}

# =============================================================================
# Result Validation
# =============================================================================

#' Validate mpaqt_quant_result Object
#'
#' @param x Object to validate
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_mpaqt_quant_result <- function(x) {
    if (!inherits(x, "mpaqt_quant_result")) {
        cli::cli_abort(c(
            "Expected an {.cls mpaqt_quant_result} object",
            "i" = "Run quantification with {.fn mpaqt_quant} first"
        ))
    }

    required <- c("abundances", "tpm", "log_likelihood", "converged", "iterations")
    missing <- setdiff(required, names(x))

    if (length(missing) > 0) {
        cli::cli_abort(c(
            "Invalid {.cls mpaqt_quant_result}: missing components",
            "x" = "Missing: {.val {missing}}"
        ))
    }

    invisible(TRUE)
}
