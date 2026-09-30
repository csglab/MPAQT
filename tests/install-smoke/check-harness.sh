#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

required_files=(
    create-toy-reference.sh
    run-index-smoke.R
    common.sh
    test-conda.sh
    test-apptainer.sh
    test-pak.sh
    run-all.sh
)

for file in "${required_files[@]}"; do
    [[ -f "$SCRIPT_DIR/$file" ]] || fail "missing $file"
done

for script in "$SCRIPT_DIR"/*.sh; do
    bash -n "$script"
done

Rscript -e 'parse(file = commandArgs(trailingOnly = TRUE)[[1]])' \
    "$SCRIPT_DIR/run-index-smoke.R" >/dev/null

rg -q 'r-mpaqt=2\.4\.0=r43_1' "$SCRIPT_DIR/test-conda.sh" ||
    fail "Conda test is not pinned to corrected build r43_1"
rg -q -- '-c defaults' "$SCRIPT_DIR/test-conda.sh" ||
    fail "Conda package test does not explicitly enable defaults for r-gpboost"
rg -q -- '-c defaults' "$SCRIPT_DIR/test-pak.sh" ||
    fail "pak dependency environment does not explicitly enable defaults for r-gpboost"
rg -q 'library://csglab/mpaqt/mpaqt:2\.4\.0' "$SCRIPT_DIR/test-apptainer.sh" ||
    fail "Apptainer test is not pinned to the stable v2.4.0 image"
rg -Fq 'pak::pak("csglab/MPAQT_merged")' "$SCRIPT_DIR/test-pak.sh" ||
    fail "pak test does not use the required installation command"
rg -q 'mpaqt_index\(' "$SCRIPT_DIR/run-index-smoke.R" ||
    fail "shared smoke test does not call mpaqt_index()"
rg -q 'packageVersion\("mpaqt"\).*2\.4\.0|2\.4\.0.*packageVersion\("mpaqt"\)' \
    "$SCRIPT_DIR/run-index-smoke.R" ||
    fail "shared smoke test does not verify MPAQT 2.4.0"

echo "Installation smoke harness checks passed."
