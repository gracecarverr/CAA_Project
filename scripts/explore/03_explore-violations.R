# =========================================================================================================
# 03_explore-violations.R — exploratory profiling of ICIS-AIR_VIOLATION_HISTORY.
# Tabulates enforcement-response codes, agency types, cross-tabs; writes CSVs to output/explore_tabulations/violations/.
# Exploratory only — not part of the analysis pipeline. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# here() anchors on the project's .git directory, so paths resolve from any working directory.

icis_dir <- here("data/raw/ICIS-AIR_downloads")
violations <- read_csv(file.path(icis_dir, "ICIS-AIR_VIOLATION_HISTORY.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- here("output/explore_tabulations/violations")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(violations)
ncol(violations)
names(violations)
n_distinct(violations$PGM_SYS_ID)

# ---- Overview ------------------------------------------------------------------------------------------

overview <- data.frame(
  n_obs = nrow(violations),
  n_distinct_facilities = n_distinct(violations$PGM_SYS_ID)
)
overview
write_csv(overview, file.path(out_dir, "overview.csv"))

# ---- Missingness ----------------------------------------------------------------------------------------

miss <- data.frame(
  field = names(violations),
  n_missing = sapply(violations, function(x) sum(is.na(x)))
)
miss$pct <- round(miss$n_missing / nrow(violations) * 100, 1)
miss
write_csv(miss, file.path(out_dir, "missingness.csv"))

# ---- Agency type ----------------------------------------------------------------------------------------

tab_agency <- violations |>
  count(AGENCY_TYPE_DESC, name = "n") |>
  mutate(pct = round(n / nrow(violations) * 100, 1)) |>
  arrange(desc(n))
tab_agency
write_csv(tab_agency, file.path(out_dir, "tab_agency_type.csv"))

# ---- Enforcement response policy (FRV vs HPV) ----------------------------------------------------------

tab_enf <- violations |>
  count(ENF_RESPONSE_POLICY_CODE, name = "n") |>
  mutate(pct = round(n / nrow(violations) * 100, 1)) |>
  arrange(desc(n))
tab_enf
write_csv(tab_enf, file.path(out_dir, "tab_enf_response.csv"))

# ---- Program codes --------------------------------------------------------------------------------------
# Note: PROGRAM_CODES can contain multiple codes separated by commas

tab_programs <- violations |>
  count(PROGRAM_CODES, name = "n") |>
  mutate(pct = round(n / nrow(violations) * 100, 1)) |>
  arrange(desc(n))
tab_programs
write_csv(tab_programs, file.path(out_dir, "tab_program_codes.csv"))

# ---- State ----------------------------------------------------------------------------------------------

tab_state <- violations |>
  count(STATE_CODE, name = "n") |>
  mutate(pct = round(n / nrow(violations) * 100, 1)) |>
  arrange(desc(n))
tab_state
write_csv(tab_state, file.path(out_dir, "tab_state.csv"))

# ---- HPV resolution status ------------------------------------------------------------------------------
# HPV_DAYZERO_DATE present = HPV violation. Check how many are resolved.

n_hpv <- sum(!is.na(violations$HPV_DAYZERO_DATE))
n_hpv_resolved <- sum(!is.na(violations$HPV_DAYZERO_DATE) & !is.na(violations$HPV_RESOLVED_DATE))
n_hpv_unresolved <- n_hpv - n_hpv_resolved

data.frame(
  status = c("HPV total", "HPV resolved", "HPV unresolved", "FRV only (no HPV date)"),
  n = c(n_hpv, n_hpv_resolved, n_hpv_unresolved, nrow(violations) - n_hpv)
)

# ---- Local control region code -------------------------------------------------------------------------

tab_lcon <- violations |>
  count(AIR_LCON_CODE, name = "n") |>
  mutate(pct = round(n / nrow(violations) * 100, 1)) |>
  arrange(desc(n))
tab_lcon
write_csv(tab_lcon, file.path(out_dir, "tab_lcon_code.csv"))

# ---- Pollutant codes -----------------------------------------------------------------------------------

tab_pollutants <- violations |>
  count(POLLUTANT_CODES, name = "n") |>
  mutate(pct = round(n / nrow(violations) * 100, 1)) |>
  arrange(desc(n))
tab_pollutants
write_csv(tab_pollutants, file.path(out_dir, "tab_pollutant_codes.csv"))

# ---- Date summaries ------------------------------------------------------------------------------------

parse_year <- function(x) as.numeric(format(as.Date(x, format = "%m-%d-%Y"), "%Y"))

date_fields <- c("EARLIEST_FRV_DETERM_DATE", "HPV_DAYZERO_DATE",
                  "HPV_RESOLVED_DATE", "DSCV_PATHWAY_DATE", "NFTC_PATHWAY_DATE")

date_summaries <- lapply(date_fields, function(f) {
  yr <- parse_year(violations[[f]])
  valid <- yr[!is.na(yr)]
  data.frame(
    field = f,
    n = length(valid),
    n_missing = sum(is.na(yr)),
    min = if (length(valid) > 0) min(valid) else NA,
    p5 = if (length(valid) > 0) quantile(valid, 0.05) else NA,
    p25 = if (length(valid) > 0) quantile(valid, 0.25) else NA,
    median = if (length(valid) > 0) median(valid) else NA,
    p75 = if (length(valid) > 0) quantile(valid, 0.75) else NA,
    p95 = if (length(valid) > 0) quantile(valid, 0.95) else NA,
    max = if (length(valid) > 0) max(valid) else NA
  )
}) |> bind_rows()

date_summaries
write_csv(date_summaries, file.path(out_dir, "date_summaries.csv"))

# ---- Cross-tab: enforcement response × facility classification -----------------------------------------

viol_class <- violations |>
  left_join(
    facilities |> select(PGM_SYS_ID, AIR_POLLUTANT_CLASS_CODE),
    by = "PGM_SYS_ID"
  ) |>
  count(ENF_RESPONSE_POLICY_CODE, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(ENF_RESPONSE_POLICY_CODE, desc(n))
viol_class
write_csv(viol_class, file.path(out_dir, "xtab_enf_by_classification.csv"))

# ---- Cross-tab: enforcement response × agency type ----------------------------------------------------

viol_agency <- violations |>
  count(ENF_RESPONSE_POLICY_CODE, AGENCY_TYPE_DESC, name = "n") |>
  arrange(ENF_RESPONSE_POLICY_CODE, desc(n))
viol_agency
write_csv(viol_agency, file.path(out_dir, "xtab_enf_by_agency.csv"))
