# Tests for mpaqt_counts S3 classes

test_that("new_mpaqt_counts_sr creates valid object", {
  counts <- c(10, 20, 30)
  names(counts) <- c("ec1", "ec2", "ec3")

  sr <- new_mpaqt_counts_sr(
    counts = counts,
    technology = "bulk",
    sample_id = "sample1"
  )

  expect_s3_class(sr, "mpaqt_counts_sr")
  expect_s3_class(sr, "mpaqt_counts")
  expect_equal(length(sr$counts), 3)
  expect_equal(sr$sample_id, "sample1")
  expect_equal(attr(sr, "n_ec"), 3)  # attribute is n_ec not n_ecs
})

test_that("new_mpaqt_counts_lr creates valid object", {
  counts <- c(5, 15, 0, 25)
  names(counts) <- c("tx1", "tx2", "tx3", "tx4")

  lr <- new_mpaqt_counts_lr(
    counts = counts,
    sample_id = "sample1"
  )

  expect_s3_class(lr, "mpaqt_counts_lr")
  expect_s3_class(lr, "mpaqt_counts")
  expect_equal(length(lr$counts), 4)
  expect_equal(attr(lr, "n_transcripts"), 4)
})

test_that("counts class validation works", {
  counts <- c(10, 20, 30)
  names(counts) <- c("ec1", "ec2", "ec3")

  sr <- new_mpaqt_counts_sr(
    counts = counts,
    technology = "bulk",
    sample_id = "sample1"
  )

  expect_silent(validate_mpaqt_counts_sr(sr))

  expect_error(
    validate_mpaqt_counts_sr(list(a = 1)),
    "Expected"
  )
})

test_that("print methods work for counts", {
  counts <- c(10, 20, 30)
  names(counts) <- c("ec1", "ec2", "ec3")

  sr <- new_mpaqt_counts_sr(
    counts = counts,
    technology = "bulk",
    sample_id = "sample1"
  )

  # cli output may not be captured by expect_output, so just verify it runs
  expect_no_error(print(sr))

  lr_counts <- c(5, 15)
  names(lr_counts) <- c("tx1", "tx2")

  lr <- new_mpaqt_counts_lr(
    counts = lr_counts,
    sample_id = "sample1"
  )

  expect_no_error(print(lr))
})
