FROM rocker/tidyverse:4.3.1

# Install necessary system dependencies --> for rtracklayer
RUN apt-get update && \
    apt-get install -y libxml2-dev libssl-dev libcurl4-openssl-dev libgit2-dev libbz2-dev

RUN R -e "BiocManager::install('rtracklayer')"
RUN R -e "BiocManager::install('Biostrings')"
RUN R -e "BiocManager::install('Rsubread')"
# Install required packages
# Already pre-installed: dplyr, tidyr, stringr, Matrix 
#RUN install2.r \
#    -d TRUE -e \
#    -r "https://cran.rstudio.com" \
#    -r "http://www.bioconductor.org/packages/release/bioc" \
#    Biostrings \
#    Rsubread

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

# Install autoconf 2.69 because 2.71 doesnt work for installing kallisto. Need to FIRST install autoconf latest with apt-get, THEN install 2.69 otherwise it doesn't work
RUN wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz \
    && tar zxf autoconf-2.69.tar.gz \
    && cd autoconf-2.69 \
    && ./configure \
    && make && make install

## Install necessary system dependencies for kallisto
RUN apt-get install -y libxml2-dev libssl-dev libcurl4-openssl-dev libgit2-dev libbz2-dev cmake curl unzip libhts3

# Download and build Kallisto
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

ENV PATH="/MPAQT/scripts:${PATH}"


# Use Bash as the default shell
SHELL ["/bin/bash", "-c"]
