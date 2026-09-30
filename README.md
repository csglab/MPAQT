# MPAQT <img src="man/figures/logo.png" align="right" height="139" alt="MPAQT logo" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

**M**ulti-**P**latform **A**ccurate **Q**uantification of **T**ranscripts

MPAQT is an R package for RNA-seq transcript quantification that integrates short-read and long-read sequencing data for improved accuracy. It supports both bulk and single-cell RNA-seq analysis.

**Documentation**: [csglab.github.io/mpaqt2](https://csglab.github.io/mpaqt2/)

---

## Features

- **Multi-platform integration**: Combine Illumina short-reads with PacBio/ONT long-reads
- **Bulk and single-cell**: Unified API for both analysis types
- **Positional bias correction**: Account for 3' or 5' sequencing biases
- **Uncertainty quantification**: Bootstrap-based standard errors
- **Flexible inputs**: Start from FASTQ or pre-computed counts
- **Command-line interface**: Shell-friendly workflow automation

---

## Installation

Choose your preferred installation method:

| Method | Best For | Instructions |
|--------|----------|--------------|
| **Local** | Development, customization | [Jump to section](#local-installation) |
| **Docker** | Reproducibility, portability | [Jump to section](#docker) |
| **Apptainer** | HPC clusters | [Jump to section](#apptainer) |
| **Conda** | Simple environment management | [Jump to section](#conda-package) |

---

### Local Installation

#### Step 1: Install R and Compilation Dependencies

```bash
# Via conda (recommended)
conda install -c conda-forge r-base cmake icu zlib
```

Or install R from [CRAN](https://cran.r-project.org/) and ensure `cmake`, `icu`, and `zlib` are available.

---

#### Step 2: Install MPAQT R Package

```r
# Install pak (recommended)
install.packages("pak")

# Install MPAQT from GitHub
pak::pak("csglab/mpaqt2")
```

Alternative with devtools:
```r
install.packages("devtools")
devtools::install_github("csglab/mpaqt2")
```

---

#### Step 3: Install Required System Tools

```bash
# Required for short-read processing
conda install -c bioconda kallisto bustools
```

| Tool | Version | Purpose |
|------|---------|---------|
| **kallisto** | >= 0.50.1 | Short-read pseudoalignment |
| **bustools** | >= 0.43.1 | BUS file processing |

---

### Docker

```bash
# Pull image
docker pull csglab/mpaqt:2.0.0

# CLI usage
docker run -v $(pwd):/data csglab/mpaqt:2.0.0 mpaqt --help

# R API usage
docker run -v $(pwd):/data csglab/mpaqt:2.0.0 R -e 'library(mpaqt)'

# Run interactively
docker run -it -v $(pwd):/data csglab/mpaqt:2.0.0
```

---

### Apptainer

For HPC clusters without Docker access:

```bash
# Pull image
apptainer pull library://csglab/mpaqt:2.0.0

# CLI usage
apptainer exec mpaqt_2.0.0.sif mpaqt --help

# R API usage
apptainer exec mpaqt_2.0.0.sif R -e 'library(mpaqt)'

# Run interactively
apptainer shell mpaqt_2.0.0.sif
```

---

### Conda Package

```bash
# Install from csglab channel
conda install -c csglab -c conda-forge -c bioconda r-mpaqt
```

---

## Quick Start

### R Interface

```r
library(mpaqt)

# 1. Create index (run once)
index <- mpaqt_index(
  annotation = "gencode.v44.gtf",
  transcriptome = "gencode.v44.transcripts.fa",
  output_file = "mpaqt.index.rds"
)

# 2. Process short reads
sr_counts <- mpaqt_prepare_short_reads(
  index = index,
  fastq_1 = "sample_R1.fastq.gz",
  fastq_2 = "sample_R2.fastq.gz",
  output_dir = "results/"
)

# 3. Quantify
result <- mpaqt_quant(
  index = index,
  sr_counts = sr_counts,
  positional_bias = "3p"
)

# 4. Get results
tpm_values <- tpm(result)
```

---

### Command Line Interface

```bash
mpaqt run my_index.rds \
  --fastq-r1 sample_R1.fastq.gz \
  --fastq-r2 sample_R2.fastq.gz \
  --bias 3p \
  --output-dir results/ \
  --threads 8
```

---

## Documentation

Full documentation: **https://csglab.github.io/mpaqt2/**

| Guide | Description |
|-------|-------------|
| [Get Started](https://csglab.github.io/mpaqt2/articles/mpaqt.html) | Package overview and concepts |
| [Installation](https://csglab.github.io/mpaqt2/articles/installation.html) | Detailed installation guide |
| [Bulk Workflow](https://csglab.github.io/mpaqt2/articles/bulk-workflow.html) | Complete bulk RNA-seq analysis |
| [Single-Cell](https://csglab.github.io/mpaqt2/articles/single-cell-workflow.html) | Cluster-level quantification |
| [CLI Reference](https://csglab.github.io/mpaqt2/articles/cli-reference.html) | Command-line interface |
| [API Reference](https://csglab.github.io/mpaqt2/reference/index.html) | All functions |

---

## Citation

If you use MPAQT in your research, please cite:

> Apostolides, M., Choi, B., Navickas, A., Saberi, A., Soto, L. M., Goodarzi, H., & Najafabadi, H. S. (2024). Accurate isoform quantification by joint short-and long-read RNA-sequencing. *BioRxiv*. https://doi.org/10.1101/2024.07.11.603067

---

## Contributing

We welcome contributions! See our [Package Structure](https://csglab.github.io/mpaqt2/articles/package-structure.html) guide.

Report issues at: https://github.com/csglab/mpaqt2/issues

---

## License

MIT License
