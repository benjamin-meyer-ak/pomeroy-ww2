# Tuning experiments behind the choices described in the "Local OCR" chapter.
# Both run on the prepared page images (data/pages/), so run the OCR step
# first. Results are written to data/interim/experiments/ and read by the book.
library(tidyverse)
library(magick)
library(tesseract)

# Ten pages that cover every layout: portrait singles, a TOC, spreads, a
# faded-ribbon page and a two-column page
sample_ids <- c("vol1_p001", "vol1_p044", "vol1_p070", "vol2_p001", "vol2_p040",
                "vol2_p120", "vol3_p002", "vol3_p020", "vol3_p066", "vol3_p087")

ocr_stats <- function(img, psm = 3) {
  raw <- image_write(image_convert(img, colorspace = "gray"), format = "png")
  d <- ocr_data(raw, engine = tesseract("eng", options = list(tessedit_pageseg_mode = as.character(psm))))
  tibble(words = nrow(d), mean_conf = mean(d$confidence), pct_below_80 = mean(d$confidence < 80) * 100)
}

# Page-segmentation modes 3 (automatic), 4 (single column), 6 (single block)
compare_psm <- function(ids = sample_ids, psms = c(3, 4, 6)) {
  expand_grid(page_id = ids, psm = psms) |>
    mutate(stats = map2(page_id, psm, \(id, m) ocr_stats(image_read(file.path("data/pages", paste0(id, ".png"))), m))) |>
    unnest(stats)
}

# Preprocessing variants on one page from each of three kinds of page
preprocess_variants <- list(
  baseline = identity,
  threshold = \(img) img |> image_convert(colorspace = "gray") |>
    image_threshold("white", "55%") |> image_threshold("black", "55%"),
  contrast = \(img) image_contrast(img, sharpen = 1)
)

compare_preprocessing <- function(ids = c("vol1_p010", "vol2_p040", "vol3_p020")) {
  expand_grid(page_id = ids, variant = names(preprocess_variants)) |>
    mutate(stats = map2(page_id, variant, \(id, v) {
      img <- image_read(file.path("data/pages", paste0(id, ".png")))
      ocr_stats(preprocess_variants[[v]](img))
    })) |>
    unnest(stats)
}

run_experiments <- function(ocr_files = NULL, dir = "data/interim/experiments") {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  paths <- c(psm = file.path(dir, "psm_comparison.csv"),
             preprocessing = file.path(dir, "preprocessing_comparison.csv"))
  write_csv(compare_psm(), paths[["psm"]])
  write_csv(compare_preprocessing(), paths[["preprocessing"]])
  unname(paths)
}
