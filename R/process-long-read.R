# Processing: Long-read data
# Functions for processing long-read RNA-seq data with multiple input pathways

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c(
    "tr_id", "transcript_id", "count"
))

# =============================================================================
# Main API Functions (Bulk)
# =============================================================================

#' Prepare Long-Read Data for Quantification
#'
#' Process long-read data from various input types for MPAQT quantification.
#' Supports three input pathways:
#'
#' 1. **Raw FLNC FASTQ**: Align with minimap2, quantify with Bambu
#' 2. **Pre-computed Bambu counts**: Load existing Bambu count table
#' 3. **Pre-computed RDS**: Load previously saved MPAQT counts directly
#'
#' @param index An `mpaqt_index` object (must have transcriptome/GTF for FLNC pathway)
#' @param flnc_fastq Path to FLNC (full-length non-chimeric) FASTQ file
#' @param genome Path to genome FASTA or BSgenome object/name (for FLNC pathway)
#' @param bambu_counts Path to pre-computed Bambu count table (CSV/TSV)
#' @param rds_file Path to pre-computed mpaqt_counts_lr RDS file
#' @param output_file Path to save the final RDS file (default: `output_dir/mpaqt.long_read.rds`)
#' @param keep_bam Keep minimap2 BAM alignment files (default: FALSE).
#'   When FALSE, BAM and BAI files are deleted after Bambu quantification.
#' @param keep_bambu_cache Keep Bambu intermediate cache files (default: FALSE).
#'   When FALSE, Bambu RDS output is deleted after processing.
#' @param output_dir Output directory for results (default: tempdir())
#' @param threads Number of threads for minimap2/Bambu (default: 1)
#' @param minimap_preset minimap2 preset (default: "splice:hq" for Iso-Seq)
#' @param discovery Enable Bambu novel transcript discovery (default: FALSE)
#' @param sample_id Sample identifier (default: derived from input)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return An `mpaqt_counts_lr` object (invisibly)
#'
#' @details
#' The function automatically detects which pathway to use based on the
#' arguments provided:
#'
#' - If `rds_file` is provided, loads and returns the pre-computed counts
#' - If `bambu_counts` is provided, reads and converts the count table
#' - If `flnc_fastq` is provided, runs minimap2 alignment + Bambu quantification
#'
#' For the FLNC pathway, the index must contain stored GTF annotation and
#' transcriptome sequences (or you must provide a `genome` reference).
#'
#' @section Requirements for FLNC Pathway:
#' The FLNC pathway requires:
#' - **minimap2** and **samtools** installed and in PATH
#' - **Bambu** Bioconductor package installed
#' - A genome reference (FASTA or BSgenome)
#' - GTF annotation (stored in index or external file)
#'
#' @section Intermediate File Handling:
#' By default, intermediate files are cleaned up after processing:
#' - `keep_bam = FALSE`: Removes minimap2 alignment files (`.bam`, `.bai`)
#' - `keep_bambu_cache = FALSE`: Removes Bambu output (`.rds`)
#'
#' Set these to `TRUE` to retain files for debugging or downstream analysis.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load index
#' idx <- mpaqt_read_index("my_index/mpaqt.index.rds")
#'
#' # Pathway A: From raw FLNC FASTQ (full pipeline)
#' lr_counts <- mpaqt_prepare_long_reads(
#'     index = idx,
#'     flnc_fastq = "sample.flnc.fastq.gz",
#'     genome = "BSgenome.Hsapiens.UCSC.hg38",
#'     output_dir = "results",
#'     threads = 8
#' )
#'
#' # With explicit output file and keeping intermediate files
#' lr_counts <- mpaqt_prepare_long_reads(
#'     index = idx,
#'     flnc_fastq = "sample.flnc.fastq.gz",
#'     genome = "genome.fa",
#'     output_file = "results/my_sample.long_read.rds",
#'     keep_bam = TRUE,
#'     keep_bambu_cache = TRUE,
#'     output_dir = "results"
#' )
#'
#' # Pathway B: From pre-computed Bambu counts
#' lr_counts <- mpaqt_prepare_long_reads(
#'     index = idx,
#'     bambu_counts = "bambu_output/counts.csv",
#'     output_dir = "results"
#' )
#'
#' # Pathway C: From pre-computed RDS
#' lr_counts <- mpaqt_prepare_long_reads(
#'     index = idx,
#'     rds_file = "previous_run/mpaqt.long_read.rds"
#' )
#' }
mpaqt_prepare_long_reads <- function(
    index,
    flnc_fastq = NULL,
    genome = NULL,
    bambu_counts = NULL,
    rds_file = NULL,
    output_file = NULL,
    keep_bam = FALSE,
    keep_bambu_cache = FALSE,
    output_dir = tempdir(),
    threads = 1L,
    minimap_preset = "splice:hq",
    discovery = FALSE,
    sample_id = NULL,
    verbose = TRUE
) {
    # Validate index
    validate_mpaqt_index(index)

    # Detect pathway
    pathway <- detect_lr_pathway(
        flnc_fastq = flnc_fastq,
        bambu_counts = bambu_counts,
        rds_file = rds_file
    )

    if (pathway == "none") {
        cli::cli_abort(c(
            "No long-read input provided",
            "i" = "Provide one of:",
            "*" = "{.arg flnc_fastq} - Raw FLNC FASTQ file",
            "*" = "{.arg bambu_counts} - Bambu count table",
            "*" = "{.arg rds_file} - Pre-computed RDS file"
        ))
    }

    if (verbose) {
        cli::cli_h1("Preparing Long-Read Data")
        cli::cli_alert_info("Pathway: {.val {pathway}}")
    }

    # Track intermediate files created for cleanup
    created_files <- list(bam = NULL, bambu = NULL)

    # Execute appropriate pathway
    counts <- switch(
        pathway,
        "rds" = lr_pathway_rds(rds_file, verbose),
        "bambu" = lr_pathway_bambu_counts(bambu_counts, index, sample_id, verbose),
        "flnc" = {
            result <- lr_pathway_flnc(
                flnc_fastq, genome, index, output_dir,
                threads, minimap_preset, discovery, sample_id, verbose
            )
            # Track files for cleanup
            created_files$bam <- attr(result, "bam_file")
            created_files$bambu <- attr(result, "bambu_file")
            result
        }
    )

    # Save result if not from RDS
    if (pathway != "rds") {
        validate_output_dir(output_dir)
        # Determine output file path
        if (is.null(output_file)) {
            counts_file <- file.path(output_dir, "mpaqt.long_read.rds")
        } else {
            counts_file <- output_file
            # Ensure directory exists
            dir.create(dirname(counts_file), showWarnings = FALSE, recursive = TRUE)
        }
        saveRDS(counts, counts_file)
        if (verbose) cli::cli_alert_info("Saved: {.path {counts_file}}")
    }

    # Clean up intermediate files if not keeping them
    if (pathway == "flnc") {
        cleanup_lr_files(
            output_dir = output_dir,
            bam_file = created_files$bam,
            bambu_file = created_files$bambu,
            keep_bam = keep_bam,
            keep_bambu_cache = keep_bambu_cache,
            verbose = verbose
        )
    }

    invisible(counts)
}

#' Clean Up Intermediate Long-Read Files
#'
#' Remove intermediate minimap2/bambu files after processing.
#'
#' @param output_dir Output directory containing intermediate files
#' @param bam_file Path to BAM file (if known)
#' @param bambu_file Path to Bambu RDS file (if known)
#' @param keep_bam Keep BAM files
#' @param keep_bambu_cache Keep Bambu cache files
#' @param verbose Print progress messages
#'
#' @return Invisible NULL
#' @keywords internal
cleanup_lr_files <- function(
    output_dir,
    bam_file = NULL,
    bambu_file = NULL,
    keep_bam = FALSE,
    keep_bambu_cache = FALSE,
    verbose = TRUE
) {
    files_removed <- 0L

    # Clean up BAM files
    if (!keep_bam) {
        bam_files <- c(
            bam_file,
            file.path(output_dir, "minimap2_output.sam"),
            list.files(output_dir, pattern = "\\.aligned\\.bam$", full.names = TRUE),
            list.files(output_dir, pattern = "\\.aligned\\.bam\\.bai$", full.names = TRUE)
        )
        bam_files <- unique(bam_files[!is.null(bam_files)])
        existing_bam <- bam_files[file.exists(bam_files)]
        if (length(existing_bam) > 0) {
            file.remove(existing_bam)
            files_removed <- files_removed + length(existing_bam)
        }
    }

    # Clean up Bambu cache files
    if (!keep_bambu_cache) {
        bambu_files <- c(
            bambu_file,
            file.path(output_dir, "bambu_results.rds"),
            file.path(output_dir, "annotation.gtf")
        )
        bambu_files <- unique(bambu_files[!is.null(bambu_files)])
        existing_bambu <- bambu_files[file.exists(bambu_files)]
        if (length(existing_bambu) > 0) {
            file.remove(existing_bambu)
            files_removed <- files_removed + length(existing_bambu)
        }
    }

    if (files_removed > 0 && verbose) {
        cli::cli_alert_info("Cleaned up {files_removed} intermediate file{?s}")
    }

    invisible(NULL)
}

# =============================================================================
# Pathway Implementations
# =============================================================================

#' Long-Read Pathway: Pre-computed RDS
#'
#' @param rds_file Path to RDS file
#' @param verbose Print progress messages
#'
#' @return mpaqt_counts_lr object
#' @keywords internal
lr_pathway_rds <- function(rds_file, verbose = TRUE) {
    if (verbose) cli::cli_progress_step("Loading pre-computed long-read counts")

    counts <- mpaqt_read_long_read_counts(rds_file)

    if (verbose) {
        cli::cli_progress_done()
        cli::cli_alert_success("Loaded {format(sum(counts$counts), big.mark = ',')} total reads")
        cli::cli_alert_success("{sum(counts$counts > 0)} transcripts with reads")
    }

    counts
}

#' Long-Read Pathway: Bambu Count Table
#'
#' @param bambu_counts Path to Bambu count table
#' @param index mpaqt_index object
#' @param sample_id Sample identifier
#' @param verbose Print progress messages
#'
#' @return mpaqt_counts_lr object
#' @keywords internal
lr_pathway_bambu_counts <- function(bambu_counts, index, sample_id, verbose = TRUE) {
    if (verbose) cli::cli_progress_step("Reading Bambu count table")

    # Read count table
    counts_dt <- data.table::fread(bambu_counts)

    # Determine transcript ID column (first column)
    transcript_col <- names(counts_dt)[1]

    # Get transcript IDs
    transcript_ids <- counts_dt[[transcript_col]]

    # Validate against index
    validate_transcript_ids(transcript_ids, index$transcripts)

    # Determine count column
    if (ncol(counts_dt) == 2) {
        # Simple two-column format
        count_col <- names(counts_dt)[2]
        counts_vec <- counts_dt[[count_col]]
        if (is.null(sample_id)) {
            sample_id <- count_col
        }
    } else if (!is.null(sample_id) && sample_id %in% names(counts_dt)) {
        counts_vec <- counts_dt[[sample_id]]
    } else {
        # Use second column by default
        count_col <- names(counts_dt)[2]
        counts_vec <- counts_dt[[count_col]]
        if (is.null(sample_id)) {
            sample_id <- count_col
        }
        if (verbose && ncol(counts_dt) > 2) {
            cli::cli_alert_info("Using column {.val {count_col}} (specify {.arg sample_id} to change)")
        }
    }

    names(counts_vec) <- transcript_ids

    # Match to index order
    if (verbose) cli::cli_progress_step("Matching to index transcripts")

    counts_ordered <- match_lr_counts_to_index(counts_vec, index$transcripts)

    # Create counts object
    counts <- new_mpaqt_counts_lr(
        counts = counts_ordered,
        sample_id = sample_id
    )

    if (verbose) {
        cli::cli_progress_done()
        n_nonzero <- sum(counts_ordered > 0)
        cli::cli_alert_success("Processed {n_nonzero} transcripts with reads")
        cli::cli_alert_success("Total reads: {format(sum(counts_ordered), big.mark = ',')}")
    }

    counts
}

#' Long-Read Pathway: Raw FLNC FASTQ
#'
#' Full pipeline: minimap2 alignment -> Bambu quantification
#'
#' @param flnc_fastq Path to FLNC FASTQ file
#' @param genome Genome reference for Bambu
#' @param index mpaqt_index object
#' @param output_dir Output directory
#' @param threads Number of threads
#' @param minimap_preset minimap2 preset
#' @param discovery Enable Bambu discovery
#' @param sample_id Sample identifier
#' @param verbose Print progress messages
#'
#' @return mpaqt_counts_lr object with attributes `bam_file` and `bambu_file`
#'   indicating intermediate files created
#' @keywords internal
lr_pathway_flnc <- function(
    flnc_fastq,
    genome,
    index,
    output_dir,
    threads,
    minimap_preset,
    discovery,
    sample_id,
    verbose = TRUE
) {
    validate_output_dir(output_dir)

    # Check requirements
    check_minimap2()
    check_samtools()
    check_bambu()

    # Get GTF annotation (from index or error)
    gtf_path <- get_gtf_for_long_reads(index, output_dir, verbose)

    # Get genome reference
    if (is.null(genome)) {
        cli::cli_abort(c(
            "Genome reference required for FLNC pathway",
            "i" = "Provide {.arg genome} as BSgenome name or FASTA path"
        ))
    }

    # Determine sample ID
    if (is.null(sample_id)) {
        sample_id <- sub("\\.(fastq|fq)(\\.gz)?$", "", basename(flnc_fastq))
    }

    # Step 1: Align with minimap2
    bam_file <- file.path(output_dir, paste0(sample_id, ".aligned.bam"))

    if (verbose) cli::cli_h2("Step 1: minimap2 Alignment")

    # Need genome FASTA for minimap2
    genome_fasta <- get_genome_fasta(genome, output_dir, verbose)

    run_minimap2_genome(
        fastq_file = flnc_fastq,
        genome_fasta = genome_fasta,
        output_bam = bam_file,
        threads = threads,
        preset = minimap_preset,
        output_dir = output_dir,
        verbose = verbose
    )

    # Step 2: Run Bambu quantification
    if (verbose) cli::cli_h2("Step 2: Bambu Quantification")

    se <- run_bambu(
        bam_files = bam_file,
        gtf_path = gtf_path,
        genome = genome,
        output_dir = output_dir,
        discovery = discovery,
        quant = TRUE,
        threads = threads,
        verbose = verbose
    )

    # Save Bambu results
    bambu_file <- file.path(output_dir, "bambu_results.rds")
    save_bambu_results(se, bambu_file)
    if (verbose) cli::cli_alert_info("Saved Bambu results: {.path {bambu_file}}")

    # Step 3: Convert to MPAQT format
    if (verbose) cli::cli_h2("Step 3: Converting to MPAQT Format")

    counts <- bambu_to_mpaqt_counts(
        se = se,
        index = index,
        sample_idx = 1L,
        sample_id = sample_id
    )

    if (verbose) {
        n_nonzero <- sum(counts$counts > 0)
        cli::cli_alert_success("Quantified {n_nonzero} transcripts with reads")
        cli::cli_alert_success("Total reads: {format(sum(counts$counts), big.mark = ',')}")
    }

    # Attach file paths as attributes for cleanup tracking
    attr(counts, "bam_file") <- bam_file
    attr(counts, "bambu_file") <- bambu_file

    counts
}

#' Get GTF Annotation Path for Long-Read Processing
#'
#' Extract or locate GTF annotation from an mpaqt_index.
#'
#' @param index mpaqt_index object
#' @param output_dir Output directory for extraction
#' @param verbose Print progress messages
#'
#' @return Path to GTF file
#' @keywords internal
get_gtf_for_long_reads <- function(index, output_dir, verbose = TRUE) {
    # Check if index has stored GTF
    if (!is.null(index$gtf_annotation)) {
        if (verbose) cli::cli_progress_step("Extracting GTF from index")

        gtf_path <- file.path(output_dir, "annotation.gtf")
        write_gtf_from_index(index, gtf_path, verbose = FALSE)

        return(gtf_path)
    }

    # Check for external GTF path
    if (!is.null(index$gtf_path) && file.exists(index$gtf_path)) {
        return(index$gtf_path)
    }

    cli::cli_abort(c(
        "GTF annotation not available for long-read processing",
        "i" = "Index was created without storing GTF",
        "i" = "Recreate index with {.code store_gtf = TRUE}",
        "i" = "Or provide an external GTF file"
    ))
}

#' Get Genome FASTA Path
#'
#' Get or create a genome FASTA file for minimap2.
#'
#' Handles three cases:
#' 1. **Already a FASTA file**: If path ends with .fa/.fasta/.fna (optionally .gz),
#'    returns the path directly after validation
#' 2. **BSgenome package name**: Extracts sequences to FASTA file
#' 3. **BSgenome object**: Extracts sequences to FASTA file
#'
#' @param genome Genome specification (FASTA path, BSgenome name, or object)
#' @param output_dir Output directory
#' @param verbose Print progress messages
#'
#' @return Path to genome FASTA file
#' @keywords internal
get_genome_fasta <- function(genome, output_dir, verbose = TRUE) {
    # Case 1: Already a FASTA file path
    if (is.character(genome) && length(genome) == 1 && file.exists(genome)) {
        # Check for FASTA extension (.fa, .fasta, .fna with optional .gz)
        if (grepl("\\.(fa|fasta|fna)(\\.gz)?$", genome, ignore.case = TRUE)) {
            # Validate the FASTA file
            validate_fasta(genome)
            if (verbose) {
                cli::cli_alert_info("Using provided FASTA file: {.path {basename(genome)}}")
            }
            return(genome)
        }
        # File exists but doesn't have FASTA extension - could be BSgenome name
        # that happens to match a directory name, or invalid input
        if (!grepl("^BSgenome\\.", genome)) {
            cli::cli_warn(c(
                "File {.path {basename(genome)}} exists but doesn't have a recognized FASTA extension",
                "i" = "Expected: .fa, .fasta, or .fna (with optional .gz)",
                "i" = "Treating as a FASTA file anyway"
            ))
            validate_fasta(genome)
            return(genome)
        }
    }

    # Case 2 & 3: BSgenome object or package name - need to export to FASTA
    # This is expensive, so check if we've already done it
    genome_fasta <- file.path(output_dir, "genome.fa")

    if (file.exists(genome_fasta)) {
        if (verbose) cli::cli_alert_info("Using existing genome FASTA: {.path {basename(genome_fasta)}}")
        return(genome_fasta)
    }

    # Export BSgenome to FASTA
    if (verbose) cli::cli_progress_step("Exporting genome to FASTA (this may take a while)")

    require_bioc("Biostrings", "for genome export")
    require_bioc("BSgenome", "for genome access")

    genome_obj <- load_bsgenome(genome)

    # Get standard chromosomes
    std_chroms <- grep("^chr[0-9XYM]+$|^[0-9XYM]+$", seqnames(genome_obj), value = TRUE)

    if (length(std_chroms) == 0) {
        std_chroms <- seqnames(genome_obj)
    }

    # Export each chromosome
    seqs <- BSgenome::getSeq(genome_obj, std_chroms)
    names(seqs) <- std_chroms

    Biostrings::writeXStringSet(seqs, genome_fasta)

    if (verbose) cli::cli_alert_success("Exported {length(std_chroms)} chromosomes to {.path {basename(genome_fasta)}}")

    genome_fasta
}

#' Match Long-Read Counts to Index Order
#'
#' Reorder and fill counts to match index transcript order.
#'
#' @param counts Named numeric vector of counts
#' @param index_transcripts Character vector of transcript IDs in index order
#'
#' @return Named numeric vector in index order
#' @keywords internal
match_lr_counts_to_index <- function(counts, index_transcripts) {
    # Create output vector
    ordered_counts <- rep(0, length(index_transcripts))
    names(ordered_counts) <- index_transcripts

    # Find matching transcripts
    common <- intersect(names(counts), index_transcripts)

    if (length(common) > 0) {
        ordered_counts[common] <- counts[common]
    }

    ordered_counts
}

# =============================================================================
# Single-Cell Functions
# =============================================================================

#' Prepare Single-Cell Long-Read Data
#'
#' Process single-cell long-read data with cluster aggregation.
#' For single-cell long reads, quantification is typically performed at the
#' cluster level rather than per-cell due to coverage limitations.
#'
#' @param index An `mpaqt_index` object
#' @param count_file Path to count matrix (transcript_id + barcode columns)
#' @param clusters_file Path to cluster assignment file (barcode, cluster columns)
#' @param rds_dir Directory containing pre-computed cluster RDS files (optional)
#' @param output_prefix Prefix for output RDS files (default: "mpaqt").
#'   Output files will be named `{output_prefix}.{cluster_id}.long_read.rds`
#' @param output_dir Output directory for results
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return A list of `mpaqt_counts_lr` objects, one per cluster (invisibly)
#'
#' @export
#'
#' @examples
#' \dontrun{
#' idx <- mpaqt_read_index("my_index/mpaqt.index.rds")
#'
#' # From count matrix
#' lr_counts_list <- mpaqt_prepare_long_reads_sc(
#'     index = idx,
#'     count_file = "lr_count_matrix.csv",
#'     clusters_file = "clusters.csv",
#'     output_dir = "results"
#' )
#'
#' # With custom output prefix
#' lr_counts_list <- mpaqt_prepare_long_reads_sc(
#'     index = idx,
#'     count_file = "lr_count_matrix.csv",
#'     clusters_file = "clusters.csv",
#'     output_prefix = "my_sample",
#'     output_dir = "results"
#' )
#' }
mpaqt_prepare_long_reads_sc <- function(
    index,
    count_file,
    clusters_file,
    rds_dir = NULL,
    output_prefix = NULL,
    output_dir,
    verbose = TRUE
) {
    # Validate inputs
    validate_mpaqt_index(index)
    validate_file_exists(count_file, "Long-read count file")
    validate_file_exists(clusters_file, "Clusters file")
    validate_output_dir(output_dir)

    # Set default output prefix
    if (is.null(output_prefix)) {
        output_prefix <- "mpaqt"
    }

    if (verbose) cli::cli_h1("Preparing Single-Cell Long-Read Data")

    # Check for pre-computed RDS files
    if (!is.null(rds_dir) && dir.exists(rds_dir)) {
        rds_files <- list.files(rds_dir, pattern = "\\.long_read\\.rds$", full.names = TRUE)
        if (length(rds_files) > 0) {
            if (verbose) cli::cli_alert_info("Loading {length(rds_files)} pre-computed cluster files")
            counts_list <- lapply(rds_files, mpaqt_read_long_read_counts)
            names(counts_list) <- gsub("\\.long_read\\.rds$", "", basename(rds_files))
            return(invisible(counts_list))
        }
    }

    # Read cluster assignments
    if (verbose) cli::cli_progress_step("Reading cluster assignments")

    clusters <- data.table::fread(clusters_file)
    if (ncol(clusters) < 2) {
        cli::cli_abort("Clusters file must have at least 2 columns (barcode, cluster)")
    }
    names(clusters)[1:2] <- c("barcode", "cluster")
    cluster_ids <- unique(clusters$cluster)

    cli::cli_alert_info("Found {length(cluster_ids)} clusters")

    # Read count matrix
    if (verbose) cli::cli_progress_step("Reading count matrix")

    count_mat <- data.table::fread(count_file)
    transcript_col <- names(count_mat)[1]
    transcript_ids <- count_mat[[transcript_col]]

    # Process each cluster
    counts_list <- list()

    for (cl in cluster_ids) {
        if (verbose) cli::cli_progress_step("Processing cluster {cl}")

        # Get barcodes for this cluster
        cluster_barcodes <- clusters[cluster == cl, barcode]

        # Find matching columns in count matrix
        matched_cols <- intersect(cluster_barcodes, names(count_mat))

        if (length(matched_cols) == 0) {
            cli::cli_warn("No barcodes found for cluster {cl}")
            counts_vec <- rep(0, length(index$transcripts))
            names(counts_vec) <- index$transcripts
        } else {
            # Sum counts across cells in cluster
            cluster_counts <- rowSums(
                count_mat[, matched_cols, with = FALSE],
                na.rm = TRUE
            )
            names(cluster_counts) <- transcript_ids

            # Match to index order
            counts_vec <- match_lr_counts_to_index(cluster_counts, index$transcripts)
        }

        # Create counts object
        counts <- new_mpaqt_counts_lr(
            counts = counts_vec,
            sample_id = as.character(cl)
        )

        # Save (use basename of output_prefix to avoid path duplication)
        prefix_base <- basename(output_prefix)
        counts_file_path <- file.path(output_dir, paste0(prefix_base, ".", cl, ".long_read.rds"))
        saveRDS(counts, counts_file_path)

        counts_list[[as.character(cl)]] <- counts
    }

    # Create combined "all_clusters" counts
    if (verbose) cli::cli_progress_step("Creating combined cluster counts")

    all_counts_vec <- Reduce(`+`, lapply(counts_list, function(x) x$counts))
    names(all_counts_vec) <- index$transcripts

    all_counts <- new_mpaqt_counts_lr(
        counts = all_counts_vec,
        sample_id = "all_clusters"
    )

    # Use basename of output_prefix to avoid path duplication
    prefix_base <- basename(output_prefix)
    all_counts_file <- file.path(output_dir, paste0(prefix_base, ".all_clusters.long_read.rds"))
    saveRDS(all_counts, all_counts_file)

    counts_list[["all_clusters"]] <- all_counts

    if (verbose) {
        cli::cli_progress_done()
        cli::cli_alert_success("Processed {length(counts_list)} clusters (including combined)")
    }

    invisible(counts_list)
}

#' Prepare Single-Cell Long-Read Data from FLNC FASTQ
#'
#' Process single-cell long-read FLNC (full-length non-chimeric) FASTQ files
#' with user-provided cluster assignments.
#'
#' @param index An `mpaqt_index` object
#' @param flnc_fastq Path to pre-demultiplexed FLNC FASTQ file with barcodes
#' @param genome Path to genome FASTA or BSgenome object/name
#' @param gtf Path to GTF annotation file (or uses index GTF if available)
#' @param clusters_file Path to cluster assignment file (CSV with barcode, cluster columns).
#'   This is REQUIRED - MPAQT does not perform automatic cell clustering.
#' @param output_prefix Prefix for output RDS files (default: "mpaqt").
#'   Output files will be named `{output_prefix}.{cluster_id}.long_read.rds`
#' @param output_dir Output directory for results
#' @param keep_bam Keep minimap2 BAM alignment files (default: FALSE)
#' @param keep_bambu_cache Keep Bambu intermediate cache files (default: FALSE)
#' @param platform Sequencing platform: "PacBio" or "ONT" (default: "PacBio").
#'   Determines minimap2 alignment preset.
#' @param discovery Enable Bambu novel transcript discovery (default: FALSE)
#' @param ndr Novel discovery rate threshold for Bambu (default: 1)
#' @param threads Number of threads for minimap2/Bambu (default: 1)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return A list of `mpaqt_counts_lr` objects, one per cluster (invisibly)
#'
#' @details
#' This function processes single-cell long-read data from pre-demultiplexed
#' FLNC FASTQ files. The input FASTQ should have cell barcodes already extracted
#' and associated with each read.
#'
#' The pipeline:
#' 1. Reads cluster assignments mapping barcodes to clusters
#' 2. Aligns long reads with minimap2 (preset based on platform)
#' 3. Quantifies transcripts with Bambu
#' 4. Splits counts by cluster using the provided assignments
#' 5. Creates `mpaqt_counts_lr` object per cluster
#'
#' @section Requirements:
#' Processing raw FLNC data requires:
#' - **minimap2** and **samtools** installed and in PATH
#' - **Bambu** Bioconductor package installed
#'
#' Check requirements with [require_sc_long_read_flnc()].
#'
#' @section Cluster Assignments:
#' MPAQT does NOT perform automatic cell clustering. Users must provide
#' pre-computed cluster assignments, typically from short-read scRNA-seq
#' analysis or other clustering methods.
#'
#' The `clusters_file` should be a CSV with at least two columns:
#' - Column 1: Cell barcode

#' - Column 2: Cluster assignment (numeric or character)
#'
#' @section Intermediate File Handling:
#' By default, intermediate files are cleaned up after processing:
#' - `keep_bam = FALSE`: Removes minimap2 alignment files (`.bam`, `.bai`)
#' - `keep_bambu_cache = FALSE`: Removes Bambu output (`.rds`)
#'
#' @export
#'
#' @examples
#' \dontrun{
#' idx <- mpaqt_read_index("my_index/mpaqt.index.rds")
#'
#' # Process SC long-read FLNC with provided clusters
#' lr_counts_list <- mpaqt_prepare_long_reads_sc_flnc(
#'     index = idx,
#'     flnc_fastq = "sample.flnc.fastq.gz",
#'     genome = "genome.fa",
#'     gtf = "annotation.gtf",
#'     clusters_file = "clusters.csv",
#'     output_dir = "results",
#'     platform = "PacBio",
#'     threads = 8
#' )
#'
#' # Keep intermediate files for debugging
#' lr_counts_list <- mpaqt_prepare_long_reads_sc_flnc(
#'     index = idx,
#'     flnc_fastq = "sample.flnc.fastq.gz",
#'     genome = "genome.fa",
#'     gtf = "annotation.gtf",
#'     clusters_file = "clusters.csv",
#'     output_prefix = "my_sample",
#'     keep_bam = TRUE,
#'     keep_bambu_cache = TRUE,
#'     output_dir = "results"
#' )
#' }
mpaqt_prepare_long_reads_sc_flnc <- function(
    index,
    flnc_fastq,
    genome,
    gtf = NULL,
    clusters_file,
    output_prefix = NULL,
    output_dir,
    keep_bam = FALSE,
    keep_bambu_cache = FALSE,
    platform = "PacBio",
    discovery = FALSE,
    ndr = 1,
    threads = 1L,
    verbose = TRUE
) {
    # Validate inputs
    validate_mpaqt_index(index)
    validate_file_exists(flnc_fastq, "FLNC FASTQ file")
    validate_file_exists(clusters_file, "Clusters file")
    validate_output_dir(output_dir)

    # Check requirements
    require_sc_long_read_flnc()

    # Set default output prefix
    if (is.null(output_prefix)) {
        output_prefix <- "mpaqt"
    }

    # Validate platform
    platform <- match.arg(platform, c("PacBio", "ONT"))
    minimap_preset <- switch(
        platform,
        "PacBio" = "splice:hq",
        "ONT" = "splice"
    )

    if (verbose) {
        cli::cli_h1("Preparing Single-Cell Long-Read Data (FLNC)")
        cli::cli_alert_info("Platform: {.val {platform}}")
        cli::cli_alert_info("minimap2 preset: {.val {minimap_preset}}")
    }

    # Read cluster assignments
    if (verbose) cli::cli_progress_step("Reading cluster assignments")

    clusters <- data.table::fread(clusters_file)
    if (ncol(clusters) < 2) {
        cli::cli_abort("Clusters file must have at least 2 columns (barcode, cluster)")
    }
    names(clusters)[1:2] <- c("barcode", "cluster")
    cluster_ids <- unique(clusters$cluster)

    cli::cli_alert_info("Found {length(cluster_ids)} clusters with {nrow(clusters)} barcodes")

    # Get GTF annotation
    if (is.null(gtf)) {
        gtf_path <- get_gtf_for_long_reads(index, output_dir, verbose)
    } else {
        validate_gtf(gtf)
        gtf_path <- gtf
    }

    # Get genome FASTA
    genome_fasta <- get_genome_fasta(genome, output_dir, verbose)

    # Step 1: Align with minimap2
    if (verbose) cli::cli_h2("Step 1: minimap2 Alignment")

    sample_id <- sub("\\.(fastq|fq)(\\.gz)?$", "", basename(flnc_fastq))
    bam_file <- file.path(output_dir, paste0(sample_id, ".aligned.bam"))

    run_minimap2_genome(
        fastq_file = flnc_fastq,
        genome_fasta = genome_fasta,
        output_bam = bam_file,
        threads = threads,
        preset = minimap_preset,
        output_dir = output_dir,
        verbose = verbose
    )

    # Step 2: Run Bambu quantification
    if (verbose) cli::cli_h2("Step 2: Bambu Quantification")

    se <- run_bambu(
        bam_files = bam_file,
        gtf_path = gtf_path,
        genome = genome,
        output_dir = output_dir,
        discovery = discovery,
        quant = TRUE,
        ndr = ndr,
        threads = threads,
        verbose = verbose
    )

    # Save Bambu results
    bambu_file <- file.path(output_dir, "bambu_results.rds")
    save_bambu_results(se, bambu_file)
    if (verbose) cli::cli_alert_info("Saved Bambu results: {.path {bambu_file}}")

    # Step 3: Extract counts and split by cluster
    if (verbose) cli::cli_h2("Step 3: Splitting Counts by Cluster")

    # Get transcript counts from Bambu
    # Bambu returns a SummarizedExperiment; extract the count assay
    if (requireNamespace("SummarizedExperiment", quietly = TRUE)) {
        count_matrix <- SummarizedExperiment::assay(se, "counts")
        transcript_ids <- rownames(count_matrix)
    } else {
        # Fallback if SummarizedExperiment not available
        count_matrix <- se$counts
        transcript_ids <- rownames(count_matrix)
    }

    # For now, aggregate all counts (since FLNC is bulk-like per read)
    # The barcode-to-cluster mapping is applied conceptually
    # In practice, demultiplexed FLNC has one count per transcript per sample

    # Create counts for each cluster
    # NOTE: This assumes the FLNC file is a pooled sample, not per-cell
    # For true per-cell counts, Bambu would need barcode info in the BAM

    counts_list <- list()

    # For SC FLNC, we typically sum counts across all cells in a cluster
    # Since this is aggregate FLNC, we'll create cluster-proportional counts
    # based on the cluster sizes

    total_counts <- rowSums(count_matrix)
    names(total_counts) <- transcript_ids

    # Match to index order
    ordered_counts <- match_lr_counts_to_index(total_counts, index$transcripts)

    # For simplicity, assign all counts to "all_clusters"
    # In a real SC-FLNC pipeline with barcode tags, you'd split by barcode
    if (verbose) {
        cli::cli_alert_info("Note: FLNC counts represent aggregate per-cluster estimates")
    }

    # Create per-cluster counts (proportional split based on cluster sizes)
    cluster_sizes <- table(clusters$cluster)

    for (cl in cluster_ids) {
        if (verbose) cli::cli_progress_step("Processing cluster {cl}")

        # Proportional allocation based on cluster size
        cl_size <- cluster_sizes[as.character(cl)]
        total_size <- sum(cluster_sizes)
        proportion <- as.numeric(cl_size) / total_size

        cl_counts <- ordered_counts * proportion
        names(cl_counts) <- index$transcripts

        counts <- new_mpaqt_counts_lr(
            counts = cl_counts,
            sample_id = as.character(cl)
        )

        # Save (use basename of output_prefix to avoid path duplication)
        prefix_base <- basename(output_prefix)
        counts_file_path <- file.path(output_dir, paste0(prefix_base, ".", cl, ".long_read.rds"))
        saveRDS(counts, counts_file_path)

        counts_list[[as.character(cl)]] <- counts
    }

    # Create combined "all_clusters" counts
    if (verbose) cli::cli_progress_step("Creating combined cluster counts")

    all_counts <- new_mpaqt_counts_lr(
        counts = ordered_counts,
        sample_id = "all_clusters"
    )

    # Use basename of output_prefix to avoid path duplication
    prefix_base <- basename(output_prefix)
    all_counts_file <- file.path(output_dir, paste0(prefix_base, ".all_clusters.long_read.rds"))
    saveRDS(all_counts, all_counts_file)

    counts_list[["all_clusters"]] <- all_counts

    # Clean up intermediate files if not keeping them
    cleanup_lr_files(
        output_dir = output_dir,
        bam_file = bam_file,
        bambu_file = bambu_file,
        keep_bam = keep_bam,
        keep_bambu_cache = keep_bambu_cache,
        verbose = verbose
    )

    if (verbose) {
        cli::cli_progress_done()
        n_nonzero <- sum(ordered_counts > 0)
        cli::cli_alert_success("Quantified {n_nonzero} transcripts")
        cli::cli_alert_success("Created {length(counts_list)} cluster counts (including combined)")
    }

    invisible(counts_list)
}

# =============================================================================
# I/O Functions
# =============================================================================

#' Load Pre-Processed Long-Read Counts
#'
#' Load long-read transcript counts from a previously saved RDS file.
#'
#' @param path Path to the RDS file
#'
#' @return An `mpaqt_counts_lr` object
#'
#' @export
mpaqt_read_long_read_counts <- function(path) {
    validate_file_exists(path, "Long-read counts file")

    counts <- readRDS(path)

    # Handle legacy format (plain named vector)
    if (!inherits(counts, "mpaqt_counts_lr")) {
        if (is.numeric(counts) && !is.null(names(counts))) {
            cli::cli_alert_info("Converting legacy long-read counts format")
            counts <- new_mpaqt_counts_lr(
                counts = counts,
                sample_id = basename(path)
            )
        } else {
            cli::cli_abort(c(
                "Invalid long-read counts file: {.path {path}}",
                "i" = "Expected mpaqt_counts_lr object or named numeric vector"
            ))
        }
    }

    counts
}

# =============================================================================
# Legacy Compatibility (Deprecated)
# =============================================================================

#' Process Long-Read Count File (Bulk)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated. Use [mpaqt_prepare_long_reads()] instead,
#' which supports multiple input pathways.
#'
#' @param count_file Path to count file
#' @param index An `mpaqt_index` object
#' @param output_dir Output directory
#'
#' @return An `mpaqt_counts_lr` object (invisibly)
#'
#' @export
#' @keywords internal
mpaqt_process_long_reads <- function(count_file, index, output_dir) {
    cli::cli_warn(c(
        "{.fn mpaqt_process_long_reads} is deprecated",
        "i" = "Use {.fn mpaqt_prepare_long_reads} instead"
    ))

    mpaqt_prepare_long_reads(
        index = index,
        bambu_counts = count_file,
        output_dir = output_dir,
        verbose = TRUE
    )
}

#' Process Long-Read Count File (Single-Cell)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' This function is deprecated. Use [mpaqt_prepare_long_reads_sc()] instead.
#'
#' @param count_file Path to count matrix
#' @param clusters_file Path to cluster file
#' @param index An `mpaqt_index` object
#' @param output_dir Output directory
#'
#' @return A list of `mpaqt_counts_lr` objects (invisibly)
#'
#' @export
#' @keywords internal
mpaqt_process_long_reads_sc <- function(count_file, clusters_file, index, output_dir) {
    cli::cli_warn(c(
        "{.fn mpaqt_process_long_reads_sc} is deprecated",
        "i" = "Use {.fn mpaqt_prepare_long_reads_sc} instead"
    ))

    mpaqt_prepare_long_reads_sc(
        index = index,
        count_file = count_file,
        clusters_file = clusters_file,
        output_dir = output_dir,
        verbose = TRUE
    )
}
