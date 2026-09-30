#!/bin/bash
set -ex

# Install the R package
R CMD INSTALL --build .

# Link the CLI script to PREFIX/bin so it's in PATH
mkdir -p "${PREFIX}/bin"
ln -sf "${PREFIX}/lib/R/library/mpaqt/bin/mpaqt" "${PREFIX}/bin/mpaqt"
