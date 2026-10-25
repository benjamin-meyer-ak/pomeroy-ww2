# Small helpers shared by several steps.
library(tidyverse)

# "1;44-46" -> c(1, 44, 45, 46). Page lists in volume_config.csv use this form.
parse_pages <- function(x) {
  if (is.na(x)) return(integer())
  str_split_1(x, ";") |>
    map(\(s) { r <- as.integer(str_split_1(s, "-")); seq(r[1], r[length(r)]) }) |>
    unlist()
}
