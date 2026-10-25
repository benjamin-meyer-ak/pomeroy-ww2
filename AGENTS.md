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
- Book: `_quarto.yml` has parts "WWII Journals" (`09-vol1`, `10-vol3`) and "Europe Journal, 1966" (`11-europe-1966`), plus methods chapters `01-overview` to `08-assembly`. Methods chapters 01-08 were drafted Oct 24 (rendered clean to HTML); pipeline code is pulled in with `#| file:` + `eval: false` so the book shows the real source, and numbers come from chunks reading cached outputs. 06 (vision LLM) and 08 (assembly) are marked "planned, not built". Transcription chapters 09-11 show a status table; the text chunk is `eval: false` until review is done (flip to true to publish). `repo-url` is a placeholder; `references.bib` is empty.
- Packages installed: pdftools, magick, officer, fs, purrr, stringr, tidyverse, tesseract, ellmer, targets, renv, quarto, spelling. Quarto CLI 1.6.40. Tesseract has `eng` and `osd` only; `deu`/`fra` not downloaded (the assistant cannot download them; owner must run `tesseract::tesseract_download("deu")` and `"fra"` in their own console).

### Code (R/)
- `inventory.R`: `profile_volume()`, `flag_pages()`; relative ink/sd_lum (absolute 30 DPI thresholds fail on thin typewriter text). Replaced `explore_inventory.R`.
- `crop_spread.R`: `detect_text_box()` on a 100 DPI render, `crop_text_half(pdf, page)` returns a 300 DPI crop of the right-hand page, trimming binding shadow and scan borders. vol3 p88 keeps some shadow at the left edge.
- `ocr_pipeline.R`: `prepare_page()` (crop spreads, full render for portrait/single pages, writes `data/pages/<id>.png`), `ocr_page()` (tesseract psm 3, gray, eng; caches `list(text, words)` in `data/interim/ocr/<id>.rds`). Runs in parallel with a PSOCK cluster, about 2.6 s/page with 6 workers (all 378 pages in about 20 min).
- `build_outputs.R`: aggregates the cache into tiers, drafts, review images and the manual queue.
- `run_ocr.R`: `run_ocr(vols, workers)` runs the cached parallel OCR over whole volumes (uses installed languages from volume_config; smoke-tested on cached vol3). `book_helpers.R`: `volume_markdown()`, `volume_status()` for chapters 09-11.
- `explore_sample_ocr.R`: early exploration only.
- `proofread.R`: `run_proofread()` launches the Shiny app in `proofread/app.R`; `apply_corrections()` merges `data/corrections.csv` into `output/pages.csv` (adds `final_text`, `source`).

### Proofreading app and corrections (built Oct 24, 2026)
- Launch: `source("R/proofread.R"); run_proofread()` from the project root. Scan on the left (boxed-flags review image or clean crop), editable OCR draft on the right; filters by tier (default A and B), volume and status. Owner confirmed it runs fine in the browser (Oct 24); the auto-save and unsaved-changes badge were added afterward and tested only with `shiny::testServer()`.
- Saves to `data/corrections.csv` (committed): `page_id, status (edited|confirmed), corrected_text, saved_at`; one row per page, latest save wins, written via temp file and rename. Edits are auto-saved when leaving a page (pages only viewed are not recorded); a header badge shows unsaved changes and the browser warns before closing the tab with unsaved edits.
- `apply_corrections()` replaces the draft with the correction at page level; leftover `[?word]` marks stay. Not yet wired into DOCX, PDF or the book.
- Gotcha: the edit tool failed on multi-line matches in `proofread/app.R` (CRLF); patch such blocks with `readLines`/`writeLines` in R.

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

- Next likely steps: owner proofreads tier A/B pages in the app (starting with vol1; no further prerequisites), then DOCX and searchable PDF assembly from `apply_corrections()`, render the book.
- Ordering caveat: if vol2 is rerun with `deu`/`fra`, do it before the owner reviews vol2, because saved corrections replace the new OCR text for those pages. A `targets` pipeline is a convenience for the published book, not a prerequisite for review.
- `data/triage_overrides.csv` still not created.
- Rerun vol2 with `eng+deu+fra` once the language files are installed (owner has not yet confirmed installing them).
- Check vol1/vol3 first/last pages for front matter; decide which duplicate pages to drop (confirm against OCR text).
- Confirm WWII volume numbering (vol1.pdf/vol3.pdf).
- Hand-type ground-truth pages; tune psm, threshold, masking, languages; compare vision LLMs on tier A pages (front matter, two-column, faded ribbon).
- Decide `targets` (recommended) and `renv`; searchable PDF type; API keys in `.Renviron`; real repo URL; PDF engine (LaTeX or Typst).

## Style notes

- Base pipe `|>`, tidyverse, brief rationale-only comments.
- Pipeline runs via script/`targets`; the book reads cached outputs (`freeze: auto`) and never reruns OCR or API calls.

## Reproducibility pass (Oct 24, 2026)

Goal from owner: the book must contain all code so a rerun from the same PDFs gives the same result.
- `_targets.R` is now the single entry point (`targets::tar_make()`): config -> inventory (`run_inventory`) -> `ensure_languages` -> `run_ocr` -> `build_outputs(config, ocr_files)` -> `run_experiments` -> `final` (`apply_corrections`). `renv.lock` written with `renv::snapshot(packages=...)` (renv NOT activated; no .Rprofile).
- New/changed: `R/utils.R` (`parse_pages`), `R/experiments.R` (psm and preprocessing comparisons, replaced `explore_sample_ocr.R`), `build_outputs()` is now a function and reads forced-tier-A pages from the new `force_manual_pages` column in `volume_config.csv`; `ocr_page()` reuses a cache only if cached `langs` match the config; `run_ocr(config, ...)` returns cache paths and no longer falls back silently to fewer languages.
- Inventory is one file, `data/interim/page_inventory.csv` (regenerated, 3.7 min; ink values identical to before; duplicates 77/78 and 96/97 only; vol1 p102 vs vol3 p1 is mutual nearest at 0.165, just above the 0.15 cutoff). Old `page_inventory_vol1_vol3.csv` deleted.
- Verified: `build_outputs()` on the existing cache reproduces `output/*` byte for byte; re-cropping and re-OCRing vol1 p10, vol3 p60, vol2 p40 gives identical text, boxes, confidences (1e-14 float noise).
- Chapter 05 earlier numbers (psm 86.0/85.6/81.6, threshold 66 to 30, vol2 p40 640 vs 414 words) did NOT reproduce on the prepared pages; chapter now reads `data/interim/experiments/*.csv` (psm means 86.5/86.5/84.8; thresholding hurts vol2 p40, 93 to 33, not vol1 p10).
- `tar_make()` will stop at `languages` until `deu`/`fra` can be installed. From the assistant's session `tesseract_download()` downloads but cannot save (sandbox); it should work in the owner's console. After that, vol2 is re-OCR'd automatically (cached langs differ) and outputs/tiers for vol2 change; do this before the owner reviews vol2.
- Not yet verified: a full `tar_make()` end to end (languages blocked), PDF/DOCX book outputs. Sandbox note: never run tests that write the real `data/corrections.csv`.

## Session notes (Oct 24, 2026, end of day)

- Nothing is committed yet (git repo, many modified/untracked files incl. `_targets.R`, `renv.lock`, `R/*.R`, `proofread/`, `data/corrections.csv`, `_freeze/`). Committing is an open item.
- `data/corrections.csv` now holds the owner's real proofreading work. Never delete it or run tests that write it; use a copy or a different `pomeroy.root` option.
- Book chapters 01-05 were rewritten for reproducibility and render clean to HTML (`quarto render --to html`); PDF/DOCX not built, pages not viewed in a browser. `02-setup.qmd` has an unmeasured "about 30 minutes" full-run claim; update after a real `tar_make()`.
- `PLAN.md` was NOT updated for the reproducibility pass; `index.qmd` says 364 pages but the PDFs total 378 (unreconciled, owner's file, not edited).
- Ground rule from owner: drive the work and report; do not ask for analysis decisions.
- Extra gotchas: the edit tool fails on multi-line matches in CRLF files (`.gitignore`, `proofread/app.R`, `AGENTS.md`); do not call `python3` via bash (hangs); run R via `executeCode`, not `Rscript`; set `timeout` on long R calls.

### Next steps (priority order)
1. Owner runs `tesseract::tesseract_download("deu")` and `"fra"` in their console; then a full `targets::tar_make()` (re-OCRs vol2 automatically). Do this before the owner proofreads vol2.
2. Chapter 08 assembly: DOCX, searchable PDF, per-page CSV from `apply_corrections()`; wire into `_targets.R`; flip `eval: false` in chapters 09-11 to publish.
3. Add a checksum check script for output reproducibility.
4. Decide duplicates to drop and check vol1/vol3 front matter; confirm WWII volume numbering.
5. Ground-truth pages, tune psm/languages by character error rate; vision LLM comparison on tier A pages (confirm owner is OK sending images externally).
6. Create `triage_overrides.csv`, names/places dictionary, real `repo-url`, PDF engine choice, renv activation decision, update `PLAN.md`.
