# Tests for Newton-Raphson algorithm functions

test_that("compute_regularized_newton_step computes valid update", {
  obs <- c(10, 20, 30)
  exp <- c(12, 18, 32)
  probs <- c(0.5, 0.3, 0.2)
  weights <- c(1, 1, 1)
  current_beta <- 100

  delta <- compute_regularized_newton_step(
    obs = obs,
    exp = exp,
    probs = probs,
    weights = weights,
    current_beta = current_beta,
    use_regularization = FALSE,
    prior_mean = 0,
    prior_var = 1
  )

  expect_true(is.numeric(delta))
  expect_length(delta, 1)
  expect_false(is.na(delta))
  expect_false(is.infinite(delta))
})

test_that("compute_regularized_newton_step handles regularization", {
  obs <- c(10, 20, 30)
  exp <- c(12, 18, 32)
  probs <- c(0.5, 0.3, 0.2)
  weights <- c(1, 1, 1)
  current_beta <- 100

  # Without regularization
  delta_unreg <- compute_regularized_newton_step(
    obs = obs,
    exp = exp,
    probs = probs,
    weights = weights,
    current_beta = current_beta,
    use_regularization = FALSE,
    prior_mean = 0,
    prior_var = 1
  )

  # With regularization
  delta_reg <- compute_regularized_newton_step(
    obs = obs,
    exp = exp,
    probs = probs,
    weights = weights,
    current_beta = current_beta,
    use_regularization = TRUE,
    prior_mean = log(current_beta),  # Prior at current value
    prior_var = 1
  )

  # Both should be finite
  expect_true(is.finite(delta_unreg))
  expect_true(is.finite(delta_reg))
})

test_that("compute_regularized_newton_step handles edge cases", {
  # Very small expected counts
  delta <- compute_regularized_newton_step(
    obs = c(1, 2, 3),
    exp = c(0.001, 0.002, 0.003),
    probs = c(0.5, 0.3, 0.2),
    weights = c(1, 1, 1),
    current_beta = 0.01,
    use_regularization = FALSE,
    prior_mean = 0,
    prior_var = 1
  )

  expect_true(is.finite(delta))
})
