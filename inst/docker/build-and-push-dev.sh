#!/bin/bash
set -euo pipefail

# Configuration - use env vars if set, else defaults
DOCKER_USER="${DOCKER_USER:-csglab}"
DOCKER_ORGANIZATION="csglab"
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
IMAGE_TAG="${DOCKER_ORGANIZATION}/${IMAGE_NAME}:${VERSION}-dev"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed or not in PATH"
    exit 1
fi

push_image() {
    if [[ -n "${DOCKER_PASSWORD:-}" ]]; then
        echo "$DOCKER_PASSWORD" |
            docker login -u "$DOCKER_USER" --password-stdin
    fi

    docker push "$IMAGE_TAG"
}

if [[ "$MODE" == "--publish-only" ]]; then
    docker image inspect "$IMAGE_TAG" >/dev/null
    push_image
    exit 0
fi

echo "=== Building MPAQT Docker Image (dev) v${VERSION}-dev ==="

cleanup() {
    rm -f environment.yml
    rm -rf mpaqt-source
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

# Build Docker image
echo "Building Docker image..."
docker build -f Dockerfile.dev -t "$IMAGE_TAG" .

# Test the image
echo ""
echo "Testing image..."
docker run --rm "$IMAGE_TAG" R --slave -e "library(mpaqt); stopifnot(as.character(packageVersion('mpaqt')) == '${VERSION}'); cat('mpaqt ${VERSION} OK\\n')"
# CLI smoke test disabled; the release exposes only the R API.
# docker run --rm "$IMAGE_TAG" mpaqt --help
docker run --rm "$IMAGE_TAG" sh -c 'test ! -e /venv/bin/mpaqt'
docker run --rm "$IMAGE_TAG" kallisto version
docker run --rm "$IMAGE_TAG" bustools version
docker run --rm "$IMAGE_TAG" R --slave -e 'library(testthat); cat("testthat OK\n")'
docker run --rm "$IMAGE_TAG" R --slave -e 'library(devtools); cat("devtools OK\n")'

echo ""
echo "Build and tests complete: ${IMAGE_TAG}"

if [[ "$MODE" == "--publish" ]]; then
    push_image
fi
