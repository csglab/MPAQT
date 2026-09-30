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

test_that("normalize_p_matrices_for_umi returns normalized working copy", {
    set.seed(1)
    index <- mock_mpaqt_index(n_transcripts = 4, n_ec = 8)
    original_sums <- vapply(index$p_matrices, function(p_data) sum(p_data$x), numeric(1))

    normalized_index <- normalize_p_matrices_for_umi(index)
    normalized_sums <- vapply(normalized_index$p_matrices, function(p_data) sum(p_data$x), numeric(1))
    post_call_sums <- vapply(index$p_matrices, function(p_data) sum(p_data$x), numeric(1))

    expect_s3_class(normalized_index, "mpaqt_index")
    expect_equal(unname(normalized_sums), rep(1, length(normalized_sums)), tolerance = 1e-12)
    expect_equal(post_call_sums, original_sums)
})

test_that("post UMI normalization happens after positional weighting", {
    index <- structure(
        list(
            transcripts = "tx1",
            genes = "gene1",
            ec_ids = c("ec1", "ec2"),
            p_matrices = list(
                tx1 = data.table::data.table(
                    i = c(1L, 2L),
                    x = c(2, 1),
                    dist_3p = c(10, 90),
                    dist_5p = c(10, 90)
                )
            ),
            distances = data.table::data.table(
                ec_tr_id = c("ec1,tx1", "ec2,tx1"),
                tr_id = "tx1",
                dist_3p = c(10, 90),
                dist_5p = c(10, 90)
            )
        ),
        class = c("mpaqt_index", "list")
    )

    sr_counts <- c(ec1 = 10, ec2 = 20)
    weights <- c(1, 3)

    post_result <- run_em_algorithm(
        index = index,
        sr_counts = sr_counts,
        positional_weights = weights,
        bias_type = "3p",
        post_weight_umi_correction = TRUE,
        max_iter = 1L,
        verbose = FALSE
    )

    manual_index <- index
    manual_index$p_matrices[[1]] <- data.table::copy(index$p_matrices[[1]])
    manual_index$p_matrices[[1]][, x := c(0.4, 0.6)]

    manual_result <- run_em_algorithm(
        index = manual_index,
        sr_counts = sr_counts,
        max_iter = 1L,
        verbose = FALSE
    )

    pre_result <- run_em_algorithm(
        index = normalize_p_matrices_for_umi(index),
        sr_counts = sr_counts,
        positional_weights = weights,
        bias_type = "3p",
        max_iter = 1L,
        verbose = FALSE
    )

    expect_equal(post_result$abundances, manual_result$abundances, tolerance = 1e-12)
    expect_equal(post_result$fitted_values, manual_result$fitted_values, tolerance = 1e-12)
    expect_gt(abs(post_result$abundances[[1]] - pre_result$abundances[[1]]), 1e-6)
})

test_that("mpaqt_postquant stores umi correction flag", {
    set.seed(2)
    index <- mock_mpaqt_index(n_transcripts = 4, n_ec = 8)
    sr_counts <- mock_short_read_counts(index)
    default_umi_timing <- eval(formals(mpaqt_postquant)$umi_correction_timing)

    result <- mpaqt_postquant(
        index = index,
        sr_counts = sr_counts,
        max_iter = 2L,
        convergence_start = 1L,
        verbose = FALSE
    )

    expect_false(isTRUE(result$parameters$do_umi_correction))
    expect_equal(result$parameters$umi_correction_timing, default_umi_timing)
})

test_that("validate_umi_correction_timing rejects invalid values", {
    expect_error(
        validate_umi_correction_timing("late"),
        "umi_correction_timing"
    )
})

test_that("mpaqt_quant_sc enables umi correction by default", {
    set.seed(3)
    index <- mock_mpaqt_index(n_transcripts = 4, n_ec = 8)
    sr_counts_list <- list(cluster1 = mock_short_read_counts(index))

    results <- mpaqt_quant_sc(
        index = index,
        sr_counts_list = sr_counts_list,
        max_iter = 2L,
        convergence_start = 1L,
        verbose = FALSE
    )

    expect_true(isTRUE(results[["cluster1"]]$parameters$do_umi_correction))
})

test_that("mpaqt_quant_sc allows disabling umi correction", {
    set.seed(4)
    index <- mock_mpaqt_index(n_transcripts = 4, n_ec = 8)
    sr_counts_list <- list(cluster1 = mock_short_read_counts(index))

    results <- mpaqt_quant_sc(
        index = index,
        sr_counts_list = sr_counts_list,
        do_umi_correction = FALSE,
        max_iter = 2L,
        convergence_start = 1L,
        verbose = FALSE
    )

    expect_false(isTRUE(results[["cluster1"]]$parameters$do_umi_correction))
})
