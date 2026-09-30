#!/bin/bash

#######################################################
# TO SET
#######################################################

# DOCKER
#fasta="/reference/gencode.v38.transcripts.fa"
#gtf="/reference/gencode.v38.annotation.gtf.gz"
#P=/MPAQT/reference/P/P.Oct-15-2021.Rds
#OUTPUT_DIR=/MPAQT/RUNS/covMX_test
#mkdir -p $OUTPUT_DIR

# SINGULARITY
fasta="/project/6007998/maposto/reference/gencode.v38.transcripts.fa"
gtf="/project/6007998/maposto/reference/gencode.v38.annotation.gtf.gz"
P=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/reference/P/P.Oct-15-2021.Rds
OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/covMX_test.Aug-10-2023
mkdir -p $OUTPUT_DIR

#######################################################
# RUN SCRIPT 
#######################################################

Rscript generate_covMx.R --topdir=$OUTPUT_DIR --fasta=$fasta --gtf=$gtf --P=$P
