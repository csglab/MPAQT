#!/bin/bash
set -euo pipefail

# =============================================================================
# MPAQT Docker Build Script
# Builds and pushes Docker images (stable, full, dev)
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

print_header "MPAQT Docker Build v${VERSION}"

run_docker_task() {
    local name="$1"
    local script="$2"
    local mode="$3"

    run_task "$name" "$script" "$mode" ||
        { print_summary || true; exit 1; }
}

if [[ "$MODE" != "--publish-only" ]]; then
    echo "Building and testing Docker images..."
    run_docker_task "Docker stable build" ./inst/docker/build-and-push.sh --build-only
    run_docker_task "Docker full build" ./inst/docker/build-and-push-full.sh --build-only
    run_docker_task "Docker dev build" ./inst/docker/build-and-push-dev.sh --build-only
fi

if [[ "$MODE" != "--build-only" ]]; then
    echo "Publishing previously validated Docker images..."
    run_docker_task "Docker stable publish" ./inst/docker/build-and-push.sh --publish-only
    run_docker_task "Docker full publish" ./inst/docker/build-and-push-full.sh --publish-only
    run_docker_task "Docker dev publish" ./inst/docker/build-and-push-dev.sh --publish-only
fi

# =============================================================================
# Summary
# =============================================================================

print_summary
