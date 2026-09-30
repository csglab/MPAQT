#!/bin/bash

# Configuration - use env vars if set, else defaults
SYLABS_USER="${SYLABS_USER:-csglab}"
IMAGE_NAME="mpaqt"

# Parse arguments
AUTO_YES=false
[[ "$1" == "-y" ]] && AUTO_YES=true

cd "$(dirname "$0")"

# Read version from VERSION file
VERSION=$(cat ../../VERSION | tr -d '[:space:]')
SIF_FILE="mpaqt_${VERSION}-dev.sif"

echo "=== Building MPAQT Apptainer Image (dev) v${VERSION}-dev ==="

# Prepare build context
echo "Preparing build context..."
cp ../conda/environment_dev.yml ./environment.yml

# Extract package from tarball
rm -rf ./mpaqt-source
cp ../../releases/mpaqt_${VERSION}.tar.gz ./
tar -xzf mpaqt_${VERSION}.tar.gz
mv mpaqt mpaqt-source
rm mpaqt_${VERSION}.tar.gz

# Build (requires root or fakeroot)
echo "Building Apptainer image..."
apptainer build --fakeroot ${SIF_FILE} mpaqt-dev.def

# Cleanup build context
rm -f environment.yml
rm -rf mpaqt-source

# Show image size
echo ""
echo "Image size:"
ls -lh ${SIF_FILE}

# Run tests
echo ""
echo "Running tests..."
apptainer test ${SIF_FILE}

echo ""
echo "Build complete: ${SIF_FILE}"

# Push to Sylabs Cloud
if [[ "$AUTO_YES" == true ]]; then
    # Auto mode: push without prompting
    echo ""
    echo "Pushing to Sylabs Cloud..."

    # Add remote if not exists
    apptainer remote add --no-login SylabsCloud https://cloud.sylabs.io 2>/dev/null || true

    # Login with token from env var (non-interactive)
    if [[ -n "$SYLABS_TOKEN" ]]; then
        echo "$SYLABS_TOKEN" | apptainer remote login --tokenfile /dev/stdin SylabsCloud 2>/dev/null || true
    fi

    apptainer push -U ${SIF_FILE} library://${SYLABS_USER}/${IMAGE_NAME}/${IMAGE_NAME}:${VERSION}-dev
    echo "Done! Image available at:"
    echo "  - library://${SYLABS_USER}/${IMAGE_NAME}/${IMAGE_NAME}:${VERSION}-dev"
else
    # Interactive mode
    read -p "Push to Sylabs Cloud? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Add remote if not exists
        apptainer remote add --no-login SylabsCloud https://cloud.sylabs.io 2>/dev/null || true

        # Login only if not already logged in (check for valid token)
        if apptainer remote status SylabsCloud 2>&1 | grep -qi "logged in.*yes"; then
            echo "Already logged in to Sylabs Cloud"
        else
            echo "Logging in to Sylabs Cloud..."
            apptainer remote login SylabsCloud
        fi

        apptainer push -U ${SIF_FILE} library://${SYLABS_USER}/${IMAGE_NAME}/${IMAGE_NAME}:${VERSION}-dev
        echo "Done! Image available at:"
        echo "  - library://${SYLABS_USER}/${IMAGE_NAME}/${IMAGE_NAME}:${VERSION}-dev"
    fi
fi
