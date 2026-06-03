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

# ---- Begin exploration -------------------------------------------------------------------------------

names(ICIS_AIR_FACILITIES)
names(ICIS_AIR_FCES_PCES)
names(ICIS_AIR_FORMAL_ACTIONS)
names(ICIS_AIR_INFORMAL_ACTIONS)
names(ICIS_AIR_POLLUTANTS)
names(ICIS_AIR_PROGRAM_SUBPARTS)
names(ICIS_AIR_PROGRAMS)
names(ICIS_AIR_STACK_TESTS)
names(ICIS_AIR_TITLEV_CERTS)
names(ICIS_AIR_VIOLATION_HISTORY)

# ---- ICIS_AIR_FACILITIES -------------------------------------------------------------------------------

# Missingness by column
missingness <- data.frame(
  variable = names(ICIS_AIR_FACILITIES),
  n_missing = colSums(is.na(ICIS_AIR_FACILITIES)),
  pct_missing = round(colSums(is.na(ICIS_AIR_FACILITIES)) / nrow(ICIS_AIR_FACILITIES) * 100, 2)
)
write_csv(missingness, "output/exploratory_analysis/facilities_missingness.csv")

# State distribution
state_dist <- ICIS_AIR_FACILITIES |>
  count(STATE, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(state_dist, "output/exploratory_analysis/facilities_by_state.csv")

# Emissions classification
class_dist <- ICIS_AIR_FACILITIES |>
  count(AIR_POLLUTANT_CLASS_CODE, AIR_POLLUTANT_CLASS_DESC, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(class_dist, "output/exploratory_analysis/facilities_by_class.csv")

# Operating status
status_dist <- ICIS_AIR_FACILITIES |>
  count(AIR_OPERATING_STATUS_CODE, AIR_OPERATING_STATUS_DESC, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(status_dist, "output/exploratory_analysis/facilities_by_status.csv")

# HPV status
hpv_dist <- ICIS_AIR_FACILITIES |>
  count(CURRENT_HPV, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(hpv_dist, "output/exploratory_analysis/facilities_by_hpv.csv")

# Air Pollutant Class Code

pollutant_dist <- ICIS_AIR_FACILITIES |> 
    count(AIR_POLLUTANT_CLASS_CODE, name = "n_facilities") |>
    arrange(desc(n_facilities))
write_csv(pollutant_dist, "output/exploratory_analysis/facilities_by_pollutant.csv")

# ---- ICIS_VIOLATION_HISTORY -------------------------------------------------------------------------------

# Find and document bad dates, then turn into NAs for now (only 4 obs)

# Document bad dates

bad_dates <- ICIS_AIR_VIOLATION_HISTORY |>
  filter(if_any(where(is.Date), ~ . < as.Date("1970-01-01"))) |>
  select(PGM_SYS_ID, ACTIVITY_ID, HPV_DAYZERO_DATE, HPV_RESOLVED_DATE,
         EARLIEST_FRV_DETERM_DATE, DSCV_PATHWAY_DATE, NFTC_PATHWAY_DATE)
write_csv(bad_dates, "output/exploratory_analysis/violations_bad_dates.csv")

# Clean
ICIS_AIR_VIOLATION_HISTORY <- ICIS_AIR_VIOLATION_HISTORY |>
  mutate(across(where(is.Date), ~ if_else(. < as.Date("1970-01-01"), NA_Date_, .)))

# Adjust date formatting

ICIS_AIR_VIOLATION_HISTORY <- ICIS_AIR_VIOLATION_HISTORY |>
  mutate(
    HPV_DAYZERO_DATE = mdy(HPV_DAYZERO_DATE),
    HPV_RESOLVED_DATE = mdy(HPV_RESOLVED_DATE),
    EARLIEST_FRV_DETERM_DATE = mdy(EARLIEST_FRV_DETERM_DATE),
    DSCV_PATHWAY_DATE = mdy(DSCV_PATHWAY_DATE),
    NFTC_PATHWAY_DATE = mdy(NFTC_PATHWAY_DATE)
  )

# Missingness
vh_missingness <- data.frame(
  variable = names(ICIS_AIR_VIOLATION_HISTORY),
  n_missing = colSums(is.na(ICIS_AIR_VIOLATION_HISTORY)),
  pct_missing = round(colSums(is.na(ICIS_AIR_VIOLATION_HISTORY)) / nrow(ICIS_AIR_VIOLATION_HISTORY) * 100, 2)
)
write_csv(vh_missingness, "output/exploratory_analysis/violations_missingness.csv")

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
write_csv(vh_date_range, "output/exploratory_analysis/violations_date_range.csv")

# Violations per year (by day-zero date)
vh_by_year <- ICIS_AIR_VIOLATION_HISTORY |>
  filter(!is.na(HPV_DAYZERO_DATE)) |>
  mutate(year = year(HPV_DAYZERO_DATE)) |>
  count(year, name = "n_violations") |>
  arrange(year)
write_csv(vh_by_year, "output/exploratory_analysis/violations_by_year.csv")

# HPV vs FRV distribution
vh_by_type <- ICIS_AIR_VIOLATION_HISTORY |>
  count(ENF_RESPONSE_POLICY_CODE, name = "n_violations") |>
  arrange(desc(n_violations))
write_csv(vh_by_type, "output/exploratory_analysis/violations_by_type.csv")

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
write_csv(vh_per_facility, "output/exploratory_analysis/violations_per_facility.csv")

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
    max_days = max(days_to_resolve),
    pct_unresolved = round(
      sum(is.na(ICIS_AIR_VIOLATION_HISTORY$HPV_RESOLVED_DATE) & !is.na(ICIS_AIR_VIOLATION_HISTORY$HPV_DAYZERO_DATE)) /
      sum(!is.na(ICIS_AIR_VIOLATION_HISTORY$HPV_DAYZERO_DATE)) * 100, 2
    )
  )
write_csv(vh_resolution, "output/exploratory_analysis/violations_resolution_time.csv")

# Agency distribution
vh_by_agency <- ICIS_AIR_VIOLATION_HISTORY |>
  count(AGENCY_TYPE_DESC, name = "n_violations") |>
  arrange(desc(n_violations))
write_csv(vh_by_agency, "output/exploratory_analysis/violations_by_agency.csv")

# ---- ICIS_AIR_POLLUTANTS -------------------------------------------------------------------------------

names(ICIS_AIR_POLLUTANTS)

# Missingness
poll_missingness <- data.frame(
  variable = names(ICIS_AIR_POLLUTANTS),
  n_missing = colSums(is.na(ICIS_AIR_POLLUTANTS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_POLLUTANTS)) / nrow(ICIS_AIR_POLLUTANTS) * 100, 2)
)
write_csv(poll_missingness, "output/exploratory_analysis/pollutants_missingness.csv")

# Most common pollutants across facilities
poll_by_frequency <- ICIS_AIR_POLLUTANTS |>
  count(POLLUTANT_CODE, POLLUTANT_DESC, name = "n_facilities") |>
  arrange(desc(n_facilities))
write_csv(poll_by_frequency, "output/exploratory_analysis/pollutants_by_frequency.csv")

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
write_csv(poll_per_facility, "output/exploratory_analysis/pollutants_per_facility.csv")

# Emissions classification distribution
poll_by_class <- ICIS_AIR_POLLUTANTS |>
  count(AIR_POLLUTANT_CLASS_CODE, AIR_POLLUTANT_CLASS_DESC, name = "n_records") |>
  arrange(desc(n_records))
write_csv(poll_by_class, "output/exploratory_analysis/pollutants_by_class.csv")

# CAS number coverage (useful for linking to health/tox data)
poll_cas <- ICIS_AIR_POLLUTANTS |>
  summarise(
    n_total = n(),
    n_with_cas = sum(!is.na(CHEMICAL_ABSTRACT_SERVICE_NMBR)),
    pct_with_cas = round(mean(!is.na(CHEMICAL_ABSTRACT_SERVICE_NMBR)) * 100, 2)
  )
write_csv(poll_cas, "output/exploratory_analysis/pollutants_cas_coverage.csv")
