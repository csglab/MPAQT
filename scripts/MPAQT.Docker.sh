#!/bin/bash

echo "STARTING: " $(date)

# DOCKER
#OUTPUT_DIR=/MPAQT/RUNS/MPAQT_test.July-13-2023 
#mkdir $OUTPUT_DIR
#p_list=/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
#p_rowSums=/reference/P/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds
#covMx=/MPAQT/RUNS/covMX_test.Day61.rep1/covMx.Rds

#Singularity shell test
#OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.July-13-2023       
OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.July-17-2023
#OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test
mkdir $OUTPUT_DIR

refdir=/project/6007998/maposto
p_list=$refdir/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
p_rowSums=$refdir/reference/P/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds
covMx=$refdir/reference/covMx.Rds

# MPAQT
Rscript MPAQT.R --topdir=$OUTPUT_DIR --p_list=$p_list --p_rowSums=$p_rowSums --covMx=$covMx
