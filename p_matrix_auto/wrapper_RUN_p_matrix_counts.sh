#!/bin/bash


reps=( $(seq 1 24 ) )
#reps=( $(seq 1 2 ) )

topdir=/home/maposto/scratch/p_mat.novel_MDA-MB-231_dup1.Sept-16-2021
for rep in ${reps[@]};do

OUTPUT_DIR=$topdir/rep$rep
sbatch --export=rep=$rep,topdir=$topdir --error=$OUTPUT_DIR/counts.err.log --output=$OUTPUT_DIR/counts.out.log RUN_p_matrix_counts.sh 

done
