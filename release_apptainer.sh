#!/bin/bash
set -euo pipefail

# =============================================================================
# MPAQT Apptainer Build Script
# Builds and pushes Apptainer images (stable, full, dev)
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
if [[ "$MODE" != "--build-only" ]]; then
    require_published_release_tag
    load_credentials
fi

print_header "MPAQT Apptainer Build v${VERSION}"

run_apptainer_task() {
    local name="$1"
    local script="$2"
    local mode="$3"

    run_task "$name" "$script" "$mode" ||
        { print_summary || true; exit 1; }
}

if [[ "$MODE" != "--publish-only" ]]; then
    echo "Building and testing Apptainer images..."
    run_apptainer_task "Apptainer stable build" ./inst/apptainer/build-and-push.sh --build-only
    run_apptainer_task "Apptainer full build" ./inst/apptainer/build-and-push-full.sh --build-only
    run_apptainer_task "Apptainer dev build" ./inst/apptainer/build-and-push-dev.sh --build-only
fi

if [[ "$MODE" != "--build-only" ]]; then
    echo "Publishing previously validated Apptainer images..."
    run_apptainer_task "Apptainer stable publish" ./inst/apptainer/build-and-push.sh --publish-only
    run_apptainer_task "Apptainer full publish" ./inst/apptainer/build-and-push-full.sh --publish-only
    run_apptainer_task "Apptainer dev publish" ./inst/apptainer/build-and-push-dev.sh --publish-only
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
