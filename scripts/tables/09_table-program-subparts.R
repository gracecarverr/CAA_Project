# =========================================================================================================
# 09_table-program-subparts.R — builds the data-dictionary table for ICIS-AIR_PROGRAM_SUBPARTS.
# Each raw row links a facility-program enrollment to a specific regulatory subpart (e.g. NSPS Subpart
# JJJJ for spark-ignition engines). Summarizes every column and writes a formatted workbook to
# output/tables/program_subparts_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized; suffixes: _miss = % missing, _ncat = # categories.
# Paths via here::here() (anchored on .git).
# =========================================================================================================

library(here)
library(openxlsx)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------

sp <- read_csv(here("data/raw/ICIS-AIR_downloads/ICIS-AIR_PROGRAM_SUBPARTS.csv"), show_col_types = FALSE)
n_obs <- nrow(sp)
n_fac <- n_distinct(sp$PGM_SYS_ID)

# ---- Compute statistics ---------------------------------------------------------------------------------

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# PROGRAM_CODE
pc <- sp |> count(PROGRAM_CODE, PROGRAM_DESC) |>
  mutate(pct = n / n_obs) |> arrange(desc(n))
pc_miss <- pct_miss(sp$PROGRAM_CODE)
pc_ncat <- n_cats(sp$PROGRAM_CODE)

# AIR_PROGRAM_SUBPART_CODE — top 6
sub_top <- sp |> count(AIR_PROGRAM_SUBPART_CODE, AIR_PROGRAM_SUBPART_DESC) |>
  mutate(pct = n / n_obs) |> arrange(desc(n)) |> slice_head(n = 6)
sub_miss <- pct_miss(sp$AIR_PROGRAM_SUBPART_CODE)
sub_ncat <- n_cats(sp$AIR_PROGRAM_SUBPART_CODE)

# Duplicates
n_exact_dup <- sum(duplicated(sp))
n_dup_combo <- sum(duplicated(sp |> select(PGM_SYS_ID, PROGRAM_CODE, AIR_PROGRAM_SUBPART_CODE)))
fpf <- sp |> group_by(PGM_SYS_ID) |> summarise(n = n(), .groups = "drop")
n_multi <- sum(fpf$n > 1)
max_sub <- max(fpf$n)
med_sub <- as.integer(median(fpf$n))

# Subparts per program
spp <- sp |> group_by(PROGRAM_CODE) |>
  summarise(n_subparts = n_distinct(AIR_PROGRAM_SUBPART_CODE), .groups = "drop") |>
  arrange(desc(n_subparts))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "Program Subparts")
ws <- "Program Subparts"

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
setColWidths(wb, ws, cols = 4, widths = 65)
setColWidths(wb, ws, cols = 5:6, widths = 14)

# ---- Header block ---------------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "ICIS-Air Program Subparts (ICIS-AIR_PROGRAM_SUBPARTS.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Each row links a facility's program enrollment to a specific regulatory subpart. ",
  "Subparts are the detailed rules within NSPS (Part 60), MACT (Part 63), and NESHAP (Part 61) ",
  "that apply to specific source categories or industrial processes."),
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
writeData(wb, ws, "IDENTIFIERS: PGM_SYS_ID, PROGRAM_CODE, AIR_PROGRAM_SUBPART_CODE",
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

# ---- PROGRAM_CODE (rows 7-14) -------------------------------------------------------------------------

write_variable(wb, ws, 7,
  "PROGRAM_CODE",
  "Which regulatory program the subpart falls under.",
  pc_miss, pc_ncat,
  paste0(pc$PROGRAM_CODE, " - ", pc$PROGRAM_DESC),
  pc$n, pc$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- AIR_PROGRAM_SUBPART_CODE (rows 15-20) -------------------------------------------------------------

sub_descs <- sub_top$AIR_PROGRAM_SUBPART_DESC

write_variable(wb, ws, 15,
  "AIR_PROGRAM_SUBPART_CODE",
  paste0("Specific regulatory subpart. ", sub_ncat, " distinct subparts in the dataset."),
  sub_miss, sub_ncat,
  sub_descs,
  sub_top$n, sub_top$pct)
setRowHeights(wb, ws, rows = 15, heights = 45)

# ---- Footnotes -----------------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 22)
writeData(wb, ws, paste0(
  "**NSPS (", round(pc$pct[pc$PROGRAM_CODE == "CAANSPS"] * 100, 1),
  "%) and MACT (", round(pc$pct[pc$PROGRAM_CODE == "CAAMACT"] * 100, 1),
  "%) account for ", round((pc$pct[pc$PROGRAM_CODE == "CAANSPS"] +
  pc$pct[pc$PROGRAM_CODE == "CAAMACT"]) * 100, 1),
  "% of all subpart records. These are the two technology-based standard programs with ",
  "the most detailed subpart structure."),
  startRow = 22)
addStyle(wb, ws, font12_left, rows = 22, cols = 1)
setRowHeights(wb, ws, rows = 22, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 23)
writeData(wb, ws, paste0(
  "**The most common subpart is MACT Subpart ZZZZ (Stationary Reciprocating Internal Combustion ",
  "Engines), covering ", formatC(sub_top$n[1], format = "d", big.mark = ","), " facility-subpart ",
  "records (", round(sub_top$pct[1] * 100, 1), "%). NSPS Subparts JJJJ and IIII (spark ignition ",
  "and compression ignition engines) are the next most common — engines are ubiquitous across ",
  "industrial facilities."),
  startRow = 23)
addStyle(wb, ws, font12_left, rows = 23, cols = 1)
setRowHeights(wb, ws, rows = 23, heights = 50)

# ---- Duplicates section --------------------------------------------------------------------------------

mergeCells(wb, ws, cols = 1:6, rows = 25)
writeData(wb, ws, "DUPLICATES", startRow = 25)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = 25, cols = 1)

mergeCells(wb, ws, cols = 1:6, rows = 26)
writeData(wb, ws, paste0(
  formatC(n_exact_dup, format = "d", big.mark = ","), " exact duplicate rows (",
  round(n_exact_dup / n_obs * 100, 1), "%). ",
  formatC(n_dup_combo, format = "d", big.mark = ","),
  " rows share the same PGM_SYS_ID + PROGRAM_CODE + AIR_PROGRAM_SUBPART_CODE combination ",
  "with at least one other row."),
  startRow = 26)
addStyle(wb, ws, font12_left, rows = 26, cols = 1)
setRowHeights(wb, ws, rows = 26, heights = 40)

mergeCells(wb, ws, cols = 1:6, rows = 27)
writeData(wb, ws, paste0(
  formatC(n_multi, format = "d", big.mark = ","), " facilities (",
  round(n_multi / n_fac * 100, 1),
  "%) are subject to 2+ subparts (max ", max_sub,
  "; median ", med_sub, "). This is expected — a facility with multiple emission points or ",
  "processes will be subject to multiple NSPS or MACT subparts. NSPS alone has ",
  spp$n_subparts[spp$PROGRAM_CODE == "CAANSPS"],
  " distinct subparts; MACT has ",
  spp$n_subparts[spp$PROGRAM_CODE == "CAAMACT"], "."),
  startRow = 27)
addStyle(wb, ws, font12_left, rows = 27, cols = 1)
setRowHeights(wb, ws, rows = 27, heights = 50)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/program_subparts_table.xlsx"), overwrite = TRUE)
