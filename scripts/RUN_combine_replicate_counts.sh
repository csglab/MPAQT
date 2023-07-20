#!/bin/bash

while test $# -gt 0;do
    case $1 in
        --reps=*)
        reps="${1#*=}"
        shift
        ;;
        --topdir=*)
        topdir="${1#*=}"
        shift
        ;;
    esac
done

echo Combine replicate counts
echo $topdir
Rscript combine_replicate_counts.R --topdir=$topdir --reps=$reps

echo Generate P matrix
Rscript generate_p_matrix.R --topdir=$topdir --reps=$reps 

echo Convert P matrix to list
Rscript 01.convert_to_list.R --topdir=$topdir
