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

out_dir <- "output/exploratory_analysis/ICIS_AIR_PROGRAM_SUBPARTS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -----------------------------------------------------------------------------------

nrow(ICIS_AIR_PROGRAM_SUBPARTS)
n_distinct(ICIS_AIR_PROGRAM_SUBPARTS$PGM_SYS_ID)

# Missingness
sub_miss <- data.frame(
  variable = names(ICIS_AIR_PROGRAM_SUBPARTS),
  n_missing = colSums(is.na(ICIS_AIR_PROGRAM_SUBPARTS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_PROGRAM_SUBPARTS)) / nrow(ICIS_AIR_PROGRAM_SUBPARTS) * 100, 2)
)
write_csv(sub_miss, file.path(out_dir, "subparts_missingness.csv"))

# Most common subparts
sub_by_type <- ICIS_AIR_PROGRAM_SUBPARTS |>
  count(AIR_PROGRAM_SUBPART_CODE, AIR_PROGRAM_SUBPART_DESC, name = "n_records") |>
  arrange(desc(n_records))
write_csv(sub_by_type, file.path(out_dir, "subparts_by_type.csv"))
