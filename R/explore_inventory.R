# Inventory step (written Oct 23, 2026, NOT yet completed): profile every page
# at 30 DPI to find blank pages, which half of a spread holds text, duplicate
# pages across volumes (via a 24x24 block-mean signature), and front matter.
# The first full run was cancelled (slow; run per volume, or via targets with
# caching). Write the result to data/interim/page_inventory.csv.
library(pdftools)
library(tidyverse)

block_mean <- function(m, n = 24) {
  ri <- cut(seq_len(nrow(m)), n, labels = FALSE)
  ci <- cut(seq_len(ncol(m)), n, labels = FALSE)
  as.vector(tapply(m, list(factor(ri, 1:n)[row(m)], factor(ci, 1:n)[col(m)]), mean))
}

profile_page <- function(pdf, page) {
  a <- pdf_render_page(pdf, page = page, dpi = 30, numeric = TRUE)
  g <- (a[, , 1] + a[, , 2] + a[, , 3]) / 3
  h <- nrow(g); w <- ncol(g)
  trim <- function(m) m[round(h * .06):round(h * .94), ]
  inkfrac <- function(m) mean(m < 0.5)
  tibble(
    width_px = w, height_px = h, mean_lum = mean(g), ink = inkfrac(g),
    ink_left = inkfrac(trim(g[, round(w * .06):round(w * .5)])),
    ink_right = inkfrac(trim(g[, round(w * .5):round(w * .94)])),
    sig = list(block_mean(g))
  )
}

profile_volume <- function(file) {
  pdf <- file.path("data/raw_pdf", file)
  tibble(file = file, page = seq_len(pdf_info(pdf)$pages)) |>
    mutate(prof = map(page, \(p) profile_page(pdf, p))) |>
    unnest(prof)
}
