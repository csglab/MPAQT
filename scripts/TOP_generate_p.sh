#!/bin/bash

# Set output directory
topdir=

mode=single
#mode=paired

ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa

# REPLICATES
job1=$(sbatch --export=topdir=$topdir,mode=$mode replicates_combined_script.sh, --export=ref_txome=$ref_txome)
echo $job1
job1=$(echo $job1 | awk '{print $NF}')

# COMBINE
job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir RUN_combine_replicate_counts.sh) 

#job2=$(sbatch --account=rrg-hsn --export=topdir=$topdir RUN_combine_replicate_counts.sh) 
echo $job2
