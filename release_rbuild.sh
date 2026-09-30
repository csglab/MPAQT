#!/bin/bash
set -euo pipefail

# =============================================================================
# MPAQT R Package Build Script
# Verifies version references, builds R package, and generates documentation
# =============================================================================

cd "$(dirname "$0")"
source ./release_common.sh

# Initialize
init_log
read_version
STARTED_WITH_CLEAN_TREE=0
if [[ -z "$(git status --porcelain)" ]]; then
    STARTED_WITH_CLEAN_TREE=1
fi
R_SOURCE_CHECKSUM_BEFORE=$(
    find R -type f -print0 |
        sort -z |
        xargs -0 sha256sum |
        sha256sum |
        awk '{ print $1 }'
)

print_header "MPAQT R Build v${VERSION}"

# =============================================================================
# Step 1: Verify version in all files
# =============================================================================

echo "Step 1: Verifying version references..."

verify_versions() {
    grep -q "^Version: ${VERSION}$" DESCRIPTION ||
        { echo "ERROR: DESCRIPTION version does not match VERSION"; return 1; }

    for df in inst/docker/Dockerfile inst/docker/Dockerfile.full inst/docker/Dockerfile.dev; do
        grep -q "^LABEL version=\"${VERSION}\"$" "$df" ||
            { echo "ERROR: $df version does not match VERSION"; return 1; }
    done

    for def in inst/apptainer/mpaqt.def inst/apptainer/mpaqt-full.def inst/apptainer/mpaqt-dev.def; do
        grep -q "^[[:space:]]*Version ${VERSION}$" "$def" ||
            { echo "ERROR: $def version does not match VERSION"; return 1; }
        grep -q "packageVersion(\"mpaqt\")) == \"${VERSION}\"" "$def" ||
            { echo "ERROR: $def version test does not match VERSION"; return 1; }
    done

    for meta in inst/conda-recipe/meta.yaml inst/conda-recipe/meta-full.yaml inst/conda-recipe/meta-dev.yaml; do
        grep -q "^  version: \"${VERSION}\"$" "$meta" ||
            { echo "ERROR: $meta version does not match VERSION"; return 1; }
        grep -q "^  git_rev: v${VERSION}$" "$meta" ||
            { echo "ERROR: $meta release tag does not match VERSION"; return 1; }
        grep -q "packageVersion('mpaqt')) == '${VERSION}'" "$meta" ||
            { echo "ERROR: $meta version test does not match VERSION"; return 1; }
    done

    echo "All release version references match ${VERSION}"
}

run_task "Verify version references" verify_versions ||
    { print_summary || true; exit 1; }

# =============================================================================
# Step 2: R package documentation and checks
# =============================================================================

echo ""
echo "Step 2: Building R package..."

run_task_inline "R documentation" "Rscript -e 'devtools::document()'" ||
    { print_summary || true; exit 1; }
run_task_inline "R check" "Rscript -e 'devtools::check(error_on = \"warning\")'" ||
    { print_summary || true; exit 1; }
run_task_inline "R build" "Rscript -e 'devtools::build()'" ||
    { print_summary || true; exit 1; }

verify_r_source_unchanged() {
    local checksum_after
    checksum_after=$(
        find R -type f -print0 |
            sort -z |
            xargs -0 sha256sum |
            sha256sum |
            awk '{ print $1 }'
    )

    if [[ "$checksum_after" != "$R_SOURCE_CHECKSUM_BEFORE" ]]; then
        echo "ERROR: R source files changed during the release build"
        return 1
    fi

    echo "R source checksum unchanged: ${checksum_after}"
}

run_task "Verify R source unchanged" verify_r_source_unchanged ||
    { print_summary || true; exit 1; }

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

run_task "Copy tarball to releases" copy_tarball ||
    { print_summary || true; exit 1; }

verify_tarball() {
    local tarball="releases/mpaqt_${VERSION}.tar.gz"
    local max_size=$((10 * 1024 * 1024))
    local contents
    local size

    [[ -f "$tarball" ]] || {
        echo "ERROR: Missing $tarball"
        return 1
    }

    contents=$(tar -tzf "$tarball") || {
        echo "ERROR: Unable to list $tarball"
        return 1
    }

    if grep -Eq \
        '^mpaqt/(debug|build|\.agents|\.codex)(/|$)|^mpaqt/(AGENTS\.md|\.lintr\.R)$' \
        <<< "$contents"; then
        echo "ERROR: Release tarball contains excluded development files"
        return 1
    fi

    if ! grep -qx 'mpaqt/inst/bin/mpaqt' <<< "$contents"; then
        echo "ERROR: Release tarball does not preserve inst/bin/mpaqt"
        return 1
    fi

    size=$(stat -c '%s' "$tarball")
    if [[ "$size" -gt "$max_size" ]]; then
        echo "ERROR: Release tarball is unexpectedly large: ${size} bytes"
        return 1
    fi

    echo "Verified release tarball: ${size} bytes"
}

install_tarball_clean() {
    Rscript -e '
        args <- commandArgs(trailingOnly = TRUE)
        lib <- tempfile("mpaqt-release-lib-")
        dir.create(lib)
        on.exit(unlink(lib, recursive = TRUE), add = TRUE)
        install.packages(args[[1]], lib = lib, repos = NULL, type = "source")
        library(mpaqt, lib.loc = lib)
        stopifnot(as.character(packageVersion("mpaqt", lib.loc = lib)) == args[[2]])
        stopifnot(file.exists(system.file("bin", "mpaqt", package = "mpaqt",
                                          lib.loc = lib)))
    ' "releases/mpaqt_${VERSION}.tar.gz" "$VERSION"
}

run_task "Verify tarball contents and size" verify_tarball ||
    { print_summary || true; exit 1; }
run_task "Install tarball in clean library" install_tarball_clean ||
    { print_summary || true; exit 1; }

# =============================================================================
# Step 3: Build documentation website
# =============================================================================

echo ""
echo "Step 3: Building pkgdown site..."

run_task_inline "Build pkgdown site" "Rscript -e 'pkgdown::build_site(preview = FALSE)'" ||
    { print_summary || true; exit 1; }

verify_clean_tree_preserved() {
    if [[ "$STARTED_WITH_CLEAN_TREE" -eq 0 ]]; then
        echo "Skipped: release build started with existing working-tree changes"
        return 0
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        echo "ERROR: Release generation changed tracked or untracked files"
        git status --short
        return 1
    fi

    echo "Release generation preserved the clean working tree"
}

run_task "Verify clean release tree preserved" verify_clean_tree_preserved ||
    { print_summary || true; exit 1; }

# =============================================================================
# Summary
# =============================================================================

print_summary

echo ""
echo "Next steps:"
echo "  Run release_docker.sh, release_apptainer.sh, release_conda.sh"
echo "  Or run release_all.sh for a complete release"
