#!/bin/bash
#SBATCH --job-name="P_mat_replicates"
#SBATCH --cpus-per-task=1
#SBATCH --time=4:00:00
#SBATCH --mem=40G
#SBATCH --array=1-24
#SBATCH --err=logs/err.%x.%j.log
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --account=rrg-hsn

set -eu -o pipefail
echo "STARTING: " $(date)

# Arguments
OUTPUT_DIR=$topdir/rep$SLURM_ARRAY_TASK_ID
sample=SIM.$SLURM_ARRAY_TASK_ID

# Generate fastqs
echo Generating fastq number $SLURM_ARRAY_TASK_ID
echo Running simReads.R in $mode mode
echo $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
Rscript simReads.R --rep=$SLURM_ARRAY_TASK_ID --topdir=$OUTPUT_DIR --sample=$sample --ref_txome=$ref_txome --mode=$mode

# Run kallisto bus
echo Run kallisto bus $SLURM_ARRAY_TASK_ID
TRANSCRIPTOME=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
FASTQ1=$OUTPUT_DIR/$sample\_R1.fastq.gz
FASTQ2=$OUTPUT_DIR/$sample\_R2.fastq.gz
echo $FASTQ1 $FASTQ2

if [ $mode == "single" ];then 
  echo single
  kallisto bus --num -o $OUTPUT_DIR -i  $TRANSCRIPTOME $FASTQ1
elif [ $mode == "paired" ];then 
  echo paired
  kallisto bus --num --paired -o $OUTPUT_DIR -i  $TRANSCRIPTOME $FASTQ1 $FASTQ2
fi

# Bustools
module load bustools
bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus

# Parse fastq read names
echo Parse fastq read names 
cat $OUTPUT_DIR/$sample\_R1.fastq.gz | gunzip  | grep ^@R  | awk  '{gsub("\\|","\t",$0); print;}' |awk  '{gsub(":","\t",$0); print;}' | cut -f 1,2 > $OUTPUT_DIR/read_names.txt

# Count reads per-EC
Rscript p_matrix_counts.R --rep=$SLURM_ARRAY_TASK_ID --topdir=$OUTPUT_DIR


echo "ENDING: " $(date)
