#!/bin/bash

# Set output directory
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023
topdir="/MPAQT/RUNS/P_mat_gen.TEST.July-7-2023"
mkdir -p $topdir

mode=single
#mode=paired

ref_txome=/reference/gencode.v38.transcripts.fa
KALLISTO_IDX=/reference/kallisto/gencode.v38.transcripts.fa.idx

rep=1
# REPLICATES
sh replicates_combined_script.Docker.sh --rep=$rep  --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX

# COMBINE
#job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
#job2=$(sbatch --account=rrg-hsn --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
