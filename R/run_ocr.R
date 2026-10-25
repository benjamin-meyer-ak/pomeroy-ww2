# Run the page pipeline (prepare_page + ocr_page) for whole volumes in parallel.
# Results are cached per page, so a rerun only processes pages that are missing
# or were made with different languages (force = TRUE redoes everything).
# About 2.6 s/page with 6 workers. Returns the paths of all cached results.
source("R/ocr_pipeline.R")
library(parallel)

run_ocr <- function(config, pdf_files = NULL, workers = 6, force = FALSE) {
  jobs <- map(config$volume_id, \(v) {
    # Languages come straight from the config; ensure_languages() has installed them
    page_ids(v) |> mutate(langs = filter(config, volume_id == v)$ocr_langs)
  }) |> list_rbind()

  cl <- makeCluster(workers)
  on.exit(stopCluster(cl))
  clusterEvalQ(cl, source("R/ocr_pipeline.R"))
  parLapplyLB(cl, seq_len(nrow(jobs)), \(i, jobs, force) {
    ocr_page(jobs$volume_id[i], jobs$page[i], langs = jobs$langs[i], force = force)
  }, jobs = jobs, force = force) |>
    invisible()
  file.path("data/interim/ocr", paste0(jobs$page_id, ".rds"))
}
