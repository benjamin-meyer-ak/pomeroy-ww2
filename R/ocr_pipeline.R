# Page pipeline: PDF page -> cropped 300 DPI PNG -> tesseract OCR -> word table
# and page text, cached per page so a run can be stopped and resumed.
#   data/pages/<page_id>.png        prepared page image
#   data/interim/ocr/<page_id>.rds  list(text, words, langs)
library(tidyverse)
library(pdftools)
library(magick)
library(tesseract)
source("R/utils.R")
source("R/crop_spread.R")

cfg <- read_csv("data/volume_config.csv", show_col_types = FALSE)


page_ids <- function(vol) {
  row <- filter(cfg, volume_id == vol)
  tibble(volume_id = vol, file = row$file, page = seq_len(row$n_pages),
         page_id = sprintf("%s_p%03d", vol, page),
         layout = row$layout, is_portrait = page %in% parse_pages(row$portrait_pages))
}

# Download any tesseract language data that volume_config.csv asks for and is
# not installed. Stops if a language is still missing, so a run never silently
# uses fewer languages than the config says.
ensure_languages <- function(config) {
  want <- config$ocr_langs |> str_split("\\+") |> unlist() |> unique()
  for (lang in setdiff(want, tesseract_info()$available)) {
    message("Downloading tesseract language data: ", lang)
    tesseract_download(lang, progress = FALSE)
  }
  missing <- setdiff(want, tesseract_info()$available)
  if (length(missing)) stop("Tesseract language data still missing: ", paste(missing, collapse = ", "))
  sort(want)
}

prepare_page <- function(vol, page, force = FALSE) {
  id <- sprintf("%s_p%03d", vol, page)
  out <- file.path("data/pages", paste0(id, ".png"))
  if (!force && file.exists(out)) return(out)
  row <- filter(cfg, volume_id == vol)
  pdf <- file.path("data/raw_pdf", row$file)
  img <- if (row$layout == "spread" && !(page %in% parse_pages(row$portrait_pages))) {
    suppressWarnings(crop_text_half(pdf, page))
  } else {
    tmp <- file.path("data/interim", paste0("full_", id, ".png"))
    suppressWarnings(pdf_convert(pdf, pages = page, dpi = 300, format = "png",
                                 filenames = tmp, verbose = FALSE))
    on.exit(unlink(tmp))
    image_read(tmp)
  }
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  image_write(img, out, format = "png")
  out
}

ocr_engine <- function(langs = "eng", psm = 3) {
  tesseract(langs, options = list(tessedit_pageseg_mode = as.character(psm)))
}

# A cached result is reused only if it was made with the same languages, so
# changing ocr_langs in the config reruns the affected pages.
ocr_page <- function(vol, page, langs = "eng", force = FALSE) {
  id <- sprintf("%s_p%03d", vol, page)
  cache <- file.path("data/interim/ocr", paste0(id, ".rds"))
  if (!force && file.exists(cache) && identical(readRDS(cache)$langs, langs)) {
    return(invisible(cache))
  }
  png <- prepare_page(vol, page, force = force)
  img <- image_read(png) |> image_convert(colorspace = "gray")
  raw <- image_write(img, format = "png")
  eng <- ocr_engine(langs)
  words <- ocr_data(raw, engine = eng) |>
    mutate(page_id = id, .before = 1) |>
    separate_wider_delim(bbox, ",", names = c("x0", "y0", "x1", "y1")) |>
    mutate(across(x0:y1, as.integer))
  text <- ocr(raw, engine = eng)
  dir.create(dirname(cache), showWarnings = FALSE, recursive = TRUE)
  saveRDS(list(text = text, words = words, langs = langs), cache)
  invisible(cache)
}
