#!/bin/bash
#
#SBATCH --time=0:04:00
#SBATCH --partition=cpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=ali.saberi@arcinstitute.org

source /opt/conda/etc/profile.d/conda.sh
conda activate mpaqt

# Set MPAQT environment variables
MPAQT_DIR='/home/saberi/projects/mpaqt/rebuttal/MPAQT'
export MPAQT_DIR=$PWD
export PATH=$MPAQT_DIR:$PATH

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ref_txome_fa)
            ref_txome_fa="$2"
            shift 2
            ;;
        --ref_annot_gtf)
            ref_annot_gtf="$2"
            shift 2
            ;;
        --mpaqt_index)
            mpaqt_index="$2"
            shift 2
            ;;
        --num_threads)
            num_threads="$2"
            shift 2
            ;;
        --tmp-dir)
            tmp_dir="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Set default values if not provided
num_threads=${num_threads:-32}
tmp_dir=${tmp_dir:-"/large_storage/goodarzilab/saberi/mpaqt/tmp"}

# Set TMPDIR environment variable
export TMPDIR="${tmp_dir}"

# Validate required inputs
if [ -z "${ref_txome_fa}" ] || [ -z "${ref_annot_gtf}" ] || [ -z "${mpaqt_index}" ]; then
    echo "Error: Required parameters missing"
    echo "Usage: sbatch run_mpaqt.sh --ref_txome_fa <file> --ref_annot_gtf <file> --mpaqt_index <output> [--num_threads <int>] [--tmp-dir <dir>]"
    exit 1
fi

# Enable strict error checking
set -eo pipefail

# Run MPAQT indexing
mpaqt index \
    --ref_txome ${ref_txome_fa} \
    --ref_annot ${ref_annot_gtf} \
    --output ${mpaqt_index} \
    --num_threads ${num_threads} \
    --tmp_dir ${tmp_dir} \
    > stdout.log 2> stderr.log
