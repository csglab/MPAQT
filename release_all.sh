#!/bin/bash
set -euo pipefail

# =============================================================================
# MPAQT Complete Release Script
# Runs all release steps: R build, Docker, Apptainer, Conda
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Modes: build/test everything by default; publishing is always explicit.
MODE="${1:---build-only}"
case "$MODE" in
    --build-only|--publish|--publish-only) ;;
    *)
        echo "Usage: $0 [--build-only|--publish|--publish-only]"
        exit 2
        ;;
esac

# Initialize - clear log for fresh start
> "$LOG_FILE"

# Set flag so sub-scripts append to log instead of clearing
export RELEASE_LOG_APPEND=1

# Read version. Credentials are loaded only by explicit publish phases.
read_version
require_published_release_tag

print_header "MPAQT Complete Release v${VERSION}"

if [[ "$MODE" != "--publish-only" ]]; then
    echo "Step 1: R Package Build"
    ./release_rbuild.sh

    echo ""
    echo "Step 2: Docker Images"
    ./release_docker.sh --build-only

    echo ""
    echo "Step 3: Apptainer Images"
    ./release_apptainer.sh --build-only

    echo ""
    echo "Step 4: Conda Packages"
    ./release_conda.sh --build-only
fi

if [[ "$MODE" != "--build-only" ]]; then
    echo ""
    echo "Publishing all previously validated artifacts..."
    ./release_docker.sh --publish-only
    ./release_apptainer.sh --publish-only
    ./release_conda.sh --publish-only
fi

# =============================================================================
# Final Summary
# =============================================================================

echo ""
echo "==========================================="
echo "       COMPLETE RELEASE SUMMARY"
echo "==========================================="
echo ""
echo "Full log: $LOG_FILE"
echo ""
if [[ "$MODE" == "--build-only" ]]; then
    echo "All local builds completed. Review their evidence before publishing:"
    echo "  ./release_all.sh --publish-only"
else
    echo "Requested release operation completed."
fi
