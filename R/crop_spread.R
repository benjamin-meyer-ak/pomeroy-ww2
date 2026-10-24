# Crop a scanned spread to its text page and trim the binding shadow and scan
# borders. Geometry is detected on a cheap low-DPI render, then applied to the
# full-resolution render. Only the right-hand page holds text in vol1/vol3
# (see data/volume_config.csv), so side = "right" is the default.
library(pdftools)
library(magick)
library(tidyverse)

gray_matrix <- function(img) {
  a <- image_data(image_convert(img, colorspace = "gray"), channels = "gray")
  # rows = x (columns of the picture), cols = y
  matrix(as.integer(a[1, , ]), nrow = dim(a)[2]) / 255
}

# last/first run helpers: extend a boundary while the profile stays dark
extend_while_dark <- function(is_dark, start, dir, max_steps) {
  pos <- start
  for (i in seq_len(max_steps)) {
    nxt <- pos + dir
    if (nxt < 1 || nxt > length(is_dark) || !is_dark[nxt]) break
    pos <- nxt
  }
  pos
}

# Returns fractional box (x0, x1, y0, y1) of the text page, in 0-1 of the spread
detect_text_box <- function(m, side = "right", dark_drop = 0.1, pad = 0.01) {
  w <- nrow(m); h <- ncol(m)
  colmed <- apply(m, 1, median)
  paper <- quantile(colmed[round(w * .55):round(w * .9)], .9)
  dark <- colmed < paper - dark_drop

  # Spine: darkest lines near the centre, then any graded shadow touching them
  centre <- round(w * .4):round(w * .6)
  spine <- centre[dark[centre]]
  spine_end <- if (length(spine)) max(spine) else round(w * .5)
  colmean <- colMeans(t(m))
  graded <- colmean < mean(colmean[round(w * .55):round(w * .9)]) - 0.04
  spine_end <- extend_while_dark(graded, spine_end, +1, round(w * .06))
  x0 <- spine_end + round(w * pad)

  # Outer scan border on the far edge
  edge <- round(w * .93):w
  edge_dark <- edge[dark[edge]]
  x1 <- if (length(edge_dark)) min(edge_dark) - round(w * pad) else w

  # Top/bottom borders, measured over the text page only
  rowmed <- apply(m[x0:x1, , drop = FALSE], 2, median)
  rdark <- rowmed < median(rowmed) - dark_drop
  top <- which(rdark[seq_len(round(h * .06))])
  bot <- which(rdark) |> keep(\(y) y > h * .94)
  y0 <- if (length(top)) max(top) + round(h * pad) else 1
  y1 <- if (length(bot)) min(bot) - round(h * pad) else h

  if (side == "left") stop("left-side text is not used in these volumes")
  c(x0 = x0 / w, x1 = x1 / w, y0 = y0 / h, y1 = y1 / h)
}

# page: 1-based PDF page. Returns a magick image at out_dpi.
crop_text_half <- function(pdf, page, out_dpi = 300, detect_dpi = 100, side = "right") {
  render <- function(dpi) {
    f <- file.path("data/interim", sprintf("render_%s_%03d_%d.png",
                                           tools::file_path_sans_ext(basename(pdf)), page, dpi))
    on.exit(unlink(f))
    pdf_convert(pdf, pages = page, dpi = dpi, format = "png", filenames = f, verbose = FALSE)
    image_read(f)
  }
  box <- detect_text_box(gray_matrix(render(detect_dpi)), side = side)
  hi <- render(out_dpi)
  info <- image_info(hi)
  geom <- geometry_area(
    width = round((box[["x1"]] - box[["x0"]]) * info$width),
    height = round((box[["y1"]] - box[["y0"]]) * info$height),
    x_off = round(box[["x0"]] * info$width),
    y_off = round(box[["y0"]] * info$height)
  )
  # repage drops the virtual canvas offset left by the crop
  image_crop(hi, geom, repage = FALSE)
}
