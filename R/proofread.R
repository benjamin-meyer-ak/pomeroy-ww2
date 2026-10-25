# Launch the proofreading app from the project root.
# Requires output/pages.csv (run R/build_outputs.R first).
run_proofread <- function(root = getwd()) {
  stopifnot(file.exists(file.path(root, "output", "pages.csv")))
  options(pomeroy.root = normalizePath(root))
  shiny::runApp(file.path(root, "proofread"), launch.browser = TRUE)
}

# Apply data/corrections.csv to the OCR text: one final text per page.
# Corrected pages replace the draft; everything else keeps the OCR draft.
# Leftover [?word] marks stay visible so unresolved words are never hidden.
apply_corrections <- function(pages = readr::read_csv("output/pages.csv", show_col_types = FALSE),
                              corr_path = "data/corrections.csv") {
  corr <- if (file.exists(corr_path)) {
    readr::read_csv(corr_path, col_types = "cccc", show_col_types = FALSE)
  } else {
    tibble::tibble(page_id = character(), status = character(),
                   corrected_text = character(), saved_at = character())
  }
  pages |>
    dplyr::left_join(dplyr::select(corr, page_id, status, corrected_text), by = "page_id") |>
    dplyr::mutate(final_text = dplyr::coalesce(corrected_text, text_marked),
                  source = dplyr::coalesce(status, "ocr_draft")) |>
    dplyr::select(-corrected_text, -status)
}
