# Project Memory: pomeroy-ww2

## Overview

Transcription of the WWII journals of Richard Pomeroy, with a fully documented, reproducible R OCR pipeline published as a Quarto book. Planning docs: `PLAN.md` (decisions, layout, 10 steps) and `rstudio_ocr_workflow_blueprint.md` (original blueprint).

## Source material

- 3 typewritten PDFs: vol 1 = 174 pp, vol 2 = 102 pp, vol 3 = 88 pp (364 total).
- Placed at `data/raw_pdf/vol1.pdf`, `vol2.pdf`, `vol3.pdf` (Oct 23, 2026). Actual page counts DON'T match the above: vol1.pdf = 102 pp, vol2.pdf = 188 pp, vol3.pdf = 88 pp (378 total). Likely file/volume mix-up and/or 14 extra pages; needs checking.
- No embedded text layer in any PDF (pdf_text empty), so full OCR is needed.
- Some vol1.pdf pages are landscape 1224x792 pt (double width), possibly two-page spreads needing splitting before OCR.
- Local copies only: `data/raw_pdf/*`, `data/pages/*` and `*.pdf` are gitignored (except `output/*.pdf` and `docs/**/*.pdf`).
- File sizes: vol1 ~266 MB, vol2 ~22 MB, vol3 ~222 MB.

## Decisions (from interview, Oct 23, 2026)

- Book contains methods chapters plus one transcription chapter per volume.
- Public publishing via GitHub Pages from `docs/` (un-ignored); owner confirmed cleared to publish. `repo-url` in `_quarto.yml` is a placeholder.
- Quality target: near-verbatim; flag low-confidence words and proofread them.
- Keep `[p. N]` page markers; no dated-entry parsing for now.
- Triage: automatic tesseract-confidence scoring with manual overrides in `data/triage_overrides.csv` (not yet created).
- Engines: tesseract + magick locally; vision LLM via ellmer for failed pages. Open to Gemini, Claude, OpenAI; compare on ~10 hand-typed pages (character error rate, cost). Blueprint's `gemini-1.5-flash` is likely retired.
- Deliverables: DOCX, searchable PDF, per-page CSV (text, confidence, engine), side-by-side proofreading view.
- Page IDs: `vol1_p001.png` style, 300 DPI.

## Current state

- Folders created: `data/{raw_pdf,pages,interim}`, `output/`, `R/`, `docs/`.
- Quarto book scaffolded: `_quarto.yml`, `index.qmd`, `01-overview` to `08-assembly`, `09-vol1`, `10-vol2`, `11-vol3`, `references.qmd`, `references.bib` (stubs only; not yet rendered).
- Packages installed: pdftools, magick, officer, fs, purrr, stringr, tidyverse, tesseract, ellmer, targets, renv, quarto, spelling. Quarto CLI 1.6.40.
- Blocked: `library(tesseract)` fails in the assistant session because it tries to create `C:\Users\Benjamin\AppData\Local\tesseract5\tesseract5` (outside allowed paths). User said they installed tesseract, but it was still blocked afterward. Next: user runs `library(tesseract); tesseract_info()` in their own console, or allow the path, or use a project-local tessdata folder (with user's OK). English OCR test not yet run.
- `.gitignore` uses CRLF line endings; the edit tool needs single-line matches.

## Open items

- Map each PDF to its volume; reconcile page counts (378 vs 364); check landscape/spread pages, blank pages, scan quality via low-res thumbnails.
- Resolve the tesseract first-load permission issue, then run an OCR test.
- Decide whether to use `targets` (recommended) and `renv`.
- Searchable PDF: scans with text layer, typeset transcription, or both.
- Set up API keys in `.Renviron`.
- Set the real repo URL; confirm PDF render engine (LaTeX or Typst).

## Style notes

- Use base pipe `|>`, tidyverse, brief rationale-only comments.
- Pipeline should run via script/`targets`; the book reads cached outputs (`freeze: auto`) and never reruns OCR or API calls.
