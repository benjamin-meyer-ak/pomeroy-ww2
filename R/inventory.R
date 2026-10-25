# Inventory step: profile every page at low DPI to find blank pages, duplicate
# pages (24x24 block-mean signature) and front matter. Run per volume.
# Typewriter strokes are thin and wash out at 30 DPI, so "ink" is measured
# relative to each page's own median luminance, not an absolute threshold.
library(pdftools)
library(tidyverse)

block_mean <- function(m, n = 24) {
  ri <- cut(seq_len(nrow(m)), n, labels = FALSE)
  ci <- cut(seq_len(ncol(m)), n, labels = FALSE)
  as.vector(tapply(m, list(factor(ri, 1:n)[row(m)], factor(ci, 1:n)[col(m)]), mean))
}

profile_page <- function(pdf, page, dpi = 40) {
  a <- pdf_render_page(pdf, page = page, dpi = dpi, numeric = TRUE)
  g <- (a[, , 1] + a[, , 2] + a[, , 3]) / 3
  h <- nrow(g); w <- ncol(g)
  cut_at <- median(g) - 0.12
  ink <- function(m) mean(m < cut_at)
  trim <- function(m) m[round(h * .06):round(h * .94), ]
  tibble(
    width_px = w, height_px = h, mean_lum = mean(g), sd_lum = sd(g),
    ink = ink(trim(g[, round(w * .06):round(w * .94)])),
    ink_left = ink(trim(g[, round(w * .06):round(w * .5)])),
    ink_right = ink(trim(g[, round(w * .5):round(w * .94)])),
    sig = list(block_mean(g))
  )
}

profile_volume <- function(file, dpi = 40) {
  pdf <- file.path("data/raw_pdf", file)
  vol <- tools::file_path_sans_ext(file)
  tibble(file = file, page_id = sprintf("%s_p%03d", vol, seq_len(pdf_info(pdf)$pages))) |>
    mutate(page = row_number(), prof = map(page, \(p) profile_page(pdf, p, dpi))) |>
    unnest(prof)
}

flag_pages <- function(inv, blank_ink = 0.003, dup_dist = 0.15) {
  sigm <- do.call(rbind, inv$sig)
  d <- as.matrix(dist(sigm)); diag(d) <- Inf
  nn <- apply(d, 1, which.min)
  inv |>
    mutate(
      orientation = if_else(width_px > height_px, "landscape", "portrait"),
      is_blank = ink < blank_ink,
      nearest_page = nn,
      nearest_dist = d[cbind(seq_along(nn), nn)],
      possible_dup = nearest_dist < dup_dist
    ) |>
    select(-sig)
}

# Inventory every PDF listed in the config and write one table. Duplicate
# detection runs over all pages together, so a repeat across files (such as
# vol1 p102 and vol3 p1) is found too.
run_inventory <- function(config, pdf_files = NULL, out = "data/interim/page_inventory.csv", dpi = 40) {
  inv <- map(config$file, profile_volume, dpi = dpi) |> list_rbind() |> flag_pages()
  inv <- inv |>
    mutate(nearest_id = page_id[nearest_page]) |>
    select(-nearest_page)
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  write_csv(inv, out)
  out
}
