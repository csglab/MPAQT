#!/usr/bin/env bash

#!/bin/bash

# This script combines the replicate simulations, generates sparse matrix P,
# then converts P into formats more easily usable as inputs to MPAQT.

# Usage:
#   script.sh [options]
#
# Options:
#   -n, --reps          Number of replicates
#   -t, --topdir        Top directory for output
#   -s, --scripts       Directory containing the required scripts
#   -h, --help          Display this help message and exit

# Example:
#   ./script.sh --reps=24 --topdir=/path/to/output --scripts=/path/to/scripts

# Initialize variables with default values
reps=24
topdir=""
scripts=""

# Function to display usage information
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -n, --reps          Number of replicates (default: 24)"
  echo "  -t, --topdir        Top directory"
  echo "  -s, --scripts       Scripts directory"
  echo "  -h, --help          Display this help message"
}

# Parse command line arguments using getopts
while getopts ":n:t:s:h-:" opt; do
  case ${opt} in
    n ) reps=$OPTARG ;;
    t ) topdir=$OPTARG ;;
    s ) scripts=$OPTARG ;;
    h ) usage; exit 0 ;;
    - )
      case "${OPTARG}" in
        reps=*) reps=${OPTARG#*=} ;;
        topdir=*) topdir=${OPTARG#*=} ;;
        scripts=*) scripts=${OPTARG#*=} ;;
        help) usage; exit 0 ;;
        *) echo "Invalid option: --${OPTARG}" >&2; usage; exit 1 ;;
      esac ;;
    \? ) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    : ) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done
shift $((OPTIND -1))

# Check for required parameters
if [ -z "$topdir" ] || [ -z "$scripts" ]; then
  echo "Error: Missing required parameters."
  usage
  exit 1
fi

# COMBINE REPLICATES
# Combines the specified number of replicates into a single object
echo "==== Step 1: Combining replicate counts"
# echo "Top directory: $topdir"
# echo "Number of replicates: $reps"
# echo "Scripts directory: $scripts"
Rscript $scripts/R/combine_replicate_counts.R --topdir=$topdir --reps=$reps
echo "Combining replicates complete"

# GENERATE P
# Generates matrix P as a sparse matrix
# Outputs file p_matrix.Rds
echo "==== Step 2: Generating P matrix"
Rscript $scripts/R/generate_p_matrix.R --topdir=$topdir --reps=$reps
echo "P matrix generation complete"

# Generates files p_rowSums.Rds and p_list.Rds, which are used as input to MPAQT
echo "==== Step 3: Converting P matrix to list"
Rscript $scripts/R/01.convert_to_list.R --topdir=$topdir
echo "P matrix conversion complete"