# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
informal   <- read_csv(file.path(icis_dir, "ICIS-AIR_INFORMAL_ACTIONS.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/informal"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(informal)
ncol(informal)
names(informal)
n_distinct(informal$PGM_SYS_ID)

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
