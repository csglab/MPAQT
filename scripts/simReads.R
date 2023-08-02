# This script generates simulated short-read FASTQs using a provided reference transcriptome
# Can produce either single-end or paired-end FASTQ files
# Generates the fastqs such that all transcripts have equal abundance 

suppressPackageStartupMessages(library(Rsubread))

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
rep <- strsplit(grep('--rep*', args, value = TRUE), split = '=')[[1]][[2]]
topdir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
sample.name <- strsplit(grep('--sample*', args, value = TRUE), split = '=')[[1]][[2]]
ref_txome <- strsplit(grep('--ref_txome*', args, value = TRUE), split = '=')[[1]][[2]]
mode <- strsplit(grep('--mode*', args, value = TRUE), split = '=')[[1]][[2]]
lib.size <- as.integer(strsplit(grep('--lib_size*', args, value = TRUE), split = '=')[[1]][[2]]) 

getwd()
#setwd(topdir)
# Define reference transcriptome

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
print(paste0("paired mode is: ", paired))

# generate reads
true.counts <- simReads(ref_txome, 
	TPMs,
	paired.end = paired,
	sample.name,
	read.length = 75,
	library.size = lib.size,
	truth.in.read.names = TRUE
	)
print(true.counts[1:10,])
