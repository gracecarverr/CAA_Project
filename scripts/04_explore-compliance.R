# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
compliance <- read_csv(file.path(icis_dir, "ICIS-AIR_FCES_PCES.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/compliance"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(compliance)
ncol(compliance)
names(compliance)
n_distinct(compliance$PGM_SYS_ID)

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
