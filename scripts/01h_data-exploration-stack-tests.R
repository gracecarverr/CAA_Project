# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets ---------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
icis_files <- list.files(icis_dir, pattern = "\\.csv$", full.names = TRUE)
icis_data <- lapply(icis_files, read_csv)
names(icis_data) <- gsub("-", "_", tools::file_path_sans_ext(basename(icis_files)))
list2env(icis_data, envir = .GlobalEnv)

# ---- Output directory ------------------------------------------------------------------------------------

out_dir <- "output/exploratory_analysis/ICIS_AIR_STACK_TESTS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -----------------------------------------------------------------------------------

nrow(ICIS_AIR_STACK_TESTS)
n_distinct(ICIS_AIR_STACK_TESTS$PGM_SYS_ID)

# Missingness
st_miss <- data.frame(
  variable = names(ICIS_AIR_STACK_TESTS),
  n_missing = colSums(is.na(ICIS_AIR_STACK_TESTS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_STACK_TESTS)) / nrow(ICIS_AIR_STACK_TESTS) * 100, 2)
)
write_csv(st_miss, file.path(out_dir, "stack_tests_missingness.csv"))

# Pass/fail distribution
st_by_result <- ICIS_AIR_STACK_TESTS |>
  count(AIR_STACK_TEST_STATUS_CODE, AIR_STACK_TEST_STATUS_DESC, name = "n_tests") |>
  arrange(desc(n_tests))
write_csv(st_by_result, file.path(out_dir, "stack_tests_by_result.csv"))

# State vs EPA
st_by_agency <- ICIS_AIR_STACK_TESTS |>
  count(STATE_EPA_FLAG, name = "n_tests") |>
  arrange(desc(n_tests))
write_csv(st_by_agency, file.path(out_dir, "stack_tests_by_agency.csv"))
