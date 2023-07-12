#!/bin/bash

# Set output directory
#topdir=/home/maposto/scratch/pmat_single.TEST_github.JULY-3-2023
#topdir="/MPAQT/RUNS/P_mat_gen.TEST.July-7-2023"
#topdir="/MPAQT/RUNS/P_mat_gen.TEST.July-10-2023"
#topdir="/MPAQT/RUNS/P_mat_gen.TEST2.July-10-2023"
topdir="/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/P_mat_gen.cluster.July-11-2023"
mkdir -p $topdir

mode=single
#mode=paired

#ref_txome=/reference/gencode.v38.transcripts.fa
ref_txome=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx

#reps=24
reps=2
# REPLICATES
for (( rep = 1; rep <= $reps; rep++ )); do
    echo $rep
    bash replicates_combined_script.Docker.sh --rep=$rep  --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX
done

bash RUN_combine_replicate_counts.Docker.sh $topdir $reps
# COMBINE
#job2=$(sbatch --account=rrg-hsn --dependency=afterany:$job1 --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
#job2=$(sbatch --account=rrg-hsn --export=topdir=$topdir,env=$env RUN_combine_replicate_counts.sh) 
