# =========================================================================================================
# 09_table-afs-hpv.R — data-dictionary table for the legacy AFS_HPV_HISTORY dataset.
# Writes output/tables/afs_hpv_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------
# here      — resolves project-root-relative paths (replaces a hardcoded working directory)
# openxlsx  — builds and formats the Excel workbook
# readr     — fast CSV reading with read_csv()
# dplyr     — data wrangling (filter, count, group_by, etc.)
# lubridate — parses date strings into proper Date objects so we can extract years

library(here)
library(openxlsx)
library(readr)
library(dplyr)
library(lubridate)

# ---- Load data ------------------------------------------------------------------------------------------
# Each row in this file is one HPV (High Priority Violation) event from the legacy AFS system.
# It records when the violation was identified (day-zero) and when it was resolved.

hpv <- read_csv(here("data/raw/afs_downloads/AFS_HPV_HISTORY.csv"), show_col_types = FALSE)
n_obs <- nrow(hpv)
n_fac <- n_distinct(hpv$AFS_ID)

# ---- Helper functions -----------------------------------------------------------------------------------
# pct_miss  — returns the % of values that are NA as a string like "12.3%"
# n_cats    — counts how many unique values a column has
# top_vals  — finds the n_top most common values and their share of all rows

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# date_stats — parses a date column (trying mdy first), extracts years, and returns
#              summary statistics: missingness, min, p5, median, p95, max
date_stats <- function(date_col) {
  # Try mdy first (the AFS dates are in MM/DD/YYYY format)
  parsed <- mdy(date_col, quiet = TRUE)
  yr <- year(parsed)
  n_miss <- sum(is.na(yr))
  n_valid <- sum(!is.na(yr))
  list(
    n_miss = n_miss,
    miss_label = paste0(formatC(n_miss, format = "d", big.mark = ","), " (",
                        round(n_miss / length(date_col) * 100, 1), "%)"),
    n = n_valid,
    min = min(yr, na.rm = TRUE),
    p5 = as.integer(quantile(yr, 0.05, na.rm = TRUE)),
    med = as.integer(median(yr, na.rm = TRUE)),
    p95 = as.integer(quantile(yr, 0.95, na.rm = TRUE)),
    max = max(yr, na.rm = TRUE)
  )
}

# ---- Compute statistics ---------------------------------------------------------------------------------

# --- Categorical variables ---

# HPV_DAYZERO_TYPE — the code for how the HPV was identified (top 4)
dzt <- top_vals(hpv, HPV_DAYZERO_TYPE, 4)
dzt_miss <- pct_miss(hpv$HPV_DAYZERO_TYPE)
dzt_ncat <- n_cats(hpv$HPV_DAYZERO_TYPE)

# Build combined labels: TYPE - DESC (trimming trailing whitespace from DESC)
# We join the top types back to the original data to grab the corresponding descriptions
dzt_descs_lookup <- hpv |>
  filter(!is.na(HPV_DAYZERO_TYPE)) |>
  distinct(HPV_DAYZERO_TYPE, HPV_DAYZERO_DESC) |>
  mutate(HPV_DAYZERO_DESC = trimws(HPV_DAYZERO_DESC))
dzt_labels <- dzt |>
  left_join(dzt_descs_lookup, by = "HPV_DAYZERO_TYPE") |>
  mutate(label = paste0(HPV_DAYZERO_TYPE, " - ", HPV_DAYZERO_DESC))

# HPV_RESOLVED_TYPE — the code for how the HPV was resolved (top 4)
rst <- top_vals(hpv, HPV_RESOLVED_TYPE, 4)
rst_miss <- pct_miss(hpv$HPV_RESOLVED_TYPE)
rst_ncat <- n_cats(hpv$HPV_RESOLVED_TYPE)

rst_descs_lookup <- hpv |>
  filter(!is.na(HPV_RESOLVED_TYPE)) |>
  distinct(HPV_RESOLVED_TYPE, HPV_RESOLVED_DESC) |>
  mutate(HPV_RESOLVED_DESC = trimws(HPV_RESOLVED_DESC))
rst_labels <- rst |>
  left_join(rst_descs_lookup, by = "HPV_RESOLVED_TYPE") |>
  mutate(label = paste0(HPV_RESOLVED_TYPE, " - ", HPV_RESOLVED_DESC))

# --- Numerical / Date variables ---

dz_date  <- date_stats(hpv$HPV_DAYZERO_DATE)
res_date <- date_stats(hpv$HPV_RESOLVED_DATE)

# Resolution time in days: how long it took to resolve each HPV
# Only computed for rows where both dates are valid
dz_parsed  <- mdy(hpv$HPV_DAYZERO_DATE, quiet = TRUE)
res_parsed <- mdy(hpv$HPV_RESOLVED_DATE, quiet = TRUE)
res_days   <- as.numeric(difftime(res_parsed, dz_parsed, units = "days"))

# Keep only valid (non-NA, non-negative) resolution times
res_days_valid <- res_days[!is.na(res_days)]
n_res_valid    <- length(res_days_valid)
n_res_miss     <- n_obs - n_res_valid
res_miss_label <- paste0(formatC(n_res_miss, format = "d", big.mark = ","), " (",
                         round(n_res_miss / n_obs * 100, 1), "%)")
res_min  <- as.integer(min(res_days_valid, na.rm = TRUE))
res_p5   <- as.integer(quantile(res_days_valid, 0.05, na.rm = TRUE))
res_med  <- as.integer(median(res_days_valid, na.rm = TRUE))
res_p95  <- as.integer(quantile(res_days_valid, 0.95, na.rm = TRUE))
res_max  <- as.integer(max(res_days_valid, na.rm = TRUE))

# Temporal coverage — the earliest and latest years across both date columns
all_mins <- c(dz_date$min, res_date$min)
all_maxs <- c(dz_date$max, res_date$max)
temp_min <- min(all_mins)
temp_max <- max(all_maxs)

# --- Duplicates ---
n_exact_dup <- sum(duplicated(hpv))
# How many facilities appear more than once (i.e., have multiple HPV events)?
hpv_per_fac <- hpv |> group_by(AFS_ID) |> summarise(n = n(), .groups = "drop")
n_multi     <- sum(hpv_per_fac$n > 1)
max_hpv     <- max(hpv_per_fac$n)
med_hpv     <- as.integer(median(hpv_per_fac$n))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "AFS HPV History")
ws <- "AFS HPV History"

# ---- Styles ---------------------------------------------------------------------------------------------

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
cell_year <- createStyle(border = "TopBottomLeftRight", halign = "center",
                          valign = "center", numFmt = "0",
                          fontName = "Calibri", fontSize = 12)

# ---- Column widths --------------------------------------------------------------------------------------

setColWidths(wb, ws, cols = 1, widths = 30)
setColWidths(wb, ws, cols = 2, widths = 18)
setColWidths(wb, ws, cols = 3, widths = 14)
setColWidths(wb, ws, cols = 4, widths = 55)
setColWidths(wb, ws, cols = 5:9, widths = 14)

# ---- Header block (rows 1-4) ---------------------------------------------------------------------------
# Row 1: Title
# Row 2: Description of the dataset
# Row 3: Observation and facility counts + temporal coverage
# Row 4: Identifier columns

mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "AFS HPV History (AFS_HPV_HISTORY.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "High Priority Violation tracking from EPA's legacy AFS system. Each row links an HPV ",
  "day-zero event (when the violation was identified) to its resolution."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES: ", formatC(n_fac, format = "d", big.mark = ","),
                          "  TEMPORAL COVERAGE: ", temp_min, " - ", temp_max),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: AFS_ID", startRow = 4)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center"),
         rows = 4, cols = 1)

# ---- Categorical table header (row 6) ------------------------------------------------------------------

cat_headers <- c("Variable", "% Missing", "# Categories", "Frequent Values", "N", "%")
writeData(wb, ws, t(cat_headers), startRow = 6, colNames = FALSE)
addStyle(wb, ws, green_header, rows = 6, cols = 1:6, gridExpand = TRUE)

# ---- Helper: write_variable -----------------------------------------------------------------------------
# Writes one variable's block into the categorical table.
# var_name  — column name (bold in col 1)
# var_desc  — plain-language description (appended below var_name in col 1)
# pct_missing — string like "12.3%" (col 2)
# n_cats    — number of distinct values (col 3)
# descs     — character vector of value labels (col 4, one per row)
# ns        — count for each value (col 5)
# pcts      — proportion for each value (col 6, formatted as %)

write_variable <- function(wb, ws, start_row, var_name, var_desc, pct_missing, n_cats,
                           descs, ns, pcts) {
  n_vals <- length(descs)
  end_row <- start_row + n_vals - 1

  writeData(wb, ws, paste0(var_name, "\n", var_desc), startRow = start_row, startCol = 1)
  if (n_vals > 1) mergeCells(wb, ws, cols = 1, rows = start_row:end_row)
  addStyle(wb, ws, cell_border_bold, rows = start_row, cols = 1)

  writeData(wb, ws, pct_missing, startRow = start_row, startCol = 2)
  if (n_vals > 1) mergeCells(wb, ws, cols = 2, rows = start_row:end_row)
  addStyle(wb, ws, cell_border, rows = start_row, cols = 2)

  writeData(wb, ws, n_cats, startRow = start_row, startCol = 3)
  if (n_vals > 1) mergeCells(wb, ws, cols = 3, rows = start_row:end_row)
  addStyle(wb, ws, cell_border, rows = start_row, cols = 3)

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

# ---- HPV_DAYZERO_TYPE (rows 7-10) ----------------------------------------------------------------------
# How the HPV was identified — the type code paired with its description

write_variable(wb, ws, 7,
  "HPV_DAYZERO_TYPE",
  "Code for how the HPV day-zero was established. Paired with HPV_DAYZERO_DESC.",
  dzt_miss, dzt_ncat,
  dzt_labels$label, dzt$n, dzt$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- HPV_RESOLVED_TYPE (rows 11-14) --------------------------------------------------------------------
# How the HPV was resolved — the type code paired with its description

write_variable(wb, ws, 11,
  "HPV_RESOLVED_TYPE",
  "Code for how the HPV was resolved. Paired with HPV_RESOLVED_DESC.",
  rst_miss, rst_ncat,
  rst_labels$label, rst$n, rst$pct)
setRowHeights(wb, ws, rows = 11, heights = 45)

# ---- Categorical footnotes -----------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 16)
writeData(wb, ws, paste0(
  "**HPV_DAYZERO_TYPE tells you who or what triggered the violation clock. The most common type is '",
  trimws(dzt_labels$label[1]), "' (", round(dzt$pct[1] * 100), "%). ",
  "HPV_RESOLVED_TYPE shows how it was closed — '",
  trimws(rst_labels$label[1]), "' accounts for ",
  round(rst$pct[1] * 100), "% of resolutions."),
  startRow = 16)
addStyle(wb, ws, font12_left, rows = 16, cols = 1)
setRowHeights(wb, ws, rows = 16, heights = 45)

mergeCells(wb, ws, cols = 1:6, rows = 17)
writeData(wb, ws, paste0(
  "**HPV_RESOLVED_TYPE is ", rst_miss, " missing — rows without a resolved type represent ",
  "HPVs that were still open or had incomplete records when the AFS system was frozen in October 2014."),
  startRow = 17)
addStyle(wb, ws, font12_left, rows = 17, cols = 1)
setRowHeights(wb, ws, rows = 17, heights = 30)

# ---- Numerical table header (row 19) -------------------------------------------------------------------
# The numerical section covers date-year distributions and resolution time

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 19, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 19, cols = 1:9, gridExpand = TRUE)

# ---- Date rows (rows 20-21) — year distributions -------------------------------------------------------

date_vars <- list(
  list(name = "HPV_DAYZERO_DATE\nDate the HPV was identified (day-zero). Parsed as year.", d = dz_date),
  list(name = "HPV_RESOLVED_DATE\nDate the HPV was resolved or closed. Parsed as year.", d = res_date)
)

for (i in seq_along(date_vars)) {
  r <- 19 + i
  dv <- date_vars[[i]]
  d <- dv$d
  writeData(wb, ws, dv$name, startRow = r, startCol = 1)
  addStyle(wb, ws, cell_border_bold, rows = r, cols = 1)
  writeData(wb, ws, d$miss_label, startRow = r, startCol = 2)
  addStyle(wb, ws, cell_border, rows = r, cols = 2)
  writeData(wb, ws, d$n, startRow = r, startCol = 3)
  addStyle(wb, ws, cell_comma, rows = r, cols = 3)
  writeData(wb, ws, d$min, startRow = r, startCol = 4)
  addStyle(wb, ws, cell_year, rows = r, cols = 4)
  writeData(wb, ws, d$p5, startRow = r, startCol = 5)
  addStyle(wb, ws, cell_year, rows = r, cols = 5)
  writeData(wb, ws, d$med, startRow = r, startCol = 6)
  addStyle(wb, ws, cell_year, rows = r, cols = 6)
  addStyle(wb, ws, cell_border, rows = r, cols = 7)
  writeData(wb, ws, d$p95, startRow = r, startCol = 8)
  addStyle(wb, ws, cell_year, rows = r, cols = 8)
  writeData(wb, ws, d$max, startRow = r, startCol = 9)
  addStyle(wb, ws, cell_year, rows = r, cols = 9)
  setRowHeights(wb, ws, rows = r, heights = 40)
}

# ---- Resolution time row (row 22) -----------------------------------------------------------------------

r_res <- 22
writeData(wb, ws, "Resolution Time (days)\nDays between HPV_DAYZERO_DATE and HPV_RESOLVED_DATE.", startRow = r_res, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_res, cols = 1)
writeData(wb, ws, res_miss_label, startRow = r_res, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_res, cols = 2)
writeData(wb, ws, n_res_valid, startRow = r_res, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_res, cols = 3)
writeData(wb, ws, res_min, startRow = r_res, startCol = 4)
addStyle(wb, ws, cell_comma, rows = r_res, cols = 4)
writeData(wb, ws, res_p5, startRow = r_res, startCol = 5)
addStyle(wb, ws, cell_comma, rows = r_res, cols = 5)
writeData(wb, ws, res_med, startRow = r_res, startCol = 6)
addStyle(wb, ws, cell_comma, rows = r_res, cols = 6)
addStyle(wb, ws, cell_border, rows = r_res, cols = 7)
writeData(wb, ws, res_p95, startRow = r_res, startCol = 8)
addStyle(wb, ws, cell_comma, rows = r_res, cols = 8)
writeData(wb, ws, res_max, startRow = r_res, startCol = 9)
addStyle(wb, ws, cell_comma, rows = r_res, cols = 9)
setRowHeights(wb, ws, rows = r_res, heights = 40)

# ---- Numerical footnotes -------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 24)
writeData(wb, ws, paste0(
  "**Dates are from the legacy AFS system (frozen October 2014). Some entries may contain ",
  "data-entry errors (e.g., very early years). ",
  "HPV_RESOLVED_DATE is missing for HPVs that were still unresolved when AFS was frozen."),
  startRow = 24)
addStyle(wb, ws, font12_left, rows = 24, cols = 1)
setRowHeights(wb, ws, rows = 24, heights = 40)

mergeCells(wb, ws, cols = 1:9, rows = 25)
writeData(wb, ws, paste0(
  "**Resolution time is computed only for rows where both dates parse successfully. ",
  "Median resolution is reported in days alongside the 5th and 95th percentiles to show ",
  "the typical range. Negative values, if present, indicate data-entry errors."),
  startRow = 25)
addStyle(wb, ws, font12_left, rows = 25, cols = 1)
setRowHeights(wb, ws, rows = 25, heights = 40)

# ---- Duplicates section ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 27)
writeData(wb, ws, "DUPLICATES", startRow = 27)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 27, cols = 1)

mergeCells(wb, ws, cols = 1:9, rows = 28)
writeData(wb, ws, paste0(
  "Exact duplicate rows: ", formatC(n_exact_dup, format = "d", big.mark = ","), ". ",
  "AFS_ID is not unique — facilities can have multiple HPV events over time. ",
  formatC(n_multi, format = "d", big.mark = ","),
  " facilities have 2+ HPV records (max ", formatC(max_hpv, format = "d", big.mark = ","),
  "; median ", med_hpv, "). This is expected: a facility may accumulate ",
  "multiple violations across different inspections or time periods."),
  startRow = 28)
addStyle(wb, ws, font12_left, rows = 28, cols = 1)
setRowHeights(wb, ws, rows = 28, heights = 55)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/afs_hpv_table.xlsx"), overwrite = TRUE)
