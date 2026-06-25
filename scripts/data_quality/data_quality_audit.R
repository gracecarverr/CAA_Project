# =========================================================================================================
# data_quality_audit.R — one reproducible pass that recomputes the data-quality issues surfaced during
# table construction, across every dataset (ICIS-Air, CAA pipeline, AFS, emissions) plus the FRS crosswalk.
# Prints a per-table report and writes a tidy summary to
#   output/explore_tabulations/data_quality/data_quality_summary.csv  (one row per dataset/table x issue).
#
# Metrics:
#   rows                     row count
#   duplicate_key_rows       # rows sharing a key that should be unique (event tables: ACTIVITY_ID; etc.)
#   missing_top              the highest-missing fields (% of rows), top 3
#   bad_dates                # dates that parse to a year outside the plausible window 1965-2026
#   unparseable_dates        # non-blank date values that do not parse (e.g. "Unresolved", "N/A")
#   numeric_max / pct_zero / pct_neg   anomaly checks on penalty / cost / emission fields
#   placeholder / undoc_code special checks (pipeline 9906/9913 placeholders; AFS undocumented program codes)
#   crosswalk_unmatched      AFS facilities with no FRS identifier link (from the crosswalk coverage file)
#
# Dates are parsed with each field's actual format (mdy / YYYYMMDD / YYQQ / raw year). Exploratory; raw
# data is never modified; paths via here::here().
# =========================================================================================================

library(here); library(readr); library(dplyr); library(tidyr); library(lubridate)

YMIN <- 1965L; YMAX <- 2026L
out_dir <- here("output/explore_tabulations/data_quality")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
icis <- function(f) here("data/raw/ICIS-AIR_downloads", f)
afs  <- function(f) here("data/raw/afs_downloads", f)

parse_year <- function(x, fmt) {
  x <- ifelse(is.na(x) | trimws(x) == "", NA, x)
  if (fmt == "mdy")  return(year(mdy(x, quiet = TRUE)))
  if (fmt == "ymd8") return(year(ymd(x, quiet = TRUE)))
  if (fmt == "yyqq") { yy <- suppressWarnings(as.integer(substr(x, 1, 2))); return(ifelse(is.na(yy), NA, 2000L + yy)) }
  if (fmt == "year") { y <- suppressWarnings(as.integer(x)); return(ifelse(!is.na(y) & y >= 1000 & y <= 9999, y, NA)) }
  stop("bad fmt")
}

# ---- accumulator -----------------------------------------------------------------------------------------
S <- list()
add <- function(dataset, table, issue, value, detail = "") {
  S[[length(S) + 1L]] <<- data.frame(dataset = dataset, table = table, issue = issue,
                                     value = as.character(value), detail = detail, stringsAsFactors = FALSE)
}

blank <- function(v) is.na(v) | trimws(v) == ""

# ---- generic per-table profiler --------------------------------------------------------------------------
profile <- function(dataset, table, path, key = NULL, dates = NULL, nums = NULL) {
  d <- read_csv(path, col_types = cols(.default = col_character()), show_col_types = FALSE)
  n <- nrow(d)
  cat(sprintf("\n==== %s / %s : %s rows ====\n", dataset, table, format(n, big.mark = ",")))
  add(dataset, table, "rows", n)

  if (!is.null(key) && all(key %in% names(d))) {
    k <- if (length(key) == 1) d[[key]] else do.call(paste, c(d[key], sep = "|"))
    ndup <- sum(duplicated(k[!blank(k)]))
    add(dataset, table, "duplicate_key_rows", ndup, paste(key, collapse = "+"))
    cat(sprintf("  key %-14s distinct=%s  duplicate rows=%s\n", paste(key, collapse = "+"),
                format(length(unique(k[!blank(k)])), big.mark = ","), format(ndup, big.mark = ",")))
  }

  miss <- sort(vapply(d, function(c) mean(blank(c)), numeric(1)), decreasing = TRUE)
  top  <- head(miss[miss > 0], 3)
  for (i in seq_along(top)) {
    add(dataset, table, "missing_top", round(top[i] * 100, 1), names(top)[i])
    cat(sprintf("  missing %-28s %5.1f%%\n", names(top)[i], top[i] * 100))
  }

  for (f in names(dates)) if (f %in% names(d)) {
    present <- !blank(d[[f]]); yr <- parse_year(d[[f]], dates[[f]])
    bad <- sum(!is.na(yr) & (yr < YMIN | yr > YMAX)); unp <- sum(present & is.na(yr))
    add(dataset, table, "bad_dates", bad, f); add(dataset, table, "unparseable_dates", unp, f)
    if (bad > 0 || unp > 0) cat(sprintf("  date %-26s bad=%s unparseable=%s\n", f,
                                         format(bad, big.mark = ","), format(unp, big.mark = ",")))
  }

  for (f in nums) if (f %in% names(d)) {
    v <- suppressWarnings(as.numeric(d[[f]])); v <- v[!is.na(v)]
    if (length(v)) {
      add(dataset, table, "numeric_max", format(max(v), scientific = FALSE, trim = TRUE), f)
      add(dataset, table, "numeric_pct_zero", round(mean(v == 0) * 100, 1), f)
      add(dataset, table, "numeric_pct_neg",  round(mean(v < 0)  * 100, 1), f)
      cat(sprintf("  numeric %-22s max=%s  zero=%.1f%%  neg=%.1f%%\n", f,
                  format(max(v), big.mark = ","), mean(v == 0) * 100, mean(v < 0) * 100))
    }
  }
  invisible(d)
}

# ============================================================================================
# ICIS-Air
# ============================================================================================
profile("ICIS-Air", "FACILITIES", icis("ICIS-AIR_FACILITIES.csv"), key = "PGM_SYS_ID")
profile("ICIS-Air", "PROGRAMS", icis("ICIS-AIR_PROGRAMS.csv"),
        dates = list(BEGIN_DATE = "mdy", UPDATED_DATE = "mdy"))
profile("ICIS-Air", "PROGRAM_SUBPARTS", icis("ICIS-AIR_PROGRAM_SUBPARTS.csv"))
profile("ICIS-Air", "POLLUTANTS", icis("ICIS-AIR_POLLUTANTS.csv"))
profile("ICIS-Air", "FCES_PCES", icis("ICIS-AIR_FCES_PCES.csv"), key = "ACTIVITY_ID",
        dates = list(ACTUAL_END_DATE = "mdy"))
profile("ICIS-Air", "VIOLATION_HISTORY", icis("ICIS-AIR_VIOLATION_HISTORY.csv"), key = "ACTIVITY_ID",
        dates = list(EARLIEST_FRV_DETERM_DATE = "mdy", HPV_DAYZERO_DATE = "mdy", HPV_RESOLVED_DATE = "mdy",
                     DSCV_PATHWAY_DATE = "mdy", NFTC_PATHWAY_DATE = "mdy"))
profile("ICIS-Air", "FORMAL_ACTIONS", icis("ICIS-AIR_FORMAL_ACTIONS.csv"), key = "ACTIVITY_ID",
        dates = list(SETTLEMENT_ENTERED_DATE = "mdy"), nums = "PENALTY_AMOUNT")
profile("ICIS-Air", "INFORMAL_ACTIONS", icis("ICIS-AIR_INFORMAL_ACTIONS.csv"), key = "ACTIVITY_ID",
        dates = list(ACHIEVED_DATE = "mdy"))
profile("ICIS-Air", "STACK_TESTS", icis("ICIS-AIR_STACK_TESTS.csv"), key = "ACTIVITY_ID",
        dates = list(ACTUAL_END_DATE = "mdy"))
profile("ICIS-Air", "TITLEV_CERTS", icis("ICIS-AIR_TITLEV_CERTS.csv"), key = "ACTIVITY_ID",
        dates = list(ACTUAL_END_DATE = "mdy"))

# ============================================================================================
# CAA Pipeline (+ placeholder check)
# ============================================================================================
pipe <- profile("CAA Pipeline", "PIPELINE", here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"),
        dates = list(EVAL_DATE = "mdy", VIOL_START_DATE = "mdy", VIOL_END_DATE = "mdy", EA_DATE = "mdy"),
        nums = c("EA_PENALTY_AMT", "EA_COMP_ACTION_COST"))
ph <- sum(grepl("^(9906|9913)", pipe$VIOL_ACTIVITY_ID))
add("CAA Pipeline", "PIPELINE", "placeholder_rows", ph, "VIOL_ACTIVITY_ID 9906/9913 prefix")
add("CAA Pipeline", "PIPELINE", "placeholder_pct", round(ph / nrow(pipe) * 100, 1), "of rows")
cat(sprintf("  placeholder VIOL_ACTIVITY_ID (9906/9913): %s (%.1f%%)\n", format(ph, big.mark=","), ph/nrow(pipe)*100))

# ============================================================================================
# AFS (+ undocumented program-code check)
# ============================================================================================
profile("AFS", "AFS_FACILITIES", afs("AFS_FACILITIES.csv"), key = "AFS_ID")
air <- profile("AFS", "AIR_PROGRAM", afs("AIR_PROGRAM.csv"))
documented <- c("0","1","3","4","6","7","8","9","A","F","I","M","T","V")
undoc <- air$AIR_PROGRAM_CODE[!blank(air$AIR_PROGRAM_CODE) & !(air$AIR_PROGRAM_CODE %in% documented)]
add("AFS", "AIR_PROGRAM", "undocumented_code_rows", length(undoc),
    paste0("AIR_PROGRAM_CODE not in EPA list: ", paste(sort(unique(undoc)), collapse = ",")))
cat(sprintf("  undocumented AIR_PROGRAM_CODE values: %s (rows=%s)\n",
            paste(sort(unique(undoc)), collapse = ","), format(length(undoc), big.mark = ",")))
profile("AFS", "AFS_ACTIONS", afs("AFS_ACTIONS.csv"),
        dates = list(DATE_ACHIEVED = "ymd8"), nums = "PENALTY_AMOUNT")
profile("AFS", "AFS_AIR_PRG_HIST_COMPLIANCE", afs("AFS_AIR_PRG_HIST_COMPLIANCE.csv"),
        dates = list(HISTORICAL_COMPLIANCE_DATE = "yyqq"))
profile("AFS", "AFS_HPV_HISTORY", afs("AFS_HPV_HISTORY.csv"),
        dates = list(HPV_DAYZERO_DATE = "mdy", HPV_RESOLVED_DATE = "mdy"))

# ============================================================================================
# Emissions (REPORTING_YEAR plausibility + ANNUAL_EMISSION anomalies)
# ============================================================================================
profile("Emissions", "POLL_RPT_COMBINED_EMISSIONS", here("data/raw/POLL_RPT_COMBINED_EMISSIONS.csv"),
        dates = list(REPORTING_YEAR = "year"), nums = "ANNUAL_EMISSION")

# ============================================================================================
# FRS crosswalk (read the already-computed coverage file)
# ============================================================================================
cov_path <- here("output/explore_tabulations/frs_crosswalk/crosswalk_coverage.csv")
if (file.exists(cov_path)) {
  cov <- read_csv(cov_path, show_col_types = FALSE)
  unm <- cov$afs_facilities_total - cov$afs_linked_to_registry
  add("FRS crosswalk", "AFS->FRS", "crosswalk_unmatched", unm,
      paste0(round(unm / cov$afs_facilities_total * 100, 1), "% of AFS facilities (state-driven)"))
  cat(sprintf("\n==== FRS crosswalk ====\n  AFS facilities unmatched: %s (%.1f%%)\n",
              format(unm, big.mark = ","), unm / cov$afs_facilities_total * 100))
}

# ---- write summary ---------------------------------------------------------------------------------------
summary_df <- bind_rows(S)
write_csv(summary_df, file.path(out_dir, "data_quality_summary.csv"))
cat("\nWrote", file.path(out_dir, "data_quality_summary.csv"), "(", nrow(summary_df), "rows )\n")
