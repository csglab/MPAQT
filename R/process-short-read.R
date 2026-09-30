# Processing: Short-read data
# Functions for processing short-read RNA-seq data with multiple input pathways

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c(
    "ec_tr_id", "count", "barcode", "cluster", "all_clusters", ".SD", ".SDcols",
    "ec_idx", "umi", "k", "weight", "n_reads", "total_reads"
))

# Valid UMI dedup modes
VALID_UMI_DEDUP_MODES <- c(
    "unique", "fractional_equal", "fractional_proportional", "bustools_count"
)

# =============================================================================
# Main API Functions (Bulk)
# =============================================================================

#' Prepare Short-Read Data for Quantification
#'
#' Process short-read data from various input types for MPAQT quantification.
#' Supports three input pathways:
#'
#' 1. **Raw FASTQ files**: Run kallisto bus alignment and extract EC counts
#' 2. **Pre-computed BUS/EC files**: Skip alignment, process existing BUS output
#' 3. **Pre-computed RDS**: Load previously saved MPAQT counts directly
#'
#' @param index An `mpaqt_index` object (bundled or with valid kallisto_index path)
#' @param fastq_1 Path to first FASTQ file (R1) for paired-end reads
#' @param fastq_2 Path to second FASTQ file (R2) for paired-end reads
#' @param bus_file Path to pre-computed BUS file (from kallisto bus)
#' @param ec_file Path to EC mapping file (matrix.ec from kallisto bus)
#' @param rds_file Path to pre-computed mpaqt_counts_sr RDS file
#' @param output_file Path to save the final RDS file (default: `output_dir/mpaqt.short_read.rds`)
#' @param keep_bus Keep intermediate kallisto/bustools files (default: FALSE).
#' @param output_dir Output directory for results (default: tempdir())
#' @param threads Number of threads for kallisto (default: 1)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return An `mpaqt_counts_sr` object (invisibly)
#'
#' @export
mpaqt_prepare_short_reads <- function(
    index,
    fastq_1 = NULL,
    fastq_2 = NULL,
    bus_file = NULL,
    ec_file = NULL,
    rds_file = NULL,
    output_file = NULL,
    keep_bus = FALSE,
    output_dir = tempdir(),
    threads = 1L,
    verbose = TRUE
) {
    validate_mpaqt_index(index)

    pathway <- detect_sr_pathway(
        fastq_1 = fastq_1,
        fastq_2 = fastq_2,
        bus_file = bus_file,
        ec_file = ec_file,
        rds_file = rds_file
    )

    if (verbose) {
        cli::cli_h1("Preparing Short-Read Data")
        cli::cli_alert_info("Pathway: {.val {pathway}}")
    }

    counts <- switch(
        pathway,
        "rds" = sr_pathway_rds(rds_file, verbose),
        "bus" = sr_pathway_bus(bus_file, ec_file, index, output_dir, verbose),
        "fastq" = sr_pathway_fastq(fastq_1, fastq_2, index, output_dir, threads, verbose)
    )

    if (pathway != "rds") {
        if (is.null(output_file)) {
            counts_file <- file.path(output_dir, "mpaqt.short_read.rds")
        } else {
            counts_file <- output_file
            dir.create(dirname(counts_file), showWarnings = FALSE, recursive = TRUE)
        }
        saveRDS(counts, counts_file)
        if (verbose) cli::cli_alert_info("Saved: {.path {counts_file}}")
    }

    if (!keep_bus && pathway %in% c("fastq", "bus")) {
        cleanup_bus_files(output_dir, verbose)
    }

    invisible(counts)
}

#' Clean Up Intermediate BUS Files
#'
#' @param output_dir Output directory containing intermediate files
#' @param verbose Print progress messages
#' @return Invisible NULL
#' @keywords internal
cleanup_bus_files <- function(output_dir, verbose = TRUE) {
    bus_files <- c(
        "output.bus",
        "output.bus.txt",
        "output.sorted.bus",
        "output.corrected.bus",
        "output.corrected.sorted.bus",
        "output.corrected.sorted.bus.txt",
        "matrix.ec",
        "transcripts.txt",
        "run_info.json",
        "t2g.tsv",
        "whitelist.txt"
    )

    count_files <- list.files(output_dir, pattern = "^output\\.counts\\.", full.names = FALSE)
    bus_files <- c(bus_files, count_files)

    files_to_remove <- file.path(output_dir, bus_files)
    existing_files <- files_to_remove[file.exists(files_to_remove)]

    if (length(existing_files) > 0) {
        file.remove(existing_files)
        if (verbose) {
            cli::cli_alert_info("Cleaned up {length(existing_files)} intermediate BUS file{?s}")
        }
    }

    invisible(NULL)
}

# =============================================================================
# Pathway Implementations (Bulk)
# =============================================================================

#' @keywords internal
sr_pathway_rds <- function(rds_file, verbose = TRUE) {
    if (verbose) cli::cli_progress_step("Loading pre-computed short-read counts")

    counts <- mpaqt_read_short_read_counts(rds_file)

    if (verbose) {
        cli::cli_progress_done()
        cli::cli_alert_success("Loaded {format(sum(counts$counts), big.mark = ',')} total reads")
        cli::cli_alert_success("{sum(counts$counts > 0)} ECs with reads")
    }

    counts
}

#' @keywords internal
sr_pathway_bus <- function(bus_file, ec_file, index, output_dir, verbose = TRUE) {
    validate_output_dir(output_dir)

    if (verbose) cli::cli_progress_step("Validating BUS/EC files")
    validate_bus_ec_compatibility(bus_file, ec_file, index)

    if (verbose) cli::cli_progress_step("Converting BUS file to text")

    bus_txt_file <- file.path(output_dir, "output.bus.txt")
    run_bustools_text(bus_file, bus_txt_file, output_dir = output_dir)

    if (verbose) cli::cli_progress_step("Extracting EC counts")

    ec_counts <- extract_bulk_ec_counts(
        bus_txt_file = bus_txt_file,
        ec_file = ec_file,
        index_ec_ids = index$ec_ids
    )

    counts <- new_mpaqt_counts_sr(
        counts = ec_counts,
        technology = "bulk",
        sample_id = basename(output_dir)
    )

    if (verbose) {
        cli::cli_progress_done()
        cli::cli_alert_success("Processed {sum(ec_counts > 0)} ECs with reads")
        cli::cli_alert_success("Total reads: {format(sum(ec_counts), big.mark = ',')}")
    }

    counts
}

#' @keywords internal
sr_pathway_fastq <- function(fastq_1, fastq_2, index, output_dir, threads, verbose = TRUE) {
    validate_output_dir(output_dir)

    kallisto_index <- get_kallisto_index_path(index, output_dir, verbose)

    if (verbose) cli::cli_progress_step("Running kallisto bus pseudoalignment")

    run_kallisto_bus(
        index_file = kallisto_index,
        fastq_files = c(fastq_1, fastq_2),
        output_dir = output_dir,
        threads = threads,
        technology = "bulk"
    )

    bus_file <- file.path(output_dir, "output.bus")
    ec_file <- file.path(output_dir, "matrix.ec")

    sr_pathway_bus(bus_file, ec_file, index, output_dir, verbose)
}

#' @keywords internal
get_kallisto_index_path <- function(index, output_dir, verbose = TRUE) {
    if (is_bundled_index(index)) {
        if (verbose) cli::cli_progress_step("Extracting Kallisto index from bundle")

        unbundled_index <- unbundle_mpaqt_index(
            index = index,
            extract_dir = output_dir,
            kallisto_filename = "kallisto.idx",
            verbose = verbose
        )

        return(unbundled_index$kallisto_index)
    }

    kallisto_index <- index$kallisto_index

    if (is.null(kallisto_index)) {
        cli::cli_abort(c(
            "Kallisto index not found in mpaqt_index",
            "i" = "Index may be bundled - check with {.fn is_bundled_index}",
            "i" = "Or the index may need to be recreated"
        ))
    }

    if (!file.exists(kallisto_index)) {
        cli::cli_abort(c(
            "Kallisto index file not found: {.path {kallisto_index}}",
            "i" = "The file may have been moved or deleted",
            "i" = "Consider using a bundled index format"
        ))
    }

    kallisto_index
}

# =============================================================================
# Single-Cell Functions
# =============================================================================

#' Prepare Single-Cell Short-Read Data
#'
#' Process single-cell short-read FASTQ files with cluster aggregation.
#' Supports optional UMI deduplication with multiple strategies.
#'
#' Pipeline (all modes):
#' \code{kallisto bus -> sort -> correct -> sort -> bustools text}
#'
#' Then branch by \code{do_umi_dedup} and \code{umi_dedup_mode}:
#'
#' \describe{
#'   \item{\code{do_umi_dedup = FALSE} (default)}{
#'     Read-level counting. Each read contributes 1 count to its EC.
#'   }
#'   \item{\code{umi_dedup_mode = "unique"}}{
#'     Collapse duplicate (barcode, UMI, EC) rows, then count rows per
#'     (barcode, EC). A UMI mapping to k distinct ECs contributes k counts
#'     (one per EC).
#'   }
#'   \item{\code{umi_dedup_mode = "fractional_equal"}}{
#'     Collapse duplicate (barcode, UMI, EC) rows, then assign each row
#'     weight = 1/k where k is the number of distinct ECs for that
#'     (barcode, UMI). Enforces mass conservation: each molecule contributes
#'     total mass = 1. Counts per (barcode, EC) are \code{sum(weight)}.
#'   }
#'   \item{\code{umi_dedup_mode = "fractional_proportional"}}{
#'     Count reads per (barcode, UMI, EC) \strong{without} deduplicating
#'     first, then assign weight = n_reads / total_reads within each
#'     molecule. Enforces mass conservation while using within-molecule
#'     read support as evidence. Counts per (barcode, EC) are
#'     \code{sum(weight)}.
#'   }
#'   \item{\code{umi_dedup_mode = "bustools_count"}}{
#'     Uses \code{bustools count} for UMI deduplication. Note: the
#'     \code{-g} flag causes \code{bustools count} to create new
#'     equivalence classes not present in \code{matrix.ec}. These are
#'     discarded with a warning. Only counts mapping to original kallisto
#'     ECs are retained.
#'   }
#' }
#'
#' @section Fractional Counts:
#' When \code{umi_dedup_mode} is \code{"fractional_equal"} or
#' \code{"fractional_proportional"}, the resulting EC counts will be
#' fractional (non-integer). Downstream code should not assume integer
#' counts. This is by design: fractional counting enforces mass
#' conservation per molecule and provides a better approximation of
#' latent assignment uncertainty, particularly at isoform-dense loci.
#'
#' @param index An `mpaqt_index` object
#' @param fastq_1 Path to first FASTQ file (contains barcode + UMI)
#' @param fastq_2 Path to second FASTQ file (contains cDNA)
#' @param clusters_file Path to cluster assignment file (barcode, cluster columns)
#' @param bus_file Path to pre-computed BUS file (optional)
#' @param ec_file Path to EC mapping file (optional)
#' @param rds_dir Directory containing pre-computed cluster RDS files (optional)
#' @param output_prefix Prefix for output RDS files (default: "mpaqt").
#' @param keep_bus Keep intermediate kallisto/bustools files (default: FALSE).
#' @param do_umi_dedup Logical (default: FALSE). If TRUE, perform UMI
#'   deduplication using the strategy specified by \code{umi_dedup_mode}.
#' @param umi_dedup_mode Character. UMI deduplication strategy (only used when
#'   \code{do_umi_dedup = TRUE}). One of:
#'   \describe{
#'     \item{\code{"fractional_proportional"}}{(default) Read-proportional
#'       fractional counting. Mass-conserving, uses within-molecule read
#'       evidence.}
#'     \item{\code{"fractional_equal"}}{Equal fractional counting.
#'       Mass-conserving, each EC gets weight 1/k.}
#'     \item{\code{"unique"}}{Simple dedup. Each unique (barcode, UMI, EC)
#'       contributes 1 count.}
#'     \item{\code{"bustools_count"}}{Dedup via \code{bustools count}. May
#'       discard counts from newly-created ECs.}
#'   }
#' @param whitelist Path to barcode whitelist file for correction (optional).
#'   If NULL (default), a whitelist is auto-generated from \code{clusters_file}.
#' @param output_dir Output directory for results
#' @param technology Technology string: "10xv2", "10xv3", or "10xv4"
#' @param threads Number of threads (default: 1)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return A list of `mpaqt_counts_sr` objects, one per cluster (invisibly)
#'
#' @export
mpaqt_prepare_short_reads_sc <- function(
    index,
    fastq_1 = NULL,
    fastq_2 = NULL,
    clusters_file,
    bus_file = NULL,
    ec_file = NULL,
    whitelist = NULL,
    rds_dir = NULL,
    output_prefix = NULL,
    keep_bus = FALSE,
    do_umi_dedup = FALSE,
    umi_dedup_mode = "fractional_proportional",
    output_dir,
    technology = "10xv3",
    threads = 1L,
    verbose = TRUE
) {
    # -------------------------------------------------------------------------
    # Validate inputs
    # -------------------------------------------------------------------------
    validate_mpaqt_index(index)
    validate_file_exists(clusters_file, "Clusters file")
    validate_technology(technology)
    validate_output_dir(output_dir)

    if (do_umi_dedup) {
        umi_dedup_mode <- match.arg(umi_dedup_mode, VALID_UMI_DEDUP_MODES)
    }

    if (is.null(output_prefix)) {
        output_prefix <- "mpaqt"
    }

    if (verbose) {
        cli::cli_h1("Preparing Single-Cell Short-Read Data")
        cli::cli_alert_info("Technology: {.val {technology}}")
        if (do_umi_dedup) {
            cli::cli_alert_info("UMI dedup: {.val {umi_dedup_mode}}")
        } else {
            cli::cli_alert_info("UMI dedup: disabled (read-level counting)")
        }
    }

    # -------------------------------------------------------------------------
    # Check for pre-computed RDS files
    # -------------------------------------------------------------------------
    if (!is.null(rds_dir) && dir.exists(rds_dir)) {
        rds_files <- list.files(rds_dir, pattern = "\\.short_read\\.rds$", full.names = TRUE)
        if (length(rds_files) > 0) {
            if (verbose) cli::cli_alert_info("Loading {length(rds_files)} pre-computed cluster files")
            counts_list <- lapply(rds_files, mpaqt_read_short_read_counts)
            names(counts_list) <- gsub("\\.short_read\\.rds$", "", basename(rds_files))
            return(invisible(counts_list))
        }
    }

    # -------------------------------------------------------------------------
    # Get kallisto index
    # -------------------------------------------------------------------------
    kallisto_index <- get_kallisto_index_path(index, output_dir, verbose)

    # -------------------------------------------------------------------------
    # Step 1: kallisto bus (pseudoalignment)
    # -------------------------------------------------------------------------
    if (is.null(bus_file) || is.null(ec_file)) {
        if (is.null(fastq_1) || is.null(fastq_2)) {
            cli::cli_abort(c(
                "No valid input provided for single-cell processing",
                "i" = "Provide FASTQ files or BUS/EC files"
            ))
        }

        if (verbose) cli::cli_progress_step("Running kallisto bus pseudoalignment")

        run_kallisto_bus(
            index_file = kallisto_index,
            fastq_files = c(fastq_1, fastq_2),
            output_dir = output_dir,
            threads = threads,
            technology = technology
        )

        bus_file <- file.path(output_dir, "output.bus")
        ec_file <- file.path(output_dir, "matrix.ec")
    }

    # -------------------------------------------------------------------------
    # Step 2: bustools sort (pre-correction)
    # -------------------------------------------------------------------------
    if (verbose) cli::cli_progress_step("Sorting BUS file")

    sorted_bus <- file.path(output_dir, "output.sorted.bus")
    run_bustools_sort(
        bus_file = bus_file,
        output_file = sorted_bus,
        threads = threads,
        output_dir = output_dir
    )

    # -------------------------------------------------------------------------
    # Step 3: bustools correct (barcode error correction)
    # -------------------------------------------------------------------------
    if (verbose) cli::cli_progress_step("Correcting barcodes")

    if (is.null(whitelist)) {
        whitelist <- file.path(output_dir, "whitelist.txt")
        generate_whitelist_from_clusters(clusters_file, whitelist)
    }
    validate_file_exists(whitelist, "Barcode whitelist")

    corrected_bus <- file.path(output_dir, "output.corrected.bus")
    run_bustools_correct(
        bus_file = sorted_bus,
        output_file = corrected_bus,
        whitelist = whitelist,
        output_dir = output_dir
    )

    # -------------------------------------------------------------------------
    # Step 4: bustools sort (post-correction)
    # -------------------------------------------------------------------------
    if (verbose) cli::cli_progress_step("Re-sorting corrected BUS file")

    corrected_sorted_bus <- file.path(output_dir, "output.corrected.sorted.bus")
    run_bustools_sort(
        bus_file = corrected_bus,
        output_file = corrected_sorted_bus,
        threads = threads,
        output_dir = output_dir
    )

    # -------------------------------------------------------------------------
    # Step 5: QC inspect
    # -------------------------------------------------------------------------
    if (verbose) {
        cli::cli_progress_step("Running QC inspection")
        run_bustools_inspect(corrected_sorted_bus, output_dir = output_dir)
    }

    # -------------------------------------------------------------------------
    # Step 6: Extract counts (branch by dedup mode)
    # -------------------------------------------------------------------------
    if (!do_umi_dedup || (do_umi_dedup && umi_dedup_mode != "bustools_count")) {
        # All non-bustools_count paths need BUS text
        if (verbose) cli::cli_progress_step("Converting corrected BUS to text")

        bus_txt_file <- file.path(output_dir, "output.corrected.sorted.bus.txt")
        run_bustools_text(corrected_sorted_bus, bus_txt_file, output_dir = output_dir)
    }

    if (!do_umi_dedup) {
        # Read-level counting (no UMI dedup)
        if (verbose) cli::cli_progress_step("Extracting read-level EC counts by cluster")

        counts_list <- extract_sc_ec_counts(
            bus_txt_file = bus_txt_file,
            ec_file = ec_file,
            clusters_file = clusters_file,
            index_ec_ids = index$ec_ids,
            output_dir = output_dir,
            output_prefix = output_prefix
        )
    } else if (umi_dedup_mode != "bustools_count") {
        # R-based UMI dedup (unique, fractional_equal, fractional_proportional)
        if (verbose) cli::cli_progress_step(
            "Extracting UMI-deduplicated EC counts ({umi_dedup_mode})"
        )

        counts_list <- extract_sc_ec_counts_dedup(
            bus_txt_file = bus_txt_file,
            ec_file = ec_file,
            clusters_file = clusters_file,
            index_ec_ids = index$ec_ids,
            output_dir = output_dir,
            output_prefix = output_prefix,
            mode = umi_dedup_mode
        )
    } else {
        # bustools count path
        txnames <- file.path(output_dir, "transcripts.txt")
        if (!file.exists(txnames)) {
            txnames <- file.path(dirname(bus_file), "transcripts.txt")
        }
        validate_file_exists(txnames, "Transcripts file")

        if (verbose) cli::cli_progress_step("Generating transcript-to-gene mapping")

        t2g_file <- file.path(output_dir, "t2g.tsv")
        generate_t2g(index, txnames, t2g_file)

        if (verbose) cli::cli_progress_step("Counting UMIs via bustools count")

        count_prefix <- file.path(output_dir, "output.counts")
        run_bustools_count(
            bus_file = corrected_sorted_bus,
            output_prefix = count_prefix,
            genemap = t2g_file,
            ecmap = ec_file,
            txnames = txnames,
            output_dir = output_dir
        )

        if (verbose) cli::cli_progress_step("Extracting EC counts from MTX")

        counts_list <- extract_sc_ec_counts_dedup_mtx(
            mtx_file = paste0(count_prefix, ".mtx"),
            barcodes_file = paste0(count_prefix, ".barcodes.txt"),
            ec_counts_file = paste0(count_prefix, ".ec.txt"),
            ec_file = ec_file,
            clusters_file = clusters_file,
            index_ec_ids = index$ec_ids,
            output_dir = output_dir,
            output_prefix = output_prefix
        )
    }

    if (verbose) {
        cli::cli_progress_done()
        dedup_suffix <- if (do_umi_dedup) paste0(" (", umi_dedup_mode, ")") else ""
        cli::cli_alert_success("Processed {length(counts_list)} clusters{dedup_suffix}")
    }

    # Clean up intermediate files if not keeping them
    if (!keep_bus) {
        cleanup_bus_files(output_dir, verbose)
    }

    invisible(counts_list)
}

# =============================================================================
# EC Count Extraction Functions
# =============================================================================

#' Extract Bulk EC Counts from BUS Output
#'
#' @param bus_txt_file Path to BUS text file
#' @param ec_file Path to matrix.ec file
#' @param index_ec_ids EC IDs from the index
#'
#' @return Named numeric vector of EC counts
#' @keywords internal
extract_bulk_ec_counts <- function(bus_txt_file, ec_file, index_ec_ids) {
    matrix_ec <- data.table::fread(
        ec_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_id", "ec_tr_id"),
        colClasses = c("integer", "character")
    )

    bus_dt <- data.table::fread(
        bus_txt_file,
        sep = "\t",
        header = FALSE,
        select = c(3, 5),
        col.names = c("ec_id", "read_id")
    )

    reads_ec_counts <- bus_dt[matrix_ec, on = "ec_id"][, .(count = .N), by = ec_tr_id]

    reads_ec_counts <- reads_ec_counts[
        data.table::data.table(ec_tr_id = index_ec_ids),
        on = "ec_tr_id"
    ]
    reads_ec_counts[is.na(count), count := 0]

    ec_counts <- reads_ec_counts$count
    names(ec_counts) <- reads_ec_counts$ec_tr_id

    stopifnot(identical(names(ec_counts), index_ec_ids))

    ec_counts
}

#' Extract Single-Cell EC Counts by Cluster (Read-Level)
#'
#' Count reads per (barcode, EC) from BUS text output, then aggregate
#' by cluster. No UMI deduplication.
#'
#' @param bus_txt_file Path to BUS text file
#' @param ec_file Path to matrix.ec file
#' @param clusters_file Path to cluster assignment file
#' @param index_ec_ids EC IDs from the index
#' @param output_dir Output directory for saving results
#' @param output_prefix Prefix for output RDS files
#'
#' @return List of mpaqt_counts_sr objects, one per cluster
#' @keywords internal
extract_sc_ec_counts <- function(
    bus_txt_file,
    ec_file,
    clusters_file,
    index_ec_ids,
    output_dir,
    output_prefix = "mpaqt"
) {
    matrix_ec <- data.table::fread(
        ec_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_id", "ec_tr_id"),
        colClasses = c("integer", "character")
    )

    bus_dt <- data.table::fread(
        bus_txt_file,
        sep = "\t",
        header = FALSE,
        select = c(1, 3, 5),
        col.names = c("barcode", "ec_id", "read_id")
    )

    reads_ec_counts <- bus_dt[matrix_ec, on = "ec_id"][
        , .(count = .N), by = .(ec_tr_id, barcode)
    ]

    aggregate_sc_counts_by_cluster(
        reads_ec_counts = reads_ec_counts,
        clusters_file = clusters_file,
        index_ec_ids = index_ec_ids,
        output_dir = output_dir,
        output_prefix = output_prefix
    )
}

#' Extract Single-Cell EC Counts with UMI Deduplication (R-based)
#'
#' Read BUS text output from the corrected+sorted BUS file and perform
#' UMI deduplication using one of three strategies. All three preserve the
#' original kallisto equivalence classes from \code{matrix.ec}.
#'
#' @param bus_txt_file Path to BUS text file
#' @param ec_file Path to matrix.ec file (0-based ec_id -> ec_tr_id mapping)
#' @param clusters_file Path to cluster assignment file
#' @param index_ec_ids EC IDs from the index
#' @param output_dir Output directory for saving results
#' @param output_prefix Prefix for output RDS files
#' @param mode Dedup strategy: \code{"unique"}, \code{"fractional_equal"},
#'   or \code{"fractional_proportional"}.
#'
#' @section Modes:
#' \describe{
#'   \item{\code{"unique"}}{
#'     Collapse duplicate (barcode, UMI, EC) rows via
#'     \code{data.table::unique()}, then count rows per (barcode, EC).
#'     A UMI mapping to k distinct ECs contributes k counts (one per EC).
#'   }
#'   \item{\code{"fractional_equal"}}{
#'     Collapse duplicate (barcode, UMI, EC) rows, then assign weight = 1/k
#'     where k = number of distinct ECs for that (barcode, UMI). Each
#'     molecule contributes total mass = 1, split equally across its ECs.
#'   }
#'   \item{\code{"fractional_proportional"}}{
#'     Count reads per (barcode, UMI, EC) \strong{without} deduplicating
#'     first. Assign weight = n_reads_ec / total_reads_molecule. Each
#'     molecule contributes total mass = 1, split proportionally to
#'     within-molecule read support per EC.
#'   }
#' }
#'
#' @return List of mpaqt_counts_sr objects, one per cluster
#' @keywords internal
extract_sc_ec_counts_dedup <- function(
    bus_txt_file,
    ec_file,
    clusters_file,
    index_ec_ids,
    output_dir,
    output_prefix = "mpaqt",
    mode = "fractional_proportional"
) {
    mode <- match.arg(mode, c("unique", "fractional_equal", "fractional_proportional"))

    # Read matrix.ec
    matrix_ec <- data.table::fread(
        ec_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_id", "ec_tr_id"),
        colClasses = c("integer", "character")
    )

    # Read bus text: barcode, UMI, EC
    # BUS text format: barcode \t UMI \t ec_id \t count [\t read_id]
    bus_dt <- data.table::fread(
        bus_txt_file,
        sep = "\t",
        header = FALSE,
        select = c(1, 2, 3),
        col.names = c("barcode", "umi", "ec_id")
    )

    if (mode == "unique") {
        # Dedup: one row per (barcode, UMI, EC), then count = .N
        bus_dt <- unique(bus_dt, by = c("barcode", "umi", "ec_id"))

        reads_ec_counts <- bus_dt[matrix_ec, on = "ec_id"][
            , .(count = .N), by = .(ec_tr_id, barcode)
        ]

    } else if (mode == "fractional_equal") {
        # Dedup first, then assign weight = 1/k per molecule
        bus_dt <- unique(bus_dt, by = c("barcode", "umi", "ec_id"))
        bus_dt[, k := data.table::uniqueN(ec_id), by = .(barcode, umi)]
        bus_dt[, weight := 1 / k]

        reads_ec_counts <- bus_dt[matrix_ec, on = "ec_id"][
            , .(count = sum(weight)), by = .(ec_tr_id, barcode)
        ]

    } else {
        # fractional_proportional: do NOT unique() first
        # Count reads per (barcode, UMI, EC)
        bus_dt_ec <- bus_dt[, .(n_reads = .N), by = .(barcode, umi, ec_id)]
        # Total reads per molecule
        bus_dt_ec[, total_reads := sum(n_reads), by = .(barcode, umi)]
        # Read-proportional weight (sums to 1 per molecule)
        bus_dt_ec[, weight := n_reads / total_reads]

        reads_ec_counts <- bus_dt_ec[matrix_ec, on = "ec_id"][
            , .(count = sum(weight)), by = .(ec_tr_id, barcode)
        ]
    }

    aggregate_sc_counts_by_cluster(
        reads_ec_counts = reads_ec_counts,
        clusters_file = clusters_file,
        index_ec_ids = index_ec_ids,
        output_dir = output_dir,
        output_prefix = output_prefix
    )
}

#' Extract Single-Cell EC Counts with UMI Dedup (bustools count MTX)
#'
#' Read the MatrixMarket output of \code{bustools count}, join back to
#' \code{matrix.ec}, and discard any ECs created by EC splitting (which
#' are not in the original kallisto index). A warning is emitted with the
#' number of discarded ECs and their total UMI count.
#'
#' @param mtx_file Path to output.counts.mtx
#' @param barcodes_file Path to output.counts.barcodes.txt
#' @param ec_counts_file Path to output.counts.ec.txt
#' @param ec_file Path to matrix.ec (original kallisto ECs)
#' @param clusters_file Path to cluster assignment file
#' @param index_ec_ids EC IDs from the index
#' @param output_dir Output directory for saving results
#' @param output_prefix Prefix for output RDS files
#'
#' @return List of mpaqt_counts_sr objects, one per cluster
#' @keywords internal
extract_sc_ec_counts_dedup_mtx <- function(
    mtx_file,
    barcodes_file,
    ec_counts_file,
    ec_file,
    clusters_file,
    index_ec_ids,
    output_dir,
    output_prefix = "mpaqt"
) {
    # -------------------------------------------------------------------------
    # Index conventions:
    #   - output.counts.ec.txt:   row N (0-indexed in file) = MTX column N+1
    #   - output.counts.mtx:      row (i) and col (j) are 1-based (MatrixMarket)
    #   - Matrix::summary(mtx):   returns 1-based i, j indices
    #   - R vectors:              1-based positional indexing
    #   - matrix.ec:              ec_id is 0-based (from kallisto bus)
    #
    # bustools count -g creates new ECs beyond matrix.ec. We join back to
    # matrix.ec and discard non-matching ECs with a warning.
    # -------------------------------------------------------------------------

    mtx <- Matrix::readMM(mtx_file)

    barcodes <- data.table::fread(
        barcodes_file, header = FALSE, col.names = "barcode"
    )$barcode

    ec_counts_map <- data.table::fread(
        ec_counts_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_idx", "ec_tr_id"),
        colClasses = c("integer", "character")
    )

    stopifnot(
        nrow(mtx) == length(barcodes),
        ncol(mtx) == nrow(ec_counts_map)
    )

    # Read original matrix.ec to get the set of valid EC indices
    matrix_ec <- data.table::fread(
        ec_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_id", "ec_tr_id"),
        colClasses = c("integer", "character")
    )
    original_ec_ids <- matrix_ec$ec_id  # 0-based integer indices

    # Convert sparse matrix to triplet form
    mtx_coo <- Matrix::summary(mtx)

    # Use ec_idx (0-based integer) for filtering, ec_tr_id for downstream
    bus_dt <- data.table::data.table(
        barcode  = barcodes[mtx_coo$i],
        ec_idx   = ec_counts_map$ec_idx[mtx_coo$j],    # 0-based EC index
        ec_tr_id = ec_counts_map$ec_tr_id[mtx_coo$j],  # transcript IDs
        count    = mtx_coo$x
    )

    # Count how many new ECs bustools count created (in the ec file, regardless of counts)
    new_ec_indices <- setdiff(ec_counts_map$ec_idx, original_ec_ids)
    n_new_ecs_total <- length(new_ec_indices)

    # Identify nonzero entries from new ECs in the sparse matrix
    is_original <- bus_dt$ec_idx %in% original_ec_ids
    n_discarded_entries <- sum(!is_original)
    discarded_umi_count <- sum(bus_dt$count[!is_original])

    if (n_new_ecs_total > 0) {
        cli::cli_warn(c(
            "bustools count -g created {n_new_ecs_total} new EC{?s} not in the original kallisto index (original: 0-{max(original_ec_ids)}, counts file: up to {max(ec_counts_map$ec_idx)})",
            "i" = "Of these, {n_discarded_entries} nonzero entr{?y/ies} ({format(discarded_umi_count, big.mark = ',')} UMI counts) were discarded",
            "i" = "Consider using umi_dedup_mode = 'fractional_proportional' to preserve all original ECs"
        ))
    }

    # Keep only original ECs, then map ec_idx -> ec_tr_id via matrix.ec
    bus_dt <- bus_dt[is_original]
    # Replace ec_tr_id from counts file with ec_tr_id from matrix.ec
    # (they should be the same for original ECs, but this ensures consistency)
    bus_dt[, ec_tr_id := NULL]
    bus_dt <- merge(bus_dt, matrix_ec, by.x = "ec_idx", by.y = "ec_id", all.x = TRUE)

    # Aggregate UMI counts per (ec_tr_id, barcode)
    reads_ec_counts <- bus_dt[, .(count = sum(count, na.rm = TRUE)),
                               by = .(ec_tr_id, barcode)]

    aggregate_sc_counts_by_cluster(
        reads_ec_counts = reads_ec_counts,
        clusters_file = clusters_file,
        index_ec_ids = index_ec_ids,
        output_dir = output_dir,
        output_prefix = output_prefix
    )
}

#' Aggregate SC Counts by Cluster
#'
#' Shared logic for all SC pipelines. Takes a data.table of
#' (ec_tr_id, barcode, count) and produces per-cluster mpaqt_counts_sr
#' objects.
#'
#' @section Fractional Counts:
#' When called from fractional dedup modes, the \code{count} column may
#' contain non-integer values. These are summed normally via
#' \code{sum(count)} and propagated into the final counts vector.
#' Downstream code should not assume integer counts.
#'
#' @param reads_ec_counts data.table with columns: ec_tr_id, barcode, count
#' @param clusters_file Path to cluster assignment file
#' @param index_ec_ids EC IDs from the index
#' @param output_dir Output directory for saving results
#' @param output_prefix Prefix for output RDS files
#'
#' @return Named list of mpaqt_counts_sr objects
#' @keywords internal
aggregate_sc_counts_by_cluster <- function(
    reads_ec_counts,
    clusters_file,
    index_ec_ids,
    output_dir,
    output_prefix = "mpaqt"
) {
    barcode_clusters <- data.table::fread(
        clusters_file,
        select = c(1, 2),
        col.names = c("barcode", "cluster")
    )
    cluster_ids <- unique(barcode_clusters$cluster)

    cli::cli_alert_info("Found {length(cluster_ids)} clusters")

    reads_ec_counts <- merge(
        reads_ec_counts,
        barcode_clusters,
        by = "barcode",
        all.y = TRUE
    )
    reads_ec_counts <- reads_ec_counts[, .(count = sum(count, na.rm = TRUE)),
                                        by = .(ec_tr_id, cluster)]

    reads_ec_wide <- data.table::dcast(
        reads_ec_counts,
        ec_tr_id ~ cluster,
        value.var = "count",
        fill = 0
    )

    reads_ec_wide[, all_clusters := rowSums(.SD), .SDcols = as.character(cluster_ids)]
    cluster_ids <- c(cluster_ids, "all_clusters")

    counts_list <- lapply(cluster_ids, function(cl) {
        cl_counts <- reads_ec_wide[, c("ec_tr_id", as.character(cl)), with = FALSE]
        data.table::setnames(cl_counts, as.character(cl), "count")

        cl_counts <- cl_counts[
            data.table::data.table(ec_tr_id = index_ec_ids),
            on = "ec_tr_id"
        ]
        cl_counts[is.na(count), count := 0]

        ec_counts <- cl_counts$count
        names(ec_counts) <- cl_counts$ec_tr_id

        stopifnot(identical(names(ec_counts), index_ec_ids))

        counts <- new_mpaqt_counts_sr(
            counts = ec_counts,
            technology = "bulk",  # Aggregated clusters treated as bulk
            sample_id = as.character(cl)
        )

        prefix_base <- basename(output_prefix)
        counts_file <- file.path(output_dir, paste0(prefix_base, ".", cl, ".short_read.rds"))
        saveRDS(counts, counts_file)

        counts
    })
    names(counts_list) <- cluster_ids

    counts_list
}

# =============================================================================
# I/O Functions
# =============================================================================

#' Load Pre-Processed Short-Read Counts
#'
#' @param path Path to the RDS file
#' @return An `mpaqt_counts_sr` object
#' @export
mpaqt_read_short_read_counts <- function(path) {
    validate_file_exists(path, "Short-read counts file")

    counts <- readRDS(path)

    if (!inherits(counts, "mpaqt_counts_sr")) {
        if (is.numeric(counts) && !is.null(names(counts))) {
            cli::cli_alert_info("Converting legacy short-read counts format")
            counts <- new_mpaqt_counts_sr(
                counts = counts,
                technology = "bulk",
                sample_id = basename(path)
            )
        } else {
            cli::cli_abort(c(
                "Invalid short-read counts file: {.path {path}}",
                "i" = "Expected mpaqt_counts_sr object or named numeric vector"
            ))
        }
    }

    counts
}

# =============================================================================
# Legacy Compatibility (Deprecated)
# =============================================================================

#' Process Short-Read FASTQ Files (Bulk)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated. Use [mpaqt_prepare_short_reads()] instead.
#'
#' @inheritParams mpaqt_prepare_short_reads
#' @return An `mpaqt_counts_sr` object (invisibly)
#' @export
#' @keywords internal
mpaqt_process_short_reads <- function(
    fastq_1,
    fastq_2,
    index,
    output_dir,
    threads = 1L
) {
    cli::cli_warn(c(
        "{.fn mpaqt_process_short_reads} is deprecated",
        "i" = "Use {.fn mpaqt_prepare_short_reads} instead"
    ))

    mpaqt_prepare_short_reads(
        index = index,
        fastq_1 = fastq_1,
        fastq_2 = fastq_2,
        output_dir = output_dir,
        threads = threads,
        verbose = TRUE
    )
}

#' Process Short-Read FASTQ Files (Single-Cell)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated. Use [mpaqt_prepare_short_reads_sc()] instead.
#'
#' @inheritParams mpaqt_prepare_short_reads_sc
#' @return A list of `mpaqt_counts_sr` objects (invisibly)
#' @export
#' @keywords internal
mpaqt_process_short_reads_sc <- function(
    fastq_1,
    fastq_2,
    index,
    clusters_file,
    output_dir,
    technology = "10xv3",
    threads = 1L
) {
    cli::cli_warn(c(
        "{.fn mpaqt_process_short_reads_sc} is deprecated",
        "i" = "Use {.fn mpaqt_prepare_short_reads_sc} instead"
    ))

    mpaqt_prepare_short_reads_sc(
        index = index,
        fastq_1 = fastq_1,
        fastq_2 = fastq_2,
        clusters_file = clusters_file,
        output_dir = output_dir,
        technology = technology,
        threads = threads,
        verbose = TRUE
    )
}
