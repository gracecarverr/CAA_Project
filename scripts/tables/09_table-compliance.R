# =========================================================================================================
# 09_table-compliance.R — builds the data-dictionary table for ICIS-AIR_FCES_PCES (compliance evaluations).
# Summarizes every column and writes a formatted workbook to output/tables/compliance_table.xlsx.
# Reference tooling, not part of the analysis pipeline. Short object names abbreviate the column
# summarized; suffixes: _miss = % missing, _ncat = # distinct categories. Paths via here::here().
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(openxlsx)
library(readr)
library(dplyr)
library(lubridate)

# ---- Load data ------------------------------------------------------------------------------------------

comp <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_FCES_PCES.csv"), show_col_types = FALSE)
n_obs <- nrow(comp)
n_fac <- n_distinct(comp$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# Categorical
cmt <- top_vals(comp, COMP_MONITOR_TYPE_CODE, 4)
cmt_miss <- pct_miss(comp$COMP_MONITOR_TYPE_CODE)
cmt_ncat <- n_cats(comp$COMP_MONITOR_TYPE_CODE)

sef <- top_vals(comp, STATE_EPA_FLAG, 3)
sef_miss <- pct_miss(comp$STATE_EPA_FLAG)
sef_ncat <- n_cats(comp$STATE_EPA_FLAG)

apd <- top_vals(comp, ACTIVITY_PURPOSE_DESC, 4)
apd_miss <- pct_miss(comp$ACTIVITY_PURPOSE_DESC)
apd_ncat <- n_cats(comp$ACTIVITY_PURPOSE_DESC)

atc <- comp |> count(ACTIVITY_TYPE_CODE, ACTIVITY_TYPE_DESC) |>
  mutate(pct = n / n_obs) |> arrange(desc(n))
atc_miss <- pct_miss(comp$ACTIVITY_TYPE_CODE)
atc_ncat <- n_cats(comp$ACTIVITY_TYPE_CODE)

prc <- top_vals(comp, PROGRAM_CODES, 4)
prc_miss <- pct_miss(comp$PROGRAM_CODES)
prc_ncat <- n_cats(comp$PROGRAM_CODES)

# Date
aed_yr <- year(mdy(comp$ACTUAL_END_DATE))
aed_n_miss <- sum(is.na(comp$ACTUAL_END_DATE))
aed_n <- sum(!is.na(aed_yr))
aed <- list(min = min(aed_yr, na.rm = TRUE),
            p5 = as.integer(quantile(aed_yr, 0.05, na.rm = TRUE)),
            med = as.integer(median(aed_yr, na.rm = TRUE)),
            p95 = as.integer(quantile(aed_yr, 0.95, na.rm = TRUE)),
            max = max(aed_yr, na.rm = TRUE))
n_junk_dates <- sum(!is.na(aed_yr) & (aed_yr < 1972 | aed_yr > 2026))

# Duplicates
n_exact_dup <- sum(duplicated(comp))
dup_act <- comp |> group_by(ACTIVITY_ID) |> summarise(n = n(), .groups = "drop") |> filter(n > 1)
n_dup_act_ids <- nrow(dup_act)
n_dup_act_rows <- sum(dup_act$n - 1)
cpf <- comp |> group_by(PGM_SYS_ID) |> summarise(n = n(), .groups = "drop")
n_multi <- sum(cpf$n > 1)
max_insp <- max(cpf$n)
med_insp <- as.integer(median(cpf$n))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Compliance")
ws <- "Compliance"

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
writeData(wb, ws, "ICIS-Air Compliance Monitoring (ICIS-AIR_FCES_PCES.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Compliance monitoring activities — inspections and evaluations conducted at regulated facilities. ",
  "Full Compliance Evaluations (FCEs) are comprehensive on-site inspections. Partial Compliance ",
  "Evaluations (PCEs) cover a subset of requirements and can be on-site or off-site (document review)."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 50)

mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES: ", formatC(n_fac, format = "d", big.mark = ","),
                          "  TEMPORAL COVERAGE: ", aed$min, " - ", aed$max),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID, ACTIVITY_ID  |  DATE: ACTUAL_END_DATE",
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

# ---- COMP_MONITOR_TYPE_CODE (rows 7-10) ----------------------------------------------------------------

cmt_labels <- c("FOO" = "FCE On-Site", "PFF" = "PCE Off-Site",
                "PCE" = "PCE On-Site", "POR" = "PCE Record/Report Review")
cmt_descs <- paste0(cmt$COMP_MONITOR_TYPE_CODE, " - ", cmt_labels[cmt$COMP_MONITOR_TYPE_CODE])

write_variable(wb, ws, 7,
  "COMP_MONITOR_TYPE_CODE",
  "Type of compliance evaluation conducted.",
  cmt_miss, cmt_ncat, cmt_descs, cmt$n, cmt$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- STATE_EPA_FLAG (rows 11-13) -----------------------------------------------------------------------

write_variable(wb, ws, 11,
  "STATE_EPA_FLAG",
  "Which agency conducted the inspection.",
  sef_miss, sef_ncat,
  c("S - State", "L - Local", "E - EPA"),
  sef$n, sef$pct)
setRowHeights(wb, ws, rows = 11, heights = 40)

# ---- ACTIVITY_PURPOSE_DESC (rows 14-17) ----------------------------------------------------------------

write_variable(wb, ws, 14,
  "ACTIVITY_PURPOSE_DESC",
  "Reason for the monitoring activity.",
  apd_miss, apd_ncat,
  apd$ACTIVITY_PURPOSE_DESC, apd$n, apd$pct)
setRowHeights(wb, ws, rows = 14, heights = 40)

# ---- ACTIVITY_TYPE_CODE (row 18) -----------------------------------------------------------------------

write_variable(wb, ws, 18,
  "ACTIVITY_TYPE_CODE",
  "Type of compliance activity. All records in this table are inspections/evaluations.",
  atc_miss, atc_ncat,
  paste0(atc$ACTIVITY_TYPE_CODE, " - ", atc$ACTIVITY_TYPE_DESC),
  atc$n, atc$pct)
setRowHeights(wb, ws, rows = 18, heights = 45)

# ---- PROGRAM_CODES (rows 19-22) -----------------------------------------------------------------------

write_variable(wb, ws, 19,
  "PROGRAM_CODES",
  "Regulatory program(s) inspected. Can list multiple programs. Optional field.",
  prc_miss, prc_ncat,
  c("CAASIP - State Implementation Plan", "CAATVP - Title V Permits",
    "CAASIP, CAATVP - Both SIP & Title V", "CAANSPS, CAASIP - NSPS & SIP"),
  prc$n, prc$pct)
setRowHeights(wb, ws, rows = 19, heights = 45)

# ---- Categorical footnotes ----------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 24)
writeData(wb, ws, paste0(
  "**States conduct ", round(sef$pct[1] * 100), "% of all compliance monitoring. EPA conducts only ",
  round(sef$pct[sef$STATE_EPA_FLAG == "E"] * 100), "%, primarily for oversight ",
  "or targeted enforcement. FCEs (", round(cmt$pct[1] * 100), "%) are the most thorough inspection type — a full review of the ",
  "facility's compliance with all applicable requirements."),
  startRow = 24)
addStyle(wb, ws, font12_left, rows = 24, cols = 1)
setRowHeights(wb, ws, rows = 24, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 25)
writeData(wb, ws, paste0(
  "**ACTIVITY_TYPE_CODE is 100% ", atc$ACTIVITY_TYPE_CODE[1], " (", atc$ACTIVITY_TYPE_DESC[1],
  ") — this table only contains inspection ",
  "records. PROGRAM_CODES is ", prc_miss, " missing and ACTIVITY_PURPOSE_DESC is ", apd_miss,
  " missing — these are optional reporting fields under EPA's Minimum Data Requirements."),
  startRow = 25)
addStyle(wb, ws, font12_left, rows = 25, cols = 1)
setRowHeights(wb, ws, rows = 25, heights = 40)

# ---- Numerical table header (row 27) -------------------------------------------------------------------

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 27, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 27, cols = 1:9, gridExpand = TRUE)

# ---- ACTUAL_END_DATE_YEAR (row 28) ---------------------------------------------------------------------

writeData(wb, ws, "ACTUAL_END_DATE_YEAR\nDate the inspection was completed.",
          startRow = 28, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 28, cols = 1)
writeData(wb, ws, pct_miss(comp$ACTUAL_END_DATE), startRow = 28, startCol = 2)
addStyle(wb, ws, cell_border, rows = 28, cols = 2)
writeData(wb, ws, aed_n, startRow = 28, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 28, cols = 3)

for (yv in list(list(4, aed$min), list(5, aed$p5), list(6, aed$med),
                list(8, aed$p95), list(9, aed$max))) {
  writeData(wb, ws, yv[[2]], startRow = 28, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = 28, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = 28, cols = 7)
setRowHeights(wb, ws, rows = 28, heights = 40)

# ---- Numerical footnote ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 30)
writeData(wb, ws, paste0(
  "**", n_junk_dates, " records have junk dates outside the 1972-2026 range. ",
  "95% of inspections fall between ", aed$p5, " and ", aed$p95, "."),
  startRow = 30)
addStyle(wb, ws, font12_left, rows = 30, cols = 1)

# ---- Duplicates section ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 32)
writeData(wb, ws, "DUPLICATES", startRow = 32)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 32, cols = 1)

mergeCells(wb, ws, cols = 1:9, rows = 33)
writeData(wb, ws, paste0(
  "No exact duplicate rows. ", n_dup_act_ids, " ACTIVITY_IDs (",
  formatC(n_dup_act_rows, format = "d", big.mark = ","),
  " rows, <0.1%) appear more than once — ",
  "these share the same inspection event ID but may differ in PROGRAM_CODES or ",
  "ACTIVITY_PURPOSE_DESC, likely reflecting a single inspection covering multiple programs. ",
  "Most facilities have multiple inspections over time: ",
  formatC(n_multi, format = "d", big.mark = ","), " facilities (",
  round(n_multi / n_fac * 100, 1), "%) have 2+ ",
  "records (max ", formatC(max_insp, format = "d", big.mark = ","),
  "; median ", med_insp, ")."),
  startRow = 33)
addStyle(wb, ws, font12_left, rows = 33, cols = 1)
setRowHeights(wb, ws, rows = 33, heights = 55)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/compliance_table.xlsx"), overwrite = TRUE)
