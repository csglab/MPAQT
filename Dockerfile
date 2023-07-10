FROM bioconductor/release_core2:R3.6.2_Bioc3.10

# Install required packages
# Already pre-installed: rtracklayer, dplyr, Biostrings, stringr, Matrix
RUN install2.r \
    -d TRUE -e \
    -r "https://cran.rstudio.com" \
    -r "http://www.bioconductor.org/packages/release/bioc" \
    Rsubread \
    tidyr

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    zlib1g-dev \
    vim

# -->BUSTOOLS<--
# Clone the bustools repository
RUN git clone https://github.com/BUStools/bustools.git

# Build bustools
WORKDIR bustools
RUN mkdir build && cd build && cmake .. && make

# Add bustools to PATH
ENV PATH="/bustools/build/src:${PATH}"

# Set the working directory
WORKDIR /

# Install necessary dependencies
RUN apt-get install -y \
    libhdf5-dev \
    libboost-dev \
    libboost-program-options-dev \
    libboost-iostreams-dev \
    libssl-dev \
    curl \
    autoconf

## Download and build Kallisto
WORKDIR /kallisto
#https://github.com/pachterlab/kallisto/archive/refs/tags/v0.46.2.zip
RUN curl -LO https://github.com/pachterlab/kallisto/archive/refs/tags/v0.48.0.zip \
    && unzip v0.48.0.zip \
    && cd kallisto-0.48.0 \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make

# Add Kallisto executable to PATH
ENV PATH="/kallisto/kallisto-0.48.0/build/src:${PATH}"

# Set workdir to MPAQT
WORKDIR /MPAQT/scripts

# Use Bash as the default shell
SHELL ["/bin/bash", "-c"]
