# Plan: Pomeroy WWII Journals OCR Pipeline and Quarto Book

## Decisions so far

| Topic | Decision |
|---|---|
| Source | 3 typewritten PDFs: vol 1 = 174 pp, vol 2 = 102 pp, vol 3 = 88 pp (364 total) |
| PDFs | Local only, gitignored |
| Book | Pipeline, code, narrative, plus one transcription chapter per volume |
| Publishing | Public (GitHub Pages from `docs/`); author/subjects cleared by owner |
| Quality target | Near-verbatim: low-confidence words flagged and proofread |
| Structure | Page markers kept (`[p. N]`), no dated-entry parsing (can be added later) |
| Triage | Automatic quality scoring (tesseract confidence) with manual override CSV |
| Engines | tesseract + magick locally; vision LLM via ellmer (Gemini/Claude/OpenAI compared) for failed pages |
| Deliverables | DOCX, searchable PDF, per-page CSV (text, confidence, engine), side-by-side proofing view |

## Proposed layout

```text
pomeroy-ww2/
├── _quarto.yml
├── index.qmd
├── 01-overview.qmd            goals, source description, ethics/rights
├── 02-setup.qmd               packages, Tesseract install, API keys, renv
├── 03-extraction.qmd          PDF -> 300 DPI PNG
├── 04-triage.qmd              confidence scoring, override CSV
├── 05-ocr-local.qmd           tesseract + magick preprocessing
├── 06-ocr-llm-fallback.qmd    ellmer, prompts, model comparison, cost
├── 07-proofreading.qmd        low-confidence flags, side-by-side review
├── 08-assembly.qmd            DOCX, searchable PDF, CSV
├── 09-vol1.qmd  10-vol2.qmd  11-vol3.qmd   transcription chapters
├── references.qmd
├── R/                         reusable functions (extract, preprocess, ocr, assemble)
├── data/
│   ├── raw_pdf/               GITIGNORED: vol1.pdf, vol2.pdf, vol3.pdf
│   ├── pages/                 GITIGNORED: PNGs (vol1/, vol2/, vol3/)
│   ├── interim/               OCR results per page (RDS/CSV; commit CSV)
│   └── triage_overrides.csv   committed; manual decisions
├── output/                    DOCX, PDF, CSV downloads (committed)
└── docs/                      rendered book (un-ignored)
```

## Steps

1. **Repo setup.** Create the folders. Update `.gitignore` (add `data/raw_pdf/`, `data/pages/`, `*.pdf` under data; remove `docs/`). Fill in the README. Initialize `renv`.
2. **Environment check.** Confirm Tesseract and its `eng` language data are installed, and check the packages (pdftools, magick, tesseract, officer, ellmer, quarto, tidyverse). Set API keys in `.Renviron`.
3. **Extraction.** Convert each PDF to zero-padded 300 DPI PNGs, named `vol1_p001.png` and so on. Keep the PDF page number as the page ID.
4. **Baseline OCR.** Run tesseract on every page with `ocr_data()` to get word-level confidence. Typewriter text works best with `--psm 6` or 4, so test both on a sample.
5. **Triage.** Compute per-page mean confidence and the share of low-confidence words. Auto-label pages as clean, faded or failed. Apply the manual overrides from `triage_overrides.csv`.
6. **Enhanced OCR for faded pages.** Apply grayscale, contrast and threshold tuning, and deskew. Re-run OCR and keep the result only if confidence improves. Tune parameters on a hand-picked sample of pages and record the tuning in the book.
7. **LLM fallback.** Send only the pages that still fail to a vision model via ellmer. Compare 2-3 providers on about 10 pages with hand-typed ground truth, using character error rate. Pick the model by accuracy and cost, and cache responses so reruns don't re-bill. The blueprint's `gemini-1.5-flash` is probably retired, so choose a current model.
8. **Proofreading.** Flag words below a confidence threshold. Add a spell-check pass with a custom dictionary for names and places. Build a Quarto side-by-side view (page image next to text). Do the manual corrections in a committed corrections CSV so they can be replayed.
9. **Assembly.** Build one table of volume, page, text, engine and confidence. Insert `[p. N]` markers. Export per-volume and combined DOCX with officer, a searchable PDF (via Quarto/Typst or `pdftools`/`magick` with a text layer), and the CSV.
10. **Book and publish.** Render the transcription chapters from the CSV. Configure the HTML book to output to `docs/`, add download links, and enable GitHub Pages. Use `freeze: auto` so rendering doesn't rerun OCR. The pipeline should run through a script or `targets` and the book should only read cached outputs.

## Open items

- PDF file names and locations. Place them in `data/raw_pdf/` and we will confirm the details.
- Whether the PDFs already contain an embedded text layer.
- Tesseract installation status and which API keys exist.
- Whether to use `targets` for pipeline orchestration, which I recommend given 364 pages and cached LLM calls.
- Whether the searchable PDF should be the original scans with a text layer, or a typeset PDF of the transcription. These are different products and you may want both.
