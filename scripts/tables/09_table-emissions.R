# =========================================================================================================
# 09_table-emissions.R — data-dictionary table for the POLL_RPT_COMBINED_EMISSIONS dataset (~10.4M rows).
# Writes output/tables/emissions_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(openxlsx)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# This file is ~10.4 million rows. read_csv handles it fine but it may take
# 30-60 seconds to load depending on your machine. Be patient!

em <- read_csv(here("data/raw/POLL_RPT_COMBINED_EMISSIONS.csv"), show_col_types = FALSE)
n_obs <- nrow(em)
n_fac <- n_distinct(em$REGISTRY_ID)
n_pgm <- n_distinct(em$PGM_SYS_ID)

# ---- Helper functions -----------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# ---- Compute statistics: Categorical -------------------------------------------------------------------

# PGM_SYS_ACRNM — reporting program acronym (tells you TRI vs NEI vs other sources)
# Report all values since this is a key variable for understanding the data
psa_all <- em |> filter(!is.na(PGM_SYS_ACRNM)) |>
  count(PGM_SYS_ACRNM) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
psa_miss <- pct_miss(em$PGM_SYS_ACRNM)
psa_ncat <- n_cats(em$PGM_SYS_ACRNM)

# POLLUTANT_NAME — top 6 most common pollutants
pol <- top_vals(em, POLLUTANT_NAME, 6)
pol_miss <- pct_miss(em$POLLUTANT_NAME)
pol_ncat <- n_cats(em$POLLUTANT_NAME)

# UNIT_OF_MEASURE — all values (expect a small number of distinct units)
uom_all <- em |> filter(!is.na(UNIT_OF_MEASURE)) |>
  count(UNIT_OF_MEASURE) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
uom_miss <- pct_miss(em$UNIT_OF_MEASURE)
uom_ncat <- n_cats(em$UNIT_OF_MEASURE)

# NEI_TYPE — all values
nei_all <- em |> filter(!is.na(NEI_TYPE)) |>
  count(NEI_TYPE) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
nei_miss <- pct_miss(em$NEI_TYPE)
nei_ncat <- n_cats(em$NEI_TYPE)

# NEI_HAP_VOC_FLAG — all values
nhv_all <- em |> filter(!is.na(NEI_HAP_VOC_FLAG)) |>
  count(NEI_HAP_VOC_FLAG) |> arrange(desc(n)) |> mutate(pct = n / n_obs)
nhv_miss <- pct_miss(em$NEI_HAP_VOC_FLAG)
nhv_ncat <- n_cats(em$NEI_HAP_VOC_FLAG)

# ---- Compute statistics: Numerical ---------------------------------------------------------------------

# REPORTING_YEAR — already numeric, no parsing needed
ry_miss <- sum(is.na(em$REPORTING_YEAR))
ry_n <- sum(!is.na(em$REPORTING_YEAR))
ry <- list(min = min(em$REPORTING_YEAR, na.rm = TRUE),
           p5  = as.integer(quantile(em$REPORTING_YEAR, 0.05, na.rm = TRUE)),
           med = as.integer(median(em$REPORTING_YEAR, na.rm = TRUE)),
           p95 = as.integer(quantile(em$REPORTING_YEAR, 0.95, na.rm = TRUE)),
           max = max(em$REPORTING_YEAR, na.rm = TRUE))

# ANNUAL_EMISSION — continuous, can be 0 or negative
# Only compute stats among non-missing values
ae_miss <- sum(is.na(em$ANNUAL_EMISSION))
ae_n <- sum(!is.na(em$ANNUAL_EMISSION))
ae_zeros <- sum(em$ANNUAL_EMISSION == 0, na.rm = TRUE)
ae_negatives <- sum(em$ANNUAL_EMISSION < 0, na.rm = TRUE)
ae <- list(min = min(em$ANNUAL_EMISSION, na.rm = TRUE),
           p5  = quantile(em$ANNUAL_EMISSION, 0.05, na.rm = TRUE),
           med = median(em$ANNUAL_EMISSION, na.rm = TRUE),
           p95 = quantile(em$ANNUAL_EMISSION, 0.95, na.rm = TRUE),
           max = max(em$ANNUAL_EMISSION, na.rm = TRUE))

# ---- Compute statistics: Duplicates --------------------------------------------------------------------

# Exact duplicate rows (all columns identical)
n_exact_dup <- sum(duplicated(em))

# Records per facility (REGISTRY_ID) — how many rows does each facility have?
rpf <- em |> group_by(REGISTRY_ID) |> summarise(n = n(), .groups = "drop")
rpf_med <- as.integer(median(rpf$n))
rpf_max <- max(rpf$n)
rpf_multi <- sum(rpf$n > 1)

# Facility-pollutant-year duplicates — are there multiple records for the same
# facility reporting the same pollutant in the same year?
fpy_dups <- em |>
  group_by(REGISTRY_ID, POLLUTANT_NAME, REPORTING_YEAR) |>
  summarise(n = n(), .groups = "drop") |>
  filter(n > 1)
n_fpy_dup_combos <- nrow(fpy_dups)
n_fpy_dup_rows <- sum(fpy_dups$n)

# ---- Compute program shares for footnotes ---------------------------------------------------------------

# Which programs contribute what share of the data
pgm_shares <- em |> filter(!is.na(PGM_SYS_ACRNM)) |>
  count(PGM_SYS_ACRNM) |> arrange(desc(n)) |>
  mutate(pct = round(n / sum(n) * 100, 1))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Emissions")
ws <- "Emissions"

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

# ---- Header block ---------------------------------------------------------------------------------------

# Row 1: Title
mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "Combined Emissions (POLL_RPT_COMBINED_EMISSIONS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

# Row 2: Description
mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Facility-level pollutant emissions from multiple EPA reporting programs (TRI, NEI, etc.). ",
  "Each row is one facility-pollutant-year observation. Links to FRS via REGISTRY_ID."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 40)

# Row 3: Counts
mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0(
  "OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
  "  DISTINCT FACILITIES (REGISTRY_ID): ", formatC(n_fac, format = "d", big.mark = ","),
  "  DISTINCT PGM_SYS_IDs: ", formatC(n_pgm, format = "d", big.mark = ",")),
  startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

# Row 4: Identifiers
mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: REGISTRY_ID, PGM_SYS_ID, PGM_SYS_ACRNM", startRow = 4)
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

# ---- PGM_SYS_ACRNM (rows 7+) --------------------------------------------------------------------------
# This variable tells you which reporting program the emission data comes from.
# Show all values since this is a key structural variable.

psa_n_show <- nrow(psa_all)
write_variable(wb, ws, 7,
  "PGM_SYS_ACRNM",
  "Reporting program acronym (e.g., TRIS = TRI, EIS = NEI). Tells you the source system.",
  psa_miss, psa_ncat,
  psa_all$PGM_SYS_ACRNM, psa_all$n, psa_all$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# Track where we are for the next variable
r_next <- 7 + psa_n_show

# ---- POLLUTANT_NAME (top 6) ----------------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "POLLUTANT_NAME",
  paste0("Name of the pollutant. ", pol_ncat, " distinct pollutants in the dataset."),
  pol_miss, pol_ncat,
  pol$POLLUTANT_NAME, pol$n, pol$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(pol)

# ---- UNIT_OF_MEASURE (all values) ----------------------------------------------------------------------

write_variable(wb, ws, r_next,
  "UNIT_OF_MEASURE",
  "Unit for ANNUAL_EMISSION (e.g., Pounds, Tons).",
  uom_miss, uom_ncat,
  uom_all$UNIT_OF_MEASURE, uom_all$n, uom_all$pct)
setRowHeights(wb, ws, rows = r_next, heights = 45)
r_next <- r_next + nrow(uom_all)

# ---- NEI_TYPE (all values) -----------------------------------------------------------------------------
# Only write this variable if there are non-missing values

if (nrow(nei_all) > 0) {
  write_variable(wb, ws, r_next,
    "NEI_TYPE",
    "National Emissions Inventory type classification. Only populated for NEI records.",
    nei_miss, nei_ncat,
    nei_all$NEI_TYPE, nei_all$n, nei_all$pct)
  setRowHeights(wb, ws, rows = r_next, heights = 45)
  r_next <- r_next + nrow(nei_all)
} else {
  # If all missing, write a single row noting that
  write_variable(wb, ws, r_next,
    "NEI_TYPE",
    "National Emissions Inventory type classification. Only populated for NEI records.",
    nei_miss, nei_ncat,
    "(all missing)", 0, 0)
  setRowHeights(wb, ws, rows = r_next, heights = 45)
  r_next <- r_next + 1
}

# ---- NEI_HAP_VOC_FLAG (all values) --------------------------------------------------------------------

if (nrow(nhv_all) > 0) {
  write_variable(wb, ws, r_next,
    "NEI_HAP_VOC_FLAG",
    "Flags whether the pollutant is a HAP or VOC in the NEI system.",
    nhv_miss, nhv_ncat,
    nhv_all$NEI_HAP_VOC_FLAG, nhv_all$n, nhv_all$pct)
  setRowHeights(wb, ws, rows = r_next, heights = 45)
  r_next <- r_next + nrow(nhv_all)
} else {
  write_variable(wb, ws, r_next,
    "NEI_HAP_VOC_FLAG",
    "Flags whether the pollutant is a HAP or VOC in the NEI system.",
    nhv_miss, nhv_ncat,
    "(all missing)", 0, 0)
  setRowHeights(wb, ws, rows = r_next, heights = 45)
  r_next <- r_next + 1
}

# ---- Categorical footnotes (after last categorical variable + 1 blank row) ----------------------------

r_fn1 <- r_next + 1
n_merge_cols_cat <- 6

mergeCells(wb, ws, cols = 1:n_merge_cols_cat, rows = r_fn1)
# Build a string summarizing the program shares
pgm_shares_str <- paste0(pgm_shares$PGM_SYS_ACRNM, " (", pgm_shares$pct, "%)",
                          collapse = ", ")
writeData(wb, ws, paste0(
  "**Reporting programs represented: ", pgm_shares_str, ". ",
  "TRIS = Toxics Release Inventory, EIS = Emissions Inventory System (NEI)."),
  startRow = r_fn1)
addStyle(wb, ws, font12_left, rows = r_fn1, cols = 1)
setRowHeights(wb, ws, rows = r_fn1, heights = 40)

r_fn2 <- r_fn1 + 1
mergeCells(wb, ws, cols = 1:n_merge_cols_cat, rows = r_fn2)
writeData(wb, ws, paste0(
  "**ANNUAL_EMISSION values: ",
  formatC(ae_zeros, format = "d", big.mark = ","), " zeros (",
  round(ae_zeros / n_obs * 100, 1), "%), ",
  formatC(ae_negatives, format = "d", big.mark = ","), " negatives (",
  round(ae_negatives / n_obs * 100, 1), "%). ",
  "Range: ", formatC(ae$min, format = "f", big.mark = ",", digits = 2),
  " to ", formatC(ae$max, format = "f", big.mark = ",", digits = 2),
  ". Units vary — see UNIT_OF_MEASURE."),
  startRow = r_fn2)
addStyle(wb, ws, font12_left, rows = r_fn2, cols = 1)
setRowHeights(wb, ws, rows = r_fn2, heights = 40)

# ---- Numerical table header ---------------------------------------------------------------------------

r_num_hdr <- r_fn2 + 2
num_headers <- c("Variable", "% Missing", "N", "Min", "P5", "Median", "", "P95", "Max")
writeData(wb, ws, t(num_headers), startRow = r_num_hdr, colNames = FALSE)
addStyle(wb, ws, orange_header, rows = r_num_hdr, cols = 1:9, gridExpand = TRUE)

# ---- REPORTING_YEAR (numerical row) -------------------------------------------------------------------

r_ry <- r_num_hdr + 1
writeData(wb, ws, "REPORTING_YEAR\nYear of the emissions report.",
          startRow = r_ry, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_ry, cols = 1)
writeData(wb, ws, pct_miss(em$REPORTING_YEAR), startRow = r_ry, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_ry, cols = 2)
writeData(wb, ws, ry_n, startRow = r_ry, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_ry, cols = 3)

for (yv in list(list(4, ry$min), list(5, ry$p5), list(6, ry$med),
                list(8, ry$p95), list(9, ry$max))) {
  writeData(wb, ws, yv[[2]], startRow = r_ry, startCol = yv[[1]])
  addStyle(wb, ws, cell_year, rows = r_ry, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_ry, cols = 7)
setRowHeights(wb, ws, rows = r_ry, heights = 40)

# ---- ANNUAL_EMISSION (numerical row) ------------------------------------------------------------------
# Note: these values can be 0 or negative, and we count those separately.

r_ae <- r_ry + 1
writeData(wb, ws, paste0("ANNUAL_EMISSION\nAnnual emission quantity. ",
                          formatC(ae_zeros, format = "d", big.mark = ","), " zeros, ",
                          formatC(ae_negatives, format = "d", big.mark = ","), " negatives."),
          startRow = r_ae, startCol = 1)
addStyle(wb, ws, cell_border_bold, rows = r_ae, cols = 1)
writeData(wb, ws, pct_miss(em$ANNUAL_EMISSION), startRow = r_ae, startCol = 2)
addStyle(wb, ws, cell_border, rows = r_ae, cols = 2)
writeData(wb, ws, ae_n, startRow = r_ae, startCol = 3)
addStyle(wb, ws, cell_comma, rows = r_ae, cols = 3)

# Write the five summary stats: min, p5, median, p95, max
for (yv in list(list(4, ae$min), list(5, ae$p5), list(6, ae$med),
                list(8, ae$p95), list(9, ae$max))) {
  writeData(wb, ws, yv[[2]], startRow = r_ae, startCol = yv[[1]])
  addStyle(wb, ws, cell_comma, rows = r_ae, cols = yv[[1]])
}
addStyle(wb, ws, cell_border, rows = r_ae, cols = 7)
setRowHeights(wb, ws, rows = r_ae, heights = 55)

# ---- Duplicates section ---------------------------------------------------------------------------------

r_dup_hdr <- r_ae + 2
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
  "Records per facility (REGISTRY_ID): median ", rpf_med, ", max ",
  formatC(rpf_max, format = "d", big.mark = ","), ". ",
  formatC(rpf_multi, format = "d", big.mark = ","), " facilities (",
  round(rpf_multi / n_fac * 100, 1), "%) have multiple records — ",
  "expected since each facility can report multiple pollutants across multiple years."),
  startRow = r_dup2)
addStyle(wb, ws, font12_left, rows = r_dup2, cols = 1)
setRowHeights(wb, ws, rows = r_dup2, heights = 40)

r_dup3 <- r_dup2 + 1
mergeCells(wb, ws, cols = 1:n_merge_cols, rows = r_dup3)
writeData(wb, ws, paste0(
  formatC(n_fpy_dup_combos, format = "d", big.mark = ","),
  " facility-pollutant-year combinations appear more than once (",
  formatC(n_fpy_dup_rows, format = "d", big.mark = ","),
  " total rows). These may reflect reports from different programs ",
  "(e.g., same pollutant reported to both TRI and NEI) or duplicate submissions."),
  startRow = r_dup3)
addStyle(wb, ws, font12_left, rows = r_dup3, cols = 1)
setRowHeights(wb, ws, rows = r_dup3, heights = 40)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/emissions_table.xlsx"), overwrite = TRUE)
