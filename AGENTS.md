# Project Memory: pomeroy-ww2

## Overview

Transcription of Richard Pomeroy's typewritten journals, with a fully documented, reproducible R OCR pipeline published as a Quarto book. Single planning doc: `PLAN.md` (decisions, measured scan findings, review of the v1/v2 Gemini blueprints, layout, 13 steps, open items). The two earlier blueprint files were merged into it and deleted (Oct 23, 2026). Read PLAN.md first in a new session.

## Source material (measured Oct 23, 2026)

- `data/raw_pdf/vol1.pdf` (102 pp: 98 landscape spreads + 4 portrait; WWII; spreads have one text page, one blank page, binding shadow, some handwriting), `vol2.pdf` (188 pp portrait), `vol3.pdf` (88 landscape spreads; WWII; p87-88 two-column newsletter pages, dark). Sizes ~266 / 22 / 222 MB.
- **`vol2.pdf` is the 1966 Europe travel journal, a SEPARATE document** (confirmed by owner). It needs its own full run to its own DOCX/PDF/CSV and its own `volume_config.csv` entry. Its front matter is pages 1-6 (3-page TOC with dotted leaders, itinerary, mail schedule), then 182 entry pages; punch-hole marks on some pages; German/French/Dutch names; speaker labels (Dick, Walt, Kay, Mary, Ann); typist initials `RWP/sg`.
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

## Current state (Oct 24, 2026)

**Goal reframed by owner:** automate as much transcription as possible and flag only what needs manual typing. The owner does not want to be asked for more analysis decisions; drive the work and report.

- Folders: `data/{raw_pdf,pages,interim}`, `output/`, `R/`, `docs/`. `.gitignore` uses CRLF line endings (the edit tool needs single-line matches).
- Book: `_quarto.yml` has parts "WWII Journals" (`09-vol1`, `10-vol3`) and "Europe Journal, 1966" (`11-europe-1966`), plus methods chapters `01-overview` to `08-assembly`. All chapters are stubs; the book has not been rendered. `repo-url` is a placeholder.
- Packages installed: pdftools, magick, officer, fs, purrr, stringr, tidyverse, tesseract, ellmer, targets, renv, quarto, spelling. Quarto CLI 1.6.40. Tesseract has `eng` and `osd` only; `deu`/`fra` not downloaded (the assistant cannot download them; owner must run `tesseract::tesseract_download("deu")` and `"fra"` in their own console).

### Code (R/)
- `inventory.R`: `profile_volume()`, `flag_pages()`; relative ink/sd_lum (absolute 30 DPI thresholds fail on thin typewriter text). Replaced `explore_inventory.R`.
- `crop_spread.R`: `detect_text_box()` on a 100 DPI render, `crop_text_half(pdf, page)` returns a 300 DPI crop of the right-hand page, trimming binding shadow and scan borders. vol3 p88 keeps some shadow at the left edge.
- `ocr_pipeline.R`: `prepare_page()` (crop spreads, full render for portrait/single pages, writes `data/pages/<id>.png`), `ocr_page()` (tesseract psm 3, gray, eng; caches `list(text, words)` in `data/interim/ocr/<id>.rds`). Runs in parallel with a PSOCK cluster, about 2.6 s/page with 6 workers (all 378 pages in about 20 min).
- `build_outputs.R`: aggregates the cache into tiers, drafts, review images and the manual queue.
- `explore_sample_ocr.R`: early exploration only.

### Data and outputs
- `data/volume_config.csv`: one row per volume (layout, text side, portrait pages, front-matter pages, check pages, duplicate pairs, OCR langs, notes). vol1/vol3 front matter not determined.
- Inventories: `data/interim/page_inventory.csv` (vol2), `data/interim/page_inventory_vol1_vol3.csv`.
  - vol2: no blank pages or duplicates; pages 1-6 front matter (3 TOC, itinerary, mail); entries start p7 ("Friday, 24 June, 1966"), so 182 entry pages (earlier estimate was 174).
  - vol1/vol3: text on the right half of every spread; vol1 p1 and p44-46 are portrait; vol3 p87-88 are two columns inside the right half. Duplicates: vol1 77=78, 96=97 (near-identical), vol1 p102 vs vol3 p1 (weaker match). Duplicates not removed.
- First full OCR pass (all 378 pages, eng only). Outputs: `output/pages.csv`, `output/ocr_words.csv`, `output/manual_queue.csv`, `output/vol{1,2,3}_draft.txt` (`[p. N]` markers, flagged words as `[?word]`, tier A pages bannered), red-box review images in `data/pages/review/`.
- Flag = word confidence < 60 or not in the dictionary. Tiers: A_manual (pct_flag >= 0.25, < 40 words, or forced: vol2 p1-6, vol3 p87-88) 36 pages; B_proofread (>= 0.10) 69; C_spot_check 273. Median page: 92-94% mean confidence, 5-8% words flagged.
- Most of vol1 tier A is p10-27, a worn/faded ribbon section with broken letters (legible to humans). Other tier A: vol2 p58, p93, p105.
- No ground truth yet, so thresholds are untuned. Thresholding preprocessing hurt (conf 66 to 30 on vol1 p10); contrast gave a small gain (not adopted). Names are flagged as non-dictionary words; confident misreads of real words are not flagged.

## Environment gotchas

- The assistant's R session cannot write outside the project (including the temp scratch dir); write to `data/interim/` or `data/pages/`. Pass in-memory images to tesseract as raw bytes: `ocr(image_write(img, format = "png"), engine = ...)`.
- Tesseract's first load had to happen in the user's own console (it creates the `tesseract5` folder under `AppData/Local`).
- `pdf_render_page(numeric = FALSE)` doesn't feed `image_read()`; use `pdf_convert()` to PNG (it passes the filename through `sprintf`, so warnings about unused arguments are harmless). `image_write()` on montages needs `format = "png"`. `image_crop(repage = FALSE)` drops the canvas offset.
- Long R calls time out at 30 s by default; set `timeout`. Heredocs through bash can lose backslashes in R code; edit with the edit tool afterward.

## Open items

- Next likely steps: proofreading view (side-by-side scan and editable text for tier A/B pages), `data/corrections.csv` workflow, DOCX and searchable PDF assembly, render the book.
- Rerun vol2 with `eng+deu+fra` once the language files are installed.
- Check vol1/vol3 first/last pages for front matter; decide which duplicate pages to drop (confirm against OCR text).
- Confirm WWII volume numbering (vol1.pdf/vol3.pdf).
- Hand-type ground-truth pages; tune psm, threshold, masking, languages; compare vision LLMs on tier A pages (front matter, two-column, faded ribbon).
- Decide `targets` (recommended) and `renv`; searchable PDF type; API keys in `.Renviron`; real repo URL; PDF engine (LaTeX or Typst).

## Style notes

- Base pipe `|>`, tidyverse, brief rationale-only comments.
- Pipeline runs via script/`targets`; the book reads cached outputs (`freeze: auto`) and never reruns OCR or API calls.
