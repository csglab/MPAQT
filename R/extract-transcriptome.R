# Extract transcriptome sequences from GTF and genome
# This module enables indexing without a pre-built transcriptome FASTA

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c(
    "type", "seqnames", "start", "end", "strand", "transcript_id",
    "exon_order", "seq", "sequence"
))

#' Extract Transcriptome Sequences from GTF and Genome
#'
#' Extracts transcript sequences by combining exon coordinates from a GTF
#' annotation file with genome sequences from a BSgenome object. This allows
#' creating an MPAQT index without a pre-existing transcriptome FASTA file.
#'
#' @param gtf_path Path to GTF annotation file
#' @param genome BSgenome object or character string naming a BSgenome package
#'   (e.g., "BSgenome.Hsapiens.UCSC.hg38")
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return A DNAStringSet containing transcript sequences, named by transcript_id
#'
#' @details
#' The function:
#' 1. Imports GTF and extracts exon coordinates per transcript
#' 2. Orders exons 5' to 3' based on strand

#' 3. Extracts and concatenates exon sequences from the genome
#' 4. Reverse complements sequences for minus-strand transcripts
#'
#' This is useful when you have a GTF annotation and genome but no pre-built
#' transcriptome FASTA file.
#'
#' @section BSgenome Installation:
#' BSgenome packages must be installed from Bioconductor:
#' ```
#' BiocManager::install("BSgenome.Hsapiens.UCSC.hg38")
#' ```
#'
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Using BSgenome object name
#' seqs <- extract_transcriptome_from_gtf(
#'     gtf_path = "annotation.gtf",
#'     genome = "BSgenome.Hsapiens.UCSC.hg38"
#' )
#'
#' # Using loaded BSgenome object
#' library(BSgenome.Hsapiens.UCSC.hg38)
#' seqs <- extract_transcriptome_from_gtf(
#'     gtf_path = "annotation.gtf",
#'     genome = BSgenome.Hsapiens.UCSC.hg38
#' )
#' }
extract_transcriptome_from_gtf <- function(gtf_path, genome, verbose = TRUE) {
    # Check required Bioconductor packages
    require_bioc("Biostrings", "for sequence manipulation")
    require_bioc("rtracklayer", "to parse GTF annotation")
    require_bioc("GenomicRanges", "for genomic coordinate operations")
    require_bioc("BSgenome", "to access genome sequences")

    # Validate GTF
    validate_gtf(gtf_path)

    # Load genome if string provided
    genome_obj <- load_bsgenome(genome)

    if (verbose) {
        cli::cli_h2("Extracting Transcriptome from GTF + Genome")
        cli::cli_alert_info("GTF: {.path {basename(gtf_path)}}")
        cli::cli_alert_info("Genome: {.val {genome_obj@pkgname}}")
    }

    # Import GTF
    if (verbose) cli::cli_progress_step("Importing GTF annotation")

    gtf <- rtracklayer::import(gtf_path)
    gtf_dt <- data.table::as.data.table(gtf)

    # Get exon coordinates grouped by transcript
    if (verbose) cli::cli_progress_step("Extracting exon coordinates")

    exons <- gtf_dt[type == "exon", .(
        seqnames = as.character(seqnames),
        start = as.integer(start),
        end = as.integer(end),
        strand = as.character(strand),
        transcript_id = transcript_id
    )]

    if (nrow(exons) == 0) {
        cli::cli_abort(c(
            "No exon features found in GTF",
            "i" = "Check that the GTF contains 'exon' entries in the type column"
        ))
    }

    n_transcripts <- length(unique(exons$transcript_id))
    if (verbose) {
        cli::cli_alert_info("Found {.val {nrow(exons)}} exons for {.val {n_transcripts}} transcripts")
    }

    # Validate chromosome names match genome
    gtf_chroms <- unique(exons$seqnames)
    genome_chroms <- GenomicRanges::seqnames(genome_obj)
    missing_chroms <- setdiff(gtf_chroms, genome_chroms)

    if (length(missing_chroms) > 0) {
        # Try common chromosome name transformations
        if (all(grepl("^chr", genome_chroms)) && !any(grepl("^chr", gtf_chroms))) {
            # GTF uses 1,2,3 but genome uses chr1,chr2,chr3
            if (verbose) cli::cli_alert_info("Adding 'chr' prefix to match genome chromosomes")
            exons[, seqnames := paste0("chr", seqnames)]
        } else if (!any(grepl("^chr", genome_chroms)) && all(grepl("^chr", gtf_chroms))) {
            # GTF uses chr1 but genome uses 1
            if (verbose) cli::cli_alert_info("Removing 'chr' prefix to match genome chromosomes")
            exons[, seqnames := gsub("^chr", "", seqnames)]
        }

        # Re-check after transformation
        gtf_chroms <- unique(exons$seqnames)
        missing_chroms <- setdiff(gtf_chroms, genome_chroms)

        if (length(missing_chroms) > 0) {
            n_affected <- nrow(exons[seqnames %in% missing_chroms])
            cli::cli_warn(c(
                "{length(missing_chroms)} chromosome{?s} in GTF not found in genome",
                "i" = "Missing: {.val {head(missing_chroms, 5)}}{if(length(missing_chroms) > 5) '...' else ''}",
                "i" = "{n_affected} exons will be skipped"
            ))
            exons <- exons[!seqnames %in% missing_chroms]
        }
    }

    # Order exons within each transcript (5' to 3')
    if (verbose) cli::cli_progress_step("Ordering exons by position")

    exons[strand == "+" | strand == "*", exon_order := rank(start), by = transcript_id]
    exons[strand == "-", exon_order := rank(-start), by = transcript_id]
    data.table::setorder(exons, transcript_id, exon_order)

    # Extract sequences for each exon
    if (verbose) cli::cli_progress_step("Extracting exon sequences from genome")

    exons[, seq := BSgenome::getSeq(
        genome_obj,
        names = seqnames,
        start = start,
        end = end,
        as.character = TRUE
    )]

    # Check for any failed extractions
    failed <- exons[is.na(seq) | seq == ""]
    if (nrow(failed) > 0) {
        cli::cli_warn(c(
            "{nrow(failed)} exons could not be extracted",
            "i" = "These may be outside chromosome boundaries"
        ))
        exons <- exons[!is.na(seq) & seq != ""]
    }

    # Concatenate exon sequences per transcript
    if (verbose) cli::cli_progress_step("Assembling transcript sequences")

    transcript_seqs <- exons[, .(
        sequence = paste(seq, collapse = ""),
        strand = strand[1]
    ), by = transcript_id]

    # Reverse complement for minus strand transcripts
    if (verbose) cli::cli_progress_step("Reverse complementing minus-strand transcripts")

    n_minus <- sum(transcript_seqs$strand == "-")
    if (n_minus > 0) {
        transcript_seqs[strand == "-", sequence := as.character(
            Biostrings::reverseComplement(Biostrings::DNAStringSet(sequence))
        )]
        if (verbose) {
            cli::cli_alert_info("Reverse complemented {.val {n_minus}} minus-strand transcripts")
        }
    }

    # Create DNAStringSet
    seqs <- Biostrings::DNAStringSet(transcript_seqs$sequence)
    names(seqs) <- transcript_seqs$transcript_id

    if (verbose) {
        cli::cli_progress_done()
        cli::cli_alert_success("Extracted {.val {length(seqs)}} transcript sequences")

        # Summary statistics
        lens <- Biostrings::width(seqs)
        cli::cli_alert_info("Length range: {.val {min(lens)}} - {.val {max(lens)}} bp")
        cli::cli_alert_info("Median length: {.val {median(lens)}} bp")
    }

    seqs
}

#' Load BSgenome Object
#'
#' Helper to load a BSgenome object from either a loaded object or package name.
#'
#' @param genome BSgenome object or character package name
#'
#' @return BSgenome object
#' @keywords internal
load_bsgenome <- function(genome) {
    require_bioc("BSgenome", "to access genome sequences")

    # If already a BSgenome object, return it
    if (inherits(genome, "BSgenome")) {
        return(genome)
    }

    # If character, try to load the package
    if (is.character(genome)) {
        # Check if it's a valid BSgenome package name
        if (!grepl("^BSgenome\\.", genome)) {
            cli::cli_abort(c(
                "Invalid genome specification: {.val {genome}}",
                "i" = "Provide a BSgenome package name (e.g., 'BSgenome.Hsapiens.UCSC.hg38')",
                "i" = "Or a loaded BSgenome object"
            ))
        }

        # Check if package is installed
        if (!requireNamespace(genome, quietly = TRUE)) {
            cli::cli_abort(c(
                "BSgenome package not installed: {.pkg {genome}}",
                "i" = "Install with: {.code BiocManager::install('{genome}')}",
                "i" = "Available genomes: {.code BSgenome::available.genomes()}"
            ))
        }

        # Load and return the genome object
        # BSgenome packages export an object with the same name as the package
        genome_obj <- tryCatch(
            get(genome, asNamespace(genome)),
            error = function(e) {
                cli::cli_abort(c(
                    "Could not load genome from package: {.pkg {genome}}",
                    "i" = "Error: {e$message}"
                ))
            }
        )

        return(genome_obj)
    }

    cli::cli_abort(c(
        "Invalid genome argument",
        "i" = "Provide a BSgenome object or package name string"
    ))
}

#' Write Transcriptome to FASTA File
#'
#' Helper function to write extracted transcriptome sequences to a FASTA file.
#'
#' @param seqs DNAStringSet of transcript sequences
#' @param output_path Path for output FASTA file
#' @param compress Compress output with gzip (default: FALSE)
#'
#' @return Invisible output path
#' @keywords internal
write_transcriptome_fasta <- function(seqs, output_path, compress = FALSE) {
    require_bioc("Biostrings", "to write FASTA file")

    if (compress && !grepl("\\.gz$", output_path)) {
        output_path <- paste0(output_path, ".gz")
    }

    Biostrings::writeXStringSet(seqs, output_path, compress = compress)

    invisible(output_path)
}
