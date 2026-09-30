#!/bin/bash

# This script combines the replicate simulations, generates sparse matrix P,
# then converts P into formats more easily useable as inputs to MPAQT
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

# COMBINE REPLICATES
# Combines the 24 replicates into a single object 
echo Combine replicate counts
echo $topdir
Rscript combine_replicate_counts.R --topdir=$topdir --reps=$reps

# GENERATE P
# Generates matrix P as a sparse matrix
# Outputs file p_matrix.Rds
echo Generate P matrix
Rscript generate_p_matrix.R --topdir=$topdir --reps=$reps 

# Generates files p_rowSums.Rds and p_list.Rds, which are used as input to MPAQT
echo Convert P matrix to list
Rscript 01.convert_to_list.R --topdir=$topdir
