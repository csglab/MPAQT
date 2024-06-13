#!/usr/bin/env bash

# This script automates the process of generating simulated single-end FASTQ files, mapping the reads to equivalence classes (ECs) using kallisto,
# and combining the read-EC mappings with the original transcript information. The final output is saved as an RDS file containing the counts of
# reads per EC for each transcript of origin.

# The script runs a specified number of replicates (default is 24) and performs the following steps for each replicate:
# 1. Generates a single-end simulated FASTQ file using a specified read simulator.
# 2. Uses kallisto to map the simulated reads to equivalence classes (ECs).
# 3. Converts the resulting bus file from kallisto into a more usable text format using bustools.
# 4. Extracts read names from the FASTQ files, which include the transcript of origin for each read.
# 5. Counts the reads per EC and combines this information with the transcript of origin to create a final data frame.
# 6. Saves the combined read-EC and transcript data frame as an RDS file (ec.txs.joined.counts.Rds).

# Usage:
#   script.sh [options]
#
# Options:
#   -r, --rep           Number of replicates (default: 24)
#   -t, --topdir        Top directory for output
#   -m, --mode          Mode (simulation mode)
#   -x, --ref_txome     Reference transcriptome file
#   -i, --KALLISTO_IDX  Kallisto index file
#   -s, --scripts       Directory containing the required scripts
#   -l, --lib_size      Library size for the simulated reads
#   -h, --help          Display this help message and exit

# Example:
#   ./script.sh --rep=10 --topdir=/path/to/output --mode=fast --ref_txome=/path/to/ref_txome.fa \
#               --KALLISTO_IDX=/path/to/kallisto_idx.idx --scripts=/path/to/scripts --lib_size=1000000

# Initialize variables with default values
rep=24
topdir=""
mode=""
ref_txome=""
KALLISTO_IDX=""
scripts=""
lib_size=""

# Function to display usage information
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -r, --rep           Number of replicates (default: 24)"
  echo "  -t, --topdir        Top directory"
  echo "  -m, --mode          Mode"
  echo "  -x, --ref_txome     Reference transcriptome"
  echo "  -i, --KALLISTO_IDX  Kallisto index"
  echo "  -s, --scripts       Scripts directory"
  echo "  -l, --lib_size      Library size"
  echo "  -p, --num_threads   Number of threads"
  echo "  -h, --help          Display this help message"
}

# Parse command line arguments using getopts
while getopts ":r:t:m:x:i:s:l:h-:" opt; do
  case ${opt} in
    r ) rep=$OPTARG ;;
    t ) topdir=$OPTARG ;;
    m ) mode=$OPTARG ;;
    x ) ref_txome=$OPTARG ;;
    i ) KALLISTO_IDX=$OPTARG ;;
    s ) scripts=$OPTARG ;;
    l ) lib_size=$OPTARG ;;
    p ) num_threads=$OPTARG ;;
    h ) usage; exit 0 ;;
    - )
      case "${OPTARG}" in
        rep=*) rep=${OPTARG#*=} ;;
        topdir=*) topdir=${OPTARG#*=} ;;
        mode=*) mode=${OPTARG#*=} ;;
        ref_txome=*) ref_txome=${OPTARG#*=} ;;
        KALLISTO_IDX=*) KALLISTO_IDX=${OPTARG#*=} ;;
        scripts=*) scripts=${OPTARG#*=} ;;
        lib_size=*) lib_size=${OPTARG#*=} ;;
        num_threads=*) num_threads=${OPTARG#*=} ;;
        help) usage; exit 0 ;;
        *) echo "Invalid option: --${OPTARG}" >&2; usage; exit 1 ;;
      esac ;;
    \? ) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    : ) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done
shift $((OPTIND -1))

# Check for required parameters
if [ -z "$topdir" ] || [ -z "$mode" ] || [ -z "$ref_txome" ] || [ -z "$KALLISTO_IDX" ] || [ -z "$scripts" ] || [ -z "$lib_size" ]; then
  echo "Error: Missing required parameters."
  usage
  exit 1
fi

# Arguments
OUTPUT_DIR=$topdir/p-matrix/replicates/rep$rep
mkdir -p ${OUTPUT_DIR}
sample=simulated_rep${rep}

# Generate simulated single-end FASTQ file
# echo "———————— Generating FASTQ file for replicate $rep in $mode mode"
# echo "Running simReads.R in $mode mode"
# echo "Output directory: $OUTPUT_DIR"
mkdir -p $OUTPUT_DIR
cd $OUTPUT_DIR
Rscript $scripts/R/simReads.R --topdir=$OUTPUT_DIR --sample=$sample --ref_txome=$ref_txome --mode=$mode --lib_size=$lib_size
# echo "FASTQ generation complete for replicate $rep"

# KALLISTO BUS
# Runs kallisto's pseudoalignment tool to map reads to equivalence classes. 
# Generates a bus file which contains the information specifying which 
# equivalence class each read corresponds to
# echo "———————— Running kallisto bus for replicate $rep"
FASTQ1=${OUTPUT_DIR}/${sample}_R1.fastq.gz
kallisto bus \
  --index $KALLISTO_IDX \
  --output-dir $OUTPUT_DIR \
  --technology bulk \
  --threads ${num_threads} \
  --num \
  ${FASTQ1} \
  > /dev/null 2>&1
# echo "Kallisto bus run complete for replicate $rep"
# echo "FASTQ file used: $FASTQ1"

# BUSTOOLS TEXT
# Converts the bus file into a text file which is more easily useable
# echo "———————— Converting bus file to text format for replicate $rep"
bustools text -f -o $OUTPUT_DIR/output.bus.txt $OUTPUT_DIR/output.bus  > /dev/null 2>&1
# echo "Bustools text conversion complete for replicate $rep"

# PARSE READ NAMES
# Extracts the read names from the FASTQ files. The read name contains the transcript
# of origin of the read.
# echo "———————— Parsing read names from FASTQ file for replicate $rep"
cat $FASTQ1 | gunzip | grep ^@R | awk '{gsub("\\|","\t",$0); print;}' | awk '{gsub(":","\t",$0); print;}' | cut -f 1,2 > $OUTPUT_DIR/read_names.txt
zcat $FASTQ1 | grep ^@R | cut -d':' -f 2 | sort | uniq > $OUTPUT_DIR/transcripts.txt
# echo "Read name parsing complete for replicate $rep"

# Count reads per-EC
# Combines the transcript of origin and the EC mapping of each read into one object 
# Generates file ec.txs.joined.counts.Rds, a data frame containing the equivalence class,
# transcript of origin, and number of reads in that EC originating from that transcript:
#                                   txs             tx_id n
# 1              0,171373,171374,171376 ENST00000562189.1 1
# 2                              100056 ENST00000220676.2 2
# echo "———————— Counting reads per EC and generating final RDS file for replicate $rep"
Rscript $scripts/R/p_matrix_counts.R --topdir=$OUTPUT_DIR
# echo "Read counting and RDS generation complete for replicate $rep"

# Clean up intermediate files
find "$OUTPUT_DIR" -type f ! -name "ec.txs.joined.counts.Rds" -exec rm -f {} +
 
# echo "———————— Generation completed successfully for replicate $rep at: $(date)"
