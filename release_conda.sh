#!/bin/bash

# =============================================================================
# MPAQT Conda Build Script
# Builds and uploads Conda packages (stable, full, dev)
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Initialize
init_log
read_version
load_credentials

print_header "MPAQT Conda Build v${VERSION}"

echo "Building Conda packages..."

run_task "Conda stable" ./inst/conda-recipe/build-and-upload.sh -y
run_task "Conda full" ./inst/conda-recipe/build-and-upload-full.sh -y
run_task "Conda dev" ./inst/conda-recipe/build-and-upload-dev.sh -y

# =============================================================================
# Summary
# =============================================================================

print_summary
