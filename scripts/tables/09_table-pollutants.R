# =========================================================================================================
# 09_table-pollutants.R — builds the data-dictionary table for ICIS-AIR_POLLUTANTS.
# Summarizes every column and writes a formatted workbook to output/tables/pollutants_table.xlsx.
# Reference tooling, not part of the analysis pipeline. Short object names abbreviate the column
# summarized; suffixes: _miss = % missing, _ncat = # distinct categories. Paths via here::here().
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(openxlsx)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------

pl <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_POLLUTANTS.csv"), show_col_types = FALSE)
n_obs <- nrow(pl)
n_fac <- n_distinct(pl$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# POLLUTANT_DESC — count distinct (POLLUTANT_CODE, POLLUTANT_DESC) pairs
pld <- top_vals(pl, POLLUTANT_DESC, 5)
pld_miss <- pct_miss(pl$POLLUTANT_DESC)
pld_ncat <- pl |> filter(!is.na(POLLUTANT_CODE), !is.na(POLLUTANT_DESC)) |>
  distinct(POLLUTANT_CODE, POLLUTANT_DESC) |> nrow()

# AIR_POLLUTANT_CLASS_CODE — top 3, then sum remaining into "Other"
apc_all <- pl |> filter(!is.na(AIR_POLLUTANT_CLASS_CODE)) |>
  count(AIR_POLLUTANT_CLASS_CODE) |> arrange(desc(n))
apc_top <- apc_all |> slice_head(n = 3) |> mutate(pct = n / nrow(pl))
apc_other <- apc_all |> slice_tail(n = nrow(apc_all) - 3)
apc_other_row <- tibble(AIR_POLLUTANT_CLASS_CODE = "UNK/NAP/OTH",
                        n = sum(apc_other$n), pct = sum(apc_other$n) / nrow(pl))
apc <- bind_rows(apc_top, apc_other_row)
apc_miss <- pct_miss(pl$AIR_POLLUTANT_CLASS_CODE)
apc_ncat <- n_cats(pl$AIR_POLLUTANT_CLASS_CODE)

# SRS_ID
srs_miss <- pct_miss(pl$SRS_ID)
srs_ncat <- n_cats(pl$SRS_ID)
srs_n_nonmiss <- sum(!is.na(pl$SRS_ID))

# CHEMICAL_ABSTRACT_SERVICE_NMBR
cas <- top_vals(pl, CHEMICAL_ABSTRACT_SERVICE_NMBR, 4)
cas_miss <- pct_miss(pl$CHEMICAL_ABSTRACT_SERVICE_NMBR)
cas_ncat <- n_cats(pl$CHEMICAL_ABSTRACT_SERVICE_NMBR)

# Duplicates
n_exact_dup <- sum(duplicated(pl))
n_dup_pgm_pol <- sum(duplicated(pl |> select(PGM_SYS_ID, POLLUTANT_CODE)))
n_class_diff <- pl |> group_by(PGM_SYS_ID, POLLUTANT_CODE) |>
  filter(n() > 1, n_distinct(AIR_POLLUTANT_CLASS_CODE) > 1) |>
  ungroup() |> distinct(PGM_SYS_ID, POLLUTANT_CODE) |> nrow()

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Pollutants")
ws <- "Pollutants"

# ---- Styles ---------------------------------------------------------------------------------------------

font_title <- createStyle(fontName = "Calibri", fontSize = 15, textDecoration = "bold",
                          halign = "center")
font12_left <- createStyle(fontName = "Calibri", fontSize = 12, halign = "left",
                            valign = "top", wrapText = TRUE)

green_header <- createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                             halign = "center", valign = "center", wrapText = TRUE,
                             fgFill = "#C6EFCE", border = "TopBottomLeftRight")

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

# ---- Column widths --------------------------------------------------------------------------------------

setColWidths(wb, ws, cols = 1, widths = 30)
setColWidths(wb, ws, cols = 2, widths = 18)
setColWidths(wb, ws, cols = 3, widths = 14)
setColWidths(wb, ws, cols = 4, widths = 45)
setColWidths(wb, ws, cols = 5:6, widths = 14)

# ---- Header block ---------------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "ICIS-Air Pollutants (ICIS-AIR_POLLUTANTS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Each row is one facility-pollutant combination — which pollutants each regulated source is ",
  "associated with. A single facility can appear many times if it is linked to multiple pollutants."),
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
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID, POLLUTANT_CODE, SRS_ID", startRow = 4)
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

# ---- POLLUTANT_DESC (rows 7-11) ------------------------------------------------------------------------

write_variable(wb, ws, 7,
  "POLLUTANT_DESC",
  paste0("Name of the pollutant. ", pld_ncat, " distinct pollutants in the dataset."),
  pld_miss, pld_ncat,
  pld$POLLUTANT_DESC, pld$n, pld$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- AIR_POLLUTANT_CLASS_CODE (rows 12-15) -------------------------------------------------------------

write_variable(wb, ws, 12,
  "AIR_POLLUTANT_CLASS_CODE",
  "Emissions classification of the facility associated with this pollutant record.",
  apc_miss, apc_ncat,
  c("MIN - Minor Emissions", "SMI - Synthetic Minor",
    "MAJ - Major Emissions", "UNK/NAP/OTH - Other or Unknown"),
  apc$n, apc$pct)
setRowHeights(wb, ws, rows = 12, heights = 45)

# ---- SRS_ID (rows 16-17) -------------------------------------------------------------------------------

write_variable(wb, ws, 16,
  "SRS_ID",
  "EPA Substance Registry Services identifier for the pollutant.",
  srs_miss, srs_ncat,
  c("(Numeric IDs — no human-readable labels)", paste0(srs_ncat, " distinct values")),
  c(srs_n_nonmiss, srs_n_nonmiss),
  c(srs_n_nonmiss / n_obs, srs_n_nonmiss / n_obs))
setRowHeights(wb, ws, rows = 16, heights = 45)

# ---- CHEMICAL_ABSTRACT_SERVICE_NMBR (rows 18-21) -------------------------------------------------------

cas_labels <- c("630080" = "Carbon Monoxide (CO)", "10102440" = "Nitrogen Dioxide (NO2)",
                "7446095" = "Sulfur Dioxide (SO2)", "50000" = "Formaldehyde")
cas_descs <- paste0(cas$CHEMICAL_ABSTRACT_SERVICE_NMBR, " - ",
                    cas_labels[as.character(cas$CHEMICAL_ABSTRACT_SERVICE_NMBR)])

write_variable(wb, ws, 18,
  "CHEMICAL_ABSTRACT_SERVICE_NMBR",
  "CAS Registry Number — standard chemical identifier used across databases.",
  cas_miss, cas_ncat,
  cas_descs, cas$n, cas$pct)
setRowHeights(wb, ws, rows = 18, heights = 45)

# ---- Footnotes ------------------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 23)
writeData(wb, ws, paste0(
  "**\"", pld$POLLUTANT_DESC[1], "\" is the most common pollutant entry (",
  round(pld$pct[1] * 100), "%) — it is a facility-level placeholder ",
  "with no actual pollutant information. The next four are criteria pollutants (VOCs, PM, CO, NOx), ",
  "which together account for another ", round(sum(pld$pct[2:5]) * 100), "% of records."),
  startRow = 23)
addStyle(wb, ws, font12_left, rows = 23, cols = 1)
setRowHeights(wb, ws, rows = 23, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 24)
writeData(wb, ws, paste0(
  "**SRS_ID (", srs_miss, " missing) and CAS Number (", cas_miss, " missing) are chemical registry identifiers. ",
  "Not all pollutant entries map to a specific chemical compound — entries like FACIL and VOCs ",
  "are categories, not individual chemicals."),
  startRow = 24)
addStyle(wb, ws, font12_left, rows = 24, cols = 1)
setRowHeights(wb, ws, rows = 24, heights = 30)

# ---- Duplicates section ---------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 26)
writeData(wb, ws, "DUPLICATES", startRow = 26)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 26, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 27)
writeData(wb, ws, paste0(
  formatC(n_exact_dup, format = "d", big.mark = ","), " exact duplicate rows (",
  round(n_exact_dup / n_obs * 100, 1), "%). ",
  "Likely a data export artifact — same facility-pollutant record doubled. ",
  "Users should deduplicate before analysis."),
  startRow = 27)
addStyle(wb, ws, font12_left, rows = 27, cols = 1)
setRowHeights(wb, ws, rows = 27, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 28)
writeData(wb, ws, paste0(
  "Beyond exact duplicates, ", formatC(n_class_diff, format = "d", big.mark = ","),
  " facility-pollutant pairs have multiple rows that differ only in ",
  "AIR_POLLUTANT_CLASS_CODE — the same facility lists the same pollutant under different emissions ",
  "classifications (e.g., UNK and MIN). This likely reflects reclassification events: a facility's ",
  "emissions status changed but the old record was retained alongside the new one."),
  startRow = 28)
addStyle(wb, ws, font12_left, rows = 28, cols = 1)
setRowHeights(wb, ws, rows = 28, heights = 55)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/pollutants_table.xlsx"), overwrite = TRUE)
