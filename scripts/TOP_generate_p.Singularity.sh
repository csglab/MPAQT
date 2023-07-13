#!/bin/bash

# Set output directory
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-7-2023
#topdir=/home/maposto/scratch/pmat.TEST_singularity.JULY-12-2023
topdir=/scratch/maposto/pmat.TEST_singularity.JULY-13-2023
mkdir -p $topdir

mode=single
#mode=paired

ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx

# REPLICATES
#sbatch --job-name="P_mat_replicates" --cpus-per-task=1 --time=4:00:00 --mem=40G --array=1-2 --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn \

sbatch --export=topdir=$topdir,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX --job-name="P_mat_replicates" --cpus-per-task=1 --time=1:00:00 --mem=20G --array=1-2 --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn tmp.sh 
 
#job1=$(sbatch replicates_combined_script.Docker.sh --rep=$rep  --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX)
#echo $job1
#job1=$(echo $job1 | awk '{print $NF}')

# COMBINE
#job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
#job2=$(sbatch --account=rrg-hsn --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
#echo $job2
