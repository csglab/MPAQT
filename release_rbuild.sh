#!/bin/bash

# =============================================================================
# MPAQT R Package Build Script
# Updates version references, builds R package, and generates documentation
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Initialize
init_log
read_version

print_header "MPAQT R Build v${VERSION}"

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

run_task_inline "Build pkgdown site" "Rscript -e 'pkgdown::build_site(preview = FALSE)'"

# =============================================================================
# Summary
# =============================================================================

print_summary

echo ""
echo "Next steps:"
echo "  Run release_docker.sh, release_apptainer.sh, release_conda.sh"
echo "  Or run release_all.sh for a complete release"
