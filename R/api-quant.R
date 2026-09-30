# API: Transcript Quantification
# User-facing functions for running MPAQT quantification

#' Quantify Transcript Abundances
#'
#' Main entry point for MPAQT transcript quantification. Estimates transcript
#' abundances from short-read (required) and long-read (optional) RNA-seq data
#' using an EM algorithm with optional positional bias correction and prior
#' integration.
#'
#' @details
#' The MPAQT algorithm solves the following optimization problem:
#' \deqn{maximize L(\beta) = L_{SR}(\beta) + L_{LR}(\beta) - R(\beta)}
#'
#' Where:
#' - \eqn{L_{SR}(\beta)}: Short-read Poisson likelihood
#' - \eqn{L_{LR}(\beta)}: Long-read Poisson likelihood (if available)
#' - \eqn{R(\beta)}: L2 regularization penalty on log scale
#'
#' ## Workflow Phases
#'
#' Quantification proceeds in two phases:
#'
#' 1. **Pre-quantification** (optional): Estimates positional bias weights
#' 2. **Post-quantification** (required): Runs main EM algorithm
#'
#' You can run these phases separately using [mpaqt_prequant()] and
#' [mpaqt_postquant()] for more control.
#'
#' @param index An `mpaqt_index` object or path to index RDS file
#' @param sr_counts An `mpaqt_counts_sr` object or path to short-read counts
#' @param lr_counts An `mpaqt_counts_lr` object or path to long-read counts
#'   (optional)
#' @param positional_bias Type of positional bias correction: NULL (none),
#'   "3p" (3' bias), or "5p" (5' bias). Default is NULL.
#' @param n_bins Number of distance bins for bias correction (default: 50)
#' @param prior_model Prior specification: NULL (none), "shrinkage",
#'   "long_read", or a custom list. See Details.
#' @param normalize Normalization method: "tpm" (default), "depth", or "none"
#' @param max_iter Maximum number of EM iterations (default: 100)
#' @param tolerance Convergence tolerance for log-likelihood change
#'   (default: 1e-4)
#' @param prior_start Iteration to start using prior information
#'   (default: 25)
#' @param convergence_start Iteration to start checking convergence
#'   (default: 25)
#' @param compute_uncertainty Compute uncertainty estimates (default: FALSE)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return An `mpaqt_quant_result` object containing:
#'   - `abundances`: Estimated transcript abundances (beta)
#'   - `tpm`: Transcripts per million values
#'   - `log_likelihood`: Final log-likelihood
#'   - `converged`: Whether algorithm converged
#'   - `iterations`: Number of iterations run
#'   - `fitted_values`: Expected EC counts
#'   - `prior_variance`: Prior variance (sigma^2)
#'   - `positional_weights`: Positional bias weights (if used)
#'   - `lr_coverage_probs`: Long-read coverage probabilities (if used)
#'   - `uncertainty`: Standard errors (if computed)
#'
#' @export
#'
#' @seealso
#' - [mpaqt_prequant()] for separate pre-quantification
#' - [mpaqt_postquant()] for separate post-quantification
#' - [mpaqt_index()] for creating an index
#' - [mpaqt_prepare_short_reads()] for processing short reads
#' - [mpaqt_prepare_long_reads()] for processing long reads
#'
#' @examples
#' \dontrun{
#' # Basic quantification with short reads only
#' result <- mpaqt_quant(
#'   index = "my_index/mpaqt.index.rds",
#'   sr_counts = "results/mpaqt.short_read.rds"
#' )
#'
#' # With long reads
#' result <- mpaqt_quant(
#'   index = idx,
#'   sr_counts = sr,
#'   lr_counts = lr
#' )
#'
#' # With positional bias correction
#' result <- mpaqt_quant(
#'   index = idx,
#'   sr_counts = sr,
#'   lr_counts = lr,
#'   positional_bias = "3p",
#'   n_bins = 50
#' )
#'
#' # With shrinkage prior
#' result <- mpaqt_quant(
#'   index = idx,
#'   sr_counts = sr,
#'   prior_model = "shrinkage"
#' )
#' }
mpaqt_quant <- function(
    index,
    sr_counts,
    lr_counts = NULL,
    positional_bias = NULL,
    n_bins = 50L,
    prior_model = NULL,
    normalize = "tpm",
    max_iter = 100L,
    tolerance = 1e-4,
    prior_start = 25L,
    convergence_start = 25L,
    compute_uncertainty = FALSE,
    verbose = TRUE
) {
    # Load inputs if paths provided
    if (is.character(index)) {
        index <- mpaqt_read_index(index)
    }
    validate_mpaqt_index(index)

    if (is.character(sr_counts)) {
        sr_counts <- mpaqt_read_short_read_counts(sr_counts)
    }
    validate_mpaqt_counts_sr(sr_counts)

    if (!is.null(lr_counts) && is.character(lr_counts)) {
        lr_counts <- mpaqt_read_long_read_counts(lr_counts)
    }

    # Run pre-quantification if bias correction requested
    prequant <- NULL
    if (!is.null(positional_bias)) {
        validate_bias_type(positional_bias)

        prequant <- mpaqt_prequant(
            index = index,
            sr_counts = sr_counts,
            positional_bias = positional_bias,
            n_bins = n_bins,
            verbose = verbose
        )
    }

    # Run post-quantification
    result <- mpaqt_postquant(
        index = index,
        sr_counts = sr_counts,
        lr_counts = lr_counts,
        prequant = prequant,
        prior_model = prior_model,
        normalize = normalize,
        max_iter = max_iter,
        tolerance = tolerance,
        prior_start = prior_start,
        convergence_start = convergence_start,
        compute_uncertainty = compute_uncertainty,
        verbose = verbose
    )

    result
}

#' Quantify Transcript Abundances (Bulk RNA-seq)
#'
#' @description
#' Alias for [mpaqt_quant()] for backwards compatibility.
#'
#' @inheritParams mpaqt_quant
#' @param prior Data frame with transcript_id column and covariate columns
#'   for mixed-effects prior integration (deprecated, use prior_model)
#'
#' @return An `mpaqt_quant_result` object
#'
#' @export
#'
#' @seealso [mpaqt_quant()] for the main quantification function
mpaqt_quant_bulk <- function(
    index,
    sr_counts,
    lr_counts = NULL,
    positional_bias = NULL,
    n_bins = 50L,
    prior = NULL,
    max_iter = 100L,
    tolerance = 1e-4,
    prior_start = 25L,
    convergence_start = 25L,
    verbose = TRUE
) {
    # Handle legacy 'prior' parameter
    prior_model <- NULL
    if (!is.null(prior)) {
        cli::cli_warn(c(
            "The {.arg prior} parameter is deprecated",
            "i" = "Use {.arg prior_model} instead"
        ))
        prior_model <- prior
    }

    mpaqt_quant(
        index = index,
        sr_counts = sr_counts,
        lr_counts = lr_counts,
        positional_bias = positional_bias,
        n_bins = n_bins,
        prior_model = prior_model,
        normalize = "tpm",
        max_iter = max_iter,
        tolerance = tolerance,
        prior_start = prior_start,
        convergence_start = convergence_start,
        compute_uncertainty = FALSE,
        verbose = verbose
    )
}

#' Quantify Transcript Abundances (Single-Cell RNA-seq)
#'
#' Estimate transcript abundances for single-cell RNA-seq data by cluster.
#' This function processes each cluster independently and returns a list
#' of quantification results.
#'
#' @inheritParams mpaqt_quant
#' @param sr_counts_list Named list of `mpaqt_counts_sr` objects, one per
#'   cluster (as returned by [mpaqt_prepare_short_reads_sc()])
#' @param lr_counts_list Named list of `mpaqt_counts_lr` objects, one per
#'   cluster (optional, as returned by [mpaqt_prepare_long_reads_sc()])
#'
#' @return Named list of `mpaqt_quant_result` objects, one per cluster
#'
#' @export
#'
#' @seealso [mpaqt_quant()] for bulk quantification,
#'   [mpaqt_prepare_short_reads_sc()] for processing single-cell short reads
#'
#' @examples
#' \dontrun{
#' # Process single-cell data
#' sr_list <- mpaqt_prepare_short_reads_sc(
#'   index = idx,
#'   fastq_1 = "sample_R1.fastq.gz",
#'   fastq_2 = "sample_R2.fastq.gz",
#'   clusters_file = "clusters.csv",
#'   output_dir = "results"
#' )
#'
#' # Quantify all clusters
#' results <- mpaqt_quant_sc(
#'   index = idx,
#'   sr_counts_list = sr_list
#' )
#'
#' # Access results for a specific cluster
#' cluster1_tpm <- results[["1"]]$tpm
#' }
mpaqt_quant_sc <- function(
    index,
    sr_counts_list,
    lr_counts_list = NULL,
    positional_bias = NULL,
    n_bins = 50L,
    prior_model = NULL,
    max_iter = 100L,
    tolerance = 1e-4,
    prior_start = 25L,
    convergence_start = 25L,
    verbose = TRUE
) {
    # Load index if path provided
    if (is.character(index)) {
        index <- mpaqt_read_index(index)
    }
    validate_mpaqt_index(index)

    # Validate inputs
    if (!is.list(sr_counts_list)) {
        cli::cli_abort("sr_counts_list must be a named list of mpaqt_counts_sr objects")
    }

    cluster_ids <- names(sr_counts_list)
    if (is.null(cluster_ids)) {
        cli::cli_abort("sr_counts_list must be a named list")
    }

    cli::cli_h1("MPAQT Single-Cell Quantification")
    cli::cli_alert_info("Processing {length(cluster_ids)} clusters")

    # Run pre-quantification once if bias correction requested
    # Use the "all_clusters" combined counts for better weight estimation
    prequant <- NULL
    if (!is.null(positional_bias)) {
        validate_bias_type(positional_bias)

        # Use combined counts if available
        combined_sr <- if ("all_clusters" %in% cluster_ids) {
            sr_counts_list[["all_clusters"]]
        } else {
            sr_counts_list[[1]]
        }

        cli::cli_h2("Pre-quantification (shared across clusters)")

        prequant <- mpaqt_prequant(
            index = index,
            sr_counts = combined_sr,
            positional_bias = positional_bias,
            n_bins = n_bins,
            verbose = verbose
        )
    }

    # Process each cluster
    results <- list()

    for (cluster in cluster_ids) {
        cli::cli_h2("Cluster: {cluster}")

        sr_counts <- sr_counts_list[[cluster]]
        lr_counts <- if (!is.null(lr_counts_list)) lr_counts_list[[cluster]] else NULL

        result <- mpaqt_postquant(
            index = index,
            sr_counts = sr_counts,
            lr_counts = lr_counts,
            prequant = prequant,
            prior_model = prior_model,
            normalize = "tpm",
            max_iter = max_iter,
            tolerance = tolerance,
            prior_start = prior_start,
            convergence_start = convergence_start,
            compute_uncertainty = FALSE,
            verbose = verbose
        )

        results[[cluster]] <- result
    }

    cli::cli_alert_success("Completed quantification for {length(results)} clusters")

    results
}

#' Save Quantification Results
#'
#' Save transcript quantification results to files. Creates both an RDS file
#' with the full result object and a CSV file with TPM values.
#'
#' @param result An `mpaqt_quant_result` object
#' @param output_dir Output directory
#' @param prefix File name prefix (default: "mpaqt")
#' @param include_abundances Include raw abundances in CSV (default: FALSE)
#' @param include_uncertainty Include uncertainty in CSV (default: FALSE)
#'
#' @return Invisibly returns the paths to created files
#'
#' @export
#'
#' @examples
#' \dontrun{
#' result <- mpaqt_quant(index, sr_counts)
#' mpaqt_save_result(result, output_dir = "results", prefix = "sample1")
#' }
mpaqt_save_result <- function(
    result,
    output_dir,
    prefix = "mpaqt",
    include_abundances = FALSE,
    include_uncertainty = FALSE
) {
    validate_mpaqt_quant_result(result)
    validate_output_dir(output_dir)

    # Save RDS
    rds_file <- file.path(output_dir, paste0(prefix, ".quant.rds"))
    saveRDS(result, rds_file)

    # Build CSV data
    csv_data <- data.table::data.table(
        transcript_id = names(result$tpm),
        tpm = result$tpm
    )

    if (include_abundances) {
        csv_data[, abundance := result$abundances]
    }

    if (include_uncertainty && !is.null(result$uncertainty)) {
        csv_data[, se := result$uncertainty]
    }

    # Save CSV
    csv_file <- file.path(output_dir, paste0(prefix, ".quant.csv"))
    data.table::fwrite(csv_data, csv_file)

    cli::cli_alert_success("Saved: {.path {rds_file}}")
    cli::cli_alert_success("Saved: {.path {csv_file}}")

    invisible(c(rds = rds_file, csv = csv_file))
}

#' Save Single-Cell Quantification Results
#'
#' Save all cluster results and a combined TPM matrix.
#'
#' @param results Named list of mpaqt_quant_result objects
#' @param output_dir Output directory
#' @param prefix File name prefix (default: "mpaqt")
#'
#' @return Invisibly returns the path to the combined CSV
#'
#' @export
mpaqt_save_result_sc <- function(results, output_dir, prefix = "mpaqt") {
    validate_output_dir(output_dir)

    # Save individual cluster results
    for (cluster in names(results)) {
        cluster_prefix <- paste0(prefix, ".", cluster)
        mpaqt_save_result(
            results[[cluster]],
            output_dir,
            prefix = cluster_prefix
        )
    }

    # Create combined TPM matrix
    combined <- do.call(combine_quant_results, results)
    combined_file <- file.path(output_dir, paste0(prefix, ".combined.csv"))
    data.table::fwrite(combined, combined_file)

    cli::cli_alert_success("Saved combined TPM matrix: {.path {combined_file}}")

    invisible(combined_file)
}

