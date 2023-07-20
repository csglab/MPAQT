#!/bin/bash

# Set output directory
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023
#topdir="/MPAQT/RUNS/P_mat_gen.TEST.July-7-2023"
#topdir="/MPAQT/RUNS/P_mat_gen.TEST.July-10-2023"

# DOCKER
#topdir="/MPAQT/RUNS/P_mat_gen.TEST2.July-10-2023"
#mkdir -p $topdir
#ref_txome=/reference/gencode.v38.transcripts.fa
#KALLISTO_IDX=/reference/kallisto/gencode.v38.transcripts.fa.idx

# SINGULARITY
#topdir="/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.July-11-2023"
#topdir="/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.July-13-2023"
topdir="/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.July-13-2023"
topdir="/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.July-17-2023"
topdir="/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.July-17-2023.V2"
topdir="/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.July-17-2023.V3"

mkdir -p $topdir
ref_txome=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts
#mode=paired
mode=single
#reps=24
reps=2
#lib_size=100000000
lib_size=10000
# REPLICATES
for (( rep = 1; rep <= $reps; rep++ )); do
    echo $rep
    bash replicates_combined_script.Docker.sh --rep=$rep  --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX --scripts=$scripts --lib_size=$lib_size
done

bash RUN_combine_replicate_counts.Docker.sh $topdir $reps
