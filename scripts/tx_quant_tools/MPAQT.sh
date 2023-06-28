#!/bin/bash
#SBATCH --job-name="MPAQT"
#SBATCH --cpus-per-task=1 
#SBATCH --time=2:00:00
#SBATCH --err=logs/err.%x.%j.log
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --mem=30G
#SBATCH --account=rrg-hsn
#SBATCH --mail-user=michael.j.apostolides@gmail.com
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

echo "STARTING: " $(date)

# Set output directory
#OUTPUT_DIR=/path/to/output_dir

mkdir $OUTPUT_DIR
cd $OUTPUT_DIR

# Kallisto indexed transcriptome. The transcriptome fasta must be in the same directory
#KALLISTO_IDX=/path/to/kallisto/index/gencode.v38.transcripts.fa.idx

# MPAQT: KALLISTO BUS
bin=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
$bin/kallisto bus --num --paired  -o $OUTPUT_DIR -i \
  $KALLISTO_IDX \
  $FASTQ1 \
  $FASTQ2

module load bustools
bustools text -f -o output.bus.txt output.bus

scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts
env=~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin
#EC counts
$env/Rscript $scripts/EC_counts_bustools.R --topdir=$OUTPUT_DIR

# MPAQT
$env/Rscript $scripts/MPAQT.R --topdir=$OUTPUT_DIR --p_list=$p_list --p_rowSums=$p_rowSums
