# Tests for mpaqt_quant_result S3 class

test_that("new_mpaqt_quant_result creates valid object", {
  abundances <- c(100, 200, 50)
  names(abundances) <- c("tx1", "tx2", "tx3")

  tpm <- abundances * 1e6 / sum(abundances)

  result <- new_mpaqt_quant_result(
    abundances = abundances,
    tpm = tpm,
    log_likelihood = -1000.5,
    converged = TRUE,
    iterations = 50,
    fitted_values = c(10, 20, 30),
    prior_variance = 0.5
  )

  expect_s3_class(result, "mpaqt_quant_result")
  expect_true(result$converged)
  expect_equal(result$iterations, 50L)
  expect_equal(attr(result, "n_transcripts"), 3)
})

test_that("print.mpaqt_quant_result works", {
  abundances <- c(100, 200, 50)
  names(abundances) <- c("tx1", "tx2", "tx3")

  result <- new_mpaqt_quant_result(
    abundances = abundances,
    tpm = abundances * 1e6 / sum(abundances),
    log_likelihood = -1000.5,
    converged = TRUE,
    iterations = 50,
    fitted_values = c(10, 20, 30),
    prior_variance = 0.5
  )

  # cli output may not be captured by expect_output
  expect_no_error(print(result))
})

test_that("summary.mpaqt_quant_result works", {
  abundances <- c(100, 200, 50)
  names(abundances) <- c("tx1", "tx2", "tx3")

  result <- new_mpaqt_quant_result(
    abundances = abundances,
    tpm = abundances * 1e6 / sum(abundances),
    log_likelihood = -1000.5,
    converged = TRUE,
    iterations = 50,
    fitted_values = c(10, 20, 30),
    prior_variance = 0.5
  )

  expect_output(summary(result), "Summary")
})

test_that("tpm extractor works", {
  abundances <- c(100, 200, 50)
  names(abundances) <- c("tx1", "tx2", "tx3")

  expected_tpm <- abundances * 1e6 / sum(abundances)

  result <- new_mpaqt_quant_result(
    abundances = abundances,
    tpm = expected_tpm,
    log_likelihood = -1000.5,
    converged = TRUE,
    iterations = 50,
    fitted_values = c(10, 20, 30),
    prior_variance = 0.5
  )

  expect_equal(tpm(result), expected_tpm)
})

test_that("abundances extractor works", {
  abundances <- c(100, 200, 50)
  names(abundances) <- c("tx1", "tx2", "tx3")

  result <- new_mpaqt_quant_result(
    abundances = abundances,
    tpm = abundances * 1e6 / sum(abundances),
    log_likelihood = -1000.5,
    converged = TRUE,
    iterations = 50,
    fitted_values = c(10, 20, 30),
    prior_variance = 0.5
  )

  expect_equal(abundances(result), abundances)
})

test_that("coef method works", {
  abundances <- c(100, 200, 50)
  names(abundances) <- c("tx1", "tx2", "tx3")

  result <- new_mpaqt_quant_result(
    abundances = abundances,
    tpm = abundances * 1e6 / sum(abundances),
    log_likelihood = -1000.5,
    converged = TRUE,
    iterations = 50,
    fitted_values = c(10, 20, 30),
    prior_variance = 0.5
  )

  expect_equal(coef(result), abundances)
})

test_that("fitted method works", {
  abundances <- c(100, 200, 50)
  names(abundances) <- c("tx1", "tx2", "tx3")

  fitted_vals <- c(10, 20, 30)

  result <- new_mpaqt_quant_result(
    abundances = abundances,
    tpm = abundances * 1e6 / sum(abundances),
    log_likelihood = -1000.5,
    converged = TRUE,
    iterations = 50,
    fitted_values = fitted_vals,
    prior_variance = 0.5
  )

  expect_equal(fitted(result), fitted_vals)
})

test_that("validate_mpaqt_quant_result catches invalid objects", {
  expect_error(
    validate_mpaqt_quant_result(list(a = 1)),
    "Expected"
  )

  # Missing components
  bad_result <- structure(
    list(abundances = c(1, 2)),
    class = c("mpaqt_quant_result", "list")
  )
  expect_error(
    validate_mpaqt_quant_result(bad_result),
    "missing"
  )
})
