#!/bin/bash

echo "STARTING: " $(date)

# Set output directory
#OUTPUT_DIR=/MPAQT/RUNS/covMX_test.Day61.rep1
OUTPUT_DIR=/MPAQT/RUNS/RUN_MPAQT.neurondiff.Day61.rep1.JULY-10-2023
mkdir $OUTPUT_DIR

p_list=/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
p_rowSums=/reference/P/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds
covMx=/MPAQT/RUNS/covMX_test.Day61.rep1/covMx.Rds
# MPAQT
Rscript MPAQT.R --topdir=$OUTPUT_DIR --p_list=$p_list --p_rowSums=$p_rowSums --covMx=$covMx