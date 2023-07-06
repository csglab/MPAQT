library(Biostrings)
library(dplyr)
library(rtracklayer)

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
dir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]
fasta <- strsplit(grep('--fasta*', args, value = TRUE), split = '=')[[1]][[2]]
gtf <- strsplit(grep('--gtf*', args, value = TRUE), split = '=')[[1]][[2]]

fasta <- Biostrings::readDNAStringSet(fasta, format="fasta")

ensGTF <- rtracklayer::import(con=gtf, format="gtf")
ensGTF.df <- as(ensGTF, "data.frame")
ensGTF.tx <- ensGTF.df[ensGTF.df$type == "transcript",]

# calc letter frequency + gc ratio
gc <- letterFrequency(fasta, c("GC") )
at <- letterFrequency(fasta, c("AT") )
df <- as.data.frame(cbind(gc, at) )
gc_ratio <- gc/(gc + at)

# Make df with AT count, CG count, and GC_ratio
df<- data.frame(gc_ratio=as.vector(gc_ratio), AT=as.vector(at), GC=as.vector(gc) )
df$tx_id <- sapply(strsplit(as.character(names(fasta)), "\\|"), "[[", 1)

# Add transcript length
df$tx_length <- df$AT + df$GC

# add other annotations
df <- full_join(df, ensGTF.tx , by=c("tx_id"="transcript_id") )

# Make transcript_type categries with fewer than 10 "other"
counts <- table(df$transcript_type)
low_freq <- names(counts[counts < 10])
df$transcript_type[which(df$transcript_type %in% low_freq)] <- "other"

# filter df based on transcripts in P
df <- df %>% filter(tx_id %in% names(P))
# confirm P and df have same transcripts
identical(df$tx_id, names(P))

# Add protein coding status
df$protein_coding <- ifelse(df$gene_type == "protein_coding", 1, 0)

# Make covMx
covDataFrame <- df[,c("tx_id","gc_ratio", "AT", "GC", "tx_length", "protein_coding")]
covMx <- model.matrix( ~ log(gc_ratio) + log(tx_length) + protein_coding , data=covDataFrame )
#saveRDS(covMx, file = file.path(topdir, "covMx.Rds"))
