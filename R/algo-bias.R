# Algorithm: Positional bias correction
# Functions for computing and optimizing positional bias weights

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c(
    "avg_distance", "range", "tr_index", "ec_index",
    "putbetat", "betat"
))

#' Initialize positional bias weights
#'
#' Create initial distance bins and weight vector for positional bias correction.
#'
#' @param distances Distance data.table from index
#' @param bias_type "3p" or "5p" bias type
#' @param n_bins Number of distance bins
#'
#' @return List with quantiles and initial weights
#' @keywords internal
init_positional_bias <- function(distances, bias_type, n_bins) {
    # Select appropriate distance column
    dist_col <- if (bias_type == "3p") "dist_3p" else "dist_5p"

    if (!dist_col %in% names(distances)) {
        cli::cli_abort(c(
            "Distance column not found: {.val {dist_col}}",
            "i" = "Check that index was created with distance information"
        ))
    }

    # Create distance bins using quantiles
    dist_values <- distances[[dist_col]]
    dist_values[is.na(dist_values)] <- 1

    quantiles <- stats::quantile(
        dist_values,
        probs = seq(0, 1, length.out = n_bins + 1)
    )

    # Initialize weights to 1 (no bias)
    weights <- rep(1, n_bins)

    list(
        quantiles = quantiles,
        weights = weights,
        bias_type = bias_type,
        n_bins = n_bins
    )
}

#' Optimize positional bias weights
#'
#' Update positional weights using L-BFGS-B optimization of the Poisson
#' likelihood.
#'
#' @param sr_counts Short-read EC counts
#' @param beta Current transcript abundances
#' @param index mpaqt_index object
#' @param current_weights Current positional weights
#' @param bias_type "3p" or "5p"
#' @param quantiles Distance quantiles for binning
#' @param verbose Print progress
#'
#' @return Updated positional weights
#' @keywords internal
optimize_positional_weights <- function(
    sr_counts,
    beta,
    index,
    current_weights,
    bias_type,
    quantiles,
    verbose = FALSE
) {
    n_bins <- length(current_weights)
    n_ecs <- length(sr_counts)

    # Build expected count matrix for each distance bin
    # S[i,k] = sum over j: beta[j] * P[i,j] for transcripts j in bin k
    si_mat <- build_expected_count_matrix(
        index = index,
        beta = beta,
        bias_type = bias_type,
        quantiles = quantiles,
        n_bins = n_bins,
        n_ecs = n_ecs
    )

    if (verbose) {
        cli::cli_alert_info("Expected count matrix range: [{round(min(si_mat), 4)}, {round(max(si_mat), 4)}]")
    }

    # Optimize weights using Poisson likelihood
    # L(w) = sum_i [n_i * log(sum_k w_k * S_ik) - sum_k w_k * S_ik]
    neg_log_lik <- function(log_w, X, y) {
        lambda <- X %*% exp(log_w)
        sum(lambda - y * log(lambda + 1e-30))
    }

    # L-BFGS-B with bounds
    result <- stats::optim(
        par = log(current_weights),
        fn = neg_log_lik,
        X = si_mat,
        y = sr_counts,
        method = "L-BFGS-B",
        lower = log(current_weights) - 1,
        upper = log(current_weights) + 1
    )

    # Extract and normalize weights
    weights <- exp(result$par)
    weights[weights < 1e-10] <- 1e-10

    # Normalize so first bin = 1
    weights <- weights / weights[1]

    if (verbose) {
        cli::cli_alert_info("Updated weights (first 10): {paste(round(weights[1:min(10, n_bins)], 3), collapse = ', ')}")
    }

    weights
}

#' Build expected count matrix for bias optimization
#'
#' @param index mpaqt_index object
#' @param beta Transcript abundances
#' @param bias_type "3p" or "5p"
#' @param quantiles Distance quantiles
#' @param n_bins Number of bins
#' @param n_ecs Number of equivalence classes
#'
#' @return Matrix of expected counts per EC and bin
#' @keywords internal
build_expected_count_matrix <- function(
    index,
    beta,
    bias_type,
    quantiles,
    n_bins,
    n_ecs
) {
    # Initialize matrix
    si_mat <- matrix(0, nrow = n_ecs, ncol = n_bins)

    dist_col <- if (bias_type == "3p") "dist_3p" else "dist_5p"

    # Process each transcript
    for (j in seq_along(index$p_matrices)) {
        p_data <- index$p_matrices[[j]]
        ec_idx <- p_data$i
        probs <- p_data$x

        # Get distances for this transcript
        if (dist_col %in% names(p_data)) {
            distances <- p_data[[dist_col]]
        } else {
            next
        }

        # Assign to bins
        bins <- cut(distances, breaks = quantiles, labels = FALSE, include.lowest = TRUE)
        bins[is.na(bins)] <- 1

        # Add contribution to each bin
        for (k in seq_len(n_bins)) {
            mask <- bins == k
            if (any(mask)) {
                si_mat[ec_idx[mask], k] <- si_mat[ec_idx[mask], k] + probs[mask] * beta[j]
            }
        }
    }

    si_mat
}

#' Recompute expected counts with positional weights
#'
#' @param index mpaqt_index object
#' @param beta Transcript abundances
#' @param weights Positional weights
#' @param bias_type "3p" or "5p"
#' @param quantiles Distance quantiles
#' @param n_ecs Number of equivalence classes
#'
#' @return Expected EC counts
#' @keywords internal
compute_weighted_expected_counts <- function(
    index,
    beta,
    weights,
    bias_type,
    quantiles,
    n_ecs
) {
    y <- rep(0, n_ecs)
    dist_col <- if (bias_type == "3p") "dist_3p" else "dist_5p"

    for (j in seq_along(index$p_matrices)) {
        p_data <- index$p_matrices[[j]]
        ec_idx <- p_data$i
        probs <- p_data$x

        # Get positional weights
        if (dist_col %in% names(p_data)) {
            distances <- p_data[[dist_col]]
            bins <- cut(distances, breaks = quantiles, labels = FALSE, include.lowest = TRUE)
            bins[is.na(bins)] <- 1
            w <- weights[bins]
        } else {
            w <- rep(1, length(probs))
        }

        y[ec_idx] <- y[ec_idx] + probs * w * beta[j]
    }

    y[y < 0] <- 0
    y
}
