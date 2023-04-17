# This script runs MPAQT

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
topdir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
topdir <- paste0(topdir, "/")

#P <- readRDS(paste0(topdir, "p_list.Rds"))
P <- readRDS("/project/6007998/maposto/scripts/p_matrix_auto/reference/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds")
#n <- readRDS(paste0(topdir, "p_rowSums.Rds"))
n <- readRDS("/project/6007998/maposto/scripts/p_matrix_auto/reference/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds")


#### Function for fitting transcript abundances
# P: The matrix P for the type 1 reads (i.e., short RNA-seq read type), in the
#   list format
# n: The vector of type 1 read counts observed for each EC, in the same order
#   as the rows of P matrix
# n2: The vector of type 2 read counts (i.e., long reads) for each transcript,
#   in the same order as the columns of P matrix
# tol: The desired accuracy. The algorithm runs until the improvement in
#   log-liklihood (LL) is smaller than tol multiplied by LL improvement in
#   iteration 2
# itelim: The maximum number of iterations to achieve convergence
fit_model <- function( P, n, n2=rep(0,length(P)), tol=1e-4, itelim=100 )
{
  # Initialize the vector of transcript abundances
  beta <- rep(0,length(P))
  # Initialize the library size ratio for type2/type1 reads
  libsize2 <- 0
  # Initialize the vector of the current model fit for type 1 reads (i.e. the
  #   EC abundances predicted by the current model parameters)
  y <- rep(0,length(n))

  ######## The code for coordinate descent optimization

  prev_LL <- NA # The log-likelihood value after the previous round of optimization
  ref_dLL <- NA # The improvement in the log-liklihood after the second round. This value will be used to gauge when LL is not improving too much anymore
  converged <- F
  for( ite in 1:itelim )
  {
    cat("Iteration",ite,"...\n")

    # In each iteration, go over every transcript once and optimize the transcript abundance, given the estimated abundances of other transcripts
    for( j in 1:length(P) )
    {
      # To prevent repetitive array calls, store the values that are needed
      #   during optimization
      n_subset <- n[ P[[j]]$i ] # the type 1 read counts for ECs that have non-zero probabilities for transcript j
      y_subset <- y[ P[[j]]$i ] # the current fit for ECs that have non-zero probabilities for transcript j
      p <- P[[j]]$x # the non-zero EC probabilities
      n2_subset <- n2[j] # the type 2 read count for transcript j
      beta_subset <- beta[j] # the current fit for abundance of transcript j

      # Poisson error model
      #  Minimizes the Poisson -LL (negative log-likelihood), which is:
      #    [ lambda - k*log(lambda) ]
      #  To prevent taking log of zero (which may occur when k is zero), a small
      #    value is added to lambda.
      #  Note that for each transcript j, the LL should be calculated for both
      #    short and long reads.
      opt_res <- optimize(
        function(x) { # x is the difference between the new and old beta estimate for transcript j
          lambda <- y_subset+p*x # The mean for EC counts (type 1 reads)
          lambda2 <- (beta_subset+x)*libsize2 # The mean for type 2 (long) read count
          sum( lambda - n_subset*log(lambda+1e-30) ) +
            lambda2 - n2_subset*log(lambda2+1e-30) },
        lower=-beta[j], upper=10000 )

      beta[j] <- beta[j]+opt_res$minimum
      y[ P[[j]]$i ] <- y[ P[[j]]$i ] + p*opt_res$minimum
    }

    # optimize the library size ratio for type2/type1 reads, given the current
    #   beta estimates
    libsize2 <- sum(n2)/sum(beta) # this is the maximum likelihood Poisson estimator

    # log-likelihood after this round of optimization
    LL <-
      sum( n*log(y+1e-30) - y ) + # The LL for type 1 reads
      sum( n2*log(beta*libsize2+1e-30) - beta*libsize2 ) # The LL for type 2 reads
    cat("Log-Likelihood:",LL,"\n")

    dLL <- LL - prev_LL # How much has it improved since the last round?
    if(ite==2) { ref_dLL <- dLL } # If this is the second iteration, this dLL will be used as reference for evaluating convergence
    if( !is.na(dLL) & !is.na(ref_dLL) ) {
      if( dLL < ref_dLL*tol ) {
        cat("Model converged.\n")
        converged <- T
        break
      }
    }
    prev_LL <- LL
  }

  if( !converged ) {
    warning("Model did not converge.")
  }

  names(beta) <- names(P)

  # A list object is returned:
  return( list(
    beta=beta, # The beta coefficients, corresponding to the abundance of each transcript
    tpm=beta*1000000/sum(beta), # The normalized beta coefficients, i.e. TPM
    libsize2=libsize2, # The library size for type 2 reads relative to type 1 reads
    LL=LL, # The log-likelihood of model
    fitted.values=y # The fitted values for type 1 reads
    ) )
}

# Read in reads.ecs.counts
reads.ecs.counts <- readRDS(paste0(topdir, "reads.ecs.counts.Rds"))

# Use n names for proper order and fill in missing ECS in reads.ecs.counts
# Vast majority are present, so we can just eliminate ECs which are not in n
reads.ecs.counts <- reads.ecs.counts[which(reads.ecs.counts$txs %in% names(n) ),]

# Convert reads.ecs.counts to named vector
n_sample <- reads.ecs.counts$n
names(n_sample) <- reads.ecs.counts$txs

# Assign "0" to ECs not in in this sample
n_sample[names(n)[which(! names(n) %in%  reads.ecs.counts$txs )]] <- 0

# order n_sample vector by order of n from P
n_sample <- n_sample[names(n)]

tol=1e-4
itelim=100
# Fit model with only SR
res <- fit_model( P, n_sample,  tol=tol, itelim=itelim )
#res <- readRDS(' fit.tol= 1e-04 .itelim= 100 .Rds') 
saveRDS(res, file=paste0(topdir, paste0("fit.tol=", tol, ".itelim=", itelim, ".Rds") ))
