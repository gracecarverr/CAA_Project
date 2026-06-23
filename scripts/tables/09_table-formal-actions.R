# =========================================================================================================
# 09_table-formal-actions.R — data-dictionary table for ICIS-AIR_FORMAL_ACTIONS.
# Writes output/tables/formal_actions_table.xlsx. Reference tooling, not part of the analysis pipeline.
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
# Read the raw CSV into a dataframe called "fa" (short for formal actions).
# Each row in this CSV is one formal enforcement action taken against a facility.

fa <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_FORMAL_ACTIONS.csv"), show_col_types = FALSE)

# Count total rows and distinct facilities — these are used throughout the script.
n_obs <- nrow(fa)                       # total number of rows in the dataset
n_fac <- n_distinct(fa$PGM_SYS_ID)      # number of unique facilities (PGM_SYS_ID is the facility ID)

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

# ---------- ACTIVITY_TYPE_CODE ----------
# This variable tells you whether the action was administrative (issued by the agency)
# or judicial (filed in court). We count occurrences of each type.

atc <- fa |> count(ACTIVITY_TYPE_CODE, ACTIVITY_TYPE_DESC) |>   # count rows per type
  mutate(pct = n / n_obs) |>                                     # calculate % of total
  arrange(desc(n))                                                # sort most common first
atc_miss <- pct_miss(fa$ACTIVITY_TYPE_CODE)                      # % missing
atc_ncat <- n_cats(fa$ACTIVITY_TYPE_CODE)                        # number of categories

# ---------- STATE_EPA_FLAG ----------
# Which agency took the action: State (S), Local (L), or EPA (E).
# We just grab the top 3 (which is all of them since there are only 3 values).

sef <- top_vals(fa, STATE_EPA_FLAG, 3)
sef_miss <- pct_miss(fa$STATE_EPA_FLAG)
sef_ncat <- n_cats(fa$STATE_EPA_FLAG)

# ---------- ENF_TYPE_CODE ----------
# The specific type of enforcement action (e.g., administrative order, civil suit, penalty action).
# There are 47 different types, so we only show the top 5 in the table.

etc <- fa |> count(ENF_TYPE_CODE, ENF_TYPE_DESC) |>   # count rows per enforcement type
  mutate(pct = n / n_obs) |> arrange(desc(n)) |>       # sort by frequency
  slice_head(n = 5)                                     # keep top 5
etc_miss <- pct_miss(fa$ENF_TYPE_CODE)
etc_ncat <- n_cats(fa$ENF_TYPE_CODE)

# ---------- SETTLEMENT_ENTERED_DATE (Date variable) ----------
# Parse the date strings into actual dates, then extract the year.
# mdy() converts strings like "03/15/2020" into proper dates.
# year() pulls out just the year (e.g., 2020).

sed_yr <- year(mdy(fa$SETTLEMENT_ENTERED_DATE))

# Count how many dates are missing in the raw data
sed_n_miss <- sum(is.na(fa$SETTLEMENT_ENTERED_DATE))

# Count how many dates successfully parsed (non-NA after parsing)
sed_n <- sum(!is.na(sed_yr))

# Compute summary statistics on the parsed years:
#   min  = earliest year
#   p5   = 5th percentile (5% of values are below this)
#   med  = median (middle value)
#   p95  = 95th percentile (95% of values are below this)
#   max  = latest year
sed <- list(min = min(sed_yr, na.rm = TRUE),
            p5 = as.integer(quantile(sed_yr, 0.05, na.rm = TRUE)),
            med = as.integer(median(sed_yr, na.rm = TRUE)),
            p95 = as.integer(quantile(sed_yr, 0.95, na.rm = TRUE)),
            max = max(sed_yr, na.rm = TRUE))

# ---------- PENALTY_AMOUNT (Numerical variable) ----------
# Dollar amount of the penalty. We compute stats twice:
#   1. Including $0 penalties (actions with no fine)
#   2. Excluding $0 penalties (to see the distribution of actual fines)

pen_miss <- sum(is.na(fa$PENALTY_AMOUNT))      # how many are missing
pen_n <- sum(!is.na(fa$PENALTY_AMOUNT))         # how many have a value

# Stats for ALL penalties (including $0)
pen_all <- list(min = min(fa$PENALTY_AMOUNT, na.rm = TRUE),
                p5 = quantile(fa$PENALTY_AMOUNT, 0.05, na.rm = TRUE),
                med = median(fa$PENALTY_AMOUNT, na.rm = TRUE),
                p95 = quantile(fa$PENALTY_AMOUNT, 0.95, na.rm = TRUE),
                max = max(fa$PENALTY_AMOUNT, na.rm = TRUE))

# How many actions have $0 penalty (compliance orders with no fine)
n_zero <- sum(fa$PENALTY_AMOUNT == 0, na.rm = TRUE)

# Filter to only rows with penalties > $0, then compute stats on those
pen_nz <- fa |> filter(!is.na(PENALTY_AMOUNT), PENALTY_AMOUNT > 0)
n_nonzero <- nrow(pen_nz)
pen_nz_stats <- list(min = min(pen_nz$PENALTY_AMOUNT),
                     p5 = quantile(pen_nz$PENALTY_AMOUNT, 0.05),
                     med = median(pen_nz$PENALTY_AMOUNT),
                     p95 = quantile(pen_nz$PENALTY_AMOUNT, 0.95),
                     max = max(pen_nz$PENALTY_AMOUNT))

# ---------- DUPLICATES ----------
# Check for duplicate rows in different ways to understand the data structure.

# Exact duplicates: rows where EVERY column is identical to another row
n_exact_dup <- sum(duplicated(fa))

# How many rows share an ACTIVITY_ID with another row
# (ACTIVITY_ID should ideally be unique, but isn't always)
n_dup_act <- sum(duplicated(fa$ACTIVITY_ID))

# How many rows share an ENF_IDENTIFIER with another row
n_dup_enf <- sum(duplicated(fa$ENF_IDENTIFIER))

# How many rows share ALL THREE identifiers (facility + action + enforcement case)
# These are rows for the same facility, same action, same case — they differ in other columns
# like PENALTY_AMOUNT or ENF_TYPE_CODE
n_dup_all3 <- sum(duplicated(fa |> select(PGM_SYS_ID, ACTIVITY_ID, ENF_IDENTIFIER)))

# How many ACTIVITY_IDs appear at DIFFERENT facilities?
# These are multi-facility enforcement actions (e.g., one lawsuit covering multiple plants)
n_diff_fac <- fa |> group_by(ACTIVITY_ID) |>                     # group rows by action ID
  filter(n() > 1, n_distinct(PGM_SYS_ID) > 1) |>                 # keep groups with 2+ rows AND 2+ facilities
  ungroup() |> distinct(ACTIVITY_ID) |> nrow()                    # count unique action IDs

# How many facilities have multiple formal actions?
fpf <- fa |> group_by(PGM_SYS_ID) |> summarise(n = n(), .groups = "drop")  # count actions per facility
n_multi <- sum(fpf$n > 1)               # facilities with 2 or more actions
max_act <- max(fpf$n)                    # facility with the most actions
med_act <- as.integer(median(fpf$n))     # median number of actions per facility

# How many ENF_IDENTIFIERs appear more than once?
# (one enforcement case generating multiple action records)
n_enf_multi <- fa |> group_by(ENF_IDENTIFIER) |> filter(n() > 1) |> ungroup() |>
  distinct(ENF_IDENTIFIER) |> nrow()

# ==================================================================================================
# EVERYTHING BELOW THIS LINE IS TABLE FORMATTING
# It writes the statistics we computed above into a formatted Excel spreadsheet.
# The pattern is: create a workbook → define styles → write data into cells → save.
# ==================================================================================================

# ---- Create workbook ------------------------------------------------------------------------------------
# Create a blank Excel workbook and add one worksheet called "Formal Actions"

wb <- createWorkbook()
addWorksheet(wb, "Formal Actions")
ws <- "Formal Actions"    # shorthand so we don't have to type the full name every time

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
setColWidths(wb, ws, cols = 4, widths = 45)     # Column D: frequent values / descriptions
setColWidths(wb, ws, cols = 5:9, widths = 14)   # Columns E-I: N, %, and numerical stats

# ---- Header block (rows 1-4) ---------------------------------------------------------------------------
# The top of the table: title, description, observation counts, and identifier list.

# Row 1: Title — merge columns A-F into one wide cell and write the table title
mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "ICIS-Air Formal Actions (ICIS-AIR_FORMAL_ACTIONS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

# Row 2: Description of the dataset
mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Formal enforcement actions taken against facilities for Clean Air Act violations. ",
  "Includes administrative orders (consent agreements, compliance orders) and judicial actions ",
  "(civil lawsuits filed in court). Each row is one enforcement action event."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 50)

# Row 3: Key counts — total observations, distinct facilities, and date range
# paste0() glues strings together. formatC() adds commas to numbers.
mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES: ", formatC(n_fac, format = "d", big.mark = ","),
                          "  TEMPORAL COVERAGE: ", sed$min, " - ", sed$max),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

# Row 4: List of identifier columns
mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID, ACTIVITY_ID, ENF_IDENTIFIER",
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
#   var_name   — the column name (e.g., "ACTIVITY_TYPE_CODE")
#   var_desc   — a plain-English description of what the variable means
#   pct_missing — string like "0%" showing how much data is missing
#   n_cats     — number of distinct categories
#   descs      — vector of value labels (e.g., "AFR - Administrative Formal")
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

# ---- ACTIVITY_TYPE_CODE (rows 7-8) ---------------------------------------------------------------------
# Write the ACTIVITY_TYPE_CODE variable block starting at row 7.
# paste0(atc$ACTIVITY_TYPE_CODE, " - ", atc$ACTIVITY_TYPE_DESC) creates labels
# like "AFR - Administrative Formal" by combining the code and description columns.

write_variable(wb, ws, 7,
  "ACTIVITY_TYPE_CODE",
  "Whether the action is administrative (agency-issued) or judicial (court-filed).",
  atc_miss, atc_ncat,
  paste0(atc$ACTIVITY_TYPE_CODE, " - ", atc$ACTIVITY_TYPE_DESC),
  atc$n, atc$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- STATE_EPA_FLAG (rows 9-11) ------------------------------------------------------------------------
# Here we use hardcoded labels ("S - State", etc.) instead of pulling from the data,
# because the raw data only has the single-letter codes (S, L, E) with no descriptions.

write_variable(wb, ws, 9,
  "STATE_EPA_FLAG",
  "Which agency took the enforcement action.",
  sef_miss, sef_ncat,
  c("S - State", "L - Local", "E - EPA"),
  sef$n, sef$pct)
setRowHeights(wb, ws, rows = 9, heights = 40)

# ---- ENF_TYPE_CODE (rows 12-16) ------------------------------------------------------------------------
# Specific enforcement action type. 47 categories exist, but we only show top 5.
# Combine code + description into labels like "SCAAAO - Administrative Order"

etc_descs <- paste0(etc$ENF_TYPE_CODE, " - ", etc$ENF_TYPE_DESC)

write_variable(wb, ws, 12,
  "ENF_TYPE_CODE",
  "Specific type of enforcement action taken.",
  etc_miss, etc_ncat,
  etc_descs, etc$n, etc$pct)
setRowHeights(wb, ws, rows = 12, heights = 45)

# ---- Categorical footnotes (rows 18-19) ----------------------------------------------------------------
# Interpretive notes below the categorical table.
# These pull computed values (like atc$pct[1]) so the text updates if the data changes.

# Footnote 1: Summary of key patterns
mergeCells(wb, ws, cols = 1:6, rows = 18)
writeData(wb, ws, paste0(
  "**", round(atc$pct[1] * 100), "% of formal actions are administrative (issued by the agency directly), only ",
  round(atc$pct[2] * 100), "% are judicial ",
  "(filed in court). Administrative orders (", round(etc$pct[1] * 100), "%) are the dominant enforcement tool. EPA takes ",
  round(sef$pct[sef$STATE_EPA_FLAG == "E"] * 100), "% of formal actions — a much larger share than its 3% of compliance monitoring, reflecting ",
  "EPA's role in escalated enforcement."),
  startRow = 18)
addStyle(wb, ws, font12_left, rows = 18, cols = 1)
setRowHeights(wb, ws, rows = 18, heights = 50)

# Footnote 2: Glossary explaining the ENF_TYPE_CODE abbreviations
mergeCells(wb, ws, cols = 1:6, rows = 19)
writeData(wb, ws, paste0(
  "**ENF_TYPE_CODE glossary: ", etc$ENF_TYPE_CODE[1], " = ", etc$ENF_TYPE_DESC[1], "; ",
  etc$ENF_TYPE_CODE[2], " = ", etc$ENF_TYPE_DESC[2], "; ",
  etc$ENF_TYPE_CODE[3], " = ", etc$ENF_TYPE_DESC[3], "; ",
  etc$ENF_TYPE_CODE[4], " = ", etc$ENF_TYPE_DESC[4], "; ",
  etc$ENF_TYPE_CODE[5], " = ", etc$ENF_TYPE_DESC[5], "."),
  startRow = 19)
addStyle(wb, ws, font12_left, rows = 19, cols = 1)
setRowHeights(wb, ws, rows = 19, heights = 40)

# ---- Numerical table header (row 21) ------------------------------------------------------------------
# Orange header row for the numerical variables section.
# Column 7 is intentionally blank (visual spacer between Median and P95).

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 21, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 21, cols = 1:9, gridExpand = TRUE)

# ---- SETTLEMENT_ENTERED_DATE_YEAR (row 22) -------------------------------------------------------------
# Write the date variable row. Each statistic goes in its own column.
# Note: column 7 is skipped (the blank spacer column).

writeData(wb, ws, "SETTLEMENT_ENTERED_DATE_YEAR\nDate the settlement or order was entered.",
          startRow = 22, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 22, cols = 1)

# % Missing column: shows count and percentage (e.g., "41 (0%)")
writeData(wb, ws, paste0(sed_n_miss, " (", round(sed_n_miss / n_obs * 100), "%)"),
          startRow = 22, startCol = 2)
addStyle(wb, ws, cell_border, rows = 22, cols = 2)

# N column: number of valid (non-missing) dates
writeData(wb, ws, sed_n, startRow = 22, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 22, cols = 3)

# Write Min/P5/Median/P95/Max into columns 4/5/6/8/9
# This loop pairs each column number with its value
for (yv in list(list(4, sed$min), list(5, sed$p5), list(6, sed$med),
                list(8, sed$p95), list(9, sed$max))) {
  writeData(wb, ws, yv[[2]], startRow = 22, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = 22, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = 22, cols = 7)   # border on the blank spacer column
setRowHeights(wb, ws, rows = 22, heights = 45)

# ---- PENALTY_AMOUNT — all (row 23) --------------------------------------------------------------------
# Penalty statistics including $0 values.

writeData(wb, ws, "PENALTY_AMOUNT (all)\nDollar amount of the assessed penalty. Includes $0 values.",
          startRow = 23, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 23, cols = 1)
writeData(wb, ws, pct_miss(fa$PENALTY_AMOUNT), startRow = 23, startCol = 2)
addStyle(wb, ws, cell_border, rows = 23, cols = 2)
writeData(wb, ws, pen_n, startRow = 23, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 23, cols = 3)

# Write Min/P5/Median/P95/Max with dollar formatting
for (pv in list(list(4, pen_all$min), list(5, pen_all$p5), list(6, pen_all$med),
                list(8, pen_all$p95), list(9, pen_all$max))) {
  writeData(wb, ws, pv[[2]], startRow = 23, startCol = pv[[1]])
  addStyle(wb, ws, cell_dollar, rows = 23, cols = pv[[1]])
}
addStyle(wb, ws, cell_border, rows = 23, cols = 7)
setRowHeights(wb, ws, rows = 23, heights = 45)

# ---- PENALTY_AMOUNT — nonzero (row 24) -----------------------------------------------------------------
# Same penalty stats but EXCLUDING $0 values, so you can see the distribution of actual fines.
# The variable description notes how many actions have $0 penalty.

writeData(wb, ws, paste0("PENALTY_AMOUNT (nonzero)\nPenalties > $0 only. ",
                          formatC(n_zero, format = "d", big.mark = ","), " actions (",
                          round(n_zero / n_obs * 100, 1), "%) have $0 penalty."),
          startRow = 24, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 24, cols = 1)
writeData(wb, ws, "N/A", startRow = 24, startCol = 2)     # "% Missing" doesn't apply here
addStyle(wb, ws, cell_border, rows = 24, cols = 2)
writeData(wb, ws, n_nonzero, startRow = 24, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 24, cols = 3)

for (pv in list(list(4, pen_nz_stats$min), list(5, pen_nz_stats$p5), list(6, pen_nz_stats$med),
                list(8, pen_nz_stats$p95), list(9, pen_nz_stats$max))) {
  writeData(wb, ws, pv[[2]], startRow = 24, startCol = pv[[1]])
  addStyle(wb, ws, cell_dollar, rows = 24, cols = pv[[1]])
}
addStyle(wb, ws, cell_border, rows = 24, cols = 7)
setRowHeights(wb, ws, rows = 24, heights = 50)

# ---- Numerical footnote (row 26) -----------------------------------------------------------------------
# Interpretive note about the penalty distribution.

mergeCells(wb, ws, cols = 1:9, rows = 26)
writeData(wb, ws, paste0(
  "**", round(n_zero / n_obs * 100, 1),
  "% of formal actions carry $0 penalty — these are compliance orders requiring corrective ",
  "action without a fine (primarily CAA 113A orders). Among nonzero penalties, the median is $",
  formatC(pen_nz_stats$med, format = "d", big.mark = ","),
  " and the 95th percentile is $",
  formatC(pen_nz_stats$p95, format = "d", big.mark = ","),
  ". The maximum ($", formatC(pen_nz_stats$max / 1e6, format = "f", digits = 1), "M) is an outlier."),
  startRow = 26)
addStyle(wb, ws, font12_left, rows = 26, cols = 1)
setRowHeights(wb, ws, rows = 26, heights = 50)

# ---- Duplicates section (rows 28-30) -------------------------------------------------------------------
# This section examines the data structure: are there duplicate rows, and if so, what do they mean?

# Row 28: Section header
mergeCells(wb, ws, cols = 1:9, rows = 28)
writeData(wb, ws, "DUPLICATES", startRow = 28)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 28, cols = 1)

# Row 29: Main duplicate analysis
# Explains three levels of duplication:
#   - n_dup_act: rows sharing an ACTIVITY_ID (not fully unique)
#   - n_dup_all3: rows sharing all 3 IDs (same facility + action + case)
#   - n_dup_act - n_dup_all3: rows sharing ACTIVITY_ID across DIFFERENT facilities
mergeCells(wb, ws, cols = 1:9, rows = 29)
writeData(wb, ws, paste0(
  "No exact duplicate rows. ACTIVITY_ID is not fully unique — ",
  formatC(n_dup_act, format = "d", big.mark = ","), " rows (",
  round(n_dup_act / n_obs * 100, 1), "%) share an ACTIVITY_ID ",
  "with at least one other row. Of these, ",
  formatC(n_dup_all3, format = "d", big.mark = ","),
  " share all three IDs (PGM_SYS_ID + ACTIVITY_ID + ",
  "ENF_IDENTIFIER) — same facility, same action, with differences in PENALTY_AMOUNT, ",
  "SETTLEMENT_ENTERED_DATE, or ENF_TYPE_CODE (e.g., multiple penalty entries or date corrections). The remaining ",
  formatC(n_dup_act - n_dup_all3, format = "d", big.mark = ","),
  " share an ACTIVITY_ID across different facilities — likely multi-facility enforcement actions ",
  "(e.g., one civil suit covering multiple co-located sources)."),
  startRow = 29)
addStyle(wb, ws, font12_left, rows = 29, cols = 1)
setRowHeights(wb, ws, rows = 29, heights = 65)

# Row 30: Per-facility action counts and ENF_IDENTIFIER patterns
mergeCells(wb, ws, cols = 1:9, rows = 30)
writeData(wb, ws, paste0(
  formatC(n_multi, format = "d", big.mark = ","), " facilities (",
  round(n_multi / n_fac * 100, 1), "%) have 2+ formal actions (max ",
  formatC(max_act, format = "d", big.mark = ","), "; median ", med_act, "). ",
  "ENF_IDENTIFIER has ", formatC(n_enf_multi, format = "d", big.mark = ","),
  " values appearing more than once (",
  formatC(n_dup_enf, format = "d", big.mark = ","),
  " rows), meaning some enforcement cases generate multiple action records — ",
  "typically when a single case involves multiple enforcement provisions or legal authorities."),
  startRow = 30)
addStyle(wb, ws, font12_left, rows = 30, cols = 1)
setRowHeights(wb, ws, rows = 30, heights = 50)

# ---- Save ----------------------------------------------------------------------------------------------
# Write the finished workbook to disk as an .xlsx file. overwrite = TRUE replaces any existing file.

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/formal_actions_table.xlsx"), overwrite = TRUE)
