# This script generates simulated short-read FASTQs using a provided reference transcriptome

# Can produce either single-end or paired-end FASTQ files
# Generates the fastqs such that all transcripts have equal abundance 
library(magrittr)
shhh = suppressPackageStartupMessages
library(optparse) %>% shhh()
library(Rsubread) %>% shhh()

option_list <- list(
  make_option(c("--topdir"), type="character", default=NULL, help="topdir description"),
  make_option(c("--sample"), type="character", default=NULL, help="sample name description"),
  make_option(c("--ref_txome"), type="character", default=NULL, help="reference transcriptome description"),
  make_option(c("--mode"), type="character", default=NULL, help="mode description"),
  make_option(c("--lib_size"), type="integer", default=NULL, help="library size description")
)

args <- parse_args(OptionParser(option_list=option_list))

log_dir = file.path(args$topdir, 'logs')
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_file = file.path(log_dir, 'simReads.log')
sink(log_file)

topdir <- args$topdir
sample.name <- args$sample
ref_txome <- args$ref_txome
mode <- args$mode
lib.size <- args$lib_size

# Scan through the fasta file to get transcript names and lengths
transcripts <- scanFasta(ref_txome)
nsequences <- nrow(transcripts) - sum(transcripts$Duplicate)

# Assign TPM value to each non-duplicated transcript sequence
TPMs <- rep(0, nrow(transcripts))
TPMs[!transcripts$Duplicate] <- rep(1, nsequences) 

# select single/paired mode
if (mode == "single"){
  paired <- FALSE
} else if (mode == "paired") {
  paired <- TRUE
} else {
 stop("Something went wrong")
}

# generate reads
true.counts <- simReads(ref_txome, 
	TPMs,
	paired.end = paired,
	output.prefix = file.path(topdir, sample.name),
	read.length = 81,
	library.size = lib.size,
	truth.in.read.names = TRUE,
	simulate.sequencing.error=FALSE)

sink()