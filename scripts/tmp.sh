#!/bin/bash
module load apptainer/1.1.6
#singularity exec -B /home \
singularity shell -B /home \
                  -B /tmp \
                  -B /project/6007998/maposto/reference \
                  -B $topdir \
                  -B /project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT \
                     /project/6007998/maposto/MODULES/MPAQT.simg \
                     bash replicates_combined_script.Docker.sh --rep=1  --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX
