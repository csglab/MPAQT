# This script runs MPAQT
library(magrittr)
shhh = suppressPackageStartupMessages
library(optparse) %>% shhh()
library(dplyr) %>% shhh()
library(stringr) %>% shhh()

option_list <- list(
  make_option(c("--topdir"), type="character", default=NULL, help="Top directory path"),
  make_option(c("--sample"), type="character", default=NULL, help="Path to sample file (RDS or other format)"),
  make_option(c("--p_matrix"), type="character", default=NULL, help="Path to P matrix (RDS file)"),
  make_option(c("--covMx"), type="character", default=NULL, help="Path to covariance matrix (RDS file)"),
  make_option(c("--LR_counts"), type="character", default=NULL, help="Path to LR counts (RDS file)")
)
args <- parse_args(OptionParser(option_list=option_list))

topdir <- args$topdir
sample <- args$sample

P <- readRDS(args$p_matrix)
n <- P[[2]]
P <- P[[1]]

covMx <- readRDS(args$covMx)
LR_counts <- readRDS(args$LR_counts)

#### Function for fitting transcript abundances
# P: The matrix P for the type 1 reads (i.e., short RNA-seq read type), in the
#   list format
# n: The vector of type 1 read counts observed for each EC, in the same order
#   as the rows of P matrix
# n2: The vector of type 2 read counts (i.e., long reads) for each transcript,
#   in the same order as the columns of P matrix
# covMx: The matrix of covariates, including variables that may affect type2
#   reads. At the minimum, this must be a model matrix with an intercept.
# tol: The desired accuracy. The algorithm runs until the improvement in
#   log-liklihood (LL) is smaller than tol multiplied by LL improvement in
#   iteration 2
# itelim: The maximum number of iterations to achieve convergence
# L2: Logical, indicating whether L2 regularization should be applied
fit_model.v9.better_convergence <- function( P, n, n2=rep(0,length(P)), covMx=rep(1,length(P)), tol=1e-4, itelim=100, prior=F )
{
  # Initialize the vector of transcript abundances
  beta <- rep(0,length(P))
  # Initialize P2, the P matrix for type2 reads, which is relative to type1 reads
  P2 <- rep(0,length(P))
  P2.fit <- NULL
  # Initialize the vector of the current model fit for type 1 reads (i.e. the
  #   EC abundances predicted by the current model parameters)
  y <- rep(0,length(n))

  n2_sum <- sum(n2)
  input_type = ifelse(n2_sum > 0, 'LR+SR Data', 'SR Data')
  input_type = str_pad(input_type, nchar('LR+SR Data'), 'right')

  ######## The code for coordinate descent optimization

  prev_LL <- NA # The log-likelihood value after the previous round of optimization
  ref_dLL <- NA # The improvement in the log-liklihood after the second round. This value will be used to gauge when LL is not improving too much anymore
  converged <- F
  sigma2 <- 1
  mu <- 0
  for( ite in 1:itelim )
  {
    # cat("Iteration",ite,"...\n")
    overshoot <- 0
    undershoot <- 0

    # In each iteration, go over every transcript once and optimize the transcript abundance, given the estimated abundances of other transcripts
    for( j in 1:length(P) )
    {
      # To prevent repetitive array calls, store the values that are needed
      #   during optimization
      n_subset <- n[ P[[j]]$i ] # the type 1 read counts for ECs that have non-zero probabilities for transcript j
      y_subset <- y[ P[[j]]$i ] # the current fit for ECs that have non-zero probabilities for transcript j
      p <- P[[j]]$x # the non-zero EC probabilities
      if( n2_sum > 0 ) { # type 2 reads are provided
        n_subset <- c(n_subset,n2[j]) # Add the observed count of type 2 read count
        y_subset <- c(y_subset,beta[j]*P2[j]) # Add the fit for type 2 reads
        p <- c(p,P2[j]) # Add the probability of type 2 reads
      }

      # Poisson error model
      #  Minimizes the Poisson -LL (negative log-likelihood), which is:
      #    [ lambda - k*log(lambda) ]
      #  To prevent taking log of zero (which may occur when k is zero), a small
      #    value is added to lambda.
      if( ite<=1 ) { # for the first iteration, use Gaussian error without any penalty; this results in a better starting point
        delta <- sum((n_subset-y_subset)*p)/sum(p^2)
      } else { # for the following iterations, use Poisson error, with L2 regularization if requested
        b <- sum( p * (1-(n_subset+1e-30)/(y_subset+1e-30)) )
        a <- sum( (n_subset+1e-30) * (p/(y_subset+1e-30))^2 )
        delta1 <- delta <- -b/a
        if(prior) { # L2 regularization is requested
          b <- b + (log(beta[j])-mu)/(beta[j]*sigma2)
          a <- a + (-log(beta[j])+mu+1)/(beta[j]*beta[j]*sigma2)
          delta2 <- exp(mu)-beta[j]
          delta <- -b/a
          if( delta < min(delta1,delta2) ) {
            opt_range <- c(
              max(-beta[j]+1e-10,min(delta1,delta2)),
              max(-beta[j]+1e-10,max(delta1,delta2)) )
            delta <- optimize( function(x) {
              1/(2*sigma2)*(log(beta[j]+x)-mu)^2 +
                sum( y_subset+p*x - n_subset*log(y_subset+p*x+1e-30) ) },
              opt_range )$minimum
            undershoot <- undershoot + 1
          } else if( delta > max(delta1,delta2) ) {
            opt_range <- c(
              max(-beta[j]+1e-10,min(delta1,delta2)),
              max(-beta[j]+1e-10,max(delta1,delta2)) )
            delta <- optimize( function(x) {
              1/(2*sigma2)*(log(beta[j]+x)-mu)^2 +
                sum( y_subset+p*x - n_subset*log(y_subset+p*x+1e-30) ) },
              opt_range )$minimum
            overshoot <- overshoot + 1
          }
        }
      }

      delta <- max( -beta[j]+1e-10, delta ) # The pseudocount ensures that beta=0 does not occur
      beta[j] <- beta[j]+delta
      y[ P[[j]]$i ] <- y[ P[[j]]$i ] + P[[j]]$x*delta
    }

    if(prior) {
      mu <- mean(log(beta)) # This is used for the L2 regularization, starting from iter=2
      sigma2 <- mean((log(beta)-mu)^2) # This is used for the L2 regularization, starting from iter=2
    }

    # Update P2, given the current beta estimates
    if( n2_sum > 0 ) {
      P2.fit <- glm(n2~covMx+0, offset=log(beta), family=poisson )
      P2 <- exp( covMx %*% matrix( coefficients(P2.fit), ncol=1 ) )
    }

    # Due to limits of computing precision and accumulation of errors, small negative y values may occur, which should be replaced with zero
    y[ y < 0 ] <- 0
    # log-likelihood after this round of optimization
    LL <-
      sum( n*log(y+1e-30) - y ) # The LL for type 1 reads
    - length(beta)/2*log(sigma2)
    if( n2_sum > 0 ) {
      LL <- LL +
        sum( n2*log(beta*P2) - beta*P2 ) # The LL for type 2 reads
      + logLik(P2.fit)

    }

    dLL <- LL - prev_LL # How much has it improved since the last round?
    # cat("Log-Likelihood:",LL,"; dLL:",dLL,"; sigma2:", sigma2,"; mu:", mu, "; undershoot:", undershoot, "; overshoot:", overshoot, "\n")
    cat(sprintf("\r——————————— %s | Iteration %d/%d | Log-Likelihood: %.4f; dLL: %.4f; sigma2: %.4f; mu: %.4f; undershoot: %.4f; overshoot: %.4f |",
                input_type, ite, itelim, LL, dLL, sigma2, mu, undershoot, overshoot))    
    flush.console()

    if(ite==2) { ref_dLL <- dLL } # If this is the second iteration, this dLL will be used as reference for evaluating convergence
    if( !is.na(dLL) & !is.na(ref_dLL) ) {
      if( dLL >0 & dLL < ref_dLL*tol ) {
        cat(" Model converged.\n")
        converged <- T
        break
      }
    }
    prev_LL <- LL
  }

  if( !converged ) {
    # warning("Model did not converge.")
    cat(" Model did not converge.\n")
  }

  names(beta) <- names(P)

  # A list object is returned:
  return( list(
    beta=beta, # The beta coefficients, corresponding to the abundance of each transcript
    tpm=beta*1000000/sum(beta), # The normalized beta coefficients, i.e. TPM
    P2=P2, # The P matrix for type 2 reads relative to type 1 reads
    P2.fit=P2.fit, # The glm object for the model fitted to type 2 reads
    LL=LL, # The log-likelihood of model
    sigma2=sigma2,
    fitted.values=y,# The fitted values for type 1 reads
    ite=ite
  ) )
}

# PREPARE SR DATA
# print("PREPARE SR DATA")
# Read in reads.ecs.counts
reads.ecs.counts <- readRDS(file.path(topdir, "reads.ecs.counts.Rds"))

# Use n names for proper order and fill in missing ECS in reads.ecs.counts
# Vast majority are present, so we can just eliminate ECs which are not in n
reads.ecs.counts <- reads.ecs.counts[which(reads.ecs.counts$txs %in% names(n) ),]

# Convert reads.ecs.counts to named vector
n_sample <- reads.ecs.counts$n
names(n_sample) <- reads.ecs.counts$txs

# Assign "0" to ECs not in this sample
n_sample[names(n)[which(! names(n) %in%  reads.ecs.counts$txs )]] <- 0

# order n_sample vector by order of n from P
n_sample <- n_sample[names(n)]

tol=1e-10
itelim=100

dir.create(file.path(topdir, "quant"), showWarnings = FALSE)


# Run MPAQT
# Save MPAQT output as Rds objects containing all output of the MPAQT model
# including various statistics, weights, etc
# Write plain text .tsv files containing only transcript IDs and TPM values

# print("FITTING MPAQT WITH SR DATA ONLY")
# res <- fit_model.v9.better_convergence( P, n_sample, prior=T, tol=tol, itelim=itelim )
suppressWarnings({
  res <- fit_model.v9.better_convergence( P, n_sample, prior=T, tol=tol, itelim=itelim )
})

# print("SAVING Rds OBJECT")
saveRDS(res, str_glue("{topdir}/{sample}.sr.mpaqt.RDS"))

# print("Writing tsv MPAQT output")
MPAQT.SR.df <- data.frame(transcript_id=names(res$tpm), TPM=res$tpm)
write.table(MPAQT.SR.df, file=str_glue("{topdir}/quant/{sample}.MPAQT.SR.tsv"), quote=F, row.names=F, sep = "\t")

# print("FITTING MPAQT WITH LR + SR DATA")
# res2 <- fit_model.v9.better_convergence( P, n_sample, n2=LR.counts,covMx = covMx, prior=T, tol=tol, itelim=itelim )
suppressWarnings({
  res2 <- fit_model.v9.better_convergence( P, n_sample, n2=LR_counts,covMx = covMx, prior=T, tol=tol, itelim=itelim )
})

# print("SAVING Rds OBJECT")
saveRDS(res2, str_glue("{topdir}/{sample}.lr_sr.mpaqt.RDS"))

# print("Writing tsv MPAQT output")
MPAQT.LR.df <- data.frame(transcript_id=names(res2$tpm), TPM=res2$tpm)
write.table(MPAQT.LR.df, file=str_glue("{topdir}/quant/{sample}.MPAQT.LR_SR.tsv"), quote=F, row.names=F, sep = "\t")
