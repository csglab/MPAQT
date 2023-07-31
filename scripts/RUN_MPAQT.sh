#!/bin/bash
module load apptainer/1.1.8
echo "STARTING: " $(date)

# TO SET
MPAQT=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT
fastq_dir=/project/6007998/maposto/PROJECTS/neurondiff/20220415_neurondiff_RNAseq
refdir=/project/6007998/maposto/reference
#OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.FULL.V2
OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.FULL.V3
mkdir $OUTPUT_DIR
FASTQ1=$fastq_dir/SOX10_Day61_replicate_1_S5_R1_001.fastq.gz
FASTQ2=$fastq_dir/SOX10_Day61_replicate_1_S5_R2_001.fastq.gz
sample=SOX10_Day61.rep1
SIMG=/project/6007998/maposto/MODULES/MPAQT.V2.simg

# INPUT
scripts=$MPAQT/scripts
p_list=$refdir/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
p_rowSums=$refdir/P/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds
covMx=$refdir/covMx.Rds
KALLISTO_IDX=$refdir/kallisto/gencode.v38.transcripts.fa.idx

singularity exec -B $refdir \
                 -B $MPAQT \
		 -B $OUTPUT_DIR \
                 -B $fastq_dir \
                 $SIMG \
                 bash MPAQT.sh --scripts=$MPAQT/scripts \
                    --KALLISTO_IDX=$KALLISTO_IDX \
                    --p_list=$p_list \
	            --p_rowSums=$p_rowSums \
	            --covMx=$covMx \
	            --sample=$sample \
	            --FASTQ1=$FASTQ1 \
	            --FASTQ2=$FASTQ2 \
	            --OUTPUT_DIR=$OUTPUT_DIR

# DOCKER
#OUTPUT_DIR=/MPAQT/RUNS/MPAQT_test.July-13-2023 
#mkdir $OUTPUT_DIR
#p_list=/reference/P/p_list.pmat_single.2.4_billion.Oct-15-2021.Rds
#p_rowSums=/reference/P/p_rowSums.pmat_single.2.4_billion.Oct-15-2021.Rds
#covMx=/MPAQT/RUNS/covMX_test.Day61.rep1/covMx.Rds

#Singularity shell test
#OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.July-13-2023      
#OUTPUT_DIR=/project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT/RUNS/MPAQT_test.July-17-2023

