#!/bin/bash
set -euo pipefail

# Configuration - use env vars if set, else defaults
SYLABS_USER="${SYLABS_USER:-csglab}"
IMAGE_NAME="mpaqt"

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
SIF_FILE="mpaqt_${VERSION}-dev.sif"
LIBRARY_URI="library://${SYLABS_USER}/${IMAGE_NAME}/${IMAGE_NAME}:${VERSION}-dev"

if ! command -v apptainer >/dev/null 2>&1; then
    echo "ERROR: Apptainer is not installed or not in PATH"
    exit 1
fi

push_image() {
    apptainer remote add --no-login SylabsCloud https://cloud.sylabs.io 2>/dev/null ||
        true

    if [[ -n "${SYLABS_TOKEN:-}" ]]; then
        echo "$SYLABS_TOKEN" |
            apptainer remote login --tokenfile /dev/stdin SylabsCloud
    fi

    apptainer push -U "$SIF_FILE" "$LIBRARY_URI"
}

if [[ "$MODE" == "--publish-only" ]]; then
    [[ -f "$SIF_FILE" ]] || {
        echo "ERROR: Missing $SIF_FILE"
        exit 1
    }
    push_image
    exit 0
fi

echo "=== Building MPAQT Apptainer Image (dev) v${VERSION}-dev ==="

PUBLIC_PULL_HOME=$(mktemp -d)
cleanup() {
    rm -f environment.yml
    rm -rf mpaqt-source
    rm -rf "$PUBLIC_PULL_HOME"
}
trap cleanup EXIT

# Prepare build context
echo "Preparing build context..."
cp ../conda/environment_dev.yml ./environment.yml

# Extract package from tarball
TARBALL="../../releases/mpaqt_${VERSION}.tar.gz"
[[ -f "$TARBALL" ]] || {
    echo "ERROR: Missing $TARBALL"
    exit 1
}
rm -rf mpaqt-source
tar -xzf "$TARBALL"
mv mpaqt mpaqt-source

# Build and test (requires root or fakeroot)
HOME="$PUBLIC_PULL_HOME" apptainer build --fakeroot "$SIF_FILE" mpaqt-dev.def
ls -lh "$SIF_FILE"
apptainer test "$SIF_FILE"
echo "Build and tests complete: ${SIF_FILE}"

if [[ "$MODE" == "--publish" ]]; then
    push_image
fi
