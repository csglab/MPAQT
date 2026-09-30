#!/bin/bash
module load apptainer

REF=$1
MPAQT=$2
SIMG=$3
singularity exec \
                  -B $REF \
                  -B $topdir \
                  -B $MPAQT \
                     $SIMG \
                     bash $scripts/generate_replicate_pmat.sh --rep=$SLURM_ARRAY_TASK_ID --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX --lib_size=$lib_size
