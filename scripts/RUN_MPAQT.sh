#!/bin/bash
module load apptainer/1.1.8
echo "STARTING: " $(date)

#######################################################
# TO SET
#######################################################
# INPUT DATA
fastq_dir=/project/6007998/maposto/PROJECTS/neurondiff/20220415_neurondiff_RNAseq
FASTQ1=$fastq_dir/SOX10_Day61_replicate_1_S5_R1_001.fastq.gz
FASTQ2=$fastq_dir/SOX10_Day61_replicate_1_S5_R2_001.fastq.gz
FASTQS=$FASTQ1,$FASTQ2
LR_counts=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/sqanti/LR.counts.Rds

# OUTPUT DIRECTORY
OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT.Aug-9-2023
mkdir $OUTPUT_DIR

# CODE
MPAQT=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT
SIMG=/project/6007998/maposto/MODULES/MPAQT.V2.simg

# REFERENCE
refdir=/project/6007998/maposto/reference
P=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/reference/P/P.Oct-15-2021.Rds
covMx=/project/6007998/maposto/reference/covMx.Rds
KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx

# MODE
mode=paired

#######################################################
# RUN SCRIPT  
#######################################################

scripts=$MPAQT/scripts
singularity exec -B $refdir \
                 -B $MPAQT \
		 -B $OUTPUT_DIR \
                 -B $fastq_dir \
                 $SIMG \
                 bash MPAQT.sh --scripts=$MPAQT/scripts \
                    --KALLISTO_IDX=$KALLISTO_IDX \
	            --P=$P \
	            --covMx=$covMx \
	            --FASTQS=$FASTQS\
		    --LR_counts=$LR_counts \
	            --mode=$mode\
	            --OUTPUT_DIR=$OUTPUT_DIR

# DOCKER
#OUTPUT_DIR=/MPAQT/RUNS/MPAQT_test.July-13-2023 
#mkdir $OUTPUT_DIR
#p_list=/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
#p_rowSums=/reference/P/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds
#covMx=/MPAQT/RUNS/covMX_test.Day61.rep1/covMx.Rds

## SAMPLE SINGLE END
#fastq_dir=/project/6007998/maposto/PROJECTS/09152015_MDA-LM2_RNA-seq/
#FASTQ1=/project/6007998/maposto/PROJECTS/09152015_MDA-LM2_RNA-seq/MDA-Par_r1.fastq
#FASTQ2=/project/6007998/maposto/PROJECTS/09152015_MDA-LM2_RNA-seq/MDA-Par_r2.fastq
#FASTQS=$FASTQ1,$FASTQ2
#mode=single

