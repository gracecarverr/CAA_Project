# =========================================================================================================
# 09_table-violations.R — builds the data-dictionary table for ICIS-AIR_VIOLATION_HISTORY.
# Summarizes every column and writes a formatted workbook to output/tables/violations_table.xlsx.
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

viol <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_VIOLATION_HISTORY.csv"), show_col_types = FALSE)
n_obs <- nrow(viol)
n_fac <- n_distinct(viol$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

date_stats <- function(date_col) {
  yr <- year(mdy(date_col))
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

# Categorical
erp <- top_vals(viol, ENF_RESPONSE_POLICY_CODE, 2)
erp_miss <- pct_miss(viol$ENF_RESPONSE_POLICY_CODE)
erp_ncat <- n_cats(viol$ENF_RESPONSE_POLICY_CODE)

# AGENCY_TYPE_DESC — top 3, then sum remaining into "Other"
atd_all <- viol |> filter(!is.na(AGENCY_TYPE_DESC)) |>
  count(AGENCY_TYPE_DESC) |> arrange(desc(n))
atd_top <- atd_all |> slice_head(n = 3) |> mutate(pct = n / n_obs)
atd_other <- atd_all |> slice_tail(n = nrow(atd_all) - 3)
atd_other_row <- tibble(AGENCY_TYPE_DESC = "Tribal/Other",
                        n = sum(atd_other$n), pct = sum(atd_other$n) / n_obs)
atd <- bind_rows(atd_top, atd_other_row)
atd_miss <- pct_miss(viol$AGENCY_TYPE_DESC)
atd_ncat <- n_cats(viol$AGENCY_TYPE_DESC)

prc <- top_vals(viol, PROGRAM_CODES, 4)
prc_miss <- pct_miss(viol$PROGRAM_CODES)
prc_ncat <- n_cats(viol$PROGRAM_CODES)

stc <- top_vals(viol, STATE_CODE, 4)
stc_miss <- pct_miss(viol$STATE_CODE)
stc_ncat <- n_cats(viol$STATE_CODE)

alc <- top_vals(viol, AIR_LCON_CODE, 4)
alc_miss <- pct_miss(viol$AIR_LCON_CODE)
alc_ncat <- n_cats(viol$AIR_LCON_CODE)

plc <- top_vals(viol, POLLUTANT_CODES, 4)
plc_miss <- pct_miss(viol$POLLUTANT_CODES)
plc_ncat <- n_cats(viol$POLLUTANT_CODES)

# Dates
frv <- date_stats(viol$EARLIEST_FRV_DETERM_DATE)
hpv_dz <- date_stats(viol$HPV_DAYZERO_DATE)
hpv_res <- date_stats(viol$HPV_RESOLVED_DATE)
dscv <- date_stats(viol$DSCV_PATHWAY_DATE)
nftc <- date_stats(viol$NFTC_PATHWAY_DATE)

# Temporal coverage: raw min across all date fields
all_mins <- c(frv$min, hpv_dz$min, hpv_res$min, dscv$min, nftc$min)
all_maxs <- c(frv$max, hpv_dz$max, hpv_res$max, dscv$max, nftc$max)
temp_min <- min(all_mins)
temp_max <- max(all_maxs)

# Duplicates
n_exact_dup <- sum(duplicated(viol))
n_uniq_act <- n_distinct(viol$ACTIVITY_ID)
n_uniq_uid <- n_distinct(viol$COMP_DETERMINATION_UID)
vpf <- viol |> group_by(PGM_SYS_ID) |> summarise(n = n(), .groups = "drop")
n_dup_pgm <- sum(duplicated(viol$PGM_SYS_ID))
n_multi <- sum(vpf$n > 1)
max_viol <- max(vpf$n)
med_viol <- as.integer(median(vpf$n))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Violations")
ws <- "Violations"

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
writeData(wb, ws, "ICIS-Air Violations (ICIS-AIR_VIOLATION_HISTORY.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Violations identified through compliance monitoring. Each record is a violation finding, ",
  "classified as either a Federally Reportable Violation (FRV) or a High Priority Violation (HPV). ",
  "HPVs are the most serious — they trigger EPA tracking and escalated oversight."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 50)

mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES: ", formatC(n_fac, format = "d", big.mark = ","),
                          "  TEMPORAL COVERAGE: ", temp_min, " - ", temp_max),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID, ACTIVITY_ID, COMP_DETERMINATION_UID",
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

# ---- ENF_RESPONSE_POLICY_CODE (rows 7-8) ---------------------------------------------------------------

write_variable(wb, ws, 7,
  "ENF_RESPONSE_POLICY_CODE",
  "Severity classification. FRV = reportable but lower priority. HPV = most serious, triggers EPA tracking.",
  erp_miss, erp_ncat,
  c("FRV - Federally Reportable Violation", "HPV - High Priority Violation"),
  erp$n, erp$pct)
setRowHeights(wb, ws, rows = 7, heights = 55)

# ---- AGENCY_TYPE_DESC (rows 9-12) ----------------------------------------------------------------------

write_variable(wb, ws, 9,
  "AGENCY_TYPE_DESC",
  "Which level of government identified the violation.",
  atd_miss, atd_ncat,
  c("State", "Local", "U.S. EPA", "Tribal/Other"),
  atd$n, atd$pct)
setRowHeights(wb, ws, rows = 9, heights = 40)

# ---- PROGRAM_CODES (rows 13-16) ------------------------------------------------------------------------

prc_labels <- c("CAASIP" = "State Implementation Plan", "CAATVP" = "Title V Permits",
                "CAASIP CAATVP" = "Both", "CAANSPS" = "New Source Performance Standards")
prc_descs <- paste0(prc$PROGRAM_CODES, " - ", prc_labels[prc$PROGRAM_CODES])

write_variable(wb, ws, 13,
  "PROGRAM_CODES",
  "Which regulatory program(s) the violation falls under. Can list multiple programs.",
  prc_miss, prc_ncat,
  prc_descs, prc$n, prc$pct)
setRowHeights(wb, ws, rows = 13, heights = 45)

# ---- STATE_CODE (rows 17-20) ---------------------------------------------------------------------------

state_names <- c("CA" = "California", "PA" = "Pennsylvania", "TX" = "Texas", "OK" = "Oklahoma",
                 "IL" = "Illinois", "NY" = "New York", "OH" = "Ohio", "LA" = "Louisiana")
stc_descs <- paste0(stc$STATE_CODE, " - ", state_names[stc$STATE_CODE])

write_variable(wb, ws, 17,
  "STATE_CODE",
  "State where the violation was identified.",
  stc_miss, stc_ncat,
  stc_descs, stc$n, stc$pct)
setRowHeights(wb, ws, rows = 17, heights = 40)

# ---- AIR_LCON_CODE (rows 21-24) ------------------------------------------------------------------------

alc_labels <- c("SJV" = "San Joaquin Valley (CA)", "BAA" = "Bay Area AQMD (CA)",
                "SCA" = "South Coast AQMD (CA)", "PAM" = "Pima County (AZ)")
alc_descs <- paste0(alc$AIR_LCON_CODE, " - ", alc_labels[alc$AIR_LCON_CODE])

write_variable(wb, ws, 21,
  "AIR_LCON_CODE",
  "Local control region code — the local air agency jurisdiction.",
  alc_miss, alc_ncat,
  alc_descs, alc$n, alc$pct)
setRowHeights(wb, ws, rows = 21, heights = 45)

# ---- POLLUTANT_CODES (rows 25-28) ----------------------------------------------------------------------

plc_labels <- c("300000329" = "FACIL (facility-level placeholder)",
                "300000243" = "VOCs",
                "300000322" = "Total Particulate Matter",
                "300000328" = "ADMIN (administrative)")
plc_descs <- paste0(plc$POLLUTANT_CODES, " - ", plc_labels[plc$POLLUTANT_CODES])

write_variable(wb, ws, 25,
  "POLLUTANT_CODES",
  "Pollutant code(s) associated with the violation. Can list multiple pollutants.",
  plc_miss, plc_ncat,
  plc_descs, plc$n, plc$pct)
setRowHeights(wb, ws, rows = 25, heights = 45)

# ---- Categorical footnotes ----------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 30)
writeData(wb, ws, paste0(
  "**HPVs (", round(erp$pct[erp$ENF_RESPONSE_POLICY_CODE == "HPV"] * 100), "%) are violations serious enough to warrant EPA headquarters tracking. ",
  "They include violations of applicable requirements, failure to report, and operating ",
  "without a required permit. ", stc$STATE_CODE[1], " alone accounts for ",
  round(stc$pct[1] * 100), "% of all violation records."),
  startRow = 30)
addStyle(wb, ws, font12_left, rows = 30, cols = 1)
setRowHeights(wb, ws, rows = 30, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 31)
writeData(wb, ws, paste0(
  "**AIR_LCON_CODE is ", alc_miss, " missing — only populated when a local agency has jurisdiction. ",
  round(plc$pct[1] * 100), "% of violations list FACIL as the pollutant code, a facility-level placeholder ",
  "with no specific pollutant."),
  startRow = 31)
addStyle(wb, ws, font12_left, rows = 31, cols = 1)
setRowHeights(wb, ws, rows = 31, heights = 30)

# ---- Numerical table header (row 33) -------------------------------------------------------------------

num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = 33, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = 33, cols = 1:9, gridExpand = TRUE)

# ---- Date rows -----------------------------------------------------------------------------------------

date_vars <- list(
  list(name = "EARLIEST_FRV_DETERM_DATE\nDate the violation was first formally determined.", d = frv),
  list(name = "HPV_DAYZERO_DATE\nDate the HPV tracking clock started.", d = hpv_dz),
  list(name = "HPV_RESOLVED_DATE\nDate the HPV was resolved or closed.", d = hpv_res),
  list(name = "DSCV_PATHWAY_DATE\nDate the violation was discovered through the pathway process.", d = dscv),
  list(name = "NFTC_PATHWAY_DATE\nDate the violation entered the no-further-tracking-required pathway.", d = nftc)
)

for (i in seq_along(date_vars)) {
  r <- 33 + i
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

# ---- Numerical footnotes -------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 40)
writeData(wb, ws, paste0(
  "**Some date fields contain junk values (e.g., year ", frv$min, ", ", hpv_res$min, ", ", hpv_dz$min,
  ") — likely data entry errors. ",
  "FRV determination dates are sparse before 2014 (AFS system was frozen Oct 2014). ",
  "HPV dates go back further because HPV history was migrated from the legacy system. ",
  round(hpv_dz$n_miss / n_obs * 100), "% of records have no HPV day-zero date because they are FRVs, not HPVs."),
  startRow = 40)
addStyle(wb, ws, font12_left, rows = 40, cols = 1)
setRowHeights(wb, ws, rows = 40, heights = 50)

mergeCells(wb, ws, cols = 1:9, rows = 41)
writeData(wb, ws, paste0(
  "**DSCV_PATHWAY_DATE (", round(dscv$n_miss / n_obs * 100), "% missing) and NFTC_PATHWAY_DATE (",
  round(nftc$n_miss / n_obs * 100), "% missing) track the ",
  "violation's progress through EPA's enforcement response pathway. Not all violations ",
  "enter or complete the pathway."),
  startRow = 41)
addStyle(wb, ws, font12_left, rows = 41, cols = 1)
setRowHeights(wb, ws, rows = 41, heights = 30)

# ---- Duplicates section ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:9, rows = 43)
writeData(wb, ws, "DUPLICATES", startRow = 43)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 43, cols = 1)

mergeCells(wb, ws, cols = 1:9, rows = 44)
writeData(wb, ws, paste0(
  "No exact duplicate rows. ACTIVITY_ID and COMP_DETERMINATION_UID are each fully unique (",
  formatC(n_uniq_act, format = "d", big.mark = ","), " distinct values). PGM_SYS_ID is not unique — ",
  formatC(n_dup_pgm, format = "d", big.mark = ","), " rows (",
  round(n_dup_pgm / n_obs * 100, 1), "%) share a facility ",
  "with at least one other violation. ", formatC(n_multi, format = "d", big.mark = ","),
  " facilities have 2+ violations (max ", formatC(max_viol, format = "d", big.mark = ","),
  "; median ", med_viol, "). This is expected: repeat violators accumulate multiple records over time."),
  startRow = 44)
addStyle(wb, ws, font12_left, rows = 44, cols = 1)
setRowHeights(wb, ws, rows = 44, heights = 55)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/violations_table.xlsx"), overwrite = TRUE)
