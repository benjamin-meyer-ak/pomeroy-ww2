# Exploration (Oct 23, 2026): 10-page sample at 300 DPI, tesseract psm 3/4/6.
# Results are summarised in PLAN.md section 3. Reuse the pieces below when
# building the real extract/ocr functions and the tuning experiments.
library(pdftools)
library(magick)
library(tesseract)
library(tidyverse)

# Page sizes: vol1/vol3 are mostly landscape spreads, vol2 is portrait
page_sizes <- \(vols) map_dfr(vols, \(f) pdf_pagesize(f) |> mutate(file = basename(f), page = row_number()))

# Contact sheet of low-res thumbnails. pdf_render_page(numeric = FALSE) does not
# feed image_read(); render to PNG with pdf_convert() instead, and give
# image_write(format = "png") for montages (their format is empty).
sheet <- function(vol, pages, tile, name, dir = "data/pages/thumbs") {
  fn <- file.path(dir, sprintf("%s_p%03d.png", tools::file_path_sans_ext(vol), pages))
  suppressWarnings(pdf_convert(file.path("data/raw_pdf", vol), pages = pages, dpi = 45, filenames = fn, verbose = FALSE))
  map2(fn, pages, \(f, p) image_read(f) |> image_annotate(paste0("p", p), size = 24, color = "red", location = "+5+5")) |>
    image_join() |> image_montage(tile = tile, geometry = "+4+4") |>
    image_write(file.path(dir, name), format = "png")
  invisible(file.remove(fn))
}

sample_pages <- tribble(
  ~vol, ~page,
  "vol1", 1, "vol1", 44, "vol1", 70,
  "vol2", 1, "vol2", 40, "vol2", 120,
  "vol3", 2, "vol3", 20, "vol3", 66, "vol3", 87
) |>
  mutate(id = sprintf("%s_p%03d", vol, page), path = file.path("data/pages/sample", paste0(id, ".png")))

# Extract the sample at 300 DPI (file names follow the vol1_p001 convention)
extract_sample <- function(sp = sample_pages) {
  dir.create("data/pages/sample", showWarnings = FALSE, recursive = TRUE)
  pwalk(sp, \(vol, page, id, path, ...) {
    suppressWarnings(pdf_convert(file.path("data/raw_pdf", paste0(vol, ".pdf")), pages = page, dpi = 300,
                                 filenames = path, verbose = FALSE))
  })
}

engine_for <- \(psm, lang = "eng") tesseract(lang, options = list(tessedit_pageseg_mode = psm))

compare_psm <- function(sp = sample_pages, psms = c(3, 4, 6)) {
  expand_grid(sp |> select(id, path), psm = psms) |>
    mutate(data = map2(path, psm, \(p, m) ocr_data(p, engine = engine_for(m)))) |>
    mutate(words = map_int(data, nrow),
           mean_conf = map_dbl(data, \(d) mean(d$confidence)),
           pct_low = map_dbl(data, \(d) mean(d$confidence < 80) * 100))
}
# Caution: mean confidence is only a proxy. On vol2_p040 psm 6 returned ~640
# words vs ~414 for psm 3/4, so score with character error rate against
# hand-typed ground truth before choosing.
