FROM bioconductor/release_core2:R3.6.2_Bioc3.10

# Install required packages
RUN install2.r \
    -d TRUE -e \
    -r "https://cran.rstudio.com" \
    -r "http://www.bioconductor.org/packages/release/bioc" \
    Rsubread 
