#!/bin/bash
#SBATCH --job-name="combine_replicate_counts"
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --error=logs/err.%x.%j.log
#SBATCH --time=2:00:00
#SBATCH --mem=20G
#SBATCH --account=rrg-hsn

env=~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin

echo Combine replicate counts
echo $topdir
$env/Rscript combine_replicate_counts.R --topdir=$topdir

echo Generate P matrix
$env/Rscript generate_p_matrix.R --topdir=$topdir 

echo Convert P matrix to list
$env/Rscript 01.convert_to_list.R --topdir=$topdir
