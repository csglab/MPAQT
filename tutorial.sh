#!/bin/bash
set -eo pipefail

### Cloning the MPAQT repository
git clone https://github.com/csglab/MPAQT.git
cd MPAQT

### Setting up the environment
export MPAQT_DIR=$PWD
export PATH=$MPAQT_DIR:$PATH

### Downloading reference transcriptome and annotation files
mkdir references
wget "https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_46/gencode.v46.transcripts.fa.gz" -P references
wget "https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_46/gencode.v46.annotation.gtf.gz" -P references

# ── mpaqt
# ── references
#     ├── gencode.v46.annotation.gtf.gz
#     └── gencode.v46.transcripts.fa.gz

### Indexing the reference transcriptome and annotation files (one-time only)
mpaqt index \
	--ref_txome references/gencode.v46.transcripts.fa.gz \
	--ref_annot references/gencode.v46.annotation.gtf.gz \
	--output references/gencode.v46.index \
    --threads 32

# ── mpaqt
# ── references
#     ├── gencode.v46.annotation.gtf.gz
#     ├── gencode.v46.transcripts.fa.gz
#     ├── gencode.v46.index.kallisto
#     └── gencode.v46.index.mpaqt

### Creating a new project and samples
project='neurondiff'
samples='hESC_Day0_1 hESC_Day0_2 SOX10_Day41_1 SOX10_Day41_2 SOX10_Day61_1 SOX10_Day61_2'
samples=($samples)

mpaqt create project \
	--index references/gencode.v46.index.mpaqt \
	${project}

# ── mpaqt
# ── references
#     ├── gencode.v46.annotation.gtf.gz
#     ├── gencode.v46.transcripts.fa.gz
#     ├── gencode.v46.index.kallisto
#     └── gencode.v46.index.mpaqt
# ── projects
#     └── neurondiff
#         ├── covMx.Rds
#         └── P.Rds

mpaqt create sample \
	--project ${project} \
    ${samples[*]}

# ── mpaqt
# ── references
#     ├── gencode.v46.annotation.gtf.gz
#     ├── gencode.v46.transcripts.fa.gz
#     ├── gencode.v46.index.kallisto
#     └── gencode.v46.index.mpaqt
# ── projects
#     └── neurondiff
#         ├── covMx.Rds
#         ├── P.Rds
#         └── samples
#             ├── hESC_Day0_1
#             ├── hESC_Day0_2
#             ├── SOX10_Day41_1
#             ├── SOX10_Day41_2
#             ├── SOX10_Day61_1
#             └── SOX10_Day61_2
	
### Preparing short-read data for each sample
for sample in ${samples[@]}
do
    mpaqt prepare short-read \
        --project ${project} \
        --sample ${sample} \
        --bus data/${project}/short-reads/equivalent-classes/${sample}.output.bus \
        --matrix_ec data/${project}/short-reads/equivalent-classes/${sample}.matrix.ec
done

# ── mpaqt
# ── references
#     ├── ...
# ── projects
#     └── neurondiff
#         ├── ...
#         └── samples
#             ├── hESC_Day0_1
#                 └── reads.ecs.counts.Rds
#             ├── ...

### Preparing long-read data for each sample
for sample in ${samples[@]}
do
    mpaqt prepare long-read \
        --project ${project} \
        --sample ${sample} \
        --counts data/${project}/long-reads/isoform-quantification/${sample}.counts_transcript.txt
done

# ── mpaqt
# ── references
#     ├── ...
# ── projects
#     └── neurondiff
#         ├── ...
#         └── samples
#             ├── hESC_Day0_1
#                 ├── reads.ecs.counts.Rds
#                 └── LR.counts.Rds
#             ├── ...

### Quantifying expression for each sample
for sample in ${samples[@]}
do
mpaqt quant \
    --project ${project} \
    --sample ${sample}
done

# ── mpaqt
# ── references
#     ├── ...
# ── projects
#     └── neurondiff
#         ├── ...
#         └── samples
#             ├── hESC_Day0_1
#                 ├── ...
#                 └── quant
#                     ├── hESC_Day0_1.MPAQT.SR.tsv
#                     └── hESC_Day0_1.MPAQT.LR_SR.tsv
#             ├── ...