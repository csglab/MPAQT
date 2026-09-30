# Infrastructure: Kallisto and bustools wrapper functions
# Internal functions for running external bioinformatics tools

#' Run kallisto index
#'
#' Create a kallisto index from a transcriptome FASTA file.
#'
#' @param transcriptome Path to transcriptome FASTA file
#' @param index_file Output path for kallisto index
#' @param threads Number of threads to use
#' @param output_dir Directory for log files
#'
#' @return Invisible path to created index
#' @keywords internal
run_kallisto_index <- function(
    transcriptome,
    index_file,
    threads = 1,
    output_dir = tempdir()
) {
    validate_fasta(transcriptome)

    run_system_command(
        task = "kallisto_index",
        command = "kallisto",
        args = c(
            "index",
            paste0("--index=", index_file),
            paste0("--threads=", threads),
            transcriptome
        ),
        output_dir = output_dir
    )

    invisible(index_file)
}

#' Run kallisto bus for pseudoalignment
#'
#' Run kallisto bus to pseudoalign reads to transcriptome.
#'
#' @param index_file Path to kallisto index
#' @param fastq_files Character vector of FASTQ file paths
#' @param output_dir Output directory for bus files
#' @param threads Number of threads
#' @param technology Technology string (e.g., "bulk", "10xv3")
#' @param single_end Logical; single-end mode
#' @param fragment_length Fragment length for single-end (optional)
#' @param fragment_sd Fragment length SD for single-end (optional)
#'
#' @return Invisible output directory path
#' @keywords internal
run_kallisto_bus <- function(
    index_file,
    fastq_files,
    output_dir,
    threads = 1,
    technology = "bulk",
    single_end = FALSE,
    fragment_length = NULL,
    fragment_sd = NULL
) {
    validate_file_exists(index_file, "Kallisto index")

    # Map lowercase technology names to kallisto's expected format
    tech_map <- c(
        "bulk" = "Bulk",
        "10xv2" = "10xv2",
        "10xv3" = "10xv3",
        "10xv4" = "10xv4"
    )
    kallisto_tech <- if (technology %in% names(tech_map)) tech_map[technology] else technology

    args <- c(
        "bus",
        "--index", index_file,
        "--output-dir", output_dir,
        "--technology", kallisto_tech,
        "--threads", threads,
        "--num"
    )

    # Add single-end parameters if needed
    if (single_end) {
        if (is.null(fragment_length) || is.null(fragment_sd)) {
            cli::cli_abort(c(
                "Single-end mode requires fragment length parameters",
                "i" = "Provide {.arg fragment_length} and {.arg fragment_sd}"
            ))
        }
        args <- c(args, "--single", "-l", fragment_length, "-s", fragment_sd)
    }

    args <- c(args, fastq_files)

    run_system_command(
        task = "kallisto_bus",
        command = "kallisto",
        args = args,
        output_dir = output_dir
    )

    invisible(output_dir)
}

#' Run kallisto quant for standard quantification
#'
#' Run kallisto quant for standard RNA-seq quantification (not bus mode).
#'
#' @param index_file Path to kallisto index
#' @param fastq_files Character vector of FASTQ file paths
#' @param output_dir Output directory
#' @param threads Number of threads
#' @param bootstrap Number of bootstrap samples (0 for none)
#'
#' @return Invisible output directory path
#' @keywords internal
run_kallisto_quant <- function(
    index_file,
    fastq_files,
    output_dir,
    threads = 1,
    bootstrap = 0
) {
    validate_file_exists(index_file, "Kallisto index")

    args <- c(
        "quant",
        "--index", index_file,
        "--output-dir", output_dir,
        "--threads", threads
    )

    if (bootstrap > 0) {
        args <- c(args, "--bootstrap-samples", bootstrap)
    }

    args <- c(args, fastq_files)

    run_system_command(
        task = "kallisto_quant",
        command = "kallisto",
        args = args,
        output_dir = output_dir
    )

    invisible(output_dir)
}

#' Convert BUS file to text format
#'
#' Use bustools to convert binary BUS file to human-readable text.
#'
#' @param bus_file Path to input BUS file
#' @param output_file Path for output text file
#' @param output_dir Directory for log files
#'
#' @return Invisible output file path
#' @keywords internal
run_bustools_text <- function(bus_file, output_file, output_dir = tempdir()) {
    validate_file_exists(bus_file, "BUS file")

    run_system_command(
        task = "bustools_text",
        command = "bustools",
        args = c("text", "-f", "-o", output_file, bus_file),
        output_dir = output_dir
    )

    invisible(output_file)
}

#' Sort a BUS file
#'
#' Sort BUS file by barcode, UMI, and equivalence class.
#'
#' @param bus_file Path to input BUS file
#' @param output_file Path for sorted output
#' @param threads Number of threads
#' @param output_dir Directory for log files
#'
#' @return Invisible output file path
#' @keywords internal
run_bustools_sort <- function(
    bus_file,
    output_file,
    threads = 1,
    output_dir = tempdir()
) {
    validate_file_exists(bus_file, "BUS file")

    run_system_command(
        task = "bustools_sort",
        command = "bustools",
        args = c(
            "sort",
            "-t", threads,
            "-o", output_file,
            bus_file
        ),
        output_dir = output_dir
    )

    invisible(output_file)
}

#' Correct barcodes in BUS file
#'
#' Correct cell barcodes using a whitelist.
#'
#' @param bus_file Path to sorted BUS file
#' @param output_file Path for corrected output
#' @param whitelist Path to barcode whitelist file
#' @param output_dir Directory for log files
#'
#' @return Invisible output file path
#' @keywords internal
run_bustools_correct <- function(
    bus_file,
    output_file,
    whitelist,
    output_dir = tempdir()
) {
    validate_file_exists(bus_file, "BUS file")
    validate_file_exists(whitelist, "Barcode whitelist")

    run_system_command(
        task = "bustools_correct",
        command = "bustools",
        args = c(
            "correct",
            "-w", whitelist,
            "-o", output_file,
            bus_file
        ),
        output_dir = output_dir
    )

    invisible(output_file)
}

#' Count UMIs from BUS file
#'
#' Generate count matrices from a sorted, corrected BUS file.
#'
#' @param bus_file Path to sorted BUS file
#' @param output_prefix Output prefix for count files
#' @param genemap Path to transcript-to-gene map
#' @param ecmap Path to equivalence class map
#' @param txnames Path to transcript names file
#' @param output_dir Directory for log files
#'
#' @return Invisible output prefix
#' @keywords internal
run_bustools_count <- function(
    bus_file,
    output_prefix,
    genemap,
    ecmap,
    txnames,
    output_dir = tempdir()
) {
    validate_file_exists(bus_file, "BUS file")
    validate_file_exists(genemap, "Gene map")
    validate_file_exists(ecmap, "EC map")
    validate_file_exists(txnames, "Transcript names")

    run_system_command(
        task = "bustools_count",
        command = "bustools",
        args = c(
            "count",
            "-o", output_prefix,
            "-g", genemap,
            "-e", ecmap,
            "-t", txnames,
            "--genecounts",
            bus_file
        ),
        output_dir = output_dir
    )

    invisible(output_prefix)
}

#' Read equivalence class mapping
#'
#' Parse the matrix.ec file produced by kallisto bus.
#'
#' @param ec_file Path to matrix.ec file
#'
#' @return data.table with ec_id and transcript indices
#' @keywords internal
read_ec_mapping <- function(ec_file) {
    validate_file_exists(ec_file, "EC mapping file")

    data.table::fread(
        ec_file,
        sep = "\t",
        header = FALSE,
        col.names = c("ec_id", "ec_tr_id")
    )
}

#' Read BUS text file
#'
#' Parse a BUS file that has been converted to text format.
#'
#' @param bus_txt_file Path to BUS text file
#' @param columns Which columns to read (default: ec_id and read_id)
#'
#' @return data.table with requested columns
#' @keywords internal
read_bus_text <- function(bus_txt_file, columns = c(3, 5)) {
    validate_file_exists(bus_txt_file, "BUS text file")

    col_names <- c("barcode", "umi", "ec_id", "count", "read_id")[columns]

    data.table::fread(
        bus_txt_file,
        sep = "\t",
        header = FALSE,
        select = columns,
        col.names = col_names
    )
}
