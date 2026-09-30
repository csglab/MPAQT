# Stage 1: Build environment with conda and install mpaqt
FROM continuumio/miniconda3:latest AS builder

WORKDIR /build

# Copy environment file and package source
COPY environment.yml /build/environment.yml
COPY mpaqt-source /build/mpaqt-source

# Create environment with the solver bundled in the base image.
# Installing standalone mamba can break resolution of older Bioconda builds.
RUN conda env create --solver libmamba -f environment.yml && \
    # Install mpaqt R package
    /opt/conda/envs/mpaqt/bin/R CMD INSTALL /build/mpaqt-source && \
    # CLI exposure is intentionally disabled; use the R API.
    # cp /build/mpaqt-source/inst/bin/mpaqt /opt/conda/envs/mpaqt/bin/mpaqt && \
    # chmod +x /opt/conda/envs/mpaqt/bin/mpaqt && \
    # Pack the environment
    conda install -c conda-forge conda-pack -y && \
    conda-pack -n mpaqt -o /tmp/env.tar.gz && \
    mkdir /venv && cd /venv && tar xf /tmp/env.tar.gz && \
    rm /tmp/env.tar.gz && \
    /venv/bin/conda-unpack

# Stage 2: Minimal runtime image
FROM debian:bookworm-slim

LABEL maintainer="Ali Saberi, Michael Apostolides, Jichen Wang, Hamed S. Najafabadi"
LABEL version="2.4.0"
LABEL variant="stable"
LABEL description="MPAQT - Multi-Platform Accurate Quantification of Transcripts"
LABEL org.opencontainers.image.source="https://github.com/csglab/MPAQT_merged"

# Copy the packed environment from builder
COPY --from=builder /venv /venv

# Set environment variables
ENV PATH="/venv/bin:$PATH"
ENV LC_ALL=C

# Create working directory
WORKDIR /data

# Default command
CMD ["/bin/bash"]
