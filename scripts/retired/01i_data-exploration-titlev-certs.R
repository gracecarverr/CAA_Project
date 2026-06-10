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

out_dir <- "output/exploratory_analysis/ICIS_AIR_TITLEV_CERTS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -----------------------------------------------------------------------------------

nrow(ICIS_AIR_TITLEV_CERTS)
n_distinct(ICIS_AIR_TITLEV_CERTS$PGM_SYS_ID)

# Missingness
tv_miss <- data.frame(
  variable = names(ICIS_AIR_TITLEV_CERTS),
  n_missing = colSums(is.na(ICIS_AIR_TITLEV_CERTS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_TITLEV_CERTS)) / nrow(ICIS_AIR_TITLEV_CERTS) * 100, 2)
)
write_csv(tv_miss, file.path(out_dir, "titlev_missingness.csv"))

# Deviation flag distribution
tv_by_deviation <- ICIS_AIR_TITLEV_CERTS |>
  count(FACILITY_RPT_DEVIATION_FLAG, name = "n_certs") |>
  arrange(desc(n_certs))
write_csv(tv_by_deviation, file.path(out_dir, "titlev_by_deviation.csv"))

# State vs EPA
tv_by_agency <- ICIS_AIR_TITLEV_CERTS |>
  count(STATE_EPA_FLAG, name = "n_certs") |>
  arrange(desc(n_certs))
write_csv(tv_by_agency, file.path(out_dir, "titlev_by_agency.csv"))
