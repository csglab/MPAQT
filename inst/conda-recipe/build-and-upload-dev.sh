#!/bin/bash

# Check for conda-build
if ! conda build --version &>/dev/null; then
    echo "Error: conda-build is not installed."
    echo "Install it with: conda install conda-build"
    exit 1
fi

# Configuration - use env vars if set, else defaults
CONDA_USER="${CONDA_USER:-csglab}"

# Parse arguments
AUTO_YES=false
[[ "$1" == "-y" ]] && AUTO_YES=true

cd "$(dirname "$0")"

# Read version from VERSION file
VERSION=$(cat ../../VERSION | tr -d '[:space:]')

# Build the conda package
echo "=== Building conda package r-mpaqt-dev v${VERSION}-dev ==="
conda build . --output-folder ./output --variant-config-files meta-dev.yaml

# Find the built package
PACKAGE=$(find ./output \( -name "r-mpaqt-dev-*.tar.bz2" -o -name "r-mpaqt-dev-*.conda" \) | head -1)
echo "Built package: ${PACKAGE}"

# Upload to Anaconda
if [[ "$AUTO_YES" == true ]]; then
    # Auto mode: upload without prompting
    echo ""
    echo "Uploading to anaconda.org/${CONDA_USER}..."

    # Login with token from env var (non-interactive)
    if [[ -n "$CONDA_TOKEN" ]]; then
        anaconda -t "$CONDA_TOKEN" upload -u ${CONDA_USER} ${PACKAGE}
    else
        anaconda upload -u ${CONDA_USER} ${PACKAGE}
    fi
    echo "Done! Package available at: anaconda.org/${CONDA_USER}/r-mpaqt-dev"
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

        anaconda upload -u ${CONDA_USER} ${PACKAGE}
        echo "Done! Package available at: anaconda.org/${CONDA_USER}/r-mpaqt-dev"
    fi
fi

# Cleanup
rm -rf ./output
