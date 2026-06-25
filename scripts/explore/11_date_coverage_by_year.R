# =========================================================================================================
# 11_date_coverage_by_year.R — coverage matrix: one row per date variable, one column per year, cells =
# number of records whose date falls in that year. Spans all datasets (ICIS-Air, CAA pipeline, AFS,
# emissions). Two worksheets:
#   "all_dates"        every observed year, including out-of-range / implausible years (kept on purpose)
#   "filtered_1965_2026"  only years 1965-2026; records dated outside that window are dropped
#
# Each date field is parsed with the format that field actually uses (verified by inspection):
#   mdy   : mm-dd-yyyy or mm/dd/yyyy   (ICIS-Air event/program dates; pipeline dates; AFS HPV dates)
#   ymd8  : YYYYMMDD                   (AFS_ACTIONS.DATE_ACHIEVED)
#   yyqq  : YYQQ -> year = 2000+YY     (AFS_AIR_PRG_HIST_COMPLIANCE quarterly compliance)
#   year  : already a 4-digit year     (emissions REPORTING_YEAR)
# A non-blank value that does not parse to a year is counted in the "(unparseable)" column (e.g. the
# pipeline VIOL_END_DATE values "N/A" / "Unresolved").
#
# Record-management timestamps (CREATION_DATE, *_UPDATED_DATE, pipeline SORT_DATE) are excluded: they
# track when a row was entered/edited, not when the regulatory activity occurred.
#
# Output: output/explore_tabulations/date_coverage_by_year.xlsx . Exploratory; paths via here::here().
# =========================================================================================================

library(here)
library(readr)
library(dplyr)
library(tidyr)
library(lubridate)
library(openxlsx)

FILT_MIN <- 1965L
FILT_MAX <- 2026L

icis <- function(f) here("data/raw/ICIS-AIR_downloads", f)
afs  <- function(f) here("data/raw/afs_downloads", f)

# label, file path, column, format
datevars <- list(
  list("ICIS FCES_PCES.ACTUAL_END_DATE",            icis("ICIS-AIR_FCES_PCES.csv"),        "ACTUAL_END_DATE",          "mdy"),
  list("ICIS VIOLATION.EARLIEST_FRV_DETERM_DATE",   icis("ICIS-AIR_VIOLATION_HISTORY.csv"),"EARLIEST_FRV_DETERM_DATE", "mdy"),
  list("ICIS VIOLATION.HPV_DAYZERO_DATE",           icis("ICIS-AIR_VIOLATION_HISTORY.csv"),"HPV_DAYZERO_DATE",         "mdy"),
  list("ICIS VIOLATION.HPV_RESOLVED_DATE",          icis("ICIS-AIR_VIOLATION_HISTORY.csv"),"HPV_RESOLVED_DATE",        "mdy"),
  list("ICIS VIOLATION.DSCV_PATHWAY_DATE",          icis("ICIS-AIR_VIOLATION_HISTORY.csv"),"DSCV_PATHWAY_DATE",        "mdy"),
  list("ICIS VIOLATION.NFTC_PATHWAY_DATE",          icis("ICIS-AIR_VIOLATION_HISTORY.csv"),"NFTC_PATHWAY_DATE",        "mdy"),
  list("ICIS FORMAL_ACTIONS.SETTLEMENT_ENTERED_DATE",icis("ICIS-AIR_FORMAL_ACTIONS.csv"),  "SETTLEMENT_ENTERED_DATE",  "mdy"),
  list("ICIS INFORMAL_ACTIONS.ACHIEVED_DATE",       icis("ICIS-AIR_INFORMAL_ACTIONS.csv"), "ACHIEVED_DATE",            "mdy"),
  list("ICIS STACK_TESTS.ACTUAL_END_DATE",          icis("ICIS-AIR_STACK_TESTS.csv"),      "ACTUAL_END_DATE",          "mdy"),
  list("ICIS TITLEV_CERTS.ACTUAL_END_DATE",         icis("ICIS-AIR_TITLEV_CERTS.csv"),     "ACTUAL_END_DATE",          "mdy"),
  list("ICIS PROGRAMS.BEGIN_DATE",                  icis("ICIS-AIR_PROGRAMS.csv"),         "BEGIN_DATE",               "mdy"),
  list("PIPELINE.EVAL_DATE",        here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"), "EVAL_DATE",       "mdy"),
  list("PIPELINE.VIOL_START_DATE",  here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"), "VIOL_START_DATE", "mdy"),
  list("PIPELINE.VIOL_END_DATE",    here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"), "VIOL_END_DATE",   "mdy"),
  list("PIPELINE.EA_DATE",          here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"), "EA_DATE",         "mdy"),
  list("AFS ACTIONS.DATE_ACHIEVED",            afs("AFS_ACTIONS.csv"),                 "DATE_ACHIEVED",     "ymd8"),
  list("AFS HPV_HISTORY.HPV_DAYZERO_DATE",     afs("AFS_HPV_HISTORY.csv"),             "HPV_DAYZERO_DATE",  "mdy"),
  list("AFS HPV_HISTORY.HPV_RESOLVED_DATE",    afs("AFS_HPV_HISTORY.csv"),             "HPV_RESOLVED_DATE", "mdy"),
  list("AFS HIST_COMPLIANCE.HISTORICAL_COMPLIANCE_DATE", afs("AFS_AIR_PRG_HIST_COMPLIANCE.csv"), "HISTORICAL_COMPLIANCE_DATE", "yyqq"),
  list("EMISSIONS.REPORTING_YEAR",  here("data/raw/POLL_RPT_COMBINED_EMISSIONS.csv"), "REPORTING_YEAR", "year")
)

parse_year <- function(x, fmt) {
  x <- ifelse(is.na(x) | trimws(x) == "", NA, x)
  if (fmt == "mdy")  return(year(mdy(x, quiet = TRUE)))
  if (fmt == "ymd8") return(year(ymd(x, quiet = TRUE)))
  if (fmt == "yyqq") { yy <- suppressWarnings(as.integer(substr(x, 1, 2))); return(ifelse(is.na(yy), NA, 2000L + yy)) }
  if (fmt == "year") { y <- suppressWarnings(as.integer(x)); return(ifelse(!is.na(y) & y >= 1000 & y <= 9999, y, NA)) }
  stop("unknown fmt")
}

# ---- Build a long table: variable, year (or "(unparseable)"), n ----------------------------------------
long <- list()
for (dv in datevars) {
  label <- dv[[1]]; path <- dv[[2]]; col <- dv[[3]]; fmt <- dv[[4]]
  cat("reading", label, "\n")
  v <- read_csv(path, col_select = all_of(col), show_col_types = FALSE,
                col_types = cols(.default = col_character()))[[col]]
  present <- !(is.na(v) | trimws(v) == "")
  yr <- parse_year(v, fmt)
  tab <- as.data.frame(table(year = yr), stringsAsFactors = FALSE)   # parseable years
  if (nrow(tab)) long[[length(long) + 1]] <- data.frame(variable = label, year = as.integer(tab$year), n = tab$Freq)
  n_unparse <- sum(present & is.na(yr))
  if (n_unparse > 0) long[[length(long) + 1]] <- data.frame(variable = label, year = NA_integer_, n = n_unparse)
}
long <- bind_rows(long)

vars_order <- vapply(datevars, function(d) d[[1]], character(1))

build_wide <- function(df, year_cols) {
  w <- df |>
    filter(year %in% year_cols) |>
    mutate(year = factor(year, levels = year_cols)) |>
    pivot_wider(names_from = year, values_from = n, values_fill = 0, names_expand = TRUE) |>
    mutate(variable = factor(variable, levels = vars_order)) |> arrange(variable)
  # ensure all variables present even if all-zero in window
  miss <- setdiff(vars_order, as.character(w$variable))
  if (length(miss)) w <- bind_rows(w, tibble(variable = miss))
  w |> mutate(variable = factor(variable, levels = vars_order)) |> arrange(variable) |>
    mutate(across(-variable, ~replace_na(as.numeric(.), 0))) |>
    mutate(total = rowSums(across(-variable)))
}

# All dates: every observed (parseable) year, plus an "(unparseable)" column.
obs_years <- sort(unique(long$year[!is.na(long$year)]))
all_tab <- build_wide(long |> filter(!is.na(year)), obs_years)
unparsed <- long |> filter(is.na(year)) |> group_by(variable) |> summarise(`(unparseable)` = sum(n), .groups = "drop")
all_tab <- all_tab |> left_join(unparsed, by = "variable") |>
  mutate(`(unparseable)` = replace_na(`(unparseable)`, 0)) |>
  relocate(`(unparseable)`, .after = last_col())   # keep after totals? put before total
# reorder: variable, years..., (unparseable), total
all_tab <- all_tab |> relocate(total, .after = last_col())

# Filtered: 1965-2026 only.
filt_tab <- build_wide(long |> filter(!is.na(year)), FILT_MIN:FILT_MAX)

# ---- Write workbook ------------------------------------------------------------------------------------
out <- here("output/explore_tabulations/date_coverage_by_year.xlsx")
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
wb    <- createWorkbook()
hdr   <- createStyle(textDecoration = "bold", halign = "center", border = "bottom")
green <- createStyle(bgFill = "#C6EFCE", fontColour = "#006100")  # populated year cells
comma <- createStyle(numFmt = "#,##0", halign = "center")
grp   <- createStyle(textDecoration = "bold", fgFill = "#D9E1F2", border = "TopBottom")  # dataset header rows

# Map a variable label to its source dataset (rows are grouped under these headers).
dataset_of <- function(x) ifelse(grepl("^ICIS ", x),     "ICIS-Air",
                          ifelse(grepl("^PIPELINE", x),   "CAA Pipeline",
                          ifelse(grepl("^AFS ", x),       "AFS (legacy, frozen 2014)",
                          ifelse(grepl("^EMISSIONS", x),  "Emissions", "Other"))))

write_sheet <- function(sh, dat) {
  dat$variable <- as.character(dat$variable)
  yrc0 <- which(grepl("^[0-9]+$", names(dat)));  upc0 <- which(names(dat) == "(unparseable)")
  for (j in c(yrc0, upc0)) dat[[j]][dat[[j]] == 0] <- NA   # blank zeros: empty = no records that year

  # Insert a bold dataset-header row before each group (rows already ordered by dataset).
  ds <- dataset_of(dat$variable); blocks <- list(); hdr_rows <- integer(0); rr <- 0L; cur <- ""
  for (i in seq_len(nrow(dat))) {
    if (ds[i] != cur) {
      cur <- ds[i]; h <- dat[i, ]; h[1, ] <- NA; h$variable <- cur
      blocks[[length(blocks) + 1]] <- h; rr <- rr + 1L; hdr_rows <- c(hdr_rows, rr)
    }
    blocks[[length(blocks) + 1]] <- dat[i, ]; rr <- rr + 1L
  }
  dat2 <- do.call(rbind, blocks)
  yrc  <- which(grepl("^[0-9]+$", names(dat2)))
  cntc <- c(yrc, which(names(dat2) %in% c("(unparseable)", "total")))

  addWorksheet(wb, sh)
  writeData(wb, sh, dat2, headerStyle = hdr)   # NA -> blank cell
  nr <- nrow(dat2)
  addStyle(wb, sh, comma, rows = 2:(nr + 1), cols = cntc, gridExpand = TRUE, stack = TRUE)
  # Per-row heat map: each variable's year cells get a pale->dark-green colour scale computed WITHIN that
  # row, so the darkest cells mark the years with the most coverage for that variable. Blanks stay white.
  for (i in seq_len(nr)) {
    if (i %in% hdr_rows) next
    conditionalFormatting(wb, sh, cols = yrc, rows = i + 1L, type = "colourScale",
                          style = c("#F1F8E9", "#66BB6A", "#1B5E20"))
  }
  addStyle(wb, sh, grp, rows = hdr_rows + 1L, cols = 1:ncol(dat2), gridExpand = TRUE, stack = TRUE)
  freezePane(wb, sh, firstActiveRow = 2, firstActiveCol = 2)
  setColWidths(wb, sh, cols = 1, widths = 46)
}
write_sheet("all_dates", all_tab)
write_sheet("filtered_1965_2026", filt_tab)

# ---- Availability sheet -----------------------------------------------------------------------------------
# Presence only: a year cell is filled (solid green) if the variable has ANY records that year, blank
# otherwise. No counts, no within-row gradient -> shows the coverage WINDOW per variable without conflating
# it with regulatory intensity (a high-activity year and a low-activity year look the same here). The
# years_covered column is the number of in-window years with any data.
write_availability <- function(sh, dat) {   # dat = filt_tab (counts over 1965-2026, with total)
  dat$variable <- as.character(dat$variable)
  yrc0 <- which(grepl("^[0-9]+$", names(dat)))
  yc   <- rowSums(vapply(dat[yrc0], function(c) !is.na(c) & c > 0, logical(nrow(dat))))
  for (j in yrc0) dat[[j]] <- ifelse(!is.na(dat[[j]]) & dat[[j]] > 0, 1L, NA_integer_)  # presence
  dat$total <- NULL
  dat$years_covered <- yc

  ds <- dataset_of(dat$variable); blocks <- list(); hdr_rows <- integer(0); rr <- 0L; cur <- ""
  for (i in seq_len(nrow(dat))) {
    if (ds[i] != cur) { cur <- ds[i]; h <- dat[i, ]; h[1, ] <- NA; h$variable <- cur
      blocks[[length(blocks) + 1]] <- h; rr <- rr + 1L; hdr_rows <- c(hdr_rows, rr) }
    blocks[[length(blocks) + 1]] <- dat[i, ]; rr <- rr + 1L
  }
  d2  <- do.call(rbind, blocks)
  yrc <- which(grepl("^[0-9]+$", names(d2)))
  addWorksheet(wb, sh)
  writeData(wb, sh, d2, headerStyle = hdr)
  nr <- nrow(d2)
  solid <- createStyle(bgFill = "#2E7D32", fontColour = "#2E7D32")  # uniform fill; hides the "1"
  conditionalFormatting(wb, sh, cols = yrc, rows = 2:(nr + 1), rule = ">0", style = solid)
  addStyle(wb, sh, grp, rows = hdr_rows + 1L, cols = 1:ncol(d2), gridExpand = TRUE, stack = TRUE)
  addStyle(wb, sh, createStyle(halign = "center"),
           rows = 2:(nr + 1), cols = which(names(d2) == "years_covered"), gridExpand = TRUE, stack = TRUE)
  freezePane(wb, sh, firstActiveRow = 2, firstActiveCol = 2)
  setColWidths(wb, sh, cols = 1, widths = 46)
}
write_availability("availability_1965_2026", filt_tab)

saveWorkbook(wb, out, overwrite = TRUE)
cat("\nWrote", out, "\n")
cat("Variables:", length(vars_order), "| observed-year span:", min(obs_years), "-", max(obs_years), "\n")
