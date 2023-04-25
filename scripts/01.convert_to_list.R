# This script converts the P matrix from dgTMatrix format to a different format that allows quick access to non-zero entries of each column during model fitting
args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
topdir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
topdir <- paste0(topdir, "/")

P <- readRDS(paste0(topdir, "p_matrix.Rds"))
P <- as(P,"dgCMatrix")
saveRDS(rowSums(P), paste0(topdir, "p_rowSums.Rds"))

#dim(P)

sum( colSums(P) == 0 ) # there are 3072 transcripts with zero colSums. Looking at a few of them, they seem to be mostly miRNAs, which are probably too shot to produce any reads

# Remove transcripts with zero colSums
P <- P[ , which( colSums(P) != 0 ) ]
#dim(P)

# Convert P to a new format that is more efficient for the model-fitting algorithm
# In this format, P is represented as a list of N data frames, with N being the same as the number of columns in the P matrix
# Each data frame j contains as many rows as the number of non-zero entries in P column j
# Each entry in the data frame contains the row number (1-indexed) of a non-zero entry in the original P matrix, as well as the actual value for that non-zero entry
P.list <- lapply(
  1:ncol(P),
  function(x){
    #cat(x,"\n")
    data.frame(
      i=P@i[ (P@p[x]+1):(P@p[x+1]) ]+1,
      x=P@x[ (P@p[x]+1):(P@p[x+1]) ] ) } )
names(P.list) <- colnames(P)

# test if the conversion was correct

x <- y <- c()
for( ite in 1:100 )
{
  j <- sample.int(length(P.list),1)
  n <- sample(length(P.list[[j]]$i),1)
  i <- P.list[[j]]$i[n]
  x[ite] <- P.list[[j]]$x[n]
  y[ite] <- P[i,j]
}
if( sum(x!=y) > 0 ) { stop("Something went wrong.")}


saveRDS(P.list,  paste0(topdir, "p_list.Rds"))

## In the next steps, use the following file:
# P <- readRDS("~/GDrive/Projects/Michael/20210812.model_fit/p_list.Rds")
