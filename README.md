# pomeroy-ww2

Transcription of Richard Pomeroy's typewritten journals (WWII volumes and a 1966 Europe journal), with a reproducible R OCR pipeline published as a Quarto book.

## Rebuild from the scans

1. Save the three PDFs as `data/raw_pdf/vol1.pdf`, `vol2.pdf`, `vol3.pdf` (not in git).
2. `renv::restore(lockfile = "renv.lock")`
3. `targets::tar_make()` (inventory, OCR, triage, experiments, final text; about 30 minutes)
4. `quarto render`

Per-volume settings are in `data/volume_config.csv`; human corrections are in `data/corrections.csv`. See the book's Setup chapter for details.
