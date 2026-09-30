# Tests for positional bias functions

test_that("init_positional_bias creates valid initialization", {
  # Create mock distance data
  distances <- data.table::data.table(
    dist_3p = runif(100, 0, 1000),
    dist_5p = runif(100, 0, 1000)
  )

  result <- init_positional_bias(
    distances = distances,
    bias_type = "3p",
    n_bins = 10
  )

  expect_type(result, "list")
  expect_named(result, c("quantiles", "weights", "bias_type", "n_bins"))
  expect_length(result$weights, 10)
  expect_length(result$quantiles, 11)  # n_bins + 1 quantiles
  expect_equal(result$bias_type, "3p")
  expect_equal(result$n_bins, 10)

  # Weights should be initialized to 1
  expect_true(all(result$weights == 1))
})

test_that("init_positional_bias handles 5p bias", {
  distances <- data.table::data.table(
    dist_3p = runif(100, 0, 1000),
    dist_5p = runif(100, 0, 1000)
  )

  result <- init_positional_bias(
    distances = distances,
    bias_type = "5p",
    n_bins = 20
  )

  expect_equal(result$bias_type, "5p")
  expect_length(result$weights, 20)
})

test_that("init_positional_bias handles NA values", {
  distances <- data.table::data.table(
    dist_3p = c(runif(90, 0, 1000), rep(NA, 10)),
    dist_5p = runif(100, 0, 1000)
  )

  # Should not error - NAs should be replaced with median
  result <- init_positional_bias(
    distances = distances,
    bias_type = "3p",
    n_bins = 10
  )

  expect_type(result, "list")
  expect_length(result$weights, 10)
})

test_that("init_positional_bias errors on missing column", {
  distances <- data.table::data.table(
    dist_3p = runif(100, 0, 1000)
    # dist_5p is missing
  )

  expect_error(
    init_positional_bias(distances, "5p", 10),
    "not found"
  )
})
