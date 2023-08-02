#!/bin/bash
OUTPUT_DIR=/MPAQT/RUNS/covMX_test
mkdir -p $OUTPUT_DIR

#fasta="/project/6007998/maposto/reference/gencode.v38.transcripts.fa"
fasta="/reference/gencode.v38.transcripts.fa"
#gtf="/project/6007998/maposto/reference/gencode.v38.annotation.gtf.gz"
gtf="/reference/gencode.v38.annotation.gtf.gz"

#env=~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin
#$env/Rscript generate_covMx.R --topdir=$OUTPUT_DIR --fasta=$fasta --gtf=$gtf
#p_list=/reference/P/p_list.spikeins.June-10-2022.Rds
p_list=/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds

Rscript generate_covMx.R --topdir=$OUTPUT_DIR --fasta=$fasta --gtf=$gtf --p_list=$p_list
