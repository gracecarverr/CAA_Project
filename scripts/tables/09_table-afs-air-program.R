# =========================================================================================================
# 09_table-afs-air-program.R — data-dictionary table for the legacy AFS AIR_PROGRAM dataset.
# Writes output/tables/afs_air_program_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------
# here     — resolves project-root-relative paths (replaces a hardcoded working directory)
# openxlsx — builds and formats the Excel workbook
# readr    — fast CSV reading with read_csv()
# dplyr    — data wrangling (filter, count, group_by, etc.)

library(here)
library(openxlsx)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------
# Each row in this file links a facility to an air program enrollment.
# Columns include the program code, compliance status, and associated pollutant info.
# This is from EPA's legacy AFS system (frozen October 2014).

air <- read_csv(here("data/raw/afs_downloads/AIR_PROGRAM.csv"), show_col_types = FALSE)
n_obs <- nrow(air)
n_fac <- n_distinct(air$AFS_ID)

# ---- Helper functions -----------------------------------------------------------------------------------
# pct_miss  — returns the % of values that are NA as a string like "12.3%"
# n_cats    — counts how many unique values a column has
# top_vals  — finds the n_top most common values and their share of all rows

pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

top_vals <- function(df, var, n_top = 4) {
  df |> filter(!is.na({{ var }})) |> count({{ var }}) |> arrange(desc(n)) |>
    slice_head(n = n_top) |> mutate(pct = n / nrow(df))
}

# ---- Compute statistics ---------------------------------------------------------------------------------

# --- Categorical variables ---

# AIR_PROGRAM_CODE — which regulatory air program the facility is enrolled in (top 6)
apc <- top_vals(air, AIR_PROGRAM_CODE, 6)
apc_miss <- pct_miss(air$AIR_PROGRAM_CODE)
apc_ncat <- n_cats(air$AIR_PROGRAM_CODE)

# AIR_PROGRAM_STATUS — whether the program enrollment is active, obsolete, etc. (top 5)
aps_all <- air |> filter(!is.na(AIR_PROGRAM_STATUS)) |>
  count(AIR_PROGRAM_STATUS) |> arrange(desc(n)) |>
  mutate(pct = n / n_obs) |> slice_head(n = 5)
aps_miss <- pct_miss(air$AIR_PROGRAM_STATUS)
aps_ncat <- n_cats(air$AIR_PROGRAM_STATUS)

# EPA_CLASSIFICATION_CODE — EPA's classification of the source (all values)
ecc_all <- air |> filter(!is.na(EPA_CLASSIFICATION_CODE)) |>
  mutate(EPA_CLASSIFICATION_CODE = trimws(EPA_CLASSIFICATION_CODE)) |>
  count(EPA_CLASSIFICATION_CODE) |> arrange(desc(n)) |>
  mutate(pct = n / n_obs)
ecc_miss <- pct_miss(air$EPA_CLASSIFICATION_CODE)
ecc_ncat <- n_cats(air$EPA_CLASSIFICATION_CODE)

# EPA_COMPLIANCE_STATUS — top 4 compliance status codes
ecs <- top_vals(air, EPA_COMPLIANCE_STATUS, 4)
ecs_miss <- pct_miss(air$EPA_COMPLIANCE_STATUS)
ecs_ncat <- n_cats(air$EPA_COMPLIANCE_STATUS)

# POLLUTANT_CLASSIFICATION — top 4 pollutant classification codes
pcl <- top_vals(air, POLLUTANT_CLASSIFICATION, 4)
pcl_miss <- pct_miss(air$POLLUTANT_CLASSIFICATION)
pcl_ncat <- n_cats(air$POLLUTANT_CLASSIFICATION)

# POLLUTANT_CODE — specific pollutant associated with the program enrollment (top 4)
pcd <- top_vals(air, POLLUTANT_CODE, 4)
pcd_miss <- pct_miss(air$POLLUTANT_CODE)
pcd_ncat <- n_cats(air$POLLUTANT_CODE)

# POLLUTANT_COMPLIANCE_STATUS — compliance status at the pollutant level (top 4)
pcs <- top_vals(air, POLLUTANT_COMPLIANCE_STATUS, 4)
pcs_miss <- pct_miss(air$POLLUTANT_COMPLIANCE_STATUS)
pcs_ncat <- n_cats(air$POLLUTANT_COMPLIANCE_STATUS)

# --- Duplicates ---
n_exact_dup <- sum(duplicated(air))
# How many facilities appear more than once?
air_per_fac <- air |> group_by(AFS_ID) |> summarise(n = n(), .groups = "drop")
n_multi     <- sum(air_per_fac$n > 1)
max_per_fac <- max(air_per_fac$n)
med_per_fac <- as.integer(median(air_per_fac$n))

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "AFS Air Programs")
ws <- "AFS Air Programs"

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
setColWidths(wb, ws, cols = 5:6, widths = 14)

# ---- Header block (rows 1-4) ---------------------------------------------------------------------------
# Row 1: Title
# Row 2: Description of the dataset
# Row 3: Observation and facility counts
# Row 4: Identifier columns

mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "AFS Air Programs (AIR_PROGRAM.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Program enrollments from EPA's legacy AFS system. Each row links a facility to an air ",
  "program with its classification, compliance status, and associated pollutants."),
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
writeData(wb, ws, "IDENTIFIERS: AFS_ID, PLANT_ID, AIR_PROGRAM_CODE_SUBPARTS, CHEMICAL_ABSTRACT_SERVICE_NMBR", startRow = 4)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center"),
         rows = 4, cols = 1)

# ---- Categorical table header (row 6) ------------------------------------------------------------------

cat_headers <- c("Variable", "% Missing", "# Categories", "Frequent Values", "N", "%")
writeData(wb, ws, t(cat_headers), startRow = 6, colNames = FALSE)
addStyle(wb, ws, green_header, rows = 6, cols = 1:6, gridExpand = TRUE)

# ---- Helper: write_variable -----------------------------------------------------------------------------
# Writes one variable's block into the categorical table.
# var_name  — column name (bold in col 1)
# var_desc  — plain-language description (appended below var_name in col 1)
# pct_missing — string like "12.3%" (col 2)
# n_cats    — number of distinct values (col 3)
# descs     — character vector of value labels (col 4, one per row)
# ns        — count for each value (col 5)
# pcts      — proportion for each value (col 6, formatted as %)

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

# ---- AIR_PROGRAM_CODE (rows 7-12) ----------------------------------------------------------------------
# The regulatory air program the facility is enrolled in. Top 6 values shown.

# documentation-sourced labels for air program codes
apc_code_labels <- c(
  "0" = "SIP", "1" = "FIP (SIP under federal jurisdiction)", "3" = "Non-federally reportable",
  "4" = "CFC Tracking", "6" = "PSD", "7" = "NSR", "8" = "NESHAP (Part 61)",
  "9" = "NSPS", "A" = "Acid Precipitation", "F" = "FESOP (non-Title V)",
  "I" = "Native American", "M" = "MACT (Part 63 NESHAPS)",
  "T" = "TIP (Tribal Implementation Plan)", "V" = "Title V"
)
apc_descs <- ifelse(
  as.character(apc$AIR_PROGRAM_CODE) %in% names(apc_code_labels),
  paste0(apc$AIR_PROGRAM_CODE, " - ", apc_code_labels[as.character(apc$AIR_PROGRAM_CODE)]),
  as.character(apc$AIR_PROGRAM_CODE)
)

write_variable(wb, ws, 7,
  "AIR_PROGRAM_CODE",
  "Code for the air program the facility is enrolled in (e.g., Title V, SIP, NESHAP).",
  apc_miss, apc_ncat,
  apc_descs, apc$n, apc$pct)
setRowHeights(wb, ws, rows = 7, heights = 45)

# ---- AIR_PROGRAM_STATUS (rows 13-...) -------------------------------------------------------------------
# Whether the enrollment is active, obsolete, etc. All values shown.

# documentation-sourced labels for program status (same codes as OPERATING_STATUS)
aps_labels <- c(
  "O" = "O - Operating", "C" = "C - Under Construction", "P" = "P - Planned",
  "T" = "T - Temporarily Closed", "X" = "X - Permanently Closed", "I" = "I - Seasonal",
  "D" = "D - NESHAP Demolition", "R" = "R - NESHAP Renovation",
  "S" = "S - NESHAP Spraying", "L" = "L - Landfill"
)
aps_descs <- ifelse(
  as.character(aps_all$AIR_PROGRAM_STATUS) %in% names(aps_labels),
  aps_labels[as.character(aps_all$AIR_PROGRAM_STATUS)],
  as.character(aps_all$AIR_PROGRAM_STATUS)
)

write_variable(wb, ws, 13,
  "AIR_PROGRAM_STATUS",
  "Status of the facility's enrollment in the program.",
  aps_miss, aps_ncat,
  aps_descs, aps_all$n, aps_all$pct)
setRowHeights(wb, ws, rows = 13, heights = 45)

# Figure out where the next variable starts based on how many status values there are
aps_end <- 13 + nrow(aps_all) - 1
ecc_start <- aps_end + 1

# ---- EPA_CLASSIFICATION_CODE ---------------------------------------------------------------------------
# EPA's classification of the emissions source. All values shown.

# documentation-sourced labels for EPA classification codes
ecc_labels <- c(
  "A"  = "A - Major: actual/potential emissions above major source thresholds",
  "A1" = "A1 - Major: actual/potential controlled >100 tons/year",
  "A2" = "A2 - Major: actual <100, potential uncontrolled >100 tons/year",
  "B"  = "B - Minor: potential uncontrolled <100 tons/year",
  "SM" = "SM - Synthetic minor: below all major thresholds via enforceable limits",
  "C"  = "C - Unregulated pollutant: actual/potential controlled emissions >100 tons/year",
  "UK" = "UK - Unknown",
  "ND" = "ND - Thresholds not defined"
)
ecc_descs <- ifelse(
  ecc_all$EPA_CLASSIFICATION_CODE %in% names(ecc_labels),
  ecc_labels[ecc_all$EPA_CLASSIFICATION_CODE],
  as.character(ecc_all$EPA_CLASSIFICATION_CODE)
)

write_variable(wb, ws, ecc_start,
  "EPA_CLASSIFICATION_CODE",
  "EPA source classification.",
  ecc_miss, ecc_ncat,
  ecc_descs, ecc_all$n, ecc_all$pct)
setRowHeights(wb, ws, rows = ecc_start, heights = 50)

ecc_end <- ecc_start + nrow(ecc_all) - 1
ecs_start <- ecc_end + 1

# ---- EPA_COMPLIANCE_STATUS (top 4) ----------------------------------------------------------------------
# Compliance status code assigned by EPA. Top 4 values shown.

# documentation-sourced labels for compliance status codes
ecs_labels <- c(
  "0" = "0 - Unknown", "1" = "1 - In Violation, No Schedule",
  "2" = "2 - In Compliance, Source Test", "3" = "3 - In Compliance, Inspection",
  "4" = "4 - In Compliance, Certification", "5" = "5 - Meeting Compliance Schedule",
  "6" = "6 - In Violation, Not Meeting Schedule", "7" = "7 - In Violation, Unknown re Schedule",
  "8" = "8 - No Applicable State Regulation", "9" = "9 - In Compliance, Shut Down",
  "D" = "D - HPV Violation (auto)", "E" = "E - FRV Violation (auto)",
  "F" = "F - HPV On Schedule (auto)", "G" = "G - FRV On Schedule (auto)",
  "H" = "H - In Compliance (auto)", "M" = "M - In Compliance, CEMs",
  "A" = "A - Unknown re Procedural Compliance",
  "B" = "B - In Violation re Both Emissions and Procedural Compliance",
  "C" = "C - In Compliance With Procedural Requirements",
  "P" = "P - Present, See Other Program(s)",
  "U" = "U - Unknown by Evaluation Calculation",
  "W" = "W - In Violation re Procedural Compliance",
  "Y" = "Y - Unknown re Both Emissions and Procedural Compliance"
)
ecs_descs <- ifelse(
  as.character(ecs$EPA_COMPLIANCE_STATUS) %in% names(ecs_labels),
  ecs_labels[as.character(ecs$EPA_COMPLIANCE_STATUS)],
  as.character(ecs$EPA_COMPLIANCE_STATUS)
)

write_variable(wb, ws, ecs_start,
  "EPA_COMPLIANCE_STATUS",
  "EPA compliance status code for the facility under this program.",
  ecs_miss, ecs_ncat,
  ecs_descs, ecs$n, ecs$pct)
setRowHeights(wb, ws, rows = ecs_start, heights = 45)

ecs_end <- ecs_start + nrow(ecs) - 1
pcl_start <- ecs_end + 1

# ---- POLLUTANT_CLASSIFICATION (top 4) -------------------------------------------------------------------
# Classification of the pollutant associated with the program enrollment.

# same code set as EPA_CLASSIFICATION_CODE per documentation
pcl_labels <- c(
  "A"  = "A - Major: above major source thresholds",
  "A1" = "A1 - Major: controlled >100 tons/year",
  "A2" = "A2 - Major: actual <100, potential >100 tons/year",
  "B"  = "B - Minor: potential uncontrolled <100 tons/year",
  "SM" = "SM - Synthetic minor",
  "C"  = "C - Unregulated pollutant: actual/potential controlled emissions >100 tons/year",
  "UK" = "UK - Unknown",
  "ND" = "ND - Thresholds not defined"
)
pcl_descs <- ifelse(
  as.character(pcl$POLLUTANT_CLASSIFICATION) %in% names(pcl_labels),
  pcl_labels[as.character(pcl$POLLUTANT_CLASSIFICATION)],
  as.character(pcl$POLLUTANT_CLASSIFICATION)
)

write_variable(wb, ws, pcl_start,
  "POLLUTANT_CLASSIFICATION",
  "Emissions classification at the pollutant level (same codes as EPA_CLASSIFICATION_CODE).",
  pcl_miss, pcl_ncat,
  pcl_descs, pcl$n, pcl$pct)
setRowHeights(wb, ws, rows = pcl_start, heights = 45)

pcl_end <- pcl_start + nrow(pcl) - 1
pcd_start <- pcl_end + 1

# ---- POLLUTANT_CODE ------------------------------------------------------------------------------------

write_variable(wb, ws, pcd_start,
  "POLLUTANT_CODE",
  "Code identifying the specific pollutant associated with this program enrollment.",
  pcd_miss, pcd_ncat,
  as.character(pcd$POLLUTANT_CODE), pcd$n, pcd$pct)
setRowHeights(wb, ws, rows = pcd_start, heights = 45)

pcd_end <- pcd_start + nrow(pcd) - 1
pcs_start <- pcd_end + 1

# ---- POLLUTANT_COMPLIANCE_STATUS -----------------------------------------------------------------------

pcs_descs <- ifelse(
  as.character(pcs$POLLUTANT_COMPLIANCE_STATUS) %in% names(ecs_labels),
  ecs_labels[as.character(pcs$POLLUTANT_COMPLIANCE_STATUS)],
  as.character(pcs$POLLUTANT_COMPLIANCE_STATUS)
)

write_variable(wb, ws, pcs_start,
  "POLLUTANT_COMPLIANCE_STATUS",
  "Compliance status at the pollutant level (same codes as EPA_COMPLIANCE_STATUS).",
  pcs_miss, pcs_ncat,
  pcs_descs, pcs$n, pcs$pct)
setRowHeights(wb, ws, rows = pcs_start, heights = 45)

pcs_end <- pcs_start + nrow(pcs) - 1

# ---- Categorical footnotes -----------------------------------------------------------------------------

fn1_row <- pcs_end + 2

mergeCells(wb, ws, cols = 1:6, rows = fn1_row)
writeData(wb, ws, paste0(
  "**This dataset has ~1.1M rows because each row is a facility-program-pollutant combination. ",
  "A single facility enrolled in multiple programs with multiple pollutants generates many rows. ",
  "AIR_PROGRAM_CODE '", apc$AIR_PROGRAM_CODE[1], "' is the most common program (",
  round(apc$pct[1] * 100), "% of rows)."),
  startRow = fn1_row)
addStyle(wb, ws, font12_left, rows = fn1_row, cols = 1)
setRowHeights(wb, ws, rows = fn1_row, heights = 45)

fn2_row <- fn1_row + 1

mergeCells(wb, ws, cols = 1:6, rows = fn2_row)
writeData(wb, ws, paste0(
  "**POLLUTANT_CLASSIFICATION is ", pcl_miss, " missing — not all program rows have an associated ",
  "pollutant. EPA_COMPLIANCE_STATUS encodes compliance as a single character; '",
  ecs$EPA_COMPLIANCE_STATUS[1], "' is the most common code (",
  round(ecs$pct[1] * 100), "% of rows)."),
  startRow = fn2_row)
addStyle(wb, ws, font12_left, rows = fn2_row, cols = 1)
setRowHeights(wb, ws, rows = fn2_row, heights = 35)

# ---- Duplicates section ---------------------------------------------------------------------------------

dup_header_row <- fn2_row + 2

mergeCells(wb, ws, cols = 1:6, rows = dup_header_row)
writeData(wb, ws, "DUPLICATES", startRow = dup_header_row)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = dup_header_row, cols = 1)

dup_text_row <- dup_header_row + 1

mergeCells(wb, ws, cols = 1:6, rows = dup_text_row)
writeData(wb, ws, paste0(
  "Exact duplicate rows: ", formatC(n_exact_dup, format = "d", big.mark = ","), ". ",
  "AFS_ID is not unique — each facility can be enrolled in multiple air programs ",
  "and each program can list multiple pollutants. ",
  formatC(n_multi, format = "d", big.mark = ","),
  " facilities have 2+ rows (max ", formatC(max_per_fac, format = "d", big.mark = ","),
  "; median ", med_per_fac, "). ",
  "This is by design: the table is a many-to-many mapping of facilities to programs and pollutants."),
  startRow = dup_text_row)
addStyle(wb, ws, font12_left, rows = dup_text_row, cols = 1)
setRowHeights(wb, ws, rows = dup_text_row, heights = 55)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/afs_air_program_table.xlsx"), overwrite = TRUE)
