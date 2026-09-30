#!/bin/bash
# Setup script for MPAQT conda environment
# Run from the package root directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/environment.yml"

echo "=== MPAQT Environment Setup ==="
echo ""

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo "ERROR: conda is not installed or not in PATH"
    echo "Please install miniconda or anaconda first:"
    echo "  https://docs.conda.io/en/latest/miniconda.html"
    exit 1
fi

# Check if environment already exists
if conda env list | grep -q "^mpaqt "; then
    echo "Environment 'mpaqt' already exists."
    read -p "Do you want to remove and recreate it? (y/N): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Removing existing environment..."
        conda env remove -n mpaqt -y
    else
        echo "Updating existing environment..."
        conda env update -n mpaqt -f "$ENV_FILE"
        echo ""
        echo "Environment updated. Activate with: conda activate mpaqt"
        exit 0
    fi
fi

# Create the environment
echo "Creating conda environment 'mpaqt'..."
conda env create -f "$ENV_FILE"

echo ""
echo "=== Installing Bioconductor packages ==="
echo ""

# Activate environment and install Bioconductor packages
conda run -n mpaqt Rscript -e '
# Install BiocManager if not present
if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

# Set Bioconductor version
BiocManager::install(version = "3.18", ask = FALSE)

# Install required Bioconductor packages
bioc_packages <- c(
    "Biostrings",
    "rtracklayer",
    "GenomicRanges",
    "IRanges",
    "BSgenome",
    "bambu",
    "SummarizedExperiment"
)

# Install packages (suppress most output)
for (pkg in bioc_packages) {
    cat("Installing", pkg, "...\n")
    BiocManager::install(pkg, ask = FALSE, update = FALSE, quiet = TRUE)
}

cat("\nBioconductor packages installed successfully!\n")
'

echo ""
echo "=== Environment Setup Complete ==="
echo ""
echo "To activate the environment, run:"
echo "  conda activate mpaqt"
echo ""
echo "To install the MPAQT package in development mode:"
echo "  conda activate mpaqt"
echo "  R -e 'devtools::install()'"
echo ""
echo "To run tests:"
echo "  R -e 'devtools::test()'"
echo ""
