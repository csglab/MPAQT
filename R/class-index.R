# S3 class: mpaqt_index
# Stores the reference index created from transcriptome and GTF
# Supports bundling into a single portable file

#' Create a new mpaqt_index object
#'
#' Internal constructor for mpaqt_index objects. Users should use
#' `mpaqt_index()` to create indices from FASTA/GTF files.
#'
#' @param transcripts Character vector of transcript IDs
#' @param genes Character vector of gene IDs (same length as transcripts)
#' @param ec_ids Character vector of equivalence class IDs
#' @param p_matrices List of probability data.tables (one per transcript)
#' @param ec_counts Named numeric vector of EC read counts from simulation
#' @param covariates Matrix of transcript covariates
#' @param distances Data.table of distance information
#' @param t2g_matrix Sparse transcript-to-gene matrix
#' @param g2t_matrix Sparse gene-to-transcript matrix
#' @param t2g_normalized Normalized transcript-to-gene matrix
#' @param kallisto_index Path to kallisto index file (optional)
#' @param gtf_annotation GTF annotation data.table (optional, for LR workflows)
#' @param transcriptome_seqs Transcriptome sequences (optional, for LR workflows)
#' @param kallisto_binary Raw binary content of kallisto index (for bundled indices)
#'
#' @return An object of class `mpaqt_index`
#' @keywords internal
new_mpaqt_index <- function(
    transcripts,
    genes,
    ec_ids,
    p_matrices,
    ec_counts = NULL,
    covariates = NULL,
    distances = NULL,
    t2g_matrix = NULL,
    g2t_matrix = NULL,
    t2g_normalized = NULL,
    kallisto_index = NULL,
    gtf_annotation = NULL,
    transcriptome_seqs = NULL,
    kallisto_binary = NULL
) {
    stopifnot(is.character(transcripts))
    stopifnot(is.character(genes))
    stopifnot(length(genes) == length(transcripts))
    stopifnot(is.character(ec_ids))
    stopifnot(is.list(p_matrices))
    stopifnot(length(p_matrices) == length(transcripts))

    structure(
        list(
            transcripts = transcripts,
            genes = genes,
            ec_ids = ec_ids,
            p_matrices = p_matrices,
            ec_counts = ec_counts,
            covariates = covariates,
            distances = distances,
            t2g_matrix = t2g_matrix,
            g2t_matrix = g2t_matrix,
            t2g_normalized = t2g_normalized,
            kallisto_index = kallisto_index,
            gtf_annotation = gtf_annotation,
            transcriptome_seqs = transcriptome_seqs,
            kallisto_binary = kallisto_binary
        ),
        class = c("mpaqt_index", "list"),
        n_transcripts = length(transcripts),
        n_genes = length(unique(genes)),
        n_ec = length(ec_ids),
        created = Sys.time(),
        mpaqt_version = utils::packageVersion("mpaqt"),
        bundled = !is.null(kallisto_binary)
    )
}

#' Print method for mpaqt_index
#'
#' @param x An mpaqt_index object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible x
#' @export
print.mpaqt_index <- function(x, ...) {
    cli::cli_h1("MPAQT Index")
    cli::cli_text("Transcripts: {.val {attr(x, 'n_transcripts')}}")
    cli::cli_text("Genes: {.val {attr(x, 'n_genes')}}")
    cli::cli_text("Equivalence classes: {.val {attr(x, 'n_ec')}}")

    if (!is.null(x$covariates)) {
        cli::cli_text("Covariates: {.val {colnames(x$covariates)}}")
    }

    # Show bundling status
    is_bundled <- isTRUE(attr(x, "bundled"))
    if (is_bundled) {
        cli::cli_text("Format: {.emph bundled}")
    } else if (!is.null(x$kallisto_index)) {
        cli::cli_text("Kallisto index: {.path {x$kallisto_index}}")
    }

    # Show available components for LR workflows
    has_gtf <- !is.null(x$gtf_annotation)
    has_seqs <- !is.null(x$transcriptome_seqs)
    if (has_gtf || has_seqs) {
        components <- c()
        if (has_gtf) components <- c(components, "GTF")
        if (has_seqs) components <- c(components, "sequences")
        cli::cli_text("LR components: {.val {components}}")
    }

    created <- attr(x, "created")
    if (!is.null(created)) {
        cli::cli_text("Created: {.val {format(created, '%Y-%m-%d %H:%M:%S')}}")
    }

    invisible(x)
}

#' Summary method for mpaqt_index
#'
#' @param object An mpaqt_index object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible summary list
#' @export
summary.mpaqt_index <- function(object, ...) {
    cat("MPAQT Index Summary\n")
    cat("===================\n\n")

    cat("Dimensions:\n")
    cat("  Transcripts:", attr(object, "n_transcripts"), "\n")
    cat("  Genes:", attr(object, "n_genes"), "\n")
    cat("  Equivalence classes:", attr(object, "n_ec"), "\n\n")

    # P matrix statistics
    p_sizes <- vapply(object$p_matrices, nrow, integer(1))
    cat("P matrix entries per transcript:\n")
    cat("  Min:", min(p_sizes), "\n")
    cat("  Median:", median(p_sizes), "\n")
    cat("  Max:", max(p_sizes), "\n")
    cat("  Total:", sum(p_sizes), "\n\n")

    # Covariate summary
    if (!is.null(object$covariates)) {
        cat("Covariates:\n")
        for (col in colnames(object$covariates)) {
            vals <- object$covariates[, col]
            cat(sprintf("  %s: [%.2f, %.2f]\n", col, min(vals), max(vals)))
        }
    }

    invisible(list(
        n_transcripts = attr(object, "n_transcripts"),
        n_genes = attr(object, "n_genes"),
        n_ec = attr(object, "n_ec"),
        p_matrix_sizes = p_sizes
    ))
}

#' Get number of transcripts in index
#'
#' @param x An mpaqt_index object
#'
#' @return Number of transcripts
#' @export
length.mpaqt_index <- function(x) {
    attr(x, "n_transcripts")
}

#' Subset an mpaqt_index by transcript indices
#'
#' @param x An mpaqt_index object
#' @param i Transcript indices or names
#' @param ... Additional arguments (unused)
#'
#' @return A subsetted mpaqt_index object
#' @export
`[.mpaqt_index` <- function(x, i, ...) {
    if (is.character(i)) {
        i <- match(i, x$transcripts)
    }

    new_mpaqt_index(
        transcripts = x$transcripts[i],
        genes = x$genes[i],
        ec_ids = x$ec_ids,  # Keep all ECs for now
        p_matrices = x$p_matrices[i],
        ec_counts = x$ec_counts,
        covariates = if (!is.null(x$covariates)) x$covariates[i, , drop = FALSE] else NULL,
        distances = if (!is.null(x$distances)) x$distances[x$distances$tr_id %in% x$transcripts[i], ] else NULL,
        t2g_matrix = if (!is.null(x$t2g_matrix)) x$t2g_matrix[i, , drop = FALSE] else NULL,
        g2t_matrix = x$g2t_matrix,
        t2g_normalized = if (!is.null(x$t2g_normalized)) x$t2g_normalized[i, , drop = FALSE] else NULL,
        kallisto_index = x$kallisto_index
    )
}

#' Save mpaqt_index to disk
#'
#' @param index An mpaqt_index object
#' @param path File path for the RDS file
#'
#' @return Invisible path
#' @keywords internal
save_mpaqt_index <- function(index, path) {
    validate_mpaqt_index(index)
    saveRDS(index, path)
    invisible(path)
}

# Note: mpaqt_read_index is defined in api-index.R with the main API

#' Convert legacy index format to new format
#'
#' @param legacy_index List in legacy format
#'
#' @return An mpaqt_index object
#' @keywords internal
convert_legacy_index <- function(legacy_index) {
    new_mpaqt_index(
        transcripts = legacy_index$I,
        genes = legacy_index$G,
        ec_ids = legacy_index$E,
        p_matrices = legacy_index$P,
        ec_counts = legacy_index$N,
        covariates = legacy_index$C,
        distances = legacy_index$D,
        t2g_matrix = legacy_index$T2G,
        g2t_matrix = legacy_index$G2T,
        t2g_normalized = legacy_index$T2Gn,
        kallisto_index = NULL
    )
}

# =============================================================================
# Index Bundling Functions
# =============================================================================

#' Bundle MPAQT Index into Single Portable File
#'
#' Creates a single compressed file containing all index components including
#' the Kallisto index binary. This makes the index fully portable and
#' self-contained.
#'
#' @param index mpaqt_index object to bundle
#' @param kallisto_index_path Path to Kallisto index file to embed
#' @param gtf_annotation Optional GTF annotation data.table (for LR workflows)
#' @param transcriptome_seqs Optional transcriptome sequences (for LR workflows)
#' @param output_file Output file path (should end in .mpaqt.idx or .rds)
#' @param compress Compression method: "xz" (default, smaller), "gzip" (faster),
#'   "bzip2", or FALSE
#' @param verbose Print progress messages
#'
#' @return Invisible path to output file
#'
#' @details
#' The bundled index includes:
#' - All MPAQT index metadata (P matrices, covariates, T2G mappings)
#' - The Kallisto index as embedded binary data
#' - Optional GTF annotation and transcriptome sequences for long-read workflows
#'
#' Use `unbundle_mpaqt_index()` to extract the Kallisto index before use.
#'
#' @keywords internal
bundle_mpaqt_index <- function(
    index,
    kallisto_index_path,
    gtf_annotation = NULL,
    transcriptome_seqs = NULL,
    output_file,
    compress = "gzip",  # gzip is much faster than xz with good compression
    verbose = TRUE
) {
    validate_mpaqt_index(index)
    validate_file_exists(kallisto_index_path, "Kallisto index")

    if (verbose) cli::cli_progress_step("Reading Kallisto index binary")

    # Read Kallisto index as raw binary
    kallisto_binary <- readBin(
        kallisto_index_path,
        what = "raw",
        n = file.size(kallisto_index_path)
    )

    if (verbose) {
        size_mb <- round(length(kallisto_binary) / 1024 / 1024, 1)
        cli::cli_alert_info("Kallisto index size: {.val {size_mb}} MB")
    }

    # Process transcriptome sequences if DNAStringSet
    if (!is.null(transcriptome_seqs)) {
        if (inherits(transcriptome_seqs, "DNAStringSet")) {
            # Convert to character vector for storage
            transcriptome_seqs <- stats::setNames(
                as.character(transcriptome_seqs),
                names(transcriptome_seqs)
            )
        }
    }

    if (verbose) cli::cli_progress_step("Creating bundled index")

    # Create new index with embedded components
    bundled <- new_mpaqt_index(
        transcripts = index$transcripts,
        genes = index$genes,
        ec_ids = index$ec_ids,
        p_matrices = index$p_matrices,
        ec_counts = index$ec_counts,
        covariates = index$covariates,
        distances = index$distances,
        t2g_matrix = index$t2g_matrix,
        g2t_matrix = index$g2t_matrix,
        t2g_normalized = index$t2g_normalized,
        kallisto_index = NULL,  # Path not needed for bundled
        gtf_annotation = gtf_annotation,
        transcriptome_seqs = transcriptome_seqs,
        kallisto_binary = kallisto_binary
    )

    if (verbose) cli::cli_progress_step("Saving bundled index")

    # Save with compression
    saveRDS(bundled, output_file, compress = compress)

    if (verbose) {
        final_size_mb <- round(file.size(output_file) / 1024 / 1024, 1)
        cli::cli_progress_done()
        cli::cli_alert_success("Bundled index saved: {.path {output_file}}")
        cli::cli_alert_info("Final size: {.val {final_size_mb}} MB")
    }

    invisible(output_file)
}

#' Unbundle MPAQT Index
#'
#' Extracts the Kallisto index from a bundled MPAQT index file so it can be
#' used with kallisto commands.
#'
#' @param index Bundled mpaqt_index object or path to bundled index file
#' @param extract_dir Directory to extract Kallisto index to (default: tempdir())
#' @param kallisto_filename Filename for extracted Kallisto index
#'   (default: "mpaqt.kallisto.idx")
#' @param verbose Print progress messages
#'
#' @return mpaqt_index object with `kallisto_index` path set to extracted file.
#'   The `kallisto_binary` field is removed to free memory.
#'
#' @details
#' If the index is already unbundled (has a valid `kallisto_index` path and no
#' `kallisto_binary`), it is returned unchanged.
#'
#' The extracted Kallisto index is written to `extract_dir` and the returned
#' index object has its `kallisto_index` field updated to point to this file.
#'
#' @keywords internal
unbundle_mpaqt_index <- function(
    index,
    extract_dir = tempdir(),
    kallisto_filename = "mpaqt.kallisto.idx",
    verbose = FALSE
) {
    # Load if path provided
    if (is.character(index)) {
        if (verbose) cli::cli_progress_step("Loading bundled index")
        index <- readRDS(index)
    }

    validate_mpaqt_index(index)

    # Check if already unbundled
    if (is.null(index$kallisto_binary)) {
        if (!is.null(index$kallisto_index) && file.exists(index$kallisto_index)) {
            if (verbose) cli::cli_alert_info("Index already unbundled")
            return(index)
        }

        # No binary and no valid path - check if this is an old-style index
        if (!is.null(index$kallisto_index)) {
            cli::cli_warn(c(
                "Kallisto index file not found: {.path {index$kallisto_index}}",
                "i" = "The index may have been moved or deleted"
            ))
        }

        return(index)
    }

    # Create extract directory if needed
    if (!dir.exists(extract_dir)) {
        dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
    }

    # Extract Kallisto index
    kallisto_path <- file.path(extract_dir, kallisto_filename)

    if (verbose) cli::cli_progress_step("Extracting Kallisto index")

    writeBin(index$kallisto_binary, kallisto_path)

    if (verbose) {
        size_mb <- round(file.size(kallisto_path) / 1024 / 1024, 1)
        cli::cli_alert_success("Extracted: {.path {kallisto_path}} ({size_mb} MB)")
    }

    # Update index with extracted path and clear binary to free memory
    index$kallisto_index <- kallisto_path
    index$kallisto_binary <- NULL
    attr(index, "bundled") <- FALSE

    index
}

#' Check if Index is Bundled
#'
#' @param index mpaqt_index object
#'
#' @return TRUE if index contains embedded Kallisto binary, FALSE otherwise
#' @keywords internal
is_bundled_index <- function(index) {
    isTRUE(attr(index, "bundled")) || !is.null(index$kallisto_binary)
}

#' Write Transcriptome from Index to FASTA File
#'
#' Extracts embedded transcriptome sequences from a bundled index and writes
#' them to a FASTA file. Required for long-read workflows.
#'
#' @param index mpaqt_index object with transcriptome_seqs
#' @param output_path Path for output FASTA file
#' @param verbose Print progress messages
#'
#' @return Invisible output path
#' @keywords internal
write_transcriptome_from_index <- function(index, output_path, verbose = FALSE) {
    if (is.null(index$transcriptome_seqs)) {
        cli::cli_abort(c(
            "Index does not contain transcriptome sequences",
            "i" = "This index cannot be used for FLNC long-read processing",
            "i" = "Recreate index with {.arg genome} or {.arg transcriptome} parameter"
        ))
    }

    require_bioc("Biostrings", "to write FASTA file")

    if (verbose) cli::cli_progress_step("Writing transcriptome FASTA")

    # Convert to DNAStringSet if needed
    if (is.character(index$transcriptome_seqs)) {
        seqs <- Biostrings::DNAStringSet(index$transcriptome_seqs)
    } else {
        seqs <- index$transcriptome_seqs
    }

    Biostrings::writeXStringSet(seqs, output_path)

    if (verbose) {
        cli::cli_alert_success("Written: {.path {output_path}}")
    }

    invisible(output_path)
}

#' Write GTF from Index to File
#'
#' Extracts embedded GTF annotation from a bundled index and writes it to file.
#' Required for long-read Bambu workflows.
#'
#' @param index mpaqt_index object with gtf_annotation
#' @param output_path Path for output GTF file
#' @param verbose Print progress messages
#'
#' @return Invisible output path
#' @keywords internal
write_gtf_from_index <- function(index, output_path, verbose = FALSE) {
    if (is.null(index$gtf_annotation)) {
        cli::cli_abort(c(
            "Index does not contain GTF annotation",
            "i" = "This index cannot be used for FLNC long-read processing",
            "i" = "Recreate index with GTF annotation"
        ))
    }

    if (verbose) cli::cli_progress_step("Writing GTF annotation")

    # The gtf_annotation is stored as a data.table
    # Convert back to GRanges and export
    require_bioc("rtracklayer", "to write GTF file")

    gtf_dt <- index$gtf_annotation

    # Convert data.table to GRanges
    gr <- GenomicRanges::GRanges(
        seqnames = gtf_dt$seqnames,
        ranges = IRanges::IRanges(start = gtf_dt$start, end = gtf_dt$end),
        strand = gtf_dt$strand
    )

    # Add metadata columns
    meta_cols <- setdiff(names(gtf_dt), c("seqnames", "start", "end", "width", "strand"))
    for (col in meta_cols) {
        GenomicRanges::mcols(gr)[[col]] <- gtf_dt[[col]]
    }

    rtracklayer::export(gr, output_path, format = "gtf")

    if (verbose) {
        cli::cli_alert_success("Written: {.path {output_path}}")
    }

    invisible(output_path)
}
