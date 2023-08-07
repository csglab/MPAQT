#!/bin/bash


echo reading in args
while test $# -gt 0;do
    case $1 in
        --scripts=*)
        scripts="${1#*=}"
        shift
        ;;
        --KALLISTO_IDX=*)
        KALLISTO_IDX="${1#*=}"
        shift
        ;;
        --p_list=*)
        p_list="${1#*=}"
        shift
        ;;
        --p_rowSums=*)
        p_rowSums="${1#*=}"
        shift
        ;;
        --covMx=*)
        covMx="${1#*=}"
        shift
        ;;
        --sample=*)
        sample="${1#*=}"
        shift
        ;;
        --FASTQS=*)
        FASTQS="${1#*=}"
        shift
        ;;
        --LR_counts*)
        LR_counts="${1#*=}"
        shift
        ;;
        --mode=*)
        mode="${1#*=}"
        shift
        ;;
        --OUTPUT_DIR=*)
        OUTPUT_DIR="${1#*=}"
        shift
        ;;
    esac
done
#        --FASTQ1=*)
#        FASTQ1="${1#*=}"
#        shift
#        ;;
#        --FASTQ2=*)
#        FASTQ2="${1#*=}"
#        shift
#        ;;

echo Print arg values:
echo scripts: $scripts
echo KALLISTO_IDX: $KALLISTO_IDX
echo p_list: $p_list
echo p_rowSums: $p_rowSums
echo covMx: $covMx
echo sample: $sample
echo FASTQS: $FASTQS
echo mode: $mode
echo OUTPUT_DIR: $OUTPUT_DIR
echo
echo "STARTING: " $(date)
echo
ls $KALLISTO_IDX  $p_list $p_rowSums $covMx $FASTQ1 $FASTQ2
ls -d $OUTPUT_DIR
ls -d $scripts

IFS=',' read -ra FASTQS <<< "$FASTQS"

echo FASTQS: ${FASTQS[@]}
#exit 0

## MPAQT: KALLISTO BUS
## Runs kallisto's pseudoalignment tool to map reads to equivalence classes. 
## Generates a bus file which contains the information specifying which 
## equivalence class each read corresponds to
#if [ "$mode" = paired ]; then
#echo paired end
#FASTQ1=${FASTQS[0]}
#FASTQ2=${FASTQS[1]}
#echo FASTQ1: $FASTQ1 
#echo FASTQ2: $FASTQ2 
#kallisto bus --num --paired -t 32  -o $OUTPUT_DIR -i \
#  $KALLISTO_IDX \
#  $FASTQ1 \
#  $FASTQ2
#
#elif [ "$mode" = single ]; then
#echo single end
#kallisto bus --num -o $OUTPUT_DIR -i \
#  $TRANSCRIPTOME \
#  ${FASTQS[@]} 
#
#else
# exit 1
#fi
## BUSTOOLS TEXT
## Converts the bus file into a text file which is more easily useable
#bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus
#
## EC COUNTS: 
## counts the number of reads in each EC, and outputs this data into a 
## format compatible with input to MPAQT.R
## Outputs file reads.ecs.counts.Rds 
#Rscript $scripts/EC_counts_bustools.R --topdir=$OUTPUT_DIR

# MPAQT
# Runs the MPAQT statistical framework
Rscript $scripts/MPAQT.R --topdir=$OUTPUT_DIR --p_list=$p_list --p_rowSums=$p_rowSums --covMx=$covMx --sample=$sample --LR_counts=$LR_counts
