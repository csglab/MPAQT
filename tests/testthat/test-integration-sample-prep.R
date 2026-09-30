# Integration tests for sample preparation workflows
# Tests for short-read and long-read preparation pathways

test_that("detect_sr_pathway returns correct pathways", {
    # Create temp files
    temp_fastq1 <- tempfile(fileext = ".fastq.gz")
    temp_fastq2 <- tempfile(fileext = ".fastq.gz")
    temp_bus <- tempfile(fileext = ".bus")
    temp_ec <- tempfile(fileext = ".ec")
    temp_rds <- tempfile(fileext = ".rds")

    # Create dummy files
    file.create(temp_fastq1, temp_fastq2, temp_bus, temp_ec)
    saveRDS(list(test = TRUE), temp_rds)

    # Test RDS pathway (highest priority)
    result <- detect_sr_pathway(
        fastq_1 = temp_fastq1,
        fastq_2 = temp_fastq2,
        bus_file = temp_bus,
        ec_file = temp_ec,
        rds_file = temp_rds
    )
    expect_equal(result, "rds")

    # Test BUS pathway
    result <- detect_sr_pathway(
        fastq_1 = temp_fastq1,
        fastq_2 = temp_fastq2,
        bus_file = temp_bus,
        ec_file = temp_ec,
        rds_file = NULL
    )
    expect_equal(result, "bus")

    # Test FASTQ pathway
    result <- detect_sr_pathway(
        fastq_1 = temp_fastq1,
        fastq_2 = temp_fastq2,
        bus_file = NULL,
        ec_file = NULL,
        rds_file = NULL
    )
    expect_equal(result, "fastq")

    # Test error when nothing provided
    expect_error(
        detect_sr_pathway(
            fastq_1 = NULL,
            fastq_2 = NULL,
            bus_file = NULL,
            ec_file = NULL,
            rds_file = NULL
        ),
        "No valid"
    )

    # Cleanup
    unlink(c(temp_fastq1, temp_fastq2, temp_bus, temp_ec, temp_rds))
})

test_that("detect_lr_pathway returns correct pathways", {
    # Create temp files
    temp_flnc <- tempfile(fileext = ".fastq.gz")
    temp_counts <- tempfile(fileext = ".csv")
    temp_rds <- tempfile(fileext = ".rds")

    file.create(temp_flnc)
    writeLines("transcript_id,count\ntx1,100", temp_counts)
    saveRDS(list(test = TRUE), temp_rds)

    # Test RDS pathway
    result <- detect_lr_pathway(
        flnc_fastq = temp_flnc,
        bambu_counts = temp_counts,
        rds_file = temp_rds
    )
    expect_equal(result, "rds")

    # Test Bambu pathway
    result <- detect_lr_pathway(
        flnc_fastq = temp_flnc,
        bambu_counts = temp_counts,
        rds_file = NULL
    )
    expect_equal(result, "bambu")

    # Test FLNC pathway
    result <- detect_lr_pathway(
        flnc_fastq = temp_flnc,
        bambu_counts = NULL,
        rds_file = NULL
    )
    expect_equal(result, "flnc")

    # Test none pathway (all NULL is valid - LR is optional)
    result <- detect_lr_pathway(
        flnc_fastq = NULL,
        bambu_counts = NULL,
        rds_file = NULL
    )
    expect_equal(result, "none")

    # Cleanup
    unlink(c(temp_flnc, temp_counts, temp_rds))
})

test_that("new_mpaqt_counts_sr creates valid object", {
    counts <- new_mpaqt_counts_sr(
        counts = setNames(c(100, 200, 300), c("ec1", "ec2", "ec3")),
        technology = "bulk",
        sample_id = "test_sample"
    )

    expect_s3_class(counts, "mpaqt_counts_sr")
    expect_equal(sum(counts$counts), 600)
    expect_equal(counts$sample_id, "test_sample")
    expect_equal(counts$technology, "bulk")
})

test_that("new_mpaqt_counts_lr creates valid object", {
    counts <- new_mpaqt_counts_lr(
        counts = setNames(c(10, 20, 30), c("tx1", "tx2", "tx3")),
        sample_id = "test_lr_sample"
    )

    expect_s3_class(counts, "mpaqt_counts_lr")
    expect_equal(sum(counts$counts), 60)
    expect_equal(counts$sample_id, "test_lr_sample")
})

test_that("mpaqt_read_short_read_counts handles legacy format", {
    # Create legacy format (plain named vector)
    temp_rds <- tempfile(fileext = ".rds")
    legacy_counts <- setNames(c(100, 200), c("ec1", "ec2"))
    saveRDS(legacy_counts, temp_rds)

    # Should convert automatically
    result <- mpaqt_read_short_read_counts(temp_rds)
    expect_s3_class(result, "mpaqt_counts_sr")
    expect_equal(sum(result$counts), 300)

    unlink(temp_rds)
})

test_that("mpaqt_read_long_read_counts handles legacy format", {
    # Create legacy format
    temp_rds <- tempfile(fileext = ".rds")
    legacy_counts <- setNames(c(10, 20), c("tx1", "tx2"))
    saveRDS(legacy_counts, temp_rds)

    # Should convert automatically
    result <- mpaqt_read_long_read_counts(temp_rds)
    expect_s3_class(result, "mpaqt_counts_lr")
    expect_equal(sum(result$counts), 30)

    unlink(temp_rds)
})

test_that("validate_technology accepts valid technologies", {
    expect_silent(validate_technology("bulk"))
    expect_silent(validate_technology("10xv2"))
    expect_silent(validate_technology("10xv3"))
    expect_silent(validate_technology("10xv4"))

    expect_error(
        validate_technology("invalid_tech"),
        "Invalid"
    )
})

test_that("validate_bus_ec_compatibility checks EC count match", {
    skip("Requires actual BUS file parsing")
    # This test would require creating valid BUS/EC files
    # which is complex without the actual binary format
})

test_that("match_lr_counts_to_index handles missing transcripts", {
    counts <- setNames(c(10, 20, 30), c("tx1", "tx2", "tx_missing"))
    index_transcripts <- c("tx1", "tx2", "tx3", "tx4")

    result <- match_lr_counts_to_index(counts, index_transcripts)

    expect_equal(length(result), 4)
    expect_equal(names(result), index_transcripts)
    expect_equal(result["tx1"], c(tx1 = 10))
    expect_equal(result["tx2"], c(tx2 = 20))
    expect_equal(result["tx3"], c(tx3 = 0))  # Missing in counts
    expect_equal(result["tx4"], c(tx4 = 0))  # Missing in counts
})
