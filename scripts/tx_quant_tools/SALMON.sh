#!/bin/bash
#SBATCH --job-name="SALMON"
#SBATCH --cpus-per-task=12 
#SBATCH --time=2:00:00
#SBATCH --err=logs/err.%x.%j.log
#SBATCH --output=logs/out.%x.%j.log
#SBATCH --mem=40G
#SBATCH --account=rrg-hsn
#SBATCH --mail-user=michael.j.apostolides@gmail.com
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

#set -eu -o pipefail
echo "STARTING: " $(date)

mkdir $OUTPUT_DIR
cd $OUTPUT_DIR

# SALMON

# Modules required

module load nixpkgs/16.09
module load gcc/7.3.0
module load openmpi/3.1.4
module load salmon/1.3.0

FAIDX=/project/6007998/maposto/reference/salmon/salmon_genomeIndex

salmon quant -p 8 \
                         -i ${FAIDX} \
                         -l A \
                         --validateMappings \
                         --gcBias \
                         -o ${OUTPUT_DIR} \
                         -1 $FASTQ1 \
                         -2 $FASTQ2
