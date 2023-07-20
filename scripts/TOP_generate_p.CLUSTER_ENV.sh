#!/bin/bash

# Set output directory
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023
topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-7-2023
mkdir -p $topdir

mode=single
#mode=paired

ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx

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
