# MPAQT <img src="man/figures/logo.png" align="right" height="139" alt="MPAQT logo" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

**M**ulti-**P**latform **A**ccurate **Q**uantification of **T**ranscripts

MPAQT is an R package for RNA-seq transcript quantification that integrates short-read and long-read sequencing data for improved accuracy. It supports both bulk and single-cell RNA-seq analysis.

**Documentation**: [csglab.github.io/MPAQT](https://csglab.github.io/MPAQT/)

---

## Features

- **Multi-platform integration**: Combine Illumina short-reads with PacBio/ONT long-reads
- **Bulk and single-cell**: Unified API for both analysis types
- **Positional bias correction**: Account for 3' or 5' sequencing biases
- **Prior integration**: Incorporate custom transcript-specific priors into
  abundance estimation
- **Flexible inputs**: Start from FASTQ or pre-computed counts

---

## Installation

Choose your preferred installation method:

| Method | Best For | Instructions |
|--------|----------|--------------|
| **Local** | Development, customization | [Jump to section](#local-installation) |
| **Conda** | Simple environment management | [Jump to section](#conda) |
| **Apptainer** | HPC clusters | [Jump to section](#apptainer) |
| **Docker** | Reproducibility, portability | [Jump to section](#docker) |

---

### Local Installation

#### Step 1: Install R and Dependencies

Install R (>= 4.0.0) from [CRAN](https://cran.r-project.org/) with compilation tools (make, zlib, curl).

Install the Bioconductor packages required by `mpaqt_index()`:

```r
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install(c("Biostrings", "rtracklayer"))
```

#### Step 2: Install MPAQT R Package

```r
install.packages("pak")
pak::pak("csglab/MPAQT")
```

The source repository is public. GitHub credentials are optional and can help
avoid API rate limits.

#### Step 3: Install System Tools

Install [kallisto](https://github.com/pachterlab/kallisto) (>= 0.50.1) and [bustools](https://github.com/BUStools/bustools) (>= 0.43.1).

Verify:
```bash
kallisto version
bustools version
```

---

### Conda

```bash
conda create -n mpaqt \
  -c csglab -c conda-forge -c bioconda \
  r-mpaqt
conda activate mpaqt

R -e 'library(mpaqt)'
```

---

### Apptainer

For HPC clusters without Docker access:

```bash
# Pull image
apptainer pull docker://csglab/mpaqt:2.0.0 

# R API usage
apptainer exec mpaqt_2.0.0.sif R -e 'library(mpaqt)'

# Run interactively
apptainer shell mpaqt_2.0.0.sif
```

---

### Docker

```bash
# Pull image
docker pull csglab/mpaqt:2.0.0

# R API usage
docker run -v $(pwd):/data csglab/mpaqt:2.0.0 R -e 'library(mpaqt)'

# Run interactively
docker run -it -v $(pwd):/data csglab/mpaqt:2.0.0
```

---

## Quick Start

### R API

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

## Documentation

Full documentation: **https://csglab.github.io/MPAQT/**

| Guide | Description |
|-------|-------------|
| [Installation](https://csglab.github.io/MPAQT/articles/installation.html) | Detailed installation guide |
| [Bulk Workflow](https://csglab.github.io/MPAQT/articles/bulk-workflow.html) | Complete bulk RNA-seq analysis |
| [Single-Cell](https://csglab.github.io/MPAQT/articles/single-cell-workflow.html) | Cluster-level quantification |
| [API Reference](https://csglab.github.io/MPAQT/reference/index.html) | All functions |

---

## Citation

If you use MPAQT in your research, please cite:

> Apostolides, M., Choi, B., Navickas, A., Saberi, A., Soto, L. M., Goodarzi, H., & Najafabadi, H. S. (2024). Accurate isoform quantification by joint short- and long-read RNA sequencing. *BioRxiv*. https://doi.org/10.1101/2024.07.11.603067

---

## Contributing

We welcome contributions! See our [Package Structure](https://csglab.github.io/MPAQT/articles/package-structure.html) guide.

Report issues at: https://github.com/csglab/MPAQT/issues.

---

## License

MIT License
