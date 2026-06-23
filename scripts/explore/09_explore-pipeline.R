# =========================================================================================================
# 09_explore-pipeline.R — exploratory profiling of the assembled PIPELINE_CAA_00_COMPLETE dataset
# (the merged cross-table pipeline file), cross-referenced against ICIS-AIR_FACILITIES. Writes CSVs to
# output/explore/pipeline/. Exploratory only — not part of the analysis pipeline. Paths via here::here().
# =========================================================================================================

library(here)
library(readr)
library(dplyr)
library(lubridate)
library(tidyr)

# here() anchors on the project's .git directory, so paths resolve from any working directory.
out_dir <- here("output/explore/pipeline")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

pipe <- read_csv(here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"), show_col_types = FALSE)

# ============================================================================================
# 1. DIMENSIONS AND STRUCTURE
# ============================================================================================

cat("====== DIMENSIONS ======\n")
cat("Rows:", nrow(pipe), "\n")
cat("Columns:", ncol(pipe), "\n")
cat("Column names:\n")
cat(paste(" ", names(pipe)), sep = "\n")

# ============================================================================================
# 2. UNIT OF OBSERVATION
# ============================================================================================

cat("\n====== UNIT OF OBSERVATION ======\n")
cat("Distinct SOURCE_ID:", n_distinct(pipe$SOURCE_ID), "\n")
cat("Distinct REGISTRY_ID:", n_distinct(pipe$REGISTRY_ID), "\n")
cat("Distinct VIOL_ACTIVITY_ID:", n_distinct(pipe$VIOL_ACTIVITY_ID), "\n")
cat("Distinct EA_ACTIVITY_ID:", n_distinct(pipe$EA_ACTIVITY_ID), "\n")
cat("Distinct EVAL_ACTIVITY_ID:", n_distinct(pipe$EVAL_ACTIVITY_ID), "\n")

cat("\n--- Testing candidate keys ---\n")
cat("VIOL_ACTIVITY_ID alone unique?",
    n_distinct(pipe$VIOL_ACTIVITY_ID) == nrow(pipe), "\n")
cat("VIOL_ACTIVITY_ID + EA_ACTIVITY_ID unique?",
    nrow(distinct(pipe, VIOL_ACTIVITY_ID, EA_ACTIVITY_ID)) == nrow(pipe), "\n")
cat("VIOL_ACTIVITY_ID + EA_ACTIVITY_ID + EVAL_ACTIVITY_ID unique?",
    nrow(distinct(pipe, VIOL_ACTIVITY_ID, EA_ACTIVITY_ID, EVAL_ACTIVITY_ID)) == nrow(pipe), "\n")

cat("\n--- Rows per SOURCE_ID ---\n")
rows_per_source <- pipe |> count(SOURCE_ID, name = "n_rows")
cat("Mean:", round(mean(rows_per_source$n_rows), 1), "\n")
cat("Median:", median(rows_per_source$n_rows), "\n")
cat("Max:", max(rows_per_source$n_rows), "\n")
print(quantile(rows_per_source$n_rows, c(0.25, 0.5, 0.75, 0.9, 0.95, 0.99)))

cat("\n--- Rows per VIOL_ACTIVITY_ID (how many EA/EVAL per violation) ---\n")
rows_per_viol <- pipe |> count(VIOL_ACTIVITY_ID, name = "n_rows")
cat("Mean:", round(mean(rows_per_viol$n_rows), 1), "\n")
cat("Median:", median(rows_per_viol$n_rows), "\n")
cat("Max:", max(rows_per_viol$n_rows), "\n")
print(table(rows_per_viol$n_rows))

# ============================================================================================
# 3. FLAGS: WHAT EACH ROW CONTAINS
# ============================================================================================

cat("\n====== FLAGS ======\n")
cat("PIPELINE_FLAG (violation still in the enforcement pipeline):\n")
print(table(pipe$PIPELINE_FLAG, useNA = "always"))

cat("\nFOUND_VIOLATION:\n")
print(table(pipe$FOUND_VIOLATION, useNA = "always"))

cat("\nOFFICIAL_FLAG:\n")
print(table(pipe$OFFICIAL_FLAG, useNA = "always"))

cat("\nEVAL_FLAG (evaluation linked to this violation):\n")
print(table(pipe$EVAL_FLAG, useNA = "always"))

cat("\nVIOL_FLAG:\n")
print(table(pipe$VIOL_FLAG, useNA = "always"))

cat("\nEA_FLAG (enforcement action linked):\n")
print(table(pipe$EA_FLAG, useNA = "always"))

cat("\nFEA_ISSUE_DATE_FLAG:\n")
print(table(pipe$FEA_ISSUE_DATE_FLAG, useNA = "always"))

cat("\n--- Cross-tabulation: EVAL_FLAG x EA_FLAG ---\n")
print(table(EVAL = pipe$EVAL_FLAG, EA = pipe$EA_FLAG))

cat("\n--- Cross-tabulation: PIPELINE_FLAG x EA_FLAG ---\n")
print(table(PIPELINE = pipe$PIPELINE_FLAG, EA = pipe$EA_FLAG))

# ============================================================================================
# 4. VIOLATION CHARACTERISTICS
# ============================================================================================

cat("\n====== VIOLATION CHARACTERISTICS ======\n")

cat("VIOL_TYPE:\n")
pipe |> count(VIOL_TYPE, sort = TRUE) |> print(n = 10)

cat("\nVIOL_LEAD_AGENCY:\n")
pipe |> count(VIOL_LEAD_AGENCY, sort = TRUE) |> print(n = 10)

cat("\nVIOL_PROGRAMS (top 15):\n")
pipe |> count(VIOL_PROGRAMS, sort = TRUE) |> print(n = 15)

cat("\nVIOL_POLLUTANT_CODES (top 15, non-blank):\n")
pipe |> filter(VIOL_POLLUTANT_CODES != "") |>
  count(VIOL_POLLUTANT_CODES, sort = TRUE) |> print(n = 15)

# ============================================================================================
# 5. EVALUATION CHARACTERISTICS (where linked)
# ============================================================================================

cat("\n====== EVALUATIONS (EVAL_FLAG == Y) ======\n")
evals_linked <- pipe |> filter(EVAL_FLAG == "Y")
cat("Rows with linked evaluation:", nrow(evals_linked), "\n")

cat("\nEVAL_TYPE_DESC:\n")
evals_linked |> count(EVAL_TYPE_DESC, sort = TRUE) |> print(n = 15)

cat("\nEVAL_LEAD_AGENCY:\n")
evals_linked |> count(EVAL_LEAD_AGENCY, sort = TRUE) |> print(n = 10)

# ============================================================================================
# 6. ENFORCEMENT ACTION CHARACTERISTICS (where linked)
# ============================================================================================

cat("\n====== ENFORCEMENT ACTIONS (EA_FLAG == Y) ======\n")
ea_linked <- pipe |> filter(EA_FLAG == "Y")
cat("Rows with linked enforcement action:", nrow(ea_linked), "\n")

cat("\nEA_TYPE:\n")
ea_linked |> count(EA_TYPE, sort = TRUE) |> print(n = 15)

cat("\nEA_PENALTY_AMT distribution (non-missing, non-zero):\n")
penalties <- ea_linked |> filter(!is.na(EA_PENALTY_AMT), EA_PENALTY_AMT > 0)
cat("  N:", nrow(penalties), "\n")
cat("  Mean: $", round(mean(penalties$EA_PENALTY_AMT), 0), "\n")
cat("  Median: $", round(median(penalties$EA_PENALTY_AMT), 0), "\n")
cat("  P25: $", round(quantile(penalties$EA_PENALTY_AMT, 0.25), 0), "\n")
cat("  P75: $", round(quantile(penalties$EA_PENALTY_AMT, 0.75), 0), "\n")
cat("  P95: $", round(quantile(penalties$EA_PENALTY_AMT, 0.95), 0), "\n")
cat("  Max: $", round(max(penalties$EA_PENALTY_AMT), 0), "\n")

cat("\nEA_COMP_ACTION_COST distribution (non-missing, non-zero):\n")
comp_costs <- ea_linked |> filter(!is.na(EA_COMP_ACTION_COST), EA_COMP_ACTION_COST > 0)
cat("  N:", nrow(comp_costs), "\n")
if (nrow(comp_costs) > 0) {
  cat("  Mean: $", round(mean(comp_costs$EA_COMP_ACTION_COST), 0), "\n")
  cat("  Median: $", round(median(comp_costs$EA_COMP_ACTION_COST), 0), "\n")
  cat("  Max: $", round(max(comp_costs$EA_COMP_ACTION_COST), 0), "\n")
}

# ============================================================================================
# 7. DATES AND TEMPORAL COVERAGE
# ============================================================================================

cat("\n====== TEMPORAL COVERAGE ======\n")

pipe <- pipe |> mutate(
  sort_dt = mdy(SORT_DATE),
  viol_start_dt = mdy(VIOL_START_DATE),
  viol_end_dt = mdy(VIOL_END_DATE_DATE),
  eval_dt = mdy(EVAL_DATE),
  ea_dt = mdy(EA_DATE),
  sort_year = year(sort_dt),
  viol_start_year = year(viol_start_dt)
)

cat("SORT_DATE range:", as.character(min(pipe$sort_dt, na.rm = TRUE)), "to",
    as.character(max(pipe$sort_dt, na.rm = TRUE)), "\n")
cat("VIOL_START_DATE range:", as.character(min(pipe$viol_start_dt, na.rm = TRUE)), "to",
    as.character(max(pipe$viol_start_dt, na.rm = TRUE)), "\n")

cat("\nViolations by start year:\n")
pipe |> filter(!is.na(viol_start_year)) |>
  count(viol_start_year) |> print(n = 30)

cat("\nDate missingness:\n")
cat("  SORT_DATE missing:", sum(is.na(pipe$sort_dt)), "\n")
cat("  VIOL_START_DATE missing:", sum(is.na(pipe$viol_start_dt)), "\n")
cat("  VIOL_END_DATE_DATE missing:", sum(is.na(pipe$viol_end_dt)), "\n")
cat("  EVAL_DATE missing:", sum(is.na(pipe$eval_dt)), "\n")
cat("  EA_DATE missing:", sum(is.na(pipe$ea_dt)), "\n")

cat("\n--- Time between violation start and enforcement action ---\n")
with_both <- pipe |> filter(!is.na(viol_start_dt), !is.na(ea_dt))
cat("Rows with both VIOL_START_DATE and EA_DATE:", nrow(with_both), "\n")
with_both <- with_both |> mutate(lag_days = as.numeric(ea_dt - viol_start_dt))
cat("Lag (days): EA_DATE - VIOL_START_DATE\n")
print(quantile(with_both$lag_days, c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1), na.rm = TRUE))
cat("Negative lags (EA before violation):", sum(with_both$lag_days < 0, na.rm = TRUE), "\n")
cat("Same-day:", sum(with_both$lag_days == 0, na.rm = TRUE), "\n")

cat("\n--- Time between violation start and end ---\n")
with_end <- pipe |> filter(!is.na(viol_start_dt), !is.na(viol_end_dt))
cat("Rows with both start and end:", nrow(with_end), "\n")
with_end <- with_end |> mutate(duration_days = as.numeric(viol_end_dt - viol_start_dt))
cat("Duration (days):\n")
print(quantile(with_end$duration_days, c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1), na.rm = TRUE))

# ============================================================================================
# 8. SORT METADATA
# ============================================================================================

cat("\n====== SORT METADATA ======\n")
cat("SORT_ORDER range:", min(pipe$SORT_ORDER), "to", max(pipe$SORT_ORDER), "\n")
cat("SORT_ORDER == row number?", all(pipe$SORT_ORDER == 1:nrow(pipe)), "\n")
cat("SORT_ORDER unique?", n_distinct(pipe$SORT_ORDER) == nrow(pipe), "\n")

cat("\nVIOL_TYPE_SORT:\n")
pipe |> count(VIOL_TYPE_SORT, sort = TRUE) |> print(n = 5)

cat("\nEVAL_SORT_ORDER:\n")
pipe |> count(EVAL_SORT_ORDER, sort = TRUE) |> print(n = 5)

cat("\nVIOL_SORT_ORDER:\n")
pipe |> count(VIOL_SORT_ORDER, sort = TRUE) |> print(n = 5)

cat("\nEA_SORT_ORDER:\n")
pipe |> count(EA_SORT_ORDER, sort = TRUE) |> print(n = 5)

# ============================================================================================
# 9. RELATIONSHIP TO ICIS-AIR TABLES
# ============================================================================================

cat("\n====== RELATIONSHIP TO ICIS-AIR ======\n")

# SOURCE_ID = PGM_SYS_ID?
facilities <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)
pipe_sources <- unique(pipe$SOURCE_ID)
fac_sources <- unique(facilities$PGM_SYS_ID)

cat("Pipeline SOURCE_IDs:", length(pipe_sources), "\n")
cat("Facilities PGM_SYS_IDs:", length(fac_sources), "\n")
cat("Pipeline SOURCE_IDs in facilities table:", sum(pipe_sources %in% fac_sources), "\n")
cat("Pipeline SOURCE_IDs NOT in facilities table:", sum(!pipe_sources %in% fac_sources), "\n")

not_in_fac <- pipe_sources[!pipe_sources %in% fac_sources]
if (length(not_in_fac) > 0) {
  cat("  Examples not found:", paste(head(not_in_fac, 5), collapse = ", "), "\n")
}

# VIOL_ACTIVITY_ID matches violation history?
viol_hist <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_VIOLATION_HISTORY.csv"), show_col_types = FALSE)
pipe_viol_ids <- unique(pipe$VIOL_ACTIVITY_ID)
hist_viol_ids <- unique(viol_hist$ACTIVITY_ID)

cat("\nPipeline VIOL_ACTIVITY_IDs:", length(pipe_viol_ids), "\n")
cat("Violation history ACTIVITY_IDs:", length(hist_viol_ids), "\n")
cat("Pipeline violations in history:", sum(pipe_viol_ids %in% hist_viol_ids), "\n")
cat("Pipeline violations NOT in history:", sum(!pipe_viol_ids %in% hist_viol_ids), "\n")
cat("History violations NOT in pipeline:", sum(!hist_viol_ids %in% pipe_viol_ids), "\n")

# EA_ACTIVITY_ID matches formal/informal actions?
formal <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_FORMAL_ACTIONS.csv"), show_col_types = FALSE)
informal <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_INFORMAL_ACTIONS.csv"), show_col_types = FALSE)
all_ea_ids <- unique(c(formal$ACTIVITY_ID, informal$ACTIVITY_ID))
pipe_ea_ids <- unique(pipe$EA_ACTIVITY_ID[pipe$EA_ACTIVITY_ID != ""])

cat("\nPipeline EA_ACTIVITY_IDs (non-blank):", length(pipe_ea_ids), "\n")
cat("Formal + informal ACTIVITY_IDs:", length(all_ea_ids), "\n")
cat("Pipeline EAs in formal/informal:", sum(pipe_ea_ids %in% all_ea_ids), "\n")
cat("Pipeline EAs NOT in formal/informal:", sum(!pipe_ea_ids %in% all_ea_ids), "\n")

# EVAL_ACTIVITY_ID matches FCEs/PCEs?
fces <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_FCES_PCES.csv"), show_col_types = FALSE)
fce_ids <- unique(fces$ACTIVITY_ID)
pipe_eval_ids <- unique(pipe$EVAL_ACTIVITY_ID[pipe$EVAL_ACTIVITY_ID != ""])

cat("\nPipeline EVAL_ACTIVITY_IDs (non-blank):", length(pipe_eval_ids), "\n")
cat("FCES_PCES ACTIVITY_IDs:", length(fce_ids), "\n")
cat("Pipeline evals in FCES_PCES:", sum(pipe_eval_ids %in% fce_ids), "\n")
cat("Pipeline evals NOT in FCES_PCES:", sum(!pipe_eval_ids %in% fce_ids), "\n")

# REGISTRY_ID overlap
pipe_reg <- unique(pipe$REGISTRY_ID)
fac_reg <- unique(facilities$REGISTRY_ID)
cat("\nPipeline REGISTRY_IDs:", length(pipe_reg), "\n")
cat("In facilities table:", sum(pipe_reg %in% fac_reg), "\n")
cat("Not in facilities table:", sum(!pipe_reg %in% fac_reg), "\n")

# ============================================================================================
# 10. WHAT THE PIPELINE ADDS OVER INDIVIDUAL ICIS-AIR TABLES
# ============================================================================================

cat("\n====== WHAT THE PIPELINE ADDS ======\n")

cat("The pipeline links violations to their triggering evaluation and resulting\n")
cat("enforcement action in a single row. This linkage is not available in the\n")
cat("individual ICIS-Air tables, which share ACTIVITY_IDs but require manual joining.\n\n")

cat("Unique fields not in other ICIS-Air tables:\n")
cat("  PIPELINE_FLAG — whether the violation is still in the enforcement pipeline\n")
cat("  SORT_ORDER / SORT_DATE — EPA's internal ordering\n")
cat("  VIOL_END_DATE — when the violation was resolved (text field, mixed format)\n")
cat("  VIOL_END_DATE_DATE — parsed date version of VIOL_END_DATE\n")
cat("  FEA_ISSUE_DATE_FLAG — flag for formal enforcement action issue date\n")
cat("  EA_FEA_ACTIVITY_ID — separate ID for formal enforcement actions\n")
cat("  EA_COMP_ACTION_COST — supplemental environmental project / compliance costs\n\n")

cat("Beyond the individual tables, the pipeline can provide:\n")
cat("  1. Violation-to-enforcement linkage (which EA responded to which violation)\n")
cat("  2. Violation resolution status (PIPELINE_FLAG, VIOL_END_DATE)\n")
cat("  3. Time-to-resolution for individual violations\n")
cat("  4. Whether a violation triggered an evaluation or vice versa\n")

# ============================================================================================
# 11. COMPLIANCE ACTION COST BY LEAD AGENCY (STATE / EPA / LOCAL)
# ============================================================================================

cat("\n====== COMPLIANCE ACTION COST BY LEAD AGENCY ======\n")

pipe <- pipe |> mutate(
  agency_group = dplyr::case_when(
    VIOL_LEAD_AGENCY == "EPA"   ~ "EPA",
    VIOL_LEAD_AGENCY == "Local" ~ "Local",
    is.na(VIOL_LEAD_AGENCY)     ~ NA_character_,
    TRUE                        ~ "State"
  ),
  cac = as.numeric(EA_COMP_ACTION_COST),
  pen = as.numeric(EA_PENALTY_AMT)
)

agency_cost <- pipe |>
  filter(!is.na(agency_group)) |>
  group_by(agency_group) |>
  summarise(
    n_rows            = n(),
    n_facilities      = n_distinct(SOURCE_ID),
    n_with_ea         = sum(EA_FLAG == "Y", na.rm = TRUE),
    n_with_penalty    = sum(pen > 0, na.rm = TRUE),
    total_penalty     = sum(pen, na.rm = TRUE),
    mean_penalty      = mean(pen[pen > 0], na.rm = TRUE),
    median_penalty    = median(pen[pen > 0], na.rm = TRUE),
    max_penalty       = max(pen, na.rm = TRUE),
    n_with_comp_cost  = sum(cac > 0, na.rm = TRUE),
    total_comp_cost   = sum(cac, na.rm = TRUE),
    mean_comp_cost    = mean(cac[cac > 0], na.rm = TRUE),
    median_comp_cost  = median(cac[cac > 0], na.rm = TRUE),
    max_comp_cost     = max(cac, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(across(where(is.numeric), ~ ifelse(is.nan(.) | is.infinite(.), NA_real_, .))) |>
  arrange(desc(n_rows))

cat("\nAgency cost summary:\n")
print(agency_cost, width = Inf)

ea_type_by_agency <- pipe |>
  filter(!is.na(agency_group), EA_FLAG == "Y", !is.na(EA_TYPE)) |>
  count(agency_group, EA_TYPE) |>
  tidyr::pivot_wider(names_from = agency_group, values_from = n, values_fill = 0) |>
  arrange(desc(rowSums(across(where(is.numeric)))))

cat("\nEA type by agency:\n")
print(ea_type_by_agency, width = Inf)

write_csv(agency_cost, file.path(out_dir, "pipeline_cost_by_agency.csv"))
write_csv(ea_type_by_agency, file.path(out_dir, "pipeline_ea_type_by_agency.csv"))

# ============================================================================================
# 12. SAVE SUMMARY
# ============================================================================================

summary_out <- pipe |>
  group_by(SOURCE_ID) |>
  summarise(
    n_rows = n(),
    n_violations = n_distinct(VIOL_ACTIVITY_ID),
    n_hpv = sum(VIOL_TYPE == "HPV", na.rm = TRUE),
    n_frv = sum(VIOL_TYPE == "FRV", na.rm = TRUE),
    n_with_ea = sum(EA_FLAG == "Y"),
    n_with_eval = sum(EVAL_FLAG == "Y"),
    n_in_pipeline = sum(PIPELINE_FLAG == "Y"),
    has_penalty = any(EA_PENALTY_AMT > 0, na.rm = TRUE),
    total_penalty = sum(EA_PENALTY_AMT, na.rm = TRUE),
    earliest_viol = min(viol_start_dt, na.rm = TRUE),
    latest_viol = max(viol_start_dt, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(summary_out, file.path(out_dir, "pipeline_by_source.csv"))

write_csv(
  pipe |>
    summarise(
      total_rows = n(),
      n_sources = n_distinct(SOURCE_ID),
      n_violations = n_distinct(VIOL_ACTIVITY_ID),
      n_with_eval = sum(EVAL_FLAG == "Y"),
      n_with_ea = sum(EA_FLAG == "Y"),
      n_in_pipeline = sum(PIPELINE_FLAG == "Y"),
      pct_hpv = round(mean(VIOL_TYPE == "HPV", na.rm = TRUE) * 100, 1),
      n_with_penalty = sum(EA_PENALTY_AMT > 0, na.rm = TRUE),
      total_penalties = sum(EA_PENALTY_AMT, na.rm = TRUE),
      date_range = paste(min(viol_start_dt, na.rm = TRUE), "to", max(viol_start_dt, na.rm = TRUE))
    ),
  file.path(out_dir, "pipeline_overview.csv")
)

cat("\nOutputs saved to:", out_dir, "\n")
