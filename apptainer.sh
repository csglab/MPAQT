#!/bin/bash

module load apptainer/1.1.6

singularity shell -B /home \
                  -B /tmp \
                  -B /project/6007998/maposto/reference \
                  -B /project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT \
                     /project/6007998/maposto/MODULES/MPAQT.V2.simg

singularity exec -B /home \
                  -B /tmp \
                  -B /project/6007998/maposto/reference \
                  -B /project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT \
                     /project/6007998/maposto/MODULES/MPAQT.simg \
		     bash TOP_generate_p.Docker.sh
# singularity exec -B /home -B /absolute/path/to/MetaFusion -B /tmp -B /local/path/to/tmp  /absolute/path/to/MetaFusion.simg bash RUN_MetaFusion.Singularity.sh
