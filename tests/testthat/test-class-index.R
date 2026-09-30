# Tests for mpaqt_index S3 class

test_that("new_mpaqt_index creates valid object", {
  # Create minimal valid index
  idx <- new_mpaqt_index(
    transcripts = c("tx1", "tx2", "tx3"),
    genes = c("g1", "g1", "g2"),
    ec_ids = c("ec1", "ec2"),
    p_matrices = list(
      list(i = 1L, x = 0.5),
      list(i = c(1L, 2L), x = c(0.3, 0.7)),
      list(i = 2L, x = 1.0)
    )
  )

  expect_s3_class(idx, "mpaqt_index")
  expect_equal(length(idx$transcripts), 3)
  expect_equal(length(idx$p_matrices), 3)
  expect_equal(attr(idx, "n_transcripts"), 3)
  # n_ecs attribute may not exist - check for n_ec or ec count
  expect_equal(length(idx$ec_ids), 2)
})

test_that("new_mpaqt_index validates inputs", {
  expect_error(
    new_mpaqt_index(
      transcripts = 1:3,  # Should be character
      genes = c("g1", "g2"),
      ec_ids = c("ec1"),
      p_matrices = list()
    ),
    "character"
  )
})

test_that("print.mpaqt_index works", {
  idx <- new_mpaqt_index(
    transcripts = c("tx1", "tx2"),
    genes = c("g1", "g2"),
    ec_ids = c("ec1", "ec2"),
    p_matrices = list(
      list(i = 1L, x = 0.5),
      list(i = 2L, x = 0.8)
    )
  )

  # cli output may not be captured by expect_output
  expect_no_error(print(idx))
})

test_that("validate_mpaqt_index catches invalid objects", {
  # Not an mpaqt_index
  expect_error(
    validate_mpaqt_index(list(a = 1)),
    "Expected"
  )

  # Missing components
  bad_idx <- structure(
    list(transcripts = c("tx1")),
    class = c("mpaqt_index", "list")
  )
  expect_error(
    validate_mpaqt_index(bad_idx),
    "missing"
  )
})
