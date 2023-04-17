#!/bin/bash
#SBATCH --job-name="kallisto_index"
#SBATCH --cpus-per-task=1
#SBATCH --time=3:00:00
#SBATCH --mem=30G
#SBATCH --account=rrg-hsn
#SBATCH --mail-user=michael.j.apostolides@gmail.com
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

bin=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
$bin/kallisto index \
                -i /project/6007998/maposto/reference/gencode.v38.transcripts.novel_MDA-MB-231_dup1.Sept-16-2021.fa.kidx \
                /project/6007998/maposto/reference/gencode.v38.transcripts.novel_MDA-MB-231_dup1.Sept-16-2021.fa 
