# =========================================================================================================
# 09_table-pipeline.R — data-dictionary table for the assembled PIPELINE_CAA_00_COMPLETE dataset
# (a pre-joined enforcement pipeline: evaluation -> violation -> enforcement action).
# Writes output/tables/pipeline_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(openxlsx)
library(readr)
library(dplyr)
library(lubridate)

# ---- Inspect column names -------------------------------------------------------------------------------
# First, read just the header to see all 35 columns in this dataset.

all_cols <- names(read_csv(here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"), n_max = 0, show_col_types = FALSE))
cat("Columns:", paste(all_cols, collapse = ", "), "\n")

# ---- Load data ------------------------------------------------------------------------------------------

pipe <- read_csv(here("data/raw/PIPELINE_CAA_00_COMPLETE.csv"), show_col_types = FALSE)
n_obs <- nrow(pipe)
n_fac <- n_distinct(pipe$SOURCE_ID)

# ---- Helper functions -----------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# ---- Compute statistics: Categorical -------------------------------------------------------------------

# PIPELINE_FLAG — key structural variable showing how far through the pipeline each row went
plf_all <- pipe |> filter(!is.na(PIPELINE_FLAG)) |>
  count(PIPELINE_FLAG) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
plf_miss <- pct_miss(pipe$PIPELINE_FLAG)
plf_ncat <- n_cats(pipe$PIPELINE_FLAG)

# EVAL_FLAG — whether this row has an evaluation
evf_all <- pipe |> filter(!is.na(EVAL_FLAG)) |>
  count(EVAL_FLAG) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
evf_miss <- pct_miss(pipe$EVAL_FLAG)
evf_ncat <- n_cats(pipe$EVAL_FLAG)

# VIOL_FLAG — whether this row has a violation
vif_all <- pipe |> filter(!is.na(VIOL_FLAG)) |>
  count(VIOL_FLAG) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
vif_miss <- pct_miss(pipe$VIOL_FLAG)
vif_ncat <- n_cats(pipe$VIOL_FLAG)

# EA_FLAG — whether this row has an enforcement action
eaf_all <- pipe |> filter(!is.na(EA_FLAG)) |>
  count(EA_FLAG) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
eaf_miss <- pct_miss(pipe$EA_FLAG)
eaf_ncat <- n_cats(pipe$EA_FLAG)

# EVAL_TYPE_DESC — top 4 evaluation types
etd <- top_vals(pipe, EVAL_TYPE_DESC, 4)
etd_miss <- pct_miss(pipe$EVAL_TYPE_DESC)
etd_ncat <- n_cats(pipe$EVAL_TYPE_DESC)

# EVAL_LEAD_AGENCY — all values (expect a small set: state, EPA, local)
ela_all <- pipe |> filter(!is.na(EVAL_LEAD_AGENCY)) |>
  count(EVAL_LEAD_AGENCY) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
ela_miss <- pct_miss(pipe$EVAL_LEAD_AGENCY)
ela_ncat <- n_cats(pipe$EVAL_LEAD_AGENCY)

# VIOL_TYPE — top 4 violation types
vt <- top_vals(pipe, VIOL_TYPE, 4)
vt_miss <- pct_miss(pipe$VIOL_TYPE)
vt_ncat <- n_cats(pipe$VIOL_TYPE)

# FOUND_VIOLATION — all values
fv_all <- pipe |> filter(!is.na(FOUND_VIOLATION)) |>
  count(FOUND_VIOLATION) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
fv_miss <- pct_miss(pipe$FOUND_VIOLATION)
fv_ncat <- n_cats(pipe$FOUND_VIOLATION)

# OFFICIAL_FLAG — whether the record is official
off_all <- pipe |> filter(!is.na(OFFICIAL_FLAG)) |>
  count(OFFICIAL_FLAG) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
off_miss <- pct_miss(pipe$OFFICIAL_FLAG)
off_ncat <- n_cats(pipe$OFFICIAL_FLAG)

# VIOL_LEAD_AGENCY — agency leading the violation case
vla <- top_vals(pipe, VIOL_LEAD_AGENCY, 4)
vla_miss <- pct_miss(pipe$VIOL_LEAD_AGENCY)
vla_ncat <- n_cats(pipe$VIOL_LEAD_AGENCY)

# VIOL_PROGRAMS — program codes associated with the violation
vpr <- top_vals(pipe, VIOL_PROGRAMS, 4)
vpr_miss <- pct_miss(pipe$VIOL_PROGRAMS)
vpr_ncat <- n_cats(pipe$VIOL_PROGRAMS)

# VIOL_POLLUTANT_CODES — pollutant codes for the violation
vpc <- top_vals(pipe, VIOL_POLLUTANT_CODES, 4)
vpc_miss <- pct_miss(pipe$VIOL_POLLUTANT_CODES)
vpc_ncat <- n_cats(pipe$VIOL_POLLUTANT_CODES)

# EA_TYPE — type of enforcement action
eat <- top_vals(pipe, EA_TYPE, 4)
eat_miss <- pct_miss(pipe$EA_TYPE)
eat_ncat <- n_cats(pipe$EA_TYPE)

# FEA_ISSUE_DATE_FLAG — flag about the formal enforcement action issue date
fid_all <- pipe |> filter(!is.na(FEA_ISSUE_DATE_FLAG)) |>
  count(FEA_ISSUE_DATE_FLAG) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
fid_miss <- pct_miss(pipe$FEA_ISSUE_DATE_FLAG)
fid_ncat <- n_cats(pipe$FEA_ISSUE_DATE_FLAG)

# ---- Compute statistics: Numerical (date) ---------------------------------------------------------------

# EVAL_DATE — parse the date and extract year for summary stats
# Try multiple date formats in case the format varies
eval_date_parsed <- mdy(pipe$EVAL_DATE)
# If mdy fails for most, try ymd as a fallback
if (sum(!is.na(eval_date_parsed)) < sum(!is.na(pipe$EVAL_DATE)) * 0.5) {
  eval_date_parsed <- ymd(pipe$EVAL_DATE)
}
eval_yr <- year(eval_date_parsed)
eval_n_miss <- sum(is.na(pipe$EVAL_DATE))
eval_n <- sum(!is.na(eval_yr))

eval_yr_stats <- list(
  min = min(eval_yr, na.rm = TRUE),
  p5  = as.integer(quantile(eval_yr, 0.05, na.rm = TRUE)),
  med = as.integer(median(eval_yr, na.rm = TRUE)),
  p95 = as.integer(quantile(eval_yr, 0.95, na.rm = TRUE)),
  max = max(eval_yr, na.rm = TRUE)
)

# Flag dates outside a reasonable range
n_junk_dates <- sum(!is.na(eval_yr) & (eval_yr < 1972 | eval_yr > 2026))

# VIOL_START_DATE — violation start date
viol_start_parsed <- mdy(pipe$VIOL_START_DATE)
if (sum(!is.na(viol_start_parsed)) < sum(!is.na(pipe$VIOL_START_DATE)) * 0.5) {
  viol_start_parsed <- ymd(pipe$VIOL_START_DATE)
}
viol_start_yr <- year(viol_start_parsed)
viol_start_n <- sum(!is.na(viol_start_yr))
viol_start_stats <- list(
  min = min(viol_start_yr, na.rm = TRUE),
  p5  = as.integer(quantile(viol_start_yr, 0.05, na.rm = TRUE)),
  med = as.integer(median(viol_start_yr, na.rm = TRUE)),
  p95 = as.integer(quantile(viol_start_yr, 0.95, na.rm = TRUE)),
  max = max(viol_start_yr, na.rm = TRUE)
)

# VIOL_END_DATE — mixed column: contains status strings ("N/A", "Unresolved") and dates.
# Treat as categorical. The actual date is in VIOL_END_DATE_DATE.
ved <- top_vals(pipe, VIOL_END_DATE, 4)
ved_miss <- pct_miss(pipe$VIOL_END_DATE)
ved_ncat <- n_cats(pipe$VIOL_END_DATE)

# VIOL_END_DATE_DATE — the actual violation end date (dates only)
viol_end_parsed <- mdy(pipe$VIOL_END_DATE_DATE)
if (sum(!is.na(viol_end_parsed)) < sum(!is.na(pipe$VIOL_END_DATE_DATE)) * 0.5) {
  viol_end_parsed <- ymd(pipe$VIOL_END_DATE_DATE)
}
viol_end_yr <- year(viol_end_parsed)
viol_end_n <- sum(!is.na(viol_end_yr))
if (viol_end_n > 0) {
  viol_end_stats <- list(
    min = min(viol_end_yr, na.rm = TRUE),
    p5  = as.integer(quantile(viol_end_yr, 0.05, na.rm = TRUE)),
    med = as.integer(median(viol_end_yr, na.rm = TRUE)),
    p95 = as.integer(quantile(viol_end_yr, 0.95, na.rm = TRUE)),
    max = max(viol_end_yr, na.rm = TRUE)
  )
} else {
  viol_end_stats <- list(min = NA, p5 = NA, med = NA, p95 = NA, max = NA)
}

# EA_DATE — enforcement action date
ea_date_parsed <- mdy(pipe$EA_DATE)
if (sum(!is.na(ea_date_parsed)) < sum(!is.na(pipe$EA_DATE)) * 0.5) {
  ea_date_parsed <- ymd(pipe$EA_DATE)
}
ea_date_yr <- year(ea_date_parsed)
ea_date_n <- sum(!is.na(ea_date_yr))
ea_date_stats <- list(
  min = min(ea_date_yr, na.rm = TRUE),
  p5  = as.integer(quantile(ea_date_yr, 0.05, na.rm = TRUE)),
  med = as.integer(median(ea_date_yr, na.rm = TRUE)),
  p95 = as.integer(quantile(ea_date_yr, 0.95, na.rm = TRUE)),
  max = max(ea_date_yr, na.rm = TRUE)
)

# EA_PENALTY_AMT — enforcement action penalty amount
pen_vals <- as.numeric(pipe$EA_PENALTY_AMT)
pen_n <- sum(!is.na(pen_vals))
pen_stats <- list(
  min = min(pen_vals, na.rm = TRUE),
  p5  = quantile(pen_vals, 0.05, na.rm = TRUE),
  med = median(pen_vals, na.rm = TRUE),
  p95 = quantile(pen_vals, 0.95, na.rm = TRUE),
  max = max(pen_vals, na.rm = TRUE)
)

# EA_COMP_ACTION_COST — compliance action cost
cac_vals <- as.numeric(pipe$EA_COMP_ACTION_COST)
cac_n <- sum(!is.na(cac_vals))
cac_stats <- list(
  min = min(cac_vals, na.rm = TRUE),
  p5  = quantile(cac_vals, 0.05, na.rm = TRUE),
  med = median(cac_vals, na.rm = TRUE),
  p95 = quantile(cac_vals, 0.95, na.rm = TRUE),
  max = max(cac_vals, na.rm = TRUE)
)

# ---- Compute statistics: Duplicates --------------------------------------------------------------------

# Exact duplicates
n_exact_dup <- sum(duplicated(pipe))

# Records per facility (SOURCE_ID)
rpf <- pipe |> group_by(SOURCE_ID) |> summarise(n = n(), .groups = "drop")
rpf_med <- as.integer(median(rpf$n))
rpf_max <- max(rpf$n)
rpf_multi <- sum(rpf$n > 1)

# ---- Pipeline progression stats for footnotes -----------------------------------------------------------

# What share of rows have each flag set? This shows pipeline attrition.
pct_eval <- round(sum(pipe$EVAL_FLAG == "Y", na.rm = TRUE) / n_obs * 100, 1)
pct_viol <- round(sum(pipe$VIOL_FLAG == "Y", na.rm = TRUE) / n_obs * 100, 1)
pct_ea   <- round(sum(pipe$EA_FLAG == "Y", na.rm = TRUE) / n_obs * 100, 1)

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Pipeline")
ws <- "Pipeline"

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
cell_dollar <- createStyle(border = "TopBottomLeftRight", halign = "center",
                            valign = "center", numFmt = "$#,##0",
                            fontName = "Calibri", fontSize = 12)

# ---- Column widths --------------------------------------------------------------------------------------

setColWidths(wb, ws, cols = 1, widths = 30)
setColWidths(wb, ws, cols = 2, widths = 18)
setColWidths(wb, ws, cols = 3, widths = 14)
setColWidths(wb, ws, cols = 4, widths = 55)
setColWidths(wb, ws, cols = 5:9, widths = 14)

# ---- Header block ---------------------------------------------------------------------------------------

# Row 1: Title
mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "CAA Enforcement Pipeline (PIPELINE_CAA_00_COMPLETE.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

# Row 2: Description
mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Pre-joined view linking CAA violations to their triggering evaluations (CMAs) and resulting ",
  "enforcement actions. Each row is a violation x enforcement action x evaluation combination. ",
  "Contains ONLY facilities where a violation was found. Source: EPA ECHO. ",
  "Note: 10.8% of rows are placeholders with system-generated VIOL_ACTIVITY_IDs (see footnotes)."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 65)

# Row 3: Counts
mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0(
  "OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
  "  DISTINCT FACILITIES (SOURCE_ID): ", formatC(n_fac, format = "d", big.mark = ",")),
  startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

# Row 4: Key columns
mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, paste0(
  "KEY COLUMNS: SOURCE_ID, REGISTRY_ID, PIPELINE_FLAG, EVAL_FLAG, VIOL_FLAG, EA_FLAG",
  "  |  ACTIVITY IDs: EVAL_ACTIVITY_ID, VIOL_ACTIVITY_ID, EA_ACTIVITY_ID, EA_FEA_ACTIVITY_ID"),
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

# ---- PIPELINE_FLAG (rows 7+) --------------------------------------------------------------------------
# This is the key structural variable — it encodes which stages of the pipeline each row reached.

write_variable(wb, ws, 7,
  "PIPELINE_FLAG",
  "Y = at least one violation links to evaluations/enforcement actions (active in pipeline). N = exited pipeline.",
  plf_miss, plf_ncat,
  paste0(plf_all$PIPELINE_FLAG, " - ", ifelse(plf_all$PIPELINE_FLAG == "Y", "Active in pipeline", "Resolved / exited")),
  plf_all$n, plf_all$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)
r_next <- 7 + nrow(plf_all)

# ---- EVAL_FLAG -----------------------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "EVAL_FLAG",
  "System-generated. Y = at least one CMA (evaluation) linked to the VIOL_ACTIVITY_ID.",
  evf_miss, evf_ncat,
  evf_all$EVAL_FLAG, evf_all$n, evf_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(evf_all)

# ---- VIOL_FLAG -----------------------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "VIOL_FLAG",
  "System-generated. Y = violation present. Per EPA: rows without actual violations have a generated VIOL_ACTIVITY_ID as a linking placeholder.",
  vif_miss, vif_ncat,
  vif_all$VIOL_FLAG, vif_all$n, vif_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(vif_all)

# ---- EA_FLAG -------------------------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "EA_FLAG",
  "System-generated. Y = an enforcement action is linked to this violation.",
  eaf_miss, eaf_ncat,
  eaf_all$EA_FLAG, eaf_all$n, eaf_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(eaf_all)

# ---- EVAL_TYPE_DESC (top 4) ---------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "EVAL_TYPE_DESC",
  "Description of the type of compliance evaluation conducted.",
  etd_miss, etd_ncat,
  etd$EVAL_TYPE_DESC, etd$n, etd$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(etd)

# ---- EVAL_LEAD_AGENCY (all values) --------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "EVAL_LEAD_AGENCY",
  "Agency that led the evaluation (state, EPA, local).",
  ela_miss, ela_ncat,
  ela_all$EVAL_LEAD_AGENCY, ela_all$n, ela_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(ela_all)

# ---- VIOL_TYPE (top 4) ---------------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "VIOL_TYPE",
  "Type of violation. NA and 'Linked to Viol. Below' are placeholders with system-generated VIOL_ACTIVITY_IDs (9906/9913 prefix).",
  vt_miss, vt_ncat,
  dplyr::case_when(
    vt$VIOL_TYPE == "FRV" ~ "FRV - Federally Reportable Violation",
    vt$VIOL_TYPE == "HPV" ~ "HPV - High Priority Violation",
    vt$VIOL_TYPE == "Linked to Viol. Below" ~ "Linked to Viol. Below - System-generated placeholder (no actual violation)",
    TRUE ~ vt$VIOL_TYPE
  ), vt$n, vt$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(vt)

# ---- FOUND_VIOLATION (all values) ---------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "FOUND_VIOLATION",
  "Flag indicating if a violation was found. Y for all rows in this dataset (pipeline contains only violating facilities).",
  fv_miss, fv_ncat,
  fv_all$FOUND_VIOLATION, fv_all$n, fv_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(fv_all)

# ---- OFFICIAL_FLAG (all values) ----------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "OFFICIAL_FLAG",
  "Y = counted as compliance monitoring strategy activities in EPA's Annual Results. Null for programs without compliance monitoring strategies.",
  off_miss, off_ncat,
  off_all$OFFICIAL_FLAG, off_all$n, off_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(off_all)

# ---- VIOL_LEAD_AGENCY (top 4) -----------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "VIOL_LEAD_AGENCY",
  "Agency leading the violation case.",
  vla_miss, vla_ncat,
  vla$VIOL_LEAD_AGENCY, vla$n, vla$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(vla)

# ---- VIOL_PROGRAMS (top 4) --------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "VIOL_PROGRAMS",
  "Program codes associated with the violation.",
  vpr_miss, vpr_ncat,
  vpr$VIOL_PROGRAMS, vpr$n, vpr$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(vpr)

# ---- VIOL_POLLUTANT_CODES (top 4) -------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "VIOL_POLLUTANT_CODES",
  "Pollutant codes for the violation.",
  vpc_miss, vpc_ncat,
  vpc$VIOL_POLLUTANT_CODES, vpc$n, vpc$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(vpc)

# ---- EA_TYPE (top 4) ---------------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "EA_TYPE",
  "Type of enforcement action. 'Date Out of Range' = EA date outside expected window (no EA_DATE recorded).",
  eat_miss, eat_ncat,
  dplyr::case_when(
    eat$EA_TYPE == "Notice of Violation" ~ "Notice of Violation (informal)",
    eat$EA_TYPE == "Administrative - Formal" ~ "Administrative - Formal (consent order, etc.)",
    eat$EA_TYPE == "Warning Letter" ~ "Warning Letter (informal)",
    eat$EA_TYPE == "Date Out of Range" ~ "Date Out of Range (EA date outside expected window; no date recorded)",
    TRUE ~ eat$EA_TYPE
  ), eat$n, eat$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(eat)

# ---- FEA_ISSUE_DATE_FLAG (all values) ----------------------------------------------------------------

write_variable(wb, ws, r_next,
  "FEA_ISSUE_DATE_FLAG",
  "Y = a formal enforcement action issue date exists.",
  fid_miss, fid_ncat,
  fid_all$FEA_ISSUE_DATE_FLAG, fid_all$n, fid_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(fid_all)

# ---- VIOL_END_DATE (top 4, categorical — mixed status/date column) -----------------------------------

write_variable(wb, ws, r_next,
  "VIOL_END_DATE",
  "Violation end date or status (N/A, Unresolved, or a date).",
  ved_miss, ved_ncat,
  ved$VIOL_END_DATE, ved$n, ved$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(ved)

# ---- Categorical footnotes ---------------------------------------------------------------------------

r_fn1 <- r_next + 1
mergeCells(wb, ws, cols = 1:6, rows = r_fn1)
writeData(wb, ws, paste0(
  "**Placeholder rows: ",
  formatC(sum(is.na(pipe$VIOL_TYPE) | pipe$VIOL_TYPE == "Linked to Viol. Below"),
          format = "d", big.mark = ","),
  " rows (", round(sum(is.na(pipe$VIOL_TYPE) | pipe$VIOL_TYPE == "Linked to Viol. Below") / n_obs * 100, 1),
  "%) carry system-generated VIOL_ACTIVITY_IDs (starting with 9906 or 9913). Per EPA documentation, ",
  "these 'did not have an actual violation activity identification number' and were 'system generated ",
  "for purposes of creating the pipeline table.' VIOL_TYPE = NA rows have EA_FLAG = Y but no violation dates or type; ",
  "'Linked to Viol. Below' rows have EA_FLAG = N, EVAL_FLAG = N, and no violation dates. ",
  "Filter to VIOL_TYPE in (HPV, FRV) for real violations."),
  startRow = r_fn1)
addStyle(wb, ws, font12_left, rows = r_fn1, cols = 1)
setRowHeights(wb, ws, rows = r_fn1, heights = 70)

r_fn2 <- r_fn1 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_fn2)
writeData(wb, ws, paste0(
  "FREE-TEXT FIELDS (not tabulated): AIR_NAME (facility name), ",
  "VIOL_POLLUTANT_DESCS (description companion to VIOL_POLLUTANT_CODES)."),
  startRow = r_fn2)
addStyle(wb, ws, font12_left, rows = r_fn2, cols = 1)
setRowHeights(wb, ws, rows = r_fn2, heights = 30)

r_fn3 <- r_fn2 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_fn3)
writeData(wb, ws, paste0(
  "**Date Out of Range: ",
  formatC(sum(pipe$EA_TYPE == "Date Out of Range", na.rm = TRUE), format = "d", big.mark = ","),
  " EA rows have EA_TYPE = 'Date Out of Range'. All 1,116 have no EA_DATE recorded. ",
  "The cause is not documented by EPA."),
  startRow = r_fn3)
addStyle(wb, ws, font12_left, rows = r_fn3, cols = 1)
setRowHeights(wb, ws, rows = r_fn3, heights = 55)

r_fn4 <- r_fn3 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_fn4)
writeData(wb, ws, paste0(
  "**Flags: EVAL_FLAG = Y for ", pct_eval, "% of rows. EA_FLAG = Y for ", pct_ea,
  "%. EVAL_ACTIVITY_ID = -9999 for ",
  formatC(sum(pipe$EVAL_ACTIVITY_ID == -9999, na.rm = TRUE), format = "d", big.mark = ","),
  " rows (no evaluation linked). All PIPELINE_FLAG = N rows have EA_FLAG = N and EVAL_FLAG = N."),
  startRow = r_fn4)
addStyle(wb, ws, font12_left, rows = r_fn4, cols = 1)
setRowHeights(wb, ws, rows = r_fn4, heights = 40)

r_fn5 <- r_fn4 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_fn5)
writeData(wb, ws, paste0(
  "SORT METADATA (not tabulated): SORT_ORDER, SORT_DATE, EVAL_SORT_ORDER, VIOL_SORT_ORDER, ",
  "VIOL_TYPE_SORT, EA_SORT_ORDER. System-generated fields to aid linkage creation and display ",
  "ordering (per EPA documentation)."),
  startRow = r_fn5)
addStyle(wb, ws, font12_left, rows = r_fn5, cols = 1)
setRowHeights(wb, ws, rows = r_fn5, heights = 30)

# ---- Missingness notes -------------------------------------------------------------------------------

n_placeholder <- sum(is.na(pipe$VIOL_TYPE) | pipe$VIOL_TYPE == "Linked to Viol. Below")
n_flag_n <- sum(pipe$PIPELINE_FLAG == "N")
n_eval_9999 <- sum(pipe$EVAL_ACTIVITY_ID == -9999, na.rm = TRUE)
n_ea_n <- sum(pipe$EA_FLAG == "N")
n_ea_y <- sum(pipe$EA_FLAG == "Y")
n_ea_no_date <- sum(pipe$EA_FLAG == "Y" & (is.na(pipe$EA_DATE) | pipe$EA_DATE == ""))
n_dor <- sum(pipe$EA_TYPE == "Date Out of Range", na.rm = TRUE)
pen_vals <- as.numeric(pipe$EA_PENALTY_AMT)
n_pen_na <- sum(is.na(pen_vals) & pipe$EA_FLAG == "Y")
n_pen_zero <- sum(pen_vals == 0 & pipe$EA_FLAG == "Y", na.rm = TRUE)
n_pen_pos <- sum(pen_vals > 0 & pipe$EA_FLAG == "Y", na.rm = TRUE)

r_miss_hdr <- r_fn5 + 2
mergeCells(wb, ws, cols = 1:6, rows = r_miss_hdr)
writeData(wb, ws, "MISSINGNESS NOTES", startRow = r_miss_hdr)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 13, textDecoration = "bold",
                              halign = "left"), rows = r_miss_hdr, cols = 1)

r_m1 <- r_miss_hdr + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m1)
writeData(wb, ws, paste0(
  "Placeholder rows (", formatC(n_placeholder, format = "d", big.mark = ","),
  " rows, 10.8%): VIOL_START_DATE, VIOL_END_DATE, VIOL_LEAD_AGENCY, and VIOL_PROGRAMS are ",
  "100% missing for both placeholder categories (9906 and 9913). All are present for 100% of ",
  "real violations (HPV/FRV). The 10.8% missingness in these columns maps exactly onto the placeholder rows."),
  startRow = r_m1)
addStyle(wb, ws, font12_left, rows = r_m1, cols = 1)
setRowHeights(wb, ws, rows = r_m1, heights = 55)

r_m2 <- r_m1 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m2)
writeData(wb, ws, paste0(
  "PIPELINE_FLAG = N (", formatC(n_flag_n, format = "d", big.mark = ","),
  " rows): EVAL_LEAD_AGENCY, EVAL_DATE, EA_TYPE, EA_DATE, EA_PENALTY_AMT, and EA_COMP_ACTION_COST ",
  "are 100% missing for all N rows. All ", formatC(n_flag_n, format = "d", big.mark = ","),
  " N rows also have EVAL_ACTIVITY_ID = -9999."),
  startRow = r_m2)
addStyle(wb, ws, font12_left, rows = r_m2, cols = 1)
setRowHeights(wb, ws, rows = r_m2, heights = 45)

r_m3 <- r_m2 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m3)
writeData(wb, ws, paste0(
  "EVAL_ACTIVITY_ID = -9999 (", formatC(n_eval_9999, format = "d", big.mark = ","),
  " rows, 65%): No linked evaluation. EVAL_TYPE_DESC missingness (52.3%) tracks this — ",
  "all ", formatC(n_flag_n, format = "d", big.mark = ","), " N rows plus ",
  formatC(n_eval_9999 - n_flag_n, format = "d", big.mark = ","),
  " Y rows have this placeholder."),
  startRow = r_m3)
addStyle(wb, ws, font12_left, rows = r_m3, cols = 1)
setRowHeights(wb, ws, rows = r_m3, heights = 40)

r_m4 <- r_m3 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m4)
writeData(wb, ws, paste0(
  "EA_FLAG = N (", formatC(n_ea_n, format = "d", big.mark = ","),
  " rows, 31.9%): EA_TYPE and EA_ACTIVITY_ID are missing for exactly this share. ",
  "EA_DATE is slightly higher (33.6%) because ",
  formatC(n_ea_no_date, format = "d", big.mark = ","),
  " EA_FLAG = Y rows also lack a date — of those, ",
  formatC(n_dor, format = "d", big.mark = ","), " are 'Date Out of Range'."),
  startRow = r_m4)
addStyle(wb, ws, font12_left, rows = r_m4, cols = 1)
setRowHeights(wb, ws, rows = r_m4, heights = 45)

r_m5 <- r_m4 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m5)
writeData(wb, ws, paste0(
  "EA_PENALTY_AMT among EA_FLAG = Y rows (", formatC(n_ea_y, format = "d", big.mark = ","),
  "): NA = ", formatC(n_pen_na, format = "d", big.mark = ","),
  ", zero = ", formatC(n_pen_zero, format = "d", big.mark = ","),
  ", positive = ", formatC(n_pen_pos, format = "d", big.mark = ","),
  ". Only 31.8% of EA-linked rows carry a non-zero penalty."),
  startRow = r_m5)
addStyle(wb, ws, font12_left, rows = r_m5, cols = 1)
setRowHeights(wb, ws, rows = r_m5, heights = 35)

r_m6 <- r_m5 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m6)
writeData(wb, ws, paste0(
  "VIOL_END_DATE_DATE (74.6% missing): Among real violations (HPV/FRV), 71.6% are missing. ",
  "This column is only populated when a violation end date exists."),
  startRow = r_m6)
addStyle(wb, ws, font12_left, rows = r_m6, cols = 1)
setRowHeights(wb, ws, rows = r_m6, heights = 30)

r_m7 <- r_m6 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m7)
writeData(wb, ws, paste0(
  "FEA_ISSUE_DATE_FLAG (99.7% missing): Only 224 rows have this flag set."),
  startRow = r_m7)
addStyle(wb, ws, font12_left, rows = r_m7, cols = 1)
setRowHeights(wb, ws, rows = r_m7, heights = 25)

r_m8 <- r_m7 + 1
mergeCells(wb, ws, cols = 1:6, rows = r_m8)
writeData(wb, ws, paste0(
  "Most missingness is structural: it is driven by whether the row is a placeholder, ",
  "whether an evaluation is linked, and whether an enforcement action is linked."),
  startRow = r_m8)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "left",
                              valign = "top", wrapText = TRUE, textDecoration = "bold"),
         rows = r_m8, cols = 1)
setRowHeights(wb, ws, rows = r_m8, heights = 30)

# ---- Numerical table header ---------------------------------------------------------------------------

r_num_hdr <- r_m8 + 2
num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = r_num_hdr, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = r_num_hdr, cols = 1:9, gridExpand = TRUE)

# ---- EVAL_DATE year (numerical row) -------------------------------------------------------------------

r_ed <- r_num_hdr + 1
writeData(wb, ws, "EVAL_DATE (Year)\nYear extracted from the evaluation date.",
          startRow = r_ed, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_ed, cols = 1)
writeData(wb, ws, pct_miss(pipe$EVAL_DATE), startRow = r_ed, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_ed, cols = 2)
writeData(wb, ws, eval_n, startRow = r_ed, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_ed, cols = 3)

for (yv in list(list(4, eval_yr_stats$min), list(5, eval_yr_stats$p5),
                list(6, eval_yr_stats$med), list(8, eval_yr_stats$p95),
                list(9, eval_yr_stats$max))) {
  writeData(wb, ws, yv[[2]], startRow = r_ed, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = r_ed, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_ed, cols = 7)
setRowHeights(wb, ws, rows = r_ed, heights = 40)

# ---- VIOL_START_DATE year (numerical row) -------------------------------------------------------------

r_vsd <- r_ed + 1
writeData(wb, ws, "VIOL_START_DATE (Year)\nYear extracted from the violation start date.",
          startRow = r_vsd, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_vsd, cols = 1)
writeData(wb, ws, pct_miss(pipe$VIOL_START_DATE), startRow = r_vsd, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_vsd, cols = 2)
writeData(wb, ws, viol_start_n, startRow = r_vsd, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_vsd, cols = 3)
for (yv in list(list(4, viol_start_stats$min), list(5, viol_start_stats$p5),
                list(6, viol_start_stats$med), list(8, viol_start_stats$p95),
                list(9, viol_start_stats$max))) {
  writeData(wb, ws, yv[[2]], startRow = r_vsd, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = r_vsd, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_vsd, cols = 7)
setRowHeights(wb, ws, rows = r_vsd, heights = 40)

# ---- VIOL_END_DATE_DATE year (numerical row) -----------------------------------------------------------

r_ved <- r_vsd + 1
writeData(wb, ws, "VIOL_END_DATE_DATE (Year)\nYear extracted from the violation end date (dates only).",
          startRow = r_ved, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_ved, cols = 1)
writeData(wb, ws, pct_miss(pipe$VIOL_END_DATE_DATE), startRow = r_ved, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_ved, cols = 2)
writeData(wb, ws, viol_end_n, startRow = r_ved, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_ved, cols = 3)
if (viol_end_n > 0) {
  for (yv in list(list(4, viol_end_stats$min), list(5, viol_end_stats$p5),
                  list(6, viol_end_stats$med), list(8, viol_end_stats$p95),
                  list(9, viol_end_stats$max))) {
    writeData(wb, ws, yv[[2]], startRow = r_ved, startCol = yv[[1]])
    addStyle(wb, ws, cell_year, rows = r_ved, cols = yv[[1]])
  }
}
addStyle(wb, ws, cell_border, rows = r_ved, cols = 7)
setRowHeights(wb, ws, rows = r_ved, heights = 40)

# ---- EA_DATE year (numerical row) ---------------------------------------------------------------------

r_ead <- r_ved + 1
writeData(wb, ws, "EA_DATE (Year)\nYear extracted from the enforcement action date.",
          startRow = r_ead, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_ead, cols = 1)
writeData(wb, ws, pct_miss(pipe$EA_DATE), startRow = r_ead, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_ead, cols = 2)
writeData(wb, ws, ea_date_n, startRow = r_ead, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_ead, cols = 3)
for (yv in list(list(4, ea_date_stats$min), list(5, ea_date_stats$p5),
                list(6, ea_date_stats$med), list(8, ea_date_stats$p95),
                list(9, ea_date_stats$max))) {
  writeData(wb, ws, yv[[2]], startRow = r_ead, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = r_ead, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_ead, cols = 7)
setRowHeights(wb, ws, rows = r_ead, heights = 40)

# ---- EA_PENALTY_AMT (numerical row) -------------------------------------------------------------------

r_pen <- r_ead + 1
writeData(wb, ws, "EA_PENALTY_AMT\nEnforcement action penalty amount ($).",
          startRow = r_pen, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_pen, cols = 1)
writeData(wb, ws, pct_miss(pipe$EA_PENALTY_AMT), startRow = r_pen, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_pen, cols = 2)
writeData(wb, ws, pen_n, startRow = r_pen, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_pen, cols = 3)
for (pv in list(list(4, pen_stats$min), list(5, pen_stats$p5),
                list(6, pen_stats$med), list(8, pen_stats$p95),
                list(9, pen_stats$max))) {
  writeData(wb, ws, pv[[2]], startRow = r_pen, startCol = pv[[1]])
  addStyle(wb, ws, cell_dollar, rows = r_pen, cols = pv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_pen, cols = 7)
setRowHeights(wb, ws, rows = r_pen, heights = 40)

# ---- EA_COMP_ACTION_COST (numerical row) ---------------------------------------------------------------

r_cac <- r_pen + 1
writeData(wb, ws, "EA_COMP_ACTION_COST\nCompliance action cost ($).",
          startRow = r_cac, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_cac, cols = 1)
writeData(wb, ws, pct_miss(pipe$EA_COMP_ACTION_COST), startRow = r_cac, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_cac, cols = 2)
writeData(wb, ws, cac_n, startRow = r_cac, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_cac, cols = 3)
for (pv in list(list(4, cac_stats$min), list(5, cac_stats$p5),
                list(6, cac_stats$med), list(8, cac_stats$p95),
                list(9, cac_stats$max))) {
  writeData(wb, ws, pv[[2]], startRow = r_cac, startCol = pv[[1]])
  addStyle(wb, ws, cell_dollar, rows = r_cac, cols = pv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_cac, cols = 7)
setRowHeights(wb, ws, rows = r_cac, heights = 40)

# ---- Numerical footnote ---------------------------------------------------------------------------------

r_nfn <- r_cac + 2
mergeCells(wb, ws, cols = 1:9, rows = r_nfn)
writeData(wb, ws, paste0(
  "**", n_junk_dates, " EVAL_DATE records have dates outside the 1972-2026 range. ",
  "95% of evaluations fall between ", eval_yr_stats$p5, " and ", eval_yr_stats$p95, ". ",
  "VIOL_END_DATE is a mixed status/date column (tabulated as categorical above); ",
  "VIOL_END_DATE_DATE contains the date portion only (tabulated here)."),
  startRow = r_nfn)
addStyle(wb, ws, font12_left, rows = r_nfn, cols = 1)
setRowHeights(wb, ws, rows = r_nfn, heights = 40)

# ---- Duplicates section ---------------------------------------------------------------------------------

r_dup_hdr <- r_nfn + 2
n_merge_cols <- 9

mergeCells(wb, ws, cols = 1:n_merge_cols, rows = r_dup_hdr)
writeData(wb, ws, "DUPLICATES", startRow = r_dup_hdr)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = r_dup_hdr, cols = 1)

r_dup1 <- r_dup_hdr + 1
mergeCells(wb, ws, cols = 1:n_merge_cols, rows = r_dup1)
writeData(wb, ws, paste0(
  formatC(n_exact_dup, format = "d", big.mark = ","), " exact duplicate rows (",
  round(n_exact_dup / n_obs * 100, 1), "% of all observations)."),
  startRow = r_dup1)
addStyle(wb, ws, font12_left, rows = r_dup1, cols = 1)
setRowHeights(wb, ws, rows = r_dup1, heights = 30)

r_dup2 <- r_dup1 + 1
mergeCells(wb, ws, cols = 1:n_merge_cols, rows = r_dup2)
writeData(wb, ws, paste0(
  "Records per facility (SOURCE_ID): median ", rpf_med, ", max ",
  formatC(rpf_max, format = "d", big.mark = ","), ". ",
  formatC(rpf_multi, format = "d", big.mark = ","), " facilities (",
  round(rpf_multi / n_fac * 100, 1), "%) have multiple records — ",
  "expected since a single facility can have multiple evaluations, violations, ",
  "and enforcement actions over time."),
  startRow = r_dup2)
addStyle(wb, ws, font12_left, rows = r_dup2, cols = 1)
setRowHeights(wb, ws, rows = r_dup2, heights = 40)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/pipeline_table.xlsx"), overwrite = TRUE)
