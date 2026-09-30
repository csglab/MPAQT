#!/bin/bash
set -euo pipefail

# Configuration - use env vars if set, else defaults
CONDA_USER="${CONDA_USER:-csglab}"
PKG_NAME="r-mpaqt"

# Parse mode. Building is the safe default; publishing is always explicit.
MODE="${1:---build-only}"
case "$MODE" in
    --build-only|--publish|--publish-only) ;;
    -y) MODE="--publish" ;;
    *)
        echo "Usage: $0 [--build-only|--publish|--publish-only]"
        exit 2
        ;;
esac

cd "$(dirname "$0")"

# Read version from VERSION file
VERSION=$(tr -d '[:space:]' < ../../VERSION)

find_package() {
    find ./output -type f \
        \( -name "${PKG_NAME}-${VERSION}-*.tar.bz2" -o \
        -name "${PKG_NAME}-${VERSION}-*.conda" \) \
        -print -quit 2>/dev/null || true
}

upload_package() {
    local package="$1"

    command -v anaconda >/dev/null 2>&1 || {
        echo "ERROR: anaconda-client is not installed or not in PATH"
        return 1
    }

    if [[ -n "${CONDA_TOKEN:-}" ]]; then
        anaconda -t "$CONDA_TOKEN" upload -u "$CONDA_USER" "$package"
    else
        anaconda upload -u "$CONDA_USER" "$package"
    fi
}

if [[ "$MODE" == "--publish-only" ]]; then
    PACKAGE=$(find_package)
    [[ -n "$PACKAGE" ]] || {
        echo "ERROR: No validated ${PKG_NAME} ${VERSION} package found in ./output"
        exit 1
    }
    upload_package "$PACKAGE"
    exit 0
fi

echo "Building conda package ${PKG_NAME} v${VERSION}..."
conda build . --output-folder ./output
PACKAGE=$(find_package)
[[ -n "$PACKAGE" ]] || {
    echo "ERROR: No package found in ./output"
    exit 1
}
echo "Build and tests complete: ${PACKAGE}"

if [[ "$MODE" == "--publish" ]]; then
    upload_package "$PACKAGE"
fi
