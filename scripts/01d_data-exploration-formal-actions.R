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

out_dir <- "output/exploratory_analysis/ICIS_AIR_FORMAL_ACTIONS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -----------------------------------------------------------------------------------

nrow(ICIS_AIR_FORMAL_ACTIONS)
n_distinct(ICIS_AIR_FORMAL_ACTIONS$PGM_SYS_ID)

# Missingness
fa_miss <- data.frame(
  variable = names(ICIS_AIR_FORMAL_ACTIONS),
  n_missing = colSums(is.na(ICIS_AIR_FORMAL_ACTIONS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_FORMAL_ACTIONS)) / nrow(ICIS_AIR_FORMAL_ACTIONS) * 100, 2)
)
write_csv(fa_miss, file.path(out_dir, "formal_actions_missingness.csv"))

# Action type distribution
fa_by_type <- ICIS_AIR_FORMAL_ACTIONS |>
  count(ACTIVITY_TYPE_CODE, ACTIVITY_TYPE_DESC, name = "n_actions") |>
  arrange(desc(n_actions))
write_csv(fa_by_type, file.path(out_dir, "formal_actions_by_type.csv"))

# State vs EPA
fa_by_agency <- ICIS_AIR_FORMAL_ACTIONS |>
  count(STATE_EPA_FLAG, name = "n_actions") |>
  arrange(desc(n_actions))
write_csv(fa_by_agency, file.path(out_dir, "formal_actions_by_agency.csv"))

# Penalty amount summary (non-missing, positive only)
fa_penalties <- ICIS_AIR_FORMAL_ACTIONS |>
  filter(!is.na(PENALTY_AMOUNT), PENALTY_AMOUNT > 0) |>
  summarise(
    n = n(),
    mean_penalty = round(mean(PENALTY_AMOUNT), 2),
    median_penalty = median(PENALTY_AMOUNT),
    p25 = quantile(PENALTY_AMOUNT, 0.25),
    p75 = quantile(PENALTY_AMOUNT, 0.75),
    max_penalty = max(PENALTY_AMOUNT)
  )
write_csv(fa_penalties, file.path(out_dir, "formal_actions_penalties.csv"))
