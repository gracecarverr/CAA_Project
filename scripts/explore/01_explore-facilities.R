# =========================================================================================================
# 01_explore-facilities.R — exploratory profiling of ICIS-AIR_FACILITIES (the facility master table).
# Tabulates classification, operating status, and state/region distributions, and documents the
# REGISTRY_ID -> PGM_SYS_ID one-to-many structure with worked examples. Writes CSVs to
# output/explore_tabulations/facilities/. Exploratory only — not part of the analysis pipeline. Paths via here::here().
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# here() anchors on the project's .git directory, so paths resolve from any working directory.

facilities <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- here("output/explore_tabulations/facilities")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

# Dimensions
nrow(facilities)
ncol(facilities)
names(facilities)

# Key uniqueness
n_distinct(facilities$PGM_SYS_ID)   # air sources?
n_distinct(facilities$REGISTRY_ID)  # facilities (FRS)

# ---- Overview ------------------------------------------------------------------------------------------

overview <- data.frame(
  n_obs = nrow(facilities),
  n_distinct_facilities = n_distinct(facilities$PGM_SYS_ID)
)
overview
write_csv(overview, file.path(out_dir, "overview.csv"))

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

# ---- Multiple PGM_SYS_IDs per REGISTRY_ID ---------------------------------------------------------------

# REGISTRY_ID (FRS) identifies a physical site. PGM_SYS_ID identifies an air program source.
# One site can have many sources: sub-facility units, portable equipment, or ownership changes.

multi_id <- facilities |>
  filter(!is.na(REGISTRY_ID)) |>
  group_by(REGISTRY_ID) |>
  summarise(n_pgm = n_distinct(PGM_SYS_ID), .groups = "drop") |>
  filter(n_pgm > 1)

cat("REGISTRY_IDs with >1 PGM_SYS_ID:", nrow(multi_id), "\n")
cat("Distribution of PGM_SYS_IDs per REGISTRY_ID:\n")
print(table(multi_id$n_pgm))

# Example: 3M Cottage Grove complex (REGISTRY_ID 110000423667)
# 13 PGM_SYS_IDs at the same campus — individual buildings/process units each permitted separately.
# Mix of MAJ and MIN classifications; some legacy records closed, others still operating.

example_3m <- facilities |>
  filter(REGISTRY_ID == 110000423667) |>
  select(PGM_SYS_ID, FACILITY_NAME, STREET_ADDRESS, CITY, STATE, ZIP_CODE,
         AIR_POLLUTANT_CLASS_CODE, AIR_OPERATING_STATUS_CODE) |>
  arrange(AIR_OPERATING_STATUS_CODE, FACILITY_NAME)

cat("\n--- Example: 3M Cottage Grove (REGISTRY_ID 110000423667) ---\n")
print(as.data.frame(example_3m))
write_csv(example_3m, file.path(out_dir, "example_3m_multi_id.csv"))

# Example: Powerscreen Mid Atlantic (REGISTRY_ID 110037604152)
# 150 PGM_SYS_IDs — the most of any REGISTRY_ID. All portable equipment (crushers, screens).
# Every name contains "PORTABLE" with a serial number. All classified MIN/non-Title V.
# REGISTRY_ID is supposed to identify one physical site, but these 150 records span 6 counties
# and 7 cities across Virginia. The FRS ID is being used as a company identifier, not a site.

example_portable <- facilities |>
  filter(REGISTRY_ID == 110037604152) |>
  select(PGM_SYS_ID, FACILITY_NAME, STREET_ADDRESS, CITY, COUNTY_NAME, STATE,
         AIR_POLLUTANT_CLASS_CODE, AIR_OPERATING_STATUS_CODE) |>
  arrange(AIR_OPERATING_STATUS_CODE, FACILITY_NAME)

cat("\n--- Example: Powerscreen Mid Atlantic (REGISTRY_ID 110037604152) ---\n")
cat("Total PGM_SYS_IDs:", nrow(example_portable), "\n")
cat("Operating:", sum(example_portable$AIR_OPERATING_STATUS_CODE == "OPR"),
    "| Closed:", sum(example_portable$AIR_OPERATING_STATUS_CODE == "CLS"), "\n")
cat("Counties:", paste(unique(example_portable$COUNTY_NAME), collapse = ", "), "\n")
cat("Cities:", paste(unique(example_portable$CITY), collapse = ", "), "\n")
cat("Companies:\n")
print(unique(gsub(" - PORTABLE.*| PORTABLE.*", "", example_portable$FACILITY_NAME)))
print(as.data.frame(example_portable))
write_csv(example_portable, file.path(out_dir, "example_powerscreen_multi_id.csv"))

# Example: Evergreen Natural Resources (REGISTRY_ID 110070082225)
# 144 PGM_SYS_IDs — individual well pads in the Raton Basin near Trinidad, CO.
# All registered to the same address (27000 Highway 12) with county "Undetermined."
# The well pads are scattered across the basin but Colorado assigned them all to the
# company's field office address. 143 of 144 still operating. All MIN.

example_wellpads <- facilities |>
  filter(REGISTRY_ID == 110070082225) |>
  select(PGM_SYS_ID, FACILITY_NAME, STREET_ADDRESS, CITY, COUNTY_NAME, STATE,
         AIR_POLLUTANT_CLASS_CODE, AIR_OPERATING_STATUS_CODE) |>
  arrange(AIR_OPERATING_STATUS_CODE, FACILITY_NAME)

cat("\n--- Example: Evergreen Natural Resources (REGISTRY_ID 110070082225) ---\n")
cat("Total PGM_SYS_IDs:", nrow(example_wellpads), "\n")
cat("Operating:", sum(example_wellpads$AIR_OPERATING_STATUS_CODE == "OPR"),
    "| Closed:", sum(example_wellpads$AIR_OPERATING_STATUS_CODE == "CLS"), "\n")
cat("Unique addresses:", n_distinct(example_wellpads$STREET_ADDRESS), "\n")
cat("Counties:", paste(unique(example_wellpads$COUNTY_NAME), collapse = ", "), "\n")
print(as.data.frame(example_wellpads))
write_csv(example_wellpads, file.path(out_dir, "example_evergreen_multi_id.csv"))
