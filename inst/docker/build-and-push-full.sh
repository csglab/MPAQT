#!/bin/bash

# Configuration - use env vars if set, else defaults
DOCKER_USER="${DOCKER_USER:-csglab}"
IMAGE_NAME="mpaqt"

# Parse arguments
AUTO_YES=false
[[ "$1" == "-y" ]] && AUTO_YES=true

cd "$(dirname "$0")"

# Read version from VERSION file
VERSION=$(cat ../../VERSION | tr -d '[:space:]')

echo "=== Building and Pushing MPAQT Docker Image (full) v${VERSION}-full ==="

# Check for docker command
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not in PATH"
    echo "Docker is required to build and push Docker images."
    echo ""
    echo "Alternative: Use Apptainer images from Sylabs Cloud:"
    echo "  apptainer pull library://csglab/mpaqt/mpaqt:${VERSION}-full"
    exit 1
fi

# Prepare build context
echo "Preparing build context..."
cp ../conda/environment_full.yml ./environment.yml

# Extract package from tarball
rm -rf ./mpaqt-source
cp ../../releases/mpaqt_${VERSION}.tar.gz ./
tar -xzf mpaqt_${VERSION}.tar.gz
mv mpaqt mpaqt-source
rm mpaqt_${VERSION}.tar.gz

# Build Docker image
echo "Building Docker image..."
docker build -f Dockerfile.full -t ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full .

# Cleanup build context
rm -f environment.yml
rm -rf mpaqt-source

# Test the image
echo ""
echo "Testing image..."
docker run --rm ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full R --slave -e 'library(mpaqt); cat("mpaqt", as.character(packageVersion("mpaqt")), "OK\n")'
docker run --rm ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full mpaqt --help | head -3
docker run --rm ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full minimap2 --version
docker run --rm ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full R --slave -e 'library(bambu); cat("bambu OK\n")'

echo ""
echo "Build complete: ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full"

# Push to DockerHub
if [[ "$AUTO_YES" == true ]]; then
    # Auto mode: push without prompting
    echo ""
    echo "Pushing to DockerHub..."

    # Login with password from env var (non-interactive)
    if [[ -n "$DOCKER_PASSWORD" ]]; then
        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin
    fi

    docker push ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full
    echo "Done! Image available at:"
    echo "  - docker.io/${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full"
else
    # Interactive mode
    read -p "Push to DockerHub? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Login if needed
        if ! docker info 2>/dev/null | grep -q "Username"; then
            echo "Logging in to DockerHub..."
            docker login -u "$DOCKER_USER"
        fi

        echo "Pushing to DockerHub..."
        docker push ${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full
        echo "Done! Image available at:"
        echo "  - docker.io/${DOCKER_USER}/${IMAGE_NAME}:${VERSION}-full"
    fi
fi
