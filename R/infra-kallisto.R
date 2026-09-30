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
#' Correct cell barcodes within 1 Hamming distance of a whitelist.
#' Input BUS file must be sorted (via \code{\link{run_bustools_sort}}).
#'
#' @param bus_file Path to sorted BUS file
#' @param output_file Path for corrected output
#' @param whitelist Path to barcode whitelist file (one barcode per line)
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
#' Generate UMI-deduplicated count matrices from a sorted BUS file.
#' Produces MatrixMarket (.mtx), barcodes (.barcodes.txt), and
#' EC/gene (.ec.txt or .genes.txt) output files.
#'
#' @param bus_file Path to sorted BUS file
#' @param output_prefix Output prefix for count files
#' @param genemap Path to transcript-to-gene map (tab-separated, two columns:
#'   transcript_id and gene_id). Transcript IDs must match transcripts.txt
#'   exactly — see \code{\link{generate_t2g_from_transcripts}}.
#' @param ecmap Path to equivalence class map (matrix.ec from kallisto bus)
#' @param txnames Path to transcript names file (transcripts.txt from kallisto bus)
#' @param multimapping Logical; count multimapping reads (default: FALSE)
#' @param output_dir Directory for log files
#'
#' @return Invisible output prefix
#' @keywords internal
run_bustools_count <- function(
    bus_file,
    output_prefix,
    ecmap,
    txnames,
    genemap = NULL,
    multimapping = FALSE,
    output_dir = tempdir()
) {
    validate_file_exists(bus_file, "BUS file")
    validate_file_exists(ecmap, "EC map")
    validate_file_exists(txnames, "Transcript names")

    args <- c("count", "-o", output_prefix, "-e", ecmap, "-t", txnames)

    if (!is.null(genemap)) {
        validate_file_exists(genemap, "Gene map")
        args <- c(args, "-g", genemap)
    }

    if (multimapping) {
        args <- c(args, "--multimapping")
    }

    run_system_command(
        task = "bustools_count",
        command = "bustools",
        args = c(args, bus_file),
        output_dir = output_dir
    )

    invisible(output_prefix)
}

#' Inspect a BUS file
#'
#' Run bustools inspect to get QC statistics from a BUS file.
#'
#' @param bus_file Path to BUS file
#' @param output_dir Directory for log files
#'
#' @return Invisible bus_file path
#' @keywords internal
run_bustools_inspect <- function(bus_file, output_dir = tempdir()) {
    validate_file_exists(bus_file, "BUS file")

    run_system_command(
        task = "bustools_inspect",
        command = "bustools",
        args = c("inspect", bus_file),
        output_dir = output_dir
    )

    invisible(bus_file)
}

# =============================================================================
# Helper Functions
# =============================================================================

#' Generate t2g mapping for bustools count
#'
#' Checks whether \code{transcripts.txt} from \code{kallisto bus} uses
#' pipe-delimited GENCODE headers (e.g.
#' \code{ENST...|ENSG...|...|gene_name|...}). If so, parses the transcript
#' names directly from that file so that column 1 of the t2g matches
#' \code{transcripts.txt} exactly. Otherwise, uses the transcript/gene
#' vectors from the \code{mpaqt_index} object.
#'
#' @param index An \code{mpaqt_index} object containing \code{$transcripts}
#'   and \code{$genes} vectors
#' @param transcripts_file Path to transcripts.txt from kallisto bus
#' @param output_file Path for the output t2g file (tab-separated, no header)
#'
#' @return Invisible path to created t2g file
#' @keywords internal
generate_t2g <- function(index, transcripts_file, output_file) {
    validate_file_exists(transcripts_file, "Transcripts file")

    # Check if transcripts.txt uses pipe-delimited GENCODE headers
    first_lines <- readLines(transcripts_file, n = 5)
    is_pipe_delimited <- any(grepl("\\|", first_lines))

    if (is_pipe_delimited) {
        cli::cli_alert_info("Detected pipe-delimited transcript names in transcripts.txt")
        generate_t2g_from_transcripts(transcripts_file, output_file)
    } else {
        generate_t2g_from_index(index, output_file)
    }
}

#' Generate t2g mapping from mpaqt index
#'
#' Write a tab-separated transcript-to-gene mapping file from the transcript
#' and gene vectors stored in an \code{mpaqt_index} object.
#'
#' @param index An \code{mpaqt_index} object containing \code{$transcripts}
#'   and \code{$genes} vectors
#' @param output_file Path for the output t2g file (tab-separated, no header)
#'
#' @return Invisible path to created t2g file
#' @keywords internal
generate_t2g_from_index <- function(index, output_file) {
    t2g <- data.table::data.table(
        transcript = index$transcripts,
        gene = index$genes
    )

    data.table::fwrite(t2g, output_file, sep = "\t", col.names = FALSE)

    cli::cli_alert_info(
        "Generated t2g from index: {nrow(t2g)} transcripts, {length(unique(t2g$gene))} genes"
    )

    invisible(output_file)
}

#' Generate t2g mapping from pipe-delimited transcripts.txt
#'
#' When a GENCODE FASTA is used with \code{kallisto index}, transcript names
#' in \code{transcripts.txt} retain the full pipe-delimited header, e.g.
#' \code{ENST00000832824.1|ENSG00000290825.2|-|-|DDX11L16-260|DDX11L16|1379|lncRNA|}.
#' Column 1 of the t2g must match these names exactly for \code{bustools count}
#' to work.
#'
#' This function uses the full pipe-delimited name as column 1 and extracts
#' the gene ID (second field) as column 2.
#'
#' @param transcripts_file Path to transcripts.txt from kallisto bus
#' @param output_file Path for the output t2g file (tab-separated, no header)
#'
#' @return Invisible path to created t2g file
#' @keywords internal
generate_t2g_from_transcripts <- function(transcripts_file, output_file) {
    tx_names <- readLines(transcripts_file)

    # Parse pipe-delimited GENCODE headers
    # Format: ENST...|ENSG...|...|...|...|gene_name|length|biotype|
    parts <- strsplit(tx_names, "\\|", fixed = FALSE)
    gene_ids <- vapply(parts, function(x) {
        if (length(x) >= 2 && nchar(x[2]) > 0) x[2] else x[1]
    }, character(1))

    t2g <- data.table::data.table(
        transcript = tx_names,
        gene = gene_ids
    )

    data.table::fwrite(t2g, output_file, sep = "\t", col.names = FALSE)

    cli::cli_alert_info(
        "Generated t2g from transcripts.txt: {nrow(t2g)} transcripts, {length(unique(gene_ids))} genes"
    )

    invisible(output_file)
}

#' Generate barcode whitelist from cluster annotations
#'
#' Extract unique barcodes from a cluster assignments file to use as a
#' whitelist for \code{bustools correct}.
#'
#' @param clusters_file Path to cluster assignment CSV (barcode, cluster columns)
#' @param output_file Path for the output whitelist file (one barcode per line)
#'
#' @return Invisible path to created whitelist file
#' @keywords internal
generate_whitelist_from_clusters <- function(clusters_file, output_file) {
    validate_file_exists(clusters_file, "Clusters file")

    barcode_clusters <- data.table::fread(
        clusters_file,
        select = 1,
        col.names = "barcode"
    )

    barcodes <- sort(unique(barcode_clusters$barcode))
    writeLines(barcodes, output_file)

    cli::cli_alert_info("Generated whitelist: {length(barcodes)} barcodes")

    invisible(output_file)
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
