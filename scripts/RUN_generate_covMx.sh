#!/bin/bash
OUTPUT_DIR=/home/maposto/scratch/TEST
mkdir -p $OUTPUT_DIR

fasta="/project/6007998/maposto/reference/gencode.v38.transcripts.fa"
gtf="/project/6007998/maposto/reference/gencode.v38.annotation.gtf.gz"

env=~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin
$env/Rscript generate_covMx.R --topdir=$OUTPUT_DIR --fasta=$fasta --gtf=$gtf
