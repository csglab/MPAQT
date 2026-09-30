args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 4L) {
    stop(
        "Usage: run-index-smoke.R ANNOTATION_GTF TRANSCRIPTOME_FASTA OUTPUT_DIR INSTALLATION",
        call. = FALSE
    )
}

annotation <- normalizePath(args[[1L]], mustWork = TRUE)
transcriptome <- normalizePath(args[[2L]], mustWork = TRUE)
output_dir <- normalizePath(args[[3L]], mustWork = FALSE)
installation <- args[[4L]]

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
temp_dir <- file.path(output_dir, "tmp")
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
index_path <- file.path(output_dir, "toy.mpaqt.idx")

library(mpaqt)

stopifnot(as.character(utils::packageVersion("mpaqt")) == "2.4.0")
stopifnot(requireNamespace("Biostrings", quietly = TRUE))
stopifnot(requireNamespace("rtracklayer", quietly = TRUE))
stopifnot(nzchar(Sys.which("kallisto")))
stopifnot(nzchar(Sys.which("bustools")))
stopifnot(!nzchar(Sys.which("mpaqt")))

package_description <- utils::packageDescription("mpaqt")
remote_sha <- package_description[["RemoteSha"]]
if (is.null(remote_sha) || !nzchar(remote_sha)) {
    remote_sha <- "not-recorded"
}

cat("Installation:", installation, "\n")
cat("MPAQT version:", as.character(utils::packageVersion("mpaqt")), "\n")
cat("MPAQT RemoteSha:", remote_sha, "\n")
cat("R version:", R.version.string, "\n")
cat("Biostrings version:", as.character(utils::packageVersion("Biostrings")), "\n")
cat("rtracklayer version:", as.character(utils::packageVersion("rtracklayer")), "\n")
cat(system2("kallisto", "version", stdout = TRUE, stderr = TRUE), sep = "\n")
cat(system2("bustools", "version", stdout = TRUE, stderr = TRUE), sep = "\n")

index <- mpaqt_index(
    annotation = annotation,
    transcriptome = transcriptome,
    output_file = index_path,
    read_length = 75L,
    stride = 1L,
    threads = 1L,
    chunk_size = 150L,
    temp_dir = temp_dir,
    keep_temp = FALSE,
    verbose = TRUE
)

stopifnot(file.exists(index_path))
stopifnot(file.info(index_path)$size > 0)
stopifnot(inherits(index, "mpaqt_index"))
stopifnot(identical(sort(index$transcripts), paste0("tx", 1:4)))
stopifnot(length(index$genes) == 4L)
stopifnot(identical(sort(unique(index$genes)), c("gene1", "gene2")))
stopifnot(length(index$ec_ids) > 0L)
stopifnot(length(index$p_matrices) == 4L)
stopifnot(all(vapply(index$p_matrices, nrow, integer(1L)) > 0L))
stopifnot(nrow(index$covariates) == 4L)
stopifnot(nrow(index$distances) > 0L)
stopifnot(all(dim(index$t2g_matrix) == c(4L, 2L)))
stopifnot(is.raw(index$kallisto_binary))
stopifnot(length(index$kallisto_binary) > 0L)
stopifnot(isTRUE(attr(index, "bundled")))

reloaded <- mpaqt_read_index(index_path)
stopifnot(inherits(reloaded, "mpaqt_index"))
stopifnot(identical(index$transcripts, reloaded$transcripts))
stopifnot(identical(index$genes, reloaded$genes))

manifest <- c(
    paste0("installation=", installation),
    paste0("mpaqt_version=", utils::packageVersion("mpaqt")),
    paste0("remote_sha=", remote_sha),
    paste0("transcripts=", length(index$transcripts)),
    paste0("genes=", length(unique(index$genes))),
    paste0("equivalence_classes=", length(index$ec_ids)),
    paste0("index_file=", normalizePath(index_path))
)
writeLines(manifest, file.path(output_dir, "PASS.txt"))

cat("\nPASS:", installation, "completed mpaqt_index() successfully\n")
