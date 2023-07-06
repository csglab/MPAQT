#!/bin/bash

# Set output directory
topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023

mode=single
#mode=paired

ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
#       sbatch --export=scripts=$scripts,env=$env,KALLISTO_IDX=$KALLISTO_IDX,p_list=$p_list,p_rowSums=$p_rowSums,sample=$sample,OUTPUT_DIR=$OUTPUT_DIR,FASTQ1=$FASTQ1,FASTQ2=$FASTQ2 $scripts/MPAQT.sh

# REPLICATES
env=~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin
bin=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
job1=$(sbatch --export=topdir=$topdir,env=$env,bin=$bin,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX replicates_combined_script.sh)
echo $job1
job1=$(echo $job1 | awk '{print $NF}')

# COMBINE
job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
#job2=$(sbatch --account=rrg-hsn --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
echo $job2
