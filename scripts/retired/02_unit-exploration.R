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

out_dir <- "output/exploratory_analysis/UNIT_OF_OBSERVATION"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ===========================================================================================================
# QUESTION: What uniquely identifies a row in each ICIS-Air table?
# For each table, check whether candidate key combinations have duplicates.
# ===========================================================================================================

# ---- ICIS_AIR_FACILITIES ---------------------------------------------------------------------------------

# Candidate keys: PGM_SYS_ID (one per row?) vs REGISTRY_ID (one per facility?)
fac_keys <- data.frame(
  table = "FACILITIES",
  n_rows = nrow(ICIS_AIR_FACILITIES),
  n_pgm_sys_id = n_distinct(ICIS_AIR_FACILITIES$PGM_SYS_ID),
  n_registry_id = n_distinct(ICIS_AIR_FACILITIES$REGISTRY_ID),
  pgm_sys_id_is_unique = nrow(ICIS_AIR_FACILITIES) == n_distinct(ICIS_AIR_FACILITIES$PGM_SYS_ID)
)

# How many REGISTRY_IDs map to multiple PGM_SYS_IDs?
fac_shared_registry <- ICIS_AIR_FACILITIES |>
  count(REGISTRY_ID, name = "n_sources") |>
  filter(n_sources > 1)

fac_keys$n_registry_ids_shared <- nrow(fac_shared_registry)
fac_keys$max_sources_per_registry <- max(fac_shared_registry$n_sources)

# Look at the shared-REGISTRY_ID cases: same address or different?
fac_shared_detail <- ICIS_AIR_FACILITIES |>
  filter(REGISTRY_ID %in% fac_shared_registry$REGISTRY_ID) |>
  arrange(REGISTRY_ID) |>
  select(REGISTRY_ID, PGM_SYS_ID, FACILITY_NAME, STREET_ADDRESS, CITY, STATE,
         AIR_POLLUTANT_CLASS_CODE, AIR_OPERATING_STATUS_CODE)
write_csv(fac_shared_detail, file.path(out_dir, "facilities_shared_registry_ids.csv"))

# Same address check: for each REGISTRY_ID with multiple PGM_SYS_IDs,
# do they share the same address?
fac_address_check <- ICIS_AIR_FACILITIES |>
  filter(REGISTRY_ID %in% fac_shared_registry$REGISTRY_ID) |>
  group_by(REGISTRY_ID) |>
  summarise(
    n_sources = n(),
    n_unique_addresses = n_distinct(STREET_ADDRESS),
    n_unique_names = n_distinct(FACILITY_NAME),
    n_unique_cities = n_distinct(CITY),
    same_address = n_distinct(STREET_ADDRESS) == 1,
    same_name = n_distinct(FACILITY_NAME) == 1,
    same_city = n_distinct(CITY) == 1
  )
write_csv(fac_address_check, file.path(out_dir, "facilities_address_check.csv"))

# Summary: what fraction share same address/name/city?
fac_address_summary <- fac_address_check |>
  summarise(
    n_shared_registry_ids = n(),
    pct_same_address = round(mean(same_address) * 100, 2),
    pct_same_name = round(mean(same_name) * 100, 2),
    pct_same_city = round(mean(same_city) * 100, 2),
    pct_same_address_and_name = round(mean(same_address & same_name) * 100, 2),
    pct_diff_address = round(mean(!same_address) * 100, 2)
  )
write_csv(fac_address_summary, file.path(out_dir, "facilities_address_summary.csv"))

# For concurrent-source question: check operating status of shared pairs
# Are both operating, or is one closed (suggesting re-registration)?
fac_status_check <- ICIS_AIR_FACILITIES |>
  filter(REGISTRY_ID %in% fac_shared_registry$REGISTRY_ID) |>
  group_by(REGISTRY_ID) |>
  summarise(
    n_sources = n(),
    n_operating = sum(AIR_OPERATING_STATUS_CODE == "OPR", na.rm = TRUE),
    n_closed = sum(AIR_OPERATING_STATUS_CODE == "CLS", na.rm = TRUE),
    all_operating = all(AIR_OPERATING_STATUS_CODE == "OPR", na.rm = TRUE),
    any_closed = any(AIR_OPERATING_STATUS_CODE == "CLS", na.rm = TRUE)
  )
write_csv(fac_status_check, file.path(out_dir, "facilities_status_check.csv"))

fac_status_summary <- fac_status_check |>
  summarise(
    n_shared_registry_ids = n(),
    pct_all_operating = round(mean(all_operating, na.rm = TRUE) * 100, 2),
    pct_any_closed = round(mean(any_closed, na.rm = TRUE) * 100, 2)
  )
write_csv(fac_status_summary, file.path(out_dir, "facilities_status_summary.csv"))

# ---- ICIS_AIR_PROGRAMS ----------------------------------------------------------------------------------

# Claimed unit: PGM_SYS_ID x PROGRAM_CODE
prog_keys <- data.frame(
  table = "PROGRAMS",
  n_rows = nrow(ICIS_AIR_PROGRAMS),
  n_pgm_sys_id = n_distinct(ICIS_AIR_PROGRAMS$PGM_SYS_ID),
  n_pgm_x_prog = n_distinct(paste(ICIS_AIR_PROGRAMS$PGM_SYS_ID, ICIS_AIR_PROGRAMS$PROGRAM_CODE)),
  pgm_x_prog_is_unique = nrow(ICIS_AIR_PROGRAMS) == n_distinct(paste(ICIS_AIR_PROGRAMS$PGM_SYS_ID, ICIS_AIR_PROGRAMS$PROGRAM_CODE))
)

# If not unique, what duplicates exist?
if (!prog_keys$pgm_x_prog_is_unique) {
  prog_dups <- ICIS_AIR_PROGRAMS |>
    count(PGM_SYS_ID, PROGRAM_CODE) |>
    filter(n > 1)
  write_csv(prog_dups, file.path(out_dir, "programs_duplicate_keys.csv"))
  prog_keys$n_duplicate_combos <- nrow(prog_dups)
}

# ---- ICIS_AIR_PROGRAM_SUBPARTS --------------------------------------------------------------------------

# Claimed unit: PGM_SYS_ID x PROGRAM_CODE x AIR_PROGRAM_SUBPART_CODE
sub_keys <- data.frame(
  table = "PROGRAM_SUBPARTS",
  n_rows = nrow(ICIS_AIR_PROGRAM_SUBPARTS),
  n_pgm_sys_id = n_distinct(ICIS_AIR_PROGRAM_SUBPARTS$PGM_SYS_ID),
  n_combo = n_distinct(paste(ICIS_AIR_PROGRAM_SUBPARTS$PGM_SYS_ID,
                             ICIS_AIR_PROGRAM_SUBPARTS$PROGRAM_CODE,
                             ICIS_AIR_PROGRAM_SUBPARTS$AIR_PROGRAM_SUBPART_CODE)),
  combo_is_unique = nrow(ICIS_AIR_PROGRAM_SUBPARTS) == n_distinct(paste(
    ICIS_AIR_PROGRAM_SUBPARTS$PGM_SYS_ID,
    ICIS_AIR_PROGRAM_SUBPARTS$PROGRAM_CODE,
    ICIS_AIR_PROGRAM_SUBPARTS$AIR_PROGRAM_SUBPART_CODE))
)

# ---- ICIS_AIR_POLLUTANTS --------------------------------------------------------------------------------

# Claimed unit: PGM_SYS_ID x POLLUTANT_CODE
poll_keys <- data.frame(
  table = "POLLUTANTS",
  n_rows = nrow(ICIS_AIR_POLLUTANTS),
  n_pgm_sys_id = n_distinct(ICIS_AIR_POLLUTANTS$PGM_SYS_ID),
  n_pgm_x_poll = n_distinct(paste(ICIS_AIR_POLLUTANTS$PGM_SYS_ID, ICIS_AIR_POLLUTANTS$POLLUTANT_CODE)),
  pgm_x_poll_is_unique = nrow(ICIS_AIR_POLLUTANTS) == n_distinct(paste(ICIS_AIR_POLLUTANTS$PGM_SYS_ID, ICIS_AIR_POLLUTANTS$POLLUTANT_CODE))
)

if (!poll_keys$pgm_x_poll_is_unique) {
  poll_dups <- ICIS_AIR_POLLUTANTS |>
    count(PGM_SYS_ID, POLLUTANT_CODE) |>
    filter(n > 1)
  write_csv(poll_dups, file.path(out_dir, "pollutants_duplicate_keys.csv"))
  poll_keys$n_duplicate_combos <- nrow(poll_dups)
}

# ---- ICIS_AIR_FCES_PCES ---------------------------------------------------------------------------------

# Candidate key: ACTIVITY_ID
fce_keys <- data.frame(
  table = "FCES_PCES",
  n_rows = nrow(ICIS_AIR_FCES_PCES),
  n_activity_id = n_distinct(ICIS_AIR_FCES_PCES$ACTIVITY_ID),
  activity_id_is_unique = nrow(ICIS_AIR_FCES_PCES) == n_distinct(ICIS_AIR_FCES_PCES$ACTIVITY_ID),
  n_pgm_sys_id = n_distinct(ICIS_AIR_FCES_PCES$PGM_SYS_ID)
)

if (!fce_keys$activity_id_is_unique) {
  fce_dups <- ICIS_AIR_FCES_PCES |>
    count(ACTIVITY_ID) |>
    filter(n > 1)
  write_csv(fce_dups, file.path(out_dir, "fces_pces_duplicate_activity_ids.csv"))
  fce_keys$n_duplicate_activity_ids <- nrow(fce_dups)
}

# ---- ICIS_AIR_STACK_TESTS -------------------------------------------------------------------------------

st_keys <- data.frame(
  table = "STACK_TESTS",
  n_rows = nrow(ICIS_AIR_STACK_TESTS),
  n_activity_id = n_distinct(ICIS_AIR_STACK_TESTS$ACTIVITY_ID),
  activity_id_is_unique = nrow(ICIS_AIR_STACK_TESTS) == n_distinct(ICIS_AIR_STACK_TESTS$ACTIVITY_ID),
  n_pgm_sys_id = n_distinct(ICIS_AIR_STACK_TESTS$PGM_SYS_ID)
)

if (!st_keys$activity_id_is_unique) {
  st_dups <- ICIS_AIR_STACK_TESTS |>
    count(ACTIVITY_ID) |>
    filter(n > 1)
  write_csv(st_dups, file.path(out_dir, "stack_tests_duplicate_activity_ids.csv"))
  st_keys$n_duplicate_activity_ids <- nrow(st_dups)
}

# ---- ICIS_AIR_TITLEV_CERTS ------------------------------------------------------------------------------

tv_keys <- data.frame(
  table = "TITLEV_CERTS",
  n_rows = nrow(ICIS_AIR_TITLEV_CERTS),
  n_activity_id = n_distinct(ICIS_AIR_TITLEV_CERTS$ACTIVITY_ID),
  activity_id_is_unique = nrow(ICIS_AIR_TITLEV_CERTS) == n_distinct(ICIS_AIR_TITLEV_CERTS$ACTIVITY_ID),
  n_pgm_sys_id = n_distinct(ICIS_AIR_TITLEV_CERTS$PGM_SYS_ID)
)

if (!tv_keys$activity_id_is_unique) {
  tv_dups <- ICIS_AIR_TITLEV_CERTS |>
    count(ACTIVITY_ID) |>
    filter(n > 1)
  write_csv(tv_dups, file.path(out_dir, "titlev_duplicate_activity_ids.csv"))
  tv_keys$n_duplicate_activity_ids <- nrow(tv_dups)
}

# ---- ICIS_AIR_FORMAL_ACTIONS ----------------------------------------------------------------------------

fa_keys <- data.frame(
  table = "FORMAL_ACTIONS",
  n_rows = nrow(ICIS_AIR_FORMAL_ACTIONS),
  n_activity_id = n_distinct(ICIS_AIR_FORMAL_ACTIONS$ACTIVITY_ID),
  activity_id_is_unique = nrow(ICIS_AIR_FORMAL_ACTIONS) == n_distinct(ICIS_AIR_FORMAL_ACTIONS$ACTIVITY_ID),
  n_pgm_sys_id = n_distinct(ICIS_AIR_FORMAL_ACTIONS$PGM_SYS_ID),
  n_enf_identifier = n_distinct(ICIS_AIR_FORMAL_ACTIONS$ENF_IDENTIFIER)
)

if (!fa_keys$activity_id_is_unique) {
  fa_dups <- ICIS_AIR_FORMAL_ACTIONS |>
    count(ACTIVITY_ID) |>
    filter(n > 1)
  write_csv(fa_dups, file.path(out_dir, "formal_actions_duplicate_activity_ids.csv"))
  fa_keys$n_duplicate_activity_ids <- nrow(fa_dups)
}

# ---- ICIS_AIR_INFORMAL_ACTIONS --------------------------------------------------------------------------

ia_keys <- data.frame(
  table = "INFORMAL_ACTIONS",
  n_rows = nrow(ICIS_AIR_INFORMAL_ACTIONS),
  n_activity_id = n_distinct(ICIS_AIR_INFORMAL_ACTIONS$ACTIVITY_ID),
  activity_id_is_unique = nrow(ICIS_AIR_INFORMAL_ACTIONS) == n_distinct(ICIS_AIR_INFORMAL_ACTIONS$ACTIVITY_ID),
  n_pgm_sys_id = n_distinct(ICIS_AIR_INFORMAL_ACTIONS$PGM_SYS_ID),
  n_enf_identifier = n_distinct(ICIS_AIR_INFORMAL_ACTIONS$ENF_IDENTIFIER)
)

if (!ia_keys$activity_id_is_unique) {
  ia_dups <- ICIS_AIR_INFORMAL_ACTIONS |>
    count(ACTIVITY_ID) |>
    filter(n > 1)
  write_csv(ia_dups, file.path(out_dir, "informal_actions_duplicate_activity_ids.csv"))
  ia_keys$n_duplicate_activity_ids <- nrow(ia_dups)
}

# ---- ICIS_AIR_VIOLATION_HISTORY --------------------------------------------------------------------------

vh_keys <- data.frame(
  table = "VIOLATION_HISTORY",
  n_rows = nrow(ICIS_AIR_VIOLATION_HISTORY),
  n_activity_id = n_distinct(ICIS_AIR_VIOLATION_HISTORY$ACTIVITY_ID),
  activity_id_is_unique = nrow(ICIS_AIR_VIOLATION_HISTORY) == n_distinct(ICIS_AIR_VIOLATION_HISTORY$ACTIVITY_ID),
  n_pgm_sys_id = n_distinct(ICIS_AIR_VIOLATION_HISTORY$PGM_SYS_ID)
)

# Also check COMP_DETERMINATION_UID
vh_keys$n_comp_det_uid <- n_distinct(ICIS_AIR_VIOLATION_HISTORY$COMP_DETERMINATION_UID, na.rm = TRUE)

if (!vh_keys$activity_id_is_unique) {
  vh_dups <- ICIS_AIR_VIOLATION_HISTORY |>
    count(ACTIVITY_ID) |>
    filter(n > 1)
  write_csv(vh_dups, file.path(out_dir, "violations_duplicate_activity_ids.csv"))
  vh_keys$n_duplicate_activity_ids <- nrow(vh_dups)
}

# ---- COMBINE KEY SUMMARY --------------------------------------------------------------------------------

# Build summary table — which candidate key uniquely identifies rows?
key_summary <- bind_rows(fac_keys, prog_keys, sub_keys, poll_keys,
                         fce_keys, st_keys, tv_keys, fa_keys, ia_keys, vh_keys)
write_csv(key_summary, file.path(out_dir, "key_summary.csv"))

# ---- CROSS-TABLE: ORPHAN KEY CHECK ----------------------------------------------------------------------

# Do all PGM_SYS_IDs in child tables appear in the Facilities spine?
orphan_check <- data.frame(
  table = c("PROGRAMS", "PROGRAM_SUBPARTS", "POLLUTANTS", "FCES_PCES",
            "STACK_TESTS", "TITLEV_CERTS", "FORMAL_ACTIONS",
            "INFORMAL_ACTIONS", "VIOLATION_HISTORY"),
  n_orphans = c(
    sum(!ICIS_AIR_PROGRAMS$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_PROGRAM_SUBPARTS$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_POLLUTANTS$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_FCES_PCES$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_STACK_TESTS$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_TITLEV_CERTS$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_FORMAL_ACTIONS$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_INFORMAL_ACTIONS$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID),
    sum(!ICIS_AIR_VIOLATION_HISTORY$PGM_SYS_ID %in% ICIS_AIR_FACILITIES$PGM_SYS_ID)
  )
)
write_csv(orphan_check, file.path(out_dir, "orphan_key_check.csv"))

# ---- CONCURRENT VS RE-REGISTRATION CHECK ----------------------------------------------------------------

# For shared REGISTRY_IDs: check activity date overlap in FCEs/PCEs
# Parse dates
fce_dated <- ICIS_AIR_FCES_PCES |>
  mutate(ACTUAL_END_DATE = mdy(ACTUAL_END_DATE))

shared_ids <- ICIS_AIR_FACILITIES |>
  filter(REGISTRY_ID %in% fac_shared_registry$REGISTRY_ID) |>
  pull(PGM_SYS_ID)

overlap_check <- fce_dated |>
  filter(PGM_SYS_ID %in% shared_ids) |>
  group_by(PGM_SYS_ID) |>
  summarise(
    min_date = min(ACTUAL_END_DATE, na.rm = TRUE),
    max_date = max(ACTUAL_END_DATE, na.rm = TRUE),
    n_events = n()
  ) |>
  left_join(
    ICIS_AIR_FACILITIES |>
      filter(REGISTRY_ID %in% fac_shared_registry$REGISTRY_ID) |>
      select(REGISTRY_ID, PGM_SYS_ID),
    by = "PGM_SYS_ID"
  ) |>
  arrange(REGISTRY_ID, min_date)

write_csv(overlap_check, file.path(out_dir, "facilities_date_overlap.csv"))

# Classify each REGISTRY_ID pair as overlapping or sequential
overlap_classified <- overlap_check |>
  group_by(REGISTRY_ID) |>
  filter(n() > 1) |>
  summarise(
    n_sources = n(),
    earliest_start = min(min_date, na.rm = TRUE),
    latest_start = max(min_date, na.rm = TRUE),
    earliest_end = min(max_date, na.rm = TRUE),
    latest_end = max(max_date, na.rm = TRUE),
    # Overlap: does the later-starting source start before the earlier-ending source ends?
    has_overlap = latest_start <= earliest_end
  )

overlap_summary <- overlap_classified |>
  summarise(
    n_registry_ids_with_activity = n(),
    n_overlapping = sum(has_overlap, na.rm = TRUE),
    n_sequential = sum(!has_overlap, na.rm = TRUE),
    pct_overlapping = round(mean(has_overlap, na.rm = TRUE) * 100, 2)
  )
write_csv(overlap_classified, file.path(out_dir, "facilities_overlap_classified.csv"))
write_csv(overlap_summary, file.path(out_dir, "facilities_overlap_summary.csv"))
