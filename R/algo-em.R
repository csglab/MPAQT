# Algorithm: EM algorithm for transcript quantification
# Core EM loop and likelihood computation

# Declare data.table column names to avoid R CMD check NOTEs
utils::globalVariables(c(
    "avg_distance", "range", "tr_index", "ec_index", "indices", "i", "x",
    "putbetat", "betat"
))

#' Run EM algorithm for transcript quantification
#'
#' Main EM algorithm that estimates transcript abundances from short-read
#' and optionally long-read RNA-seq data. This is an internal function
#' called by the main quantification API.
#'
#' @param index An mpaqt_index object
#' @param sr_counts Short-read EC counts (named numeric vector)
#' @param lr_counts Long-read transcript counts (optional)
#' @param positional_weights Positional bias weights (optional)
#' @param bias_type Type of positional bias ("3p" or "5p")
#' @param max_iter Maximum number of iterations
#' @param tolerance Convergence tolerance
#' @param use_prior Whether to use prior predictions
#' @param prior_predictions Prior mean for each transcript (optional)
#' @param prior_start Iteration to start using prior
#' @param convergence_start Iteration to start checking convergence
#' @param verbose Print progress
#'
#' @return List with quantification results
#' @keywords internal
run_em_algorithm <- function(
    index,
    sr_counts,
    lr_counts = NULL,
    positional_weights = NULL,
    bias_type = "3p",
    max_iter = 100L,
    tolerance = 1e-4,
    use_prior = FALSE,
    use_regularization = TRUE,
    prior_predictions = NULL,
    covariate_matrix = NULL,
    prior_start = 25L,
    convergence_start = 25L,
    verbose = TRUE
) {
    # Initialize variables
    n_transcripts <- length(index$p_matrices)
    n_ecs <- length(sr_counts)

    # Transcript abundances (beta)
    beta <- rep(0, n_transcripts)
    names(beta) <- index$transcripts

    # Expected EC counts
    y <- rep(0, n_ecs)

    # Long-read setup
    has_lr <- !is.null(lr_counts) && sum(lr_counts) > 0
    if (is.null(lr_counts)) {
        lr_counts <- rep(0, n_transcripts)
    }
    lr_probs <- rep(0, n_transcripts)
    lr_model <- NULL

    # Prior parameters
    prior_mean <- 0
    prior_var <- 1
    if (is.null(prior_predictions)) {
        prior_predictions <- rep(0, n_transcripts)
    }

    # Convergence tracking
    prev_ll <- NA
    ref_dll <- NA
    converged <- FALSE

    # Distance bin assignments (computed on first iteration)
    bin_assignments <- vector("list", n_transcripts)

    # Compute global distance quantiles ONCE (before EM loop)
    # This matches the old implementation which computed quantiles from index$D
    distance_quantiles <- NULL
    if (!is.null(positional_weights) && !is.null(index$distances)) {
        n_bins <- length(positional_weights)
        dist_col <- if (bias_type == "3p") "dist_3p" else "dist_5p"
        if (dist_col %in% names(index$distances)) {
            distance_quantiles <- stats::quantile(
                index$distances[[dist_col]],
                probs = seq(0, 1, length.out = n_bins + 1),
                na.rm = TRUE
            )
        }
    }

    # Determine execution path: fast (no weights) vs weighted
    use_weights <- !is.null(positional_weights) && !is.null(index$distances)

    # Main EM loop
    for (iter in seq_len(max_iter)) {
        if (verbose) {
            cat(sprintf("\rIteration %3d/%3d |", iter, max_iter))
        }

        # E-step: Update transcript abundances
        if (!use_weights) {
            # ================================================================
            # FAST PATH: No positional weights - inline computation
            # ================================================================
            # This avoids: function call overhead, weight vector allocation,
            # wasteful multiplication by 1s, and list creation per transcript
            eps <- 1e-30

            for (j in seq_len(n_transcripts)) {
                p_data <- index$p_matrices[[j]]
                ec_idx <- p_data$i
                probs <- p_data$x

                obs <- sr_counts[ec_idx]
                exp_counts <- y[ec_idx]

                # Add long-read contribution
                if (has_lr && lr_counts[j] > 0) {
                    obs <- c(obs, lr_counts[j])
                    exp_counts <- c(exp_counts, beta[j] * lr_probs[j])
                    probs <- c(probs, lr_probs[j])
                }

                # Compute Newton-Raphson update
                if (iter == 1) {
                    # First iteration: Gaussian approximation (stable near zero)
                    residuals <- obs - exp_counts
                    delta <- sum(residuals * probs) / sum(probs^2)
                } else {
                    # Subsequent iterations: Poisson likelihood
                    ratio <- (obs + eps) / (exp_counts + eps)
                    gradient <- sum(probs * (1 - ratio))
                    hessian <- sum((obs + eps) * (probs / (exp_counts + eps))^2)
                    delta_unreg <- -gradient / hessian

                    # Apply regularization if enabled
                    if (use_regularization && beta[j] > 0) {
                        prior_mu <- if (use_prior && iter >= prior_start) {
                            prior_predictions[j]
                        } else {
                            prior_mean
                        }

                        log_beta <- log(beta[j])
                        gradient <- gradient + (log_beta - prior_mu) / (beta[j] * prior_var)
                        hessian <- hessian + (-log_beta + prior_mu + 1) / (beta[j]^2 * prior_var)
                        delta_reg <- -gradient / hessian
                        delta_prior <- exp(prior_mu) - beta[j]

                        delta_min <- min(delta_unreg, delta_prior)
                        delta_max <- max(delta_unreg, delta_prior)

                        if (delta_reg < delta_min || delta_reg > delta_max) {
                            # Bounded optimization
                            lower <- max(-beta[j] + eps, delta_min)
                            upper <- max(-beta[j] + eps, delta_max)

                            obj_fn <- function(x) {
                                new_beta <- beta[j] + x
                                reg <- (log(new_beta) - prior_mu)^2 / (2 * prior_var)
                                new_exp <- exp_counts + probs * x
                                nll <- sum(new_exp - obs * log(new_exp + eps))
                                reg + nll
                            }

                            delta <- stats::optimize(obj_fn, c(lower, upper))$minimum
                        } else {
                            delta <- delta_reg
                        }
                    } else {
                        delta <- delta_unreg
                    }
                }

                # Apply update with bounds
                if (is.na(delta) || is.infinite(delta)) delta <- 0
                delta <- max(-beta[j] + 1e-10, delta)

                beta[j] <- beta[j] + delta

                # Update expected counts (no weight multiplication needed)
                y[p_data$i] <- y[p_data$i] + p_data$x * delta
            }
        } else {
            # ================================================================
            # WEIGHT PATH: With positional weights - INLINED for performance
            # ================================================================
            # Avoids 38M function calls by inlining compute_newton_update()
            # and compute_regularized_newton_step() directly in the loop
            eps <- 1e-30
            dist_col <- if (bias_type == "3p") "dist_3p" else "dist_5p"

            for (j in seq_len(n_transcripts)) {
                p_data <- index$p_matrices[[j]]
                ec_idx <- p_data$i
                probs <- p_data$x

                obs <- sr_counts[ec_idx]
                exp_counts <- y[ec_idx]

                # Compute or retrieve positional weights
                if (iter == 1) {
                    # First iteration: compute bin assignments from distances
                    if (dist_col %in% names(p_data)) {
                        distances <- p_data[[dist_col]]
                        bin_idx <- cut(distances, breaks = distance_quantiles,
                                      labels = FALSE, include.lowest = TRUE)
                        bin_idx[is.na(bin_idx)] <- 1L
                    } else {
                        bin_idx <- rep(1L, length(probs))
                    }
                    bin_assignments[[j]] <- bin_idx
                    weights <- positional_weights[bin_idx]
                } else {
                    # Use cached bin assignments
                    bin_idx <- bin_assignments[[j]]
                    weights <- positional_weights[bin_idx]
                }

                # Add long-read contribution
                if (has_lr && lr_counts[j] > 0) {
                    obs <- c(obs, lr_counts[j])
                    exp_counts <- c(exp_counts, beta[j] * lr_probs[j])
                    probs <- c(probs, lr_probs[j])
                    weights <- c(weights, 1)  # No positional bias for LR
                }

                # Compute Newton-Raphson update
                weighted_probs <- probs * weights

                if (iter == 1) {
                    # First iteration: Gaussian approximation (stable near zero)
                    residuals <- obs - exp_counts
                    delta <- sum(residuals * weighted_probs) / sum(weighted_probs^2)
                } else {
                    # Subsequent iterations: Poisson likelihood with weights
                    ratio <- (obs + eps) / (exp_counts + eps)
                    gradient <- sum(weighted_probs * (1 - ratio))
                    hessian <- sum((obs + eps) * (weighted_probs / (exp_counts + eps))^2)
                    delta_unreg <- -gradient / hessian

                    # Apply regularization if enabled
                    if (use_regularization && beta[j] > 0) {
                        prior_mu <- if (use_prior && iter >= prior_start) {
                            prior_predictions[j]
                        } else {
                            prior_mean
                        }

                        log_beta <- log(beta[j])
                        gradient <- gradient + (log_beta - prior_mu) / (beta[j] * prior_var)
                        hessian <- hessian + (-log_beta + prior_mu + 1) / (beta[j]^2 * prior_var)
                        delta_reg <- -gradient / hessian
                        delta_prior <- exp(prior_mu) - beta[j]

                        delta_min <- min(delta_unreg, delta_prior)
                        delta_max <- max(delta_unreg, delta_prior)

                        if (delta_reg < delta_min || delta_reg > delta_max) {
                            # Bounded optimization
                            lower <- max(-beta[j] + eps, delta_min)
                            upper <- max(-beta[j] + eps, delta_max)

                            obj_fn <- function(x) {
                                new_beta <- beta[j] + x
                                reg <- (log(new_beta) - prior_mu)^2 / (2 * prior_var)
                                new_exp <- exp_counts + weighted_probs * x
                                nll <- sum(new_exp - obs * log(new_exp + eps))
                                reg + nll
                            }

                            delta <- stats::optimize(obj_fn, c(lower, upper))$minimum
                        } else {
                            delta <- delta_reg
                        }
                    } else {
                        delta <- delta_unreg
                    }
                }

                # Apply update with bounds
                if (is.na(delta) || is.infinite(delta)) delta <- 0
                delta <- max(-beta[j] + 1e-10, delta)

                beta[j] <- beta[j] + delta

                # Update expected counts with weights (SR only - LR was appended)
                n_sr <- length(p_data$x)
                y[ec_idx] <- y[ec_idx] + p_data$x * weights[seq_len(n_sr)] * delta
            }
        }

        # M-step: Update global parameters
        positive_beta <- beta[beta > 0]
        if (length(positive_beta) > 0) {
            log_beta <- log(positive_beta)

            if (!use_prior || iter < prior_start) {
                # Use global parameters when no prior or before prior_start
                prior_mean <- mean(log_beta)
                prior_var <- mean((log_beta - prior_mean)^2)
                # Ensure prior_var doesn't become 0 (would cause log(0) = -Inf in LL)
                prior_var <- max(prior_var, 1e-6)
            }
        }

        # Prior model integration (mixed-effects model with gene-level random effects)
        if (use_prior && iter >= prior_start && !is.null(covariate_matrix) &&
            !is.null(index$t2g_normalized)) {
            prior_update <- update_prior_predictions(
                transcript_abundances = beta,
                covariate_matrix = covariate_matrix,
                index = index,
                method = "gpboost",
                verbose = FALSE
            )
            prior_predictions <- prior_update$predictions
            prior_var <- prior_update$variance
            prior_var <- max(prior_var, 1e-6)
        }

        # Update long-read model
        if (has_lr) {
            lr_fit <- fit_long_read_model(
                lr_counts = lr_counts,
                beta = beta,
                covariates = index$covariates
            )
            lr_probs <- lr_fit$probs
            lr_model <- lr_fit$model
        }

        # Calculate log-likelihood
        y[y < 0] <- 0
        ll <- compute_log_likelihood(
            sr_counts = sr_counts,
            y = y,
            beta = beta,
            lr_counts = lr_counts,
            lr_probs = lr_probs,
            lr_model = lr_model,
            prior_var = prior_var,
            has_lr = has_lr
        )

        dll <- ll - prev_ll

        if (verbose) {
            cat(sprintf(" LL: %.4f | dLL: %.2e | sigma2: %.4f |", ll, dll, prior_var))
        }

        # Check convergence
        if (iter == 2) ref_dll <- dll

        if (!is.na(dll) && iter >= convergence_start) {
            if (dll > 0 && dll < tolerance) {
                converged <- TRUE
                if (verbose) cat("\nConverged at iteration", iter, "\n")
                break
            }
        }

        prev_ll <- ll
    }

    if (!converged && verbose) {
        cat("\nDid not converge within", max_iter, "iterations\n")
    }

    # Calculate TPM
    tpm <- beta * 1e6 / sum(beta)

    list(
        abundances = beta,
        tpm = tpm,
        log_likelihood = ll,
        converged = converged,
        iterations = iter,
        fitted_values = y,
        prior_variance = prior_var,
        lr_coverage_probs = if (has_lr) lr_probs else NULL,
        lr_model = lr_model,
        prior_predictions = if (use_prior) prior_predictions else NULL
    )
}

#' Compute log-likelihood
#'
#' @param sr_counts Short-read EC counts
#' @param y Expected EC counts
#' @param beta Transcript abundances
#' @param lr_counts Long-read counts
#' @param lr_probs Long-read coverage probabilities
#' @param lr_model Long-read GLM model
#' @param prior_var Prior variance
#' @param has_lr Whether long-reads are available
#'
#' @return Log-likelihood value
#' @keywords internal
compute_log_likelihood <- function(
    sr_counts,
    y,
    beta,
    lr_counts,
    lr_probs,
    lr_model,
    prior_var,
    has_lr
) {
    eps <- 1e-30

    # Short-read likelihood: sum(n * log(y) - y)
    ll <- sum(sr_counts * log(y + eps) - y)

    # Regularization: -(K/2) * log(sigma^2)
    n_positive <- sum(beta > 0)
    if (n_positive > 0) {
        ll <- ll - length(beta) / 2 * log(prior_var)
    }

    # Long-read likelihood
    if (has_lr) {
        lr_ll <- sum(lr_counts * log(beta * lr_probs + eps) - beta * lr_probs)
        # Check for numerical issues
        if (!is.finite(lr_ll)) lr_ll <- 0
        ll <- ll + lr_ll
        if (!is.null(lr_model)) {
            model_ll <- as.numeric(stats::logLik(lr_model))
            # Check for numerical issues in model log-likelihood
            if (is.finite(model_ll)) {
                ll <- ll + model_ll
            }
        }
    }

    ll
}

#' Fit long-read coverage model
#'
#' Fit Poisson GLM to estimate coverage probabilities from long-read counts.
#'
#' @param lr_counts Long-read transcript counts
#' @param beta Current transcript abundances
#' @param covariates Covariate matrix
#'
#' @return List with model and coverage probabilities
#' @keywords internal
fit_long_read_model <- function(lr_counts, beta, covariates) {
    if (is.null(covariates)) {
        # Simple model without covariates
        probs <- rep(1, length(beta))
        return(list(probs = probs, model = NULL))
    }

    # Ensure beta has a minimum value to avoid log(0) = -Inf in offset
    beta_safe <- pmax(beta, 1e-10)

    # Fit Poisson GLM: lr_counts ~ covariates with offset log(beta)
    model <- stats::glm(
        lr_counts ~ covariates + 0,
        offset = log(beta_safe),
        family = stats::poisson()
    )

    # P2 = exp(C * theta)
    probs <- exp(covariates %*% matrix(stats::coefficients(model), ncol = 1))

    list(probs = as.numeric(probs), model = model)
}
