#!/bin/bash
#SBATCH --job-name="MPAQT"
#SBATCH --cpus-per-task=1 
#SBATCH --time=2:00:00
#SBATCH --err=logs/err.%x.%j.log
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --mem=30G
#SBATCH --account=
#SBATCH --mail-user=
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

echo "STARTING: " $(date)

# Set output directory
OUTPUT_DIR=

mkdir $OUTPUT_DIR
cd $OUTPUT_DIR

# Kallisto indexed transcriptome. The transcriptome fasta must be in the same directory
TRANSCRIPTOME=/path/to/kallisto/index/gencode.v38.transcripts.fa.idx

# MPAQT: KALLISTO BUS
kallisto bus --num --paired  -o $OUTPUT_DIR -i \
  $TRANSCRIPTOME \
  $FASTQ1 \
  $FASTQ2

module load bustools
bustools text -f -o output.bus.txt output.bus

#EC counts
Rscript EC_counts_bustools.R --topdir=$OUTPUT_DIR

# MPAQT
Rscript MPAQT.R --topdir=$OUTPUT_DIR
