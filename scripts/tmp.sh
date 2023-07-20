#!/bin/bash
module load apptainer/1.1.6
#cd $scripts
#singularity shell -B /home \
singularity exec -B /home \
                  -B /tmp \
                  -B /project/6007998/maposto/reference \
                  -B $topdir \
                  -B /project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT \
                     /project/6007998/maposto/MODULES/MPAQT.V2.simg \
                     bash $scripts/replicates_combined_script.Docker.sh --rep=$SLURM_ARRAY_TASK_ID --topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX --lib_size=$lib_size
