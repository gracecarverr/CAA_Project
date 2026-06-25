# =========================================================================================================
# 09_table-afs-facilities.R — data-dictionary table for the legacy AFS_FACILITIES dataset.
# Writes output/tables/afs_facilities_table.xlsx. Reference tooling, not part of the analysis pipeline.
# Short object names abbreviate the column summarized. Paths via here::here() (anchored on .git).
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)
library(openxlsx)
library(readr)
library(dplyr)

# ---- Load data ------------------------------------------------------------------------------------------

# read the AFS facilities file — this is the legacy air quality database (pre-October 2014)
fac <- read_csv(here("data/raw/afs_downloads/AFS_FACILITIES.csv"), show_col_types = FALSE)
n_obs <- nrow(fac)

# count distinct facilities by AFS_ID (the primary facility identifier in this dataset)
n_fac <- n_distinct(fac$AFS_ID)

# check whether PLANT_ID and AFS_ID are 1:1 or not
n_plant <- n_distinct(fac$PLANT_ID)
id_mapping <- fac |>
  group_by(PLANT_ID) |>
  summarise(n_afs = n_distinct(AFS_ID), .groups = "drop")
plant_multi <- id_mapping |> filter(n_afs > 1) |> nrow()
id_one_to_one <- (plant_multi == 0)

# ---- Helper functions -----------------------------------------------------------------------------------

# returns the percent of values that are NA as a formatted string
pct_miss <- function(x) paste0(round(sum(is.na(x)) / length(x) * 100, 1), "%")

# returns the count of distinct values (including NA as its own category)
n_cats   <- function(x) n_distinct(x, na.rm = TRUE)  # exclude NA — not a category; missingness is reported separately

# returns a tibble of the top n most frequent values with counts and percents
top_vals <- function(df, var, n_top = 4) {
  df |>
    filter(!is.na({{ var }})) |>
    count({{ var }}) |>
    arrange(desc(n)) |>
    slice_head(n = n_top) |>
    mutate(pct = n / nrow(df))
}

# ---- Compute statistics ---------------------------------------------------------------------------------

# STATE — top 4 states by number of facilities
st <- top_vals(fac, STATE, 4)
st_miss <- pct_miss(fac$STATE)
st_ncat <- n_cats(fac$STATE)

# EPA_REGION — top 4 EPA administrative regions
epa <- top_vals(fac, EPA_REGION, 4)
epa_miss <- pct_miss(fac$EPA_REGION)
epa_ncat <- n_cats(fac$EPA_REGION)

# EPA_CLASSIFICATION_CODE — all values (major/minor/synthetic minor classification)
ecc_all <- fac |> filter(!is.na(EPA_CLASSIFICATION_CODE)) |>
  count(EPA_CLASSIFICATION_CODE) |> arrange(desc(n)) |>
  mutate(pct = n / n_obs)
ecc_miss <- pct_miss(fac$EPA_CLASSIFICATION_CODE)
ecc_ncat <- n_cats(fac$EPA_CLASSIFICATION_CODE)

# OPERATING_STATUS — all values
os_all <- fac |> filter(!is.na(OPERATING_STATUS)) |>
  count(OPERATING_STATUS) |> arrange(desc(n)) |>
  mutate(pct = n / n_obs)
os_miss <- pct_miss(fac$OPERATING_STATUS)
os_ncat <- n_cats(fac$OPERATING_STATUS)

# EPA_COMPLIANCE_STATUS — top 4 values
ecs <- top_vals(fac, EPA_COMPLIANCE_STATUS, 4)
ecs_miss <- pct_miss(fac$EPA_COMPLIANCE_STATUS)
ecs_ncat <- n_cats(fac$EPA_COMPLIANCE_STATUS)

# CURRENT_HPV — all values
hpv_all <- fac |> filter(!is.na(CURRENT_HPV)) |>
  count(CURRENT_HPV) |> arrange(desc(n)) |>
  mutate(pct = n / n_obs)
hpv_miss <- pct_miss(fac$CURRENT_HPV)
hpv_ncat <- n_cats(fac$CURRENT_HPV)

# FEDERALLY_REPORTABLE — all values
fr_all <- fac |> filter(!is.na(FEDERALLY_REPORTABLE)) |>
  count(FEDERALLY_REPORTABLE) |> arrange(desc(n)) |>
  mutate(pct = n / n_obs)
fr_miss <- pct_miss(fac$FEDERALLY_REPORTABLE)
fr_ncat <- n_cats(fac$FEDERALLY_REPORTABLE)

# PRIMARY_SIC_CODE — top 4 values
sic <- top_vals(fac, PRIMARY_SIC_CODE, 4)
sic_miss <- pct_miss(fac$PRIMARY_SIC_CODE)
sic_ncat <- n_cats(fac$PRIMARY_SIC_CODE)

# free-text fields — just compute missingness for the note at the bottom
ft_miss <- c(
  PLANT_NAME = pct_miss(fac$PLANT_NAME),
  PLANT_STREET_ADDRESS = pct_miss(fac$PLANT_STREET_ADDRESS),
  PLANT_CITY = pct_miss(fac$PLANT_CITY),
  PLANT_COUNTY = pct_miss(fac$PLANT_COUNTY),
  ZIP_CODE = pct_miss(fac$ZIP_CODE)
)

# ---- Duplicates stats -----------------------------------------------------------------------------------

# exact duplicate rows (every column identical)
n_exact_dup <- sum(duplicated(fac))

# check whether AFS_ID is unique per row or has duplicates
afs_dup_tbl <- fac |> group_by(AFS_ID) |> summarise(n = n(), .groups = "drop")
n_afs_multi <- afs_dup_tbl |> filter(n > 1) |> nrow()
max_afs_dup <- max(afs_dup_tbl$n)

# facilities per state — max and median for the distribution note
state_dist <- fac |>
  filter(!is.na(STATE)) |>
  group_by(STATE) |>
  summarise(n = n(), .groups = "drop")
max_state <- state_dist |> slice_max(n, n = 1)
median_state <- median(state_dist$n)

# ---- Create workbook ------------------------------------------------------------------------------------

wb <- createWorkbook()
addWorksheet(wb, "AFS Facilities")
ws <- "AFS Facilities"

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
setColWidths(wb, ws, cols = 4, widths = 55)
setColWidths(wb, ws, cols = 5:6, widths = 14)

# ---- Header block (rows 1-4) ---------------------------------------------------------------------------

# row 1: title
mergeCells(wb, ws, cols = 1:6, rows = 1)
writeData(wb, ws, "AFS Facilities (AFS_FACILITIES.csv)", startRow = 1)
addStyle(wb, ws, font_title, rows = 1, cols = 1)
setRowHeights(wb, ws, rows = 1, heights = 25)

# row 2: description of what AFS is
mergeCells(wb, ws, cols = 1:6, rows = 2)
writeData(wb, ws, paste0(
  "Air Facility System (AFS) — EPA's legacy air quality compliance database, ",
  "replaced by ICIS-Air in October 2014. Each row is one regulated air pollution source."),
  startRow = 2)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 2, cols = 1)
setRowHeights(wb, ws, rows = 2, heights = 40)

# row 3: observation and facility counts
mergeCells(wb, ws, cols = 1:6, rows = 3)
writeData(wb, ws, paste0("OBSERVATIONS: ", formatC(n_obs, format = "d", big.mark = ","),
                          "  DISTINCT FACILITIES (AFS_ID): ",
                          formatC(n_fac, format = "d", big.mark = ",")),
          startRow = 3)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "center"), rows = 3, cols = 1)

# row 4: identifiers
mergeCells(wb, ws, cols = 1:6, rows = 4)
writeData(wb, ws, "IDENTIFIERS: PLANT_ID, AFS_ID, STATE_NUMBER", startRow = 4)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, halign = "center",
                              wrapText = TRUE), rows = 4, cols = 1)
setRowHeights(wb, ws, rows = 4, heights = 30)

# ---- Categorical table header (row 6) ------------------------------------------------------------------

# green header row for the variable summary table
cat_headers <- c("Variable", "% Missing", "# Categories", "Frequent Values", "N", "%")
writeData(wb, ws, t(cat_headers), startRow = 6, colNames = FALSE)
addStyle(wb, ws, green_header, rows = 6, cols = 1:6, gridExpand = TRUE)

# ---- Helper function ------------------------------------------------------------------------------------

# writes one variable block into the spreadsheet: name, missingness, category count, and top values
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

# ---- STATE (rows 7-10) ---------------------------------------------------------------------------------

# look up full state names for the top 4 state codes
state_names <- c(AL="Alabama",AK="Alaska",AZ="Arizona",AR="Arkansas",CA="California",
  CO="Colorado",CT="Connecticut",DE="Delaware",FL="Florida",GA="Georgia",HI="Hawaii",
  ID="Idaho",IL="Illinois",IN="Indiana",IA="Iowa",KS="Kansas",KY="Kentucky",LA="Louisiana",
  ME="Maine",MD="Maryland",MA="Massachusetts",MI="Michigan",MN="Minnesota",MS="Mississippi",
  MO="Missouri",MT="Montana",NE="Nebraska",NV="Nevada",NH="New Hampshire",NJ="New Jersey",
  NM="New Mexico",NY="New York",NC="North Carolina",ND="North Dakota",OH="Ohio",OK="Oklahoma",
  OR="Oregon",PA="Pennsylvania",RI="Rhode Island",SC="South Carolina",SD="South Dakota",
  TN="Tennessee",TX="Texas",UT="Utah",VT="Vermont",VA="Virginia",WA="Washington",
  WV="West Virginia",WI="Wisconsin",WY="Wyoming",DC="District of Columbia",
  PR="Puerto Rico",VI="Virgin Islands",GU="Guam",AS="American Samoa",MP="Northern Mariana Islands")
st_descs <- paste0(st$STATE, " - ", state_names[st$STATE])

write_variable(wb, ws, 7,
  "STATE",
  "U.S. state or territory where the facility is located.",
  st_miss, st_ncat,
  st_descs,
  st$n,
  st$pct)
setRowHeights(wb, ws, rows = 7, heights = 40)

# ---- EPA_REGION (rows 11-14) ---------------------------------------------------------------------------

# label each EPA region with the states it covers
epa_labels <- c(
  "01" = "New England (CT, ME, MA, NH, RI, VT)",
  "02" = "NY/NJ (NY, NJ, PR, VI)",
  "03" = "Mid-Atlantic (DE, DC, MD, PA, VA, WV)",
  "04" = "Southeast (AL, FL, GA, KY, MS, NC, SC, TN)",
  "05" = "Great Lakes (IL, IN, MI, MN, OH, WI)",
  "06" = "South Central (TX, NM, OK, AR, LA)",
  "07" = "Central (IA, KS, MO, NE)",
  "08" = "Mountain (CO, MT, ND, SD, UT, WY)",
  "09" = "Pacific SW (AZ, CA, HI, NV, GU, AS)",
  "10" = "Pacific NW (AK, ID, OR, WA)"
)
# use the raw values as-is; look up labels where available
epa_descs <- ifelse(
  as.character(epa$EPA_REGION) %in% names(epa_labels),
  paste0(epa$EPA_REGION, " - ", epa_labels[as.character(epa$EPA_REGION)]),
  as.character(epa$EPA_REGION)
)

write_variable(wb, ws, 11,
  "EPA_REGION",
  "EPA administrative region (1-10) overseeing the facility.",
  epa_miss, epa_ncat,
  epa_descs,
  epa$n,
  epa$pct)
setRowHeights(wb, ws, rows = 11, heights = 50)

# ---- EPA_CLASSIFICATION_CODE (rows 15-...) --------------------------------------------------------------

# show all values for the major/minor/synthetic minor classification
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

write_variable(wb, ws, 15,
  "EPA_CLASSIFICATION_CODE",
  "Emissions classification (major/minor/synthetic minor).",
  ecc_miss, ecc_ncat,
  ecc_descs,
  ecc_all$n,
  ecc_all$pct)
setRowHeights(wb, ws, rows = 15, heights = 45)

# figure out where the next variable starts (depends on how many classification codes exist)
next_row <- 15 + nrow(ecc_all)

# ---- OPERATING_STATUS (all values) ----------------------------------------------------------------------

# documentation-sourced labels for operating status codes
os_labels <- c(
  "O" = "O - Operating",
  "C" = "C - Under Construction",
  "P" = "P - Planned",
  "T" = "T - Temporarily Closed",
  "X" = "X - Permanently Closed",
  "I" = "I - Seasonal",
  "D" = "D - NESHAP Demolition",
  "R" = "R - NESHAP Renovation",
  "S" = "S - NESHAP Spraying",
  "L" = "L - Landfill"
)
os_descs <- ifelse(
  os_all$OPERATING_STATUS %in% names(os_labels),
  os_labels[os_all$OPERATING_STATUS],
  as.character(os_all$OPERATING_STATUS)
)

write_variable(wb, ws, next_row,
  "OPERATING_STATUS",
  "Current operating status of the facility.",
  os_miss, os_ncat,
  os_descs,
  os_all$n,
  os_all$pct)
setRowHeights(wb, ws, rows = next_row, heights = 40)

next_row <- next_row + nrow(os_all)

# ---- EPA_COMPLIANCE_STATUS (top 4) ----------------------------------------------------------------------

# documentation-sourced labels for EPA compliance status codes
ecs_labels <- c(
  "0" = "0 - Unknown",
  "1" = "1 - In Violation, No Schedule",
  "2" = "2 - In Compliance, Source Test",
  "3" = "3 - In Compliance, Inspection",
  "4" = "4 - In Compliance, Certification",
  "5" = "5 - Meeting Compliance Schedule",
  "6" = "6 - In Violation, Not Meeting Schedule",
  "7" = "7 - In Violation, Unknown re Schedule",
  "8" = "8 - No Applicable State Regulation",
  "9" = "9 - In Compliance, Shut Down",
  "D" = "D - HPV Violation (auto)",
  "E" = "E - FRV Violation (auto)",
  "F" = "F - HPV On Schedule (auto)",
  "G" = "G - FRV On Schedule (auto)",
  "H" = "H - In Compliance (auto)",
  "M" = "M - In Compliance, CEMs",
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

write_variable(wb, ws, next_row,
  "EPA_COMPLIANCE_STATUS",
  "EPA compliance status code for the facility.",
  ecs_miss, ecs_ncat,
  ecs_descs,
  ecs$n,
  ecs$pct)
setRowHeights(wb, ws, rows = next_row, heights = 40)

next_row <- next_row + nrow(ecs)

# ---- CURRENT_HPV (all values) ---------------------------------------------------------------------------

# documentation-sourced labels for HPV status codes
hpv_labels <- c(
  "S" = "S - Unaddressed, state/local lead",
  "T" = "T - Addressed, state lead",
  "E" = "E - Unaddressed, EPA lead",
  "F" = "F - Addressed, EPA lead",
  "B" = "B - Unaddressed, shared lead",
  "C" = "C - Addressed, shared lead",
  "X" = "X - Unaddressed, lead unassigned"
)
hpv_descs <- ifelse(
  hpv_all$CURRENT_HPV %in% names(hpv_labels),
  hpv_labels[hpv_all$CURRENT_HPV],
  as.character(hpv_all$CURRENT_HPV)
)

write_variable(wb, ws, next_row,
  "CURRENT_HPV",
  "Current high priority violation status.",
  hpv_miss, hpv_ncat,
  hpv_descs,
  hpv_all$n,
  hpv_all$pct)
setRowHeights(wb, ws, rows = next_row, heights = 40)

next_row <- next_row + nrow(hpv_all)

# ---- FEDERALLY_REPORTABLE (all values) ------------------------------------------------------------------

write_variable(wb, ws, next_row,
  "FEDERALLY_REPORTABLE",
  "Whether the facility must report to the federal EPA system.",
  fr_miss, fr_ncat,
  as.character(fr_all$FEDERALLY_REPORTABLE),
  fr_all$n,
  fr_all$pct)
setRowHeights(wb, ws, rows = next_row, heights = 40)

next_row <- next_row + nrow(fr_all)

# ---- PRIMARY_SIC_CODE (top 4) ---------------------------------------------------------------------------

write_variable(wb, ws, next_row,
  "PRIMARY_SIC_CODE",
  "Primary Standard Industrial Classification code for the facility.",
  sic_miss, sic_ncat,
  as.character(sic$PRIMARY_SIC_CODE),
  sic$n,
  sic$pct)
setRowHeights(wb, ws, rows = next_row, heights = 45)

next_row <- next_row + nrow(sic)

# ---- Free-text location fields note ---------------------------------------------------------------------

# skip a row, then note the missingness for text fields we did not tabulate
next_row <- next_row + 1

mergeCells(wb, ws, cols = 1:6, rows = next_row)
writeData(wb, ws, paste0(
  "FREE-TEXT FIELDS (not tabulated): PLANT_NAME (", ft_miss["PLANT_NAME"], " missing), ",
  "PLANT_STREET_ADDRESS (", ft_miss["PLANT_STREET_ADDRESS"], " missing), ",
  "PLANT_CITY (", ft_miss["PLANT_CITY"], " missing), ",
  "PLANT_COUNTY (", ft_miss["PLANT_COUNTY"], " missing), ",
  "ZIP_CODE (", ft_miss["ZIP_CODE"], " missing). ",
  "Also not tabulated: SECONDARY_SIC_CODE (", pct_miss(fac$SECONDARY_SIC_CODE), " missing), ",
  "NAICS_CODE (", pct_miss(fac$NAICS_CODE), " missing), ",
  "LOCAL_CONTROL_REGION (", pct_miss(fac$LOCAL_CONTROL_REGION), " missing), ",
  "STATE_COMPLIANCE_STATUS (", pct_miss(fac$STATE_COMPLIANCE_STATUS), " missing), ",
  "AFS_GOV_FACILITY_CODE (", pct_miss(fac$AFS_GOV_FACILITY_CODE), " missing)."),
  startRow = next_row)
addStyle(wb, ws, font12_left, rows = next_row, cols = 1)
setRowHeights(wb, ws, rows = next_row, heights = 50)

# ---- Footnotes ------------------------------------------------------------------------------------------

# footnote 1: explain the PLANT_ID / AFS_ID relationship
next_row <- next_row + 2

mergeCells(wb, ws, cols = 1:6, rows = next_row)
if (id_one_to_one) {
  id_note <- paste0(
    "PLANT_ID and AFS_ID have a 1:1 mapping — every PLANT_ID corresponds to exactly one AFS_ID. ",
    "There are ", formatC(n_plant, format = "d", big.mark = ","), " distinct PLANT_IDs and ",
    formatC(n_fac, format = "d", big.mark = ","), " distinct AFS_IDs.")
} else {
  id_note <- paste0(
    "PLANT_ID and AFS_ID are NOT 1:1. There are ",
    formatC(n_plant, format = "d", big.mark = ","), " distinct PLANT_IDs vs. ",
    formatC(n_fac, format = "d", big.mark = ","), " distinct AFS_IDs. ",
    formatC(plant_multi, format = "d", big.mark = ","),
    " PLANT_IDs map to more than one AFS_ID.")
}
writeData(wb, ws, paste0("**IDENTIFIERS: ", id_note), startRow = next_row)
addStyle(wb, ws, font12_left, rows = next_row, cols = 1)
setRowHeights(wb, ws, rows = next_row, heights = 40)

# footnote 2: note the top SIC codes (raw codes only — not looking up industry names)
next_row <- next_row + 1

mergeCells(wb, ws, cols = 1:6, rows = next_row)
writeData(wb, ws, paste0(
  "**Top PRIMARY_SIC_CODEs: ",
  paste0(sic$PRIMARY_SIC_CODE, " (n=", formatC(sic$n, format = "d", big.mark = ","), ")",
         collapse = ", "),
  ". SIC codes are 4-digit industry classifiers; look up at https://www.osha.gov/data/sic-manual."),
  startRow = next_row)
addStyle(wb, ws, font12_left, rows = next_row, cols = 1)
setRowHeights(wb, ws, rows = next_row, heights = 30)

# ---- Duplicates section ---------------------------------------------------------------------------------

next_row <- next_row + 2

# section header
mergeCells(wb, ws, cols = 1:6, rows = next_row)
writeData(wb, ws, "DUPLICATES", startRow = next_row)
addStyle(wb, ws, createStyle(fontName = "Calibri", fontSize = 12, textDecoration = "bold",
                              halign = "left"), rows = next_row, cols = 1)

next_row <- next_row + 1

# exact duplicates and AFS_ID uniqueness
if (n_afs_multi == 0) {
  afs_dup_note <- "AFS_ID is unique (one row per facility)."
} else {
  afs_dup_note <- paste0(
    formatC(n_afs_multi, format = "d", big.mark = ","),
    " AFS_IDs appear in more than one row (max ", max_afs_dup, " rows per AFS_ID).")
}

mergeCells(wb, ws, cols = 1:6, rows = next_row)
writeData(wb, ws, paste0(
  "Exact duplicate rows: ", formatC(n_exact_dup, format = "d", big.mark = ","), ". ",
  afs_dup_note),
  startRow = next_row)
addStyle(wb, ws, font12_left, rows = next_row, cols = 1)
setRowHeights(wb, ws, rows = next_row, heights = 30)

# facilities per state distribution
next_row <- next_row + 1

mergeCells(wb, ws, cols = 1:6, rows = next_row)
writeData(wb, ws, paste0(
  "Facilities per state: max = ", formatC(max_state$n, format = "d", big.mark = ","),
  " (", max_state$STATE, "), median = ",
  formatC(median_state, format = "d", big.mark = ","), "."),
  startRow = next_row)
addStyle(wb, ws, font12_left, rows = next_row, cols = 1)
setRowHeights(wb, ws, rows = next_row, heights = 25)

# ---- Save ----------------------------------------------------------------------------------------------

dir.create(here("output/tables"), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, here("output/tables/afs_facilities_table.xlsx"), overwrite = TRUE)
