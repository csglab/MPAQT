# Algorithm: Newton-Raphson optimization
# Transcript abundance update calculations

#' Compute Newton-Raphson update for a transcript
#'
#' Calculate the optimal update delta for a single transcript's abundance
#' using Newton-Raphson optimization with optional regularization.
#'
#' @param transcript_idx Transcript index
#' @param index mpaqt_index object
#' @param beta Current transcript abundances
#' @param y Current expected EC counts
#' @param sr_counts Short-read EC counts
#' @param lr_counts Long-read transcript counts
#' @param lr_probs Long-read coverage probabilities
#' @param positional_weights Positional bias weights
#' @param bias_type "3p" or "5p"
#' @param bin_assignments List of bin assignments per transcript
#' @param iter Current iteration
#' @param use_prior Whether to use prior regularization
#' @param prior_mean Prior mean for this transcript
#' @param prior_var Prior variance
#' @param quantiles Global distance quantiles (computed once from index$distances)
#'
#' @return List with delta update and bin indices
#' @keywords internal
compute_newton_update <- function(
    transcript_idx,
    index,
    beta,
    y,
    sr_counts,
    lr_counts,
    lr_probs,
    positional_weights,
    bias_type,
    bin_assignments,
    iter,
    use_regularization,
    use_prior,
    prior_mean,
    prior_var,
    quantiles = NULL
) {
    # Get P matrix data for this transcript
    p_data <- index$p_matrices[[transcript_idx]]
    ec_idx <- p_data$i
    probs <- p_data$x

    # Get observed and expected counts
    obs <- sr_counts[ec_idx]
    exp <- y[ec_idx]

    # Handle positional weights
    weights <- NULL
    bin_idx <- NULL

    if (!is.null(positional_weights)) {
        if (iter == 1) {
            # Compute bin assignments on first iteration
            if (bias_type == "3p" && "dist_3p" %in% names(p_data)) {
                distances <- p_data$dist_3p
            } else if (bias_type == "5p" && "dist_5p" %in% names(p_data)) {
                distances <- p_data$dist_5p
            } else {
                distances <- NULL
            }

            if (!is.null(distances) && !is.null(quantiles)) {
                # Use global quantiles (computed once from index$distances)
                bin_idx <- cut(distances, breaks = quantiles, labels = FALSE, include.lowest = TRUE)
                bin_idx[is.na(bin_idx)] <- 1
                weights <- positional_weights[bin_idx]
            } else {
                weights <- rep(1, length(probs))
                bin_idx <- rep(1, length(probs))
            }
        } else {
            # Use cached bin assignments
            bin_idx <- bin_assignments[[transcript_idx]]
            if (!is.null(bin_idx)) {
                weights <- positional_weights[bin_idx]
            } else {
                weights <- rep(1, length(probs))
            }
        }
    } else {
        weights <- rep(1, length(probs))
    }

    # Add long-read contribution
    has_lr <- lr_counts[transcript_idx] > 0
    if (has_lr) {
        obs <- c(obs, lr_counts[transcript_idx])
        exp <- c(exp, beta[transcript_idx] * lr_probs[transcript_idx])
        probs <- c(probs, lr_probs[transcript_idx])
        weights <- c(weights, 1)  # No positional bias for long reads
    }

    # Compute update
    if (iter == 1) {
        # First iteration: Gaussian approximation (more stable near zero)
        # delta = sum((n - y) * P * w) / sum((P * w)^2)
        weighted_probs <- probs * weights
        residuals <- obs - exp
        delta <- sum(residuals * weighted_probs) / sum(weighted_probs^2)
    } else {
        # Subsequent iterations: Newton-Raphson with Poisson likelihood
        delta <- compute_regularized_newton_step(
            obs = obs,
            exp = exp,
            probs = probs,
            weights = weights,
            current_beta = beta[transcript_idx],
            use_regularization = use_regularization,
            prior_mean = prior_mean,
            prior_var = prior_var
        )
    }

    list(delta = delta, weights = weights[seq_along(p_data$x)], bin_idx = bin_idx)
}

#' Compute regularized Newton step
#'
#' Calculate Newton-Raphson step with optional L2 regularization.
#'
#' @param obs Observed counts
#' @param exp Expected counts
#' @param probs Probability values
#' @param weights Positional weights
#' @param current_beta Current abundance
#' @param use_regularization Whether to apply L2 regularization on log(beta)
#' @param prior_mean Prior mean (global or transcript-specific)
#' @param prior_var Prior variance
#'
#' @return Delta update value
#' @keywords internal
compute_regularized_newton_step <- function(
    obs,
    exp,
    probs,
    weights,
    current_beta,
    use_regularization,
    prior_mean,
    prior_var
) {
    eps <- 1e-30

    # Gradient and Hessian of Poisson likelihood
    ratio <- (obs + eps) / (exp + eps)
    weighted_probs <- probs * weights

    # g = sum(P * w * (1 - n/y))
    gradient <- sum(weighted_probs * (1 - ratio))

    # H = sum(n * (P * w / y)^2)
    hessian <- sum((obs + eps) * (weighted_probs / (exp + eps))^2)

    # Unregularized Newton step
    delta_unreg <- -gradient / hessian

    if (!use_regularization || current_beta <= 0) {
        return(delta_unreg)
    }

    # Add regularization terms
    log_beta <- log(current_beta)

    # Regularization gradient: (log(beta) - mu) / (beta * sigma^2)
    gradient <- gradient + (log_beta - prior_mean) / (current_beta * prior_var)

    # Regularization Hessian: (-log(beta) + mu + 1) / (beta^2 * sigma^2)
    hessian <- hessian + (-log_beta + prior_mean + 1) / (current_beta^2 * prior_var)

    # Regularized Newton step
    delta <- -gradient / hessian

    # Prior mode update for comparison
    delta_prior <- exp(prior_mean) - current_beta

    # Check if Newton step is reasonable
    delta_min <- min(delta_unreg, delta_prior)
    delta_max <- max(delta_unreg, delta_prior)

    if (delta < delta_min || delta > delta_max) {
        # Use bounded optimization
        lower <- max(-current_beta + eps, delta_min)
        upper <- max(-current_beta + eps, delta_max)

        obj_fn <- function(x) {
            new_beta <- current_beta + x
            # Regularization penalty
            reg <- (log(new_beta) - prior_mean)^2 / (2 * prior_var)
            # Poisson NLL
            new_exp <- exp + weighted_probs * x
            nll <- sum(new_exp - obs * log(new_exp + eps))
            reg + nll
        }

        result <- stats::optimize(obj_fn, c(lower, upper))
        delta <- result$minimum
    }

    delta
}
