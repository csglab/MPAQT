#!/usr/bin/env Rscript

# Load required package
library(optparse)

# Define command line options
option_list <- list(
  make_option(c("-p", "--p_matrix"), type = "character", help = "Path to the p_matrix RDS file", metavar = "character"),
  make_option(c("-c", "--cov_matrix"), type = "character", help = "Path to the cov_matrix RDS file", metavar = "character"),
  make_option(c("-o", "--output"), type = "character", help = "Path to the output RDS file", metavar = "character")
)

# Parse command line options
arg_parser <- OptionParser(option_list = option_list)
args <- parse_args(arg_parser)

# Check if required arguments are provided
if (is.null(args$p_matrix) | is.null(args$cov_matrix) | is.null(args$output)) {
  print_help(arg_parser)
  stop("All three arguments --p_matrix, --cov_matrix, and --output must be supplied", call. = FALSE)
}

# Read the input RDS files
p_matrix <- readRDS(args$p_matrix)
cov_matrix <- readRDS(args$cov_matrix)

# Create a list with named elements
rds_list <- list(P = p_matrix, covMx = cov_matrix)

# Save the list as an RDS file
saveRDS(rds_list, args$output)

# Print a success message
