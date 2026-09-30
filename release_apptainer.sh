#!/bin/bash

# =============================================================================
# MPAQT Apptainer Build Script
# Builds and pushes Apptainer images (stable, full, dev)
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Initialize
init_log
read_version
load_credentials

print_header "MPAQT Apptainer Build v${VERSION}"

echo "Building Apptainer images..."

run_task "Apptainer stable" ./inst/apptainer/build-and-push.sh -y
run_task "Apptainer full" ./inst/apptainer/build-and-push-full.sh -y
run_task "Apptainer dev" ./inst/apptainer/build-and-push-dev.sh -y

# =============================================================================
# Summary
# =============================================================================

print_summary
