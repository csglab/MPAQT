# Infrastructure: minimap2 wrapper functions
# Internal functions for running minimap2 for long-read alignment

#' Check if minimap2 is available
#'
#' @return Path to minimap2 if found
#' @keywords internal
check_minimap2 <- function() {
    path <- Sys.which("minimap2")

    if (path == "") {
        cli::cli_abort(c(
            "{.code minimap2} not found in PATH",
            "i" = "Install minimap2 for long-read alignment",
            "i" = "See: {.url https://github.com/lh3/minimap2}",
            "i" = "Or use conda: {.code conda install -c bioconda minimap2}"
        ))
    }

    invisible(path)
}

#' Check if samtools is available
#'
#' @return Path to samtools if found
#' @keywords internal
check_samtools <- function() {
    path <- Sys.which("samtools")

    if (path == "") {
        cli::cli_abort(c(
            "{.code samtools} not found in PATH",
            "i" = "Install samtools for BAM processing",
            "i" = "See: {.url http://www.htslib.org/}",
            "i" = "Or use conda: {.code conda install -c bioconda samtools}"
        ))
    }

    invisible(path)
}

#' Run minimap2 for Long-Read Alignment
#'
#' Align long-read FASTQ to a reference transcriptome using minimap2.
#'
#' @param fastq_file Path to input FASTQ file (FLNC or similar)
#' @param reference_fasta Path to reference transcriptome FASTA
#' @param output_bam Path for output BAM file
#' @param threads Number of threads (default: 1)
#' @param preset minimap2 preset: "splice:hq" for high-quality long reads,
#'   "splice" for standard long reads (default: "splice:hq")
#' @param output_dir Directory for log files
#' @param verbose Print progress messages
#'
#' @return Invisible path to output BAM file
#' @keywords internal
run_minimap2_lr <- function(
    fastq_file,
    reference_fasta,
    output_bam,
    threads = 1L,
    preset = "splice:hq",
    output_dir = tempdir(),
    verbose = TRUE
) {
    # Validate inputs
    validate_file_exists(fastq_file, "FASTQ file")
    validate_file_exists(reference_fasta, "Reference FASTA")
    check_minimap2()
    check_samtools()

    if (verbose) {
        cli::cli_progress_step("Aligning long reads with minimap2")
        cli::cli_alert_info("Preset: {.val {preset}}, Threads: {.val {threads}}")
    }

    # Build minimap2 command
    # -ax splice:hq for high-quality long reads (e.g., Iso-Seq FLNC)
    # -uf for strand-specific alignment (forward strand)
    # --secondary=no to keep only primary alignments
    # Create temporary SAM file
    temp_sam <- file.path(output_dir, "minimap2_output.sam")

    minimap2_args <- c(
        "-ax", preset,
        "-uf",
        "--secondary=no",
        "-t", threads,
        "-o", temp_sam,
        reference_fasta,
        fastq_file
    )

    # Run minimap2
    run_system_command(
        task = "minimap2_align",
        command = "minimap2",
        args = minimap2_args,
        output_dir = output_dir
    )

    # Convert SAM to sorted BAM using samtools
    if (verbose) {
        cli::cli_progress_step("Converting to sorted BAM")
    }

    # Sort and convert to BAM
    temp_bam <- file.path(output_dir, "minimap2_unsorted.bam")

    # samtools view -bS to convert SAM to BAM
    run_system_command(
        task = "samtools_view",
        command = "samtools",
        args = c("view", "-bS", "-@", threads, "-o", temp_bam, temp_sam),
        output_dir = output_dir
    )

    # samtools sort
    run_system_command(
        task = "samtools_sort",
        command = "samtools",
        args = c("sort", "-@", threads, "-o", output_bam, temp_bam),
        output_dir = output_dir
    )

    # Index the BAM
    if (verbose) {
        cli::cli_progress_step("Indexing BAM file")
    }

    run_system_command(
        task = "samtools_index",
        command = "samtools",
        args = c("index", "-@", threads, output_bam),
        output_dir = output_dir
    )

    # Clean up temporary files
    unlink(c(temp_sam, temp_bam), force = TRUE)

    if (verbose) {
        cli::cli_alert_success("Alignment complete: {.path {basename(output_bam)}}")
    }

    invisible(output_bam)
}

#' Run minimap2 for Genome Alignment (for Bambu)
#'
#' Align long-read FASTQ to a genome using minimap2, for use with Bambu.
#' This produces genome-aligned BAM suitable for transcript discovery/quantification.
#'
#' @param fastq_file Path to input FASTQ file
#' @param genome_fasta Path to genome FASTA file
#' @param output_bam Path for output BAM file
#' @param threads Number of threads (default: 1)
#' @param preset minimap2 preset (default: "splice:hq")
#' @param output_dir Directory for log files
#' @param verbose Print progress messages
#'
#' @return Invisible path to output BAM file
#' @keywords internal
run_minimap2_genome <- function(
    fastq_file,
    genome_fasta,
    output_bam,
    threads = 1L,
    preset = "splice:hq",
    output_dir = tempdir(),
    verbose = TRUE
) {
    # This is essentially the same as run_minimap2_lr but with genome reference
    # and potentially different parameters for Bambu compatibility

    validate_file_exists(fastq_file, "FASTQ file")
    validate_file_exists(genome_fasta, "Genome FASTA")
    check_minimap2()
    check_samtools()

    if (verbose) {
        cli::cli_progress_step("Aligning long reads to genome with minimap2")
        cli::cli_alert_info("Preset: {.val {preset}}, Threads: {.val {threads}}")
    }

    # Build minimap2 command for genome alignment
    # -ax splice:hq for high-quality long reads
    # --junc-bed can be used with junction annotations if available
    temp_sam <- file.path(output_dir, "minimap2_genome.sam")

    minimap2_args <- c(
        "-ax", preset,
        "-uf",
        "--secondary=no",
        "-t", threads,
        "-o", temp_sam,
        genome_fasta,
        fastq_file
    )

    run_system_command(
        task = "minimap2_genome",
        command = "minimap2",
        args = minimap2_args,
        output_dir = output_dir
    )

    if (verbose) {
        cli::cli_progress_step("Converting to sorted BAM")
    }

    temp_bam <- file.path(output_dir, "minimap2_genome_unsorted.bam")

    run_system_command(
        task = "samtools_view",
        command = "samtools",
        args = c("view", "-bS", "-@", threads, "-o", temp_bam, temp_sam),
        output_dir = output_dir
    )

    run_system_command(
        task = "samtools_sort",
        command = "samtools",
        args = c("sort", "-@", threads, "-o", output_bam, temp_bam),
        output_dir = output_dir
    )

    if (verbose) {
        cli::cli_progress_step("Indexing BAM file")
    }

    run_system_command(
        task = "samtools_index",
        command = "samtools",
        args = c("index", "-@", threads, output_bam),
        output_dir = output_dir
    )

    unlink(c(temp_sam, temp_bam), force = TRUE)

    if (verbose) {
        cli::cli_alert_success("Genome alignment complete: {.path {basename(output_bam)}}")
    }

    invisible(output_bam)
}

#' Get BAM Statistics
#'
#' Get basic alignment statistics from a BAM file using samtools.
#'
#' @param bam_file Path to BAM file
#'
#' @return List with alignment statistics
#' @keywords internal
get_bam_stats <- function(bam_file) {
    validate_file_exists(bam_file, "BAM file")
    check_samtools()

    # Run samtools flagstat
    result <- system2(
        "samtools",
        args = c("flagstat", bam_file),
        stdout = TRUE,
        stderr = FALSE
    )

    # Parse output
    stats <- list(
        total = 0L,
        mapped = 0L,
        primary = 0L,
        secondary = 0L,
        supplementary = 0L
    )

    for (line in result) {
        if (grepl("in total", line)) {
            stats$total <- as.integer(sub(" \\+.*", "", line))
        } else if (grepl("primary$", line)) {
            stats$primary <- as.integer(sub(" \\+.*", "", line))
        } else if (grepl("secondary$", line)) {
            stats$secondary <- as.integer(sub(" \\+.*", "", line))
        } else if (grepl("supplementary$", line)) {
            stats$supplementary <- as.integer(sub(" \\+.*", "", line))
        } else if (grepl("mapped \\(", line)) {
            stats$mapped <- as.integer(sub(" \\+.*", "", line))
        }
    }

    stats
}
