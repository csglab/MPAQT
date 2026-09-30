# Tests for validation functions

test_that("validate_file_exists catches missing files", {
    expect_error(
        validate_file_exists("/nonexistent/path/file.txt"),
        "not found"
    )
})

test_that("validate_file_exists accepts existing files", {
    # Use a file we know exists
    temp_file <- tempfile()
    writeLines("test", temp_file)
    on.exit(unlink(temp_file))

    expect_invisible(validate_file_exists(temp_file))
})

test_that("validate_output_dir creates directories", {
    temp_dir <- file.path(tempdir(), "test_mpaqt_dir")
    on.exit(unlink(temp_dir, recursive = TRUE))

    expect_invisible(validate_output_dir(temp_dir, create = TRUE))
    expect_true(dir.exists(temp_dir))
})

test_that("validate_bias_params catches invalid types", {
    expect_error(
        validate_bias_params("invalid", 50),
        "Invalid"
    )

    expect_invisible(validate_bias_params("3p", 50))
    expect_invisible(validate_bias_params("5p", 100))
})

test_that("validate_technology catches invalid values", {
    expect_error(
        validate_technology("invalid_tech"),
        "Invalid"
    )

    expect_equal(validate_technology("bulk"), "bulk")
    expect_equal(validate_technology("10xv2"), "10xv2")
    expect_equal(validate_technology("10xv3"), "10xv3")
})

test_that("detect_short_read_input works correctly", {
    expect_equal(detect_short_read_input(rds_file = "test.rds"), "rds")
    expect_equal(detect_short_read_input(fastq_1 = "r1.fq", fastq_2 = "r2.fq"), "fastq")
    expect_equal(detect_short_read_input(fastq_1 = "r1.fq"), "fastq_single")
    expect_error(detect_short_read_input(), "No short-read input")
})

test_that("detect_long_read_input works correctly", {
    expect_equal(detect_long_read_input(rds_file = "test.rds"), "rds")
    expect_equal(detect_long_read_input(counts_file = "counts.csv"), "csv")
    expect_equal(detect_long_read_input(), "none")
})
