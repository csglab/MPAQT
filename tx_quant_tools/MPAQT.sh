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

#set -eu -o pipefail
echo "STARTING: " $(date)

mkdir $OUTPUT_DIR
cd $OUTPUT_DIR

TRANSCRIPTOME=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx

# MPAQT: KALLISTO BUS
bin=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
$bin/kallisto bus --num --paired  -o $OUTPUT_DIR -i \
  $TRANSCRIPTOME \
  $FASTQ1 \
  $FASTQ2

module load bustools
bustools text -f -o output.bus.txt output.bus

#EC counts
~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin/Rscript /project/6007998/maposto/scripts/p_matrix_auto/EC_counts_bustools.R --topdir=$OUTPUT_DIR

# MPAQT
~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin/Rscript /project/6007998/maposto/scripts/p_matrix_auto/MPAQT.R --topdir=$OUTPUT_DIR
