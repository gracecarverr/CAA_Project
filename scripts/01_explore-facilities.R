# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

facilities <- read_csv("data/raw/ICIS-AIR_downloads/ICIS-AIR_FACILITIES.csv")

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/facilities"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

# Dimensions
nrow(facilities)
ncol(facilities)
names(facilities)

# Key uniqueness
n_distinct(facilities$PGM_SYS_ID)   # air sources?
n_distinct(facilities$REGISTRY_ID)  # facilities (FRS)

# ---- Missingness ----------------------------------------------------------------------------------------

missingness <- data.frame(
  variable = names(facilities),
  n_missing = colSums(is.na(facilities)),
  pct_missing = round(colSums(is.na(facilities)) / nrow(facilities) * 100, 2)
)
write_csv(missingness, file.path(out_dir, "missingness.csv"))

# ---- Categorical tabulations ---------------------------------------------------------------------------

# Emissions classification (major/synthetic minor/minor)
tab_class <- facilities |>
  count(AIR_POLLUTANT_CLASS_CODE, AIR_POLLUTANT_CLASS_DESC, name = "n") |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  arrange(desc(n))
write_csv(tab_class, file.path(out_dir, "tab_classification.csv"))

# Operating status
tab_status <- facilities |>
  count(AIR_OPERATING_STATUS_CODE, AIR_OPERATING_STATUS_DESC, name = "n") |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  arrange(desc(n))
write_csv(tab_status, file.path(out_dir, "tab_operating_status.csv"))

# Current HPV status
tab_hpv <- facilities |>
  count(CURRENT_HPV, name = "n") |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  arrange(desc(n))
write_csv(tab_hpv, file.path(out_dir, "tab_hpv.csv"))

# Facility type (ownership)
tab_type <- facilities |>
  count(FACILITY_TYPE_CODE, name = "n") |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  arrange(desc(n))
write_csv(tab_type, file.path(out_dir, "tab_facility_type.csv"))

# State distribution
tab_state <- facilities |>
  count(STATE, name = "n") |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  arrange(desc(n))
write_csv(tab_state, file.path(out_dir, "tab_state.csv"))

# EPA region
tab_region <- facilities |>
  count(EPA_REGION, name = "n") |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  arrange(desc(n))
write_csv(tab_region, file.path(out_dir, "tab_epa_region.csv"))

# ---- Cross-tabulations ---------------------------------------------------------------------------------

# Classification by operating status
xtab_class_status <- facilities |>
  count(AIR_POLLUTANT_CLASS_CODE, AIR_OPERATING_STATUS_CODE, name = "n") |>
  arrange(AIR_POLLUTANT_CLASS_CODE, desc(n))
write_csv(xtab_class_status, file.path(out_dir, "xtab_class_by_status.csv"))

# Classification by state (top states)
xtab_class_state <- facilities |>
  count(STATE, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(STATE, desc(n))
write_csv(xtab_class_state, file.path(out_dir, "xtab_class_by_state.csv"))

# In Texas, out of 7,738 records, only 87 (~1%) are Synthetic Minor. Is this a 
# state policy choice or the fact that Texas has huge emitters that can't possibly
# cap below the threshold?

facilities |>
  count(STATE, AIR_POLLUTANT_CLASS_CODE) |>
  group_by(STATE) |>
  mutate(pct = round(n / sum(n) * 100, 1)) |>
  filter(AIR_POLLUTANT_CLASS_CODE == "SMI") |>
  arrange(desc(pct)) |>
  print(n = 15)

  # Vermont has highest share of SMI, but only 194 sources (smaller sample). The second
  # largest (Arkansas), has 46% synthetic minors with 1,125 records. 