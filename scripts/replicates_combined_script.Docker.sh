#!/bin/bash

# Loop through arguments and process them
#--topdir=$topdir --mode=$mode --ref_txome=$ref_txome --KALLISTO_IDX=$KALLISTO_IDX
echo reading in args
while test $# -gt 0;do
    case $1 in
        --rep=*)
        rep="${1#*=}"
        shift
        ;;
        --topdir)
        topdir="$2"
        shift 2
        ;;
        --mode)
        mode="$2"
        shift 2
        ;;
        --ref_txome)
        ref_txome="$2"
        shift 2
        ;;
        --KALLISTO_IDX)
        KALLISTO_IDX="$2"
        shift 2
        ;;
        *)
        #OTHER_ARGUMENTS+=("$1")
        shift # Remove generic argument from processing
        ;;
    esac
done

echo test $rep $topdir $mode $ref_txome $KALLISTO_IDX $rep
echo "STARTING: " $(date)
exit 0

# Arguments
OUTPUT_DIR=$topdir/rep$rep
sample=SIM.$rep

# Generate fastqs
echo Generating fastq number $rep
echo Running simReads.R in $mode mode
echo $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
$env/Rscript simReads.R --rep=$rep --topdir=$OUTPUT_DIR --sample=$sample --ref_txome=$ref_txome --mode=$mode

# Run kallisto bus
echo Run kallisto bus $rep
#KALLISTO_IDX=/project/6007998/maposto/reference/kallisto/gencode.v38.transcripts.fa.idx
FASTQ1=$OUTPUT_DIR/$sample\_R1.fastq.gz
FASTQ2=$OUTPUT_DIR/$sample\_R2.fastq.gz

if [ $mode == "single" ];then 
  echo single
  $bin/kallisto bus --num -o $OUTPUT_DIR -i  $KALLISTO_IDX $FASTQ1
  echo $FASTQ1
elif [ $mode == "paired" ];then 
  echo paired
  $bin/kallisto bus --num --paired -o $OUTPUT_DIR -i  $KALLISTO_IDX $FASTQ1 $FASTQ2
  echo $FASTQ1 $FASTQ2
fi

# Bustools
module load bustools
bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus

# Parse fastq read names
echo Parse fastq read names 
cat $OUTPUT_DIR/$sample\_R1.fastq.gz | gunzip  | grep ^@R  | awk  '{gsub("\\|","\t",$0); print;}' |awk  '{gsub(":","\t",$0); print;}' | cut -f 1,2 > $OUTPUT_DIR/read_names.txt

# Count reads per-EC
$env/Rscript p_matrix_counts.R --rep=$rep --topdir=$OUTPUT_DIR


echo "ENDING: " $(date)
