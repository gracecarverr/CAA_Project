# =========================================================================================================
# 12_title_v_utility_panel.R
#
# PURPOSE
#   Build a balanced facility-year panel of Title V electric-utility facilities for 2016-2025,
#   with annual compliance, monitoring, violation, and enforcement variables. This is the core
#   sample-construction script for the enforcement analysis.
#
# INPUTS  (data/raw/ICIS-AIR_downloads/, the current EPA ICIS-Air bulk download)
#   ICIS-AIR_PROGRAMS.csv          Title V enrollment + enrollment dates
#   ICIS-AIR_FACILITIES.csv        industry codes, location, operating status (current snapshot)
#   ICIS-AIR_TITLEV_CERTS.csv      annual Title V compliance certifications
#   ICIS-AIR_FCES_PCES.csv         compliance evaluations / inspections (FCE, PCE)
#   ICIS-AIR_VIOLATION_HISTORY.csv violations (HPV, FRV)
#   ICIS-AIR_FORMAL_ACTIONS.csv    formal enforcement (orders, civil actions, penalties)
#   ICIS-AIR_INFORMAL_ACTIONS.csv  informal enforcement (NOVs, warning letters)
#   ICIS-AIR_STACK_TESTS.csv       emissions stack tests (pass/fail)
#
# OUTPUT
#   data/derived/title_v_utility_panel.csv   one row per facility-year (1,082 facilities x 10 years)
#
# KEY DESIGN CHOICES (see inline comments for the reasoning behind each)
#   - Sample selected on PRE-PERIOD characteristics only (Title V enrolled before 2016) to avoid
#     selecting on outcomes realized during the panel window.
#   - NO operating-status filter, to avoid survivorship bias from the current-snapshot status field.
#   - "Continuously present" = has at least one ICIS-Air event in every one of the 10 years. This is
#     the strongest sample restriction and its selection threat is documented at Step 3.
#
# Paths are resolved with here::here(), which anchors on the project's .git directory, so this
# script runs unchanged from any working directory and on any machine that has the repo.
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)      # project-root-relative paths (replaces hardcoded setwd)
library(readr)
library(dplyr)
library(lubridate)
library(tidyr)

raw <- here("data/raw/ICIS-AIR_downloads")   # all raw inputs live here

# ---- Step 1: Build candidate facility roster ------------------------------------------------------------
# Selection is based entirely on PRE-PERIOD characteristics, so that nothing about a facility's
# 2016-2025 compliance/enforcement history can affect whether it enters the sample:
#   1. Title V permit enrolled before 2016-01-01 (pre-determined relative to the panel window).
#   2. Electric utility industry classification (NAICS 2211 or SIC 4911/4931/4932/4939).
#   3. NO operating-status filter. AIR_OPERATING_STATUS_CODE reflects status in the *current*
#      download, not status during 2016-2025; filtering on it would drop facilities that operated
#      and were regulated during the window but have since closed -> survivorship bias.

programs <- read_csv(file.path(raw, "ICIS-AIR_PROGRAMS.csv"), show_col_types = FALSE)
title_v_pre <- programs |>
  filter(PROGRAM_CODE == "CAATVP") |>
  mutate(tv_begin = mdy(BEGIN_DATE)) |>
  filter(tv_begin < as.Date("2016-01-01")) |>
  distinct(PGM_SYS_ID) |>
  pull(PGM_SYS_ID)
cat("Title V facilities enrolled before 2016:", length(title_v_pre), "\n")

facilities <- read_csv(file.path(raw, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# Electric utilities are identified by EITHER classification system because the source populates
# them inconsistently: some records carry only a NAICS code, others only a legacy SIC code. Using
# both (OR) avoids dropping utilities that happen to be coded in only one system.
#   NAICS 2211  = Electric Power Generation, Transmission and Distribution
#   SIC  4911   = Electric Services; 4931 = Electric & Other Services Combined;
#                 4932 = Gas & Other Services Combined; 4939 = Combination Utilities NEC
utilities <- facilities |>
  filter(
    grepl("2211", NAICS_CODES) | grepl("4911|4931|4932|4939", SIC_CODES)
  )
cat("Electric utility facilities (NAICS 2211 or SIC 4911/4931/4932/4939):", nrow(utilities), "\n")

candidates <- utilities |> filter(PGM_SYS_ID %in% title_v_pre)
cat("Title V (pre-2016) electric utilities:", nrow(candidates), "\n")

cat("Operating status distribution:\n")
candidates |> count(AIR_OPERATING_STATUS_CODE, AIR_OPERATING_STATUS_DESC, sort = TRUE) |> print()

candidate_ids <- candidates$PGM_SYS_ID

# ---- Step 2: Parse all event dates ---------------------------------------------------------------------
# Read each event table, keep only candidate facilities, parse the relevant date to a calendar year,
# and keep events in the 2016-2025 window. All ICIS-Air dates are stored as m/d/Y strings, hence mdy().
# Each table is filtered to candidate_ids on read so we never carry the full national file further.

# Title V certifications — annual compliance certification the facility files itself.
certs <- read_csv(file.path(raw, "ICIS-AIR_TITLEV_CERTS.csv"), show_col_types = FALSE) |>
  filter(PGM_SYS_ID %in% candidate_ids) |>
  mutate(year = year(mdy(ACTUAL_END_DATE))) |>
  filter(year >= 2016, year <= 2025)

# Compliance evaluations (inspections): FCEs (full) and PCEs (partial).
evals <- read_csv(file.path(raw, "ICIS-AIR_FCES_PCES.csv"), show_col_types = FALSE) |>
  filter(PGM_SYS_ID %in% candidate_ids) |>
  mutate(year = year(mdy(ACTUAL_END_DATE))) |>
  filter(year >= 2016, year <= 2025)

# Violations. There is no single violation-date column, so we date each violation by HPV_DAYZERO_DATE
# (the "day zero" of a High Priority Violation) and fall back to EARLIEST_FRV_DETERM_DATE for Federally
# Reportable Violations that never became HPVs. CAVEAT: ~9.7% of violation rows have neither date and
# are dropped here (they cannot be assigned to a year). Those dateless rows are disproportionately FRVs
# and concentrated in a few states (notably Michigan), so violation counts are a mild LOWER BOUND.
# hpv_resolved_date is parsed separately for the n_hpv_resolved measure built in Step 5.
viols <- read_csv(file.path(raw, "ICIS-AIR_VIOLATION_HISTORY.csv"), show_col_types = FALSE) |>
  filter(PGM_SYS_ID %in% candidate_ids) |>
  mutate(
    viol_date = coalesce(mdy(HPV_DAYZERO_DATE), mdy(EARLIEST_FRV_DETERM_DATE)),
    hpv_resolved_date = mdy(HPV_RESOLVED_DATE),
    year = year(viol_date)
  ) |>
  filter(year >= 2016, year <= 2025)

# Formal enforcement actions (administrative orders, civil judicial actions, penalty assessments).
# CAVEAT: dated by SETTLEMENT_ENTERED_DATE, i.e. when the action RESOLVED, not when enforcement began
# (ICIS-Air provides no initiation date). A violation found in year t may surface here as a formal
# action several years later. Treat formal actions as an OUTCOME (did a case resolve?) rather than a
# clean t-1 enforcement signal; lag-based "deterrence" tests on this variable are biased by that delay.
formal <- read_csv(file.path(raw, "ICIS-AIR_FORMAL_ACTIONS.csv"), show_col_types = FALSE) |>
  filter(PGM_SYS_ID %in% candidate_ids) |>
  mutate(
    year = year(mdy(SETTLEMENT_ENTERED_DATE)),
    penalty = as.numeric(PENALTY_AMOUNT)
  ) |>
  filter(year >= 2016, year <= 2025)

# Informal enforcement actions (notices of violation, warning letters). Dated by ACHIEVED_DATE, which
# is closer to real-time contact than the formal settlement date and is the better near-term signal.
informal <- read_csv(file.path(raw, "ICIS-AIR_INFORMAL_ACTIONS.csv"), show_col_types = FALSE) |>
  filter(PGM_SYS_ID %in% candidate_ids) |>
  mutate(year = year(mdy(ACHIEVED_DATE))) |>
  filter(year >= 2016, year <= 2025)

# Stack tests (direct emissions measurements; status pass/fail/etc.).
stack <- read_csv(file.path(raw, "ICIS-AIR_STACK_TESTS.csv"), show_col_types = FALSE) |>
  filter(PGM_SYS_ID %in% candidate_ids) |>
  mutate(year = year(mdy(ACTUAL_END_DATE))) |>
  filter(year >= 2016, year <= 2025)

# ---- Step 3: Determine continuous presence --------------------------------------------------------------
# "Continuously present" = the facility has at least one ICIS-Air event of ANY type (certification,
# inspection, violation, formal or informal action, or stack test) in EVERY one of the 10 years.
#
# Why activity-based rather than status-based: ICIS-Air has no facility-year operating record, so the
# only evidence a facility was an active, regulated source in a given year is that it generated some
# regulatory event. Pooling all six event types is the most permissive reasonable presence test.
#
# THREAT TO IDENTIFICATION (the main one for this sample): the 10/10 requirement drops ~49% of
# candidates, and the drops are NOT random. Facilities with gaps are disproportionately minor /
# synthetic-minor sources and are concentrated in particular states (e.g. Texas, which reports to
# ICIS-Air less consistently). The surviving panel therefore over-represents large major sources in
# states with dense regulatory activity, which limits external validity. Reported as a robustness
# concern; an unbalanced-panel version (>=N of 10 years) is the natural sensitivity check.

all_activity <- bind_rows(
  certs |> select(PGM_SYS_ID, year),
  evals |> select(PGM_SYS_ID, year),
  viols |> select(PGM_SYS_ID, year),
  formal |> select(PGM_SYS_ID, year),
  informal |> select(PGM_SYS_ID, year),
  stack |> select(PGM_SYS_ID, year)
) |> distinct()

year_coverage <- all_activity |>
  group_by(PGM_SYS_ID) |>
  summarise(n_years = n_distinct(year), .groups = "drop")

cat("\nYear coverage distribution among candidates:\n")
print(table(year_coverage$n_years))

# Candidates with no activity at all in 2016-2025 (appear in zero event tables for the window).
no_activity <- setdiff(candidate_ids, year_coverage$PGM_SYS_ID)
cat("Candidates with zero events in 2016-2025:", length(no_activity), "\n")

balanced_ids <- year_coverage |>
  filter(n_years == 10) |>
  pull(PGM_SYS_ID)

cat("\nFacilities surviving balanced filter:", length(balanced_ids), "of", length(candidate_ids), "\n")
cat("Dropped:", length(candidate_ids) - length(balanced_ids), "\n")

# ---- Step 4: Create balanced skeleton -------------------------------------------------------------------
# expand_grid gives the complete facility x year rectangle (no gaps). Time-invariant facility
# attributes are attached once here; all time-varying event measures are merged in Step 5. Operating
# status is carried through as a descriptive attribute (NOT a filter — see Step 1).

skeleton <- expand_grid(PGM_SYS_ID = balanced_ids, year = 2016:2025)

static <- candidates |>
  filter(PGM_SYS_ID %in% balanced_ids) |>
  select(PGM_SYS_ID, REGISTRY_ID, FACILITY_NAME, STREET_ADDRESS, CITY, STATE,
         AIR_POLLUTANT_CLASS_CODE, AIR_OPERATING_STATUS_CODE, NAICS_CODES, SIC_CODES)

panel <- skeleton |> left_join(static, by = "PGM_SYS_ID")

# ---- Step 5: Merge event data (aggregated to facility-year) --------------------------------------------
# Each event table is collapsed to one row per facility-year (counts + 0/1 indicators) and left-joined
# onto the skeleton. Facility-years with no matching event become NA on join and are set to 0 at the
# end of this step (a non-event is a true zero, not missing data).

# Evaluations. NOTE on the FCE/PCE split: COMP_MONITOR_TYPE_CODE does NOT contain the literal strings
# "FCE"/"PCE", so a substring match (grepl("FCE", .)) silently returns zero — a bug we hit earlier.
# The actual codes are: FCE = FOO (on-site) and FFO (off-site); PCE = the nine "P*" codes below.
fce_codes <- c("FOO", "FFO")
pce_codes <- c("PCE", "PFF", "PFR", "POC", "POF", "POI", "POM", "POR", "POV")
eval_agg <- evals |>
  filter(PGM_SYS_ID %in% balanced_ids) |>
  group_by(PGM_SYS_ID, year) |>
  summarise(
    n_eval_total = n(),
    n_fce = sum(COMP_MONITOR_TYPE_CODE %in% fce_codes, na.rm = TRUE),
    n_pce = sum(COMP_MONITOR_TYPE_CODE %in% pce_codes, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(any_eval = 1L, any_fce = as.integer(n_fce > 0))

# Violations
viol_agg <- viols |>
  filter(PGM_SYS_ID %in% balanced_ids) |>
  group_by(PGM_SYS_ID, year) |>
  summarise(
    n_violations = n(),
    n_hpv = sum(ENF_RESPONSE_POLICY_CODE == "HPV", na.rm = TRUE),
    n_frv = sum(ENF_RESPONSE_POLICY_CODE == "FRV", na.rm = TRUE),
    n_hpv_resolved = sum(!is.na(hpv_resolved_date) & year(hpv_resolved_date) == year, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(any_violation = 1L, any_hpv = as.integer(n_hpv > 0))

# Title V certifications
cert_agg <- certs |>
  filter(PGM_SYS_ID %in% balanced_ids) |>
  group_by(PGM_SYS_ID, year) |>
  summarise(
    n_certs = n(),
    any_deviation = as.integer(any(FACILITY_RPT_DEVIATION_FLAG == "Y", na.rm = TRUE)),
    .groups = "drop"
  ) |>
  mutate(any_cert = 1L)

# Formal enforcement actions
formal_agg <- formal |>
  filter(PGM_SYS_ID %in% balanced_ids) |>
  group_by(PGM_SYS_ID, year) |>
  summarise(
    n_formal_actions = n(),
    n_penalty_actions = sum(penalty > 0, na.rm = TRUE),
    total_penalty = sum(penalty, na.rm = TRUE),
    max_penalty = max(penalty, na.rm = TRUE),
    any_epa_formal = as.integer(any(STATE_EPA_FLAG == "E", na.rm = TRUE)),
    .groups = "drop"
  ) |>
  mutate(
    any_formal_action = 1L,
    max_penalty = ifelse(is.infinite(max_penalty), 0, max_penalty)
  )

# Informal enforcement actions
informal_agg <- informal |>
  filter(PGM_SYS_ID %in% balanced_ids) |>
  group_by(PGM_SYS_ID, year) |>
  summarise(
    n_informal_actions = n(),
    n_nov = sum(ENF_TYPE_CODE == "NOV", na.rm = TRUE),
    n_warning_letters = sum(ENF_TYPE_CODE == "DAWL", na.rm = TRUE),
    any_epa_informal = as.integer(any(STATE_EPA_FLAG == "E", na.rm = TRUE)),
    .groups = "drop"
  ) |>
  mutate(any_informal_action = 1L)

# Stack tests
stack_agg <- stack |>
  filter(PGM_SYS_ID %in% balanced_ids) |>
  group_by(PGM_SYS_ID, year) |>
  summarise(
    n_stack_tests = n(),
    n_stack_fail = sum(AIR_STACK_TEST_STATUS_CODE == "FAI", na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(any_stack_test = 1L, any_stack_fail = as.integer(n_stack_fail > 0))

# Left-join every aggregate onto the full skeleton. A facility-year absent from an event table yields
# NA in that table's columns; those NAs are genuine zeros (the facility had no such event that year),
# so they are filled with 0 below. This is what makes the panel a true balanced rectangle.
panel <- panel |>
  left_join(eval_agg, by = c("PGM_SYS_ID", "year")) |>
  left_join(viol_agg, by = c("PGM_SYS_ID", "year")) |>
  left_join(cert_agg, by = c("PGM_SYS_ID", "year")) |>
  left_join(formal_agg, by = c("PGM_SYS_ID", "year")) |>
  left_join(informal_agg, by = c("PGM_SYS_ID", "year")) |>
  left_join(stack_agg, by = c("PGM_SYS_ID", "year"))

count_cols <- c("n_eval_total", "n_fce", "n_pce", "any_eval", "any_fce",
                "n_violations", "n_hpv", "n_frv", "n_hpv_resolved",
                "any_violation", "any_hpv",
                "n_certs", "any_cert", "any_deviation",
                "n_formal_actions", "n_penalty_actions", "total_penalty", "max_penalty",
                "any_formal_action", "any_epa_formal",
                "n_informal_actions", "n_nov", "n_warning_letters",
                "any_informal_action", "any_epa_informal",
                "n_stack_tests", "n_stack_fail", "any_stack_test", "any_stack_fail")
panel <- panel |> mutate(across(all_of(count_cols), ~replace_na(.x, 0L)))

# ---- Step 6: Validation --------------------------------------------------------------------------------

n_facilities <- n_distinct(panel$PGM_SYS_ID)
cat("\n=== PANEL VALIDATION ===\n")
cat("Facilities:", n_facilities, "\n")
cat("Years: 2016-2025 (10)\n")
cat("Total rows:", nrow(panel), "\n")
cat("Expected rows:", n_facilities * 10, "\n")
cat("Balanced:", nrow(panel) == n_facilities * 10, "\n")

cat("\nState distribution:\n")
panel |> distinct(PGM_SYS_ID, STATE) |> count(STATE, sort = TRUE) |> print(n = 20)

cat("\nYear-level summaries:\n")
panel |>
  group_by(year) |>
  summarise(
    facilities = n(),
    pct_any_eval = round(mean(any_eval) * 100, 1),
    pct_any_violation = round(mean(any_violation) * 100, 1),
    pct_any_cert = round(mean(any_cert) * 100, 1),
    pct_any_deviation = round(mean(any_deviation) * 100, 1),
    pct_any_formal = round(mean(any_formal_action) * 100, 1),
    pct_any_informal = round(mean(any_informal_action) * 100, 1),
    mean_total_penalty = round(mean(total_penalty), 0),
    pct_any_stack = round(mean(any_stack_test) * 100, 1),
    .groups = "drop"
  ) |> print(n = 10)

cat("\nSample facility names:\n")
panel |> distinct(PGM_SYS_ID, FACILITY_NAME) |> slice_head(n = 10) |> print()

# ---- Save ----------------------------------------------------------------------------------------------
# Derived data only — raw inputs are never modified. dir.create is a no-op if the folder already
# exists, so a fresh clone (which ships data/raw/ but not data/derived/) still runs end-to-end.

dir.create(here("data/derived"), showWarnings = FALSE, recursive = TRUE)
write_csv(panel, here("data/derived/title_v_utility_panel.csv"))
cat("\nPanel saved to", here("data/derived/title_v_utility_panel.csv"), "\n")
