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
#OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.July-17-2023

# INPUT
FASTQ1=/project/6007998/maposto/PROJECTS/neurondiff/20220415_neurondiff_RNAseq/SOX10_Day61_replicate_1_S5_R1_001.fastq.gz
FASTQ2=/project/6007998/maposto/PROJECTS/neurondiff/20220415_neurondiff_RNAseq/SOX10_Day61_replicate_1_S5_R2_001.fastq.gz
sample=SOX10_Day61.rep1
OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.FULL.V2
mkdir $OUTPUT_DIR

refdir=/project/6007998/maposto
p_list=$refdir/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
p_rowSums=$refdir/reference/P/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds
covMx=$refdir/reference/covMx.Rds
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
scripts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/scripts

bash MPAQT.sh --scripts=$scripts \
              --KALLISTO_IDX=$KALLISTO_IDX \
	      --p_list=$p_list \
	      --p_rowSums=$p_rowSums \
	      --covMx=$covMx \
	      --sample=$sample \
	      --FASTQ1=$FASTQ1 \
	      --FASTQ2=$FASTQ2 \
	      --OUTPUT_DIR=$OUTPUT_DIR
