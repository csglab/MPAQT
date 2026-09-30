# Processing: Short-read data
# Functions for processing short-read RNA-seq data with multiple input pathways

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c(
    "ec_tr_id", "count", "barcode", "cluster", "all_clusters", ".SD", ".SDcols"
))

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
#'   When FALSE, files like `output.bus`, `output.bus.txt`, `matrix.ec`,
#'   `transcripts.txt`, and `run_info.json` are deleted after processing.
#' @param output_dir Output directory for results (default: tempdir())
#' @param threads Number of threads for kallisto (default: 1)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return An `mpaqt_counts_sr` object (invisibly)
#'
#' @details
#' The function automatically detects which pathway to use based on the
#' arguments provided:
#'
#' - If `rds_file` is provided, loads and returns the pre-computed counts
#' - If `bus_file` and `ec_file` are provided, processes existing BUS output
#' - If `fastq_1` and `fastq_2` are provided, runs the full kallisto pipeline
#'
#' For the FASTQ and BUS pathways, a bundled index will be automatically
#' unbundled to a temporary directory.
#'
#' @section Intermediate File Handling:
#' By default (`keep_bus = FALSE`), intermediate files from kallisto/bustools
#' are deleted after EC counts are extracted. Set `keep_bus = TRUE` to retain
#' these files for debugging or downstream analysis.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load index
#' idx <- mpaqt_read_index("my_index/mpaqt.index.rds")
#'
#' # Pathway A: From raw FASTQ
#' counts <- mpaqt_prepare_short_reads(
#'     index = idx,
#'     fastq_1 = "sample_R1.fastq.gz",
#'     fastq_2 = "sample_R2.fastq.gz",
#'     output_dir = "results"
#' )
#'
#' # With explicit output file and keeping BUS files
#' counts <- mpaqt_prepare_short_reads(
#'     index = idx,
#'     fastq_1 = "sample_R1.fastq.gz",
#'     fastq_2 = "sample_R2.fastq.gz",
#'     output_file = "results/my_sample.short_read.rds",
#'     keep_bus = TRUE,
#'     output_dir = "results"
#' )
#'
#' # Pathway B: From pre-computed BUS/EC
#' counts <- mpaqt_prepare_short_reads(
#'     index = idx,
#'     bus_file = "kallisto_out/output.bus",
#'     ec_file = "kallisto_out/matrix.ec",
#'     output_dir = "results"
#' )
#'
#' # Pathway C: From pre-computed RDS
#' counts <- mpaqt_prepare_short_reads(
#'     index = idx,
#'     rds_file = "previous_run/mpaqt.short_read.rds"
#' )
#' }
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
    # Validate index
    validate_mpaqt_index(index)

    # Detect pathway
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

    # Execute appropriate pathway
    counts <- switch(
        pathway,
        "rds" = sr_pathway_rds(rds_file, verbose),
        "bus" = sr_pathway_bus(bus_file, ec_file, index, output_dir, verbose),
        "fastq" = sr_pathway_fastq(fastq_1, fastq_2, index, output_dir, threads, verbose)
    )

    # Save result if not from RDS
    if (pathway != "rds") {
        # Determine output file path
        if (is.null(output_file)) {
            counts_file <- file.path(output_dir, "mpaqt.short_read.rds")
        } else {
            counts_file <- output_file
            # Ensure directory exists
            dir.create(dirname(counts_file), showWarnings = FALSE, recursive = TRUE)
        }
        saveRDS(counts, counts_file)
        if (verbose) cli::cli_alert_info("Saved: {.path {counts_file}}")
    }

    # Clean up intermediate files if not keeping them
    if (!keep_bus && pathway %in% c("fastq", "bus")) {
        cleanup_bus_files(output_dir, verbose)
    }

    invisible(counts)
}

#' Clean Up Intermediate BUS Files
#'
#' Remove intermediate kallisto/bustools files after processing.
#'
#' @param output_dir Output directory containing intermediate files
#' @param verbose Print progress messages
#'
#' @return Invisible NULL
#' @keywords internal
cleanup_bus_files <- function(output_dir, verbose = TRUE) {
    bus_files <- c(
        "output.bus",
        "output.bus.txt",
        "matrix.ec",
        "transcripts.txt",
        "run_info.json"
    )

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
# Pathway Implementations
# =============================================================================

#' Short-Read Pathway: Pre-computed RDS
#'
#' @param rds_file Path to RDS file
#' @param verbose Print progress messages
#'
#' @return mpaqt_counts_sr object
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

#' Short-Read Pathway: BUS + EC Files
#'
#' @param bus_file Path to BUS file
#' @param ec_file Path to EC file
#' @param index mpaqt_index object
#' @param output_dir Output directory
#' @param verbose Print progress messages
#'
#' @return mpaqt_counts_sr object
#' @keywords internal
sr_pathway_bus <- function(bus_file, ec_file, index, output_dir, verbose = TRUE) {
    validate_output_dir(output_dir)

    # Validate BUS/EC compatibility with index
    if (verbose) cli::cli_progress_step("Validating BUS/EC files")
    validate_bus_ec_compatibility(bus_file, ec_file, index)

    # Convert BUS to text
    if (verbose) cli::cli_progress_step("Converting BUS file to text")

    bus_txt_file <- file.path(output_dir, "output.bus.txt")
    run_bustools_text(bus_file, bus_txt_file, output_dir = output_dir)

    # Extract EC counts
    if (verbose) cli::cli_progress_step("Extracting EC counts")

    ec_counts <- extract_bulk_ec_counts(
        bus_txt_file = bus_txt_file,
        ec_file = ec_file,
        index_ec_ids = index$ec_ids
    )

    # Create counts object
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

#' Short-Read Pathway: Raw FASTQ Files
#'
#' @param fastq_1 First FASTQ file
#' @param fastq_2 Second FASTQ file
#' @param index mpaqt_index object
#' @param output_dir Output directory
#' @param threads Number of threads
#' @param verbose Print progress messages
#'
#' @return mpaqt_counts_sr object
#' @keywords internal
sr_pathway_fastq <- function(fastq_1, fastq_2, index, output_dir, threads, verbose = TRUE) {
    validate_output_dir(output_dir)

    # Get kallisto index path (unbundle if necessary)
    kallisto_index <- get_kallisto_index_path(index, output_dir, verbose)

    # Run kallisto bus
    if (verbose) cli::cli_progress_step("Running kallisto bus pseudoalignment")

    run_kallisto_bus(
        index_file = kallisto_index,
        fastq_files = c(fastq_1, fastq_2),
        output_dir = output_dir,
        threads = threads,
        technology = "bulk"
    )

    # Continue with BUS pathway
    bus_file <- file.path(output_dir, "output.bus")
    ec_file <- file.path(output_dir, "matrix.ec")

    sr_pathway_bus(bus_file, ec_file, index, output_dir, verbose)
}

#' Get Kallisto Index Path
#'
#' Extract or locate the Kallisto index from an mpaqt_index.
#' If the index is bundled, extracts to temp directory.
#'
#' @param index mpaqt_index object
#' @param output_dir Output directory for extraction
#' @param verbose Print progress messages
#'
#' @return Path to usable Kallisto index
#' @keywords internal
get_kallisto_index_path <- function(index, output_dir, verbose = TRUE) {
    # Check if bundled
    if (is_bundled_index(index)) {
        if (verbose) cli::cli_progress_step("Extracting Kallisto index from bundle")

        # Unbundle to output directory - returns modified index object
        unbundled_index <- unbundle_mpaqt_index(
            index = index,
            extract_dir = output_dir,
            kallisto_filename = "kallisto.idx",
            verbose = verbose
        )

        # Return the path from the unbundled index
        return(unbundled_index$kallisto_index)
    }

    # Not bundled - check external path
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
#' Supports multiple input pathways similar to bulk processing.
#'
#' @param index An `mpaqt_index` object
#' @param fastq_1 Path to first FASTQ file (contains barcode + UMI)
#' @param fastq_2 Path to second FASTQ file (contains cDNA)
#' @param clusters_file Path to cluster assignment file (barcode, cluster columns)
#' @param bus_file Path to pre-computed BUS file (optional)
#' @param ec_file Path to EC mapping file (optional)
#' @param rds_dir Directory containing pre-computed cluster RDS files (optional)
#' @param output_prefix Prefix for output RDS files (default: "mpaqt").
#'   Output files will be named `{output_prefix}.{cluster_id}.short_read.rds`
#' @param keep_bus Keep intermediate kallisto/bustools files (default: FALSE).
#'   When FALSE, files like `output.bus`, `output.bus.txt`, `matrix.ec`,
#'   `transcripts.txt`, and `run_info.json` are deleted after processing.
#' @param output_dir Output directory for results
#' @param technology Technology string: "10xv2", "10xv3", or "10xv4"
#' @param threads Number of threads (default: 1)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return A list of `mpaqt_counts_sr` objects, one per cluster (invisibly)
#'
#' @section Intermediate File Handling:
#' By default (`keep_bus = FALSE`), intermediate files from kallisto/bustools
#' are deleted after EC counts are extracted. Set `keep_bus = TRUE` to retain
#' these files for debugging or downstream analysis.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' idx <- mpaqt_read_index("my_index/mpaqt.index.rds")
#'
#' # From raw FASTQ
#' counts_list <- mpaqt_prepare_short_reads_sc(
#'     index = idx,
#'     fastq_1 = "sample_R1.fastq.gz",
#'     fastq_2 = "sample_R2.fastq.gz",
#'     clusters_file = "clusters.csv",
#'     output_dir = "results",
#'     technology = "10xv3"
#' )
#'
#' # With custom output prefix and keeping BUS files
#' counts_list <- mpaqt_prepare_short_reads_sc(
#'     index = idx,
#'     fastq_1 = "sample_R1.fastq.gz",
#'     fastq_2 = "sample_R2.fastq.gz",
#'     clusters_file = "clusters.csv",
#'     output_prefix = "my_sample",
#'     keep_bus = TRUE,
#'     output_dir = "results",
#'     technology = "10xv3"
#' )
#' }
mpaqt_prepare_short_reads_sc <- function(
    index,
    fastq_1 = NULL,
    fastq_2 = NULL,
    clusters_file,
    bus_file = NULL,
    ec_file = NULL,
    rds_dir = NULL,
    output_prefix = NULL,
    keep_bus = FALSE,
    output_dir,
    technology = "10xv3",
    threads = 1L,
    verbose = TRUE
) {
    # Validate inputs
    validate_mpaqt_index(index)
    validate_file_exists(clusters_file, "Clusters file")
    validate_technology(technology)
    validate_output_dir(output_dir)

    # Set default output prefix
    if (is.null(output_prefix)) {
        output_prefix <- "mpaqt"
    }

    if (verbose) {
        cli::cli_h1("Preparing Single-Cell Short-Read Data")
        cli::cli_alert_info("Technology: {.val {technology}}")
    }

    # Check for pre-computed RDS files
    if (!is.null(rds_dir) && dir.exists(rds_dir)) {
        rds_files <- list.files(rds_dir, pattern = "\\.short_read\\.rds$", full.names = TRUE)
        if (length(rds_files) > 0) {
            if (verbose) cli::cli_alert_info("Loading {length(rds_files)} pre-computed cluster files")
            counts_list <- lapply(rds_files, mpaqt_read_short_read_counts)
            names(counts_list) <- gsub("\\.short_read\\.rds$", "", basename(rds_files))
            return(invisible(counts_list))
        }
    }

    # Track whether we created BUS files (for cleanup decision)
    created_bus_files <- FALSE

    # Get kallisto index
    kallisto_index <- get_kallisto_index_path(index, output_dir, verbose)

    # Run kallisto bus if needed
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
        created_bus_files <- TRUE
    }

    # Convert BUS to text
    if (verbose) cli::cli_progress_step("Converting BUS file to text")

    bus_txt_file <- file.path(output_dir, "output.bus.txt")
    run_bustools_text(bus_file, bus_txt_file, output_dir = output_dir)

    # Extract EC counts by cluster
    if (verbose) cli::cli_progress_step("Extracting EC counts by cluster")

    counts_list <- extract_sc_ec_counts(
        bus_txt_file = bus_txt_file,
        ec_file = ec_file,
        clusters_file = clusters_file,
        index_ec_ids = index$ec_ids,
        output_dir = output_dir,
        output_prefix = output_prefix
    )

    if (verbose) {
        cli::cli_progress_done()
        cli::cli_alert_success("Processed {length(counts_list)} clusters")
    }

    # Clean up intermediate files if not keeping them
    if (!keep_bus && created_bus_files) {
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
    # Read matrix.ec (ec_tr_id must be character to match index_ec_ids)
    matrix_ec <- data.table::fread(
        ec_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_id", "ec_tr_id"),
        colClasses = c("integer", "character")
    )

    # Read bus text (EC and read ID columns)
    bus_dt <- data.table::fread(
        bus_txt_file,
        sep = "\t",
        header = FALSE,
        select = c(3, 5),
        col.names = c("ec_id", "read_id")
    )

    # Count reads per EC
    reads_ec_counts <- bus_dt[matrix_ec, on = "ec_id"][, .(count = .N), by = ec_tr_id]

    # Match to index order
    reads_ec_counts <- reads_ec_counts[
        data.table::data.table(ec_tr_id = index_ec_ids),
        on = "ec_tr_id"
    ]
    reads_ec_counts[is.na(count), count := 0]

    # Convert to named vector
    ec_counts <- reads_ec_counts$count
    names(ec_counts) <- reads_ec_counts$ec_tr_id

    stopifnot(identical(names(ec_counts), index_ec_ids))

    ec_counts
}

#' Extract Single-Cell EC Counts by Cluster
#'
#' @param bus_txt_file Path to BUS text file
#' @param ec_file Path to matrix.ec file
#' @param clusters_file Path to cluster assignment file
#' @param index_ec_ids EC IDs from the index
#' @param output_dir Output directory for saving results
#' @param output_prefix Prefix for output RDS files (default: "mpaqt")
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
    # Read matrix.ec (ec_tr_id must be character to match index_ec_ids)
    matrix_ec <- data.table::fread(
        ec_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_id", "ec_tr_id"),
        colClasses = c("integer", "character")
    )

    # Read bus text (barcode, EC, and read ID)
    bus_dt <- data.table::fread(
        bus_txt_file,
        sep = "\t",
        header = FALSE,
        select = c(1, 3, 5),
        col.names = c("barcode", "ec_id", "read_id")
    )

    # Count reads per EC and barcode
    reads_ec_counts <- bus_dt[matrix_ec, on = "ec_id"][
        , .(count = .N), by = .(ec_tr_id, barcode)
    ]

    # Read cluster assignments
    barcode_clusters <- data.table::fread(
        clusters_file,
        select = c(1, 2),
        col.names = c("barcode", "cluster")
    )
    cluster_ids <- unique(barcode_clusters$cluster)

    cli::cli_alert_info("Found {length(cluster_ids)} clusters")

    # Merge with clusters and aggregate
    reads_ec_counts <- merge(
        reads_ec_counts,
        barcode_clusters,
        by = "barcode",
        all.y = TRUE
    )
    reads_ec_counts <- reads_ec_counts[, .(count = sum(count, na.rm = TRUE)),
                                        by = .(ec_tr_id, cluster)]

    # Pivot to wide format
    reads_ec_wide <- data.table::dcast(
        reads_ec_counts,
        ec_tr_id ~ cluster,
        value.var = "count",
        fill = 0
    )

    # Add combined cluster
    reads_ec_wide[, all_clusters := rowSums(.SD), .SDcols = as.character(cluster_ids)]
    cluster_ids <- c(cluster_ids, "all_clusters")

    # Create counts object for each cluster
    counts_list <- lapply(cluster_ids, function(cl) {
        cl_counts <- reads_ec_wide[, c("ec_tr_id", as.character(cl)), with = FALSE]
        data.table::setnames(cl_counts, as.character(cl), "count")

        # Match to index order
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

        # Save (use basename of output_prefix to avoid path duplication)
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
#' Load short-read EC counts from a previously saved RDS file.
#'
#' @param path Path to the RDS file
#'
#' @return An `mpaqt_counts_sr` object
#'
#' @export
mpaqt_read_short_read_counts <- function(path) {
    validate_file_exists(path, "Short-read counts file")

    counts <- readRDS(path)

    # Handle legacy format (plain named vector)
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
#' This function is deprecated. Use [mpaqt_prepare_short_reads()] instead,
#' which supports multiple input pathways.
#'
#' @inheritParams mpaqt_prepare_short_reads
#'
#' @return An `mpaqt_counts_sr` object (invisibly)
#'
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
#'
#' @return A list of `mpaqt_counts_sr` objects (invisibly)
#'
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
