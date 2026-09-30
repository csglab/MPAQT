#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENV_NAME="mpaqt2-local"

require_command conda
require_command rg

case_dir="$(reset_case_dir pak)"
exec > >(tee "$case_dir/test.log") 2>&1

log "Creating local-install environment: $ENV_NAME"
prepare_conda_env_name "$ENV_NAME"

conda create -n "$ENV_NAME" -y \
    --override-channels \
    -c csglab \
    -c conda-forge \
    -c bioconda \
    -c defaults \
    r-base=4.3 \
    r-pak \
    r-data.table \
    r-matrix \
    r-lme4 \
    r-gpboost \
    r-cli \
    r-rlang \
    r-stringr \
    r-purrr \
    bioconductor-biostrings \
    bioconductor-rtracklayer \
    kallisto \
    bustools \
    git

log "Installing MPAQT from GitHub with pak"
conda run --no-capture-output -n "$ENV_NAME" \
    Rscript -e 'pak::pak("csglab/MPAQT")'

conda run --no-capture-output -n "$ENV_NAME" Rscript -e '
    description <- utils::packageDescription("mpaqt")
    stopifnot(as.character(utils::packageVersion("mpaqt")) == "2.4.0")
    stopifnot(identical(description[["RemoteUsername"]], "csglab"))
    stopifnot(identical(description[["RemoteRepo"]], "MPAQT"))
    stopifnot(nzchar(description[["RemoteSha"]]))
    cat("Installed GitHub commit:", description[["RemoteSha"]], "\n")
'

create_toy_reference "$case_dir"

conda run --no-capture-output -n "$ENV_NAME" \
    Rscript "$SCRIPT_DIR/run-index-smoke.R" \
    "$case_dir/toy.gtf" \
    "$case_dir/toy.fa" \
    "$case_dir/index-output" \
    "pak:csglab/MPAQT"

[[ -s "$case_dir/index-output/PASS.txt" ]] ||
    fail "pak index smoke test did not create PASS.txt"

log "PASS: pak installation and mpaqt_index()"
