# Read the P matrix (in the list format)
P <- readRDS("/home/maposto/scratch/sim_reads.24reps.1TPM.100mil/p_list.Rds")
# Load the read counts. This will be a numeric vector, with each element representing an EC
#  The order of elements in this vector should be the same as the order of rows in the P matrix
n <- readRDS("/home/maposto/scratch/sim_reads.24reps.1TPM.100mil/p_rowSums.Rds")

#### Function for fitting transcript abundances
# P: The matrix P, in the list format
# n: The vector of read counts observed for each EC, in the same order as the rows of P matrix
# tol: The desired accuracy. The algorithm runs until the improvement in log-liklihood (LL) is smaller than tol multiplied by LL improvement in iteration 2
# itelim: The maximum number of iterations to achieve convergence
fit_model <- function( P, n, tol=1e-4, itelim=100 )
{
  # Initialize the vector of transcript abundances
  beta <- rep(0,length(P))
  # Initialize the vector of the current model fit (i.e. the EC abundances predicted by the current model parameters)
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
      n_subset <- n[ P[[j]]$i ] # the read counts for ECs that have non-zero probabilities for this transcript
      y_subset <- y[ P[[j]]$i ] # the current fit for ECs that have non-zero probabilities for this transcript
      p <- P[[j]]$x # the non-zero EC probabilities
      
      # # Gaussian error model
      # opt_res <- optimize(
      #   function(x) sum( (n_subset-y_subset-p*x)^2 ),
      #   lower=-beta[j], upper=10000 )
      
      # Poisson error model
      #  Minimizes the Poisson -LL (negative log-likelihood), which is lambda - k*log(lambda)
      #  To prevent taking log of zero (which may occur when k is zero), a small value is added to lambda
      opt_res <- optimize(
        function(x) {
          lambda <- y_subset+p*x
          sum( lambda - n_subset*log(lambda+1e-30) ) }, # poisson likelihood. coordinate gradient descent approach
        lower=-beta[j], upper=10000 )
      
      beta[j] <- beta[j]+opt_res$minimum
      y[ P[[j]]$i ] <- y[ P[[j]]$i ] + p*opt_res$minimum
    }
    
    LL <- sum( n*log(y+1e-30) - y ) # log-likelihood after this round of optimization
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
  
  return( list(
    beta=beta,
    LL=LL,
    fitted.values=y ) )
}

#################################################################


# Fit the model
library(tictoc)
tic("Fitting model parameters: ")
res <- fit_model( P, n )
toc()

# Visualize the model parameters and the fitted values
par(mfrow=c(1,2))
hist(log10(res$beta+1),breaks=1000,main="")
abline(v=log10(2),lt=3)
smoothScatter(log10(res$fitted.values+1),log10(n+1),bandwidth = 0.02)
quantile(res$beta,seq(0,1,by=0.05))
