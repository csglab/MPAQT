# MPAQT Quantification: Mathematical Methods

## Overview

MPAQT (Multi-Platform Accurate Quantification of Transcripts) integrates short-read and long-read RNA-seq data to improve transcript abundance estimation. This document provides a comprehensive mathematical description of the quantification algorithm.

### The Core Optimization Problem

MPAQT estimates transcript abundances **β** = (β₁, …, β_T) by maximizing a composite objective function:

```
max_β L(β) = L_SR(β) + L_LR(β) - R(β)
```

where:

- **L_SR(β)**: Short-read log-likelihood (equivalence class model)
- **L_LR(β)**: Long-read log-likelihood (direct transcript counts)
- **R(β)**: Regularization penalty (log-normal prior)

---

## Short-Read Likelihood (L_SR)

### Equivalence Classes

Short reads often map ambiguously to multiple transcripts due to shared sequences. Rather than discarding multi-mapping reads, MPAQT uses **equivalence classes** (ECs) - groups of reads that map to the same set of transcripts.

For each equivalence class *i*, we observe *n_i* reads and have a probability matrix **P** where *P_ij* is the probability that a read from transcript *j* falls into EC *i*.

### The Multinomial Model

The expected read count for EC *i* is:

```
y_i = Σ_{j=1}^{T} β_j · P_ij
```

where *T* is the total number of transcripts.

Under a Poisson approximation to the multinomial, the log-likelihood is:

```
L_SR(β) = Σ_{i=1}^{E} [ n_i · log(y_i) - y_i ]
```

where *E* is the number of equivalence classes.

### Computing the P Matrix

The probability *P_ij* that a fragment from transcript *j* is assigned to EC *i* depends on:

1. **Transcript length**: Longer transcripts generate more reads
2. **EC membership**: Which transcripts share the EC
3. **Effective length**: Adjusted for fragment size

```r
# Conceptual example of P matrix construction
# Rows = equivalence classes
# Columns = transcripts
# Values = probability of read from transcript mapping to EC

# Example with 3 transcripts (A, B, C) and 4 ECs
P_example <- matrix(
  c(
    1.0,   0,   0,    # EC1: unique to A
    0,   1.0,   0,    # EC2: unique to B
    0.5, 0.5,   0,    # EC3: shared A,B
    0.3, 0.3, 0.4     # EC4: shared A,B,C
  ),
  nrow = 4, byrow = TRUE,
  dimnames = list(
    paste0("EC", 1:4),
    c("Transcript_A", "Transcript_B", "Transcript_C")
  )
)
```

---

## Long-Read Likelihood (L_LR)

### Direct Transcript-Level Counts

Unlike short reads, long reads typically span full transcripts and can be unambiguously assigned. Let *c_j* be the observed long-read count for transcript *j*.

### Coverage Probability Model

Long-read coverage varies across transcripts due to:

1. **3'/5' positional bias**: Degradation or priming effects
2. **Sequence-dependent effects**: GC content, secondary structure
3. **Technical variation**: Library prep, sequencing

We model the expected long-read count as:

```
E[c_j] = β_j · p_j · d
```

where:

- *p_j*: Coverage probability for transcript *j* (from GLM)
- *d*: Sequencing depth scale factor

### The Poisson Likelihood

The long-read log-likelihood is:

```
L_LR(β) = Σ_{j=1}^{T} [ c_j · log(β_j · p_j) - β_j · p_j ]
```

For transcripts without long-read coverage (*c_j* = 0), this term contributes:

```
-β_j · p_j
```

which acts as a soft penalty discouraging high abundance estimates for uncovered transcripts.

---

## Regularization (R)

### The Log-Normal Prior

To prevent overfitting and stabilize estimates for lowly-expressed transcripts, MPAQT uses L2 regularization in log-space:

```
R(β) = (λ/2) · Σ_{j=1}^{T} ( log(β_j) - μ_j )²
```

This is equivalent to a log-normal prior:

```
log(β_j) ~ N(μ_j, σ²)
```

where σ² = 1/λ.

### Adaptive Prior Mean

The prior mean *μ_j* can be set:

1. **Global**: Same value for all transcripts (simple shrinkage)
2. **Gene-level**: Mean of transcript abundances within gene
3. **Long-read informed**: Based on long-read observations

```r
# Example: Gene-level prior
compute_gene_level_prior <- function(abundances, transcript_to_gene) {
  gene_means <- tapply(log(abundances + 1e-10), transcript_to_gene, mean)
  prior_means <- gene_means[transcript_to_gene]
  return(prior_means)
}
```

---

## The EM Algorithm

### Overview

MPAQT uses an Expectation-Maximization (EM) algorithm to maximize the objective function. The algorithm iterates between:

1. **E-step**: Compute expected read assignments
2. **M-step**: Update abundance estimates

### E-Step: Read Assignment

Given current abundances **β**^(t), compute the probability that each read in EC *i* came from transcript *j*:

```
γ_ij^(t) = (β_j^(t) · P_ij) / (Σ_{k=1}^{T} β_k^(t) · P_ik)
```

### M-Step: Abundance Update

Update abundances using the Newton-Raphson method. For each transcript *j*:

#### Gradient (First Derivative)

```
∂L/∂β_j = [Σ_{i=1}^{E} (n_i · P_ij)/y_i - Σ_{i=1}^{E} P_ij]     (Short-read)
        + [c_j/β_j - p_j]                                        (Long-read)
        - [λ(log(β_j) - μ_j)/β_j]                                (Prior)
```

#### Hessian (Second Derivative)

```
∂²L/∂β_j² = -Σ_{i=1}^{E} (n_i · P_ij²)/y_i² - c_j/β_j² - λ(1 - log(β_j) + μ_j)/β_j²
```

#### Newton-Raphson Update

```
β_j^(t+1) = β_j^(t) - (∂L/∂β_j) / (∂²L/∂β_j²)
```

With bounds to ensure β_j > 0:

```r
# Newton-Raphson update with bounds
newton_update <- function(beta, gradient, hessian, min_beta = 1e-10) {
  # Ensure hessian is negative (concave region)
  if (hessian >= 0) {
    # Use gradient descent fallback
    step <- 0.1 * gradient
  } else {
    step <- -gradient / hessian
  }

  # Apply update with bounds
  new_beta <- beta + step
  new_beta <- max(new_beta, min_beta)

  return(new_beta)
}
```

### Convergence Criteria

The algorithm terminates when:

1. **Relative change**: `||β^(t+1) - β^(t)|| / ||β^(t)|| < ε`
2. **Likelihood change**: `|L^(t+1) - L^(t)| < ε`
3. **Maximum iterations**: Reached `max_iter`

```r
# Check convergence
check_convergence <- function(beta_old, beta_new, tolerance = 1e-4) {
  relative_change <- sqrt(sum((beta_new - beta_old)^2)) / sqrt(sum(beta_old^2))
  return(relative_change < tolerance)
}
```

---

## Positional Bias Correction

### The Bias Model

RNA degradation and sequencing artifacts cause non-uniform read coverage along transcripts. MPAQT models this with distance-dependent weights.

### 3' Bias Model

For 3' bias (common in poly-A selected data), reads near the 3' end are over-represented:

```
w_j(d) = exp( Σ_{b=1}^{B} θ_b · 1[d ∈ bin_b] )
```

where:

- *d*: Distance from 3' end
- *B*: Number of distance bins
- *θ_b*: Weight for bin *b*

### 5' Bias Model

For 5' bias (common in degraded samples), reads near the 5' end are depleted:

```
w_j(d) = exp( Σ_{b=1}^{B} φ_b · 1[d ∈ bin_b] )
```

### Bias Weight Optimization

The bias weights **θ** (or **φ**) are optimized using L-BFGS-B:

```
min_θ Σ_{i=1}^{E} ( n_i - Σ_{j=1}^{T} β_j · w_j(d_i) · P_ij )²
```

```r
# Optimize bias weights
optimize_bias_weights <- function(counts, P_matrix, abundances,
                                   distances, n_bins = 50) {
  # Create distance bins
  bins <- cut(distances, breaks = n_bins, labels = FALSE)

  # Objective function
  objective <- function(weights) {
    # Apply weights to P matrix
    weighted_P <- P_matrix * exp(weights[bins])

    # Compute expected counts
    expected <- weighted_P %*% abundances

    # Residual sum of squares
    return(sum((counts - expected)^2))
  }

  # Optimize
  result <- optim(
    par = rep(0, n_bins),
    fn = objective,
    method = "L-BFGS-B",
    lower = -5,
    upper = 5
  )

  return(result$par)
}
```

---

## Prior Integration with Mixed-Effects Models

### The Hierarchical Model

MPAQT can incorporate gene-level information through a mixed-effects model:

```
log(β_jg) = X_jg^T · θ + b_g + ε_jg
```

where:

- *β_jg*: Abundance of transcript *j* in gene *g*
- *X_jg*: Fixed-effect covariates (GC content, length, etc.)
- *θ*: Fixed-effect coefficients
- *b_g ~ N(0, σ_g²)*: Gene-level random effect
- *ε_jg ~ N(0, σ²)*: Residual error

### Implementation with GPBoost/lme4

```r
# Fit mixed-effects model for prior
fit_prior_model <- function(abundances, covariates, gene_ids) {
  # Prepare data
  df <- data.frame(
    log_abundance = log(abundances + 1e-10),
    gc_content = covariates$gc,
    length = log(covariates$length),
    gene = gene_ids
  )

  # Fit with lme4
  model <- lme4::lmer(
    log_abundance ~ gc_content + length + (1 | gene),
    data = df
  )

  # Extract prior parameters
  prior_mean <- predict(model)
  prior_var <- sigma(model)^2

  return(list(mean = prior_mean, variance = prior_var))
}
```

---

## Two-Phase Quantification

### Pre-Quantification Phase

The pre-quantification phase provides initial abundance estimates and optimizes bias weights:

```r
# Pre-quantification workflow
prequant_result <- mpaqt_prequant(
  index = idx,
  sr_counts = sr_counts,
  lr_counts = lr_counts,
  positional_bias = "3p",
  n_bins = 50,
  max_iter = 50,        # Fewer iterations
  fit_prior = TRUE,     # Fit prior model
  verbose = TRUE
)
```

**Key outputs**:

- Initial abundance estimates
- Optimized bias weights
- Prior model parameters
- Convergence diagnostics

### Post-Quantification Phase

The post-quantification phase refines estimates using the pre-computed parameters:

```r
# Post-quantification workflow
result <- mpaqt_postquant(
  index = idx,
  sr_counts = sr_counts,
  lr_counts = lr_counts,
  prequant = prequant_result,
  max_iter = 100,
  tolerance = 1e-6,     # Tighter convergence
  compute_uncertainty = TRUE,
  verbose = TRUE
)
```

**Key outputs**:

- Final abundance estimates (TPM)
- Uncertainty estimates (if requested)
- Convergence information
- Log-likelihood values

---

## Uncertainty Estimation

### Fisher Information

Uncertainty in abundance estimates is computed using the observed Fisher information:

```
I(β_j) = -∂²L/∂β_j²
```

The standard error is:

```
SE(β_j) = 1 / √I(β_j)
```

### Confidence Intervals

Approximate 95% confidence intervals:

```
[ β_j · exp(-1.96 · SE(log β_j)),  β_j · exp(1.96 · SE(log β_j)) ]
```

```r
# Compute uncertainty from Fisher information
compute_uncertainty <- function(abundances, hessian_diag) {
  # Fisher information (negative Hessian)
  fisher_info <- -hessian_diag

  # Standard errors
  se <- 1 / sqrt(pmax(fisher_info, 1e-10))

  # Confidence intervals (log scale)
  ci_lower <- abundances * exp(-1.96 * se / abundances)
  ci_upper <- abundances * exp(1.96 * se / abundances)

  return(list(se = se, ci_lower = ci_lower, ci_upper = ci_upper))
}
```

---

## Workflow Diagram

The complete MPAQT workflow:

```
                    +-------------------+
                    |   Reference Files |
                    | (FASTA + GTF)     |
                    +--------+----------+
                             |
                             v
                    +-------------------+
                    |   mpaqt_index()   |
                    | - Build kallisto  |
                    | - Compute P matrix|
                    +--------+----------+
                             |
            +----------------+----------------+
            |                                 |
            v                                 v
+---------------------+            +---------------------+
| Short-Read FASTQ    |            | Long-Read FASTQ     |
+----------+----------+            +----------+----------+
           |                                  |
           v                                  v
+---------------------+            +---------------------+
| mpaqt_prepare_      |            | mpaqt_prepare_      |
| short_reads()       |            | long_reads()        |
| - kallisto bus      |            | - minimap2          |
| - Extract EC counts |            | - Bambu             |
+----------+----------+            +----------+----------+
           |                                  |
           v                                  v
+---------------------+            +---------------------+
| mpaqt_counts_sr     |            | mpaqt_counts_lr     |
| (EC count vector)   |            | (Transcript counts) |
+----------+----------+            +----------+----------+
           |                                  |
           +----------------+----------------+
                            |
                            v
               +-------------------------+
               |   mpaqt_prequant()      |
               | - Initial EM            |
               | - Bias optimization     |
               | - Prior model fitting   |
               +------------+------------+
                            |
                            v
               +-------------------------+
               |   mpaqt_postquant()     |
               | - Final EM              |
               | - Uncertainty estimation|
               +------------+------------+
                            |
                            v
               +-------------------------+
               |   mpaqt_quant_result    |
               | - abundances (TPM)      |
               | - uncertainty (SE)      |
               | - convergence info      |
               +-------------------------+
```

---

## Algorithm Summary

### Key Equations Reference

| Component | Equation |
|-----------|----------|
| **Objective** | L(β) = L_SR + L_LR - R |
| **SR Likelihood** | L_SR = Σ_i [n_i log(y_i) - y_i] |
| **Expected EC Count** | y_i = Σ_j β_j P_ij |
| **LR Likelihood** | L_LR = Σ_j [c_j log(β_j p_j) - β_j p_j] |
| **Prior** | R = (λ/2) Σ_j (log β_j - μ_j)² |
| **E-step** | γ_ij = (β_j P_ij) / (Σ_k β_k P_ik) |
| **Newton Update** | β_j^new = β_j - (∇L) / (∇²L) |

### Default Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_iter` | 100 | Maximum EM iterations |
| `tolerance` | 1e-4 | Convergence threshold |
| `lambda` | 0.1 | Prior strength |
| `n_bins` | 50 | Bias correction bins |
| `prior_start` | 25 | Iteration to enable prior |
| `convergence_start` | 25 | Iteration to check convergence |

---

## References

1. **kallisto**: Bray, N.L., et al. (2016). Near-optimal probabilistic RNA-seq quantification. Nature Biotechnology.

2. **EM Algorithm for RNA-seq**: Pachter, L. (2011). Models for transcript quantification from RNA-Seq. arXiv.

3. **bambu**: Chen, Y., et al. (2021). Bambu: context-aware transcript quantification from long read RNA-seq experiments.

4. **Mixed-Effects Models**: Bates, D., et al. (2015). Fitting Linear Mixed-Effects Models Using lme4. Journal of Statistical Software.

5. **Fisher Information**: Efron, B. & Hinkley, D.V. (1978). Assessing the accuracy of the maximum likelihood estimator.
