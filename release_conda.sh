#!/bin/bash
set -euo pipefail

# =============================================================================
# MPAQT Conda Build Script
# Builds and uploads Conda packages (stable, full, dev)
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Modes: build locally by default; publishing is always explicit.
MODE="${1:---build-only}"
case "$MODE" in
    --build-only|--publish|--publish-only) ;;
    *)
        echo "Usage: $0 [--build-only|--publish|--publish-only]"
        exit 2
        ;;
esac

# Initialize
init_log
read_version
require_published_release_tag
if [[ "$MODE" != "--build-only" ]]; then
    load_credentials
fi

print_header "MPAQT Conda Build v${VERSION}"

run_conda_task() {
    local name="$1"
    local script="$2"
    local mode="$3"

    run_task "$name" "$script" "$mode" ||
        { print_summary || true; exit 1; }
}

if [[ "$MODE" != "--publish-only" ]]; then
    echo "Building and testing Conda packages..."
    run_conda_task "Conda stable build" ./inst/conda-recipe/build-and-upload.sh --build-only
    run_conda_task "Conda full build" ./inst/conda-recipe/build-and-upload-full.sh --build-only
    run_conda_task "Conda dev build" ./inst/conda-recipe/build-and-upload-dev.sh --build-only
fi

if [[ "$MODE" != "--build-only" ]]; then
    echo "Publishing previously validated Conda packages..."
    run_conda_task "Conda stable publish" ./inst/conda-recipe/build-and-upload.sh --publish-only
    run_conda_task "Conda full publish" ./inst/conda-recipe/build-and-upload-full.sh --publish-only
    run_conda_task "Conda dev publish" ./inst/conda-recipe/build-and-upload-dev.sh --publish-only
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
