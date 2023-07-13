#!/bin/bash

# Loop through arguments and process them
#--topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX
#        --rep=*)
#        rep="${1#*=}"
#        shift
#        ;;

echo reading in args
while test $# -gt 0;do
    case $1 in
        --rep=*)
        rep="${1#*=}"
        shift
        ;;
        --topdir=*)
        topdir="${1#*=}"
        shift
        ;;
        --mode=*)
        mode="${1#*=}"
        shift
        ;;
        --ref_txome=*)
        ref_txome="${1#*=}"
        shift
        ;;
        --KALLISTO_IDX=*)
        KALLISTO_IDX="${1#*=}"
        shift
        ;;
        #*)
        #OTHER_ARGUMENTS+=("$1")
        #shift # Remove generic argument from processing
        #;;
    esac
done
#rep=$SLURM_ARRAY_TASK_ID
echo Print arg values: 
echo rep: $rep 
echo topdir: $topdir 
echo mode: $mode 
echo ref_txome: $ref_txome 
echo KALLISTO_IDX: $KALLISTO_IDX
echo
echo "STARTING: " $(date)
echo

# Arguments
OUTPUT_DIR=$topdir/rep$rep
sample=SIM.$rep

# Generate fastqs
echo Generating fastq number $rep
echo Running simReads.R in $mode mode
echo $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
Rscript simReads.R --rep=$rep --topdir=$OUTPUT_DIR --sample=$sample --ref_txome=$ref_txome --mode=$mode

# Run kallisto bus
echo Run kallisto bus $rep
FASTQ1=$OUTPUT_DIR/$sample\_R1.fastq.gz

echo single end kallisto bus
kallisto bus --num -o $OUTPUT_DIR -i  $KALLISTO_IDX $FASTQ1
echo $FASTQ1

# Bustools
echo bustools text
bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus

# Parse fastq read names
echo Parse fastq read names
cat $OUTPUT_DIR/$sample\_R1.fastq.gz | gunzip  | grep ^@R  | awk  '{gsub("\\|","\t",$0); print;}' |awk  '{gsub(":","\t",$0); print;}' | cut -f 1,2 > $OUTPUT_DIR/read_names.txt

# Count reads per-EC
echo Count reads per-EC
Rscript p_matrix_counts.R --rep=$rep --topdir=$OUTPUT_DIR

echo "ENDING: " $(date)
