#!/bin/bash

topdir=$1
reps=$2
echo Combine replicate counts
echo $topdir
Rscript combine_replicate_counts.R --topdir=$topdir --reps=$reps

echo Generate P matrix
Rscript generate_p_matrix.R --topdir=$topdir 

echo Convert P matrix to list
Rscript 01.convert_to_list.R --topdir=$topdir
