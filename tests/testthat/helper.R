# Test helper functions and fixtures

#' Skip test if kallisto is not available
skip_if_no_kallisto <- function() {
    if (Sys.which("kallisto") == "") {
        testthat::skip("kallisto not available")
    }
}

#' Skip test if bustools is not available
skip_if_no_bustools <- function() {
    if (Sys.which("bustools") == "") {
        testthat::skip("bustools not available")
    }
}

#' Skip test if external tools are not available
skip_if_no_tools <- function() {
    skip_if_no_kallisto()
    skip_if_no_bustools()
}

#' Get path to test fixtures directory
fixture_path <- function(...) {
    system.file("testdata", ..., package = "mpaqt", mustWork = FALSE)
}

#' Skip test if testdata is not available (excluded from package build)
skip_if_no_testdata <- function() {
    path <- fixture_path()
    if (!nzchar(path) || !dir.exists(path)) {
        testthat::skip("testdata not available (excluded from package)")
    }
}

#' Create a temporary test directory
test_temp_dir <- function() {
    dir <- tempfile("mpaqt_test_")
    dir.create(dir, recursive = TRUE)
    dir
}

#' Create a minimal mock mpaqt_index for testing
mock_mpaqt_index <- function(n_transcripts = 10, n_ec = 20) {
    transcripts <- paste0("ENST", sprintf("%05d", seq_len(n_transcripts)))
    genes <- paste0("ENSG", sprintf("%05d", rep(seq_len(n_transcripts / 2), each = 2)))
    ec_ids <- paste0(seq_len(n_ec) - 1, ",", sample(seq_len(n_transcripts) - 1, n_ec, replace = TRUE))

    # Create simple P matrices
    p_matrices <- lapply(seq_len(n_transcripts), function(j) {
        n_entries <- sample(3:8, 1)
        data.table::data.table(
            i = sample(seq_len(n_ec), n_entries),
            x = runif(n_entries, 0.1, 1),
            dist_5p = runif(n_entries, 0, 100),
            dist_3p = runif(n_entries, 0, 100)
        )
    })
    names(p_matrices) <- transcripts

    structure(
        list(
            transcripts = transcripts,
            genes = genes,
            ec_ids = ec_ids,
            p_matrices = p_matrices,
            covariates = matrix(
                c(runif(n_transcripts, 0.3, 0.7), log(runif(n_transcripts, 500, 5000))),
                ncol = 2,
                dimnames = list(transcripts, c("gc_ratio", "log_length"))
            ),
            distances = data.table::data.table(
                ec_tr_id = sample(ec_ids, n_transcripts * 3, replace = TRUE),
                tr_id = sample(transcripts, n_transcripts * 3, replace = TRUE),
                dist_5p = runif(n_transcripts * 3, 0, 100),
                dist_3p = runif(n_transcripts * 3, 0, 100)
            ),
            t2g = NULL,
            g2t = NULL,
            t2g_norm = NULL
        ),
        class = c("mpaqt_index", "list"),
        n_transcripts = n_transcripts,
        n_genes = length(unique(genes)),
        n_ec = n_ec,
        created = Sys.time()
    )
}

#' Create mock short-read counts
mock_short_read_counts <- function(index) {
    counts <- rpois(length(index$ec_ids), lambda = 100)
    names(counts) <- index$ec_ids

    structure(
        list(
            counts = counts,
            technology = "bulk",
            sample_id = "test_sample"
        ),
        class = c("mpaqt_counts_sr", "mpaqt_counts", "list"),
        n_reads = sum(counts),
        n_ec = length(counts)
    )
}

#' Create mock long-read counts
mock_long_read_counts <- function(index) {
    counts <- rpois(length(index$transcripts), lambda = 10)
    names(counts) <- index$transcripts

    structure(
        list(
            counts = counts,
            sample_id = "test_sample"
        ),
        class = c("mpaqt_counts_lr", "mpaqt_counts", "list"),
        n_reads = sum(counts),
        n_transcripts = length(counts)
    )
}
