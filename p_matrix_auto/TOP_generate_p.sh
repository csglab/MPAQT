#!/bin/bash

#topdir=/home/maposto/scratch/pmat_test.Oct-14-2021
#topdir=/home/maposto/scratch/pmat_single.2.4_billion.Oct-15-2021
topdir=/home/maposto/scratch/pmat_single.2.4_billion.Jan-10-2022
mode=single

# REPLICATES
job1=$(sbatch --export=topdir=$topdir,mode=$mode replicates_combined_script.sh)
echo $job1
job1=$(echo $job1 | awk '{print $NF}')

# COMBINE
#job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir RUN_combine_replicate_counts.sh) 

#job2=$(sbatch --account=rrg-hsn --export=topdir=$topdir RUN_combine_replicate_counts.sh) 
#echo $job2
