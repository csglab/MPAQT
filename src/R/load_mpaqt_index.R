#!/usr/bin/env Rscript

library(optparse)

# Define command line options
option_list <- list(
  make_option(c("-i", "--index"), type = "character", help = "Path to the index RDS file", metavar = "character"),
  make_option(c("-p", "--p_matrix"), type = "character", help = "Path to save the p_matrix RDS file", metavar = "character"),
  make_option(c("-c", "--cov_matrix"), type = "character", help = "Path to save the cov_matrix RDS file", metavar = "character")
)

# Parse command line options
arg_parser <- OptionParser(option_list = option_list)
args <- parse_args(arg_parser)

# Check if required arguments are provided
if (is.null(args$index) | is.null(args$p_matrix) | is.null(args$cov_matrix)) {
  print_help(arg_parser)
  stop("All three arguments --index, --p_matrix, and --cov_matrix must be supplied", call. = FALSE)
}

# Read the index RDS file
rds_list <- readRDS(args$index)

# Extract matrices from the list
p_matrix <- rds_list$P
cov_matrix <- rds_list$covMx

# Save the matrices as separate RDS files
saveRDS(p_matrix, args$p_matrix)
saveRDS(cov_matrix, args$cov_matrix)

# Print a success message
cat("Matrices successfully saved as separate RDS files\n")
