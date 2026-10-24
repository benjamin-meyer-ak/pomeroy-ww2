# Project Memory: pomeroy-ww2

## Overview

Transcription of Richard Pomeroy's typewritten journals, with a fully documented, reproducible R OCR pipeline published as a Quarto book. Single planning doc: `PLAN.md` (decisions, measured scan findings, review of the v1/v2 Gemini blueprints, layout, 13 steps, open items). The two earlier blueprint files were merged into it and deleted (Oct 23, 2026). Read PLAN.md first in a new session.

## Source material (measured Oct 23, 2026)

- `data/raw_pdf/vol1.pdf` (102 pp: 98 landscape spreads + 4 portrait; WWII; spreads have one text page, one blank page, binding shadow, some handwriting), `vol2.pdf` (188 pp portrait), `vol3.pdf` (88 landscape spreads; WWII; p87-88 two-column newsletter pages, dark). Sizes ~266 / 22 / 222 MB.
- **`vol2.pdf` is the 1966 Europe travel journal, a SEPARATE document** (confirmed by owner). It needs its own full run to its own DOCX/PDF/CSV and its own `volume_config.csv` entry. Its front matter (3-page TOC with dotted leaders, itinerary, mail schedule) is about 14 pages beyond 174 entry pages; punch-hole marks on some pages; German/French/Dutch names; speaker labels (Dick, Walt, Kay, Mary, Ann); typist initials `RWP/sg`.
- vol1.pdf p102 appears to repeat vol3.pdf p1 (overlap). WWII volume numbering still unconfirmed (owner's original counts: 174 / 102 / 88, so the 102-page file is probably the second volume).
- No embedded text layer in any PDF; full OCR needed.
- Local copies only: `data/raw_pdf/*`, `data/pages/*` and `*.pdf` are gitignored (except `output/*.pdf` and `docs/**/*.pdf`).

## Decisions (interview, Oct 23, 2026)

- Book: methods chapters plus one transcription chapter per volume/document.
- Public GitHub Pages from `docs/` (un-ignored); owner cleared to publish. `repo-url` in `_quarto.yml` is a placeholder.
- Near-verbatim target; flag low-confidence words and proofread; never silently correct text (use `data/corrections.csv`).
- Keep `[p. N]` markers; no dated-entry parsing for now.
- Triage: automatic scoring (tesseract confidence plus pixel stats) with manual overrides in `data/triage_overrides.csv` (not yet created).
- Engines: tesseract + magick locally; vision LLM via ellmer for front matter, two-column and failed pages. Open to Gemini, Claude, OpenAI; compare on ~10 hand-typed pages (character error rate, cost). `gemini-1.5-flash` is likely retired.
- Deliverables: DOCX, searchable PDF, per-page CSV (text, confidence, engine), side-by-side proofreading view.
- Page IDs `vol1_p001.png` style at 300 DPI.

## Findings so far

- Sample of 10 pages at 300 DPI, mean tesseract confidence: psm 3 = 86.0, psm 4 = 85.6, psm 6 = 81.6; psm 6 merges columns on two-column pages. But psm 6 returned ~640 words vs ~414 on `vol2_p040`, so confidence is a poor proxy; decide on character error rate vs hand-typed ground truth.
- vol2 TOC page scores ~27% confidence in every mode, so route front matter to an LLM.
- Spreads need crop-to-text-half (detect side by ink density) and binding-shadow trimming; do not blindly split in half.
- v2 blueprint ideas adopted/rejected: see PLAN.md section 3.

## Current state

- Folders: `data/{raw_pdf,pages,interim}`, `output/`, `R/`, `docs/`. `.gitignore` updated (CRLF line endings; the edit tool needs single-line matches).
- Quarto book scaffolded (`_quarto.yml`, `index.qmd`, `01-overview` to `08-assembly`, `09-vol1`, `10-vol2`, `11-vol3`, `references`), stubs only, not yet rendered. Chapter layout still treats vol2 as a WWII volume; revise for the separate 1966 document.
- Packages installed: pdftools, magick, officer, fs, purrr, stringr, tidyverse, tesseract, ellmer, targets, renv, quarto, spelling. Quarto CLI 1.6.40. Tesseract works (`eng`, `osd`; first load needed to run in the user's console). `deu`/`fra` not yet downloaded.
- Exploration code saved in `R/explore_sample_ocr.R` and `R/explore_inventory.R`. Sample PNGs (`data/pages/sample/`) and contact sheets (`data/pages/thumbs/`) exist locally (gitignored) if the earlier run completed.
- Inventory step (blank pages, duplicates, front-matter pages, `data/volume_config.csv`) NOT done; the full-page profiling run was cancelled for slowness (run per volume or via targets).

## Environment gotchas

- The assistant's R session cannot write outside the project (including the temp scratch dir); write to `data/interim/` or `data/pages/`. Pass in-memory images to tesseract as raw bytes if needed.
- Tesseract's first load must happen in the user's own console (it creates `AppData\Local\tesseract5`).
- `pdf_render_page(numeric = FALSE)` doesn't feed `image_read()`; use `pdf_convert()` to PNG. `image_write()` on montages needs `format = "png"`.

## Open items

- Confirm WWII volume numbering; how the 1966 journal appears in the book (separate part/chapter).
- Finish inventory; write `data/volume_config.csv`.
- Hand-type ground-truth pages; run tuning experiments (psm, threshold window, languages, masking).
- Decide `targets` (recommended) and `renv`; searchable PDF type; API keys in `.Renviron`; real repo URL; PDF engine (LaTeX or Typst).

## Style notes

- Base pipe `|>`, tidyverse, brief rationale-only comments.
- Pipeline runs via script/`targets`; the book reads cached outputs (`freeze: auto`) and never reruns OCR or API calls.
