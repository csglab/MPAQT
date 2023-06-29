#!/bin/bash

manifest=/project/6007998/maposto/PROJECTS/MPAQT_benchmarking/SMC_challenge.2021/A549_HCC1143/manifest.A549_HCC1143.txt

date=Dec-22-2021
#samples=$( cat $manifest | cut -f 2 | head -2)
samples=$( cat $manifest | cut -f 2 )

for sample in ${samples[@]};do
	echo $sample
	FASTQ1=$(cat $manifest | grep $sample | cut -f 5)
	echo $FASTQ1
	FASTQ2=$(cat $manifest | grep $sample | cut -f 6)
	echo $FASTQ2
	OUTPUT_DIR=/home/maposto/scratch/SMC_benchmarking.A549_HCC1143/4TOOLS.SMC.$sample.$date
	# MPAQT
	#sbatch --export=sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 MPAQT.sh 
	# KALLISTO
	#sbatch --export=sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 KALLISTO.sh 
	# SALMON 
	#sbatch --export=sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 SALMON.sh  
	# RSEM 
	sbatch --export=sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 RSEM.sh 
done

