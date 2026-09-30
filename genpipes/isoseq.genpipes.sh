#!/bin/bash

# INPUT 
outdir=$1
sn=$2
#primers_fasta=NEB_SMARTer_primers.fasta
primers_fasta=$3
#demux_bam=$cwd/MDA_MB_231_duplicate_1.210222_AH_IsoSeq.ccs.demux.bam
demux_bam=$4

#cd $outdir

#SETUP ENV
module purge
conda deactivate

source /project/6007998/maposto/miniconda3/etc/profile.d/conda.sh
conda activate SQANTI3.env
export PYTHONPATH=$PYTHONPATH:/home/maposto/projects/rrg-hsn/maposto/MODULES/cDNA_Cupcake/sequence

# REFERNECE
refdir=/project/6007998/maposto/reference
ref_fasta=$refdir/GRCh38.p13.genome.fa
ref_mmi=$refdir/GRCh38.p13.genome.mmi

        ### Removing primers sequences ---------------------------------
        lima \
                $demux_bam \
                ${primers_fasta} \
                ${sn}.fl.bam \
                --isoseq \
                --peek-guess \
                --log-level INFO

## Renaming FL BAM file
bam=${sn}.fl.NEB_5p--NEB_Clontech_3p.bam
mv $bam ${bam/.NEB_5p--NEB_Clontech_3p/}

        ### Removing polyA tails and other concatemers ------------------
        isoseq3 refine \
                ${sn}.fl.bam \
                ${primers_fasta} \
                ${sn}.flnc.bam \
                --require-polya \
                --log-level DEBUG

        ### Clustering full-length transcripts --------------------------
        isoseq3 cluster \
                ${sn}.flnc.bam \
                ${sn}.clustered.bam \
                --use-qvs \
                --verbose

        ### Aligning clusters' representative transcript ----------------
        pbmm2 align \
                ${ref_mmi} \
                ${sn}.clustered.hq.bam \
                ${sn}.clustered.hq.aligned.bam \
                --preset ISOSEQ \
                --sort \
                --log-level INFO
        ### Collapsing aligned transcripts to generate a transcriptome --
        isoseq3 collapse \
                ${sn}.clustered.hq.aligned.bam \
                ${sn}.transcriptome.gff ## ${sn}.clustered.hq.aligned.collapsed.gff
