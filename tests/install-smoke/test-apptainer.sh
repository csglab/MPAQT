#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

IMAGE_URI="library://csglab/mpaqt/mpaqt:2.4.0"

require_command apptainer
require_command rg

case_dir="$(reset_case_dir apptainer)"
image_path="$case_dir/mpaqt_2.4.0.sif"
exec > >(tee "$case_dir/test.log") 2>&1

log "Pulling published Apptainer image: $IMAGE_URI"
apptainer pull --disable-cache "$image_path" "$IMAGE_URI"

apptainer inspect "$image_path" | tee "$case_dir/apptainer-inspect.txt"
rg -q 'Version:[[:space:]]+2\.4\.0|Version[[:space:]]*=[[:space:]]*2\.4\.0' \
    "$case_dir/apptainer-inspect.txt" ||
    fail "Apptainer image does not report version 2.4.0"
rg -qi 'Variant:[[:space:]]+stable|Variant[[:space:]]*=[[:space:]]*stable' \
    "$case_dir/apptainer-inspect.txt" ||
    fail "Apptainer image does not report the stable variant"

create_toy_reference "$case_dir"

apptainer exec --contain --cleanenv \
    --bind "$case_dir:/work" \
    --bind "$SCRIPT_DIR:/smoke:ro" \
    "$image_path" \
    Rscript /smoke/run-index-smoke.R \
    /work/toy.gtf \
    /work/toy.fa \
    /work/index-output \
    "apptainer:$IMAGE_URI"

[[ -s "$case_dir/index-output/PASS.txt" ]] ||
    fail "Apptainer index smoke test did not create PASS.txt"

log "PASS: Apptainer installation and mpaqt_index()"
