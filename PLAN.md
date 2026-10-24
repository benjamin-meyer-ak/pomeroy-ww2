# Plan: Pomeroy Journals OCR Pipeline and Quarto Book

Single planning document. It replaces `rstudio_ocr_workflow_blueprint.md` (v1) and `updated_ocr_workflow_blueprint.md` (v2, written from the 1966 sample only). Last updated Oct 23, 2026.

## 1. Decisions (from interview)

| Topic | Decision |
|---|---|
| Source | 3 typewritten PDFs, kept local only (gitignored). Page counts and volume mapping: see section 2 |
| Book | Methods chapters plus one transcription chapter per volume; pipeline, code and narrative |
| Publishing | Public GitHub Pages from `docs/`; author and subjects cleared by owner |
| Quality target | Near-verbatim; low-confidence words flagged and proofread. The text is never silently "corrected" |
| Structure | Keep `[p. N]` page markers; no dated-entry parsing for now (headings as an optional later layer) |
| Triage | Automatic scoring with manual overrides in `data/triage_overrides.csv` |
| Engines | tesseract + magick locally; vision LLM via ellmer for failed pages and front matter; compare providers on hand-typed pages (character error rate, cost) |
| Deliverables | DOCX, searchable PDF, per-page CSV (text, confidence, engine), side-by-side proofreading view |
| Page IDs | `vol1_p001` style, 300 DPI |

## 2. What the scans actually are (measured Oct 23, 2026)

| File | Pages | Layout | Notes |
|---|---|---|---|
| `vol1.pdf` | 102 | 98 landscape spreads + 4 portrait | Book-photocopy spreads: one text page plus a mostly blank facing page, dark binding shadow, some handwritten annotations. Last page (p102) appears to repeat `vol3.pdf` p1 |
| `vol2.pdf` | 188 | all portrait | The 1966 Europe travel journal (per the v2 analysis): clean loose pages, 3-hole punch marks on some, 3-page table of contents with dotted leaders, itinerary and mail schedule up front |
| `vol3.pdf` | 88 | 88 landscape spreads | Same spread pattern as vol1; p87-88 are dark, two-column newsletter pages |

- No embedded text layer anywhere; full OCR needed.
- Page counts you gave (174 / 102 / 88 = 364) vs measured (102 / 188 / 88 = 378): the 174-page journal is probably `vol2.pdf` (1966 journal: 174 entries pages plus about 14 front-matter pages), and the 102-page volume is `vol1.pdf`. This explains the 14-page difference but is unconfirmed.
- **Confirmed by owner (Oct 23, 2026):** `vol2.pdf` is the 1966 Europe journal and is a **separate document**, not one of the WWII volumes. It gets its own end-to-end run to its own DOCX (and PDF/CSV), with its own entry in `volume_config.csv`. How it appears in the book (separate part or chapter) is still to be decided. `vol1.pdf` and `vol3.pdf` are the WWII material; their volume numbering and the vol1 p102 / vol3 p1 overlap are still to be confirmed.
- Exploration code is saved in `R/explore_sample_ocr.R` and `R/explore_inventory.R`. Sample PNGs and contact sheets are in `data/pages/` (local, gitignored). The inventory step was not finished.

## 3. Review of the v2 (1966-sample) blueprint

v2 was derived from `vol2.pdf` alone, so it has no knowledge of the spread scans in vol1 and vol3. I assessed each element against the sample experiments.

### Adopted

- **Front matter via vision LLM.** Our test agrees: the TOC page scored about 27% mean confidence in every tesseract mode. Route TOC, itinerary and mail schedule to an LLM that returns Markdown tables.
- **Header and page-number handling.** Strip running headers (`- 6 -`) from the body text but keep the number in the CSV; the `[p. N]` markers come from the PDF page ID.
- **Margin masking.** Binder-hole and edge artifacts do pollute OCR. Adapted: per-volume settings, detected rather than a fixed 150 px, and spreads get cropped to the text half (see below).
- **Multilingual OCR (`eng+deu+fra`).** The text has German, French and Dutch names. Adopted as an experiment, because extra languages can reduce English accuracy. Needs `deu`/`fra` data downloaded.
- **Two degradation profiles (faint vs over-inked).** Plausible and worth separate enhancement paths, but untested on our pages. Adopted as hypotheses to confirm on samples, not as fixed rules.
- **Larger local-threshold window.** A `10x10` window at 300 DPI is very small relative to typewriter strokes, so the v1 setting is likely poor. Adopted: test windows from about 25 to 45 px and pick by error rate.
- **Automated triage using pixel statistics.** Adopted as an extra feature next to tesseract confidence. The v2 cutoffs (`sd < 38`, `mean < 220 & sd > 55`) are untested guesses and will be calibrated on labelled pages.
- **Structured DOCX.** Title page, headings, readable body style, paragraphs that continue across page breaks.
- **Speaker labels, typist initials and date banners** (Dick, Walt, Kay, `RWP/sg`): kept as optional markup, driven by a per-volume config file, not hard-coded regexes.
- **`cli` progress messages, modular scripts.** Folded into `R/` functions.

### Rejected or changed

| v2 element | Why not |
|---|---|
| PSM 6 as default | On our 10-page sample, mean confidence was psm 3 = 86.0, psm 4 = 85.6, psm 6 = 81.6, and psm 6 merged the columns on the two-column page. But on `vol2_p040` psm 6 returned about 640 words versus about 414 for psm 3/4, so confidence alone is misleading (psm 3/4 may drop text). The choice will be made on character error rate against hand-typed ground truth, per layout type |
| Regex "corrections" (`Ku-Dam` to `Kurfürstendamm`, `Funf` to `Fünf`) | Violates the near-verbatim goal. Use a corrections CSV with an audit trail instead |
| Blind de-hyphenation (`word-\nword` to `wordword`) | Joins real compounds ("pre-war"). Only join when the joined form is in a dictionary, otherwise flag it |
| Broad date regex (any line with "Germany", "Paris", ...) | Over-matches body text. Defer entry parsing; add a tighter parser later if wanted |
| `gemini-1.5-flash` | Probably retired. Choose the model from the provider comparison |
| Copying images into triage folders | Duplicates large files. Triage is a manifest CSV; images stay in one place |
| Hard-coded front matter = pages 1-6 | Front matter is per-volume config (vol2 has more than 6 pages of it: about 188 vs 174) |
| `page_%03d.png`, `%>%`, flat `scripts/` | Use `vol1_p001.png`, base pipe, `R/` functions plus a `targets` pipeline |
| Fixed 150 px left mask | Does not fit spreads, where the shadow is a different shape and the text page can be on either side |

### New items the v2 blueprint missed

- **Spread handling.** For vol1 and vol3, detect which half holds the text (ink density), crop to it, and trim the binding shadow before OCR. Keep a manifest of crop boxes. Do not split every spread blindly in half.
- **Two-column pages** (vol3 p87-88): need column-aware segmentation or LLM transcription.
- **Handwritten annotations** (vol1 p1 and others): keep out of the typed text, flag in the CSV, and transcribe in brackets via the LLM path where wanted.
- **Overlap between volumes** (vol1 p102 vs vol3 p1): detect duplicate pages by text similarity and decide which copy is canonical.

## 4. Layout

```text
pomeroy-ww2/
├── _quarto.yml, index.qmd, 01-overview ... 08-assembly, 09-vol1, 10-vol2, 11-vol3, references
├── R/                          extract, crop_spread, enhance, ocr, triage, llm, clean, assemble
├── _targets.R                  pipeline (book reads cached outputs only)
├── data/
│   ├── raw_pdf/                GITIGNORED: vol1.pdf, vol2.pdf, vol3.pdf
│   ├── pages/                  GITIGNORED: PNGs and sample/thumbs
│   ├── interim/                per-page OCR results (commit CSV)
│   ├── volume_config.csv       per-volume: layout, front-matter pages, languages, speakers
│   ├── ground_truth/           hand-typed reference pages
│   ├── triage_overrides.csv    manual decisions
│   └── corrections.csv         manual text fixes, replayed on rebuild
├── output/                     DOCX, PDF, CSV downloads (committed)
└── docs/                       rendered book
```

## 5. Steps

Status: steps 1-2 done, step 3 partly done (sample only).

1. **Repo setup** (done). Folders, `.gitignore` (scans ignored, `docs/` tracked), Quarto scaffold.
2. **Environment** (done). Packages installed, Tesseract works (`eng`, `osd`). Still to do: `deu`/`fra` language data, API keys in `.Renviron`, `renv`.
3. **Inventory and mapping.** Confirm which file is which volume and the scope question; list page sizes and blank pages; find overlap pages; write `volume_config.csv`.
4. **Extraction.** 300 DPI PNGs named `vol1_p001.png`. For spreads, add the crop step with a crop manifest.
5. **Ground truth.** Hand-type about 10 pages covering each layout: clean portrait, spread, faded, over-inked, two-column, front matter. This is the yardstick for every choice below.
6. **Tuning experiments** (each scored by character error rate on ground truth, plus confidence as a secondary signal): PSM 3/4/6 per layout, threshold window size, contrast/gamma path for faded vs over-inked pages, `eng` vs `eng+deu+fra`, margin masking on or off.
7. **Triage.** Features: tesseract confidence, share of low-confidence words, pixel luminance and contrast. Assign each page to a treatment path and write a manifest; manual overrides win.
8. **Full local OCR** with the chosen settings, saving word-level data. Re-run enhanced OCR only on pages that triage flags, and keep the result only if it scores better.
9. **LLM transcription.** Front matter, two-column pages and pages that still fail. Compare 2-3 providers on the ground-truth pages (error rate and cost), cache every response so reruns don't re-bill.
10. **Cleaning.** Strip headers, handle hyphenation conservatively, flag (do not rewrite) suspect words, add `[p. N]` markers, build the corrections CSV workflow, optional spell-check with a names/places dictionary.
11. **Proofreading view.** Quarto page: image beside text, low-confidence words highlighted.
12. **Assembly.** One table of volume, page, text, engine, confidence. Export per-volume and combined DOCX (officer, styled headings, title page), searchable PDF, CSV.
13. **Book and publish.** Render transcription chapters from the CSV, `freeze: auto`, download links, GitHub Pages from `docs/`, real `repo-url`.

## 6. Open items

- Confirm the WWII volume numbering for `vol1.pdf` / `vol3.pdf`, and how the separate 1966 journal is presented in the book (section 2).
- Searchable PDF: original scans with a text layer, a typeset transcription, or both.
- Use `targets` for orchestration (recommended: 378 pages, cached LLM calls) and `renv`.
- Real repo URL; PDF render engine (LaTeX or Typst).
- Which LLM providers and keys to use for the comparison.
