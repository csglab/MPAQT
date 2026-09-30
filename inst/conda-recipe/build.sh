#!/bin/bash
set -euxo pipefail

# Install the R package
R CMD INSTALL --build .

# CLI exposure is intentionally disabled; use the R API.
# mkdir -p "${PREFIX}/bin"
# ln -sf "${PREFIX}/lib/R/library/mpaqt/bin/mpaqt" "${PREFIX}/bin/mpaqt"
