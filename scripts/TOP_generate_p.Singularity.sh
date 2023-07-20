#!/bin/bash

# Set output directory
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-7-2023
#topdir=/home/maposto/scratch/pmat.TEST_singularity.JULY-12-2023
#topdir=/scratch/maposto/pmat.TEST_singularity.JULY-13-2023
#topdir=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/pmat.TEST_singularity.JULY-19-2023
topdir=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/pmat_sing.JULY-19-2023
mkdir -p $topdir


ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts
lib_size=10000
mode=single
reps=2
#mode=paired

# REPLICATES
#sbatch --job-name="P_mat_replicates" --cpus-per-task=1 --time=4:00:00 --mem=40G --array=1-2 --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn \

## THIS ONE:
job1=$(sbatch --export=topdir=$topdir,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX,lib_size=$lib_size,scripts=$scripts --job-name="P_mat_replicates" --cpus-per-task=1 --time=0:20:00 --mem=10G --array=1-2 --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn tmp.sh)
echo $job1
job1=$(echo $job1 | awk '{print $NF}')
 
#job1=$(sbatch replicates_combined_script.Docker.sh --rep=$rep  --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX)
#echo $job1
#job1=$(echo $job1 | awk '{print $NF}')

# COMBINE
#job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
#job2=$(sbatch --account=rrg-hsn --export=topdir=$topdir RUN_combine_replicate_counts.sh) 

job2=$(sbatch --dependency=afterany:$job1 --job-name="combine_replicate_counts" --output=logs/out.%x.%j.log --error=logs/err.%x.%j.log --time=0:20:00 --mem=10G --account=rrg-hsn --export=topdir=$topdir,reps=$reps,scripts=$scripts tmp2.sh) 
echo $job2
