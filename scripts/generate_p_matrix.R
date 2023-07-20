suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(Biostrings))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(Matrix))

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
topdir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
topdir <- paste0(topdir, "/")
reps <- strsplit(grep('--reps*', args, value = TRUE), split = '=')[[1]][[2]]
reps <- as.integer(reps)

# load counts and get ec_lst with ECs named based on included txs
counts <- readRDS(file.path(topdir, paste0("rep_counts.",reps,"reps.Rds")))
ec_lst <- unique(counts$txs)

# all transcripts
print("generate transcript lst")
tx_lst <- read.csv(paste0(topdir, "rep1/", "transcripts.txt"), header =F)
tx_lst <- sapply(strsplit(as.character(tx_lst$V1), "\\|"), "[[", 1)

print("making P matrix")
# Make E x T matrix P with rows E (equivalence class tx_lists) and columns ENST IDs
#https://slowkow.com/notes/sparse-matrix/

print("making ec_lst idxs")
ec.df <- data.frame(txs=ec_lst, ec_row=1:length(ec_lst))
print("making tx_lst idxs")
tx.df <- data.frame(tx_id=tx_lst, tx_col=1:length(tx_lst))

print("joining idxs to count df")
counts.ec_tx_idxs <-  dplyr::inner_join(counts, ec.df)
#rm(counts)
#rm(ec.df)
counts.ec_tx_idxs <- dplyr::inner_join (counts.ec_tx_idxs,tx.df)

print("building sparse matix")
m <- Matrix::spMatrix(nrow=length(ec_lst), ncol=length(tx_lst),
                      i=counts.ec_tx_idxs$ec_row,
                      j=counts.ec_tx_idxs$tx_col,
                      x=counts.ec_tx_idxs$n)
dimnames(m) <- list(ec_lst, tx_lst)

saveRDS(m, file=paste0(topdir, "p_matrix.Rds"))
