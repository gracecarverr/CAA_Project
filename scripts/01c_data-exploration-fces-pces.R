# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)
library(lubridate)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets ---------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
icis_files <- list.files(icis_dir, pattern = "\\.csv$", full.names = TRUE)
icis_data <- lapply(icis_files, read_csv)
names(icis_data) <- gsub("-", "_", tools::file_path_sans_ext(basename(icis_files)))
list2env(icis_data, envir = .GlobalEnv)

# ---- Output directory ------------------------------------------------------------------------------------

out_dir <- "output/exploratory_analysis/ICIS_AIR_FCES_PCES"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -----------------------------------------------------------------------------------

nrow(ICIS_AIR_FCES_PCES)
n_distinct(ICIS_AIR_FCES_PCES$PGM_SYS_ID)

# Missingness
fce_miss <- data.frame(
  variable = names(ICIS_AIR_FCES_PCES),
  n_missing = colSums(is.na(ICIS_AIR_FCES_PCES)),
  pct_missing = round(colSums(is.na(ICIS_AIR_FCES_PCES)) / nrow(ICIS_AIR_FCES_PCES) * 100, 2)
)
write_csv(fce_miss, file.path(out_dir, "fces_pces_missingness.csv"))

# FCE vs PCE split
fce_by_type <- ICIS_AIR_FCES_PCES |>
  count(COMP_MONITOR_TYPE_CODE, COMP_MONITOR_TYPE_DESC, name = "n_records") |>
  arrange(desc(n_records))
write_csv(fce_by_type, file.path(out_dir, "fces_pces_by_type.csv"))

# State vs EPA
fce_by_agency <- ICIS_AIR_FCES_PCES |>
  count(STATE_EPA_FLAG, name = "n_records") |>
  arrange(desc(n_records))
write_csv(fce_by_agency, file.path(out_dir, "fces_pces_by_agency.csv"))

# Parse dates
ICIS_AIR_FCES_PCES <- ICIS_AIR_FCES_PCES |>
  mutate(ACTUAL_END_DATE = mdy(ACTUAL_END_DATE))

# Document and clean bad dates (pre-1900 = data entry errors), take a look at other suspiciously early dates
fce_bad_dates <- ICIS_AIR_FCES_PCES |>
  filter(year(ACTUAL_END_DATE) < 1900)
write_csv(fce_bad_dates, file.path(out_dir, "fces_pces_bad_dates.csv"))

ICIS_AIR_FCES_PCES <- ICIS_AIR_FCES_PCES |>
  mutate(ACTUAL_END_DATE = if_else(year(ACTUAL_END_DATE) < 1900, NA_Date_, ACTUAL_END_DATE))

# Inspections per year
fce_by_year <- ICIS_AIR_FCES_PCES |>
  filter(!is.na(ACTUAL_END_DATE)) |>
  mutate(year = year(ACTUAL_END_DATE)) |>
  count(year, name = "n_inspections") |>
  arrange(year)
write_csv(fce_by_year, file.path(out_dir, "fces_pces_by_year.csv"))
