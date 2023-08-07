#!/bin/bash
echo "STARTING: " $(date)

# TO SET
MPAQT=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT
refdir=/project/6007998/maposto/reference
OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/sqanti
mkdir -p $OUTPUT_DIR

sqanti3=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.FULL/SOX10_Day61.rep1.transcriptome.sqanti3_classification.filtered_lite_classification.txt
p_list=/project/6007998/maposto/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds

Rscript sqanti.prepare_LR_counts.R --topdir=$OUTPUT_DIR --p_list=$p_list --sqanti3=$sqanti3
