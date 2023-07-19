#!/bin/bash

# DOCKER
#fasta="/reference/gencode.v38.transcripts.fa"
#gtf="/reference/gencode.v38.annotation.gtf.gz"
#p_list=/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
#OUTPUT_DIR=/MPAQT/RUNS/covMX_test
#mkdir -p $OUTPUT_DIR

# SINGULARITY
fasta="/project/6007998/maposto/reference/gencode.v38.transcripts.fa"
gtf="/project/6007998/maposto/reference/gencode.v38.annotation.gtf.gz"
p_list=/project/6007998/maposto/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/covMX_test.July-19-2023

mkdir -p $OUTPUT_DIR

Rscript generate_covMx.R --topdir=$OUTPUT_DIR --fasta=$fasta --gtf=$gtf --p_list=$p_list
