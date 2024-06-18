# This script converts the 24 replicates into a sparse matrix
# The file rep_counts.24reps.Rds 

library(magrittr)
shhh = suppressPackageStartupMessages

library(optparse) %>% shhh()
library(dplyr) %>% shhh()
library(Biostrings) %>% shhh()
library(stringr) %>% shhh()
library(tidyr) %>% shhh()
library(Matrix) %>% shhh()

option_list <- list(
  make_option(c("--topdir"), type="character", default=NULL, help="Description for topdir"),
  make_option(c("--reps"), type="integer", default=NULL, help="Number of replicates")
)
args <- parse_args(OptionParser(option_list=option_list))

log_dir <- file.path(args$topdir, 'logs')
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_file <- file.path(log_dir, 'generate_p_matrix.log')
sink(log_file)

topdir <- paste0(args$topdir, "/")
reps <- args$reps

# load counts and get ec_lst with ECs named based on included txs
counts <- readRDS(file.path(topdir, paste0("rep_counts.",reps,"reps.Rds")))
ec_lst <- unique(counts$txs)

# all transcripts
# print("generate transcript lst")
tx_lst <- read.csv(paste0(topdir, "rep1/", "transcripts.txt"), header =F)
tx_lst <- sapply(strsplit(as.character(tx_lst$V1), "\\|"), "[[", 1)

# print("making P matrix")
# Make E x T matrix P with rows E (equivalence class tx_lists) and columns ENST IDs
#https://slowkow.com/notes/sparse-matrix/

# print("making ec_lst idxs")
ec.df <- data.frame(txs=ec_lst, ec_row=1:length(ec_lst))
# print("making tx_lst idxs")
tx.df <- data.frame(tx_id=tx_lst, tx_col=1:length(tx_lst))

# print("joining idxs to count df")
counts.ec_tx_idxs <- inner_join(counts, ec.df, by="txs")
#rm(counts)
#rm(ec.df)
counts.ec_tx_idxs <- inner_join(counts.ec_tx_idxs, tx.df, by="tx_id")

# print("building sparse matix")
m <- spMatrix(nrow=length(ec_lst), ncol=length(tx_lst),
                      i=counts.ec_tx_idxs$ec_row,
                      j=counts.ec_tx_idxs$tx_col,
                      x=counts.ec_tx_idxs$n)

dimnames(m) <- list(ec_lst, tx_lst)

saveRDS(m, file=paste0(topdir, "p_matrix.Rds"))

sink()