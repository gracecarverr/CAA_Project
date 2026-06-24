# =========================================================================================================
# 01_titlev_utility_panel_skeleton.R — build the skeleton for a fully balanced facility x year panel of
# Title V major electric-utility facilities, 2015-2025.
#
# WHAT THIS BUILDS
#   The SCAFFOLD only: one row per (facility, year) for facilities that qualify, plus time-invariant
#   facility attributes and per-year activity-type flags. Outcome / treatment variables (event counts,
#   penalties, HPV status, ...) are merged in a later script, not here.
#
# SAMPLE DEFINITION (every choice below is a parameter near the top, so it is easy to change)
#   Population : Title V *major* sources (AIR_POLLUTANT_CLASS_DESC == "Major Emissions") in the electric
#                utility industry (NAICS starting 2211 OR SIC 4911).
#   Window     : 2015-2025 (11 complete calendar years; 2026 is excluded because it is only ~half observed).
#   Inclusion  : STRICT every-year balance. A facility is kept only if it interacts with the regulatory
#                system in *every* year of the window, where an interaction is any of:
#                   evaluation, violation, enforcement action (formal or informal), or Title V certification.
#                Each kept facility therefore has exactly length(YEARS) rows -> a fully balanced rectangle.
#   Key        : PGM_SYS_ID (ICIS-Air facility id). REGISTRY_ID is carried along so the panel can later be
#                joined to other EPA systems (incl. the AFS crosswalk in scripts/explore/10_frs-crosswalk.R).
#
#   NOTE on "Title V major": operationalized as the Major Emissions class flag (TITLEV_DEF below). Switch
#   to "has_cert" (appears in TITLEV_CERTS) or "both" with the one parameter; no logic changes needed.
#
# REGULATORY-ACTIVITY SOURCES (table : date field used -> event year)
#   evaluation    ICIS-AIR_FCES_PCES.csv          : ACTUAL_END_DATE
#   violation     ICIS-AIR_VIOLATION_HISTORY.csv  : EARLIEST_FRV_DETERM_DATE and HPV_DAYZERO_DATE (union)
#   action        ICIS-AIR_FORMAL_ACTIONS.csv     : SETTLEMENT_ENTERED_DATE
#                 ICIS-AIR_INFORMAL_ACTIONS.csv   : ACHIEVED_DATE
#   certification ICIS-AIR_TITLEV_CERTS.csv       : ACTUAL_END_DATE
#   Dates are month-first in two separators (mm-dd-yyyy and mm/dd/yyyy); lubridate::mdy() parses both.
#
# OUTPUTS (data/derived/)
#   titlev_utility_panel_skeleton.csv    one row per facility-year (the balanced skeleton).
#   titlev_utility_panel_facilities.csv  one row per kept facility: attributes + per-type event totals.
#
# REPRODUCIBILITY
#   Exploratory build step — standalone, not wired into 00_run_all.R. Paths via here::here(); raw data is
#   never modified. No randomness (nothing to seed). Blank/unparseable dates become NA and are dropped
#   before the year filter; the count that fails to parse is reported so it is auditable.
# =========================================================================================================

library(here)        # project-root-relative paths (anchors on the .git directory)
library(readr)       # read_csv / write_csv
library(dplyr)       # data manipulation verbs
library(tidyr)       # expand_grid (the balanced rectangle) and pivot_wider (the activity flags)
library(lubridate)   # mdy() date parsing -> year()

# ---- Parameters (edit here) -----------------------------------------------------------------------------
# Everything that defines the sample lives here so the script reads top-down and is easy to re-scope.
YEARS       <- 2015:2025       # the panel window; length(YEARS) == 11 is the strict-balance threshold below
NAICS_REGEX <- "2211"          # electric power generation / transmission / distribution (matched as substring)
SIC_CODES   <- c("4911")       # electric services (legacy SIC); a vector so more codes can be added
TITLEV_DEF  <- "major_class"   # "major_class" | "has_cert" | "both"  (how "Title V major" is operationalized)

raw     <- here("data/raw/ICIS-AIR_downloads")   # all raw inputs live here (immutable)
out_dir <- here("data/derived")                  # derived outputs go here (rebuilt from code)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)  # ensure the output dir exists; no-op if it does

# Read helper: pull PGM_SYS_ID + one date column from a raw activity table and tag it with an activity type.
# Everything is read as character (col_types default) so ids keep leading zeros; the date stays a string
# here and is parsed later in one place. `.date` is a temporary name so the six tables stack cleanly.
read_activity <- function(file, date_col, type) {
  read_csv(file.path(raw, file), col_types = cols(.default = col_character()), show_col_types = FALSE) |>
    transmute(PGM_SYS_ID, .date = .data[[date_col]], activity_type = type)
}

# ============================================================================================
# 1. UNIVERSE — Title V major electric-utility facilities
# ============================================================================================

# The facility master table: one row per facility, with classification, industry codes, and attributes.
# Ids forced to character so leading zeros survive (e.g. PGM_SYS_ID "0100000009003E0010").
fac <- read_csv(
  file.path(raw, "ICIS-AIR_FACILITIES.csv"),
  col_types = cols(PGM_SYS_ID = col_character(), REGISTRY_ID = col_character(), .default = col_character()),
  show_col_types = FALSE
)

# "Title V major" can be defined three ways (TITLEV_DEF). The "has_cert"/"both" options need to know which
# facilities ever hold a Title V certification, so load that id set once up front.
titlev_ids <- read_csv(file.path(raw, "ICIS-AIR_TITLEV_CERTS.csv"),
                       col_types = cols(PGM_SYS_ID = col_character(), .default = col_character()),
                       show_col_types = FALSE) |> pull(PGM_SYS_ID) |> unique()

is_major_class <- fac$AIR_POLLUTANT_CLASS_DESC == "Major Emissions"  # the major-source flag in the master table
has_titlev     <- fac$PGM_SYS_ID %in% titlev_ids                     # appears in the Title V cert table
# Resolve the chosen definition into one logical vector over `fac`; stop() guards against a typo in the param.
titlev_major <- switch(TITLEV_DEF,
  major_class = is_major_class,
  has_cert    = has_titlev,
  both        = is_major_class & has_titlev,
  stop("TITLEV_DEF must be 'major_class', 'has_cert', or 'both'", call. = FALSE)
)

# Electric utility = NAICS contains the 2211 prefix OR any of the SIC_CODES appears in SIC_CODES column.
# (Codes are matched as substrings because the columns can hold multiple ';'-separated codes.)
# Reduce(`|`, ...) ORs together one logical vector per SIC code, so SIC_CODES can grow without edits here.
is_electric <- grepl(NAICS_REGEX, fac$NAICS_CODES) |
               Reduce(`|`, lapply(SIC_CODES, function(s) grepl(s, fac$SIC_CODES)))

# The universe = facilities that satisfy the Title V rule AND the industry rule (and have an id).
# distinct() keeps just the attribute columns we want to carry, one row per facility.
universe <- fac |>
  filter(titlev_major & is_electric & !is.na(PGM_SYS_ID)) |>
  distinct(PGM_SYS_ID, REGISTRY_ID, FACILITY_NAME, STATE, COUNTY_NAME, EPA_REGION,
           NAICS_CODES, SIC_CODES, AIR_POLLUTANT_CLASS_DESC, AIR_OPERATING_STATUS_DESC)

cat("====== UNIVERSE ======\n")
cat("Title V (", TITLEV_DEF, ") major electric-utility facilities:", nrow(universe), "\n")

# ============================================================================================
# 2. ACTIVITY LEDGER — (PGM_SYS_ID, year, activity_type) for the universe, within the window
# ============================================================================================

# Stack every regulatory interaction into one long table. Each source contributes PGM_SYS_ID + one date,
# tagged by type. Violations appear twice (two date fields) so either an FRV determination or an HPV
# day-zero in a year counts as a violation interaction that year; both formal and informal actions map to
# "action". bind_rows() unions them all.
ledger_raw <- bind_rows(
  read_activity("ICIS-AIR_FCES_PCES.csv",         "ACTUAL_END_DATE",          "eval"),
  read_activity("ICIS-AIR_VIOLATION_HISTORY.csv", "EARLIEST_FRV_DETERM_DATE", "violation"),
  read_activity("ICIS-AIR_VIOLATION_HISTORY.csv", "HPV_DAYZERO_DATE",         "violation"),
  read_activity("ICIS-AIR_FORMAL_ACTIONS.csv",    "SETTLEMENT_ENTERED_DATE",  "action"),
  read_activity("ICIS-AIR_INFORMAL_ACTIONS.csv",  "ACHIEVED_DATE",            "action"),
  read_activity("ICIS-AIR_TITLEV_CERTS.csv",      "ACTUAL_END_DATE",          "cert")
)

# Parse dates once, here, for all sources. mdy() reads both mm-dd-yyyy and mm/dd/yyyy; quiet=TRUE suppresses
# the per-row failure warnings (we report the failure count ourselves). Blank strings are dropped first so
# they don't inflate the "failed to parse" tally.
n_nonblank   <- sum(!is.na(ledger_raw$.date) & ledger_raw$.date != "")  # denominator for the parse-rate check
ledger_dated <- ledger_raw |>
  filter(!is.na(.date), .date != "") |>
  mutate(year = year(mdy(.date, quiet = TRUE)))
n_unparsed <- sum(is.na(ledger_dated$year))   # dates that were non-blank but still wouldn't parse
cat("\n====== ACTIVITY LEDGER ======\n")
cat("Non-blank activity dates:", n_nonblank, "| failed to parse:", n_unparsed,
    "(", round(n_unparsed / n_nonblank * 100, 2), "%)\n")

# Final ledger: drop unparseable years, keep only in-window years and facilities in the universe, and
# de-duplicate to one row per (facility, year, type) — we only care whether a type occurred in a year.
ledger <- ledger_dated |>
  filter(!is.na(year), year %in% YEARS, PGM_SYS_ID %in% universe$PGM_SYS_ID) |>
  distinct(PGM_SYS_ID, year, activity_type)

# ============================================================================================
# 3. STRICT-BALANCE FILTER — keep facilities with >=1 interaction in EVERY year of the window
# ============================================================================================

# Count the distinct years each facility appears in the ledger. A facility covering all 11 years has
# interacted with the regulatory system every year -> it qualifies for the balanced panel.
years_per_fac <- ledger |> distinct(PGM_SYS_ID, year) |> count(PGM_SYS_ID, name = "n_years")
kept_ids      <- years_per_fac |> filter(n_years == length(YEARS)) |> pull(PGM_SYS_ID)

cat("\n====== STRICT EVERY-YEAR FILTER ======\n")
cat("Facilities active in all", length(YEARS), "years (kept):", length(kept_ids), "\n")
# Context: how many barely missed (active in 10 of 11 years) — useful for judging how sensitive the
# sample size is to the strict rule.
cat("Facilities active in", length(YEARS) - 1, "of", length(YEARS), "years (just missed):",
    sum(years_per_fac$n_years == length(YEARS) - 1), "\n")

# ============================================================================================
# 4. SKELETON — balanced rectangle (kept facilities x YEARS) + attributes + per-year activity flags
# ============================================================================================

# Per (facility, year), which interaction types occurred. Recode the type tags into flag names, mark each
# observed (facility, year, type) TRUE, then pivot wide so each type becomes a column; cells with no
# interaction of that type fill FALSE.
flags <- ledger |>
  filter(PGM_SYS_ID %in% kept_ids) |>
  mutate(type = recode(activity_type, eval = "had_eval", violation = "had_violation",
                       action = "had_action", cert = "had_cert"), present = TRUE) |>
  distinct(PGM_SYS_ID, year, type, present) |>
  pivot_wider(names_from = type, values_from = present, values_fill = FALSE)

# The balanced frame: every kept facility crossed with every year (expand_grid = the cartesian product),
# then attach time-invariant attributes and the per-year flags. coalesce() turns the NAs introduced by the
# flag join (facility-years with that flag absent) into FALSE so the flag columns are clean logicals.
skeleton <- expand_grid(PGM_SYS_ID = kept_ids, year = YEARS) |>
  left_join(universe, by = "PGM_SYS_ID") |>
  left_join(flags,    by = c("PGM_SYS_ID", "year")) |>
  mutate(across(c(had_eval, had_violation, had_action, had_cert), \(x) coalesce(x, FALSE))) |>
  arrange(PGM_SYS_ID, year)

# ============================================================================================
# 5. VALIDATION REPORT + ASSERTIONS
# ============================================================================================

cat("\n====== PANEL ======\n")
cat("Facilities:", length(kept_ids), "| years:", length(YEARS),
    "| rows:", nrow(skeleton), "\n")

# Hard checks that the panel really is balanced and well-formed; stopifnot() aborts with the named message
# if any fails, so a broken build can never silently write output.
stopifnot(
  "rows != facilities x years"      = nrow(skeleton) == length(kept_ids) * length(YEARS),      # exact rectangle
  "a facility has != length(YEARS) rows" =                                                     # no facility over/under
    all((skeleton |> count(PGM_SYS_ID) |> pull(n)) == length(YEARS)),
  "year outside window"             = all(skeleton$year %in% YEARS),                           # no stray years
  "a facility-year has no activity" =                                                          # inclusion rule held
    all(skeleton$had_eval | skeleton$had_violation | skeleton$had_action | skeleton$had_cert)
)
cat("All balance assertions passed.\n")

# ============================================================================================
# 6. WRITE OUTPUTS
# ============================================================================================

# Per-facility provenance file: the kept facilities with their attributes plus total event counts by type
# over the window (count() then pivot_wider to one n_<type> column each; missing types fill 0).
facilities_out <- universe |>
  filter(PGM_SYS_ID %in% kept_ids) |>
  left_join(
    ledger |> filter(PGM_SYS_ID %in% kept_ids) |>
      count(PGM_SYS_ID, activity_type) |>
      pivot_wider(names_from = activity_type, values_from = n, values_fill = 0,
                  names_prefix = "n_"),
    by = "PGM_SYS_ID"
  )

write_csv(skeleton,       file.path(out_dir, "titlev_utility_panel_skeleton.csv"))
write_csv(facilities_out, file.path(out_dir, "titlev_utility_panel_facilities.csv"))

cat("\nOutputs written to:", out_dir, "\n")
cat("  titlev_utility_panel_skeleton.csv  (", nrow(skeleton), "rows )\n")
cat("  titlev_utility_panel_facilities.csv (", nrow(facilities_out), "rows )\n")
