#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENV_NAME="mpaqt2"
PACKAGE_SPEC="r-mpaqt=2.4.0=r43_1"

require_command conda
require_command rg

case_dir="$(reset_case_dir conda)"
exec > >(tee "$case_dir/test.log") 2>&1

log "Testing corrected Conda package: $PACKAGE_SPEC"
prepare_conda_env_name "$ENV_NAME"

conda create -n "$ENV_NAME" -y \
    --override-channels \
    -c csglab \
    -c conda-forge \
    -c bioconda \
    -c defaults \
    "$PACKAGE_SPEC"

conda list -n "$ENV_NAME" --show-channel-urls |
    tee "$case_dir/conda-list.txt"

rg -q '^r-mpaqt[[:space:]]+2\.4\.0[[:space:]]+r43_1[[:space:]]+csglab' \
    "$case_dir/conda-list.txt" ||
    fail "installed r-mpaqt is not csglab build 2.4.0 r43_1"

create_toy_reference "$case_dir"

conda run --no-capture-output -n "$ENV_NAME" \
    Rscript "$SCRIPT_DIR/run-index-smoke.R" \
    "$case_dir/toy.gtf" \
    "$case_dir/toy.fa" \
    "$case_dir/index-output" \
    "conda:$PACKAGE_SPEC"

[[ -s "$case_dir/index-output/PASS.txt" ]] ||
    fail "Conda index smoke test did not create PASS.txt"

log "PASS: Conda installation and mpaqt_index()"
