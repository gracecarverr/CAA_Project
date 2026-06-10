# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
actions    <- read_csv(file.path(icis_dir, "ICIS-AIR_FORMAL_ACTIONS.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/formal-actions"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(actions)
ncol(actions)
names(actions)
n_distinct(actions$PGM_SYS_ID)

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

nrow(penalties)
summary(penalties$PENALTY_AMOUNT)
write_csv(penalties |> select(PGM_SYS_ID, ENF_TYPE_DESC, PENALTY_AMOUNT, SETTLEMENT_ENTERED_DATE),
          file.path(out_dir, "penalties_nonzero.csv"))

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
