#!/bin/bash

# Set output directory
topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023

mode=single
#mode=paired

ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx

# REPLICATES
job1=$(sbatch --export=topdir=$topdir,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX replicates_combined_script.sh)
echo $job1
job1=$(echo $job1 | awk '{print $NF}')

# COMBINE
job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir RUN_combine_replicate_counts.sh) 
echo $job2
