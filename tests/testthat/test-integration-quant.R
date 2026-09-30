# Integration tests for quantification workflow
# Tests for pre-quant, post-quant, and combined quantification

test_that("validate_bias_type accepts valid types", {
    expect_silent(validate_bias_type("3p"))
    expect_silent(validate_bias_type("5p"))
    expect_silent(validate_bias_type(NULL))  # NULL is valid (no bias correction)

    expect_error(
        validate_bias_type("invalid"),
        "Invalid"
    )
})

test_that("validate_prior_model accepts valid priors", {
    # NULL is valid (no prior)
    expect_silent(validate_prior_model(NULL))

    # String priors
    expect_silent(validate_prior_model("shrinkage"))
    expect_silent(validate_prior_model("long_read"))

    # List priors
    expect_silent(validate_prior_model(list(mean = c(1, 2, 3))))
    expect_silent(validate_prior_model(list(mean = c(1, 2), precision = c(0.1, 0.2))))

    # Invalid strings
    expect_error(
        validate_prior_model("invalid_prior"),
        "Invalid"
    )
})

test_that("validate_normalize accepts valid methods", {
    expect_silent(validate_normalize("tpm"))
    expect_silent(validate_normalize("depth"))
    expect_silent(validate_normalize("none"))

    expect_error(
        validate_normalize("invalid"),
        "Invalid"
    )
})

test_that("new_mpaqt_prequant creates valid object", {
    prequant <- new_mpaqt_prequant(
        weights = rep(1, 10),
        quantiles = seq(0, 1, length.out = 11),
        bias_type = "3p",
        n_bins = 10,
        converged = TRUE,
        iterations = 5,
        initial_beta = setNames(c(100, 200), c("tx1", "tx2"))
    )

    expect_s3_class(prequant, "mpaqt_prequant")
    expect_equal(prequant$n_bins, 10)
    expect_equal(prequant$bias_type, "3p")
    expect_true(prequant$converged)
})

test_that("validate_mpaqt_prequant checks required fields", {
    valid_prequant <- new_mpaqt_prequant(
        weights = rep(1, 10),
        quantiles = seq(0, 1, length.out = 11),
        bias_type = "3p",
        n_bins = 10,
        converged = TRUE,
        iterations = 5,
        initial_beta = c(100, 200)
    )

    expect_silent(validate_mpaqt_prequant(valid_prequant))

    # Invalid object
    expect_error(
        validate_mpaqt_prequant(list(weights = c(1, 2))),
        "Expected"
    )
})

test_that("new_mpaqt_quant_result creates valid object", {
    result <- new_mpaqt_quant_result(
        abundances = setNames(c(100, 200, 300), c("tx1", "tx2", "tx3")),
        tpm = setNames(c(166.67, 333.33, 500.00), c("tx1", "tx2", "tx3")),
        log_likelihood = -1000,
        converged = TRUE,
        iterations = 50,
        fitted_values = c(10, 20, 30),
        prior_variance = 0.5
    )

    expect_s3_class(result, "mpaqt_quant_result")
    expect_true(result$converged)
    expect_equal(result$iterations, 50)
    expect_equal(attr(result, "n_transcripts"), 3)
})

test_that("tpm extractor works correctly", {
    result <- new_mpaqt_quant_result(
        abundances = setNames(c(100, 200), c("tx1", "tx2")),
        tpm = setNames(c(333.33, 666.67), c("tx1", "tx2")),
        log_likelihood = -500,
        converged = TRUE,
        iterations = 25,
        fitted_values = c(5, 10),
        prior_variance = 0.3
    )

    extracted_tpm <- tpm(result)
    expect_equal(length(extracted_tpm), 2)
    expect_equal(names(extracted_tpm), c("tx1", "tx2"))
})

test_that("abundances extractor works correctly", {
    result <- new_mpaqt_quant_result(
        abundances = setNames(c(100, 200), c("tx1", "tx2")),
        tpm = setNames(c(333.33, 666.67), c("tx1", "tx2")),
        log_likelihood = -500,
        converged = TRUE,
        iterations = 25,
        fitted_values = c(5, 10),
        prior_variance = 0.3
    )

    extracted_abundances <- abundances(result)
    expect_equal(sum(extracted_abundances), 300)
})

test_that("coef.mpaqt_quant_result returns abundances", {
    result <- new_mpaqt_quant_result(
        abundances = setNames(c(50, 100, 150), c("tx1", "tx2", "tx3")),
        tpm = setNames(c(166.67, 333.33, 500.00), c("tx1", "tx2", "tx3")),
        log_likelihood = -800,
        converged = TRUE,
        iterations = 30,
        fitted_values = c(1, 2, 3),
        prior_variance = 0.4
    )

    coefs <- coef(result)
    expect_equal(coefs, result$abundances)
})

test_that("fitted.mpaqt_quant_result returns fitted values", {
    fitted_vals <- c(10, 20, 30)
    result <- new_mpaqt_quant_result(
        abundances = setNames(c(100, 200, 300), c("tx1", "tx2", "tx3")),
        tpm = setNames(c(166.67, 333.33, 500.00), c("tx1", "tx2", "tx3")),
        log_likelihood = -900,
        converged = TRUE,
        iterations = 40,
        fitted_values = fitted_vals,
        prior_variance = 0.2
    )

    expect_equal(fitted(result), fitted_vals)
})

test_that("validate_mpaqt_quant_result checks required components", {
    valid_result <- new_mpaqt_quant_result(
        abundances = setNames(c(100), c("tx1")),
        tpm = setNames(c(1000000), c("tx1")),
        log_likelihood = -100,
        converged = TRUE,
        iterations = 10,
        fitted_values = c(5),
        prior_variance = 0.1
    )

    expect_silent(validate_mpaqt_quant_result(valid_result))

    # Invalid object
    expect_error(
        validate_mpaqt_quant_result(list(abundances = c(100))),
        "Expected"
    )
})

test_that("has_uncertainty checks uncertainty field", {
    # Result without uncertainty
    result_no_unc <- new_mpaqt_quant_result(
        abundances = setNames(c(100), c("tx1")),
        tpm = setNames(c(1000000), c("tx1")),
        log_likelihood = -100,
        converged = TRUE,
        iterations = 10,
        fitted_values = c(5),
        prior_variance = 0.1
    )

    expect_false(has_uncertainty(result_no_unc))

    # Result with uncertainty
    result_with_unc <- new_mpaqt_quant_result(
        abundances = setNames(c(100), c("tx1")),
        tpm = setNames(c(1000000), c("tx1")),
        log_likelihood = -100,
        converged = TRUE,
        iterations = 10,
        fitted_values = c(5),
        prior_variance = 0.1
    )
    result_with_unc$uncertainty <- c(0.05)

    expect_true(has_uncertainty(result_with_unc))
})

test_that("normalize_abundances computes correct TPM", {
    abundances <- c(100, 200, 300)

    result <- normalize_abundances(abundances, "tpm")

    # TPM should sum to 1e6
    expect_equal(sum(result$tpm), 1e6)

    # Proportions should be correct
    expect_equal(result$tpm[1] / result$tpm[3], 100 / 300)
})

test_that("combine_quant_results creates correct matrix", {
    result1 <- new_mpaqt_quant_result(
        abundances = setNames(c(100, 200), c("tx1", "tx2")),
        tpm = setNames(c(333333, 666667), c("tx1", "tx2")),
        log_likelihood = -100,
        converged = TRUE,
        iterations = 10,
        fitted_values = c(1, 2),
        prior_variance = 0.1
    )

    result2 <- new_mpaqt_quant_result(
        abundances = setNames(c(50, 150), c("tx1", "tx2")),
        tpm = setNames(c(250000, 750000), c("tx1", "tx2")),
        log_likelihood = -120,
        converged = TRUE,
        iterations = 12,
        fitted_values = c(1, 2),
        prior_variance = 0.2
    )

    combined <- combine_quant_results(
        result1, result2, sample_names = c("sample1", "sample2")
    )

    expect_s3_class(combined, "data.table")
    expect_equal(ncol(combined), 3)  # transcript_id + 2 samples
    expect_equal(nrow(combined), 2)  # 2 transcripts
    expect_true("sample1" %in% names(combined))
    expect_true("sample2" %in% names(combined))
})

test_that("print.mpaqt_quant_result shows correct information", {
    result <- new_mpaqt_quant_result(
        abundances = setNames(c(100, 200), c("tx1", "tx2")),
        tpm = setNames(c(333333, 666667), c("tx1", "tx2")),
        log_likelihood = -500,
        converged = TRUE,
        iterations = 50,
        fitted_values = c(1, 2),
        prior_variance = 0.3,
        positional_weights = rep(1, 10),
        positional_bias_type = "3p",
        lr_coverage_probs = c(0.8, 0.9)
    )

    # print methods return invisible
    expect_invisible(print(result))
    # Just check that print doesn't error
    expect_no_error(print(result))
})
