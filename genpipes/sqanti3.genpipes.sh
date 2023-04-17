#!/bin/bash

# INPUT 
outdir=$1
sn=$2
gff=$3
counts=$4
star_splice_junctions=$5

#SETUP ENV
module purge
conda deactivate

source /project/6007998/maposto/miniconda3/etc/profile.d/conda.sh
conda activate SQANTI3.env
export PYTHONPATH=$PYTHONPATH:/home/maposto/projects/rrg-hsn/maposto/MODULES/cDNA_Cupcake/sequence
sqanti_dir=/home/maposto/projects/rrg-hsn/maposto/MODULES/SQANTI3

#REFERENCE
refdir=/project/6007998/maposto/reference
ref_gtf="$refdir/annotation/gencode.v38.primary_assembly.annotation.gtf"
ref_fasta=$refdir/GRCh38.p13.genome.fa
cage_peaks_bed="$refdir/cage-peaks/refTSS_v3.1_human_coordinate.hg38.gencode.bed"
polyA_motif_list="$refdir/polyA-peaks/human.polyA.list.txt"
polyA_peaks_bed="$refdir/polyA-peaks/atlas.clusters.2.0.GRCh38.96.gencode.bed"
intropolis_bed="$refdir/intropolis/intropolis.v1.hg19_with_liftover_to_hg38.tsv.min_count_10.modified"
tappas_ref_gff="$refdir/tappas/Homo_sapiens_GRCh38_Ensembl_86.gff3"
#kallisto_abundance=/project/6007998/maposto/PROJECTS/genpipes_runs/MDA-MB-231/output.MDA-MB-231.June-7-2021/kallisto/MDA-MB-231/abundance_transcripts.tsv
#star_splice_junctions=/project/6007998/maposto/PROJECTS/genpipes_runs/MDA-MB-231/output.MDA-MB-231.June-7-2021/alignment/MDA-MB-231/readset1/SJ.out.tab

                #-n 8 \
#                --expression $kallisto_abundance \
        ### Generating SQANTI3 QC report for the transcriptomes -----------------
        python3 $sqanti_dir/sqanti3_qc.py \
                --gtf ${gff}  \
                ${ref_gtf} \
                ${ref_fasta} \
                --dir $outdir \
                --output ${sn}.transcriptome.sqanti3 \
                --fl_count ${counts} \
                --cage_peak ${cage_peaks_bed} \
                --polyA_motif_list ${polyA_motif_list} \
                --polyA_peak ${polyA_peaks_bed} \
                -n 1 \
                --isoAnnotLite \
                --gff3 ${tappas_ref_gff} \
                -c $star_splice_junctions

        python3 $sqanti_dir/sqanti3_RulesFilter.py \
                $outdir/${sn}.transcriptome.sqanti3_classification.txt \
                $outdir/${sn}.transcriptome.sqanti3_corrected.fasta \
                $outdir/${sn}.transcriptome.sqanti3_corrected.gtf
