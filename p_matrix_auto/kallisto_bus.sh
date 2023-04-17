#!/bin/bash
TRANSCRIPTOME=$1
OUTPUT_DIR=$2
FASTQ1=$3
FASTQ2=$4
echo "STARTING: " $(date)

cd $OUTPUT_DIR
echo TRANSCRIPTOME=$TRANSCRIPTOME
echo OUTPUT_DIR=$OUTPUT_DIR
echo FASTQ1=$FASTQ1
echo FASTQ2=$FASTQ2

bin=/project/6007998/maposto/MODULES/kallisto/build/usr/local/bin
$bin/kallisto bus --num --paired -o $OUTPUT_DIR -i  $TRANSCRIPTOME $FASTQ1 $FASTQ2

module load bustools
bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus
