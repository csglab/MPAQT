#!/bin/bash
# =============================================================================
# MPAQT Environment Setup Script
# =============================================================================
# This script creates a conda environment with all dependencies required for
# the MPAQT package. It installs R, external tools, and all R packages.
#
# Usage:
#   chmod +x setup_mpaqt_env.sh
#   ./setup_mpaqt_env.sh
#
# Requirements:
#   - Miniconda or Anaconda installed
#   - Internet connection for downloading packages
# =============================================================================

set -e  # Exit on error

# Configuration
ENV_NAME="mpaqt"
R_VERSION="4.4"

echo "=============================================="
echo "MPAQT Environment Setup"
echo "=============================================="

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo "ERROR: conda is not installed or not in PATH"
    echo "Please install Miniconda or Anaconda first:"
    echo "  https://docs.conda.io/en/latest/miniconda.html"
    exit 1
fi

# Initialize conda for bash if needed
CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"

# Check if environment already exists
if conda env list | grep -q "^${ENV_NAME} "; then
    echo "Environment '${ENV_NAME}' already exists."
    read -p "Do you want to remove it and create a fresh environment? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Removing existing environment..."
        conda env remove -n ${ENV_NAME} -y
    else
        echo "Exiting. Use 'conda activate ${ENV_NAME}' to use existing environment."
        exit 0
    fi
fi

# =============================================================================
# Step 1: Create conda environment with R and external tools
# =============================================================================
echo ""
echo "[Step 1/4] Creating conda environment with R and external tools..."

conda create -n ${ENV_NAME} -y \
    r-base=${R_VERSION} \
    kallisto \
    bustools \
    minimap2 \
    samtools \
    compilers \
    make \
    zlib \
    libxml2

echo "Conda environment created successfully!"

# =============================================================================
# Step 2: Install R packages via conda (complex ones with system deps)
# =============================================================================
echo ""
echo "[Step 2/4] Installing R packages via conda..."

conda install -n ${ENV_NAME} -y \
    r-devtools \
    r-xml2 \
    r-usethis \
    r-roxygen2 \
    r-remotes \
    bioconductor-biostrings \
    bioconductor-rtracklayer \
    bioconductor-genomicranges \
    bioconductor-genomicfeatures \
    bioconductor-bsgenome

echo "Conda R packages installed!"

# =============================================================================
# Step 3: Install remaining R packages via pak
# =============================================================================
echo ""
echo "[Step 3/4] Installing remaining R packages via pak..."

conda activate ${ENV_NAME}

# Install pak first
R -e "install.packages('pak', repos='https://cloud.r-project.org')"

# Install remaining packages
R -e "
pak::pak(c(
  # Core packages
  'data.table',
  'Matrix',
  'cli',
  'rlang',
  'magrittr',
  'stringr',
  'purrr',

  # Additional packages
  'box',
  'docopt',
  'lme4',
  'gpboost',
  'testthat'
), ask = FALSE)
"

echo "R packages installed!"

# =============================================================================
# Step 4: Verify installation
# =============================================================================
echo ""
echo "[Step 4/4] Verifying installation..."

R -e "
pkgs <- c('data.table', 'Matrix', 'cli', 'rlang', 'magrittr', 'stringr', 'purrr',
          'box', 'docopt', 'lme4', 'gpboost', 'devtools', 'testthat',
          'Biostrings', 'rtracklayer', 'GenomicRanges', 'GenomicFeatures', 'BSgenome')

missing <- c()
for (pkg in pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    missing <- c(missing, pkg)
  }
}

if (length(missing) > 0) {
  cat('WARNING: The following packages are missing:\n')
  cat(paste(' -', missing, collapse = '\n'), '\n')
  quit(status = 1)
} else {
  cat('All R packages installed successfully!\n')
}
"

# Verify external tools
echo ""
echo "Checking external tools..."
which kallisto && kallisto version 2>&1 | head -1
which bustools && bustools version 2>&1 | head -1
which minimap2 && minimap2 --version 2>&1 | head -1
which samtools && samtools --version 2>&1 | head -1

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "=============================================="
echo "MPAQT Environment Setup Complete!"
echo "=============================================="
echo ""
echo "To activate the environment, run:"
echo "  conda activate ${ENV_NAME}"
echo ""
echo "To install the mpaqt package, navigate to the package directory and run:"
echo "  R -e \"devtools::install()\""
echo ""
echo "Or for development, use:"
echo "  R -e \"devtools::load_all('.')\""
echo ""
