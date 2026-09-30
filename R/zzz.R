# Package startup and shutdown functions

.onLoad <- function(libname, pkgname) {
    # Set data.table threads to avoid conflicts with parallel processing
    # Users can override with data.table::setDTthreads()
    if (requireNamespace("data.table", quietly = TRUE)) {
        # Use 1 thread by default to avoid nested parallelism issues
        # The user can increase this if they're not using other parallelism
        data.table::setDTthreads(1L)
    }
}

.onAttach <- function(libname, pkgname) {
    version <- utils::packageVersion(pkgname)

    packageStartupMessage(
        "MPAQT: Multi-Platform Aggregation and Quantification of Transcripts\n",
        "Version: ", version, "\n",
        "Type ?mpaqt for help"
    )

    # Check for required external tools
    kallisto_path <- Sys.which("kallisto")
    bustools_path <- Sys.which("bustools")

    missing_tools <- character()
    if (kallisto_path == "") {
        missing_tools <- c(missing_tools, "kallisto")
    }
    if (bustools_path == "") {
        missing_tools <- c(missing_tools, "bustools")
    }

    if (length(missing_tools) > 0) {
        packageStartupMessage(
            "\nNote: Some external tools are not found in PATH:\n",
            "  - ", paste(missing_tools, collapse = ", "), "\n",
            "These are required for index creation and read processing."
        )
    }
}
