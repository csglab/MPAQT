# S3 classes: mpaqt_counts_sr and mpaqt_counts_lr
# Store read count data from short-read and long-read processing

# =============================================================================
# Short-read counts (equivalence class level)
# =============================================================================

#' Create a new mpaqt_counts_sr object
#'
#' Internal constructor for short-read count objects.
#'
#' @param counts Named numeric vector of EC counts
#' @param technology Sequencing technology ("bulk", "10xv2", "10xv3")
#' @param sample_id Optional sample identifier
#'
#' @return An object of class `mpaqt_counts_sr`
#' @keywords internal
new_mpaqt_counts_sr <- function(counts, technology = "bulk", sample_id = NULL) {
    stopifnot(is.numeric(counts))
    stopifnot(!is.null(names(counts)))
    stopifnot(technology %in% c("bulk", "10xv2", "10xv3", "10xv4"))

    structure(
        list(
            counts = counts,
            technology = technology,
            sample_id = sample_id
        ),
        class = c("mpaqt_counts_sr", "mpaqt_counts", "list"),
        n_reads = sum(counts),
        n_ec = length(counts),
        created = Sys.time()
    )
}

#' Print method for mpaqt_counts_sr
#'
#' @param x An mpaqt_counts_sr object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible x
#' @export
print.mpaqt_counts_sr <- function(x, ...) {
    cli::cli_h1("MPAQT Short-Read Counts")
    cli::cli_text("Technology: {.val {x$technology}}")
    cli::cli_text("Total reads: {.val {format(attr(x, 'n_reads'), big.mark = ',')}}")
    cli::cli_text("Equivalence classes: {.val {attr(x, 'n_ec')}}")

    if (!is.null(x$sample_id)) {
        cli::cli_text("Sample: {.val {x$sample_id}}")
    }

    # Count distribution summary
    nonzero <- sum(x$counts > 0)
    cli::cli_text("Non-zero ECs: {.val {nonzero}} ({.val {round(100 * nonzero / attr(x, 'n_ec'), 1)}}%)")

    invisible(x)
}

#' Summary method for mpaqt_counts_sr
#'
#' @param object An mpaqt_counts_sr object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible summary list
#' @export
summary.mpaqt_counts_sr <- function(object, ...) {
    cat("Short-Read Counts Summary\n")
    cat("=========================\n\n")

    cat("Technology:", object$technology, "\n")
    if (!is.null(object$sample_id)) {
        cat("Sample ID:", object$sample_id, "\n")
    }
    cat("\n")

    cat("Read counts:\n")
    cat("  Total:", format(attr(object, "n_reads"), big.mark = ","), "\n")
    cat("  Equivalence classes:", attr(object, "n_ec"), "\n")
    cat("  Non-zero ECs:", sum(object$counts > 0), "\n")
    cat("  Zero ECs:", sum(object$counts == 0), "\n\n")

    cat("Distribution:\n")
    cat("  Min:", min(object$counts), "\n")
    cat("  Median:", median(object$counts), "\n")
    cat("  Mean:", round(mean(object$counts), 2), "\n")
    cat("  Max:", max(object$counts), "\n")

    invisible(list(
        technology = object$technology,
        sample_id = object$sample_id,
        n_reads = attr(object, "n_reads"),
        n_ec = attr(object, "n_ec"),
        n_nonzero = sum(object$counts > 0)
    ))
}

# =============================================================================
# Long-read counts (transcript level)
# =============================================================================

#' Create a new mpaqt_counts_lr object
#'
#' Internal constructor for long-read count objects.
#'
#' @param counts Named numeric vector of transcript counts
#' @param sample_id Optional sample identifier
#'
#' @return An object of class `mpaqt_counts_lr`
#' @keywords internal
new_mpaqt_counts_lr <- function(counts, sample_id = NULL) {
    stopifnot(is.numeric(counts))
    stopifnot(!is.null(names(counts)))

    structure(
        list(
            counts = counts,
            sample_id = sample_id
        ),
        class = c("mpaqt_counts_lr", "mpaqt_counts", "list"),
        n_reads = sum(counts),
        n_transcripts = length(counts),
        created = Sys.time()
    )
}

#' Print method for mpaqt_counts_lr
#'
#' @param x An mpaqt_counts_lr object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible x
#' @export
print.mpaqt_counts_lr <- function(x, ...) {
    cli::cli_h1("MPAQT Long-Read Counts")
    cli::cli_text("Total reads: {.val {format(attr(x, 'n_reads'), big.mark = ',')}}")
    cli::cli_text("Transcripts: {.val {attr(x, 'n_transcripts')}}")

    if (!is.null(x$sample_id)) {
        cli::cli_text("Sample: {.val {x$sample_id}}")
    }

    # Count distribution summary
    nonzero <- sum(x$counts > 0)
    cli::cli_text("Non-zero transcripts: {.val {nonzero}} ({.val {round(100 * nonzero / attr(x, 'n_transcripts'), 1)}}%)")

    invisible(x)
}

#' Summary method for mpaqt_counts_lr
#'
#' @param object An mpaqt_counts_lr object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible summary list
#' @export
summary.mpaqt_counts_lr <- function(object, ...) {
    cat("Long-Read Counts Summary\n")
    cat("========================\n\n")

    if (!is.null(object$sample_id)) {
        cat("Sample ID:", object$sample_id, "\n\n")
    }

    cat("Read counts:\n")
    cat("  Total:", format(attr(object, "n_reads"), big.mark = ","), "\n")
    cat("  Transcripts:", attr(object, "n_transcripts"), "\n")
    cat("  Non-zero:", sum(object$counts > 0), "\n")
    cat("  Zero:", sum(object$counts == 0), "\n\n")

    cat("Distribution:\n")
    cat("  Min:", min(object$counts), "\n")
    cat("  Median:", median(object$counts), "\n")
    cat("  Mean:", round(mean(object$counts), 2), "\n")
    cat("  Max:", max(object$counts), "\n")

    invisible(list(
        sample_id = object$sample_id,
        n_reads = attr(object, "n_reads"),
        n_transcripts = attr(object, "n_transcripts"),
        n_nonzero = sum(object$counts > 0)
    ))
}

# =============================================================================
# Common methods for mpaqt_counts
# =============================================================================

#' Get number of elements in counts object
#'
#' @param x An mpaqt_counts object
#'
#' @return Number of elements (ECs for SR, transcripts for LR)
#' @export
length.mpaqt_counts <- function(x) {
    length(x$counts)
}

#' Extract counts vector
#'
#' @param x An mpaqt_counts object
#' @param i Indices or names to extract
#' @param ... Additional arguments (unused)
#'
#' @return Numeric vector of counts
#' @export
`[.mpaqt_counts` <- function(x, i, ...) {
    x$counts[i]
}

# =============================================================================
# I/O Functions
# =============================================================================

#' Save counts to disk
#'
#' @param counts An mpaqt_counts object
#' @param path File path for the RDS file
#'
#' @return Invisible path
#' @keywords internal
save_mpaqt_counts <- function(counts, path) {
    validate_mpaqt_counts(counts)
    saveRDS(counts, path)
    invisible(path)
}

#' Load counts from disk
#'
#' @param path Path to the RDS file
#' @param type Expected type: "sr" (short-read) or "lr" (long-read) or "auto"
#'
#' @return An mpaqt_counts object
#' @export
mpaqt_read_counts <- function(path, type = "auto") {
    validate_file_exists(path, "Counts file")

    counts <- readRDS(path)

    # Handle legacy format (plain named vector)
    if (!inherits(counts, "mpaqt_counts")) {
        if (is.numeric(counts) && !is.null(names(counts))) {
            cli::cli_alert_info("Converting legacy counts format")
            counts <- convert_legacy_counts(counts, type)
        } else {
            cli::cli_abort(c(
                "Invalid counts file: {.path {path}}",
                "i" = "File does not contain valid MPAQT counts"
            ))
        }
    }

    validate_mpaqt_counts(counts)
    counts
}

#' Convert legacy counts format
#'
#' @param counts Named numeric vector
#' @param type "sr", "lr", or "auto"
#'
#' @return An mpaqt_counts object
#' @keywords internal
convert_legacy_counts <- function(counts, type = "auto") {
    # Try to auto-detect type based on naming pattern
    if (type == "auto") {
        # EC IDs typically contain commas (e.g., "0,1,2")
        has_commas <- any(grepl(",", names(counts)))
        # Transcript IDs typically start with "ENST"
        has_enst <- any(grepl("^ENST", names(counts)))

        if (has_commas && !has_enst) {
            type <- "sr"
        } else if (has_enst && !has_commas) {
            type <- "lr"
        } else {
            cli::cli_warn("Could not auto-detect counts type, assuming short-read")
            type <- "sr"
        }
    }

    if (type == "sr") {
        new_mpaqt_counts_sr(counts, technology = "bulk")
    } else {
        new_mpaqt_counts_lr(counts)
    }
}
