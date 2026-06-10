# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)
library(lubridate)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets -------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
icis_files <- list.files(icis_dir, pattern = "\\.csv$", full.names = TRUE)
icis_data <- lapply(icis_files, read_csv)
names(icis_data) <- gsub("-", "_", tools::file_path_sans_ext(basename(icis_files)))
list2env(icis_data, envir = .GlobalEnv)

# ---- Output directory ------------------------------------------------------------------------------------

out_dir <- "output/exploratory_analysis/ICIS_VIOLATION_HISTORY"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -------------------------------------------------------------------------------

nrow(ICIS_AIR_VIOLATION_HISTORY)
n_distinct(ICIS_AIR_VIOLATION_HISTORY$PGM_SYS_ID)

# Parse dates first
ICIS_AIR_VIOLATION_HISTORY <- ICIS_AIR_VIOLATION_HISTORY |>
  mutate(
    HPV_DAYZERO_DATE = mdy(HPV_DAYZERO_DATE),
    HPV_RESOLVED_DATE = mdy(HPV_RESOLVED_DATE),
    EARLIEST_FRV_DETERM_DATE = mdy(EARLIEST_FRV_DETERM_DATE),
    DSCV_PATHWAY_DATE = mdy(DSCV_PATHWAY_DATE),
    NFTC_PATHWAY_DATE = mdy(NFTC_PATHWAY_DATE)
  )

# Document bad dates (pre-1900 = data entry errors)
bad_dates <- ICIS_AIR_VIOLATION_HISTORY |>
  filter(if_any(where(is.Date), ~ !is.na(.) & . < as.Date("1900-01-01"))) |>
  select(PGM_SYS_ID, ACTIVITY_ID, HPV_DAYZERO_DATE, HPV_RESOLVED_DATE,
         EARLIEST_FRV_DETERM_DATE, DSCV_PATHWAY_DATE, NFTC_PATHWAY_DATE)
write_csv(bad_dates, file.path(out_dir, "violations_bad_dates.csv"))

# Clean — set bad dates to NA
ICIS_AIR_VIOLATION_HISTORY <- ICIS_AIR_VIOLATION_HISTORY |>
  mutate(across(where(is.Date), ~ if_else(. < as.Date("1900-01-01"), NA_Date_, .)))

# Missingness
vh_missingness <- data.frame(
  variable = names(ICIS_AIR_VIOLATION_HISTORY),
  n_missing = colSums(is.na(ICIS_AIR_VIOLATION_HISTORY)),
  pct_missing = round(colSums(is.na(ICIS_AIR_VIOLATION_HISTORY)) / nrow(ICIS_AIR_VIOLATION_HISTORY) * 100, 2)
)
write_csv(vh_missingness, file.path(out_dir, "violations_missingness.csv"))

# Date range
vh_date_range <- data.frame(
  date_field = c("HPV_DAYZERO_DATE", "HPV_RESOLVED_DATE", "EARLIEST_FRV_DETERM_DATE", "DSCV_PATHWAY_DATE"),
  earliest = c(min(ICIS_AIR_VIOLATION_HISTORY$HPV_DAYZERO_DATE, na.rm = TRUE),
               min(ICIS_AIR_VIOLATION_HISTORY$HPV_RESOLVED_DATE, na.rm = TRUE),
               min(ICIS_AIR_VIOLATION_HISTORY$EARLIEST_FRV_DETERM_DATE, na.rm = TRUE),
               min(ICIS_AIR_VIOLATION_HISTORY$DSCV_PATHWAY_DATE, na.rm = TRUE)),
  latest = c(max(ICIS_AIR_VIOLATION_HISTORY$HPV_DAYZERO_DATE, na.rm = TRUE),
             max(ICIS_AIR_VIOLATION_HISTORY$HPV_RESOLVED_DATE, na.rm = TRUE),
             max(ICIS_AIR_VIOLATION_HISTORY$EARLIEST_FRV_DETERM_DATE, na.rm = TRUE),
             max(ICIS_AIR_VIOLATION_HISTORY$DSCV_PATHWAY_DATE, na.rm = TRUE))
)
write_csv(vh_date_range, file.path(out_dir, "violations_date_range.csv"))

# Violations per year (by day-zero date)
vh_by_year <- ICIS_AIR_VIOLATION_HISTORY |>
  filter(!is.na(HPV_DAYZERO_DATE)) |>
  mutate(year = year(HPV_DAYZERO_DATE)) |>
  count(year, name = "n_violations") |>
  arrange(year)
write_csv(vh_by_year, file.path(out_dir, "violations_by_year.csv"))

# HPV vs FRV distribution
vh_by_type <- ICIS_AIR_VIOLATION_HISTORY |>
  count(ENF_RESPONSE_POLICY_CODE, name = "n_violations") |>
  arrange(desc(n_violations))
write_csv(vh_by_type, file.path(out_dir, "violations_by_type.csv"))

# Violations per facility
vh_per_facility <- ICIS_AIR_VIOLATION_HISTORY |>
  count(PGM_SYS_ID, name = "n_violations") |>
  summarise(
    n_facilities = n(),
    mean_violations = round(mean(n_violations), 2),
    median_violations = median(n_violations),
    max_violations = max(n_violations),
    pct_single = round(mean(n_violations == 1) * 100, 2)
  )
write_csv(vh_per_facility, file.path(out_dir, "violations_per_facility.csv"))

# Resolution time (days from day-zero to resolved, HPVs only)
vh_resolution <- ICIS_AIR_VIOLATION_HISTORY |>
  filter(!is.na(HPV_DAYZERO_DATE), !is.na(HPV_RESOLVED_DATE)) |>
  mutate(days_to_resolve = as.numeric(HPV_RESOLVED_DATE - HPV_DAYZERO_DATE)) |>
  summarise(
    n = n(),
    mean_days = round(mean(days_to_resolve), 1),
    median_days = median(days_to_resolve),
    p25 = quantile(days_to_resolve, 0.25),
    p75 = quantile(days_to_resolve, 0.75),
    max_days = max(days_to_resolve)
  )

# Pct unresolved (computed separately — denominator is all HPVs with a day-zero date)
vh_resolution$pct_unresolved <- round(
  sum(is.na(ICIS_AIR_VIOLATION_HISTORY$HPV_RESOLVED_DATE) & !is.na(ICIS_AIR_VIOLATION_HISTORY$HPV_DAYZERO_DATE)) /
  sum(!is.na(ICIS_AIR_VIOLATION_HISTORY$HPV_DAYZERO_DATE)) * 100, 2
)

write_csv(vh_resolution, file.path(out_dir, "violations_resolution_time.csv"))

# Agency distribution
vh_by_agency <- ICIS_AIR_VIOLATION_HISTORY |>
  count(AGENCY_TYPE_DESC, name = "n_violations") |>
  arrange(desc(n_violations))
write_csv(vh_by_agency, file.path(out_dir, "violations_by_agency.csv"))
