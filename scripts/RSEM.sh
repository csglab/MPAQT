#!/bin/bash
#SBATCH --job-name="RSEM"
#SBATCH --cpus-per-task=8
#SBATCH --time=24:00:00
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

# MODULES + REF
module load rsem/1.3.3
bowtie_path=/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Core/bowtie2/2.4.2/bin
ref=/project/6007998/maposto/MODULES/RSEM/reference/prefix

#        --no-bam-output \
rsem-calculate-expression -p 8 \
        --bowtie2 --bowtie2-path $bowtie_path \
        --paired-end \
        $FASTQ1 $FASTQ2 \
        $ref $OUTPUT_DIR/rsem
