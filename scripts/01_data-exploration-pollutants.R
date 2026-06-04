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

out_dir <- "output/exploratory_analysis/ICIS_AIR_POLLUTANTS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -------------------------------------------------------------------------------

names(ICIS_AIR_POLLUTANTS)

# Missingness
poll_missingness <- data.frame(
  variable = names(ICIS_AIR_POLLUTANTS),
  n_missing = colSums(is.na(ICIS_AIR_POLLUTANTS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_POLLUTANTS)) / nrow(ICIS_AIR_POLLUTANTS) * 100, 2)
)
write_csv(poll_missingness, file.path(out_dir, "pollutants_missingness.csv"))

# Most common pollutants across facilities
poll_by_frequency <- ICIS_AIR_POLLUTANTS |>
  count(POLLUTANT_CODE, POLLUTANT_DESC, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(poll_by_frequency, file.path(out_dir, "pollutants_by_frequency.csv"))

# Pollutants per facility
poll_per_facility <- ICIS_AIR_POLLUTANTS |>
  count(PGM_SYS_ID, name = "n_pollutants") |>
  summarise(
    n_facilities = n(),
    mean_pollutants = round(mean(n_pollutants), 2),
    median_pollutants = median(n_pollutants),
    max_pollutants = max(n_pollutants),
    pct_single = round(mean(n_pollutants == 1) * 100, 2)
  )
write_csv(poll_per_facility, file.path(out_dir, "pollutants_per_facility.csv"))

# Emissions classification distribution
poll_by_class <- ICIS_AIR_POLLUTANTS |>
  count(AIR_POLLUTANT_CLASS_CODE, AIR_POLLUTANT_CLASS_DESC, name = "n_records") |>
  arrange(desc(n_records))
write_csv(poll_by_class, file.path(out_dir, "pollutants_by_class.csv"))

# CAS number coverage (useful for linking to health/tox data)
poll_cas <- ICIS_AIR_POLLUTANTS |>
  summarise(
    n_total = n(),
    n_with_cas = sum(!is.na(CHEMICAL_ABSTRACT_SERVICE_NMBR)),
    pct_with_cas = round(mean(!is.na(CHEMICAL_ABSTRACT_SERVICE_NMBR)) * 100, 2)
  )
write_csv(poll_cas, file.path(out_dir, "pollutants_cas_coverage.csv"))
