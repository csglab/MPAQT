#!/bin/bash
module load apptainer/1.1.6

echo $scripts
singularity exec -B /home \
                  -B /tmp \
                  -B /project/6007998/maposto/reference \
                  -B $topdir \
                  -B /project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT \
                     /project/6007998/maposto/MODULES/MPAQT.V2.simg \
                     bash $scripts/RUN_combine_replicate_counts.sh --topdir=$topdir --reps=$reps 
