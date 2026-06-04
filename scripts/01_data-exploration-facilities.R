# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets -------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
icis_files <- list.files(icis_dir, pattern = "\\.csv$", full.names = TRUE)
icis_data <- lapply(icis_files, read_csv)
names(icis_data) <- gsub("-", "_", tools::file_path_sans_ext(basename(icis_files)))
list2env(icis_data, envir = .GlobalEnv)

# ---- Output directory ------------------------------------------------------------------------------------

out_dir <- "output/exploratory_analysis/ICIS_AIR_FACILITIES"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -------------------------------------------------------------------------------

nrow(ICIS_AIR_FACILITIES)
n_distinct(ICIS_AIR_FACILITIES$REGISTRY_ID) # 265,490 - facility level
n_distinct(ICIS_AIR_FACILITIES$PGM_SYS_ID) # 279,211 - air source level

# Missingness by column
fac_missingness <- data.frame(
  variable = names(ICIS_AIR_FACILITIES),
  n_missing = colSums(is.na(ICIS_AIR_FACILITIES)),
  pct_missing = round(colSums(is.na(ICIS_AIR_FACILITIES)) / nrow(ICIS_AIR_FACILITIES) * 100, 2)
)
write_csv(fac_missingness, file.path(out_dir, "facilities_missingness.csv"))

# State distribution
state_dist <- ICIS_AIR_FACILITIES |>
  count(STATE, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(state_dist, file.path(out_dir, "facilities_by_state.csv"))

# Emissions classification
class_dist <- ICIS_AIR_FACILITIES |>
  count(AIR_POLLUTANT_CLASS_CODE, AIR_POLLUTANT_CLASS_DESC, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(class_dist, file.path(out_dir, "facilities_by_class.csv"))

# Operating status
status_dist <- ICIS_AIR_FACILITIES |>
  count(AIR_OPERATING_STATUS_CODE, AIR_OPERATING_STATUS_DESC, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(status_dist, file.path(out_dir, "facilities_by_status.csv"))

# HPV status
hpv_dist <- ICIS_AIR_FACILITIES |>
  count(CURRENT_HPV, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(hpv_dist, file.path(out_dir, "facilities_by_hpv.csv"))
