#!/usr/bin/env Rscript

shhh = suppressPackageStartupMessages
library(magrittr)
library(optparse) %>% shhh()
library(data.table) %>% shhh()

parser = OptionParser()
parser = add_option(parser, "--topdir", dest="topdir", type="character", help="Path to the project directory")
parser = add_option(parser, "--p_matrix", dest="p_matrix", type="character", help="RDS file containing the P matrix as a list")
parser = add_option(parser, "--lr_counts", dest="lr_counts", type="character", help="Path to the LR counts file. Should has a column named 'transcript_id' and a column named 'count'")

args = parse_args(parser)

P = readRDS(args$p_matrix)[[1]]

lr_counts = fread(args$lr_counts, select = c('transcript_id', 'count'))

p_matrix_trs = names(P)
p_matrix_counts = data.table(transcript_id = p_matrix_trs)
p_matrix_counts = merge(p_matrix_counts, lr_counts, by = 'transcript_id', all.x = TRUE, sort = FALSE)
p_matrix_counts[is.na(count), count := 0]
p_matrix_counts_as_numeric = p_matrix_counts[, as.numeric(count)]
names(p_matrix_counts_as_numeric) = p_matrix_counts$transcript_id

saveRDS(p_matrix_counts_as_numeric, file=file.path(args$topdir, "LR.counts.Rds"))
