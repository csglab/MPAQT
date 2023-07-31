#!/bin/bash

# Set output directory
#topdir=/scratch/maposto/pmat.TEST_singularity.JULY-13-2023
#topdir=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/pmat.TEST_singularity.JULY-19-2023
#topdir=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/pmat_sing.JULY-19-2023
#topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.JULY-20-2023
#topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.FULL.JULY-20-2023
#topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.JULY-20-2023_2
topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.JULY-21-2023
mkdir -p $topdir

ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts
#lib_size=100000000
lib_size=10000
mode=single
reps=24
#reps=2

REF=/project/6007998/maposto/reference
MPAQT=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT
SIMG=/project/6007998/maposto/MODULES/MPAQT.V2.simg

# REPLICATES
#--time=4:00:00 --mem=40G 
job1=$(sbatch --export=topdir=$topdir,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX,lib_size=$lib_size,scripts=$scripts --job-name="P_mat_replicates" --cpus-per-task=1 --time=0:20:00 --mem=10G --array=1-$reps --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn tmp.sh $REF $MPAQT $SIMG)
#job1=$(sbatch --export=topdir=$topdir,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX,lib_size=$lib_size,scripts=$scripts --job-name="P_mat_replicates" --cpus-per-task=1 --time=4:00:00 --mem=40G --array=1-$reps --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn tmp.sh $REF $MPAQT $SIMG)
echo $job1
job1=$(echo $job1 | awk '{print $NF}')
 
# COMBINE

#SBATCH --time=2:00:00
#SBATCH --mem=20G
job2=$(sbatch --dependency=afterany:$job1 --job-name="combine_replicate_counts" --output=logs/out.%x.%j.log --error=logs/err.%x.%j.log --time=0:20:00 --mem=10G --account=rrg-hsn --export=topdir=$topdir,reps=$reps,scripts=$scripts tmp2.sh $REF $MPAQT $SIMG) 
#job2=$(sbatch --dependency=afterany:$job1 --job-name="combine_replicate_counts" --output=logs/out.%x.%j.log --error=logs/err.%x.%j.log --time=2:00:00 --mem=20G --account=rrg-hsn --export=topdir=$topdir,reps=$reps,scripts=$scripts tmp2.sh $REF $MPAQT $SIMG) 
echo $job2
