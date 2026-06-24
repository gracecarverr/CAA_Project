# =========================================================================================================
# 04_explore-compliance.R — exploratory profiling of ICIS-AIR_FCES_PCES (compliance evaluations).
# Tabulates evaluation/monitor types and cross-tabs; writes CSVs to output/explore_tabulations/compliance/.
# Exploratory only — not part of the analysis pipeline. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# here() anchors on the project's .git directory, so paths resolve from any working directory.

icis_dir <- here("data/raw/ICIS-AIR_downloads")
compliance <- read_csv(file.path(icis_dir, "ICIS-AIR_FCES_PCES.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- here("output/explore_tabulations/compliance")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(compliance)
ncol(compliance)
names(compliance)
n_distinct(compliance$PGM_SYS_ID)

# ---- Overview ------------------------------------------------------------------------------------------

overview <- data.frame(
  n_obs = nrow(compliance),
  n_distinct_facilities = n_distinct(compliance$PGM_SYS_ID)
)
overview
write_csv(overview, file.path(out_dir, "overview.csv"))

# ---- Missingness ----------------------------------------------------------------------------------------

miss <- data.frame(
  field = names(compliance),
  n_missing = sapply(compliance, function(x) sum(is.na(x)))
)
miss$pct <- round(miss$n_missing / nrow(compliance) * 100, 1)
miss
write_csv(miss, file.path(out_dir, "missingness.csv"))

# ---- Compliance monitoring type (FCE vs PCE) ------------------------------------------------------------

tab_monitor <- compliance |>
  count(COMP_MONITOR_TYPE_CODE, COMP_MONITOR_TYPE_DESC, name = "n") |>
  mutate(pct = round(n / nrow(compliance) * 100, 1)) |>
  arrange(desc(n))
tab_monitor
write_csv(tab_monitor, file.path(out_dir, "tab_monitor_type.csv"))

# ---- State vs EPA ---------------------------------------------------------------------------------------

tab_flag <- compliance |>
  count(STATE_EPA_FLAG, name = "n") |>
  mutate(pct = round(n / nrow(compliance) * 100, 1)) |>
  arrange(desc(n))
tab_flag
write_csv(tab_flag, file.path(out_dir, "tab_state_epa_flag.csv"))

# ---- Activity purpose -----------------------------------------------------------------------------------

tab_purpose <- compliance |>
  count(ACTIVITY_PURPOSE_DESC, name = "n") |>
  mutate(pct = round(n / nrow(compliance) * 100, 1)) |>
  arrange(desc(n))
tab_purpose
write_csv(tab_purpose, file.path(out_dir, "tab_activity_purpose.csv"))

# ---- Program codes --------------------------------------------------------------------------------------

tab_programs <- compliance |>
  count(PROGRAM_CODES, name = "n") |>
  mutate(pct = round(n / nrow(compliance) * 100, 1)) |>
  arrange(desc(n))
tab_programs
write_csv(tab_programs, file.path(out_dir, "tab_program_codes.csv"))

# ---- Cross-tab: monitor type × facility classification -------------------------------------------------

comp_class <- compliance |>
  left_join(
    facilities |> select(PGM_SYS_ID, AIR_POLLUTANT_CLASS_CODE),
    by = "PGM_SYS_ID"
  ) |>
  count(COMP_MONITOR_TYPE_CODE, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(COMP_MONITOR_TYPE_CODE, desc(n))
comp_class
write_csv(comp_class, file.path(out_dir, "xtab_monitor_by_classification.csv"))

# ---- Cross-tab: state/EPA flag × monitor type ----------------------------------------------------------

comp_flag_type <- compliance |>
  count(STATE_EPA_FLAG, COMP_MONITOR_TYPE_CODE, name = "n") |>
  arrange(STATE_EPA_FLAG, desc(n))
comp_flag_type
write_csv(comp_flag_type, file.path(out_dir, "xtab_flag_by_monitor_type.csv"))
