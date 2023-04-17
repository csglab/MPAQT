#!/bin/bash
#SBATCH --job-name="kallisto_quant"
#SBATCH --cpus-per-task=1
#SBATCH --time=3:00:00
#SBATCH --err=logs/err.%x.%j.log
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --mem=30G
#SBATCH --account=rrg-hsn
#SBATCH --mail-user=michael.j.apostolides@gmail.com
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

set -eu -o pipefail
echo "STARTING: " $(date)


OUTPUT_DIR=/home/maposto/scratch/p_mat.novel_MDA-MB-231_dup1.Sept-16-2021/kallisto_quant_bus.SR
TRANSCRIPTOME=/project/6007998/maposto/reference/gencode.v38.transcripts.novel_MDA-MB-231_dup1.Sept-16-2021.fa.kidx
FASTQ1=/project/6007998/maposto/PROJECTS/09152015_MDA-LM2_RNA-seq/MDA-Par_r1.fastq
FASTQ2=/project/6007998/maposto/PROJECTS/09152015_MDA-LM2_RNA-seq/MDA-Par_r2.fastq

# this script uses the development branch of kallisto, which does not require -x single-cell data type to be specified in kallisto bus
mkdir $OUTPUT_DIR
cd $OUTPUT_DIR

#  /cvmfs/soft.mugqic/CentOS6/software/mugqic_tools/mugqic_tools-2.5.0/tools/rnaseq_light_kallisto.sh
bin=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
$bin/kallisto quant -i $TRANSCRIPTOME -o $OUTPUT_DIR --single -l 200 -s 20 $FASTQ1 $FASTQ2 > ${OUTPUT_DIR}/kallisto_quant.log
mv $OUTPUT_DIR/abundance.tsv $OUTPUT_DIR/abundance_transcripts.tsv

$bin/kallisto bus --num  -o $OUTPUT_DIR -i \
  $TRANSCRIPTOME \
  $FASTQ1 \
  $FASTQ2

module load bustools
bustools text -f -o output.bus.txt output.bus

