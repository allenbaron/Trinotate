#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(testthat))


# Capture & Validate Input ------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
fnlineage_path <- args[1]
nodes_path <- args[2]
out_path <- args[3]

stopifnot(
    file.exists(fnlineage_path),
    file.exists(nodes_path),
    dir.exists(dirname(out_path))
)


# Read and combine fullnamelineage.dmp and nodes.dmp ----------------------

# headers from taxdump_readme.txt + EMPTY (for trailing '|')
fnlineage_col <- c("tax_id", "tax_name", "lineage", "EMPTY")
nodes_col <- c("tax_id", "parent_tax_id", "rank", "embl_code", "division_id",
               "inherited_div_flag", "genetic_code_id", "inherited_GC_flag",
               "mitochondrial_genetic_code_id", "inherited_MGC_flag",
               "GenBank_hidden_flag", "hidden_subtree_root_flag", "comments",
               "plastid_genetic_code_id", "inherited_PGC_flag",
               "specified_species", "hydrogenosome_genetic_code_id",
               "inherited_HGC_flag", "EMPTY")

fnlineage_df <- readr::read_delim(
    fnlineage_path,
    col_names = fnlineage_col,
    col_types = cols_only(tax_id = "c", tax_name = "c", lineage = "c"),
    delim = "|",
    trim_ws = TRUE
)

nodes_df <- readr::read_delim(
    nodes_path,
    col_names = nodes_col,
    col_types = cols_only(tax_id = "c", parent_tax_id = "c", rank = "c"),
    delim = "|",
    trim_ws = TRUE
)

tax_df <- dplyr::full_join(
    x = fnlineage_df,
    y = nodes_df,
    by = "tax_id"
) %>%
    dplyr::select("tax_id", "tax_name", "rank", "parent_tax_id", "lineage")


# Validate join ---------------------------------------------------------

test_that("fullnamelineage & nodes join correct", {
    # all tax_ids present
    expect_setequal(tax_df$tax_id, fnlineage_df$tax_id)
    # no missing values, except unique_name
    expect_equal(sum(is.na(tax_df$tax_id)), 0)
    expect_equal(sum(is.na(tax_df$tax_name)), 0)
    expect_equal(sum(is.na(tax_df$parent_tax_id)), 0)
    expect_equal(sum(is.na(tax_df$rank)), 0)
})


# Save --------------------------------------------------------------------

readr::write_tsv(tax_df, out_path, col_names = FALSE)
