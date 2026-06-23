# =========================================================================================================
# 09_table-afs-actions.R — data-dictionary table for the legacy AFS_ACTIONS dataset.
# Writes output/tables/afs_actions_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------
# These are the R libraries (toolkits) we need:
#   here      — resolves project-root-relative paths (replaces a hardcoded working directory)
#   openxlsx  — creates and formats Excel (.xlsx) files
#   readr     — reads CSV files into R
#   dplyr     — data manipulation (filtering, counting, grouping, etc.)
#   lubridate — makes it easier to work with dates

library(here)
library(openxlsx)
library(readr)
library(dplyr)
library(lubridate)

# ---- Load data ------------------------------------------------------------------------------------------
# Read the raw CSV into a dataframe called "aa" (short for AFS actions).
# Each row in this CSV is one enforcement or compliance action from EPA's legacy
# Air Facility System (AFS). AFS tracked CAA compliance before being replaced by
# ICIS-Air in October 2014 — so this dataset is historical.
# ~2.6M rows, 16 columns.

aa <- read_csv(here("data/raw/afs_downloads/AFS_ACTIONS.csv"), show_col_types = FALSE)

# Count total rows and distinct facilities — these are used throughout the script.
n_obs <- nrow(aa)                       # total number of rows in the dataset
n_fac <- n_distinct(aa$AFS_ID)          # number of unique facilities (AFS_ID is the facility ID)

# ---- Compute statistics ---------------------------------------------------------------------------------
# These are small helper functions that we reuse for every variable in the table.

# pct_miss: takes a column and returns the % of values that are missing (NA), as a string like "5.2%"
pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")

# n_cats: counts how many distinct values a column has (ignoring NAs)
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

# top_vals: finds the most common values in a column.
#   1. Removes NAs
#   2. Counts how many times each value appears
#   3. Sorts from most to least common
#   4. Keeps only the top n_top values
#   5. Calculates each value's percentage of the TOTAL dataset (including NAs in denominator)
top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# ---------- NATIONAL_ACTION_TYPE ----------
# This variable is the code for the type of enforcement/compliance action (e.g., "FS" for
# state-conducted FCE, "5C" for state inspection). NATIONAL_ACTION_DESC provides the
# plain-English description. We count occurrences of each type+description pair.

nat <- aa |> count(NATIONAL_ACTION_TYPE, NATIONAL_ACTION_DESC) |>   # count rows per type
  mutate(pct = n / n_obs) |>                                         # calculate % of total
  arrange(desc(n)) |>                                                 # sort most common first
  slice_head(n = 4)                                                   # keep top 4
nat_miss <- pct_miss(aa$NATIONAL_ACTION_TYPE)                        # % missing
nat_ncat <- n_cats(aa$NATIONAL_ACTION_TYPE)                          # number of categories

# ---------- RESULT_CODE ----------
# The outcome or result of the action (e.g., "MC" = met compliance, "PP" = passed).
# There is no separate description column, so we just use the code itself.

rc <- top_vals(aa, RESULT_CODE, 4)
rc_miss <- pct_miss(aa$RESULT_CODE)
rc_ncat <- n_cats(aa$RESULT_CODE)

# ---------- ALL_AIR_PROGRAM_CODES ----------
# Which air programs the facility is subject to (e.g., "V" = Title V, "M" = MACT/NESHAP).
# IMPORTANT: this column can contain multiple codes per row, separated by commas
# (e.g., "0, M, V"). We report the top 4 raw values as they appear in the data — we do NOT
# split them into individual codes, because this table reports what's actually in the data.

apc <- top_vals(aa, ALL_AIR_PROGRAM_CODES, 4)
apc_miss <- pct_miss(aa$ALL_AIR_PROGRAM_CODES)
apc_ncat <- n_cats(aa$ALL_AIR_PROGRAM_CODES)

# ---------- POLLUTANT_CODE ----------
# Pollutant associated with the enforcement/compliance action.
# Codes are not fully documented in the downloaded data dictionary, so we report raw values.

pc <- top_vals(aa, POLLUTANT_CODE, 4)
pc_miss <- pct_miss(aa$POLLUTANT_CODE)
pc_ncat <- n_cats(aa$POLLUTANT_CODE)

# ---------- ALL_VIOLATING_POLL_CODES ----------
# Pollutant(s) involved in the violation, space-delimited.
# A single row can list multiple pollutant codes.

avpc <- top_vals(aa, ALL_VIOLATING_POLL_CODES, 4)
avpc_miss <- pct_miss(aa$ALL_VIOLATING_POLL_CODES)
avpc_ncat <- n_cats(aa$ALL_VIOLATING_POLL_CODES)

# ---------- ALL_VIOLATION_TYPE_CODES ----------
# Three-character violation type codes associated with the action.

avtc <- top_vals(aa, ALL_VIOLATION_TYPE_CODES, 4)
avtc_miss <- pct_miss(aa$ALL_VIOLATION_TYPE_CODES)
avtc_ncat <- n_cats(aa$ALL_VIOLATION_TYPE_CODES)

# ---------- DATE_ACHIEVED (Date variable) ----------
# Parse the date strings into actual dates, then extract the year.
# The raw data uses YYYYMMDD format (e.g., "20110225"), so we use ymd() from lubridate.
# ymd() converts strings like "20110225" into proper dates.
# year() pulls out just the year (e.g., 2011).

da_yr <- year(ymd(aa$DATE_ACHIEVED))

# Count how many dates are missing after parsing (includes 2 raw values like "19801200"
# with day=00 that ymd() can't parse — negligible out of 2.6M rows)
da_n_miss <- sum(is.na(da_yr))

# Count how many dates successfully parsed (non-NA after parsing)
da_n <- sum(!is.na(da_yr))

# Count "junk" dates — years that are implausibly early or in the future.
# These could be data entry errors (e.g., year 0001 or 9999).
da_junk <- sum(!is.na(da_yr) & (da_yr < 1970 | da_yr > 2027))

# Compute summary statistics on the parsed years:
#   min  = earliest year
#   p5   = 5th percentile (5% of values are below this)
#   med  = median (middle value)
#   p95  = 95th percentile (95% of values are below this)
#   max  = latest year
da <- list(min = min(da_yr, na.rm = TRUE),
           p5 = as.integer(quantile(da_yr, 0.05, na.rm = TRUE)),
           med = as.integer(median(da_yr, na.rm = TRUE)),
           p95 = as.integer(quantile(da_yr, 0.95, na.rm = TRUE)),
           max = max(da_yr, na.rm = TRUE))

# ---------- PENALTY_AMOUNT (Numerical variable) ----------
# Dollar amount of the penalty. We compute stats twice:
#   1. Including $0 penalties (actions with no fine)
#   2. Excluding $0 penalties (to see the distribution of actual fines)

pen_miss <- sum(is.na(aa$PENALTY_AMOUNT))      # how many are missing
pen_n <- sum(!is.na(aa$PENALTY_AMOUNT))         # how many have a value

# Stats for ALL penalties (including $0)
pen_all <- list(min = min(aa$PENALTY_AMOUNT, na.rm = TRUE),
                p5 = quantile(aa$PENALTY_AMOUNT, 0.05, na.rm = TRUE),
                med = median(aa$PENALTY_AMOUNT, na.rm = TRUE),
                p95 = quantile(aa$PENALTY_AMOUNT, 0.95, na.rm = TRUE),
                max = max(aa$PENALTY_AMOUNT, na.rm = TRUE))

# How many actions have $0 penalty (compliance actions with no fine)
n_zero <- sum(aa$PENALTY_AMOUNT == 0, na.rm = TRUE)

# Filter to only rows with penalties > $0, then compute stats on those
pen_nz <- aa |> filter(!is.na(PENALTY_AMOUNT), PENALTY_AMOUNT > 0)
n_nonzero <- nrow(pen_nz)
pen_nz_stats <- list(min = min(pen_nz$PENALTY_AMOUNT),
                     p5 = quantile(pen_nz$PENALTY_AMOUNT, 0.05),
                     med = median(pen_nz$PENALTY_AMOUNT),
                     p95 = quantile(pen_nz$PENALTY_AMOUNT, 0.95),
                     max = max(pen_nz$PENALTY_AMOUNT))

# ---------- DUPLICATES ----------
# Check for duplicate rows in different ways to understand the data structure.

# Exact duplicates: rows where EVERY column is identical to another row
n_exact_dup <- sum(duplicated(aa))

# How many actions per facility? This tells us about the structure of the data —
# some facilities have hundreds of actions over years of monitoring.
apf <- aa |> group_by(AFS_ID) |> summarise(n = n(), .groups = "drop")  # count actions per facility
max_act <- max(apf$n)                    # facility with the most actions
med_act <- as.integer(median(apf$n))     # median number of actions per facility

# Check ANU1: is it a unique identifier for actions within a facility?
# ANU1 appears to be an action number within each facility. We check if
# (AFS_ID, ANU1) pairs are unique — if so, ANU1 uniquely identifies an action
# within a given facility.
n_dup_anu1 <- sum(duplicated(aa |> select(AFS_ID, ANU1)))  # duplicated (AFS_ID, ANU1) pairs
n_distinct_anu1 <- n_distinct(aa$ANU1)                       # how many distinct ANU1 values exist

# ==================================================================================================
# EVERYTHING BELOW THIS LINE IS TABLE FORMATTING
# It writes the statistics we computed above into a formatted Excel spreadsheet.
# The pattern is: create a workbook -> define styles -> write data into cells -> save.
# ==================================================================================================

# ---- Create workbook ------------------------------------------------------------------------------------
# Create a blank Excel workbook and add one worksheet called "AFS Actions"

wb <- createWorkbook()
addWorksheet(wb, "AFS Actions")
ws <- "AFS Actions"    # shorthand so we don't have to type the full name every time

# ---- Styles ---------------------------------------------------------------------------------------------
# Define reusable formatting styles. Think of these like CSS classes — you define them once,
# then apply them to cells throughout the spreadsheet.

# Title style: big bold centered text
font_title <- createStyle(fontName = "Calibri", fontSize = 15, textDecoration = "bold",
                          halign = "center")

# Left-aligned body text (for footnotes and descriptions)
font12_left <- createStyle(fontName = "Calibri", fontSize = 12, halign = "left",
                            valign = "top", wrapText = TRUE)

# Green header: used for categorical variable section headers
green_header <- createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                             halign = "center", valign = "center", wrapText = TRUE,
                             fgFill = "#C6EFCE", border = "TopBottomLeftRight")

# Orange header: used for numerical variable section headers
orange_header <- createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center", valign = "center", wrapText = TRUE,
                              fgFill = "#F4B084", border = "TopBottomLeftRight")

# Cell styles for different data types
cell_border <- createStyle(border = "TopBottomLeftRight", halign = "center",
                            valign = "center", wrapText = TRUE,
                            fontName = "Calibri", fontSize = 12)

cell_border_bold <- createStyle(border = "TopBottomLeftRight", halign = "center",
                                 valign = "center", wrapText = TRUE,
                                 fontName = "Calibri", fontSize = 12, textDecoration = "bold")

cell_pct <- createStyle(border = "TopBottomLeftRight", halign = "center",
                         valign = "center", numFmt = "0.0%",           # format as percentage
                         fontName = "Calibri", fontSize = 12)

cell_comma <- createStyle(border = "TopBottomLeftRight", halign = "center",
                           valign = "center", numFmt = "#,##0",        # format with commas (e.g., 1,234)
                           fontName = "Calibri", fontSize = 12)

cell_year <- createStyle(border = "TopBottomLeftRight", halign = "center",
                          valign = "center", numFmt = "0",              # plain number, no commas (for years)
                          fontName = "Calibri", fontSize = 12)

cell_dollar <- createStyle(border = "TopBottomLeftRight", halign = "center",
                            valign = "center", numFmt = "$#,##0",      # format as dollars (e.g., $1,234)
                            fontName = "Calibri", fontSize = 12)

# ---- Column widths --------------------------------------------------------------------------------------
# Set how wide each column is in the spreadsheet (in character units, roughly)

setColWidths(wb, ws, cols = 1, widths = 30)     # Column A: variable names
setColWidths(wb, ws, cols = 2, widths = 18)     # Column B: % missing
setColWidths(wb, ws, cols = 3, widths = 14)     # Column C: # categories
setColWidths(wb, ws, cols = 4, widths = 55)     # Column D: frequent values / descriptions
setColWidths(wb, ws, cols = 5:9, widths = 14)   # Columns E-I: N, %, and numerical stats

# ---- Header block (rows 1-4) ---------------------------------------------------------------------------
# The top of the table: title, description, observation counts, and identifier list.

# Row 1: Title — merge columns A-F into one wide cell and write the table title
mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "AFS Actions (AFS_ACTIONS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

# Row 2: Description of the dataset — what AFS is and why it matters
mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Enforcement actions from EPA's legacy Air Facility System (AFS). Includes both formal and ",
  "informal actions, penalties, and compliance outcomes. AFS was replaced by ICIS-Air in ",
  "October 2014."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 50)

# Row 3: Key counts — total observations, distinct facilities, and date range
# paste0() glues strings together. formatC() adds commas to numbers.
mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES (AFS_ID): ", formatC(n_fac, format = "d", big.mark = ","),
                          "  TEMPORAL COVERAGE: ", da$min, " - ", da$max),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

# Row 4: List of identifier columns — these are the columns that identify individual
# facilities and actions, rather than describing what happened.
mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PLANT_ID, AFS_ID, ANU1  |  METADATA: KEY_ACTION_NUMBERS, CREATION_DATE, DATE_RECORD_IS_UPDATED, REGIONAL_DATA_ELEMENT_8",
          startRow = 4)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center"),
         rows = 4, cols = 1)

# ---- Categorical table header (row 6) ------------------------------------------------------------------
# Row 6 is the green header row for the categorical variables section.
# It labels the 6 columns: Variable, % Missing, # Categories, Frequent Values, N, %

cat_headers <- c("Variable", "% Missing", "# Categories", "Frequent Values", "N", "%")
writeData(wb, ws, t(cat_headers), startRow = 6, colNames = FALSE)   # t() transposes to a row
addStyle(wb, ws, green_header, rows = 6, cols = 1:6, gridExpand = TRUE)

# ---- Helper function ------------------------------------------------------------------------------------
# write_variable() writes one categorical variable's block into the table.
# It handles the merged cells, borders, and formatting so we don't repeat that code
# for every variable.
#
# Arguments:
#   start_row  — which Excel row to start writing at
#   var_name   — the column name (e.g., "NATIONAL_ACTION_TYPE")
#   var_desc   — a plain-English description of what the variable means
#   pct_missing — string like "0%" showing how much data is missing
#   n_cats     — number of distinct categories
#   descs      — vector of value labels (e.g., "FS - STATE CONDUCTED FCE/ON-SITE")
#   ns         — vector of counts for each value
#   pcts       — vector of percentages for each value
#
# The function writes one row per value. If there are multiple values, it merges
# the Variable/% Missing/# Categories cells vertically so they span all rows.

write_variable <- function(wb, ws, start_row, var_name, var_desc, pct_missing, n_cats,
                           descs, ns, pcts) {
  n_vals <- length(descs)
  end_row <- start_row + n_vals - 1

  # Column A: variable name + description (merged if multiple values)
  writeData(wb, ws, paste0(var_name, "\n", var_desc), startRow = start_row, startCol = 1)
  if (n_vals > 1) mergeCells(wb, ws, cols = 1, rows = start_row:end_row)
  addStyle(wb, ws, cell_border_bold, rows = start_row, cols = 1)

  # Column B: % missing (merged)
  writeData(wb, ws, pct_missing, startRow = start_row, startCol = 2)
  if (n_vals > 1) mergeCells(wb, ws, cols = 2, rows = start_row:end_row)
  addStyle(wb, ws, cell_border, rows = start_row, cols = 2)

  # Column C: # categories (merged)
  writeData(wb, ws, n_cats, startRow = start_row, startCol = 3)
  if (n_vals > 1) mergeCells(wb, ws, cols = 3, rows = start_row:end_row)
  addStyle(wb, ws, cell_border, rows = start_row, cols = 3)

  # Columns D-F: one row per value — description, count, and percentage
  for (i in seq_along(descs)) {
    r <- start_row + i - 1
    writeData(wb, ws, descs[i], startRow = r, startCol = 4)    # value label
    writeData(wb, ws, ns[i], startRow = r, startCol = 5)       # count
    writeData(wb, ws, pcts[i], startRow = r, startCol = 6)     # percentage
    addStyle(wb, ws, cell_border, rows = r, cols = 4)
    addStyle(wb, ws, cell_comma, rows = r, cols = 5)
    addStyle(wb, ws, cell_pct, rows = r, cols = 6)
    addStyle(wb, ws, cell_border, rows = r, cols = 1:3, gridExpand = TRUE)
  }
}

# ---- NATIONAL_ACTION_TYPE (rows 7-10) ------------------------------------------------------------------
# Write the NATIONAL_ACTION_TYPE variable block starting at row 7.
# We combine the action code and its description into labels like
# "FS - STATE CONDUCTED FCE/ON-SITE" so the reader can see both the code and what it means.
# trimws() removes trailing whitespace from NATIONAL_ACTION_DESC (the raw data has padded strings).

write_variable(wb, ws, 7,
  "NATIONAL_ACTION_TYPE",
  "Code for the type of enforcement or compliance action taken.",
  nat_miss, nat_ncat,
  paste0(nat$NATIONAL_ACTION_TYPE, " - ", trimws(nat$NATIONAL_ACTION_DESC)),
  nat$n, nat$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- RESULT_CODE (rows 11-14) --------------------------------------------------------------------------
# The outcome of the action. These are short codes (e.g., "MC" = met compliance).
# No separate description column exists in this dataset, so we just show the codes.

# documentation-sourced labels for result codes
rc_labels <- c(
  "PP" = "PP - Stack test passed",
  "FF" = "FF - Stack test failed",
  "99" = "99 - Pending",
  "MC" = "MC - In compliance",
  "MV" = "MV - In violation",
  "MU" = "MU - Unknown compliance status",
  "FR" = "FR - Federally reportable violation",
  "01" = "01 - Action achieved",
  "02" = "02 - Not achieved"
)
rc_descs <- ifelse(
  rc$RESULT_CODE %in% names(rc_labels),
  rc_labels[rc$RESULT_CODE],
  rc$RESULT_CODE
)

write_variable(wb, ws, 11,
  "RESULT_CODE",
  "Outcome or compliance result of the action.",
  rc_miss, rc_ncat,
  rc_descs, rc$n, rc$pct)
setRowHeights(wb, ws, rows = 11, heights = 45)

# ---- ALL_AIR_PROGRAM_CODES (rows 15-18) ----------------------------------------------------------------
# Air programs the facility falls under. NOTE: a single row can list multiple codes
# separated by commas (e.g., "0, M, V"), so the "categories" here are actually
# combinations of program codes, not individual programs.

# documentation-sourced labels for air program codes
apc_code_labels <- c(
  "0" = "SIP", "1" = "FIP (SIP under federal jurisdiction)", "3" = "Non-federally reportable",
  "4" = "CFC Tracking", "6" = "PSD", "7" = "NSR", "8" = "NESHAP (Part 61)",
  "9" = "NSPS", "A" = "Acid Precipitation", "F" = "FESOP (non-Title V)",
  "I" = "Native American", "M" = "MACT (Part 63 NESHAPS)",
  "T" = "TIP (Tribal Implementation Plan)", "V" = "Title V"
)

# expand both single-code and multi-code values using documented labels
apc_descs <- sapply(apc$ALL_AIR_PROGRAM_CODES, function(raw) {
  codes <- trimws(strsplit(raw, ",")[[1]])
  labeled <- sapply(codes, function(c) {
    if (c %in% names(apc_code_labels)) apc_code_labels[c] else c
  }, USE.NAMES = FALSE)
  paste0(raw, " (", paste(labeled, collapse = " + "), ")")
}, USE.NAMES = FALSE)

write_variable(wb, ws, 15,
  "ALL_AIR_PROGRAM_CODES",
  "Air program codes associated with the action. May contain multiple codes per row.",
  apc_miss, apc_ncat,
  apc_descs, apc$n, apc$pct)
setRowHeights(wb, ws, rows = 15, heights = 45)

# ---- POLLUTANT_CODE (rows 19-22) ----------------------------------------------------------------------
# Pollutant associated with the action. Raw codes shown (not documented in data dictionary).

write_variable(wb, ws, 19,
  "POLLUTANT_CODE",
  "Pollutant associated with the action.",
  pc_miss, pc_ncat,
  as.character(pc$POLLUTANT_CODE), pc$n, pc$pct)
setRowHeights(wb, ws, rows = 19, heights = 45)

# ---- ALL_VIOLATING_POLL_CODES (rows 23-26) ------------------------------------------------------------
# Pollutant(s) in violation — space-delimited, may contain multiple codes per row.

write_variable(wb, ws, 23,
  "ALL_VIOLATING_POLL_CODES",
  "Pollutant(s) involved in the violation. Space-delimited; may contain multiple codes per row.",
  avpc_miss, avpc_ncat,
  as.character(avpc$ALL_VIOLATING_POLL_CODES), avpc$n, avpc$pct)
setRowHeights(wb, ws, rows = 23, heights = 45)

# ---- ALL_VIOLATION_TYPE_CODES (rows 27-30) ------------------------------------------------------------
# Three-character violation type codes.

write_variable(wb, ws, 27,
  "ALL_VIOLATION_TYPE_CODES",
  "Three-character violation type codes associated with the action.",
  avtc_miss, avtc_ncat,
  as.character(avtc$ALL_VIOLATION_TYPE_CODES), avtc$n, avtc$pct)
setRowHeights(wb, ws, rows = 27, heights = 45)

# ---- Dynamic row counter from here on ------------------------------------------------------------------
# After the last categorical variable (ALL_VIOLATION_TYPE_CODES ends at row 30),
# all subsequent content uses r_next so that adding more variables above
# automatically shifts everything below.
r_next <- 30

# ---- Categorical footnotes ----------------------------------------------------------------------------
# Interpretive notes below the categorical table.
# These pull computed values so the text updates automatically if the data changes.

# Footnote 1: Summary of top action types
r_next <- r_next + 2   # skip a row after the last categorical variable
mergeCells(wb, ws, cols = 1:6, rows = r_next)
writeData(wb, ws, paste0(
  "**Top action types: ",
  trimws(nat$NATIONAL_ACTION_DESC[1]), " (", nat$NATIONAL_ACTION_TYPE[1], ") accounts for ",
  round(nat$pct[1] * 100, 1), "% of all actions. The top 4 action types together account for ",
  round(sum(nat$pct) * 100, 1), "% of the dataset. ",
  "NATIONAL_ACTION_TYPE has ", nat_ncat, " distinct codes total."),
  startRow = r_next)
addStyle(wb, ws, font12_left, rows = r_next, cols = 1)
setRowHeights(wb, ws, rows = r_next, heights = 50)

# Footnote 2: RESULT_CODE documentation gap
r_next <- r_next + 1
mergeCells(wb, ws, cols = 1:6, rows = r_next)
writeData(wb, ws, paste0(
  "**RESULT_CODE: Only PP, FF, 99, MC, MV, MU, FR, 01, and 02 are defined in the available ",
  "AFS documentation. Numeric codes like 30, 04, 25, 21 appear frequently on inspection/evaluation ",
  "actions but their meanings are not in the downloaded data dictionary. The full code list may be ",
  "in the AFS Data Download PDF (echo.epa.gov/system/files/AFS_Data_Download.pdf)."),
  startRow = r_next)
addStyle(wb, ws, font12_left, rows = r_next, cols = 1)
setRowHeights(wb, ws, rows = r_next, heights = 50)

# Footnote 3: Note about multi-code program field
r_next <- r_next + 1
mergeCells(wb, ws, cols = 1:6, rows = r_next)
writeData(wb, ws, paste0(
  "**ALL_AIR_PROGRAM_CODES contains comma-separated lists of program codes per row. ",
  "Values shown above are the most common raw combinations, expanded with documented labels."),
  startRow = r_next)
addStyle(wb, ws, font12_left, rows = r_next, cols = 1)
setRowHeights(wb, ws, rows = r_next, heights = 30)

# ---- Numerical table header ---------------------------------------------------------------------------
# Orange header row for the numerical variables section.
# Column 7 is intentionally blank (visual spacer between Median and P95).

r_next <- r_next + 2   # skip a row before the numerical section
num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = r_next, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = r_next, cols = 1:9, gridExpand = TRUE)

# ---- DATE_ACHIEVED_YEAR -------------------------------------------------------------------------------
# Write the date variable row. DATE_ACHIEVED is the date the action was completed.
# We parsed it above with ymd() and extracted years. Each statistic goes in its own column.
# Note: column 7 is skipped (the blank spacer column).

r_next <- r_next + 1
writeData(wb, ws, paste0("DATE_ACHIEVED_YEAR\nDate the action was achieved/completed. ",
                          "Parsed from YYYYMMDD format."),
          startRow = r_next, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_next, cols = 1)

# % Missing column: shows count and percentage
writeData(wb, ws, paste0(formatC(da_n_miss, format = "d", big.mark = ","),
                          " (", round(da_n_miss / n_obs * 100, 1), "%)"),
          startRow = r_next, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_next, cols = 2)

# N column: number of valid (non-missing) dates
writeData(wb, ws, da_n, startRow = r_next, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_next, cols = 3)

# Write Min/P5/Median/P95/Max into columns 4/5/6/8/9
for (yv in list(list(4, da$min), list(5, da$p5), list(6, da$med),
                list(8, da$p95), list(9, da$max))) {
  writeData(wb, ws, yv[[2]], startRow = r_next, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = r_next, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_next, cols = 7)
setRowHeights(wb, ws, rows = r_next, heights = 45)

# ---- PENALTY_AMOUNT — all -----------------------------------------------------------------------------
# Penalty statistics including $0 values.

r_next <- r_next + 1
writeData(wb, ws, "PENALTY_AMOUNT (all)\nDollar amount of the assessed penalty. Includes $0 values.",
          startRow = r_next, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_next, cols = 1)
writeData(wb, ws, pct_miss(aa$PENALTY_AMOUNT), startRow = r_next, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_next, cols = 2)
writeData(wb, ws, pen_n, startRow = r_next, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_next, cols = 3)

# Write Min/P5/Median/P95/Max with dollar formatting
for (pv in list(list(4, pen_all$min), list(5, pen_all$p5), list(6, pen_all$med),
                list(8, pen_all$p95), list(9, pen_all$max))) {
  writeData(wb, ws, pv[[2]], startRow = r_next, startCol = pv[[1]])
  addStyle(wb, ws, cell_dollar, rows = r_next, cols = pv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_next, cols = 7)
setRowHeights(wb, ws, rows = r_next, heights = 45)

# ---- PENALTY_AMOUNT — nonzero -------------------------------------------------------------------------
# Same penalty stats but EXCLUDING $0 values, so you can see the distribution of actual fines.
# The variable description notes how many actions have $0 penalty.

r_next <- r_next + 1
writeData(wb, ws, paste0("PENALTY_AMOUNT (nonzero)\nPenalties > $0 only. ",
                          formatC(n_zero, format = "d", big.mark = ","), " actions (",
                          round(n_zero / n_obs * 100, 1), "%) have $0 penalty."),
          startRow = r_next, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_next, cols = 1)
writeData(wb, ws, "N/A", startRow = r_next, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_next, cols = 2)
writeData(wb, ws, n_nonzero, startRow = r_next, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_next, cols = 3)

for (pv in list(list(4, pen_nz_stats$min), list(5, pen_nz_stats$p5), list(6, pen_nz_stats$med),
                list(8, pen_nz_stats$p95), list(9, pen_nz_stats$max))) {
  writeData(wb, ws, pv[[2]], startRow = r_next, startCol = pv[[1]])
  addStyle(wb, ws, cell_dollar, rows = r_next, cols = pv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_next, cols = 7)
setRowHeights(wb, ws, rows = r_next, heights = 50)

# ---- Numerical footnotes ------------------------------------------------------------------------------

r_next <- r_next + 2   # skip a row before footnotes
mergeCells(wb, ws, cols = 1:9, rows = r_next)
writeData(wb, ws, paste0(
  "**DATE_ACHIEVED: ", formatC(da_junk, format = "d", big.mark = ","),
  " dates fall outside a plausible range (before 1970 or after 2027) and may be data entry errors. ",
  formatC(da_n_miss, format = "d", big.mark = ","),
  " rows (", round(da_n_miss / n_obs * 100, 1), "%) have no date recorded."),
  startRow = r_next)
addStyle(wb, ws, font12_left, rows = r_next, cols = 1)
setRowHeights(wb, ws, rows = r_next, heights = 40)

r_next <- r_next + 1
mergeCells(wb, ws, cols = 1:9, rows = r_next)
writeData(wb, ws, paste0(
  "**", round(n_zero / n_obs * 100, 1),
  "% of actions carry $0 penalty — most actions are inspections or compliance reviews, not ",
  "penalty assessments. Among nonzero penalties, the median is $",
  formatC(pen_nz_stats$med, format = "d", big.mark = ","),
  " and the 95th percentile is $",
  formatC(pen_nz_stats$p95, format = "d", big.mark = ","),
  ". ", formatC(pen_miss, format = "d", big.mark = ","),
  " rows have PENALTY_AMOUNT missing (distinct from $0, which is explicitly recorded)."),
  startRow = r_next)
addStyle(wb, ws, font12_left, rows = r_next, cols = 1)
setRowHeights(wb, ws, rows = r_next, heights = 50)

# ---- Duplicates section -------------------------------------------------------------------------------

r_next <- r_next + 2   # skip a row before duplicates
mergeCells(wb, ws, cols = 1:9, rows = r_next)
writeData(wb, ws, "DUPLICATES", startRow = r_next)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = r_next, cols = 1)

r_next <- r_next + 1
mergeCells(wb, ws, cols = 1:9, rows = r_next)
writeData(wb, ws, paste0(
  formatC(n_exact_dup, format = "d", big.mark = ","),
  " exact duplicate rows (all 16 columns identical). ",
  "Actions per facility: median ", med_act, ", max ",
  formatC(max_act, format = "d", big.mark = ","),
  ". Facilities with the highest counts likely have long compliance histories ",
  "spanning AFS's operational period (pre-2014)."),
  startRow = r_next)
addStyle(wb, ws, font12_left, rows = r_next, cols = 1)
setRowHeights(wb, ws, rows = r_next, heights = 50)

r_next <- r_next + 1
mergeCells(wb, ws, cols = 1:9, rows = r_next)
writeData(wb, ws, paste0(
  "ANU1 appears to be an action sequence number within each facility. ",
  "There are ", formatC(n_distinct_anu1, format = "d", big.mark = ","),
  " distinct ANU1 values. ",
  formatC(n_dup_anu1, format = "d", big.mark = ","),
  " rows share an (AFS_ID, ANU1) pair with another row (",
  round(n_dup_anu1 / n_obs * 100, 1), "%), meaning the combination is ",
  ifelse(n_dup_anu1 == 0, "unique and can serve as a row identifier.",
         "not fully unique — some actions share the same facility and sequence number.")),
  startRow = r_next)
addStyle(wb, ws, font12_left, rows = r_next, cols = 1)
setRowHeights(wb, ws, rows = r_next, heights = 50)

# ---- Save ----------------------------------------------------------------------------------------------
# Write the finished workbook to disk as an .xlsx file. overwrite = TRUE replaces any existing file.

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/afs_actions_table.xlsx"), overwrite = TRUE)
