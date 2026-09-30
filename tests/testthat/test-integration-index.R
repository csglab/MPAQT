# Integration tests for indexing workflow
# Tests the three indexing pathways: FASTA, genome (BSgenome), and pre-built

test_that("detect_index_pathway returns correct pathways", {
    # Create temp files for testing
    temp_fasta <- tempfile(fileext = ".fa")
    writeLines(">transcript1\nATCG", temp_fasta)

    temp_kallisto <- tempfile(fileext = ".idx")
    file.create(temp_kallisto)

    # Test FASTA pathway
    result <- detect_index_pathway(
        transcriptome = temp_fasta,
        kallisto_index = NULL,
        genome = NULL
    )
    expect_equal(result, "fasta")

    # Test prebuilt pathway (requires both kallisto_index and transcriptome)
    result <- detect_index_pathway(
        transcriptome = temp_fasta,
        kallisto_index = temp_kallisto,
        genome = NULL
    )
    expect_equal(result, "prebuilt")

    # Test that prebuilt without transcriptome throws error
    expect_error(
        detect_index_pathway(
            transcriptome = NULL,
            kallisto_index = temp_kallisto,
            genome = NULL
        ),
        "requires transcriptome"
    )

    # Test genome pathway
    result <- detect_index_pathway(
        transcriptome = NULL,
        kallisto_index = NULL,
        genome = "BSgenome.Hsapiens.UCSC.hg38"
    )
    expect_equal(result, "genome")

    # Test error when nothing provided
    expect_error(
        detect_index_pathway(
            transcriptome = NULL,
            kallisto_index = NULL,
            genome = NULL
        ),
        "Invalid input"
    )

    # Cleanup
    unlink(c(temp_fasta, temp_kallisto))
})

test_that("is_bundled_index correctly identifies bundled indices", {
    # Create a non-bundled index
    mock_index <- structure(
        list(
            transcripts = c("tx1", "tx2"),
            ec_ids = c("ec1", "ec2"),
            kallisto_index = "/path/to/index.idx",
            kallisto_binary = NULL
        ),
        class = c("mpaqt_index", "list"),
        bundled = FALSE
    )

    expect_false(is_bundled_index(mock_index))

    # Create a bundled index
    mock_bundled <- structure(
        list(
            transcripts = c("tx1", "tx2"),
            ec_ids = c("ec1", "ec2"),
            kallisto_index = NULL,
            kallisto_binary = raw(100)
        ),
        class = c("mpaqt_index", "list"),
        bundled = TRUE
    )

    expect_true(is_bundled_index(mock_bundled))
})

test_that("validate_gtf checks GTF file existence", {
    # Non-existent file
    expect_error(
        validate_gtf("/nonexistent/file.gtf"),
        "not found"
    )

    # Create a valid GTF file
    temp_gtf <- tempfile(fileext = ".gtf")
    writeLines(
        'chr1\ttest\texon\t1\t100\t.\t+\t.\ttranscript_id "tx1"; gene_id "gene1";',
        temp_gtf
    )

    expect_silent(validate_gtf(temp_gtf))

    unlink(temp_gtf)
})

test_that("load_bsgenome validates BSgenome package names", {
    skip_if_not_installed("BSgenome")

    # Invalid package name
    expect_error(
        load_bsgenome("invalid_name"),
        "Invalid genome specification"
    )

    # Non-existent BSgenome package
    expect_error(
        load_bsgenome("BSgenome.Fake.Species"),
        "not installed"
    )
})

test_that("new_mpaqt_index creates valid index object", {
    mock_index <- new_mpaqt_index(
        transcripts = c("tx1", "tx2", "tx3"),
        genes = c("gene1", "gene1", "gene2"),
        ec_ids = c("0,1", "1,2", "2"),
        p_matrices = list(
            list(i = 1:2, x = c(0.5, 0.5)),
            list(i = 2:3, x = c(0.3, 0.7)),
            list(i = 3, x = 1)
        ),
        kallisto_index = NULL,
        gtf_annotation = "/path/to/annotation.gtf"
    )

    expect_s3_class(mock_index, "mpaqt_index")
    expect_equal(length(mock_index$transcripts), 3)
    expect_equal(length(mock_index$genes), 3)
    expect_equal(length(mock_index$ec_ids), 3)
})

test_that("print.mpaqt_index works correctly", {
    mock_index <- new_mpaqt_index(
        transcripts = c("tx1", "tx2"),
        genes = c("gene1", "gene2"),
        ec_ids = c("0", "1"),
        p_matrices = list(
            list(i = 1, x = 1),
            list(i = 2, x = 1)
        ),
        kallisto_index = "/path/to/index.idx"
    )

    # Should not error, print returns invisible
    expect_no_error(print(mock_index))
    expect_invisible(print(mock_index))
})
