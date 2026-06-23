# =========================================================================================================
# 09_table-programs.R — builds the data-dictionary table for ICIS-AIR_PROGRAMS (air-program enrollments).
# Summarizes every column and writes a formatted workbook to output/tables/programs_table.xlsx.
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

prog <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_PROGRAMS.csv"), show_col_types = FALSE)
n_obs <- nrow(prog)
n_fac <- n_distinct(prog$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# PROGRAM_CODE
pc <- prog |> filter(!is.na(PROGRAM_CODE)) |> count(PROGRAM_CODE, PROGRAM_DESC) |>
  arrange(desc(n)) |> slice_head(n = 6) |> mutate(pct = n / n_obs)
pc_miss <- pct_miss(prog$PROGRAM_CODE)
pc_ncat <- n_cats(prog$PROGRAM_CODE)

# AIR_OPERATING_STATUS_CODE — top 3, then sum remaining into "Other"
aos_all <- prog |> filter(!is.na(AIR_OPERATING_STATUS_CODE)) |>
  count(AIR_OPERATING_STATUS_CODE) |> arrange(desc(n))
aos_top <- aos_all |> slice_head(n = 3) |> mutate(pct = n / n_obs)
aos_other <- aos_all |> slice_tail(n = nrow(aos_all) - 3)
aos_other_row <- tibble(AIR_OPERATING_STATUS_CODE = "PLN/CNS/SEA",
                        n = sum(aos_other$n), pct = sum(aos_other$n) / n_obs)
aos <- bind_rows(aos_top, aos_other_row)
aos_miss <- pct_miss(prog$AIR_OPERATING_STATUS_CODE)
aos_ncat <- n_cats(prog$AIR_OPERATING_STATUS_CODE)

# BEGIN_DATE
bd_yr <- year(mdy(prog$BEGIN_DATE))
bd_miss <- sum(is.na(prog$BEGIN_DATE))
bd_n <- sum(!is.na(bd_yr))
bd_stats <- list(min = min(bd_yr, na.rm = TRUE),
                 p5 = as.integer(quantile(bd_yr, 0.05, na.rm = TRUE)),
                 med = as.integer(median(bd_yr, na.rm = TRUE)),
                 p95 = as.integer(quantile(bd_yr, 0.95, na.rm = TRUE)),
                 max = max(bd_yr, na.rm = TRUE))

# UPDATED_DATE
ud_yr <- year(mdy(prog$UPDATED_DATE))
ud_miss <- sum(is.na(prog$UPDATED_DATE))
ud_n <- sum(!is.na(ud_yr))
ud_stats <- list(min = min(ud_yr, na.rm = TRUE),
                 p5 = as.integer(quantile(ud_yr, 0.05, na.rm = TRUE)),
                 med = as.integer(median(ud_yr, na.rm = TRUE)),
                 p95 = as.integer(quantile(ud_yr, 0.95, na.rm = TRUE)),
                 max = max(ud_yr, na.rm = TRUE))

# Duplicates
n_exact_dup <- sum(duplicated(prog))
n_dup_pgm_prog <- sum(duplicated(prog |> select(PGM_SYS_ID, PROGRAM_CODE)))
fac_prog <- prog |> group_by(PGM_SYS_ID) |> summarise(n_prog = n(), .groups = "drop")
n_multi <- sum(fac_prog$n_prog > 1)
max_prog <- max(fac_prog$n_prog)

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Programs")
ws <- "Programs"

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
setColWidths(wb, ws, cols = 5:6, widths = 14)
setColWidths(wb, ws, cols = 7:9, widths = 14)

# ---- Header block ---------------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "ICIS-Air Programs (ICIS-AIR_PROGRAMS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Each row is one facility-program combination. A single facility can be subject to multiple ",
  "regulatory programs (e.g., SIP + Title V + MACT). The median facility holds 1 program; ",
  "major sources typically hold several."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES: ", formatC(n_fac, format = "d", big.mark = ",")),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID  |  DATES: BEGIN_DATE, UPDATED_DATE", startRow = 4)
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

# ---- PROGRAM_CODE (rows 7-12) --------------------------------------------------------------------------

pc_descs <- paste0(pc$PROGRAM_CODE, " - ", pc$PROGRAM_DESC)

write_variable(wb, ws, 7,
  "PROGRAM_CODE",
  "Which CAA regulatory program the facility is subject to.",
  pc_miss, pc_ncat,
  pc_descs,
  pc$n,
  pc$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- AIR_OPERATING_STATUS_CODE (rows 13-16) -------------------------------------------------------------

write_variable(wb, ws, 13,
  "AIR_OPERATING_STATUS_CODE",
  "Operating status of the program enrollment.",
  aos_miss, aos_ncat,
  c("OPR - Operating", "CLS - Permanently Closed",
    "TMP - Temporarily Closed", "PLN/CNS/SEA - Other"),
  aos$n,
  aos$pct)
setRowHeights(wb, ws, rows = 13, heights = 40)

# ---- Footnotes (categorical) ---------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 18)
writeData(wb, ws, paste0(
  "**SIP (", round(pc$pct[1] * 100), "%) is the baseline — nearly every regulated source has one. ",
  "Title V (", round(pc$pct[pc$PROGRAM_CODE == "CAATVP"] * 100), "%) applies almost exclusively to major sources. MACT and NSPS are ",
  "technology-based standards for specific industries and pollutants."),
  startRow = 18)
addStyle(wb, ws, font12_left, rows = 18, cols = 1)
setRowHeights(wb, ws, rows = 18, heights = 40)

# ---- Numerical table header (row 20) ------------------------------------------------------------------

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 20, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 20, cols = 1:9, gridExpand = TRUE)

# ---- BEGIN_DATE_YEAR (row 21) --------------------------------------------------------------------------

writeData(wb, ws, "BEGIN_DATE_YEAR\nDate the program enrollment began.",
          startRow = 21, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 21, cols = 1)
writeData(wb, ws, pct_miss(prog$BEGIN_DATE), startRow = 21, startCol = 2)
addStyle(wb, ws, cell_border, rows = 21, cols = 2)
writeData(wb, ws, bd_n, startRow = 21, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 21, cols = 3)

for (yv in list(list(4, bd_stats$min), list(5, bd_stats$p5), list(6, bd_stats$med),
                list(8, bd_stats$p95), list(9, bd_stats$max))) {
  writeData(wb, ws, yv[[2]], startRow = 21, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = 21, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = 21, cols = 7)
setRowHeights(wb, ws, rows = 21, heights = 40)

# ---- UPDATED_DATE_YEAR (row 22) ------------------------------------------------------------------------

writeData(wb, ws, "UPDATED_DATE_YEAR\nDate the program record was last updated.",
          startRow = 22, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 22, cols = 1)
writeData(wb, ws, pct_miss(prog$UPDATED_DATE), startRow = 22, startCol = 2)
addStyle(wb, ws, cell_border, rows = 22, cols = 2)
writeData(wb, ws, ud_n, startRow = 22, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 22, cols = 3)

for (yv in list(list(4, ud_stats$min), list(5, ud_stats$p5), list(6, ud_stats$med),
                list(8, ud_stats$p95), list(9, ud_stats$max))) {
  writeData(wb, ws, yv[[2]], startRow = 22, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = 22, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = 22, cols = 7)
setRowHeights(wb, ws, rows = 22, heights = 40)

# ---- Numerical footnote -------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 24)
writeData(wb, ws, paste0(
  "**BEGIN_DATE has junk values (e.g., year ", bd_stats$min, ") from data entry errors. ",
  "95% of program enrollments began between ", bd_stats$p5, " and ", bd_stats$p95, ". ",
  "UPDATED_DATE ranges from ", ud_stats$min, " (ICIS system launch) to ", ud_stats$max, "."),
  startRow = 24)
addStyle(wb, ws, font12_left, rows = 24, cols = 1)
setRowHeights(wb, ws, rows = 24, heights = 40)

# ---- Duplicates section ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 26)
writeData(wb, ws, "DUPLICATES", startRow = 26)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 26, cols = 1)

n_dup_pgm <- sum(duplicated(prog$PGM_SYS_ID))
mergeCells(wb, ws, cols = 1:9, rows = 27)
writeData(wb, ws, paste0(
  "No exact duplicate rows. PGM_SYS_ID is not unique — ",
  formatC(n_dup_pgm, format = "d", big.mark = ","), " rows (",
  round(n_dup_pgm / n_obs * 100, 1), "%) share a PGM_SYS_ID ",
  "with at least one other row. This is by design: a single facility can hold multiple program ",
  "enrollments (e.g., SIP + Title V + MACT). ",
  formatC(n_multi, format = "d", big.mark = ","), " facilities have 2+ programs (max ", max_prog, "). ",
  n_dup_pgm_prog, " row has a duplicate PGM_SYS_ID + PROGRAM_CODE combination (same facility enrolled in the same ",
  "program twice)."),
  startRow = 27)
addStyle(wb, ws, font12_left, rows = 27, cols = 1)
setRowHeights(wb, ws, rows = 27, heights = 55)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/programs_table.xlsx"), overwrite = TRUE)
