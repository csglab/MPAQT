#!/bin/bash
#SBATCH --job-name="combine_replicate_counts"
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --error=logs/err.%x.%j.log
#SBATCH --time=2:00:00
#SBATCH --mem=20G
#SBATCH --account=rrg-hsn

echo Combine replicate counts
echo $topdir
~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin/Rscript /project/6007998/maposto/scripts/p_matrix_auto/combine_replicate_counts.R --topdir=$topdir

echo Generate P matrix
~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin/Rscript generate_p_matrix.R --topdir=$topdir 

echo Convert P matrix to list
~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin/Rscript 01.convert_to_list.R --topdir=$topdir
