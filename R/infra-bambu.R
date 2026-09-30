# Infrastructure: Bambu wrapper functions
# Internal functions for running Bambu for long-read transcript quantification

#' Check if Bambu is available
#'
#' @return Invisible TRUE if Bambu is installed
#' @keywords internal
check_bambu <- function() {
    require_bioc("bambu", "for long-read transcript quantification")
    invisible(TRUE)
}

#' Run Bambu for Long-Read Quantification
#'
#' Run Bambu to quantify transcript expression from long-read BAM files.
#' Bambu performs transcript discovery and quantification using genome-aligned
#' long reads and a reference annotation.
#'
#' @param bam_files Character vector of paths to BAM files (genome-aligned)
#' @param gtf_path Path to GTF annotation file
#' @param genome BSgenome object or path to genome FASTA
#' @param output_dir Output directory for Bambu results
#' @param discovery Enable novel transcript discovery (default: FALSE)
#' @param quant Enable quantification (default: TRUE)
#' @param ndr Novel Discovery Rate threshold (default: 1 = all novel)
#' @param threads Number of threads (default: 1)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return A SummarizedExperiment object with transcript counts
#' @keywords internal
run_bambu <- function(
    bam_files,
    gtf_path,
    genome,
    output_dir,
    discovery = FALSE,
    quant = TRUE,
    ndr = 1,
    threads = 1L,
    verbose = TRUE
) {
    check_bambu()
    require_bioc("SummarizedExperiment", "for Bambu output")

    # Validate inputs
    for (bam in bam_files) {
        validate_file_exists(bam, "BAM file")
    }
    validate_gtf(gtf_path)

    if (verbose) {
        cli::cli_h2("Running Bambu Long-Read Quantification")
        cli::cli_alert_info("BAM files: {length(bam_files)}")
        cli::cli_alert_info("Discovery: {.val {discovery}}")
        cli::cli_alert_info("Threads: {.val {threads}}")
    }

    # Load annotation
    if (verbose) cli::cli_progress_step("Loading annotation")

    annotations <- bambu::prepareAnnotations(gtf_path)

    # Handle genome - can be BSgenome object, package name, or FASTA path
    if (verbose) cli::cli_progress_step("Loading genome reference")

    genome_obj <- load_genome_for_bambu(genome)

    # Run Bambu
    if (verbose) cli::cli_progress_step("Running Bambu quantification")

    se <- bambu::bambu(
        reads = bam_files,
        annotations = annotations,
        genome = genome_obj,
        discovery = discovery,
        quant = quant,
        NDR = ndr,
        ncore = threads,
        verbose = verbose
    )

    if (verbose) {
        n_transcripts <- nrow(se)
        n_samples <- ncol(se)
        cli::cli_alert_success("Quantified {n_transcripts} transcripts across {n_samples} sample{?s}")
    }

    se
}

#' Load Genome for Bambu
#'
#' Helper to load genome reference for Bambu from various input types.
#'
#' @param genome BSgenome object, package name string, or FASTA path
#'
#' @return Genome object suitable for Bambu
#' @keywords internal
load_genome_for_bambu <- function(genome) {
    require_bioc("Biostrings", "for sequence handling")

    # If already a BSgenome or DNAStringSet, return as-is
    if (inherits(genome, "BSgenome") || inherits(genome, "DNAStringSet")) {
        return(genome)
    }

    # If character, could be package name or file path
    if (is.character(genome)) {
        # Check if it's a file path
        if (file.exists(genome)) {
            # Load FASTA file
            return(Biostrings::readDNAStringSet(genome))
        }

        # Check if it's a BSgenome package name
        if (grepl("^BSgenome\\.", genome)) {
            return(load_bsgenome(genome))
        }

        cli::cli_abort(c(
            "Invalid genome specification: {.val {genome}}",
            "i" = "Provide a BSgenome object, package name, or FASTA file path"
        ))
    }

    cli::cli_abort(c(
        "Invalid genome argument type",
        "i" = "Expected BSgenome object, package name string, or FASTA path"
    ))
}

#' Extract Transcript Counts from Bambu Output
#'
#' Extract transcript-level counts from a Bambu SummarizedExperiment object.
#'
#' @param se SummarizedExperiment object from Bambu
#' @param sample_idx Sample index to extract (default: 1)
#' @param count_type Count type to extract: "counts" or "CPM" (default: "counts")
#'
#' @return Named numeric vector of transcript counts
#' @keywords internal
extract_bambu_counts <- function(se, sample_idx = 1L, count_type = "counts") {
    require_bioc("SummarizedExperiment", "for Bambu output")

    if (!inherits(se, "SummarizedExperiment")) {
        cli::cli_abort("Expected SummarizedExperiment object from Bambu")
    }

    # Get assay names
    assay_names <- SummarizedExperiment::assayNames(se)

    if (!count_type %in% assay_names) {
        cli::cli_abort(c(
            "Count type {.val {count_type}} not found in Bambu output",
            "i" = "Available assays: {.val {assay_names}}"
        ))
    }

    # Extract counts
    counts_mat <- SummarizedExperiment::assay(se, count_type)

    if (sample_idx > ncol(counts_mat)) {
        cli::cli_abort(c(
            "Sample index {sample_idx} out of range",
            "i" = "Only {ncol(counts_mat)} sample{?s} available"
        ))
    }

    counts_vec <- counts_mat[, sample_idx]
    names(counts_vec) <- rownames(counts_mat)

    counts_vec
}

#' Extract Counts from All Bambu Samples
#'
#' Extract transcript counts from all samples in a Bambu SummarizedExperiment.
#'
#' @param se SummarizedExperiment object from Bambu
#' @param count_type Count type: "counts" or "CPM" (default: "counts")
#'
#' @return data.table with transcript_id and count columns for each sample
#' @keywords internal
extract_all_bambu_counts <- function(se, count_type = "counts") {
    require_bioc("SummarizedExperiment", "for Bambu output")

    counts_mat <- SummarizedExperiment::assay(se, count_type)

    # Convert to data.table
    counts_dt <- data.table::as.data.table(counts_mat, keep.rownames = "transcript_id")

    counts_dt
}

#' Convert Bambu Counts to MPAQT Format
#'
#' Convert Bambu output to mpaqt_counts_lr format for use in quantification.
#'
#' @param se SummarizedExperiment from Bambu or path to saved RDS
#' @param index mpaqt_index object for transcript ordering
#' @param sample_idx Sample index (default: 1)
#' @param sample_id Sample identifier (default: derived from Bambu output)
#'
#' @return mpaqt_counts_lr object
#' @keywords internal
bambu_to_mpaqt_counts <- function(se, index, sample_idx = 1L, sample_id = NULL) {
    require_bioc("SummarizedExperiment", "for Bambu output")

    # Load SE if path provided
    if (is.character(se)) {
        validate_file_exists(se, "Bambu output file")
        se <- readRDS(se)
    }

    if (!inherits(se, "SummarizedExperiment")) {
        cli::cli_abort("Expected SummarizedExperiment object")
    }

    # Extract counts
    counts_vec <- extract_bambu_counts(se, sample_idx, "counts")

    # Match to index transcript order
    counts_ordered <- match_counts_to_index(counts_vec, index$transcripts)

    # Create sample ID
    if (is.null(sample_id)) {
        sample_names <- colnames(SummarizedExperiment::assay(se))
        if (length(sample_names) >= sample_idx) {
            sample_id <- sample_names[sample_idx]
        } else {
            sample_id <- paste0("sample_", sample_idx)
        }
    }

    # Create counts object
    new_mpaqt_counts_lr(
        counts = counts_ordered,
        sample_id = sample_id
    )
}

#' Match Counts Vector to Index Order
#'
#' Reorder and fill counts vector to match index transcript order.
#'
#' @param counts Named numeric vector of counts
#' @param index_transcripts Character vector of transcript IDs in index order
#'
#' @return Named numeric vector in index order
#' @keywords internal
match_counts_to_index <- function(counts, index_transcripts) {
    # Create output vector with zeros
    ordered_counts <- rep(0, length(index_transcripts))
    names(ordered_counts) <- index_transcripts

    # Find matching transcripts
    common <- intersect(names(counts), index_transcripts)

    if (length(common) == 0) {
        cli::cli_warn(c(
            "No transcripts match between counts and index",
            "i" = "Check that transcript IDs are consistent"
        ))
        return(ordered_counts)
    }

    # Fill in matching counts
    ordered_counts[common] <- counts[common]

    # Report matching statistics
    n_matched <- length(common)
    n_counts <- length(counts)
    n_index <- length(index_transcripts)

    pct_matched <- round(100 * n_matched / n_counts, 1)

    if (pct_matched < 50) {
        cli::cli_warn(c(
            "Only {pct_matched}% of count transcripts found in index",
            "i" = "Matched: {n_matched} of {n_counts}",
            "i" = "This may indicate mismatched references"
        ))
    }

    ordered_counts
}

#' Read Bambu Count Table from CSV/TSV
#'
#' Read a pre-computed Bambu count table and convert to MPAQT format.
#' The file should have transcript_id in the first column and counts in
#' subsequent columns.
#'
#' @param count_file Path to count table (CSV or TSV)
#' @param index mpaqt_index object
#' @param sample_col Column name or index for counts (default: 2, second column)
#' @param sample_id Sample identifier
#'
#' @return mpaqt_counts_lr object
#' @keywords internal
read_bambu_count_table <- function(count_file, index, sample_col = 2L, sample_id = NULL) {
    validate_file_exists(count_file, "Bambu count file")

    # Read count table
    counts_dt <- data.table::fread(count_file)

    # Get transcript IDs (first column)
    if (ncol(counts_dt) < 2) {
        cli::cli_abort(c(
            "Count file must have at least 2 columns",
            "i" = "Expected: transcript_id, count(s)"
        ))
    }

    transcript_ids <- counts_dt[[1]]

    # Get counts (specified column)
    if (is.numeric(sample_col)) {
        if (sample_col > ncol(counts_dt)) {
            cli::cli_abort(c(
                "Column {sample_col} out of range",
                "i" = "File has {ncol(counts_dt)} columns"
            ))
        }
        counts_vec <- counts_dt[[sample_col]]
        if (is.null(sample_id)) {
            sample_id <- names(counts_dt)[sample_col]
        }
    } else {
        if (!sample_col %in% names(counts_dt)) {
            cli::cli_abort(c(
                "Column {.val {sample_col}} not found",
                "i" = "Available columns: {.val {names(counts_dt)}}"
            ))
        }
        counts_vec <- counts_dt[[sample_col]]
        if (is.null(sample_id)) {
            sample_id <- sample_col
        }
    }

    names(counts_vec) <- transcript_ids

    # Match to index order
    counts_ordered <- match_counts_to_index(counts_vec, index$transcripts)

    new_mpaqt_counts_lr(
        counts = counts_ordered,
        sample_id = sample_id
    )
}

#' Save Bambu Results
#'
#' Save Bambu SummarizedExperiment to disk for later use.
#'
#' @param se SummarizedExperiment object from Bambu
#' @param output_file Path for output RDS file
#'
#' @return Invisible output path
#' @keywords internal
save_bambu_results <- function(se, output_file) {
    saveRDS(se, output_file)
    invisible(output_file)
}

#' Load Bambu Results
#'
#' Load saved Bambu SummarizedExperiment from disk.
#'
#' @param path Path to saved RDS file
#'
#' @return SummarizedExperiment object
#' @keywords internal
load_bambu_results <- function(path) {
    require_bioc("SummarizedExperiment", "for Bambu output")

    validate_file_exists(path, "Bambu results file")
    se <- readRDS(path)

    if (!inherits(se, "SummarizedExperiment")) {
        cli::cli_abort(c(
            "File does not contain Bambu results",
            "i" = "Expected SummarizedExperiment object"
        ))
    }

    se
}
