# This script converts SQANTI3 output to generic input suitable for MPAQT 
library(dplyr)

args = commandArgs(trailingOnly=TRUE)
#INPUT/OUTPUT FILES
topdir <- strsplit(grep('--topdir*', args, value = TRUE), split = '=')[[1]][[2]]

#P <- "/project/6007998/maposto/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds"
P <- strsplit(grep('--p_list*', args, value = TRUE), split = '=')[[1]][[2]]
P <- readRDS(P)

sqanti3 <- strsplit(grep('--sqanti3*', args, value = TRUE), split = '=')[[1]][[2]]
#sqanti3 <- "/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.FULL/SOX10_Day61.rep1.transcriptome.sqanti3_classification.filtered_lite_classification.txt" 
sqanti_fields <- c("chrom","isoform", "associated_gene", "associated_transcript", "exons", "structural_category", "FL", "subcategory", "CDS_length")
sqanti3 <- read.csv(file=sqanti3, sep="\t", header=T)[sqanti_fields]

print("PREPARE LR DATA")
#####

# Remove novel transcripts
sqanti3.filt <- sqanti3[grep(sqanti3$associated_transcript, pattern= "ENST"),]

# Count FL per-transcript ( known/associated transcripts)
sqanti3.filt.counts  <- sqanti3.filt %>% dplyr::group_by(associated_transcript) %>%
dplyr::summarise(FL = sum(FL))

# Filter LR df for ENSTs in P
sqanti3.filt.counts <- sqanti3.filt.counts %>% filter(associated_transcript  %in% intersect(associated_transcript, names(P)) )

# Initialize LR.counts vector for all ENSTs in P
LR.counts <- rep(0, length(names(P)))
names(LR.counts) <- names(P)

# assign FL values to corresponding ENST IDs
LR.counts[sqanti3.filt.counts$associated_transcript] <- sqanti3.filt.counts$FL

saveRDS(LR.counts, file=file.path(topdir, "LR.counts.Rds"))
