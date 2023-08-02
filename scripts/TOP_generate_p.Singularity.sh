#!/bin/bash

# Set output directory
#topdir=/scratch/maposto/pmat.TEST_singularity.JULY-13-2023
#topdir=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/pmat.TEST_singularity.JULY-19-2023
#topdir=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/pmat_sing.JULY-19-2023
#topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.JULY-20-2023
#topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.JULY-20-2023_2
#topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.FULL.JULY-20-2023
#topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.TOY.Aug-1-2023
topdir=/scratch/maposto/TEST_MPAQT/pmat.TEST_singularity.TOY.Aug-1-2023.V2

mkdir -p $topdir
mkdir logs

ref_txome=/project/6007998/maposto/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts
mode=single

REF=/project/6007998/maposto/reference
MPAQT=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT
SIMG=/project/6007998/maposto/MODULES/MPAQT.V2.simg

test="true"
#test="false"

# TEST MODE --> GENERATE TEST P MATRIX TO CONFIRM CODE WORKS
if [ "$test" = "true" ]; then
    lib_size=10000
    reps=2
    echo "Test mode reps $reps and lib_size $lib_size"

    # REPLICATES
    job1=$(sbatch --export=topdir=$topdir,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX,lib_size=$lib_size,scripts=$scripts --job-name="P_mat_replicates" --cpus-per-task=1 --time=0:20:00 --mem=10G --array=1-$reps --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn step1_wrapper.generate_reps.sh $REF $MPAQT $SIMG)
    echo $job1
    job1=$(echo $job1 | awk '{print $NF}')

    # COMBINE
    job2=$(sbatch --dependency=afterany:$job1 --job-name="combine_replicate_counts" --output=logs/out.%x.%j.log --error=logs/err.%x.%j.log --time=0:20:00 --mem=10G --account=rrg-hsn --export=topdir=$topdir,reps=$reps,scripts=$scripts step2_wrapper.combine_reps.sh $REF $MPAQT $SIMG) 
    echo $job2

# FULL MODE --> GENERATE FULL P MATRIX
else
    lib_size=100000000
    reps=24
    echo "Full mode reps $reps and lib_size $lib_size"

    # REPLICATES
    job1=$(sbatch --export=topdir=$topdir,mode=$mode,ref_txome=$ref_txome,KALLISTO_IDX=$KALLISTO_IDX,lib_size=$lib_size,scripts=$scripts --job-name="P_mat_replicates" --cpus-per-task=1 --time=4:00:00 --mem=40G --array=1-$reps --err=logs/err.%x.%j.log --output=logs/out.%x.%j.log --account=rrg-hsn step1_wrapper.generate_reps.sh $REF $MPAQT $SIMG)
    echo $job1
    job1=$(echo $job1 | awk '{print $NF}')

    # COMBINE
    job2=$(sbatch --dependency=afterany:$job1 --job-name="combine_replicate_counts" --output=logs/out.%x.%j.log --error=logs/err.%x.%j.log --time=2:00:00 --mem=20G --account=rrg-hsn --export=topdir=$topdir,reps=$reps,scripts=$scripts step2_wrapper.combine_reps.sh $REF $MPAQT $SIMG)
    echo $job2
fi
