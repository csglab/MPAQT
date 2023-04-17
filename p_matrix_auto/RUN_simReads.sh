#!/bin/bash
#SBATCH --job-name="simReads"
#SBATCH --cpus-per-task=1
#SBATCH --time=4:00:00
#SBATCH --mem=20G
#SBATCH --array=10
#SBATCH --err=logs/err.%x.%j.log
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --account=rrg-hsn
#echo $topdir
topdir=/home/maposto/scratch/p_mat.novel_MDA-MB-231_dup1.Sept-16-2021
mkdir $topdir
~/projects/rrg-hsn/maposto/miniconda3/envs/simreads/bin/Rscript /project/6007998/maposto/scripts/p_matrix_array/simReads.R --rep=$SLURM_ARRAY_TASK_ID --topdir=$topdir
