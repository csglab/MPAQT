#!/bin/bash


#/project/6007998/maposto/scripts/kallisto_bus.genpipes.sh

#fastq_dir=/project/6007998/maposto/MODULES/simReads/replicates/24.100mil.fastqs
#fastq_dir=/home/maposto/scratch/sim_reads.24reps.1TPM.100mil
fastq_dir=/home/maposto/scratch/p_mat.novel_MDA-MB-231_dup1.Sept-16-2021

#outdir=/home/maposto/scratch/sim_reads.24reps.1TPM.100mil
outdir=/home/maposto/scratch/p_mat.novel_MDA-MB-231_dup1.Sept-16-2021
#TRANSCRIPTOME=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
TRANSCRIPTOME=/project/6007998/maposto/reference/gencode.v38.transcripts.novel_MDA-MB-231_dup1.Sept-16-2021.fa.kidx

array=( $(seq 1 24 ) )
#array=( $(seq 3 24 ) )

#sample=sim.1TPM.100mil
sample=novel_MDA-MB-231_dup1

for i in ${array[@]};do 
echo $i

OUTPUT_DIR=$outdir/rep$i
echo $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
FASTQ1=$fastq_dir/$sample.$i\_R1.fastq.gz
FASTQ2=$fastq_dir/$sample.$i\_R2.fastq.gz
echo $FASTQ1 $FASTQ2
#sbatch --export=TRANSCRIPTOME=$TRANSCRIPTOME --export=OUTPUT_DIR=$OUTPUT_DIR --export=FASTQ1=$FASTQ1 --export=FASTQ2=$FASTQ2  --error=$OUTPUT_DIR/err.log --output=$OUTPUT_DIR/out.log kallisto_bus.sh
sbatch --export=TRANSCRIPTOME=$TRANSCRIPTOME,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2  --error=$OUTPUT_DIR/err.kallisto.log --output=$OUTPUT_DIR/out.kallisto.log kallisto_bus.sh

done
