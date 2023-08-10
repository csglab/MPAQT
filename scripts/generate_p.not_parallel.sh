#!/bin/bash

# This script runs the P matrix generation in a linear fashion

#######################################################
# TO SET
#######################################################

# DOCKER
#topdir="/MPAQT/RUNS/P_mat_gen.TEST2.July-10-2023"
#ref_txome=/reference/gencode.v38.transcripts.fa
#KALLISTO_IDX=/reference/kallisto/gencode.v38.transcripts.fa.idx

# SINGULARITY
topdir=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.Aug-10-2023
mkdir -p $topdir
ref_txome=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts

# ARGUMENTS
mode=single
#reps=24
reps=2
#lib_size=100000000
lib_size=10000

#######################################################
# RUN SCRIPT
#######################################################

# REPLICATES
for (( rep = 1; rep <= $reps; rep++ )); do
    echo $rep
    bash $scripts/generate_replicate_pmat.sh --rep=$rep  --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX --scripts=$scripts --lib_size=$lib_size
done

bash $scripts/combine_pmat_replicates.sh --topdir=$topdir --reps=$reps 
