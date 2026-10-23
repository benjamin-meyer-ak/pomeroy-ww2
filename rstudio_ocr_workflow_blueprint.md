# RStudio OCR Workflow: Mixed-Quality PDF Pipeline

**Project Goal:** Convert a ~100-page PDF with mixed text quality (clear and faded) into a single, continuous, searchable/editable DOCX file using an R-native toolchain.

**Primary Strategy:** Fully local processing utilizing `tesseract` (OCR) and `magick` (Image Enhancement).
**Fallback Strategy:** Gemini API via `ellmer` for pages that fail local OCR.

---

## 1. Project Setup and Directory Structure

Initialize a new RStudio Project and create the following directory structure to support manual triage:

```text
pdf_ocr_project/
├── raw_pdf/         # Place the original 100-page PDF here
├── pages_all/       # Extracted PNGs of all pages
├── triage_clean/    # Manually move clear, legible PNGs here
├── triage_faded/    # Manually move degraded, faded PNGs here
├── output/          # Final compiled .docx and log files
└── scripts/         # R scripts
```

**Required Packages:**
Have Posit Assistant generate a script to install and load these:
`install.packages(c("pdftools", "magick", "tesseract", "officer", "fs", "purrr", "stringr"))`

---

## 2. Phase 1: PDF Extraction & Manual Triage

Since you will be making manual decisions on page quality, the first step is strictly extraction.

**Posit Assistant Prompt / Goal:** 
Write a script using `pdftools::pdf_convert()` to read the PDF in `raw_pdf/` and convert every page into a 300 DPI PNG file, saving them all into the `pages_all/` directory. Ensure files are padded with zeros (e.g., `page_001.png`, `page_010.png`) so they stay in order.

**Manual Action:** 
Once the script runs, open your file explorer. Review the images in `pages_all/` and drag-and-drop them into either the `triage_clean/` or `triage_faded/` folders based on your visual assessment.

---

## 3. Phase 2: Fully Local OCR Processing

We will process the two folders differently, then combine the text.

### Path A: Processing `triage_clean/`
**Posit Assistant Prompt / Goal:**
Write a function that iterates through all PNGs in `triage_clean/`. Pass each image directly to `tesseract::ocr()`. Save the output strings into a named list or dataframe, keeping track of the original page number from the filename.

### Path B: Processing `triage_faded/`
**Posit Assistant Prompt / Goal:**
Write a function for the images in `triage_faded/`. Before running OCR, use the `magick` package to enhance the image. The pre-processing pipeline should include:
1. `image_convert(colorspace = 'gray')`
2. `image_lat(geometry = '10x10+5%')` (Local Adaptive Thresholding - *Note: Posit Assistant can help tune these numbers if output is too dark/light*)
3. `image_deskew()`
Pass the enhanced image into `tesseract::ocr()`. Save the text output and the page number.

---

## 4. Phase 3: Assembly & DOCX Export

Because continuous flowing text is acceptable, we don't need to worry about inserting manual page breaks.

**Posit Assistant Prompt / Goal:**
Combine the text outputs from Path A and Path B. Sort the combined text data chronologically based on the original page numbers extracted from the filenames. Finally, use the `officer` package to create a new DOCX file, add the sorted text blocks sequentially as paragraphs, and save it to the `output/` directory.

---

## 5. API Fallback Plan (If Local OCR Fails on Faded Pages)

If `tesseract` returns gibberish for heavily degraded pages even after `magick` enhancement, you can use the Gemini API. 

**How to get access using your current account:**
1. Go to [Google AI Studio](https://aistudio.google.com).
2. Sign in with the Google account you are currently using.
3. Click **"Get API key"** in the left menu and create a new key.
4. In RStudio, run `usethis::edit_r_environ()` and add: `GEMINI_API_KEY="your_copied_key"`

**Posit Assistant Prompt for Fallback:**
"Switch the faded page processing to use the `ellmer` package. Write a function that takes a degraded image, encodes it, and sends it to `chat_gemini(model = 'gemini-1.5-flash')` with the prompt: *'Transcribe the text in this image exactly as written. Use surrounding sentence context to infer heavily faded words. Bracket any [uncertain words] you cannot confidently read. Output only the text.'* Replace the tesseract output with this API output."