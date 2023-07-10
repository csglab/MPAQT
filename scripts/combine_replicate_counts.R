suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(Biostrings))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(Matrix))

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
topdir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
reps <- strsplit(grep('--reps*', args, value = TRUE), split = '=')[[1]][[2]]
dir <- paste0(topdir, "/", "rep1", "/")
counts <- readRDS(paste0(dir, "ec.txs.joined.counts.Rds") )

reps <- as.integer(reps)

for (rep in 2:reps){
  dir <- paste0(topdir, "/", "rep", rep, "/")
  print(dir)
  counts_rep <- readRDS(paste0(dir, "ec.txs.joined.counts.Rds") )
  names(counts_rep)[3] <- paste0("n", 2)

  # keep all rows, set NA to 0
  counts <- full_join(counts, counts_rep)
  counts$n[which(is.na(counts$n))] <- 0
  counts$n2[which(is.na(counts$n2))] <- 0

  counts$n <- counts$n + counts$n2
  counts <- counts[c("txs", "tx_id", "n")]
}


saveRDS(counts, file=paste0(topdir, "/", "rep_counts.24reps.Rds"))
