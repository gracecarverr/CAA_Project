# =========================================================================================================
# 09_table-stack-tests.R — data-dictionary table for ICIS-AIR_STACK_TESTS.
# Writes output/tables/stack_tests_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized (e.g. ast = Air Stack Test status, aed = Actual
# End Date); suffixes: _miss = % missing, _ncat = # distinct categories. Paths via here::here() (.git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(openxlsx)
library(readr)
library(dplyr)
library(lubridate)

# ---- Load data ------------------------------------------------------------------------------------------

st <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_STACK_TESTS.csv"), show_col_types = FALSE)
n_obs <- nrow(st)
n_fac <- n_distinct(st$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# Categorical
ast <- top_vals(st, AIR_STACK_TEST_STATUS_CODE, 4)
ast_miss <- pct_miss(st$AIR_STACK_TEST_STATUS_CODE)
ast_ncat <- n_cats(st$AIR_STACK_TEST_STATUS_CODE)

sef <- top_vals(st, STATE_EPA_FLAG, 3)
sef_miss <- pct_miss(st$STATE_EPA_FLAG)
sef_ncat <- n_cats(st$STATE_EPA_FLAG)

cmt <- st |> count(COMP_MONITOR_TYPE_CODE, COMP_MONITOR_TYPE_DESC) |>
  mutate(pct = n / n_obs) |> arrange(desc(n))
cmt_miss <- pct_miss(st$COMP_MONITOR_TYPE_CODE)
cmt_ncat <- n_cats(st$COMP_MONITOR_TYPE_CODE)

plc <- top_vals(st, POLLUTANT_CODES, 4)
plc_miss <- pct_miss(st$POLLUTANT_CODES)
plc_ncat <- n_cats(st$POLLUTANT_CODES)

pld_miss <- pct_miss(st$POLLUTANT_DESCS)
pld_n_miss <- sum(is.na(st$POLLUTANT_DESCS))
pld_ncat <- n_cats(st$POLLUTANT_DESCS)

# Date
aed_yr <- year(mdy(st$ACTUAL_END_DATE))
aed_n_miss <- sum(is.na(st$ACTUAL_END_DATE))
aed_n <- sum(!is.na(aed_yr))
aed <- list(min = min(aed_yr, na.rm = TRUE),
            p5 = as.integer(quantile(aed_yr, 0.05, na.rm = TRUE)),
            med = as.integer(median(aed_yr, na.rm = TRUE)),
            p95 = as.integer(quantile(aed_yr, 0.95, na.rm = TRUE)),
            max = max(aed_yr, na.rm = TRUE))

# Duplicates
n_exact_dup <- sum(duplicated(st))
n_uniq_act <- n_distinct(st$ACTIVITY_ID)
spf <- st |> group_by(PGM_SYS_ID) |> summarise(n = n(), .groups = "drop")
n_multi <- sum(spf$n > 1)
max_test <- max(spf$n)
med_test <- as.integer(median(spf$n))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Stack Tests")
ws <- "Stack Tests"

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
writeData(wb, ws, "ICIS-Air Stack Tests (ICIS-AIR_STACK_TESTS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Stack test results — emissions tests conducted at facility smokestacks or vents to measure ",
  "whether actual emissions comply with permitted limits. Each row is one test event."),
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

# ---- AIR_STACK_TEST_STATUS_CODE (rows 7-10) ------------------------------------------------------------

ast_labels <- c("PSS" = "Pass", "FAI" = "Fail", "PEN" = "Pending", "INC" = "Incomplete")
ast_descs <- paste0(ast$AIR_STACK_TEST_STATUS_CODE, " - ", ast_labels[ast$AIR_STACK_TEST_STATUS_CODE])

write_variable(wb, ws, 7,
  "AIR_STACK_TEST_STATUS_CODE",
  "Result of the stack test.",
  ast_miss, ast_ncat, ast_descs, ast$n, ast$pct)
setRowHeights(wb, ws, rows = 7, heights = 40)

# ---- STATE_EPA_FLAG (rows 11-13) -----------------------------------------------------------------------

write_variable(wb, ws, 11,
  "STATE_EPA_FLAG",
  "Which agency conducted or oversaw the test.",
  sef_miss, sef_ncat,
  c("S - State", "L - Local", "E - EPA"),
  sef$n, sef$pct)
setRowHeights(wb, ws, rows = 11, heights = 40)

# ---- COMP_MONITOR_TYPE_CODE (row 14) -------------------------------------------------------------------

write_variable(wb, ws, 14,
  "COMP_MONITOR_TYPE_CODE",
  "Type of compliance monitoring activity. All records are stack tests.",
  cmt_miss, cmt_ncat,
  paste0(cmt$COMP_MONITOR_TYPE_CODE, " - ", cmt$COMP_MONITOR_TYPE_DESC),
  cmt$n, cmt$pct)
setRowHeights(wb, ws, rows = 14, heights = 40)

# ---- POLLUTANT_CODES (rows 15-18) ----------------------------------------------------------------------

write_variable(wb, ws, 15,
  "POLLUTANT_CODES",
  "Pollutant(s) tested in the stack test. Uses pollutant names, not numeric codes.",
  plc_miss, plc_ncat,
  plc$POLLUTANT_CODES, plc$n, plc$pct)
setRowHeights(wb, ws, rows = 15, heights = 45)

# ---- POLLUTANT_DESCS (row 19) --------------------------------------------------------------------------

write_variable(wb, ws, 19,
  "POLLUTANT_DESCS",
  "Pollutant description field. Entirely unpopulated in this dataset.",
  pld_miss, pld_ncat,
  c("(All values missing)"),
  c(n_obs),
  c(1.000))
setRowHeights(wb, ws, rows = 19, heights = 40)

# ---- Categorical footnotes ----------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 21)
writeData(wb, ws, paste0(
  "**", round(ast$pct[1] * 100), "% of stack tests pass. The ",
  round(ast$pct[ast$AIR_STACK_TEST_STATUS_CODE == "FAI"] * 100, 1),
  "% failure rate is concentrated at major sources ",
  "(71% of failures), consistent with the pattern that major sources face more intensive ",
  "regulatory scrutiny."),
  startRow = 21)
addStyle(wb, ws, font12_left, rows = 21, cols = 1)
setRowHeights(wb, ws, rows = 21, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 22)
writeData(wb, ws, paste0(
  "**COMP_MONITOR_TYPE_CODE is 100% ", cmt$COMP_MONITOR_TYPE_CODE[1],
  " — this table only contains stack test records. ",
  "POLLUTANT_DESCS is entirely empty. POLLUTANT_CODES is ", plc_miss,
  " missing — an optional field under EPA's Minimum Data Requirements."),
  startRow = 22)
addStyle(wb, ws, font12_left, rows = 22, cols = 1)
setRowHeights(wb, ws, rows = 22, heights = 30)

# ---- Numerical table header (row 24) -------------------------------------------------------------------

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 24, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 24, cols = 1:9, gridExpand = TRUE)

# ---- ACTUAL_END_DATE_YEAR (row 25) ---------------------------------------------------------------------

writeData(wb, ws, "ACTUAL_END_DATE_YEAR\nDate the stack test was completed.",
          startRow = 25, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 25, cols = 1)
writeData(wb, ws, paste0(aed_n_miss, " records (", round(aed_n_miss / n_obs * 100), "%)"),
          startRow = 25, startCol = 2)
addStyle(wb, ws, cell_border, rows = 25, cols = 2)
writeData(wb, ws, aed_n, startRow = 25, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 25, cols = 3)

for (yv in list(list(4, aed$min), list(5, aed$p5), list(6, aed$med),
                list(8, aed$p95), list(9, aed$max))) {
  writeData(wb, ws, yv[[2]], startRow = 25, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = 25, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = 25, cols = 7)
setRowHeights(wb, ws, rows = 25, heights = 40)

# ---- Numerical footnote ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 27)
writeData(wb, ws, paste0("**95% of stack tests fall between ", aed$p5, " and ", aed$p95, "."),
          startRow = 27)
addStyle(wb, ws, font12_left, rows = 27, cols = 1)

# ---- Duplicates section ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 29)
writeData(wb, ws, "DUPLICATES", startRow = 29)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 29, cols = 1)

mergeCells(wb, ws, cols = 1:9, rows = 30)
writeData(wb, ws, paste0(
  "No exact duplicate rows. ACTIVITY_ID is fully unique (",
  formatC(n_uniq_act, format = "d", big.mark = ","), " distinct values). ",
  "PGM_SYS_ID is not unique — ", formatC(n_multi, format = "d", big.mark = ","),
  " facilities (", round(n_multi / n_fac * 100, 1),
  "%) have 2+ stack tests (max ", formatC(max_test, format = "d", big.mark = ","),
  "; median ", med_test, "). Multiple tests per facility are expected: facilities are tested periodically, ",
  "and each test of a different pollutant or emission point generates a separate record."),
  startRow = 30)
addStyle(wb, ws, font12_left, rows = 30, cols = 1)
setRowHeights(wb, ws, rows = 30, heights = 55)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/stack_tests_table.xlsx"), overwrite = TRUE)
