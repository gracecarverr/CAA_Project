# =========================================================================================================
# 09_table-informal-actions.R — builds the data-dictionary table for ICIS-AIR_INFORMAL_ACTIONS.
# Summarizes every column and writes a formatted workbook to output/tables/informal_actions_table.xlsx.
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

inf <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_INFORMAL_ACTIONS.csv"), show_col_types = FALSE)
n_obs <- nrow(inf)
n_fac <- n_distinct(inf$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# Categorical
act <- inf |> count(ACTIVITY_TYPE_CODE, ACTIVITY_TYPE_DESC) |>
  mutate(pct = n / n_obs) |> arrange(desc(n))
act_miss <- pct_miss(inf$ACTIVITY_TYPE_CODE)
act_ncat <- n_cats(inf$ACTIVITY_TYPE_CODE)

enf <- inf |> count(ENF_TYPE_CODE, ENF_TYPE_DESC) |>
  mutate(pct = n / n_obs) |> arrange(desc(n)) |> slice_head(n = 4)
enf_miss <- pct_miss(inf$ENF_TYPE_CODE)
enf_ncat <- n_cats(inf$ENF_TYPE_CODE)

sef <- top_vals(inf, STATE_EPA_FLAG, 3)
sef_miss <- pct_miss(inf$STATE_EPA_FLAG)
sef_ncat <- n_cats(inf$STATE_EPA_FLAG)

ofl <- top_vals(inf, OFFICIAL_FLG, 2)
ofl_miss <- pct_miss(inf$OFFICIAL_FLG)
ofl_ncat <- n_cats(inf$OFFICIAL_FLG)

# Date
ad_yr <- year(mdy(inf$ACHIEVED_DATE))
ad_n_miss <- sum(is.na(inf$ACHIEVED_DATE))
ad_n <- sum(!is.na(ad_yr))
ad <- list(min = min(ad_yr, na.rm = TRUE),
           p5 = as.integer(quantile(ad_yr, 0.05, na.rm = TRUE)),
           med = as.integer(median(ad_yr, na.rm = TRUE)),
           p95 = as.integer(quantile(ad_yr, 0.95, na.rm = TRUE)),
           max = max(ad_yr, na.rm = TRUE))
n_junk_dates <- sum(!is.na(ad_yr) & (ad_yr < 1973 | ad_yr > 2027))

# Duplicates
n_exact_dup <- sum(duplicated(inf))
n_unique_rows <- nrow(distinct(inf))
inf_dedup <- distinct(inf)
n_dup_enf <- sum(duplicated(inf_dedup$ENF_IDENTIFIER))
n_distinct_enf <- n_distinct(inf_dedup$ENF_IDENTIFIER)
ipf <- inf_dedup |> group_by(PGM_SYS_ID) |> summarise(n = n(), .groups = "drop")
n_fac_dedup <- nrow(ipf)
n_multi <- sum(ipf$n > 1)
max_act <- max(ipf$n)
med_act <- as.integer(median(ipf$n))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Informal Actions")
ws <- "Informal Actions"

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
writeData(wb, ws, "ICIS-Air Informal Actions (ICIS-AIR_INFORMAL_ACTIONS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Informal enforcement actions — lower-severity responses to noncompliance that do not carry ",
  "legally binding obligations. Primarily Notices of Violation (NOVs), which formally notify a ",
  "facility that it has been found out of compliance."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES: ", formatC(n_fac, format = "d", big.mark = ","),
                          "  TEMPORAL COVERAGE: ", ad$min, " - ", ad$max),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID, ACTIVITY_ID, ENF_IDENTIFIER",
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

# ---- ACTIVITY_TYPE (rows 7-8) --------------------------------------------------------------------------

write_variable(wb, ws, 7,
  "ACTIVITY_TYPE_CODE",
  "Type of informal enforcement response taken.",
  act_miss, act_ncat,
  paste0(act$ACTIVITY_TYPE_CODE, " - ", act$ACTIVITY_TYPE_DESC),
  act$n, act$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- ENF_TYPE_CODE (rows 9-12) ------------------------------------------------------------------------

write_variable(wb, ws, 9,
  "ENF_TYPE_CODE",
  "Specific enforcement mechanism used.",
  enf_miss, enf_ncat,
  paste0(enf$ENF_TYPE_CODE, " - ", enf$ENF_TYPE_DESC),
  enf$n, enf$pct)
setRowHeights(wb, ws, rows = 9, heights = 45)

# ---- STATE_EPA_FLAG (rows 13-15) -----------------------------------------------------------------------

write_variable(wb, ws, 13,
  "STATE_EPA_FLAG",
  "Which agency issued the informal action.",
  sef_miss, sef_ncat,
  c("S - State", "L - Local", "E - EPA"),
  sef$n, sef$pct)
setRowHeights(wb, ws, rows = 13, heights = 40)

# ---- OFFICIAL_FLG (rows 16-17) -------------------------------------------------------------------------

write_variable(wb, ws, 16,
  "OFFICIAL_FLG",
  "Whether the action has been officially submitted and finalized in the EPA reporting system.",
  ofl_miss, ofl_ncat,
  c("Y - Yes", "N - No"),
  ofl$n, ofl$pct)
setRowHeights(wb, ws, rows = 16, heights = 50)

# ---- Categorical footnote (row 18) ---------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 18)
writeData(wb, ws, paste0(
  "**", round(enf$pct[1] * 100), "% of informal actions are ",
  enf$ENF_TYPE_DESC[1], " (NOVs), which notify a ",
  "facility it has been found in noncompliance. The remainder are warning letters ",
  "and other minor responses."),
  startRow = 18)
addStyle(wb, ws, font12_left, rows = 18, cols = 1)

# ---- Numerical table header (row 20) -------------------------------------------------------------------

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 20, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 20, cols = 1:9, gridExpand = TRUE)

# ---- ACHIEVED_DATE_YEAR (row 21) -----------------------------------------------------------------------

writeData(wb, ws, "ACHIEVED_DATE_YEAR\nDate the informal action was completed or resolved.",
          startRow = 21, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = 21, cols = 1)

writeData(wb, ws, paste0(formatC(ad_n_miss, format = "d", big.mark = ","), " records (",
                          round(ad_n_miss / n_obs * 100), "%)"),
          startRow = 21, startCol = 2)
addStyle(wb, ws, cell_border, rows = 21, cols = 2)

writeData(wb, ws, ad_n, startRow = 21, startCol = 3)
addStyle(wb, ws, cell_comma, rows = 21, cols = 3)

for (yv in list(list(4, ad$min), list(5, ad$p5), list(6, ad$med),
                list(8, ad$p95), list(9, ad$max))) {
  writeData(wb, ws, yv[[2]], startRow = 21, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = 21, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = 21, cols = 7)
setRowHeights(wb, ws, rows = 21, heights = 45)

# ---- Numerical footnote (row 23) -----------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 23)
writeData(wb, ws, paste0(
  "**", n_junk_dates, " records have junk dates outside the 1973-2027 range. ",
  "95% of actions fall between ", ad$p5, " and ", ad$p95, "."),
  startRow = 23)
addStyle(wb, ws, font12_left, rows = 23, cols = 1)

# ---- Duplicates section ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 25)
writeData(wb, ws, "DUPLICATES", startRow = 25)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 25, cols = 1)

mergeCells(wb, ws, cols = 1:9, rows = 26)
writeData(wb, ws, paste0(
  formatC(n_exact_dup, format = "d", big.mark = ","),
  " exact duplicate rows (", round(n_exact_dup / n_obs * 100, 1),
  "% of the dataset). Every duplicate appears exactly twice — ",
  formatC(n_unique_rows, format = "d", big.mark = ","), " unique rows, ",
  formatC(n_obs, format = "d", big.mark = ","),
  " total. The duplicates share identical values across all columns ",
  "(PGM_SYS_ID, ACTIVITY_ID, ENF_IDENTIFIER, and all other fields). This is likely a bulk data ",
  "export artifact — possibly from a system migration or a join that inadvertently doubled records. ",
  "Users should deduplicate before analysis."),
  startRow = 26)
addStyle(wb, ws, font12_left, rows = 26, cols = 1)
setRowHeights(wb, ws, rows = 26, heights = 60)

mergeCells(wb, ws, cols = 1:9, rows = 27)
writeData(wb, ws, paste0(
  "After deduplication, ", formatC(n_multi, format = "d", big.mark = ","),
  " facilities (", round(n_multi / n_fac_dedup * 100, 1),
  "%) have 2+ informal actions (max ", formatC(max_act, format = "d", big.mark = ","),
  "; median ", med_act, "). ENF_IDENTIFIER has ",
  formatC(n_dup_enf, format = "d", big.mark = ","), " duplicate values (",
  formatC(n_distinct_enf, format = "d", big.mark = ","),
  " distinct), meaning some enforcement actions appear under multiple ACTIVITY_IDs — ",
  "possibly linking one enforcement response to multiple compliance events."),
  startRow = 27)
addStyle(wb, ws, font12_left, rows = 27, cols = 1)
setRowHeights(wb, ws, rows = 27, heights = 50)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/informal_actions_table.xlsx"), overwrite = TRUE)
