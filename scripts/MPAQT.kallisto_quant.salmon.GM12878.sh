#!/bin/bash
#SBATCH --job-name="MPAQT.kallisto_quant.salmon"
#SBATCH --cpus-per-task=12 
#SBATCH --time=5:00:00
#SBATCH --err=logs/err.%x.%j.log
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --mem=40G
#SBATCH --account=rrg-hsn
#SBATCH --mail-user=michael.j.apostolides@gmail.com
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

#set -eu -o pipefail
echo "STARTING: " $(date)

# I/O
date=Dec-16-2021
#GM12878.ENCSR000AED.ENCLB037ZZZ.ENCFF001REK_ENCFF001REJ
sample=GM12878.rep1
FASTQ1=/project/6007998/maposto/PROJECTS/MPAQT_benchmarking/Teng-2016/FASTQ/GM12878.rep1.ENCFF001REK.R1.fastq.gz
FASTQ2=/project/6007998/maposto/PROJECTS/MPAQT_benchmarking/Teng-2016/FASTQ/GM12878.rep1.ENCFF001REJ.R2.fastq.gz

#GM12878.ENCSR000AED.ENCLB038ZZZ.ENCFF001REI_ENCFF001REH
#sample=GM12878.rep2
#FASTQ1=/project/6007998/maposto/PROJECTS/MPAQT_benchmarking/Teng-2016/FASTQ/GM12878.rep2.ENCFF001REI.R1.fastq.gz
#FASTQ2=/project/6007998/maposto/PROJECTS/MPAQT_benchmarking/Teng-2016/FASTQ/GM12878.rep2.ENCFF001REH.R2.fastq.gz

OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_benchmarking/Teng-2016/MPAQT_kallisto_salmon.$sample.$date
mkdir $OUTPUT_DIR
cd $OUTPUT_DIR

TRANSCRIPTOME=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx

# this script uses the development branch of kallisto, which does not require -x single-cell data type to be specified in kallisto bus

# KALLISTO
bin=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
$bin/kallisto quant -i $TRANSCRIPTOME -o $OUTPUT_DIR $FASTQ1 $FASTQ2 > ${OUTPUT_DIR}/kallisto_quant.log
mv $OUTPUT_DIR/abundance.tsv $OUTPUT_DIR/abundance_transcripts.tsv

# MPAQT: KALLISTO BUS
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

# SALMON

# Modules required

module load nixpkgs/16.09
module load gcc/7.3.0
module load openmpi/3.1.4
module load salmon/1.3.0

FAIDX=/project/6007998/maposto/reference/salmon/salmon_genomeIndex

salmon quant -p 8 \
                         -i ${FAIDX} \
                         -l A \
                         --validateMappings \
                         --gcBias \
                         -o ${OUTPUT_DIR} \
                         -1 $FASTQ1 \
                         -2 $FASTQ2
