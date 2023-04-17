#!/bin/bash
set -eu -o pipefail

echo "STARTING: " $(date)

#get args
OUTPUT_DIR=$1
PARAMETERS=$2
TRANSCRIPTOME=$3
TX2GENES=$4
FASTQ1=$5
FASTQ2=$6

mkdir -p $OUTPUT_DIR

### Builiding kallisto index ---------
kallisto index -i $TRANSCRIPTOME.idx $TRANSCRIPTOME 

kallisto quant $PARAMETERS -i $TRANSCRIPTOME.idx -o $OUTPUT_DIR $FASTQ1 $FASTQ2 > ${OUTPUT_DIR}/kallisto_quant.log
mv $OUTPUT_DIR/abundance.tsv $OUTPUT_DIR/abundance_transcripts.tsv

#R script transcript -> gene level
#Rscript --vanilla $R_TOOLS/abundanceTranscript2geneLevel.R $OUTPUT_DIR/abundance_transcripts.tsv $TX2GENES

