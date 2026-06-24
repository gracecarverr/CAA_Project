# =========================================================================================================
# 06_explore-informal.R — exploratory profiling of ICIS-AIR_INFORMAL_ACTIONS.
# Tabulates informal enforcement types (NOVs, warning letters), cross-tabs; writes to output/explore_tabulations/informal/.
# Exploratory only — not part of the analysis pipeline. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# here() anchors on the project's .git directory, so paths resolve from any working directory.

icis_dir <- here("data/raw/ICIS-AIR_downloads")
informal   <- read_csv(file.path(icis_dir, "ICIS-AIR_INFORMAL_ACTIONS.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- here("output/explore_tabulations/informal")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(informal)
ncol(informal)
names(informal)
n_distinct(informal$PGM_SYS_ID)

# ---- Overview ------------------------------------------------------------------------------------------

overview <- data.frame(
  n_obs = nrow(informal),
  n_distinct_facilities = n_distinct(informal$PGM_SYS_ID)
)
overview
write_csv(overview, file.path(out_dir, "overview.csv"))

# ---- Missingness ----------------------------------------------------------------------------------------

miss <- data.frame(
  field = names(informal),
  n_missing = sapply(informal, function(x) sum(is.na(x)))
)
miss$pct <- round(miss$n_missing / nrow(informal) * 100, 1)
miss
write_csv(miss, file.path(out_dir, "missingness.csv"))

# ---- Activity type --------------------------------------------------------------------------------------

tab_activity <- informal |>
  count(ACTIVITY_TYPE_CODE, ACTIVITY_TYPE_DESC, name = "n") |>
  mutate(pct = round(n / nrow(informal) * 100, 1)) |>
  arrange(desc(n))
tab_activity
write_csv(tab_activity, file.path(out_dir, "tab_activity_type.csv"))



# ---- Enforcement type -----------------------------------------------------------------------------------

tab_enf <- informal |>
  count(ENF_TYPE_CODE, ENF_TYPE_DESC, name = "n") |>
  mutate(pct = round(n / nrow(informal) * 100, 1)) |>
  arrange(desc(n))
tab_enf
write_csv(tab_enf, file.path(out_dir, "tab_enf_type.csv"))

# ---- State vs EPA ---------------------------------------------------------------------------------------

tab_flag <- informal |>
  count(STATE_EPA_FLAG, name = "n") |>
  mutate(pct = round(n / nrow(informal) * 100, 1)) |>
  arrange(desc(n))
tab_flag
write_csv(tab_flag, file.path(out_dir, "tab_state_epa_flag.csv"))

# ---- Official flag --------------------------------------------------------------------------------------

tab_official <- informal |>
  count(OFFICIAL_FLG, name = "n") |>
  mutate(pct = round(n / nrow(informal) * 100, 1)) |>
  arrange(desc(n))
tab_official
write_csv(tab_official, file.path(out_dir, "tab_official_flag.csv"))

# ---- Achieved date summary -----------------------------------------------------------------------------

informal$achieved_year <- as.numeric(format(as.Date(informal$ACHIEVED_DATE, format = "%m/%d/%Y"), "%Y"))

achieved_summary <- informal |>
  filter(!is.na(achieved_year)) |>
  summarise(
    n = n(),
    n_missing = sum(is.na(informal$achieved_year)),
    min = min(achieved_year),
    p5 = quantile(achieved_year, 0.05),
    p25 = quantile(achieved_year, 0.25),
    median = median(achieved_year),
    p75 = quantile(achieved_year, 0.75),
    p95 = quantile(achieved_year, 0.95),
    max = max(achieved_year)
  )
achieved_summary
write_csv(achieved_summary, file.path(out_dir, "achieved_year_summary.csv"))

# ---- Cross-tab: activity type × facility classification ------------------------------------------------

inf_class <- informal |>
  left_join(
    facilities |> select(PGM_SYS_ID, AIR_POLLUTANT_CLASS_CODE),
    by = "PGM_SYS_ID"
  ) |>
  count(ACTIVITY_TYPE_CODE, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(ACTIVITY_TYPE_CODE, desc(n))
inf_class
write_csv(inf_class, file.path(out_dir, "xtab_activity_by_classification.csv"))

# ---- Cross-tab: enforcement type × state/EPA flag ------------------------------------------------------

inf_flag <- informal |>
  count(ENF_TYPE_CODE, STATE_EPA_FLAG, name = "n") |>
  arrange(ENF_TYPE_CODE, desc(n))
inf_flag
write_csv(inf_flag, file.path(out_dir, "xtab_enf_type_by_flag.csv"))
