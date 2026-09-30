#!/bin/bash

# =============================================================================
# MPAQT Complete Release Script
# Runs all release steps: R build, Docker, Apptainer, Conda
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Initialize - clear log for fresh start
> "$LOG_FILE"

# Set flag so sub-scripts append to log instead of clearing
export RELEASE_LOG_APPEND=1

# Read version and credentials
read_version
load_credentials

print_header "MPAQT Complete Release v${VERSION}"

# =============================================================================
# Step 1: R Package Build
# =============================================================================

echo "Step 1: R Package Build"
./release_rbuild.sh

# =============================================================================
# Step 2: Docker Images
# =============================================================================

echo ""
echo "Step 2: Docker Images"
./release_docker.sh

# =============================================================================
# Step 3: Apptainer Images
# =============================================================================

echo ""
echo "Step 3: Apptainer Images"
./release_apptainer.sh

# =============================================================================
# Step 4: Conda Packages
# =============================================================================

echo ""
echo "Step 4: Conda Packages"
./release_conda.sh

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
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit: git add -A && git commit -m 'Release v${VERSION}'"
echo "  3. Tag: git tag -a v${VERSION} -m 'Version ${VERSION}'"
echo "  4. Push: git push && git push --tags"
