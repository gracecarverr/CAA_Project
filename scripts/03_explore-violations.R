# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
violations <- read_csv(file.path(icis_dir, "ICIS-AIR_VIOLATION_HISTORY.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/violations"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(violations)
ncol(violations)
names(violations)
n_distinct(violations$PGM_SYS_ID)

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
