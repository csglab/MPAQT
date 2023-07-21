#!/bin/bash
module load apptainer/1.1.6

REF=$1
MPAQT=$2
SIMG=$3
singularity exec \
                  -B $REF \
                  -B $topdir \
                  -B $MPAQT \
                     $SIMG \
                     bash $scripts/replicates_combined_script.Docker.sh --rep=$SLURM_ARRAY_TASK_ID --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX --lib_size=$lib_size
#singularity exec \
#                  -B /project/6007998/maposto/reference \
#                  -B $topdir \
#                  -B /project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT \
#                     /project/6007998/maposto/MODULES/MPAQT.V2.simg \
#                     bash $scripts/replicates_combined_script.Docker.sh --rep=$SLURM_ARRAY_TASK_ID --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX --lib_size=$lib_size
