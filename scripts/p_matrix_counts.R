library(dplyr)
library(Biostrings)
library(stringr)
library(tidyr)
library(Matrix)

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
rep <- strsplit(grep('--rep*', args, value = TRUE), split = '=')[[1]][[2]]
dir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
dir <- paste0(dir, "/")

print(paste0("rep number: ", rep))
print(paste0("writing to dir: ", dir))

# all transcripts
print("generate transcript lst")
tx_lst <- read.csv(paste0(dir, "transcripts.txt"), header =F)
tx_lst <- sapply(strsplit(as.character(tx_lst$V1), "\\|"), "[[", 1)

print("read in and convert read_names to correct format")
# read in and convert read_names to correct format
read_names <- read.csv(paste0(dir, "read_names.txt"), sep="\t", header=F)
names(read_names) <- c("read_id", "tx_id")
read_names$read_id <- sub("@R0*", "", read_names$read_id)
read_names$read_id[which(read_names$read_id == "")] <- "0"

print("read in bus file")
#bus
bus <- read.csv(paste0(dir, "output.bus.txt"), sep="\t", header=F )
names(bus) <- c("seq1", "seq2", "ec", "num", "read_id")
bus <- bus[c("ec", "read_id")]
bus$read_id <- as.character(bus$read_id)

print("read in matrix.ec")
# all equivalence classes
matrix.ec <- read.csv(paste0(dir, "matrix.ec"), header =F, sep="\t")
names(matrix.ec) <- c("ec", "txs")

print("join dfs")
bus.read_names <- inner_join(bus, read_names)
rm(read_names)
rm(bus)
ec.txs.joined <- inner_join(bus.read_names, matrix.ec)
rm(bus.read_names)
rm(matrix.ec)
#saveRDS(ec.txs.joined, file=paste0(dir, "ec.txs.joined.Rds"))
#ec.txs.joined <- readRDS(file=paste0(dir, "ec.txs.joined.Rds"))

print("count matrix elements")
ec.txs.joined.counts <- ec.txs.joined %>% dplyr::group_by(txs, tx_id) %>%
  dplyr::count(txs)
rm(ec.txs.joined)

print("convert to df")
ec.txs.joined.counts.df <- as.data.frame(ec.txs.joined.counts)

# saving Rds count for this rep
print("save Rds object for ec.txs.joined.counts")
saveRDS(ec.txs.joined.counts.df, file=paste0(dir, "ec.txs.joined.counts.Rds"))
