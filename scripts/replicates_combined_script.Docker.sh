#!/bin/bash

# This script is run n times, where n is a number of replicates decided upon. We chose n=24
# This script generates a single-end simulated FASTQ, generated using the <> read simulator
# and the reads contain the transcripts of origin.
# Then, kallisto is used to map reads to ECs
# Finally, read-EC mappings and read-tx_of_origin mappings are combined into a single object,
# and written to disk as file ec.txs.joined.counts.Rds 
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
        --scripts=*)
        scripts="${1#*=}"
        shift
        ;;
        --lib_size=*)
        lib_size="${1#*=}"
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
echo lib_size: $lib_size
echo
echo "STARTING: " $(date)
echo

# Arguments
OUTPUT_DIR=$topdir/rep$rep
sample=SIM.$rep

# Generate simulated single-end FASTQ file
echo Generating fastq number $rep
echo Running simReads.R in $mode mode
echo $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
cd $OUTPUT_DIR
Rscript $scripts/simReads.R --rep=$rep --topdir=$OUTPUT_DIR --sample=$sample --ref_txome=$ref_txome --mode=$mode --lib_size=$lib_size

# KALLISTO BUS
# Runs kallisto's pseudoalignment tool to map reads to equivalence classes. 
# Generates a bus file which contains the information specifying which 
# equivalence class each read corresponds to
echo Run kallisto bus $rep
FASTQ1=$OUTPUT_DIR/$sample\_R1.fastq.gz
echo single end kallisto bus
kallisto bus --num -o $OUTPUT_DIR -i  $KALLISTO_IDX $FASTQ1
echo $FASTQ1

# BUSTOOLS TEXT
# Converts the bus file into a text file which is more easily useable
echo bustools text
bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus

# PARSE READ NAMES
# extracts the read names from the FASTQ files. The read name contains the transcript
# of origin of the read.
echo Parse fastq read names
cat $OUTPUT_DIR/$sample\_R1.fastq.gz | gunzip  | grep ^@R  | awk  '{gsub("\\|","\t",$0); print;}' |awk  '{gsub(":","\t",$0); print;}' | cut -f 1,2 > $OUTPUT_DIR/read_names.txt

# Count reads per-EC
# Combines the transcript of origin and the EC mapping of each read into one object 
# Generates file ec.txs.joined.counts.Rds, a data frame containing the equivalence class,
# transcript of origin, and number of reads in that EC origination from that transcript:
#                                   txs             tx_id n
# 1              0,171373,171374,171376 ENST00000562189.1 1
# 2                              100056 ENST00000220676.2 2
echo Count reads per-EC
echo Rscript p_matrix_counts.R --rep=$rep --topdir=$OUTPUT_DIR
Rscript $scripts/p_matrix_counts.R --rep=$rep --topdir=$OUTPUT_DIR

echo "ENDING: " $(date)
