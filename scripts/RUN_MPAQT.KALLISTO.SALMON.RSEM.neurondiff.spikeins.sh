#!/bin/bash
#manifest=/project/6007998/maposto/PROJECTS/neurondiff/RUNS_RNAseq/manifest.neurondiff.txt
manifest=/project/6007998/maposto/PROJECTS/neurondiff/RUNS_RNAseq/manifest.neurondiff.Day61.rep2.txt

date=June-29-2023
mode=paired
#samples=$( cat $manifest | cut -f 1 | head -1)
samples=$( cat $manifest | cut -f 1 )

scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts
p_list=/project/6007998/maposto/reference/P/p_list.spikeins.June-10-2022.Rds
p_rowSums=/project/6007998/maposto/reference/P/p_rowSums.spikeins.June-10-2022.Rds
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/spikein/gencode.v38.transcripts.spikeins.fa.idx
#SALMON_IDX=/project/6007998/maposto/reference/salmon/salmon_genomeIndex
SALMON_IDX=/project/6007998/maposto/reference/salmon/spikein/salmon_genomeIndex

for sample in ${samples[@]};do
	echo $sample
	FASTQ1=$(cat $manifest | grep $sample | cut -f 2)
	echo $FASTQ1
	FASTQ2=$(cat $manifest | grep $sample | cut -f 3)
	echo $FASTQ2
	OUTPUT_DIR=/home/maposto/scratch/4TOOLS.neurondiff.spikein.$date/$sample
	mkdir -p $OUTPUT_DIR

	# MPAQT
	echo MPAQT
        env=~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin
#	sbatch --export=scripts=$scripts,env=$env,KALLISTO_IDX=$KALLISTO_IDX,p_list=$p_list,p_rowSums=$p_rowSums,sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 $scripts/MPAQT.sh

	# KALLISTO
	echo KALLISTO
	env=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
#	sbatch --export=env=$env,KALLISTO_IDX=$KALLISTO_IDX,sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 $scripts/KALLISTO.sh 

	# SALMON 
	echo SALMON
	sbatch --export=SALMON_IDX=$SALMON_IDX,sample=$sample,mode=$mode,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 $scripts/SALMON.sh  

	# RSEM 
	# sbatch --export=sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 $scripts/RSEM.sh 
done

