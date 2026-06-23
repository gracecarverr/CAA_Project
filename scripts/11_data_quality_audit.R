# ---- Data Quality Audit ---------------------------------------------------------------------------------
# Reproduces every number in output/data_quality_findings.md.
# Output is labeled by section number for cross-referencing.
# Each dataset is loaded once and all relevant findings computed before moving on.

library(here)      # project-root-relative paths (replaces hardcoded setwd)
library(readr)
library(dplyr)
library(lubridate)

# here() anchors on the project's .git directory, so paths resolve from any working directory.
raw <- here("data/raw/ICIS-AIR_downloads")

# =========================================================================================
# FORMAL ACTIONS — §1.1 penalty double-counting, §2.6 top penalties
# =========================================================================================

fa <- read_csv(file.path(raw, "ICIS-AIR_FORMAL_ACTIONS.csv"), show_col_types = FALSE)

cat("\n===== §1.1 PENALTY DOUBLE-COUNTING =====\n")

multi_enf <- fa |>
  filter(!is.na(ENF_IDENTIFIER), !is.na(PENALTY_AMOUNT), PENALTY_AMOUNT > 0) |>
  group_by(ENF_IDENTIFIER) |>
  summarise(
    n_fac = n_distinct(PGM_SYS_ID),
    penalty = first(PENALTY_AMOUNT),
    identical = n_distinct(PENALTY_AMOUNT) == 1,
    naive_sum = sum(PENALTY_AMOUNT),
    .groups = "drop"
  ) |>
  filter(n_fac > 1)

cat("ENF IDs with >1 facility and nonzero penalty:", nrow(multi_enf), "\n")
cat("Of those, >10 facilities:", sum(multi_enf$n_fac > 10), "\n")

# Specific examples with facility IDs
for (enf in c("06-2025-3401", "NM000A200275488", "NM000A200225814")) {
  rows <- fa |> filter(ENF_IDENTIFIER == enf)
  cat(sprintf("\n  ENF %s: $%s × %d facilities → naive $%s\n",
    enf,
    formatC(unique(rows$PENALTY_AMOUNT), format = "d", big.mark = ","),
    n_distinct(rows$PGM_SYS_ID),
    formatC(sum(rows$PENALTY_AMOUNT, na.rm = TRUE), format = "d", big.mark = ",")))
  cat("  PGM_SYS_IDs:\n")
  cat(paste("   ", sort(unique(rows$PGM_SYS_ID)), collapse = "\n"), "\n")
}

cat("\n===== §2.6 TOP PENALTIES =====\n")

fa |>
  filter(!is.na(PENALTY_AMOUNT)) |>
  arrange(desc(PENALTY_AMOUNT)) |>
  slice_head(n = 5) |>
  select(PGM_SYS_ID, ENF_IDENTIFIER, PENALTY_AMOUNT, ENF_TYPE_DESC, SETTLEMENT_ENTERED_DATE) |>
  print()

rm(fa)

# =========================================================================================
# PROGRAMS — §1.2 BEGIN_DATE migration artifact
# =========================================================================================

prg <- read_csv(file.path(raw, "ICIS-AIR_PROGRAMS.csv"), show_col_types = FALSE)

cat("\n===== §1.2 BEGIN_DATE MIGRATION ARTIFACT =====\n")

n_prg <- nrow(prg)
bd <- mdy(prg$BEGIN_DATE, quiet = TRUE)
ud <- mdy(prg$UPDATED_DATE, quiet = TRUE)

# 10/19/2014 counts
n_bd_oct14 <- sum(bd == as.Date("2014-10-19"), na.rm = TRUE)
cat("BEGIN_DATE = 10/19/2014:", n_bd_oct14, sprintf("(%.1f%%)\n", n_bd_oct14 / n_prg * 100))

n_ud_oct14 <- sum(ud == as.Date("2014-10-19"), na.rm = TRUE)
cat("UPDATED_DATE = 10/19/2014:", n_ud_oct14, sprintf("(%.1f%%)\n", n_ud_oct14 / n_prg * 100))

# 06/19/1969 sentinel
n_bd_1969 <- sum(bd == as.Date("1969-06-19"), na.rm = TRUE)
cat("BEGIN_DATE = 06/19/1969:", n_bd_1969, "\n")

# Year 0218
n_yr_0218 <- sum(year(bd) == 218, na.rm = TRUE)
cat("Year 0218:", n_yr_0218, "\n")
if (n_yr_0218 > 0) {
  idx_0218 <- which(year(bd) == 218)
  cat("  PGM_SYS_ID:", prg$PGM_SYS_ID[idx_0218], "\n")
  cat("  BEGIN_DATE raw:", prg$BEGIN_DATE[idx_0218], "\n")
}

# Future begin dates
n_future <- sum(bd > Sys.Date(), na.rm = TRUE)
cat("Future BEGIN_DATEs:", n_future, "\n")
if (n_future > 0) {
  future_rows <- prg |> mutate(bd = bd) |> filter(bd > Sys.Date())
  cat("  States:", paste(table(future_rows$PGM_SYS_ID |> substr(1, 2)) |> names(), collapse = ", "), "\n")
  cat("  Example PGM_SYS_IDs:\n")
  print(future_rows |> select(PGM_SYS_ID, BEGIN_DATE) |> slice_head(n = 5))
}

# Save programs for §3.4 and §5.1/5.2 joins later
prg_ids <- prg |> select(PGM_SYS_ID, PROGRAM_CODE)
rm(prg, bd, ud)

# =========================================================================================
# FACILITIES — §1.3 CA count, §2.1 CO, §3.2 ZIP, §3.3 deleted, §3.4 orphans, §4 missingness
# =========================================================================================

fac <- read_csv(file.path(raw, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)
n_fac <- nrow(fac)

cat("\n===== §1.3 CALIFORNIA REPRESENTATION (facilities) =====\n")
ca_fac <- sum(fac$STATE == "CA", na.rm = TRUE)
cat("CA facilities:", ca_fac, sprintf("(%.1f%%)\n", ca_fac / n_fac * 100))

cat("\n===== §2.1 COLORADO FACILITY COUNT =====\n")
state_counts <- fac |> count(STATE) |> arrange(desc(n))
cat("Top states by facility count:\n")
print(state_counts |> slice_head(n = 5))

# Weld County
weld <- fac |> filter(STATE == "CO", COUNTY_NAME == "Weld")
cat("Weld County CO:", nrow(weld), "\n")
cat("  NON facility type:", sum(weld$FACILITY_TYPE_CODE == "NON", na.rm = TRUE), "\n")
cat("  MIN pollutant class:", sum(weld$AIR_POLLUTANT_CLASS_CODE == "MIN", na.rm = TRUE), "\n")

cat("\n===== §3.2 JUNK ZIP CODES =====\n")
# ZIP codes that aren't plausible (not 5 digits, not 9 digits, or contain letters/symbols)
bad_zip <- fac |>
  filter(!is.na(ZIP_CODE)) |>
  mutate(zip_clean = trimws(ZIP_CODE)) |>
  filter(!grepl("^[0-9]{5}$", zip_clean),
         !grepl("^[0-9]{9}$", zip_clean),
         !grepl("^[0-9]{5}-[0-9]{4}$", zip_clean))
cat("Non-standard ZIP values:", nrow(bad_zip), "\n")
cat("Examples:\n")
bad_zip |>
  select(PGM_SYS_ID, STATE, zip_clean) |>
  slice_head(n = 10) |>
  print()

cat("\n===== §3.3 SOFT-DELETED FACILITIES =====\n")
deleted <- fac |>
  filter(grepl("DELETED|REMOVED|INACTIVE", FACILITY_NAME, ignore.case = TRUE))
cat("Facilities with DELETED/REMOVED/INACTIVE in name:", nrow(deleted), "\n")
cat("  Of those, coded CLS:", sum(deleted$AIR_OPERATING_STATUS_CODE == "CLS", na.rm = TRUE), "\n")
cat("  NOT coded CLS:", sum(deleted$AIR_OPERATING_STATUS_CODE != "CLS", na.rm = TRUE), "\n")
cat("Examples:\n")
deleted |>
  select(PGM_SYS_ID, FACILITY_NAME, AIR_OPERATING_STATUS_CODE) |>
  slice_head(n = 5) |>
  print()

cat("\n===== §3.4 FACILITIES WITH NO PROGRAM RECORDS =====\n")
fac_in_prg <- unique(prg_ids$PGM_SYS_ID)
orphan_fac <- fac |> filter(!(PGM_SYS_ID %in% fac_in_prg))
cat("Facilities with no program match:", nrow(orphan_fac),
    sprintf("(%.1f%%)\n", nrow(orphan_fac) / n_fac * 100))
cat("Example orphan facilities:\n")
orphan_fac |>
  select(PGM_SYS_ID, STATE, FACILITY_NAME, AIR_OPERATING_STATUS_CODE) |>
  slice_head(n = 5) |>
  print()

cat("\n===== §4 NON-RANDOM MISSINGNESS BY STATE =====\n")

# Utah
ut <- fac |> filter(STATE == "UT")
cat("Utah facilities:", nrow(ut), "\n")
cat("  AIR_OPERATING_STATUS_CODE missing:",
    sum(is.na(ut$AIR_OPERATING_STATUS_CODE)),
    sprintf("(%.1f%%)\n", sum(is.na(ut$AIR_OPERATING_STATUS_CODE)) / nrow(ut) * 100))
cat("  AIR_POLLUTANT_CLASS_CODE missing:",
    sum(is.na(ut$AIR_POLLUTANT_CLASS_CODE)),
    sprintf("(%.1f%%)\n", sum(is.na(ut$AIR_POLLUTANT_CLASS_CODE)) / nrow(ut) * 100))
cat("  With status:", sum(!is.na(ut$AIR_OPERATING_STATUS_CODE)), "\n")

# Ohio FACILITY_TYPE_CODE
oh <- fac |> filter(STATE == "OH")
cat("Ohio facilities:", nrow(oh), "\n")
cat("  FACILITY_TYPE_CODE missing:",
    sum(is.na(oh$FACILITY_TYPE_CODE)),
    sprintf("(%.1f%%)\n", sum(is.na(oh$FACILITY_TYPE_CODE)) / nrow(oh) * 100))

# Georgia
ga <- fac |> filter(STATE == "GA")
cat("Georgia FACILITY_TYPE_CODE missing:",
    sum(is.na(ga$FACILITY_TYPE_CODE)),
    sprintf("of %d (%.1f%%)\n", nrow(ga), sum(is.na(ga$FACILITY_TYPE_CODE)) / nrow(ga) * 100))

# Louisiana
la_fac <- fac |> filter(STATE == "LA")
cat("Louisiana FACILITY_TYPE_CODE missing:",
    sum(is.na(la_fac$FACILITY_TYPE_CODE)),
    sprintf("of %d (%.1f%%)\n", nrow(la_fac), sum(is.na(la_fac$FACILITY_TYPE_CODE)) / nrow(la_fac) * 100))

# Minnesota
mn <- fac |> filter(STATE == "MN")
cat("Minnesota FACILITY_TYPE_CODE missing:",
    sum(is.na(mn$FACILITY_TYPE_CODE)),
    sprintf("of %d (%.1f%%)\n", nrow(mn), sum(is.na(mn$FACILITY_TYPE_CODE)) / nrow(mn) * 100))

# North Dakota
nd <- fac |> filter(STATE == "ND")
cat("North Dakota facilities:", nrow(nd), "\n")
cat("  AIR_POLLUTANT_CLASS_CODE missing:",
    sprintf("%.1f%%\n", sum(is.na(nd$AIR_POLLUTANT_CLASS_CODE)) / nrow(nd) * 100))
cat("  AIR_OPERATING_STATUS_CODE missing:",
    sprintf("%.1f%%\n", sum(is.na(nd$AIR_OPERATING_STATUS_CODE)) / nrow(nd) * 100))

cat("\n===== §5.1 MINOR FACILITIES IN TITLE V =====\n")
tv_fac <- prg_ids |> filter(PROGRAM_CODE == "CAATVP") |> distinct(PGM_SYS_ID)
min_in_tv <- fac |>
  filter(AIR_POLLUTANT_CLASS_CODE == "MIN", PGM_SYS_ID %in% tv_fac$PGM_SYS_ID)
cat("MIN facilities with Title V:", nrow(min_in_tv), "\n")
cat("Example MIN + Title V:\n")
min_in_tv |>
  select(PGM_SYS_ID, STATE, FACILITY_NAME, AIR_POLLUTANT_CLASS_CODE) |>
  slice_head(n = 5) |>
  print()

smi_in_tv <- fac |>
  filter(AIR_POLLUTANT_CLASS_CODE == "SMI", PGM_SYS_ID %in% tv_fac$PGM_SYS_ID)
cat("SMI facilities with Title V:", nrow(smi_in_tv), "\n")

cat("\n===== §5.2 OPERATING MAJOR WITHOUT TITLE V =====\n")
maj_opr <- fac |>
  filter(AIR_POLLUTANT_CLASS_CODE == "MAJ",
         AIR_OPERATING_STATUS_CODE == "OPR",
         !(PGM_SYS_ID %in% tv_fac$PGM_SYS_ID))
cat("MAJ + OPR without Title V:", nrow(maj_opr), "\n")
cat("Example MAJ + OPR without Title V:\n")
maj_opr |>
  select(PGM_SYS_ID, STATE, FACILITY_NAME, AIR_POLLUTANT_CLASS_CODE) |>
  slice_head(n = 5) |>
  print()

rm(prg_ids, fac)

# =========================================================================================
# POLLUTANTS — §1.4 pseudo-pollutants, §1.7 duplicate codes, §2.7 MN granularity
# =========================================================================================

pol <- read_csv(file.path(raw, "ICIS-AIR_POLLUTANTS.csv"), show_col_types = FALSE)
n_pol <- nrow(pol)

cat("\n===== §1.4 PSEUDO-POLLUTANT CODES =====\n")

pseudo_names <- c("FACIL", "OTHER", "POLLUTANT X", "ADMIN")
pseudo <- pol |> filter(POLLUTANT_DESC %in% pseudo_names)
cat("Total pseudo-pollutant rows:", nrow(pseudo),
    sprintf("(%.1f%%)\n", nrow(pseudo) / n_pol * 100))

pseudo |>
  group_by(POLLUTANT_CODE, POLLUTANT_DESC) |>
  summarise(rows = n(), facilities = n_distinct(PGM_SYS_ID), .groups = "drop") |>
  arrange(desc(rows)) |>
  print()

cat("\n===== §1.7 DUPLICATE POLLUTANT CODES =====\n")
# Find pollutant names that appear under multiple codes
dup_names <- pol |>
  filter(!is.na(POLLUTANT_DESC)) |>
  distinct(POLLUTANT_CODE, POLLUTANT_DESC) |>
  group_by(POLLUTANT_DESC) |>
  filter(n() > 1) |>
  ungroup()

cat("Pollutant names with multiple codes:", n_distinct(dup_names$POLLUTANT_DESC), "\n")

# Show the specific examples from the markdown
for (pname in c("Benzene", "Hexane", "Manganese", "Nitrogen Oxides")) {
  codes <- dup_names |> filter(POLLUTANT_DESC == pname)
  if (nrow(codes) > 0) {
    cat("\n", pname, ":\n")
    for (i in 1:nrow(codes)) {
      code <- codes$POLLUTANT_CODE[i]
      n_fac_code <- n_distinct(pol$PGM_SYS_ID[pol$POLLUTANT_CODE == code])
      cat(sprintf("  Code %s: %d facilities\n", code, n_fac_code))
    }
  }
}

cat("\n===== §2.7 MINNESOTA POLLUTANT GRANULARITY =====\n")
fac_pol_counts <- pol |>
  group_by(PGM_SYS_ID) |>
  summarise(n = n(), .groups = "drop")

over_100 <- fac_pol_counts |> filter(n > 100)
cat("Facilities with >100 pollutant records:", nrow(over_100), "\n")

# Join back to get state (from PGM_SYS_ID prefix — first 2 chars)
over_100 <- over_100 |> mutate(state = substr(PGM_SYS_ID, 1, 2))
mn_count <- sum(over_100$state == "MN")
cat("Of those, Minnesota:", mn_count, sprintf("(%.0f%%)\n", mn_count / nrow(over_100) * 100))

rm(pol)

# =========================================================================================
# VIOLATION HISTORY — §1.4 violations pseudo-pollutants, §2.3 rates, §2.4 HPVs
# =========================================================================================

viol <- read_csv(file.path(raw, "ICIS-AIR_VIOLATION_HISTORY.csv"), show_col_types = FALSE)
n_viol <- nrow(viol)

cat("\n===== §1.3 CALIFORNIA REPRESENTATION (violations) =====\n")
# Need state from PGM_SYS_ID prefix
viol <- viol |> mutate(state = substr(PGM_SYS_ID, 1, 2))
ca_viol <- sum(viol$state == "CA", na.rm = TRUE)
cat("CA violations:", ca_viol, sprintf("(%.1f%%)\n", ca_viol / n_viol * 100))

# Bay Area and San Joaquin Valley — need LOCAL_CONTROL_REGION or agency prefix
# The PGM_SYS_ID for CA facilities starts with CA followed by agency code
# BAAQMD facilities typically have specific patterns, SJVAPCD as well
# Actually the markdown says violations not facilities. Let me check what columns we have.
cat("Violation columns:", paste(names(viol), collapse = ", "), "\n")

cat("\n===== §1.4 PSEUDO-POLLUTANTS IN VIOLATIONS =====\n")
if ("POLLUTANT_DESCS" %in% names(viol)) {
  facil_viol <- sum(viol$POLLUTANT_DESCS == "FACIL", na.rm = TRUE)
  admin_viol <- sum(viol$POLLUTANT_DESCS == "ADMIN", na.rm = TRUE)
  cat("FACIL in violations:", facil_viol, "\n")
  cat("ADMIN in violations:", admin_viol, "\n")
  cat("Combined share:", sprintf("%.0f%%\n", (facil_viol + admin_viol) / n_viol * 100))
} else {
  cat("Pollutant columns found:", grep("POLL", names(viol), value = TRUE), "\n")
}

cat("\n===== §2.3 ENFORCEMENT CULTURE (violations per facility) =====\n")
# Denominator: total facilities per state from the FACILITIES table (already freed)
# Reload just the state column for the denominator
fac_st <- read_csv(file.path(raw, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE,
                   col_select = c("PGM_SYS_ID", "STATE"))
state_fac_counts <- fac_st |> count(STATE, name = "n_fac_total")

viol_per_state <- viol |>
  group_by(state) |>
  summarise(n_viol = n(), .groups = "drop") |>
  left_join(state_fac_counts, by = c("state" = "STATE"))

for (st in c("CA", "VA", "MD", "WI")) {
  row <- viol_per_state |> filter(state == st)
  if (nrow(row) > 0) cat(sprintf("  %s: %s violations / %s total facilities = %.2f/fac\n",
    st, formatC(row$n_viol, big.mark = ","),
    formatC(row$n_fac_total, big.mark = ","),
    round(row$n_viol / row$n_fac_total, 2)))
}
rm(fac_st, state_fac_counts)

cat("\n===== §2.4 UNRESOLVED HPVS =====\n")
# HPV columns
hpv_cols <- grep("HPV", names(viol), value = TRUE)
cat("HPV-related columns:", paste(hpv_cols, collapse = ", "), "\n")

if ("HPV_DAYZERO_DATE" %in% names(viol)) {
  hpv_rows <- viol |> filter(!is.na(HPV_DAYZERO_DATE))
  cat("Total HPV records:", nrow(hpv_rows), "\n")

  dz <- mdy(hpv_rows$HPV_DAYZERO_DATE, quiet = TRUE)
  res <- mdy(hpv_rows$HPV_RESOLVED_DATE, quiet = TRUE)

  # Unresolved
  n_unresolved <- sum(is.na(res))
  cat("No resolved date:", n_unresolved,
      sprintf("(%.0f%%)\n", n_unresolved / nrow(hpv_rows) * 100))

  # Age of unresolved in years
  unres_age <- as.numeric(difftime(Sys.Date(), dz[is.na(res)], units = "days")) / 365.25
  cat("Unresolved median age:", round(median(unres_age, na.rm = TRUE), 1), "years\n")
  cat("Unresolved mean age:", round(mean(unres_age, na.rm = TRUE), 1), "years\n")
  cat("Unresolved >25 years:", sum(unres_age > 25, na.rm = TRUE), "\n")

  # Oldest unresolved
  oldest_idx <- which(is.na(res))[which.max(unres_age)]
  cat("Oldest unresolved:", hpv_rows$PGM_SYS_ID[oldest_idx],
      "day-zero", as.character(dz[oldest_idx]),
      sprintf("(%.1f years)\n", max(unres_age, na.rm = TRUE)))

  # Resolution before day-zero
  days_diff <- as.numeric(difftime(res, dz, units = "days"))
  n_negative <- sum(days_diff < 0, na.rm = TRUE)
  cat("Resolution before day-zero:", n_negative, "\n")
  cat("Worst resolution-before-day-zero examples:\n")
  neg_idx <- which(days_diff < 0)
  hpv_rows[neg_idx, ] |>
    mutate(days = days_diff[neg_idx]) |>
    arrange(days) |>
    select(PGM_SYS_ID, HPV_DAYZERO_DATE, HPV_RESOLVED_DATE, days) |>
    slice_head(n = 5) |>
    print()

  # Same-day resolution
  n_sameday <- sum(days_diff == 0, na.rm = TRUE)
  cat("Same-day resolution:", n_sameday, "\n")
}

cat("\n===== §3.1 SENTINEL DATES (violations) =====\n")
date_cols_v <- grep("DATE", names(viol), value = TRUE)
for (dc in date_cols_v) {
  parsed <- mdy(viol[[dc]], quiet = TRUE)
  pre1970_idx <- which(year(parsed) < 1970)
  if (length(pre1970_idx) > 0) {
    cat(sprintf("  %s: %d pre-1970 dates\n", dc, length(pre1970_idx)))
    cat("  Examples:\n")
    viol[pre1970_idx, ] |>
      select(PGM_SYS_ID, all_of(dc)) |>
      print()
  }
}

rm(viol)

# =========================================================================================
# INFORMAL ACTIONS — §1.8 mass duplication, §3.1 sentinel dates
# =========================================================================================

inf <- read_csv(file.path(raw, "ICIS-AIR_INFORMAL_ACTIONS.csv"), show_col_types = FALSE)
n_inf <- nrow(inf)

cat("\n===== §1.8 INFORMAL ACTIONS DUPLICATION =====\n")
n_dup <- sum(duplicated(inf))
n_unique <- n_inf - n_dup
cat("Total rows:", formatC(n_inf, big.mark = ","), "\n")
cat("Exact duplicates:", formatC(n_dup, big.mark = ","),
    sprintf("(%.1f%%)\n", n_dup / n_inf * 100))
cat("Unique rows:", formatC(n_unique, big.mark = ","), "\n")

cat("\n===== §3.1 SENTINEL DATES (informal actions) =====\n")
date_cols_i <- grep("DATE", names(inf), value = TRUE)
for (dc in date_cols_i) {
  parsed <- mdy(inf[[dc]], quiet = TRUE)
  yr <- year(parsed)

  n_0001 <- sum(yr == 1, na.rm = TRUE)
  n_8888 <- sum(yr == 8888, na.rm = TRUE)
  n_2104 <- sum(yr == 2104, na.rm = TRUE)
  n_1950 <- sum(yr == 1950, na.rm = TRUE)

  if (any(c(n_0001, n_8888, n_2104, n_1950) > 0)) {
    cat(sprintf("  %s: yr=0001: %d, yr=8888: %d, yr=2104: %d, yr=1950: %d\n",
      dc, n_0001, n_8888, n_2104, n_1950))

    sentinel_idx <- which(yr %in% c(1, 8888, 2104, 1950))
    cat("  Examples:\n")
    inf[sentinel_idx, ] |>
      select(PGM_SYS_ID, all_of(dc)) |>
      slice_head(n = 5) |>
      print()
  }
}

rm(inf)

# =========================================================================================
# TITLE V CERTS — §1.5 deviation flag missingness, §2.5 cert counts, §3.1 dates
# =========================================================================================

tv <- read_csv(file.path(raw, "ICIS-AIR_TITLEV_CERTS.csv"), show_col_types = FALSE)
n_tv <- nrow(tv)

cat("\n===== §1.5 DEVIATION FLAG MISSINGNESS =====\n")
overall_miss <- sum(is.na(tv$FACILITY_RPT_DEVIATION_FLAG)) / n_tv * 100
cat("Overall missing:", sprintf("%.0f%%\n", overall_miss))

# By STATE_EPA_FLAG
if ("STATE_EPA_FLAG" %in% names(tv)) {
  tv |>
    filter(!is.na(STATE_EPA_FLAG)) |>
    group_by(STATE_EPA_FLAG) |>
    summarise(
      n = n(),
      pct_miss = round(sum(is.na(FACILITY_RPT_DEVIATION_FLAG)) / n() * 100, 1),
      .groups = "drop"
    ) |>
    print()
}

cat("\n===== §2.5 TITLE V CERT COUNTS =====\n")
certs_per_fac <- tv |>
  group_by(PGM_SYS_ID) |>
  summarise(n = n(), .groups = "drop")

n_over_200 <- sum(certs_per_fac$n > 200)
cat("Facilities with >200 certs:", n_over_200, "\n")

top_cert <- certs_per_fac |> arrange(desc(n)) |> slice_head(n = 1)
cat("Top facility:", top_cert$PGM_SYS_ID, "with", top_cert$n, "certs\n")

cat("\n===== §3.1 SENTINEL DATES (Title V) =====\n")
date_cols_tv <- grep("DATE", names(tv), value = TRUE)
for (dc in date_cols_tv) {
  parsed <- mdy(tv[[dc]], quiet = TRUE)
  pre1990_idx <- which(year(parsed) < 1990)
  if (length(pre1990_idx) > 0) {
    cat(sprintf("  %s: %d pre-1990 dates\n", dc, length(pre1990_idx)))
    cat("  Examples:\n")
    tv[pre1990_idx, ] |>
      select(PGM_SYS_ID, all_of(dc)) |>
      slice_head(n = 5) |>
      print()
  }
}

rm(tv)

# =========================================================================================
# STACK TESTS — §1.6 pre-2001 incompleteness, §3.1 dates
# =========================================================================================

st <- read_csv(file.path(raw, "ICIS-AIR_STACK_TESTS.csv"), show_col_types = FALSE)

cat("\n===== §1.6 STACK TEST COMPLETENESS =====\n")
# Check what the result column is called
result_col <- grep("RESULT|PASS|STATUS", names(st), value = TRUE, ignore.case = TRUE)
cat("Result-related columns:", paste(result_col, collapse = ", "), "\n")

# Parse test dates
date_cols_st <- grep("DATE", names(st), value = TRUE)
cat("Date columns:", paste(date_cols_st, collapse = ", "), "\n")

if (length(date_cols_st) > 0) {
  test_date <- mdy(st[[date_cols_st[1]]], quiet = TRUE)
  test_yr <- year(test_date)

  if (length(result_col) > 0) {
    st_with_yr <- st |> mutate(yr = test_yr, result = .data[[result_col[1]]])

    # Pass/fail by year cohort
    yr_summary <- st_with_yr |>
      filter(!is.na(yr)) |>
      group_by(yr) |>
      summarise(
        n = n(),
        n_na = sum(is.na(result) | result == "N/A" | result == ""),
        pct_na = round(n_na / n * 100, 1),
        .groups = "drop"
      )
    cat("Pre-2001 N/A rates:\n")
    print(yr_summary |> filter(yr >= 1995, yr <= 2005))
  }

  # Sentinel dates
  cat("\n===== §3.1 SENTINEL DATES (stack tests) =====\n")
  yr200_idx <- which(test_yr >= 200 & test_yr < 300)
  cat("Year 200-299:", length(yr200_idx), "\n")
  if (length(yr200_idx) > 0) {
    cat("Examples:\n")
    st[yr200_idx, ] |>
      select(PGM_SYS_ID, ACTUAL_END_DATE) |>
      print()
  }
}

rm(st)

# =========================================================================================
# FCES/PCES — §2.2 MT monitoring, §2.3 evals/facility, §5.3 ACTIVITY_TYPE_CODE
# =========================================================================================

fce <- read_csv(file.path(raw, "ICIS-AIR_FCES_PCES.csv"), show_col_types = FALSE)
fce <- fce |> mutate(state = substr(PGM_SYS_ID, 1, 2))

cat("\n===== §1.3 CALIFORNIA REPRESENTATION (formal actions, stack tests) =====\n")
# We need to reload formal actions and stack tests briefly for CA counts
fa2 <- read_csv(file.path(raw, "ICIS-AIR_FORMAL_ACTIONS.csv"), show_col_types = FALSE,
                col_select = "PGM_SYS_ID")
fa2 <- fa2 |> mutate(state = substr(PGM_SYS_ID, 1, 2))
n_fa <- nrow(fa2)
ca_fa <- sum(fa2$state == "CA")
cat("CA formal actions:", ca_fa, sprintf("(%.1f%%)\n", ca_fa / n_fa * 100))

# CASJV specifically
casjv_fa <- sum(grepl("^CASJV", fa2$PGM_SYS_ID))
cat("  CASJV formal actions:", casjv_fa, "\n")
rm(fa2)

st2 <- read_csv(file.path(raw, "ICIS-AIR_STACK_TESTS.csv"), show_col_types = FALSE,
                col_select = "PGM_SYS_ID")
st2 <- st2 |> mutate(state = substr(PGM_SYS_ID, 1, 2))
n_st <- nrow(st2)
ca_st <- sum(st2$state == "CA")
cat("CA stack tests:", ca_st, sprintf("(%.1f%%)\n", ca_st / n_st * 100))

casjv_st <- sum(grepl("^CASJV", st2$PGM_SYS_ID))
cat("  CASJV stack tests:", casjv_st, sprintf("(%.1f%% of national)\n", casjv_st / n_st * 100))
rm(st2)

cat("\n===== §2.2 MONTANA MONITORING =====\n")
mt <- fce |> filter(state == "MT")
cat("MT facilities:", n_distinct(mt$PGM_SYS_ID), "\n")
cat("MT evaluations:", nrow(mt), "\n")
cat("MT evals/facility:", round(nrow(mt) / n_distinct(mt$PGM_SYS_ID), 1), "\n")

# Top MT facility
mt_top <- mt |> count(PGM_SYS_ID) |> arrange(desc(n)) |> slice_head(n = 1)
cat("Top MT facility:", mt_top$PGM_SYS_ID, "with", mt_top$n, "evals\n")

# PCE Off-Site share (in COMP_MONITOR_TYPE_DESC, not ACTIVITY_TYPE_DESC)
if ("COMP_MONITOR_TYPE_DESC" %in% names(fce)) {
  mt_pce <- sum(grepl("PCE Off", mt$COMP_MONITOR_TYPE_DESC, ignore.case = TRUE), na.rm = TRUE)
  cat("MT PCE Off-Site:", mt_pce, sprintf("(%.0f%%)\n", mt_pce / nrow(mt) * 100))
}

# Next highest state rate
state_eval_rates <- fce |>
  group_by(state) |>
  summarise(evals = n(), facs = n_distinct(PGM_SYS_ID),
            rate = round(evals / facs, 1), .groups = "drop") |>
  arrange(desc(rate))
cat("Next highest rate after MT:", state_eval_rates$state[2],
    "at", state_eval_rates$rate[2], "\n")

cat("\n===== §2.3 ENFORCEMENT CULTURE (evals per facility) =====\n")
for (st_code in c("CA", "VA")) {
  row <- state_eval_rates |> filter(state == st_code)
  if (nrow(row) > 0) cat(sprintf("  %s: %.1f evals/facility\n", st_code, row$rate))
}

cat("\n===== §5.3 ACTIVITY_TYPE_CODE =====\n")
if ("ACTIVITY_TYPE_CODE" %in% names(fce)) {
  cat("Distinct values:", n_distinct(fce$ACTIVITY_TYPE_CODE), "\n")
  print(table(fce$ACTIVITY_TYPE_CODE))
}

rm(fce)

cat("\n===== AUDIT COMPLETE =====\n")
