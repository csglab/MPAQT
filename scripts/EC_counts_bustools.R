# This script counts the number of reads in each EC

suppressPackageStartupMessages(library(dplyr))

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
dir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
dir <- paste0(dir, "/")

print("load in matrix.ec")
matrix.ec <- read.csv(paste0(dir, "matrix.ec"), header =F, sep="\t")
names(matrix.ec) <- c("ec", "txs")

print("Load in bus file")
bus <- read.csv(paste0(dir, "output.bus.txt"), sep="\t", header=F )
names(bus) <- c("seq1", "seq2", "ec", "num", "read_id")
bus <- bus[c("ec", "read_id")]
bus$read_id <- as.character(bus$read_id)

print("Count number of reads in each EC")
# Count number of reads in each EC
reads.ecs.joined <- inner_join(bus, matrix.ec)[c("read_id", "txs")]
reads.ecs.counts <- reads.ecs.joined %>% dplyr::group_by(txs) %>%
  dplyr::count(txs)

print("save reads.ecs.counts to Rds")
saveRDS(reads.ecs.counts, file=paste0(dir, "reads.ecs.counts.Rds" ))
