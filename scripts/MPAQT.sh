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
        --P=*)
        P="${1#*=}"
        shift
        ;;
        --covMx=*)
        covMx="${1#*=}"
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

echo Print arg values:
echo scripts: $scripts
echo KALLISTO_IDX: $KALLISTO_IDX
echo P: $P
echo covMx: $covMx
echo sample: $sample
echo FASTQS: $FASTQS
echo mode: $mode
echo OUTPUT_DIR: $OUTPUT_DIR
echo
echo "STARTING: " $(date)
echo
ls $KALLISTO_IDX  $P $covMx 
ls -d $OUTPUT_DIR
ls -d $scripts

IFS=',' read -ra FASTQS <<< "$FASTQS"

echo FASTQS: ${FASTQS[@]}

# MPAQT: KALLISTO BUS
# Runs kallisto's pseudoalignment tool to map reads to equivalence classes. 
# Generates a bus file which contains the information specifying which 
# equivalence class each read corresponds to
if [ "$mode" = paired ]; then
echo paired end
FASTQ1=${FASTQS[0]}
FASTQ2=${FASTQS[1]}
echo FASTQ1: $FASTQ1 
echo FASTQ2: $FASTQ2 
kallisto bus --num --paired -t 32  -o $OUTPUT_DIR -i \
  $KALLISTO_IDX \
  $FASTQ1 \
  $FASTQ2

elif [ "$mode" = single ]; then
echo single end
kallisto bus --num -o $OUTPUT_DIR -i \
  $TRANSCRIPTOME \
  ${FASTQS[@]} 

else
 exit 1
fi
# BUSTOOLS TEXT
# Converts the bus file into a text file which is more easily useable
bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus

# EC COUNTS: 
# counts the number of reads in each EC, and outputs this data into a 
# format compatible with input to MPAQT.R
# Outputs file reads.ecs.counts.Rds 
Rscript $scripts/EC_counts_bustools.R --topdir=$OUTPUT_DIR

# MPAQT
# Runs the MPAQT statistical framework
echo $P
Rscript $scripts/MPAQT.R --topdir=$OUTPUT_DIR --p_matrix=$P --covMx=$covMx --LR_counts=$LR_counts 
