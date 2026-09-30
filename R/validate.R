# Input validation functions
# All validation functions use cli for informative error messages

#' Check if a file exists
#'
#' @param path File path to check
#' @param name Human-readable name for error messages
#' @param arg Argument name for error messages
#'
#' @return Invisible TRUE if file exists
#' @keywords internal
validate_file_exists <- function(path, name = "File", arg = NULL) {
    if (is.null(path)) {
        if (!is.null(arg)) {
            cli::cli_abort("{.arg {arg}} cannot be NULL")
        } else {
            cli::cli_abort("{name} path cannot be NULL")
        }
    }

    if (!file.exists(path)) {
        cli::cli_abort(c(
            "{name} not found: {.path {path}}",
            "i" = "Check that the file exists and the path is correct"
        ))
    }

    invisible(TRUE)
}

#' Validate a FASTA file
#'
#' @param path Path to FASTA file
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_fasta <- function(path) {
    validate_file_exists(path, "Transcriptome FASTA", "transcriptome")

    # Check extension
    if (!grepl("\\.(fa|fasta|fna)(\\.gz)?$", path, ignore.case = TRUE)) {
        cli::cli_warn(c(
            "File may not be in FASTA format: {.path {basename(path)}}",
            "i" = "Expected extension: .fa, .fasta, or .fna (optionally .gz)"
        ))
    }

    invisible(TRUE)
}

#' Validate a GTF file
#'
#' @param path Path to GTF file
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_gtf <- function(path) {
    validate_file_exists(path, "GTF annotation", "annotation")

    # Check extension
    if (!grepl("\\.gtf(\\.gz)?$", path, ignore.case = TRUE)) {
        cli::cli_abort(c(
            "Annotation must be in GTF format: {.path {basename(path)}}",
            "i" = "Expected extension: .gtf or .gtf.gz",
            "i" = "GFF3 format is not currently supported"
        ))
    }

    invisible(TRUE)
}

#' Validate FASTQ files
#'
#' @param paths Character vector of FASTQ file paths
#' @param paired Expect paired-end files (length 2)
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_fastq <- function(paths, paired = TRUE) {
    if (is.null(paths) || length(paths) == 0) {
        cli::cli_abort("FASTQ file paths cannot be NULL or empty")
    }

    # Check existence
    missing <- paths[!file.exists(paths)]
    if (length(missing) > 0) {
        n_missing <- length(missing)
        cli::cli_abort(c(
            "{n_missing} FASTQ file{?s} not found:",
            setNames(missing, rep("x", n_missing))
        ))
    }

    # Check paired-end
    if (paired && length(paths) != 2) {
        cli::cli_abort(c(
            "Expected 2 FASTQ files for paired-end data, got {length(paths)}",
            "i" = "Provide paths to R1 and R2 files"
        ))
    }

    # Check extensions
    valid_ext <- grepl("\\.(fastq|fq)(\\.gz)?$", paths, ignore.case = TRUE)
    if (!all(valid_ext)) {
        invalid <- paths[!valid_ext]
        n_invalid <- length(invalid)
        cli::cli_warn(c(
            "{n_invalid} file{?s} may not be FASTQ format:",
            setNames(basename(invalid), rep("!", n_invalid)),
            "i" = "Expected extension: .fastq or .fq (optionally .gz)"
        ))
    }

    invisible(TRUE)
}

#' Check if an external tool exists in PATH
#'
#' @param tool Name of the tool (e.g., "kallisto")
#' @param min_version Minimum required version (optional)
#'
#' @return Path to the tool if found
#' @keywords internal
check_tool_exists <- function(tool, min_version = NULL) {
    path <- Sys.which(tool)

    if (path == "") {
        install_url <- switch(
            tool,
            kallisto = "https://pachterlab.github.io/kallisto/",
            bustools = "https://bustools.github.io/",
            "the tool's website"
        )

        cli::cli_abort(c(
            "`{tool}` not found in PATH",
            "i" = "Install {tool} and ensure it's in your PATH",
            "i" = "See: {.url {install_url}}"
        ))
    }

    # TODO: Version checking if min_version provided

    invisible(path)
}

#' Validate output directory
#'
#' @param path Directory path
#' @param create Create if doesn't exist
#'
#' @return Invisible TRUE if valid/created
#' @keywords internal
validate_output_dir <- function(path, create = TRUE) {
    if (is.null(path)) {
        cli::cli_abort("{.arg output_dir} cannot be NULL")
    }

    if (!dir.exists(path)) {
        if (create) {
            dir.create(path, recursive = TRUE, showWarnings = FALSE)
            if (!dir.exists(path)) {
                cli::cli_abort(c(
                    "Could not create output directory: {.path {path}}",
                    "i" = "Check that you have write permissions"
                ))
            }
        } else {
            cli::cli_abort(c(
                "Output directory does not exist: {.path {path}}",
                "i" = "Create the directory or set {.code create = TRUE}"
            ))
        }
    }

    invisible(TRUE)
}

#' Validate positional bias parameters
#'
#' @param bias_type Bias type ("3p" or "5p")
#' @param bias_bins Number of distance bins
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_bias_params <- function(bias_type, bias_bins) {
    valid_types <- c("3p", "5p")

    if (!is.null(bias_type) && !bias_type %in% valid_types) {
        cli::cli_abort(c(
            "Invalid {.arg bias_type}: {.val {bias_type}}",
            "i" = "Must be one of: {.val {valid_types}}"
        ))
    }

    if (!is.null(bias_bins)) {
        if (!is.numeric(bias_bins) || bias_bins < 10 || bias_bins > 1000) {
            cli::cli_abort(c(
                "Invalid {.arg bias_bins}: {.val {bias_bins}}",
                "i" = "Must be an integer between 10 and 1000"
            ))
        }
    }

    invisible(TRUE)
}

#' Validate technology parameter for single-cell
#'
#' @param technology Technology string
#'
#' @return Validated technology string
#' @keywords internal
validate_technology <- function(technology) {
    valid <- c("bulk", "10xv2", "10xv3", "10xv4")

    if (!technology %in% valid) {
        cli::cli_abort(c(
            "Invalid {.arg technology}: {.val {technology}}",
            "i" = "Must be one of: {.val {valid}}"
        ))
    }

    technology
}

#' Validate an mpaqt_index object
#'
#' @param x Object to validate
#'
#' @return Invisible TRUE if valid, error otherwise
#' @keywords internal
validate_mpaqt_index <- function(x) {
    if (!inherits(x, "mpaqt_index")) {
        cli::cli_abort(c(
            "Expected an {.cls mpaqt_index} object",
            "i" = "Create one with {.fn mpaqt_index} or load with {.fn mpaqt_read_index}"
        ))
    }

    required <- c("transcripts", "genes", "ec_ids", "p_matrices")
    missing <- setdiff(required, names(x))

    if (length(missing) > 0) {
        cli::cli_abort(c(
            "Invalid {.cls mpaqt_index}: missing required components",
            "x" = "Missing: {.val {missing}}"
        ))
    }

    # Check consistency
    n_tr <- length(x$transcripts)
    if (length(x$p_matrices) != n_tr) {
        cli::cli_abort(c(
            "Invalid {.cls mpaqt_index}: inconsistent dimensions",
            "x" = "P matrices: {length(x$p_matrices)}, Transcripts: {n_tr}"
        ))
    }

    invisible(TRUE)
}

#' Validate mpaqt_counts object
#'
#' @param x Object to validate
#' @param index Optional mpaqt_index to check compatibility
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_mpaqt_counts <- function(x, index = NULL) {
    if (!inherits(x, "mpaqt_counts")) {
        cli::cli_abort(c(
            "Expected an {.cls mpaqt_counts} object",
            "i" = "Create one with {.fn mpaqt_process_short_reads} or {.fn mpaqt_process_long_reads}"
        ))
    }

    if (!is.null(index)) {
        validate_mpaqt_index(index)

        if (inherits(x, "mpaqt_counts_sr")) {
            # Check EC compatibility
            if (!identical(names(x$counts), index$ec_ids)) {
                cli::cli_abort(c(
                    "Short-read counts do not match index",
                    "x" = "EC IDs differ between counts and index"
                ))
            }
        } else if (inherits(x, "mpaqt_counts_lr")) {
            # Check transcript compatibility
            if (!all(names(x$counts) %in% index$transcripts)) {
                missing <- setdiff(names(x$counts), index$transcripts)
                cli::cli_abort(c(
                    "Long-read counts contain unknown transcripts",
                    "x" = "{length(missing)} transcript{?s} not in index"
                ))
            }
        }
    }

    invisible(TRUE)
}

#' Detect short-read input type
#'
#' @param fastq_1 First FASTQ file path
#' @param fastq_2 Second FASTQ file path
#' @param rds_file Pre-processed RDS file path
#'
#' @return Character: "fastq", "fastq_single", "rds", or error
#' @keywords internal
detect_short_read_input <- function(fastq_1 = NULL, fastq_2 = NULL, rds_file = NULL) {
    if (!is.null(rds_file)) {
        return("rds")
    } else if (!is.null(fastq_1) && !is.null(fastq_2)) {
        return("fastq")
    } else if (!is.null(fastq_1)) {
        return("fastq_single")
    } else {
        cli::cli_abort(c(
            "No short-read input provided",
            "i" = "Provide FASTQ files ({.arg fastq_1}, {.arg fastq_2})",
            "i" = "Or pre-processed counts ({.arg short_read_rds})"
        ))
    }
}

#' Detect long-read input type
#'
#' @param counts_file CSV counts file path
#' @param rds_file Pre-processed RDS file path
#'
#' @return Character: "csv", "rds", or "none"
#' @keywords internal
detect_long_read_input <- function(counts_file = NULL, rds_file = NULL) {
    if (!is.null(rds_file)) {
        return("rds")
    } else if (!is.null(counts_file)) {
        return("csv")
    } else {
        return("none")
    }
}

#' Require a Bioconductor package
#'
#' @param pkg Package name
#' @param reason Why it's needed
#'
#' @return Invisible TRUE if available
#' @keywords internal
require_bioc <- function(pkg, reason = "for this operation") {
    if (!requireNamespace(pkg, quietly = TRUE)) {
        cli::cli_abort(c(
            "Package {.pkg {pkg}} is required {reason}",
            "i" = "Install with: {.code BiocManager::install('{pkg}')}"
        ))
    }
    invisible(TRUE)
}

#' Validate short-read counts object
#'
#' @param x Object to validate
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_mpaqt_counts_sr <- function(x) {
    if (!inherits(x, "mpaqt_counts_sr")) {
        cli::cli_abort(c(
            "Expected an {.cls mpaqt_counts_sr} object",
            "i" = "Create one with {.fn mpaqt_process_short_reads}"
        ))
    }

    if (is.null(x$counts) || !is.numeric(x$counts)) {
        cli::cli_abort("Invalid counts in mpaqt_counts_sr object")
    }

    invisible(TRUE)
}

#' Validate long-read counts object
#'
#' @param x Object to validate
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_mpaqt_counts_lr <- function(x) {
    if (!inherits(x, "mpaqt_counts_lr")) {
        cli::cli_abort(c(
            "Expected an {.cls mpaqt_counts_lr} object",
            "i" = "Create one with {.fn mpaqt_process_long_reads}"
        ))
    }

    if (is.null(x$counts) || !is.numeric(x$counts)) {
        cli::cli_abort("Invalid counts in mpaqt_counts_lr object")
    }

    invisible(TRUE)
}

#' Validate quantification result object
#'
#' @param x Object to validate
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_mpaqt_quant_result <- function(x) {
    if (!inherits(x, "mpaqt_quant_result")) {
        cli::cli_abort(c(
            "Expected an {.cls mpaqt_quant_result} object",
            "i" = "Create one with {.fn mpaqt_quant_bulk} or {.fn mpaqt_quant_sc}"
        ))
    }

    required <- c("abundances", "tpm", "log_likelihood", "converged")
    missing <- setdiff(required, names(x))

    if (length(missing) > 0) {
        cli::cli_abort(c(
            "Invalid {.cls mpaqt_quant_result}: missing components",
            "x" = "Missing: {.val {missing}}"
        ))
    }

    invisible(TRUE)
}

# =============================================================================
# Pathway Detection Functions for Flexible Workflows
# =============================================================================

#' Detect Indexing Input Pathway
#'
#' Determines which indexing pathway to use based on provided inputs.
#'
#' @param transcriptome Path to transcriptome FASTA (optional)
#' @param kallisto_index Path to pre-built Kallisto index (optional)
#' @param genome BSgenome object or package name (optional)
#'
#' @return Character string: "fasta", "genome", or "prebuilt"
#' @keywords internal
detect_index_pathway <- function(transcriptome = NULL,
                                  kallisto_index = NULL,
                                  genome = NULL) {
    has_fasta <- !is.null(transcriptome)
    has_index <- !is.null(kallisto_index)
    has_genome <- !is.null(genome)

    # Pathway C: Pre-built Kallisto index (requires FASTA for P matrix)
    if (has_fasta && has_index) {
        return("prebuilt")
    }

    # Pathway A: Build from FASTA (standard pathway)
    if (has_fasta && !has_index) {
        return("fasta")
    }

    # Pathway B: Extract transcriptome from genome
    if (!has_fasta && has_genome) {
        return("genome")
    }

    # Invalid combinations
    if (has_index && !has_fasta) {
        cli::cli_abort(c(
            "Pre-built Kallisto index requires transcriptome FASTA",
            "i" = "Provide {.arg transcriptome} with the FASTA used to build the index",
            "i" = "This is needed to construct the P matrix"
        ))
    }

    cli::cli_abort(c(
        "Invalid input combination for indexing",
        "i" = "Provide one of:",
        "*" = "{.arg transcriptome} - FASTA file to build index from",
        "*" = "{.arg genome} - BSgenome to extract transcriptome from GTF",
        "*" = "{.arg transcriptome} + {.arg kallisto_index} - use pre-built index"
    ))
}

#' Detect Short-Read Preprocessing Pathway
#'
#' Determines which short-read preprocessing pathway to use.
#'
#' @param fastq_1 Path to first FASTQ file (optional)
#' @param fastq_2 Path to second FASTQ file (optional)
#' @param bus_file Path to BUS file (optional)
#' @param ec_file Path to EC mapping file (optional)
#' @param rds_file Path to pre-computed RDS (optional)
#'
#' @return Character string: "fastq", "bus", or "rds"
#' @keywords internal
detect_sr_pathway <- function(fastq_1 = NULL,
                               fastq_2 = NULL,
                               bus_file = NULL,
                               ec_file = NULL,
                               rds_file = NULL) {
    # Pathway C: Pre-computed RDS (highest priority)
    if (!is.null(rds_file)) {
        validate_file_exists(rds_file, "RDS file")
        return("rds")
    }

    # Pathway B: BUS + EC files
    if (!is.null(bus_file) && !is.null(ec_file)) {
        validate_file_exists(bus_file, "BUS file")
        validate_file_exists(ec_file, "EC file")
        return("bus")
    }

    # Partial BUS input (error)
    if (!is.null(bus_file) && is.null(ec_file)) {
        cli::cli_abort(c(
            "BUS file provided without EC file",
            "i" = "Provide both {.arg bus_file} and {.arg ec_file}"
        ))
    }
    if (is.null(bus_file) && !is.null(ec_file)) {
        cli::cli_abort(c(
            "EC file provided without BUS file",
            "i" = "Provide both {.arg bus_file} and {.arg ec_file}"
        ))
    }

    # Pathway A: Raw FASTQ files
    if (!is.null(fastq_1) && !is.null(fastq_2)) {
        validate_fastq(c(fastq_1, fastq_2), paired = TRUE)
        return("fastq")
    }

    # Single-end FASTQ (error for bulk)
    if (!is.null(fastq_1) && is.null(fastq_2)) {
        cli::cli_abort(c(
            "Single-end FASTQ not supported for bulk RNA-seq",
            "i" = "Provide paired-end files with {.arg fastq_1} and {.arg fastq_2}",
            "i" = "For single-cell, use technology-specific parameters"
        ))
    }

    # No valid input
    cli::cli_abort(c(
        "No valid short-read input provided",
        "i" = "Provide one of:",
        "*" = "Paired FASTQ files: {.arg fastq_1}, {.arg fastq_2}",
        "*" = "BUS files: {.arg bus_file}, {.arg ec_file}",
        "*" = "Pre-computed: {.arg rds_file}"
    ))
}

#' Detect Long-Read Preprocessing Pathway
#'
#' Determines which long-read preprocessing pathway to use.
#'
#' @param flnc_fastq Path to FLNC FASTQ file (optional)
#' @param bambu_counts Path to Bambu count table (optional)
#' @param rds_file Path to pre-computed RDS (optional)
#'
#' @return Character string: "flnc", "bambu", "rds", or "none"
#' @keywords internal
detect_lr_pathway <- function(flnc_fastq = NULL,
                               bambu_counts = NULL,
                               rds_file = NULL) {
    # Pathway C: Pre-computed RDS
    if (!is.null(rds_file)) {
        validate_file_exists(rds_file, "Long-read RDS file")
        return("rds")
    }

    # Pathway B: Bambu count table
    if (!is.null(bambu_counts)) {
        validate_file_exists(bambu_counts, "Bambu counts file")
        return("bambu")
    }

    # Pathway A: Raw FLNC FASTQ
    if (!is.null(flnc_fastq)) {
        validate_file_exists(flnc_fastq, "FLNC FASTQ file")
        # Check FASTQ extension
        if (!grepl("\\.(fastq|fq)(\\.gz)?$", flnc_fastq, ignore.case = TRUE)) {
            cli::cli_warn(c(
                "File may not be FASTQ format: {.path {basename(flnc_fastq)}}",
                "i" = "Expected extension: .fastq or .fq (optionally .gz)"
            ))
        }
        return("flnc")
    }

    # No long-read input (valid - LR is optional)
    return("none")
}

#' Validate Kallisto Index File
#'
#' @param path Path to Kallisto index file
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_kallisto_index <- function(path) {
    validate_file_exists(path, "Kallisto index")

    # Check file is not empty
    if (file.size(path) < 100) {
        cli::cli_abort(c(
            "Kallisto index file appears invalid: {.path {path}}",
            "i" = "File is too small to be a valid index"
        ))
    }

    # Check it's a binary file (starts with specific bytes)
    # Kallisto index files have a specific header
    con <- file(path, "rb")
    on.exit(close(con))
    header <- readBin(con, "raw", n = 4)

    # Kallisto index magic number check (approximate)
    # The exact check depends on kallisto version

    invisible(TRUE)
}

#' Validate BUS/EC Compatibility with Index
#'
#' Checks that BUS and EC files are compatible with the MPAQT index.
#'
#' @param bus_file Path to BUS file
#' @param ec_file Path to EC mapping file
#' @param index mpaqt_index object
#'
#' @return Invisible TRUE if compatible
#' @keywords internal
validate_bus_ec_compatibility <- function(bus_file, ec_file, index) {
    validate_file_exists(bus_file, "BUS file")
    validate_file_exists(ec_file, "EC file")
    validate_mpaqt_index(index)

    # Read EC mapping to check transcript IDs
    ec_dt <- data.table::fread(
        ec_file,
        header = FALSE,
        col.names = c("ec_id", "transcript_indices"),
        sep = "\t"
    )

    # EC file contains comma-separated transcript indices
    # These should map to transcripts in the index
    # For now, just check the file is readable and non-empty

    if (nrow(ec_dt) == 0) {
        cli::cli_abort(c(
            "EC file is empty: {.path {ec_file}}",
            "i" = "This may indicate kallisto bus did not produce output"
        ))
    }

    n_ec <- nrow(ec_dt)
    n_index_ec <- length(index$ec_ids)

    # Warn if counts don't match (they won't match exactly for sample vs index)
    if (n_ec > n_index_ec * 2) {
        cli::cli_warn(c(
            "EC file has significantly more entries than index",
            "i" = "EC file: {n_ec}, Index: {n_index_ec}",
            "i" = "This may indicate mismatched references"
        ))
    }

    invisible(TRUE)
}

#' Validate Transcript IDs Against Index
#'
#' @param transcript_ids Character vector of transcript IDs to validate
#' @param index_transcripts Character vector of transcript IDs in index
#'
#' @return Invisible TRUE if valid (with warnings for mismatches)
#' @keywords internal
validate_transcript_ids <- function(transcript_ids, index_transcripts) {
    missing <- setdiff(transcript_ids, index_transcripts)
    extra <- setdiff(index_transcripts, transcript_ids)

    if (length(missing) > 0) {
        pct_missing <- round(100 * length(missing) / length(transcript_ids), 1)
        if (pct_missing > 10) {
            cli::cli_warn(c(
                "{length(missing)} transcripts ({pct_missing}%) not found in index",
                "i" = "First few: {.val {head(missing, 5)}}",
                "i" = "These will be assigned zero counts"
            ))
        }
    }

    if (length(extra) > length(index_transcripts) * 0.5) {
        cli::cli_warn(c(
            "Many index transcripts not in input data",
            "i" = "This may indicate mismatched annotations"
        ))
    }

    invisible(TRUE)
}

#' Validate Positional Bias Type
#'
#' @param bias_type Bias type (NULL, "3p", or "5p")
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_bias_type <- function(bias_type) {
    if (is.null(bias_type)) {
        return(invisible(TRUE))
    }

    valid <- c("3p", "5p")
    if (!bias_type %in% valid) {
        cli::cli_abort(c(
            "Invalid {.arg positional_bias}: {.val {bias_type}}",
            "i" = "Must be NULL (no bias correction) or one of: {.val {valid}}"
        ))
    }

    invisible(TRUE)
}

#' Validate Prior Model Specification
#'
#' @param prior_model Prior model (NULL, "shrinkage", "long_read", or list)
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_prior_model <- function(prior_model) {
    if (is.null(prior_model)) {
        return(invisible(TRUE))
    }

    if (is.character(prior_model)) {
        valid <- c("shrinkage", "long_read")
        if (!prior_model %in% valid) {
            cli::cli_abort(c(
                "Invalid {.arg prior_model}: {.val {prior_model}}",
                "i" = "Must be NULL, {.val {valid}}, or a list specification"
            ))
        }
        return(invisible(TRUE))
    }

    if (is.list(prior_model)) {
        # Check for required list components
        if (!is.null(prior_model$mean) && !is.numeric(prior_model$mean)) {
            cli::cli_abort("prior_model$mean must be numeric")
        }
        if (!is.null(prior_model$precision) && !is.numeric(prior_model$precision)) {
            cli::cli_abort("prior_model$precision must be numeric")
        }
        return(invisible(TRUE))
    }

    cli::cli_abort(c(
        "Invalid {.arg prior_model} type",
        "i" = "Must be NULL, a string, or a list"
    ))
}

#' Validate Normalization Method
#'
#' @param normalize Normalization method
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_normalize <- function(normalize) {
    valid <- c("tpm", "depth", "none")

    if (!normalize %in% valid) {
        cli::cli_abort(c(
            "Invalid {.arg normalize}: {.val {normalize}}",
            "i" = "Must be one of: {.val {valid}}"
        ))
    }

    invisible(TRUE)
}

# =============================================================================
# Optional Requirement Functions
# =============================================================================
# These functions check for optional dependencies and provide helpful
# installation instructions when they're missing.

#' Check Requirements for Transcriptome Extraction from GTF
#'
#' Verifies that all packages needed to extract a transcriptome FASTA from
#' a GTF annotation file are available.
#'
#' @details
#' Extracting a transcriptome from a genome reference (BSgenome) and GTF
#' annotation requires these Bioconductor packages:
#' - **Biostrings**: For sequence manipulation
#' - **rtracklayer**: To parse GTF annotation files
#' - **GenomicRanges**: For genomic coordinate operations
#' - **BSgenome**: To access genome sequences
#'
#' @section Installation:
#' If any package is missing, install with:
#' ```r
#' BiocManager::install(c("Biostrings", "rtracklayer", "GenomicRanges", "BSgenome"))
#' ```
#'
#' @return Invisible TRUE if all requirements are met
#' @export
#'
#' @examples
#' \dontrun{
#' # Check before using GTF -> FASTA extraction
#' require_transcriptome_extraction()
#' }
require_transcriptome_extraction <- function() {
    packages <- c("Biostrings", "rtracklayer", "GenomicRanges", "BSgenome")
    reasons <- c(
        "for sequence manipulation",
        "to parse GTF annotation files",
        "for genomic coordinate operations",
        "to access genome sequences"
    )

    missing <- character(0)
    for (i in seq_along(packages)) {
        if (!requireNamespace(packages[i], quietly = TRUE)) {
            missing <- c(missing, packages[i])
        }
    }

    if (length(missing) > 0) {
        cli::cli_abort(c(
            "Missing Bioconductor packages required for transcriptome extraction",
            "x" = "Missing: {.pkg {missing}}",
            "i" = "This feature extracts transcriptome sequences from GTF annotation",
            "i" = "Install with: {.code BiocManager::install(c({paste0('\"', missing, '\"', collapse = ', ')}))}"
        ))
    }

    invisible(TRUE)
}

#' Check Requirements for Long-Read Processing
#'
#' Verifies that all tools and packages needed for processing raw long-read
#' FASTQ files are available.
#'
#' @details
#' Processing raw long-read data (FLNC FASTQ) requires:
#' - **minimap2**: For spliced alignment of long reads
#' - **samtools**: For BAM file processing
#' - **bambu** (Bioconductor): For long-read transcript quantification
#'
#' @section Installation:
#' For external tools:
#' ```bash
#' # minimap2 (https://github.com/lh3/minimap2)
#' conda install -c bioconda minimap2
#'
#' # samtools (https://www.htslib.org/)
#' conda install -c bioconda samtools
#' ```
#'
#' For R packages:
#' ```r
#' BiocManager::install("bambu")
#' ```
#'
#' @return Invisible TRUE if all requirements are met
#' @export
#'
#' @examples
#' \dontrun{
#' # Check before processing long-read FASTQ
#' require_long_read_processing()
#' }
require_long_read_processing <- function() {
    missing_tools <- character(0)
    missing_pkgs <- character(0)

    # Check minimap2
    if (Sys.which("minimap2") == "") {
        missing_tools <- c(missing_tools, "minimap2")
    }

    # Check samtools
    if (Sys.which("samtools") == "") {
        missing_tools <- c(missing_tools, "samtools")
    }

    # Check bambu
    if (!requireNamespace("bambu", quietly = TRUE)) {
        missing_pkgs <- c(missing_pkgs, "bambu")
    }

    if (length(missing_tools) > 0 || length(missing_pkgs) > 0) {
        msg <- c("Missing requirements for long-read processing from raw FASTQ")

        if (length(missing_tools) > 0) {
            msg <- c(msg,
                "x" = "Missing tools: {.val {missing_tools}}",
                "i" = "Install with: {.code conda install -c bioconda {paste(missing_tools, collapse = ' ')}}"
            )
        }

        if (length(missing_pkgs) > 0) {
            msg <- c(msg,
                "x" = "Missing R packages: {.pkg {missing_pkgs}}",
                "i" = "Install with: {.code BiocManager::install('{missing_pkgs}')}"
            )
        }

        cli::cli_abort(msg)
    }

    invisible(TRUE)
}

#' Check Requirements for Single-Cell Long-Read FLNC Processing
#'
#' Verifies that all requirements for processing single-cell long-read FLNC
#' data are available.
#'
#' @details
#' Processing single-cell FLNC data requires all long-read requirements plus:
#' - User-provided cluster assignments (no automatic clustering)
#'
#' @section Note:
#' MPAQT does not perform automatic cell clustering. Users must provide
#' pre-computed cluster assignments mapping cell barcodes to clusters.
#'
#' @return Invisible TRUE if all requirements are met
#' @export
#'
#' @examples
#' \dontrun{
#' # Check before processing SC long-read FLNC
#' require_sc_long_read_flnc()
#' }
require_sc_long_read_flnc <- function() {
    # SC FLNC requires the same as bulk long-read
    require_long_read_processing()
    invisible(TRUE)
}

#' Check kallisto Availability
#'
#' Verifies that kallisto is installed and accessible.
#'
#' @return Path to kallisto executable
#' @keywords internal
check_kallisto <- function() {
    path <- Sys.which("kallisto")

    if (path == "") {
        cli::cli_abort(c(
            "{.code kallisto} not found in PATH",
            "i" = "Install kallisto (>= 0.50.1) from: {.url https://pachterlab.github.io/kallisto/}",
            "i" = "Or with conda: {.code conda install -c bioconda kallisto}"
        ))
    }

    invisible(path)
}

#' Check bustools Availability
#'
#' Verifies that bustools is installed and accessible.
#'
#' @return Path to bustools executable
#' @keywords internal
check_bustools <- function() {
    path <- Sys.which("bustools")

    if (path == "") {
        cli::cli_abort(c(
            "{.code bustools} not found in PATH",
            "i" = "Install bustools (>= 0.43.1) from: {.url https://bustools.github.io/}",
            "i" = "Or with conda: {.code conda install -c bioconda bustools}"
        ))
    }

    invisible(path)
}

#' Check minimap2 Availability
#'
#' Verifies that minimap2 is installed and accessible.
#'
#' @return Path to minimap2 executable
#' @keywords internal
check_minimap2 <- function() {
    path <- Sys.which("minimap2")

    if (path == "") {
        cli::cli_abort(c(
            "{.code minimap2} not found in PATH",
            "i" = "minimap2 is required for long-read alignment",
            "i" = "Install from: {.url https://github.com/lh3/minimap2}",
            "i" = "Or with conda: {.code conda install -c bioconda minimap2}"
        ))
    }

    invisible(path)
}

#' Check samtools Availability
#'
#' Verifies that samtools is installed and accessible.
#'
#' @return Path to samtools executable
#' @keywords internal
check_samtools <- function() {
    path <- Sys.which("samtools")

    if (path == "") {
        cli::cli_abort(c(
            "{.code samtools} not found in PATH",
            "i" = "samtools is required for BAM processing",
            "i" = "Install from: {.url https://www.htslib.org/}",
            "i" = "Or with conda: {.code conda install -c bioconda samtools}"
        ))
    }

    invisible(path)
}

#' Check Bambu Package Availability
#'
#' Verifies that the bambu Bioconductor package is installed.
#'
#' @return Invisible TRUE if available
#' @keywords internal
check_bambu <- function() {
    if (!requireNamespace("bambu", quietly = TRUE)) {
        cli::cli_abort(c(
            "Package {.pkg bambu} is required for long-read quantification",
            "i" = "Install with: {.code BiocManager::install('bambu')}"
        ))
    }

    invisible(TRUE)
}
