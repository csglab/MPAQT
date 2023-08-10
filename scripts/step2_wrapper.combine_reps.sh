#!/bin/bash
module load apptainer

echo $scripts
REF=$1
MPAQT=$2
SIMG=$3
singularity exec \
                  -B $REF \
                  -B $topdir \
                  -B $MPAQT \
                     $SIMG \
                     bash $scripts/combine_pmat_replicates.sh --topdir=$topdir --reps=$reps 
