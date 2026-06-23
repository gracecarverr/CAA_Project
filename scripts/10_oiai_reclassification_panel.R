# =========================================================================================================
# 10_oiai_reclassification_panel.R
#
# PURPOSE
#   Track how facilities' major/minor emissions classification changed around the "Once In Always In"
#   (OIAI) policy reversal. OIAI required major HAP sources to stay "major" forever; EPA withdrew it via
#   a guidance memo on 2018-01-25, letting facilities reclassify down to synthetic-minor/minor. This
#   script builds a facility-level panel across five point-in-time snapshots to measure that reclassing.
#
# INPUTS  five snapshots of ICIS-Air FACILITIES + PROGRAMS:
#   four archived Wayback Machine pulls (data/raw/wayback_snapshots/) plus the current bulk download.
#   Only 2015-09 predates the reversal, so it is the baseline for every transition.
# OUTPUT  data/derived/oiai_facility_panel.csv   one row per facility, wide over snapshots
#
# Paths use here::here() (anchored on .git) so the script runs from any working directory.
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)      # project-root-relative paths (replaces hardcoded setwd)
library(readr)
library(dplyr)
library(tidyr)

# ---- Define snapshot paths and labels -------------------------------------------------------------------
# 4 Wayback Machine snapshots + the current bulk download. The OIAI reversal was January 25, 2018
# (EPA guidance memo), so 2015-09 is the only pre-reversal snapshot and serves as the baseline.

snapshots <- list(
  list(label = "2015-09",      path = here("data/raw/wayback_snapshots/ICIS-AIR_2015-09")),
  list(label = "2019-05",      path = here("data/raw/wayback_snapshots/ICIS-AIR_2019-05")),
  list(label = "2022-04",      path = here("data/raw/wayback_snapshots/ICIS-AIR_2022-04")),
  list(label = "2024-09",      path = here("data/raw/wayback_snapshots/ICIS-AIR_2024-09")),
  list(label = "2025-current", path = here("data/raw/ICIS-AIR_downloads"))
)

# ---- Read facility classification from each snapshot ----------------------------------------------------
# Key columns: PGM_SYS_ID (facility ID), AIR_POLLUTANT_CLASS_CODE (MAJ/MIN/SM/NA),
# FACILITY_TYPE_CODE (TITV/NON/NA), AIR_OPERATING_STATUS_CODE, STATE

read_fac <- function(snap) {
  fac <- read_csv(file.path(snap$path, "ICIS-AIR_FACILITIES.csv"),
                  show_col_types = FALSE,
                  col_types = cols(.default = "c"))
  fac |>
    select(PGM_SYS_ID, STATE,
           class = AIR_POLLUTANT_CLASS_CODE,
           ftype = FACILITY_TYPE_CODE,
           op_status = AIR_OPERATING_STATUS_CODE) |>
    mutate(snapshot = snap$label)
}

fac_all <- bind_rows(lapply(snapshots, read_fac))

cat("Total facility-snapshot rows:", nrow(fac_all), "\n")
cat("Rows per snapshot:\n")
print(fac_all |> count(snapshot))

# ---- Read Title V enrollment from Programs table -------------------------------------------------------
# A facility is in Title V if it has a row with PROGRAM_CODE = "CAATVP".

read_tv <- function(snap) {
  prg <- read_csv(file.path(snap$path, "ICIS-AIR_PROGRAMS.csv"),
                  show_col_types = FALSE,
                  col_types = cols(.default = "c"))
  prg |>
    filter(PROGRAM_CODE == "CAATVP") |>
    distinct(PGM_SYS_ID) |>
    mutate(has_titlev = TRUE, snapshot = snap$label)
}

tv_all <- bind_rows(lapply(snapshots, read_tv))

# ---- Build facility-level panel -------------------------------------------------------------------------
# One row per facility, with classification and Title V status at each snapshot.

panel <- fac_all |>
  left_join(tv_all, by = c("PGM_SYS_ID", "snapshot")) |>
  mutate(has_titlev = ifelse(is.na(has_titlev), FALSE, TRUE))

# Pivot to wide: one row per facility, columns for each snapshot's classification
panel_wide <- panel |>
  select(PGM_SYS_ID, STATE, snapshot, class, ftype, has_titlev) |>
  pivot_wider(
    id_cols = c(PGM_SYS_ID, STATE),
    names_from = snapshot,
    values_from = c(class, ftype, has_titlev),
    names_sep = "_"
  )

cat("\nPanel: ", nrow(panel_wide), "unique facilities\n")
cat("Facilities present in all 5 snapshots:",
    sum(complete.cases(panel_wide |> select(starts_with("class_")))), "\n")

# ---- Balanced panel: facilities in both 2015 and at least one post-reversal snapshot --------------------
# Focus on facilities we can actually track through the policy change.

balanced <- panel_wide |>
  filter(!is.na(`class_2015-09`))

cat("\nFacilities present in 2015 baseline:", nrow(balanced), "\n")

# ---- Classification transitions -------------------------------------------------------------------------
# The OIAI question: did MAJ facilities reclassify to SM or MIN after Jan 2018?

# 2015 → 2019 (spans the reversal)
trans_15_19 <- balanced |>
  filter(!is.na(`class_2019-05`)) |>
  count(`class_2015-09`, `class_2019-05`, name = "n") |>
  arrange(`class_2015-09`, desc(n))

cat("\n=== CLASSIFICATION TRANSITIONS: 2015 → 2019 ===\n")
print(trans_15_19, n = 30)

# 2015 → 2022
trans_15_22 <- balanced |>
  filter(!is.na(`class_2022-04`)) |>
  count(`class_2015-09`, `class_2022-04`, name = "n") |>
  arrange(`class_2015-09`, desc(n))

cat("\n=== CLASSIFICATION TRANSITIONS: 2015 → 2022 ===\n")
print(trans_15_22, n = 30)

# 2015 → 2024
trans_15_24 <- balanced |>
  filter(!is.na(`class_2024-09`)) |>
  count(`class_2015-09`, `class_2024-09`, name = "n") |>
  arrange(`class_2015-09`, desc(n))

cat("\n=== CLASSIFICATION TRANSITIONS: 2015 → 2024 ===\n")
print(trans_15_24, n = 30)

# 2015 → current
trans_15_cur <- balanced |>
  filter(!is.na(`class_2025-current`)) |>
  count(`class_2015-09`, `class_2025-current`, name = "n") |>
  arrange(`class_2015-09`, desc(n))

cat("\n=== CLASSIFICATION TRANSITIONS: 2015 → current ===\n")
print(trans_15_cur, n = 30)

# ---- MAJ facilities specifically -----------------------------------------------------------------------
# These are the facilities the OIAI reversal directly affects.

maj_2015 <- balanced |> filter(`class_2015-09` == "MAJ")
cat("\n=== MAJ FACILITIES IN 2015 ===\n")
cat("Count:", nrow(maj_2015), "\n")

# Track what happened to them at each snapshot
for (snap in c("2019-05", "2022-04", "2024-09", "2025-current")) {
  col <- paste0("class_", snap)
  tv_col <- paste0("has_titlev_", snap)

  cat("\n--- 2015 MAJ facilities in", snap, "---\n")

  # Classification distribution
  class_dist <- maj_2015 |>
    filter(!is.na(.data[[col]])) |>
    count(new_class = .data[[col]]) |>
    mutate(pct = round(n / sum(n) * 100, 2))
  print(class_dist)

  # How many dropped out entirely?
  n_missing <- sum(is.na(maj_2015[[col]]))
  cat("Not in snapshot:", n_missing, "\n")
}

# ---- Title V enrollment changes for MAJ→SM/MIN switchers ------------------------------------------------
# Did facilities that reclassified also drop Title V?

cat("\n=== TITLE V STATUS OF MAJ→SMI SWITCHERS (2015 → 2024) ===\n")
switchers_sm <- maj_2015 |>
  filter(`class_2024-09` == "SMI")

if (nrow(switchers_sm) > 0) {
  cat("MAJ→SMI switchers:", nrow(switchers_sm), "\n")
  cat("Had Title V in 2015:", sum(switchers_sm$`has_titlev_2015-09`, na.rm = TRUE), "\n")
  cat("Had Title V in 2024:", sum(switchers_sm$`has_titlev_2024-09`, na.rm = TRUE), "\n")

  tv_trans <- switchers_sm |>
    count(`has_titlev_2015-09`, `has_titlev_2024-09`)
  print(tv_trans)
} else {
  cat("No MAJ→SMI switchers found\n")
}

cat("\n=== TITLE V STATUS OF MAJ→MIN SWITCHERS (2015 → 2024) ===\n")
switchers_min <- maj_2015 |>
  filter(`class_2024-09` == "MIN")

if (nrow(switchers_min) > 0) {
  cat("MAJ→MIN switchers:", nrow(switchers_min), "\n")
  cat("Had Title V in 2015:", sum(switchers_min$`has_titlev_2015-09`, na.rm = TRUE), "\n")
  cat("Had Title V in 2024:", sum(switchers_min$`has_titlev_2024-09`, na.rm = TRUE), "\n")

  tv_trans <- switchers_min |>
    count(`has_titlev_2015-09`, `has_titlev_2024-09`)
  print(tv_trans)
} else {
  cat("No MAJ→MIN switchers found\n")
}

# ---- State-level breakdown of MAJ reclassification -----------------------------------------------------
# Some states may have responded more than others.

cat("\n=== STATE-LEVEL: MAJ→non-MAJ RECLASSIFICATION (2015 → 2024) ===\n")
state_reclass <- maj_2015 |>
  filter(!is.na(`class_2024-09`)) |>
  mutate(reclassified = `class_2024-09` != "MAJ") |>
  group_by(STATE) |>
  summarise(
    n_maj_2015 = n(),
    n_reclass = sum(reclassified),
    pct_reclass = round(n_reclass / n_maj_2015 * 100, 1),
    .groups = "drop"
  ) |>
  filter(n_maj_2015 >= 20) |>
  arrange(desc(pct_reclass))

print(state_reclass, n = 60)

# ---- Aggregate classification shares over time ----------------------------------------------------------
# How did the MAJ/SM/MIN mix change across all facilities?

cat("\n=== CLASSIFICATION SHARES OVER TIME (all facilities in each snapshot) ===\n")
class_shares <- fac_all |>
  filter(!is.na(class)) |>
  group_by(snapshot) |>
  count(class) |>
  mutate(pct = round(n / sum(n) * 100, 2)) |>
  ungroup()

print(class_shares |> pivot_wider(names_from = class, values_from = c(n, pct)), width = 200)

# ---- Save panel to derived data -------------------------------------------------------------------------
# Derived output only; raw snapshots are never modified. dir.create is a no-op if the folder exists.

dir.create(here("data/derived"), showWarnings = FALSE, recursive = TRUE)
write_csv(panel_wide, here("data/derived/oiai_facility_panel.csv"))
cat("\nPanel saved to", here("data/derived/oiai_facility_panel.csv"), "\n")
cat("Columns:", ncol(panel_wide), "\n")
cat("Rows:", nrow(panel_wide), "\n")
