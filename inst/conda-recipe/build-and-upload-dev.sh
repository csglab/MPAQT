#!/bin/bash

# Configuration - use env vars if set, else defaults
CONDA_USER="${CONDA_USER:-csglab}"
PKG_NAME="r-mpaqt-dev"
RECIPE_FILE="meta-dev.yaml"

# Parse arguments
AUTO_YES=false
[[ "$1" == "-y" ]] && AUTO_YES=true

cd "$(dirname "$0")"

# Read version from VERSION file
VERSION=$(cat ../../VERSION | tr -d '[:space:]')

# Configure git credentials for private repo access (in auto mode)
if [[ "$AUTO_YES" == true && -n "$GITHUB_USER" && -n "$GITHUB_TOKEN" ]]; then
    git config --global credential.helper '!f() { echo "username='$GITHUB_USER'"; echo "password='$GITHUB_TOKEN'"; }; f'
fi

# Create temp directory with the recipe
RECIPE_DIR=$(mktemp -d)
cp "${RECIPE_FILE}" "${RECIPE_DIR}/meta.yaml"
cp build.sh "${RECIPE_DIR}/" 2>/dev/null || true

# Build the conda package
echo "Building conda package ${PKG_NAME} v${VERSION}..."
if ! conda build "${RECIPE_DIR}" --output-folder ./output; then
    echo "ERROR: conda build failed"
    rm -rf "${RECIPE_DIR}"
    exit 1
fi

rm -rf "${RECIPE_DIR}"

# Find the built package (support both .tar.bz2 and .conda formats)
PACKAGE=$(find ./output -name "${PKG_NAME}-*.tar.bz2" -o -name "${PKG_NAME}-*.conda" 2>/dev/null | head -1)
echo "Built package: ${PACKAGE}"

# Verify package was found
if [[ -z "$PACKAGE" ]]; then
    echo "ERROR: No package found in ./output"
    echo "Contents of ./output:"
    ls -la ./output 2>/dev/null || echo "  (directory does not exist)"
    exit 1
fi

# Upload to Anaconda
if [[ "$AUTO_YES" == true ]]; then
    # Auto mode: upload without prompting
    echo ""
    echo "Uploading to anaconda.org/${CONDA_USER}..."

    # Login with token from env var (non-interactive)
    if [[ -n "$CONDA_TOKEN" ]]; then
        anaconda -t "$CONDA_TOKEN" upload --force -u ${CONDA_USER} ${PACKAGE}
    else
        anaconda upload --force -u ${CONDA_USER} ${PACKAGE}
    fi
    echo "Done! Package available at: anaconda.org/${CONDA_USER}/${PKG_NAME}"
else
    # Interactive mode
    read -p "Upload to anaconda.org/${CONDA_USER}? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Login only if not already logged in
        if ! anaconda whoami &>/dev/null; then
            echo "Logging in to Anaconda..."
            anaconda login
        else
            echo "Already logged in to Anaconda"
        fi

        anaconda upload --force -u ${CONDA_USER} ${PACKAGE}
        echo "Done! Package available at: anaconda.org/${CONDA_USER}/${PKG_NAME}"
    fi
fi

# Cleanup
rm -rf ./output
