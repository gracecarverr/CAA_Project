# ===========================================================================================================
# 09_table-afs-hist-compliance.R
#
# Builds a formatted Excel summary table for the AFS Air Program Historical Compliance dataset.
# This is a LEGACY dataset from the older AFS system (predecessor to ICIS-Air). It records monthly
# compliance status snapshots for each facility-program combination over time — something the current
# ICIS-Air Programs table (which is a single snapshot) cannot do.
#
# The output is a single .xlsx file with:
#   1. A header block describing the dataset
#   2. A categorical section (green) for AIR_PROGRAM_CODE and HISTORICAL_COMPLIANCE_STATUS
#   3. A numerical section (orange) for HISTORICAL_COMPLIANCE_DATE (treated as raw numeric codes)
#   4. A duplicates section
#   5. Footnotes
#
# INPUT:  data/raw/afs_downloads/AFS_AIR_PRG_HIST_COMPLIANCE.csv  (~10.2M rows)
# OUTPUT: output/tables/afs_hist_compliance_table.xlsx
# ===========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------
# here:     resolves project-root-relative paths (replaces a hardcoded working directory)
# openxlsx: builds and formats Excel workbooks without needing Excel installed
# readr:    fast CSV reading (important here — 10M+ rows)
# dplyr:    data wrangling verbs (count, filter, summarise, etc.)

library(here)
library(openxlsx)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# This file has ~10.2M rows. Each row is one facility-program's compliance status at a point in time.
# Columns: AFS_ID, AIR_PROGRAM_CODE, HISTORICAL_COMPLIANCE_DATE, HISTORICAL_COMPLIANCE_STATUS
# We do NOT clean or modify anything — we report what's in the raw file. Paths via here::here() (.git).

hist <- read_csv(here("data/raw/afs_downloads/AFS_AIR_PRG_HIST_COMPLIANCE.csv"), show_col_types = FALSE)
n_obs <- nrow(hist)
n_fac <- n_distinct(hist$AFS_ID)

# ---- Helper functions ------------------------------------------------------------------------------------
# These are reused across all summary table scripts. They compute simple descriptive statistics.

# pct_miss: what share of a column is NA? Returns a string like "2.3%"
pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")

# n_cats: how many unique values does a column have?
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

# top_vals: returns the most common values in a column, with counts and shares
top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# ---- Compute statistics: categorical variables -----------------------------------------------------------

# AIR_PROGRAM_CODE — these are short codes like "0", "V", "M" identifying which CAA program applies
apc <- hist |> filter(!is.na(AIR_PROGRAM_CODE)) |> count(AIR_PROGRAM_CODE) |>
  arrange(desc(n)) |> slice_head(n = 6) |> mutate(pct = n / n_obs)
apc_miss <- pct_miss(hist$AIR_PROGRAM_CODE)
apc_ncat <- n_cats(hist$AIR_PROGRAM_CODE)

# HISTORICAL_COMPLIANCE_STATUS — single-digit codes (e.g., "3", "9") whose meanings require
# cross-referencing with AFS documentation. We report all distinct values.
hcs <- hist |> filter(!is.na(HISTORICAL_COMPLIANCE_STATUS)) |>
  count(HISTORICAL_COMPLIANCE_STATUS) |> arrange(desc(n)) |>
  mutate(pct = n / n_obs)
hcs_miss <- pct_miss(hist$HISTORICAL_COMPLIANCE_STATUS)
hcs_ncat <- n_cats(hist$HISTORICAL_COMPLIANCE_STATUS)

# ---- Compute statistics: numerical variable --------------------------------------------------------------

# HISTORICAL_COMPLIANCE_DATE — these are numeric codes (e.g., 1302, 9801), NOT actual dates.
# We treat them as raw numbers and compute standard summary statistics on those numbers.
# The format *appears* to be YYMM (so 1302 = Feb 2013, 9801 = Jan 1998), but this is an inference
# from the data values, not confirmed by documentation. We flag this in the footnotes.

hcd_num <- as.numeric(hist$HISTORICAL_COMPLIANCE_DATE)
hcd_miss <- sum(is.na(hcd_num))
hcd_n    <- sum(!is.na(hcd_num))
hcd_stats <- list(
  min = min(hcd_num, na.rm = TRUE),
  p5  = as.integer(quantile(hcd_num, 0.05, na.rm = TRUE)),
  med = as.integer(median(hcd_num, na.rm = TRUE)),
  p95 = as.integer(quantile(hcd_num, 0.95, na.rm = TRUE)),
  max = max(hcd_num, na.rm = TRUE)
)

# ---- Compute statistics: duplicates ----------------------------------------------------------------------

# Exact duplicate rows — are there any rows that are completely identical?
n_exact_dup <- sum(duplicated(hist))

# Records per facility — how many rows does each AFS_ID have?
# This tells you how much historical data is available per facility.
fac_recs <- hist |> group_by(AFS_ID) |> summarise(n_rec = n(), .groups = "drop")
max_per_fac    <- max(fac_recs$n_rec)
median_per_fac <- median(fac_recs$n_rec)

# Distinct facility-program combinations — this is the natural "unit" of the dataset.
# Each facility-program pair can have many monthly snapshots over time.
n_fac_prog <- n_distinct(hist |> select(AFS_ID, AIR_PROGRAM_CODE))

# Records per facility-program combination — how many months of history per enrollment?
fac_prog_recs <- hist |>
  group_by(AFS_ID, AIR_PROGRAM_CODE) |>
  summarise(n_rec = n(), .groups = "drop")
max_per_fp    <- max(fac_prog_recs$n_rec)
median_per_fp <- median(fac_prog_recs$n_rec)

# ---- Create workbook -------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Hist Compliance")
ws <- "Hist Compliance"

# ---- Styles ----------------------------------------------------------------------------------------------
# These match the formatting used across all summary table scripts in this project.

font_title <- createStyle(fontName = "Calibri", fontSize = 15, textDecoration = "bold",
                          halign = "center")
font12_left <- createStyle(fontName = "Calibri", fontSize = 12, halign = "left",
                            valign = "top", wrapText = TRUE)

green_header <- createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                             halign = "center", valign = "center", wrapText = TRUE,
                             fgFill = "#C6EFCE", border = "TopBottomLeftRight")
orange_header <- createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center", valign = "center", wrapText = TRUE,
                              fgFill = "#F4B084", border = "TopBottomLeftRight")

cell_border <- createStyle(border = "TopBottomLeftRight", halign = "center",
                            valign = "center", wrapText = TRUE,
                            fontName = "Calibri", fontSize = 12)
cell_border_bold <- createStyle(border = "TopBottomLeftRight", halign = "center",
                                 valign = "center", wrapText = TRUE,
                                 fontName = "Calibri", fontSize = 12, textDecoration = "bold")
cell_pct <- createStyle(border = "TopBottomLeftRight", halign = "center",
                         valign = "center", numFmt = "0.0%",
                         fontName = "Calibri", fontSize = 12)
cell_comma <- createStyle(border = "TopBottomLeftRight", halign = "center",
                           valign = "center", numFmt = "#,##0",
                           fontName = "Calibri", fontSize = 12)
cell_num <- createStyle(border = "TopBottomLeftRight", halign = "center",
                         valign = "center", numFmt = "0",
                         fontName = "Calibri", fontSize = 12)

# ---- Column widths ---------------------------------------------------------------------------------------

setColWidths(wb, ws, cols = 1, widths = 30)
setColWidths(wb, ws, cols = 2, widths = 18)
setColWidths(wb, ws, cols = 3, widths = 14)
setColWidths(wb, ws, cols = 4, widths = 55)
setColWidths(wb, ws, cols = 5:6, widths = 14)
setColWidths(wb, ws, cols = 7:9, widths = 14)

# ---- Header block (rows 1-4) ----------------------------------------------------------------------------
# This block gives the reader a quick orientation: what file, what it contains, how big it is.

# Row 1: title
mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "AFS Historical Compliance (AFS_AIR_PRG_HIST_COMPLIANCE.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

# Row 2: plain-language description of the dataset
mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Monthly compliance status snapshots from the legacy AFS system. Each row records one ",
  "facility-program's compliance status at a point in time. This is the historical tracking ",
  "data that ICIS-Air's current Programs table lacks."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 40)

# Row 3: counts
mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES (AFS_ID): ",
                          formatC(n_fac, format = "d", big.mark = ",")),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

# Row 4: identifier columns
mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: AFS_ID, AIR_PROGRAM_CODE, HISTORICAL_COMPLIANCE_DATE",
          startRow = 4)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center"),
         rows = 4, cols = 1)

# ---- Categorical table header (row 6) -------------------------------------------------------------------
# The green section shows categorical variables: what values appear and how often.

cat_headers <- c("Variable", "% Missing", "# Categories", "Frequent Values", "N", "%")
writeData(wb, ws, t(cat_headers), startRow = 6, colNames = FALSE)
addStyle(wb, ws, green_header, rows = 6, cols = 1:6, gridExpand = TRUE)

# ---- Helper: write_variable ------------------------------------------------------------------------------
# This function writes one variable's block into the categorical table. It handles merging cells
# when a variable has multiple frequent values, applying styles, and formatting counts/percentages.

write_variable <- function(wb, ws, start_row, var_name, var_desc, pct_missing, n_cats,
                           descs, ns, pcts) {
  n_vals <- length(descs)
  end_row <- start_row + n_vals - 1

  # Column 1: variable name + description (merged across all value rows)
  writeData(wb, ws, paste0(var_name, "\n", var_desc), startRow = start_row, startCol = 1)
  if (n_vals > 1) mergeCells(wb, ws, cols = 1, rows = start_row:end_row)
  addStyle(wb, ws, cell_border_bold, rows = start_row, cols = 1)

  # Column 2: % missing (merged)
  writeData(wb, ws, pct_missing, startRow = start_row, startCol = 2)
  if (n_vals > 1) mergeCells(wb, ws, cols = 2, rows = start_row:end_row)
  addStyle(wb, ws, cell_border, rows = start_row, cols = 2)

  # Column 3: number of distinct categories (merged)
  writeData(wb, ws, n_cats, startRow = start_row, startCol = 3)
  if (n_vals > 1) mergeCells(wb, ws, cols = 3, rows = start_row:end_row)
  addStyle(wb, ws, cell_border, rows = start_row, cols = 3)

  # Columns 4-6: one row per frequent value showing description, count, and percentage
  for (i in seq_along(descs)) {
    r <- start_row + i - 1
    writeData(wb, ws, descs[i], startRow = r, startCol = 4)
    writeData(wb, ws, ns[i], startRow = r, startCol = 5)
    writeData(wb, ws, pcts[i], startRow = r, startCol = 6)
    addStyle(wb, ws, cell_border, rows = r, cols = 4)
    addStyle(wb, ws, cell_comma, rows = r, cols = 5)
    addStyle(wb, ws, cell_pct, rows = r, cols = 6)
    addStyle(wb, ws, cell_border, rows = r, cols = 1:3, gridExpand = TRUE)
  }
}

# ---- AIR_PROGRAM_CODE (rows 7-12) -----------------------------------------------------------------------
# These are short codes identifying which CAA program the facility falls under.
# We show the top 6 most common codes.

# documentation-sourced labels for air program codes
apc_code_labels <- c(
  "0" = "SIP", "1" = "FIP (SIP under federal jurisdiction)", "3" = "Non-federally reportable",
  "4" = "CFC Tracking", "6" = "PSD", "7" = "NSR", "8" = "NESHAP (Part 61)",
  "9" = "NSPS", "A" = "Acid Precipitation", "F" = "FESOP (non-Title V)",
  "I" = "Native American", "M" = "MACT (Part 63 NESHAPS)",
  "T" = "TIP (Tribal Implementation Plan)", "V" = "Title V"
)
apc_descs <- ifelse(
  as.character(apc$AIR_PROGRAM_CODE) %in% names(apc_code_labels),
  paste0(apc$AIR_PROGRAM_CODE, " - ", apc_code_labels[as.character(apc$AIR_PROGRAM_CODE)]),
  paste0("Code: ", apc$AIR_PROGRAM_CODE)
)

write_variable(wb, ws, 7,
  "AIR_PROGRAM_CODE",
  "Which CAA air program the facility is subject to (legacy AFS codes).",
  apc_miss, apc_ncat,
  apc_descs,
  apc$n,
  apc$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- HISTORICAL_COMPLIANCE_STATUS (rows 13-N) ------------------------------------------------------------
# These are single-digit numeric codes whose exact meanings require AFS documentation.
# We show ALL distinct values since there aren't many.

# documentation-sourced labels (same code set as EPA_COMPLIANCE_STATUS in AFS Facilities)
hcs_labels <- c(
  "0" = "0 - Unknown", "1" = "1 - In Violation, No Schedule",
  "2" = "2 - In Compliance, Source Test", "3" = "3 - In Compliance, Inspection",
  "4" = "4 - In Compliance, Certification", "5" = "5 - Meeting Compliance Schedule",
  "6" = "6 - In Violation, Not Meeting Schedule", "7" = "7 - In Violation, Unknown re Schedule",
  "8" = "8 - No Applicable State Regulation", "9" = "9 - In Compliance, Shut Down",
  "D" = "D - HPV Violation (auto)", "E" = "E - FRV Violation (auto)",
  "F" = "F - HPV On Schedule (auto)", "G" = "G - FRV On Schedule (auto)",
  "H" = "H - In Compliance (auto)", "M" = "M - In Compliance, CEMs"
)
hcs_descs <- ifelse(
  as.character(hcs$HISTORICAL_COMPLIANCE_STATUS) %in% names(hcs_labels),
  hcs_labels[as.character(hcs$HISTORICAL_COMPLIANCE_STATUS)],
  paste0("Status code: ", hcs$HISTORICAL_COMPLIANCE_STATUS)
)
hcs_start <- 13
hcs_end   <- hcs_start + nrow(hcs) - 1

write_variable(wb, ws, hcs_start,
  "HISTORICAL_COMPLIANCE_STATUS",
  "Compliance status at the given date.",
  hcs_miss, hcs_ncat,
  hcs_descs,
  hcs$n,
  hcs$pct)
setRowHeights(wb, ws, rows = hcs_start, heights = 45)

# ---- Categorical footnote -------------------------------------------------------------------------------

cat_note_row <- hcs_end + 2
mergeCells(wb, ws, cols = 1:6, rows = cat_note_row)
writeData(wb, ws, paste0(
  "AIR_PROGRAM_CODE values are legacy AFS codes (e.g., '0', 'V', 'M') that may not directly ",
  "correspond to the ICIS-Air PROGRAM_CODE values. HISTORICAL_COMPLIANCE_STATUS values are ",
  "single-character codes (both letters and digits) — cross-reference with AFS documentation to ",
  "decode them (e.g., '3', '9', 'C', 'P' may represent different compliance outcomes). We report the raw codes as-is."),
  startRow = cat_note_row)
addStyle(wb, ws, font12_left, rows = cat_note_row, cols = 1)
setRowHeights(wb, ws, rows = cat_note_row, heights = 55)

# ---- Numerical table header -----------------------------------------------------------------------------
# The orange section is for variables we can treat as numeric. Here, HISTORICAL_COMPLIANCE_DATE
# contains numeric codes that we summarise with min/p5/median/p95/max.

num_header_row <- cat_note_row + 2
num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = num_header_row, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = num_header_row, cols = 1:9, gridExpand = TRUE)

# ---- HISTORICAL_COMPLIANCE_DATE (numeric summary) -------------------------------------------------------
# These are raw numeric codes — NOT dates. We compute statistics on the numbers themselves.
# If they are YYMM codes, then min/max correspond to the earliest/latest months in the data.

num_data_row <- num_header_row + 1

writeData(wb, ws, "HISTORICAL_COMPLIANCE_DATE\nRaw numeric code (appears to be YYMM — see footnote).",
          startRow = num_data_row, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = num_data_row, cols = 1)
writeData(wb, ws, pct_miss(hist$HISTORICAL_COMPLIANCE_DATE),
          startRow = num_data_row, startCol = 2)
addStyle(wb, ws, cell_border, rows = num_data_row, cols = 2)
writeData(wb, ws, hcd_n, startRow = num_data_row, startCol = 3)
addStyle(wb, ws, cell_comma, rows = num_data_row, cols = 3)

# Write each summary statistic into the appropriate column
for (yv in list(list(4, hcd_stats$min), list(5, hcd_stats$p5), list(6, hcd_stats$med),
                list(8, hcd_stats$p95), list(9, hcd_stats$max))) {
  writeData(wb, ws, yv[[2]], startRow = num_data_row, startCol = yv[[1]])
  addStyle(wb, ws, cell_num, rows = num_data_row, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = num_data_row, cols = 7)
setRowHeights(wb, ws, rows = num_data_row, heights = 45)

# ---- Numerical footnote ---------------------------------------------------------------------------------

num_note_row <- num_data_row + 2
mergeCells(wb, ws, cols = 1:9, rows = num_note_row)
writeData(wb, ws, paste0(
  "HISTORICAL_COMPLIANCE_DATE contains numeric codes, not standard dates. Based on observed values ",
  "(e.g., 1302, 9801), the format APPEARS to be YYMM — where '1302' would mean February 2013 and ",
  "'9801' would mean January 1998. However, this is an inference from the data values, not confirmed ",
  "by documentation. Verify against AFS data dictionaries before interpreting."),
  startRow = num_note_row)
addStyle(wb, ws, font12_left, rows = num_note_row, cols = 1)
setRowHeights(wb, ws, rows = num_note_row, heights = 55)

# ---- Duplicates section ----------------------------------------------------------------------------------
# This section helps you understand the structure of the data: is each row unique? How many
# records does a typical facility have? A typical facility-program pair?

dup_header_row <- num_note_row + 2
mergeCells(wb, ws, cols = 1:9, rows = dup_header_row)
writeData(wb, ws, "DUPLICATES & STRUCTURE", startRow = dup_header_row)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = dup_header_row, cols = 1)

# Exact duplicates
dup_row1 <- dup_header_row + 1
mergeCells(wb, ws, cols = 1:9, rows = dup_row1)
writeData(wb, ws, paste0(
  "Exact duplicate rows: ", formatC(n_exact_dup, format = "d", big.mark = ","),
  " (", round(n_exact_dup / n_obs * 100, 1), "% of all rows)."),
  startRow = dup_row1)
addStyle(wb, ws, font12_left, rows = dup_row1, cols = 1)
setRowHeights(wb, ws, rows = dup_row1, heights = 25)

# Records per facility
dup_row2 <- dup_row1 + 1
mergeCells(wb, ws, cols = 1:9, rows = dup_row2)
writeData(wb, ws, paste0(
  "Records per facility (AFS_ID): median = ", formatC(median_per_fac, format = "d", big.mark = ","),
  ", max = ", formatC(max_per_fac, format = "d", big.mark = ","),
  ". Each facility can have many monthly snapshots across multiple programs."),
  startRow = dup_row2)
addStyle(wb, ws, font12_left, rows = dup_row2, cols = 1)
setRowHeights(wb, ws, rows = dup_row2, heights = 30)

# Distinct facility-program combinations
dup_row3 <- dup_row2 + 1
mergeCells(wb, ws, cols = 1:9, rows = dup_row3)
writeData(wb, ws, paste0(
  "Distinct facility-program combinations (AFS_ID x AIR_PROGRAM_CODE): ",
  formatC(n_fac_prog, format = "d", big.mark = ","), "."),
  startRow = dup_row3)
addStyle(wb, ws, font12_left, rows = dup_row3, cols = 1)
setRowHeights(wb, ws, rows = dup_row3, heights = 25)

# Records per facility-program combination — this is the key structural fact:
# how many months of compliance history do we have per enrollment?
dup_row4 <- dup_row3 + 1
mergeCells(wb, ws, cols = 1:9, rows = dup_row4)
writeData(wb, ws, paste0(
  "Records per facility-program combination: median = ",
  formatC(median_per_fp, format = "d", big.mark = ","),
  ", max = ", formatC(max_per_fp, format = "d", big.mark = ","),
  ". This tells you how many months of compliance history are available per enrollment — ",
  "the core time-series depth of this dataset."),
  startRow = dup_row4)
addStyle(wb, ws, font12_left, rows = dup_row4, cols = 1)
setRowHeights(wb, ws, rows = dup_row4, heights = 40)

# ---- Final footnotes -------------------------------------------------------------------------------------

fn_row <- dup_row4 + 2
mergeCells(wb, ws, cols = 1:9, rows = fn_row)
writeData(wb, ws, paste0(
  "This dataset enables tracking compliance changes over time for individual facilities — ",
  "something ICIS-Air's current Programs snapshot table cannot do. By following a facility-program ",
  "pair across HISTORICAL_COMPLIANCE_DATE values, you can observe when a facility went in or out of ",
  "compliance and for how long. This is the longitudinal backbone of any compliance trend analysis."),
  startRow = fn_row)
addStyle(wb, ws, font12_left, rows = fn_row, cols = 1)
setRowHeights(wb, ws, rows = fn_row, heights = 55)

# ---- Save ------------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/afs_hist_compliance_table.xlsx"), overwrite = TRUE)
