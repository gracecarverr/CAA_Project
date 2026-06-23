# =========================================================================================================
# 05_explore-formal-actions.R — exploratory profiling of ICIS-AIR_FORMAL_ACTIONS.
# Tabulates enforcement types, penalties, cross-tabs; writes CSVs to output/explore/formal-actions/.
# Exploratory only — not part of the analysis pipeline. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# here() anchors on the project's .git directory, so paths resolve from any working directory.

icis_dir <- here("data/raw/ICIS-AIR_downloads")
actions    <- read_csv(file.path(icis_dir, "ICIS-AIR_FORMAL_ACTIONS.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- here("output/explore/formal-actions")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(actions)
ncol(actions)
names(actions)
n_distinct(actions$PGM_SYS_ID)

# ---- Overview ------------------------------------------------------------------------------------------

overview <- data.frame(
  n_obs = nrow(actions),
  n_distinct_facilities = n_distinct(actions$PGM_SYS_ID)
)
overview
write_csv(overview, file.path(out_dir, "overview.csv"))

# ---- Missingness ----------------------------------------------------------------------------------------

miss <- data.frame(
  field = names(actions),
  n_missing = sapply(actions, function(x) sum(is.na(x)))
)
miss$pct <- round(miss$n_missing / nrow(actions) * 100, 1)
miss
write_csv(miss, file.path(out_dir, "missingness.csv"))

# ---- Activity type (administrative vs judicial) --------------------------------------------------------

tab_activity <- actions |>
  count(ACTIVITY_TYPE_CODE, ACTIVITY_TYPE_DESC, name = "n") |>
  mutate(pct = round(n / nrow(actions) * 100, 1)) |>
  arrange(desc(n))
tab_activity
write_csv(tab_activity, file.path(out_dir, "tab_activity_type.csv"))

# ---- Enforcement type -----------------------------------------------------------------------------------

tab_enf <- actions |>
  count(ENF_TYPE_CODE, ENF_TYPE_DESC, name = "n") |>
  mutate(pct = round(n / nrow(actions) * 100, 1)) |>
  arrange(desc(n))
tab_enf
write_csv(tab_enf, file.path(out_dir, "tab_enf_type.csv"))

# ---- State vs EPA ---------------------------------------------------------------------------------------

tab_flag <- actions |>
  count(STATE_EPA_FLAG, name = "n") |>
  mutate(pct = round(n / nrow(actions) * 100, 1)) |>
  arrange(desc(n))
tab_flag
write_csv(tab_flag, file.path(out_dir, "tab_state_epa_flag.csv"))

# ---- Penalty amounts ------------------------------------------------------------------------------------

actions$PENALTY_AMOUNT <- as.numeric(actions$PENALTY_AMOUNT)
penalties <- actions |> filter(!is.na(PENALTY_AMOUNT) & PENALTY_AMOUNT > 0)

penalty_all <- actions |>
  summarise(
    group = "all",
    n = n(),
    n_zero = sum(PENALTY_AMOUNT == 0, na.rm = TRUE),
    n_nonzero = sum(PENALTY_AMOUNT > 0, na.rm = TRUE),
    min = min(PENALTY_AMOUNT, na.rm = TRUE),
    p5 = quantile(PENALTY_AMOUNT, 0.05, na.rm = TRUE),
    p25 = quantile(PENALTY_AMOUNT, 0.25, na.rm = TRUE),
    median = median(PENALTY_AMOUNT, na.rm = TRUE),
    mean = round(mean(PENALTY_AMOUNT, na.rm = TRUE), 2),
    p75 = quantile(PENALTY_AMOUNT, 0.75, na.rm = TRUE),
    p95 = quantile(PENALTY_AMOUNT, 0.95, na.rm = TRUE),
    p99 = quantile(PENALTY_AMOUNT, 0.99, na.rm = TRUE),
    max = max(PENALTY_AMOUNT, na.rm = TRUE)
  )

penalties <- actions |> filter(!is.na(PENALTY_AMOUNT) & PENALTY_AMOUNT > 0)

penalty_nonzero <- penalties |>
  summarise(
    group = "nonzero",
    n = n(),
    n_zero = 0,
    n_nonzero = n(),
    min = min(PENALTY_AMOUNT),
    p5 = quantile(PENALTY_AMOUNT, 0.05),
    p25 = quantile(PENALTY_AMOUNT, 0.25),
    median = median(PENALTY_AMOUNT),
    mean = round(mean(PENALTY_AMOUNT), 2),
    p75 = quantile(PENALTY_AMOUNT, 0.75),
    p95 = quantile(PENALTY_AMOUNT, 0.95),
    p99 = quantile(PENALTY_AMOUNT, 0.99),
    max = max(PENALTY_AMOUNT)
  )

penalty_summary <- bind_rows(penalty_all, penalty_nonzero)
penalty_summary
write_csv(penalty_summary, file.path(out_dir, "penalty_summary.csv"))

# ---- Settlement date by year ----------------------------------------------------------------------------

actions$settlement_year <- as.numeric(format(as.Date(actions$SETTLEMENT_ENTERED_DATE, format = "%m/%d/%Y"), "%Y"))

settlement_summary <- actions |>
  filter(!is.na(settlement_year)) |>
  summarise(
    n = n(),
    n_missing = sum(is.na(actions$settlement_year)),
    min = min(settlement_year),
    p5 = quantile(settlement_year, 0.05),
    p25 = quantile(settlement_year, 0.25),
    median = median(settlement_year),
    p75 = quantile(settlement_year, 0.75),
    p95 = quantile(settlement_year, 0.95),
    max = max(settlement_year)
  )
settlement_summary
write_csv(settlement_summary, file.path(out_dir, "settlement_year_summary.csv"))

# ---- Cross-tab: activity type × facility classification ------------------------------------------------

act_class <- actions |>
  left_join(
    facilities |> select(PGM_SYS_ID, AIR_POLLUTANT_CLASS_CODE),
    by = "PGM_SYS_ID"
  ) |>
  count(ACTIVITY_TYPE_CODE, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(ACTIVITY_TYPE_CODE, desc(n))
act_class
write_csv(act_class, file.path(out_dir, "xtab_activity_by_classification.csv"))

# ---- Cross-tab: activity type × state/EPA flag ---------------------------------------------------------

act_flag <- actions |>
  count(ACTIVITY_TYPE_CODE, STATE_EPA_FLAG, name = "n") |>
  arrange(ACTIVITY_TYPE_CODE, desc(n))
act_flag
write_csv(act_flag, file.path(out_dir, "xtab_activity_by_flag.csv"))
