#!/bin/bash
#SBATCH --job-name="kallisto_quant"
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

#KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
#env=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin

# KALLISTO
$env/kallisto quant -i $KALLISTO_IDX -o $OUTPUT_DIR $FASTQ1 $FASTQ2 > ${OUTPUT_DIR}/kallisto_quant.log
mv $OUTPUT_DIR/abundance.tsv $OUTPUT_DIR/abundance_transcripts.tsv
