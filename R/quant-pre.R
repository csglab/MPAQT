# Pre-Quantification Module
# Optional phase that computes positional bias weights before main quantification

#' Run Pre-Quantification Phase
#'
#' Compute positional bias weights (W) that model non-uniform read distribution
#' across transcripts. This is an optional phase that runs before the main
#' EM quantification.
#'
#' @param index An `mpaqt_index` object
#' @param sr_counts An `mpaqt_counts_sr` object with short-read EC counts
#' @param positional_bias Type of bias correction: "3p" or "5p"
#' @param n_bins Number of distance bins for bias estimation (default: 50)
#' @param max_iter Maximum iterations for weight optimization (default: 100)
#' @param tolerance Convergence tolerance (default: 1e-1)
#' @param weight_update_start Iteration to start updating positional weights (default: 20)
#' @param convergence_start Iteration to start checking convergence (default: 25)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return An `mpaqt_prequant` object containing:
#'   - `weights`: Estimated positional bias weights
#'   - `quantiles`: Distance bin boundaries
#'   - `bias_type`: Type of bias ("3p" or "5p")
#'   - `n_bins`: Number of bins used
#'   - `converged`: Whether optimization converged
#'   - `initial_beta`: Initial transcript abundance estimates
#'
#' @details
#' Pre-quantification estimates how read density varies with position along
#' transcripts. This is useful for correcting:
#'
#' - **3' bias**: Common in poly-A selected RNA-seq, where 3' ends have
#'   higher coverage
#' - **5' bias**: Can occur with certain library prep methods
#'
#' The weights are computed by:
#' 1. Running a preliminary EM to get initial abundance estimates
#' 2. Binning transcript positions by distance from 3'/5' end
#' 3. Optimizing bin weights to maximize Poisson likelihood
#'
#' @section When to Use:
#' Pre-quantification is recommended when:
#' - You observe strong positional bias in your data
#' - Transcript length varies significantly in your annotation
#' - You want more accurate short transcript quantification
#'
#' Skip pre-quantification when:
#' - Your library prep minimizes positional bias
#' - You're working with very short transcripts only
#' - Computational time is a concern
#'
#' @export
#'
#' @examples
#' \dontrun{
#' idx <- mpaqt_read_index("my_index/mpaqt.index.rds")
#' sr <- mpaqt_read_short_read_counts("short_read.rds")
#'
#' # Run pre-quantification with 3' bias correction
#' prequant <- mpaqt_prequant(
#'     index = idx,
#'     sr_counts = sr,
#'     positional_bias = "3p"
#' )
#'
#' # Use weights in post-quantification
#' result <- mpaqt_postquant(
#'     index = idx,
#'     sr_counts = sr,
#'     prequant = prequant
#' )
#' }
mpaqt_prequant <- function(
    index,
    sr_counts,
    positional_bias = "3p",
    n_bins = 50L,
    max_iter = 100L,
    tolerance = 1e-1,
    weight_update_start = 20L,
    convergence_start = 25L,
    verbose = TRUE
) {
    # Validate inputs
    if (is.character(index)) {
        index <- mpaqt_read_index(index)
    }
    validate_mpaqt_index(index)

    if (is.character(sr_counts)) {
        sr_counts <- mpaqt_read_short_read_counts(sr_counts)
    }
    validate_mpaqt_counts_sr(sr_counts)

    validate_bias_type(positional_bias)

    # Check distance data availability
    if (is.null(index$distances)) {
        cli::cli_abort(c(
            "Distance data not found in index",
            "i" = "Recreate index with distance information for bias correction"
        ))
    }

    if (verbose) {
        cli::cli_h1("MPAQT Pre-Quantification")
        cli::cli_alert_info("Bias type: {.val {positional_bias}}")
        cli::cli_alert_info("Number of bins: {.val {n_bins}}")
    }

    # Step 1: Initialize positional bias bins
    if (verbose) cli::cli_progress_step("Initializing distance bins")

    bias_init <- init_positional_bias(
        distances = index$distances,
        bias_type = positional_bias,
        n_bins = n_bins
    )
    quantiles <- bias_init$quantiles
    weights <- bias_init$weights

    sr_vec <- sr_counts$counts

    # Step 2: Run full EM with positional weight optimization
    # This matches mpaqt-dev which integrates weight updates into the EM loop
    if (verbose) cli::cli_progress_step("Running EM with positional weight optimization")

    result <- run_prequant_em(
        index = index,
        sr_counts = sr_vec,
        positional_weights = weights,
        bias_type = positional_bias,
        quantiles = quantiles,
        n_bins = n_bins,
        max_iter = max_iter,
        tolerance = tolerance,
        weight_update_start = weight_update_start,
        convergence_start = convergence_start,
        verbose = verbose
    )

    weights <- result$positional_weights
    initial_beta <- result$beta
    converged <- result$converged
    iterations <- result$iterations

    if (verbose) {
        n_expressed <- sum(initial_beta > 0)
        cli::cli_alert_info("{n_expressed} expressed transcripts")
    }

    # Create result object
    prequant <- new_mpaqt_prequant(
        weights = weights,
        quantiles = quantiles,
        bias_type = positional_bias,
        n_bins = n_bins,
        converged = converged,
        iterations = iterations,
        initial_beta = initial_beta
    )

    if (verbose) {
        cli::cli_progress_done()
        cli::cli_alert_success("Pre-quantification complete")
        cli::cli_alert_info("Weight range: [{round(min(weights), 3)}, {round(max(weights), 3)}]")
    }

    prequant
}

#' Run Preliminary EM for Initial Beta Estimates
#'
#' Simplified EM algorithm to get initial transcript abundance estimates
#' for positional weight optimization.
#'
#' @param index mpaqt_index object
#' @param sr_counts Short-read EC counts
#' @param max_iter Maximum iterations
#' @param tolerance Convergence tolerance
#' @param verbose Print progress
#'
#' @return List with beta estimates
#' @keywords internal
run_preliminary_em <- function(
    index,
    sr_counts,
    max_iter = 20L,
    tolerance = 1e-2,
    verbose = FALSE
) {
    n_transcripts <- length(index$p_matrices)
    n_ecs <- length(sr_counts)

    # Initialize beta
    beta <- rep(0, n_transcripts)
    names(beta) <- index$transcripts

    # Expected counts
    y <- rep(0, n_ecs)

    # Simple EM without positional weights or long reads
    for (iter in seq_len(max_iter)) {
        prev_beta <- beta

        for (j in seq_len(n_transcripts)) {
            p_data <- index$p_matrices[[j]]
            ec_idx <- p_data$i
            probs <- p_data$x

            # E-step: compute expected counts for this transcript
            y_j <- y[ec_idx]
            n_j <- sr_counts[ec_idx]

            # Compute gradient
            safe_y <- pmax(y_j, 1e-10)
            grad <- sum(probs * n_j / safe_y) - sum(probs)

            # Hessian (simplified)
            hess <- -sum(probs^2 * n_j / safe_y^2)

            # Newton update
            if (abs(hess) > 1e-10) {
                delta <- -grad / hess
            } else {
                delta <- 0
            }

            # Ensure non-negativity
            delta <- max(-beta[j] + 1e-10, delta)

            # Update
            beta[j] <- beta[j] + delta
            y[ec_idx] <- y[ec_idx] + probs * delta
        }

        # Check convergence
        beta_change <- max(abs(beta - prev_beta))
        if (beta_change < tolerance) break
    }

    list(beta = beta)
}

#' Run Pre-Quantification EM with Integrated Weight Optimization
#'
#' Full EM algorithm that updates positional weights within the EM loop,
#' matching the mpaqt-dev architecture.
#'
#' @param index mpaqt_index object
#' @param sr_counts Short-read EC counts
#' @param positional_weights Initial positional weights
#' @param bias_type "3p" or "5p"
#' @param quantiles Distance quantiles
#' @param n_bins Number of bins
#' @param max_iter Maximum iterations
#' @param tolerance Convergence tolerance
#' @param weight_update_start Iteration to start updating weights
#' @param convergence_start Iteration to start checking convergence
#' @param verbose Print progress
#'
#' @return List with beta, positional_weights, converged, iterations
#' @keywords internal
run_prequant_em <- function(
    index,
    sr_counts,
    positional_weights,
    bias_type,
    quantiles,
    n_bins,
    max_iter = 100L,
    tolerance = 1e-1,
    weight_update_start = 20L,
    convergence_start = 25L,
    verbose = FALSE
) {
    n_transcripts <- length(index$p_matrices)
    n_ecs <- length(sr_counts)

    # Initialize beta
    beta <- rep(0, n_transcripts)
    names(beta) <- index$transcripts

    # Expected counts
    y <- rep(0, n_ecs)

    # Prior parameters
    prior_mean <- 0
    prior_variance <- 1

    # Convergence tracking
    prev_ll <- NA
    converged <- FALSE

    # Bin assignments (computed on first iteration)
    bin_assignments <- vector("list", n_transcripts)

    # Alphabetical transcript order for si_mat construction — must match
    # mpaqt-dev's merge(distances, tr_abun, by="tr_id", sort=TRUE) which sums
    # contributions in alphabetical tr_id order, not transcript-index order
    tr_alpha_order <- order(index$transcripts)

    # Prepare flattened data for weight optimization (like mpaqt-dev)
    dist_col <- if (bias_type == "3p") "dist_3p" else "dist_5p"

    for (iter in seq_len(max_iter)) {
        if (verbose) {
            cat(sprintf("\rIteration %3d/%3d |", iter, max_iter))
        }

        # E-step: Update transcript abundances
        for (j in seq_len(n_transcripts)) {
            p_data <- index$p_matrices[[j]]
            ec_idx <- p_data$i
            probs <- p_data$x

            # Get observed and expected counts
            obs <- sr_counts[ec_idx]
            exp <- y[ec_idx]

            # Get positional weights
            if (iter == 1) {
                # Assign distance bins on first iteration
                if (dist_col %in% names(p_data)) {
                    distances <- p_data[[dist_col]]
                    bins <- cut(distances, breaks = quantiles, labels = FALSE, include.lowest = TRUE)
                    bins[is.na(bins)] <- 1
                } else {
                    bins <- rep(1, length(probs))
                }
                bin_assignments[[j]] <- bins
            } else {
                bins <- bin_assignments[[j]]
            }
            weights <- positional_weights[bins]

            # Compute update
            if (iter == 1) {
                # First iteration: Gaussian approximation
                weighted_probs <- probs * weights
                residuals <- obs - exp
                delta <- sum(residuals * weighted_probs) / sum(weighted_probs^2)
            } else {
                # Newton-Raphson with regularization
                eps <- 1e-30
                ratio <- (obs + eps) / (exp + eps)
                weighted_probs <- probs * weights

                gradient <- sum(weighted_probs * (1 - ratio))
                hessian <- sum((obs + eps) * (weighted_probs / (exp + eps))^2)

                # Unregularized Newton step
                delta_unregularized <- -gradient / hessian

                # Add regularization if beta > 0
                if (beta[j] > 0) {
                    log_beta <- log(beta[j])
                    gradient <- gradient + (log_beta - prior_mean) / (beta[j] * prior_variance)
                    hessian <- hessian + (-log_beta + prior_mean + 1) / (beta[j]^2 * prior_variance)
                    delta <- -gradient / hessian

                    # Bounded optimization fallback (matches mpaqt-dev)
                    delta_prior_mode <- exp(prior_mean) - beta[j]

                    if (delta < min(delta_unregularized, delta_prior_mode) ||
                        delta > max(delta_unregularized, delta_prior_mode)) {
                        # Use bounded optimization
                        lower_bound <- max(-beta[j] + eps, min(delta_unregularized, delta_prior_mode))
                        upper_bound <- max(-beta[j] + eps, max(delta_unregularized, delta_prior_mode))

                        objective_fn <- function(x) {
                            new_beta <- beta[j] + x
                            reg_penalty <- (log(new_beta) - prior_mean)^2 / (2 * prior_variance)
                            poisson_nll <- sum(exp + weighted_probs * x -
                                             obs * log(exp + weighted_probs * x + eps))
                            reg_penalty + poisson_nll
                        }

                        delta <- stats::optimize(objective_fn, c(lower_bound, upper_bound))$minimum
                    }
                } else {
                    delta <- delta_unregularized
                }
            }

            # Apply update with bounds
            if (is.na(delta) || is.infinite(delta)) delta <- 0
            delta <- max(-beta[j] + 1e-10, delta)

            beta[j] <- beta[j] + delta
            y[ec_idx] <- y[ec_idx] + probs * weights * delta
        }

        # M-step: Update prior parameters
        positive_beta <- beta[beta > 0]
        if (length(positive_beta) > 0) {
            log_beta <- log(positive_beta)
            prior_mean <- mean(log_beta)
            prior_variance <- mean((log_beta - prior_mean)^2)
        }

        # Calculate log-likelihood
        y[y < 0] <- 0
        ll <- sum(sr_counts * log(y + 1e-30) - y)
        if (length(positive_beta) > 0) {
            ll <- ll - n_transcripts / 2 * log(prior_variance)
        }

        dll <- ll - prev_ll

        if (verbose) {
            cat(sprintf(" LL: %.4f | dLL: %.2e | sigma2: %.4f |", ll, dll, prior_variance))
        }

        # Update positional weights after warm-up period
        if (iter >= weight_update_start) {
            if (verbose) cat(" Updating weights...")

            # Build expected count matrix per bin
            # Iterate in alphabetical tr_id order to match mpaqt-dev's
            # merge(distances, tr_abun, by="tr_id") summation order
            si_mat <- matrix(0, nrow = n_ecs, ncol = n_bins)

            for (j_ord in seq_len(n_transcripts)) {
                j <- tr_alpha_order[j_ord]
                p_data <- index$p_matrices[[j]]
                ec_idx <- p_data$i
                probs <- p_data$x
                bins <- bin_assignments[[j]]

                for (k in seq_len(n_bins)) {
                    mask <- bins == k
                    if (any(mask)) {
                        si_mat[ec_idx[mask], k] <- si_mat[ec_idx[mask], k] + probs[mask] * beta[j]
                    }
                }
            }

            # Optimize weights using L-BFGS-B
            neg_log_lik <- function(log_w, X, obs) {
                lambda <- X %*% exp(log_w)
                sum(lambda - obs * log(lambda + 1e-30))
            }

            fit <- stats::optim(
                par = log(positional_weights),
                fn = neg_log_lik,
                X = si_mat,
                obs = sr_counts,
                method = "L-BFGS-B",
                lower = log(positional_weights) - 1,
                upper = log(positional_weights) + 1
            )

            coefs <- exp(fit$par)
            coefs[coefs < 1e-10] <- 1e-10

            # mpaqt-dev order: recalculate y with OLD weights first
            y <- rowSums(sweep(si_mat, 2, positional_weights, "*"))
            y[y < 0] <- 0

            # Recalculate log-likelihood with OLD weights
            ll <- sum(sr_counts * log(y + 1e-30) - y)
            ll <- ll - n_transcripts / 2 * log(prior_variance)

            # THEN update abundances and weights (normalization)
            beta <- beta * coefs[1]
            positional_weights <- coefs / coefs[1]

            if (verbose) {
                cat(sprintf(" LL after W: %.4f", ll))
            }
        }

        if (verbose) cat("\n")

        # Check convergence
        if (!is.na(dll) && iter >= convergence_start) {
            if (dll > 0 && dll < tolerance) {
                converged <- TRUE
                if (verbose) cat("Converged at iteration", iter, "\n")
                break
            }
        }

        prev_ll <- ll
    }

    list(
        beta = beta,
        positional_weights = positional_weights,
        converged = converged,
        iterations = iter,
        log_likelihood = ll
    )
}

# =============================================================================
# S3 Class: mpaqt_prequant
# =============================================================================

#' Create a new mpaqt_prequant object
#'
#' @param weights Positional bias weights
#' @param quantiles Distance bin boundaries
#' @param bias_type "3p" or "5p"
#' @param n_bins Number of bins
#' @param converged Whether optimization converged
#' @param iterations Number of iterations
#' @param initial_beta Initial transcript abundance estimates
#'
#' @return An mpaqt_prequant object
#' @keywords internal
new_mpaqt_prequant <- function(
    weights,
    quantiles,
    bias_type,
    n_bins,
    converged,
    iterations,
    initial_beta
) {
    structure(
        list(
            weights = weights,
            quantiles = quantiles,
            bias_type = bias_type,
            n_bins = n_bins,
            converged = converged,
            iterations = iterations,
            initial_beta = initial_beta
        ),
        class = c("mpaqt_prequant", "list"),
        created = Sys.time()
    )
}

#' Print method for mpaqt_prequant
#'
#' @param x An mpaqt_prequant object
#' @param ... Additional arguments (unused)
#'
#' @return Invisible x
#' @export
print.mpaqt_prequant <- function(x, ...) {
    cli::cli_h1("MPAQT Pre-Quantification Result")

    if (x$converged) {
        cli::cli_alert_success("Converged in {x$iterations} iterations")
    } else {
        cli::cli_alert_warning("Did not converge ({x$iterations} iterations)")
    }

    cli::cli_text("Bias type: {.val {x$bias_type}}")
    cli::cli_text("Number of bins: {.val {x$n_bins}}")
    cli::cli_text("Weight range: [{round(min(x$weights), 3)}, {round(max(x$weights), 3)}]")

    invisible(x)
}

#' Validate mpaqt_prequant object
#'
#' @param x Object to validate
#'
#' @return Invisible TRUE if valid
#' @keywords internal
validate_mpaqt_prequant <- function(x) {
    if (!inherits(x, "mpaqt_prequant")) {
        cli::cli_abort(c(
            "Expected an {.cls mpaqt_prequant} object",
            "i" = "Create one with {.fn mpaqt_prequant}"
        ))
    }

    required <- c("weights", "quantiles", "bias_type", "n_bins")
    missing <- setdiff(required, names(x))

    if (length(missing) > 0) {
        cli::cli_abort(c(
            "Invalid {.cls mpaqt_prequant}: missing components",
            "x" = "Missing: {.val {missing}}"
        ))
    }

    invisible(TRUE)
}

#' Save pre-quantification result
#'
#' @param prequant An mpaqt_prequant object
#' @param path Output file path
#'
#' @return Invisible path
#' @export
mpaqt_save_prequant <- function(prequant, path) {
    validate_mpaqt_prequant(prequant)
    saveRDS(prequant, path)
    cli::cli_alert_success("Saved: {.path {path}}")
    invisible(path)
}

#' Load pre-quantification result
#'
#' @param path Path to RDS file
#'
#' @return An mpaqt_prequant object
#' @export
mpaqt_read_prequant <- function(path) {
    validate_file_exists(path, "Pre-quantification file")

    prequant <- readRDS(path)

    if (!inherits(prequant, "mpaqt_prequant")) {
        cli::cli_abort(c(
            "Invalid pre-quantification file: {.path {path}}",
            "i" = "File does not contain an mpaqt_prequant object"
        ))
    }

    prequant
}
