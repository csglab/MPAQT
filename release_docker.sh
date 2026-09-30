#!/bin/bash

# =============================================================================
# MPAQT Docker Build Script
# Builds and pushes Docker images (stable, full, dev)
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Initialize
init_log
read_version
load_credentials

print_header "MPAQT Docker Build v${VERSION}"

echo "Building Docker images..."

run_task "Docker stable" ./inst/docker/build-and-push.sh -y
run_task "Docker full" ./inst/docker/build-and-push-full.sh -y
run_task "Docker dev" ./inst/docker/build-and-push-dev.sh -y

# =============================================================================
# Summary
# =============================================================================

print_summary
