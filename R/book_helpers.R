# Helpers used by the transcription chapters. They read cached outputs only.

# Markdown for one volume: a page marker, then the page text in a plain block so
# the typewriter line breaks survive.
volume_markdown <- function(final, vol) {
  final |>
    dplyr::filter(volume == vol) |>
    dplyr::arrange(page) |>
    purrr::pmap_chr(\(page, final_text, ...) {
      sprintf("**[p. %d]**\n\n```\n%s\n```\n", page, final_text)
    }) |>
    paste(collapse = "\n")
}

# One-row-per-volume status: pages, tiers and how many pages have been reviewed
volume_status <- function(final) {
  final |>
    dplyr::summarise(
      .by = volume,
      pages = dplyr::n(),
      tier_A = sum(tier == "A_manual"),
      tier_B = sum(tier == "B_proofread"),
      tier_C = sum(tier == "C_spot_check"),
      edited = sum(source == "edited"),
      confirmed = sum(source == "confirmed"),
      ocr_draft_only = sum(source == "ocr_draft")
    )
}
