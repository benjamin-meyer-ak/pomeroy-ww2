# The whole pipeline, from the scanned PDFs to the final tables. Run with
#   targets::tar_make()
# Steps whose inputs have not changed are skipped; OCR results are also cached
# page by page in data/interim/ocr/, so an interrupted run resumes.
library(targets)
tar_source("R")
tar_option_set(packages = c("tidyverse", "pdftools", "magick", "tesseract"))

list(
  # Inputs: per-volume settings and the scans
  tar_target(config_file, "data/volume_config.csv", format = "file"),
  tar_target(config, read_csv(config_file, show_col_types = FALSE)),
  tar_target(pdf_files, file.path("data/raw_pdf", config$file), format = "file"),

  # Step 1: profile every page (blank, duplicate and layout checks)
  tar_target(inventory_file, run_inventory(config, pdf_files), format = "file"),

  # Step 2: crop, render and OCR every page
  tar_target(languages, ensure_languages(config)),
  tar_target(ocr_files, run_ocr(config, pdf_files, languages), format = "file"),

  # Step 3: tiers, draft text, review images, manual queue
  tar_target(output_files, build_outputs(config, ocr_files), format = "file"),

  # Step 4: settings experiments reported in the book
  tar_target(experiment_files, run_experiments(ocr_files), format = "file"),

  # Step 5: final text = OCR draft with the human corrections applied
  tar_target(corrections_file, "data/corrections.csv", format = "file"),
  tar_target(final, {
    output_files
    apply_corrections(corr_path = corrections_file)
  })
)
