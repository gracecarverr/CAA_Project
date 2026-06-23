# =========================================================================================================
# 09_table-titlev-certs.R — builds the data-dictionary table for ICIS-AIR_TITLEV_CERTS.
# Each raw row is one annual compliance certification submitted by a Title V permitted facility.
# Summarizes every column and writes a formatted workbook to output/tables/titlev_certs_table.xlsx.
# Reference tooling, not part of the analysis pipeline. Short object names abbreviate the column
# summarized; suffixes: _miss = % missing, _ncat = # distinct categories. Paths via here::here().
# =========================================================================================================

library(here)
library(openxlsx)
library(readr)
library(dplyr)
library(lubridate)

# ---- Load data ------------------------------------------------------------------------------------------

tv <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_TITLEV_CERTS.csv"), show_col_types = FALSE)
n_obs <- nrow(tv)
n_fac <- n_distinct(tv$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# COMP_MONITOR_TYPE_CODE — single value
cmt <- tv |> count(COMP_MONITOR_TYPE_CODE, COMP_MONITOR_TYPE_DESC) |>
  mutate(pct = n / n_obs) |> arrange(desc(n))
cmt_miss <- pct_miss(tv$COMP_MONITOR_TYPE_CODE)
cmt_ncat <- n_cats(tv$COMP_MONITOR_TYPE_CODE)

# STATE_EPA_FLAG
sef <- top_vals(tv, STATE_EPA_FLAG, 3)
sef_miss <- pct_miss(tv$STATE_EPA_FLAG)
sef_ncat <- n_cats(tv$STATE_EPA_FLAG)

# FACILITY_RPT_DEVIATION_FLAG
dev <- top_vals(tv, FACILITY_RPT_DEVIATION_FLAG, 2)
dev_miss <- pct_miss(tv$FACILITY_RPT_DEVIATION_FLAG)
dev_ncat <- n_cats(tv$FACILITY_RPT_DEVIATION_FLAG)

# Date
aed_yr <- year(mdy(tv$ACTUAL_END_DATE))
aed_n_miss <- sum(is.na(tv$ACTUAL_END_DATE))
aed_n <- sum(!is.na(aed_yr))
aed <- list(min = min(aed_yr, na.rm = TRUE),
            p5 = as.integer(quantile(aed_yr, 0.05, na.rm = TRUE)),
            med = as.integer(median(aed_yr, na.rm = TRUE)),
            p95 = as.integer(quantile(aed_yr, 0.95, na.rm = TRUE)),
            max = max(aed_yr, na.rm = TRUE))
n_junk_dates <- sum(!is.na(aed_yr) & (aed_yr < 1990 | aed_yr > 2027))

# Deviation rate among non-missing
n_dev_yes <- sum(tv$FACILITY_RPT_DEVIATION_FLAG == "Y", na.rm = TRUE)
n_dev_no  <- sum(tv$FACILITY_RPT_DEVIATION_FLAG == "N", na.rm = TRUE)
n_dev_total <- n_dev_yes + n_dev_no
pct_dev <- round(n_dev_yes / n_dev_total * 100, 1)

# Duplicates
n_exact_dup <- sum(duplicated(tv))
n_dup_act <- sum(duplicated(tv$ACTIVITY_ID))
n_distinct_act <- n_distinct(tv$ACTIVITY_ID)
fpf <- tv |> group_by(PGM_SYS_ID) |> summarise(n = n(), .groups = "drop")
n_multi <- sum(fpf$n > 1)
max_certs <- max(fpf$n)
med_certs <- as.integer(median(fpf$n))

# Certs per facility per year
certs_per_yr <- tv |>
  mutate(year = year(mdy(ACTUAL_END_DATE))) |>
  filter(!is.na(year), year >= 1990, year <= 2026) |>
  group_by(PGM_SYS_ID, year) |>
  summarise(n = n(), .groups = "drop")
n_multi_per_yr <- sum(certs_per_yr$n > 1)

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Title V Certs")
ws <- "Title V Certs"

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
setColWidths(wb, ws, cols = 4, widths = 45)
setColWidths(wb, ws, cols = 5:9, widths = 14)

# ---- Header block ---------------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "ICIS-Air Title V Certifications (ICIS-AIR_TITLEV_CERTS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Annual compliance certifications submitted by facilities holding Title V operating permits. ",
  "Title V requires major sources to certify their compliance status each year. Each row is one ",
  "certification receipt/review event."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES: ", formatC(n_fac, format = "d", big.mark = ","),
                          "  TEMPORAL COVERAGE: ", aed$min, " - ", aed$max),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID, ACTIVITY_ID | DATE: ACTUAL_END_DATE",
          startRow = 4)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center"),
         rows = 4, cols = 1)

# ---- Categorical table header (row 6) ------------------------------------------------------------------

cat_headers <- c("Variable", "% Missing", "# Categories", "Frequent Values", "N", "%")
writeData(wb, ws, t(cat_headers), startRow = 6, colNames = FALSE)
addStyle(wb, ws, green_header, rows = 6, cols = 1:6, gridExpand = TRUE)

# ---- Helper function ------------------------------------------------------------------------------------

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

# ---- COMP_MONITOR_TYPE_CODE (row 7) -------------------------------------------------------------------

write_variable(wb, ws, 7,
  "COMP_MONITOR_TYPE_CODE",
  "Type of compliance monitoring. All records are Title V ACC reviews.",
  cmt_miss, cmt_ncat,
  paste0(cmt$COMP_MONITOR_TYPE_CODE, " - ", cmt$COMP_MONITOR_TYPE_DESC),
  cmt$n, cmt$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- STATE_EPA_FLAG (rows 8-10) -----------------------------------------------------------------------

write_variable(wb, ws, 8,
  "STATE_EPA_FLAG",
  "Which agency received and reviewed the certification.",
  sef_miss, sef_ncat,
  c("S - State", "L - Local", "E - EPA"),
  sef$n, sef$pct)
setRowHeights(wb, ws, rows = 8, heights = 40)

# ---- FACILITY_RPT_DEVIATION_FLAG (rows 11-12) ---------------------------------------------------------

write_variable(wb, ws, 11,
  "FACILITY_RPT_DEVIATION_FLAG",
  "Whether the facility reported any deviations from permit conditions in its certification.",
  dev_miss, dev_ncat,
  c("N - No deviations reported", "Y - Deviations reported"),
  dev$n, dev$pct)
setRowHeights(wb, ws, rows = 11, heights = 50)

# ---- Categorical footnote (row 13) --------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 13)
writeData(wb, ws, paste0(
  "**COMP_MONITOR_TYPE_CODE is 100% TVA (Title V ACC Receipt/Review) — this table only contains ",
  "certification records. FACILITY_RPT_DEVIATION_FLAG is ", dev_miss, " missing. Among records ",
  "with a value, ", pct_dev, "% report deviations from permit conditions."),
  startRow = 13)
addStyle(wb, ws, font12_left, rows = 13, cols = 1)
setRowHeights(wb, ws, rows = 13, heights = 40)

# ---- Numerical table header (row 15) ------------------------------------------------------------------

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 15, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 15, cols = 1:9, gridExpand = TRUE)

# ---- ACTUAL_END_DATE_YEAR (row 16) --------------------------------------------------------------------

writeData(wb, ws, "ACTUAL_END_DATE_YEAR\nDate the certification was received or reviewed.",
          startRow = 16, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 16, cols = 1)

writeData(wb, ws, paste0(formatC(aed_n_miss, format = "d", big.mark = ","), " records (",
                          round(aed_n_miss / n_obs * 100, 1), "%)"),
          startRow = 16, startCol = 2)
addStyle(wb, ws, cell_border, rows = 16, cols = 2)

writeData(wb, ws, aed_n, startRow = 16, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 16, cols = 3)

for (yv in list(list(4, aed$min), list(5, aed$p5), list(6, aed$med),
                list(8, aed$p95), list(9, aed$max))) {
  writeData(wb, ws, yv[[2]], startRow = 16, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = 16, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = 16, cols = 7)
setRowHeights(wb, ws, rows = 16, heights = 45)

# ---- Numerical footnote (row 18) ----------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 18)
writeData(wb, ws, paste0(
  "**", n_junk_dates, " records have dates outside the 1990-2027 range. ",
  "Title V was created by the 1990 CAA amendments, so certifications before 1990 are data artifacts. ",
  "95% of certifications fall between ", aed$p5, " and ", aed$p95, "."),
  startRow = 18)
addStyle(wb, ws, font12_left, rows = 18, cols = 1)
setRowHeights(wb, ws, rows = 18, heights = 40)

# ---- Duplicates section --------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 20)
writeData(wb, ws, "DUPLICATES", startRow = 20)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 20, cols = 1)

mergeCells(wb, ws, cols = 1:9, rows = 21)
writeData(wb, ws, paste0(
  formatC(n_exact_dup, format = "d", big.mark = ","), " exact duplicate rows (",
  round(n_exact_dup / n_obs * 100, 1), "%). ",
  "ACTIVITY_ID has ", formatC(n_dup_act, format = "d", big.mark = ","),
  " duplicate values (", formatC(n_distinct_act, format = "d", big.mark = ","),
  " distinct). Multiple rows per ACTIVITY_ID likely reflect the same certification event ",
  "reviewed by different agencies or recorded under different flags."),
  startRow = 21)
addStyle(wb, ws, font12_left, rows = 21, cols = 1)
setRowHeights(wb, ws, rows = 21, heights = 50)

mergeCells(wb, ws, cols = 1:9, rows = 22)
writeData(wb, ws, paste0(
  formatC(n_multi, format = "d", big.mark = ","), " facilities (",
  round(n_multi / n_fac * 100, 1),
  "%) have 2+ certification records (max ", formatC(max_certs, format = "d", big.mark = ","),
  "; median ", med_certs, "). This is expected — Title V requires annual certifications, ",
  "so a facility operating for 20 years should have ~20 records. ",
  formatC(n_multi_per_yr, format = "d", big.mark = ","),
  " facility-year combinations have more than one certification in the same year."),
  startRow = 22)
addStyle(wb, ws, font12_left, rows = 22, cols = 1)
setRowHeights(wb, ws, rows = 22, heights = 50)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/titlev_certs_table.xlsx"), overwrite = TRUE)
