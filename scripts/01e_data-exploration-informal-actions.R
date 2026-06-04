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

out_dir <- "output/exploratory_analysis/ICIS_AIR_INFORMAL_ACTIONS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -----------------------------------------------------------------------------------

nrow(ICIS_AIR_INFORMAL_ACTIONS)
n_distinct(ICIS_AIR_INFORMAL_ACTIONS$PGM_SYS_ID)

# Missingness
ia_miss <- data.frame(
  variable = names(ICIS_AIR_INFORMAL_ACTIONS),
  n_missing = colSums(is.na(ICIS_AIR_INFORMAL_ACTIONS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_INFORMAL_ACTIONS)) / nrow(ICIS_AIR_INFORMAL_ACTIONS) * 100, 2)
)
write_csv(ia_miss, file.path(out_dir, "informal_actions_missingness.csv"))

# Action type distribution
ia_by_type <- ICIS_AIR_INFORMAL_ACTIONS |>
  count(ACTIVITY_TYPE_CODE, ACTIVITY_TYPE_DESC, name = "n_actions") |>
  arrange(desc(n_actions))
write_csv(ia_by_type, file.path(out_dir, "informal_actions_by_type.csv"))

# State vs EPA
ia_by_agency <- ICIS_AIR_INFORMAL_ACTIONS |>
  count(STATE_EPA_FLAG, name = "n_actions") |>
  arrange(desc(n_actions))
write_csv(ia_by_agency, file.path(out_dir, "informal_actions_by_agency.csv"))
