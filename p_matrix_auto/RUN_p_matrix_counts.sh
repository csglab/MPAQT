#!/bin/bash
#SBATCH --job-name="p_matrix_counts"
#SBATCH --cpus-per-task=1
#SBATCH --time=3:00:00
#SBATCH --mem=40G
#SBATCH --account=rrg-hsn
#source activate_conda.sh
~/projects/rrg-hsn/maposto/miniconda3/envs/r4/bin/Rscript p_matrix_counts.R --rep=$rep --topdir=$topdir
