#!/bin/bash

# =============================================================================
# MPAQT Release Script
# Reads version from VERSION file and updates all references, then builds
# Auto-yes mode: runs all tasks, logs to release.log, prints summary
# =============================================================================

cd "$(dirname "$0")"

# Configuration
CREDS_FILE="release-credentials.yml"
LOG_FILE="release.log"
> "$LOG_FILE"  # Clear log file

# Task tracking
declare -a TASK_NAMES
declare -a TASK_STATUS

# Colors for summary
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo "$@" >> "$LOG_FILE"
}

log_header() {
    echo "" >> "$LOG_FILE"
    echo "==============================================================================" >> "$LOG_FILE"
    echo "$@" >> "$LOG_FILE"
    echo "==============================================================================" >> "$LOG_FILE"
}

run_task() {
    local name="$1"
    shift
    TASK_NAMES+=("$name")

    echo -n "  Running: $name..."
    log_header "$name"

    if "$@" >> "$LOG_FILE" 2>&1; then
        TASK_STATUS+=("OK")
        echo " done"
    else
        TASK_STATUS+=("FAILED")
        echo " FAILED"
    fi
}

run_task_inline() {
    # For inline commands that need shell evaluation
    local name="$1"
    local cmd="$2"
    TASK_NAMES+=("$name")

    echo -n "  Running: $name..."
    log_header "$name"

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        TASK_STATUS+=("OK")
        echo " done"
    else
        TASK_STATUS+=("FAILED")
        echo " FAILED"
    fi
}

print_summary() {
    echo ""
    echo "==========================================="
    echo "           RELEASE SUMMARY"
    echo "==========================================="

    local success=0
    local failed=0

    for i in "${!TASK_NAMES[@]}"; do
        if [[ "${TASK_STATUS[$i]}" == "OK" ]]; then
            echo -e "  ${GREEN}✓${NC} ${TASK_NAMES[$i]}"
            ((success++))
        else
            echo -e "  ${RED}✗${NC} ${TASK_NAMES[$i]}"
            ((failed++))
        fi
    done

    echo ""
    echo "==========================================="
    echo "  Total: $((success + failed)) | Success: $success | Failed: $failed"
    echo "==========================================="
    echo ""
    echo "Full log: $LOG_FILE"

    if [[ $failed -gt 0 ]]; then
        echo ""
        echo "Check log for details: tail -100 $LOG_FILE"
    fi
}

# =============================================================================
# Check credentials file
# =============================================================================

if [[ ! -f "$CREDS_FILE" ]]; then
    echo "ERROR: $CREDS_FILE not found"
    echo ""
    echo "To set up credentials:"
    echo "  1. cp release-credentials.yml.template release-credentials.yml"
    echo "  2. Edit release-credentials.yml with your tokens"
    echo ""
    exit 1
fi

# Parse credentials from YAML (simple grep-based parsing)
export DOCKER_USER=$(grep -A3 "^docker:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
export DOCKER_PASSWORD=$(grep -A3 "^docker:" "$CREDS_FILE" | grep "password:" | sed 's/.*password: *//' | tr -d '"' | tr -d "'")
export SYLABS_USER=$(grep -A3 "^sylabs:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
export SYLABS_TOKEN=$(grep -A3 "^sylabs:" "$CREDS_FILE" | grep "token:" | sed 's/.*token: *//' | tr -d '"' | tr -d "'")
export CONDA_USER=$(grep -A3 "^conda:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
export CONDA_TOKEN=$(grep -A3 "^conda:" "$CREDS_FILE" | grep "token:" | sed 's/.*token: *//' | tr -d '"' | tr -d "'")
export GITHUB_USER=$(grep -A3 "^github:" "$CREDS_FILE" | grep "username:" | sed 's/.*username: *//' | tr -d '"' | tr -d "'")
export GITHUB_TOKEN=$(grep -A3 "^github:" "$CREDS_FILE" | grep "token:" | sed 's/.*token: *//' | tr -d '"' | tr -d "'")

# =============================================================================
# Read version
# =============================================================================

VERSION=$(cat VERSION | tr -d '[:space:]')

echo "==========================================="
echo "       MPAQT Release v${VERSION}"
echo "==========================================="
echo ""
echo "Log file: $LOG_FILE"
echo ""

# =============================================================================
# Step 1: Update version in all files
# =============================================================================

echo "Step 1: Updating version references..."

update_versions() {
    # Update DESCRIPTION
    sed -i "s/^Version: .*/Version: ${VERSION}/" DESCRIPTION
    echo "  Updated DESCRIPTION"

    # Update Dockerfiles
    for df in inst/docker/Dockerfile inst/docker/Dockerfile.full inst/docker/Dockerfile.dev; do
        if [ -f "$df" ]; then
            sed -i "s/LABEL version=\".*\"/LABEL version=\"${VERSION}\"/" "$df"
            echo "  Updated $df"
        fi
    done

    # Update Apptainer definitions
    for def in inst/apptainer/mpaqt.def inst/apptainer/mpaqt-full.def inst/apptainer/mpaqt-dev.def; do
        if [ -f "$def" ]; then
            sed -i "s/^\s*Version .*/    Version ${VERSION}/" "$def"
            echo "  Updated $def"
        fi
    done

    # Update conda recipes
    for meta in inst/conda-recipe/meta.yaml inst/conda-recipe/meta-full.yaml inst/conda-recipe/meta-dev.yaml; do
        if [ -f "$meta" ]; then
            sed -i "s/version: \".*\"/version: \"${VERSION}\"/" "$meta"
            echo "  Updated $meta"
        fi
    done
}

run_task "Update version references" update_versions

# =============================================================================
# Step 2: R package documentation and checks
# =============================================================================

echo ""
echo "Step 2: Building R package..."

run_task_inline "R documentation" "Rscript -e 'devtools::document()'"
run_task_inline "R check" "Rscript -e 'devtools::check()'"
run_task_inline "R build" "Rscript -e 'devtools::build()'"

# Copy tarball to releases directory
copy_tarball() {
    mkdir -p releases
    TARBALL="../mpaqt_${VERSION}.tar.gz"
    if [ -f "$TARBALL" ]; then
        cp "$TARBALL" releases/
        echo "Tarball copied to releases/mpaqt_${VERSION}.tar.gz"
    else
        echo "WARNING: Tarball not found at $TARBALL"
        return 1
    fi
}

run_task "Copy tarball to releases" copy_tarball

run_task_inline "R install" "Rscript -e 'devtools::install()'"

# =============================================================================
# Step 3: Build documentation website
# =============================================================================

echo ""
echo "Step 3: Building pkgdown site..."

# Workaround for xml2/libxml2 segfault when adding logo
# Move logo temporarily, build site, then restore and copy logo
build_pkgdown_with_logo_workaround() {
    local logo_src="man/figures/logo.png"
    local logo_bak="man/figures/logo.png.bak"

    # Move logo out of the way
    if [ -f "$logo_src" ]; then
        mv "$logo_src" "$logo_bak"
    fi

    # Build pkgdown site (preview=FALSE to avoid browser error)
    Rscript -e 'pkgdown::build_site(preview = FALSE)'
    local build_status=$?

    # Restore logo and copy to docs
    if [ -f "$logo_bak" ]; then
        mv "$logo_bak" "$logo_src"
        cp "$logo_src" docs/logo.png
        mkdir -p docs/reference/figures
        cp "$logo_src" docs/reference/figures/logo.png
    fi

    return $build_status
}

run_task "Build pkgdown site" build_pkgdown_with_logo_workaround

# =============================================================================
# Step 4: Build and push Docker images
# =============================================================================

echo ""
echo "Step 4: Building Docker images..."

run_task "Docker stable" ./inst/docker/build-and-push.sh -y
run_task "Docker full" ./inst/docker/build-and-push-full.sh -y
run_task "Docker dev" ./inst/docker/build-and-push-dev.sh -y

# =============================================================================
# Step 5: Build and push Apptainer images
# =============================================================================

echo ""
echo "Step 5: Building Apptainer images..."

run_task "Apptainer stable" ./inst/apptainer/build-and-push.sh -y
run_task "Apptainer full" ./inst/apptainer/build-and-push-full.sh -y
run_task "Apptainer dev" ./inst/apptainer/build-and-push-dev.sh -y

# =============================================================================
# Step 6: Build and upload Conda packages
# =============================================================================

echo ""
echo "Step 6: Building Conda packages..."

run_task "Conda stable" ./inst/conda-recipe/build-and-upload.sh -y
run_task "Conda full" ./inst/conda-recipe/build-and-upload-full.sh -y
run_task "Conda dev" ./inst/conda-recipe/build-and-upload-dev.sh -y

# =============================================================================
# Summary
# =============================================================================

print_summary

echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Commit: git add -A && git commit -m 'Release v${VERSION}'"
echo "  3. Tag: git tag -a v${VERSION} -m 'Version ${VERSION}'"
echo "  4. Push: git push && git push --tags"
