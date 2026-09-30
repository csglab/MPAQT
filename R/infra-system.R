# Infrastructure: System command execution
# Internal functions for running external tools like kallisto and bustools

#' Execute external system command with logging
#'
#' Wrapper around `system2()` with enhanced error handling, logging to files,
#' and automatic cleanup on success.
#'
#' @param task Character string identifying the task for logging
#' @param command The system command to execute
#' @param args Character vector of arguments to pass to command
#' @param output_dir Directory for stdout/stderr log files
#' @param check_command Logical; check if command exists in PATH
#' @param error_on_fail Logical; stop with error on non-zero exit code
#' @param wait Logical; wait for command to complete
#'
#' @return Invisible integer exit code
#' @keywords internal
run_system_command <- function(
    task,
    command,
    args = character(),
    output_dir = tempdir(),
    check_command = TRUE,
    error_on_fail = TRUE,
    wait = TRUE
) {
    # Check if command is available
    if (check_command) {
        check_tool_exists(command)
    }

    # Create output directory if it doesn't exist
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

    # Generate unique filenames for stdout/stderr
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    stdout_file <- file.path(output_dir, paste0(task, "_", timestamp, ".stdout"))
    stderr_file <- file.path(output_dir, paste0(task, "_", timestamp, ".stderr"))

    # Run the command with output redirection
    result <- system2(
        command = command,
        args = args,
        stdout = stdout_file,
        stderr = stderr_file,
        wait = wait
    )

    # Check exit code
    if (result != 0) {
        stdout_content <- if (file.exists(stdout_file)) {
            readLines(stdout_file, warn = FALSE)
        } else {
            character(0)
        }

        stderr_content <- if (file.exists(stderr_file)) {
            readLines(stderr_file, warn = FALSE)
        } else {
            character(0)
        }

        # Format error message
        cmd_string <- paste(command, paste(args, collapse = " "))

        if (error_on_fail) {
            extra_lines <- length(stderr_content) - 10
            cli::cli_abort(c(
                "Command failed with exit code {result}",
                "x" = paste("Command:", cmd_string),
                if (length(stderr_content) > 0) c(
                    "!" = "Stderr output:",
                    setNames(
                        utils::head(stderr_content, 10),
                        rep(" ", min(10, length(stderr_content)))
                    )
                ),
                if (length(stderr_content) > 10) c(
                    "i" = "... ({extra_lines} more lines)"
                ),
                "i" = "Full log: {.path {stderr_file}}"
            ))
        } else {
            cli::cli_warn(c(
                "Command failed with exit code {result}",
                "x" = paste("Command:", cmd_string),
                "i" = "Log files: {.path {output_dir}}"
            ))
        }
    } else {
        # Clean up files if successful
        unlink(c(stdout_file, stderr_file))
    }

    invisible(result)
}

#' Run command and capture output
#'
#' Execute a command and return its stdout as a character vector.
#'
#' @param command The system command to execute
#' @param args Character vector of arguments
#'
#' @return Character vector of stdout lines
#' @keywords internal
run_command_capture <- function(command, args = character()) {
    check_tool_exists(command)

    result <- system2(
        command = command,
        args = args,
        stdout = TRUE,
        stderr = TRUE
    )

    status <- attr(result, "status")
    if (!is.null(status) && status != 0) {
        cmd_str <- paste(command, paste(args, collapse = " "))
        cli::cli_abort(c(
            "Command failed with exit code {status}",
            "x" = paste("Command:", cmd_str)
        ))
    }

    result
}

#' Get version of an external tool
#'
#' @param tool Name of the tool
#'
#' @return Version string or NULL if cannot determine
#' @keywords internal
get_tool_version <- function(tool) {
    tryCatch({
        output <- run_command_capture(tool, "--version")
        # Extract version number (varies by tool)
        version_line <- output[grepl("version|v\\d", output, ignore.case = TRUE)][1]
        if (!is.na(version_line)) {
            # Try to extract version number
            matches <- regmatches(
                version_line,
                regexpr("\\d+\\.\\d+(\\.\\d+)?", version_line)
            )
            if (length(matches) > 0) {
                return(matches[1])
            }
        }
        return(NULL)
    }, error = function(e) {
        return(NULL)
    })
}
