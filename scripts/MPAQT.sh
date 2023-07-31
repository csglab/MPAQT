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
        --FASTQ1=*)
        FASTQ1="${1#*=}"
        shift
        ;;
        --FASTQ2=*)
        FASTQ2="${1#*=}"
        shift
        ;;
        --OUTPUT_DIR=*)
        OUTPUT_DIR="${1#*=}"
        shift
        ;;
    esac
done

echo Print arg values:
echo scripts: $scripts
echo KALLISTO_IDX: $KALLISTO_IDX
echo p_list: $p_list
echo p_rowSums: $p_rowSums
echo covMx: $covMx
echo sample: $sample
echo FASTQ1: $FASTQ1
echo FASTQ2: $FASTQ2
echo OUTPUT_DIR: $OUTPUT_DIR
echo
echo "STARTING: " $(date)
echo
ls $KALLISTO_IDX  $p_list $p_rowSums $covMx $FASTQ1 $FASTQ2 $OUTPUT_DIR
ls -d $scripts

# MPAQT: KALLISTO BUS
kallisto bus --num --paired  -o $OUTPUT_DIR -i \
  $KALLISTO_IDX \
  $FASTQ1 \
  $FASTQ2

bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus

#EC counts
Rscript $scripts/EC_counts_bustools.R --topdir=$OUTPUT_DIR

# MPAQT
Rscript $scripts/MPAQT.R --topdir=$OUTPUT_DIR --p_list=$p_list --p_rowSums=$p_rowSums --covMx=$covMx --sample=$sample
