# This script combines all replicates into one object

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
log_file <- file.path(log_dir, 'combine_replicate_counts.log')
sink(log_file)

topdir <- args$topdir
reps <- args$reps

dir <- paste0(topdir, "/", "rep1", "/")
counts <- readRDS(paste0(dir, "ec.txs.joined.counts.Rds"))

# print(c(topdir, reps, dir))
if (reps == 1){
  saveRDS(counts, file=file.path(topdir, "rep_counts.1reps.Rds"))
  sink()
  return()
}

for (rep in 2:reps){
  dir <- paste0(topdir, "/", "rep", rep, "/")
  # print(dir)
  counts_rep <- readRDS(paste0(dir, "ec.txs.joined.counts.Rds") )
  names(counts_rep)[3] <- paste0("n", 2)

  # keep all rows, set NA to 0
  counts <- full_join(counts, counts_rep, by = c('txs', 'tx_id'))
  counts$n[which(is.na(counts$n))] <- 0
  counts$n2[which(is.na(counts$n2))] <- 0

  counts$n <- counts$n + counts$n2
  counts <- counts[c("txs", "tx_id", "n")]

}


saveRDS(counts, file=file.path(topdir, paste0("rep_counts.",reps,"reps.Rds")))

sink()