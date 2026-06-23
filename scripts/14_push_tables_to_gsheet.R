# =========================================================================================================
# 14_push_tables_to_gsheet.R
#
# PURPOSE
#   Mirror the data-dictionary workbooks in output/tables/ into ONE Google Sheet, with each table on its
#   own tab. Running this re-pushes every table, so the Sheet always reflects the latest output — i.e.
#   "automatic update" means "updates whenever this script runs" (e.g. via 00_run_all.R after the tables
#   are regenerated). A static .xlsx in Drive does NOT live-update a Sheet; this push is what keeps it current.
#
# HOW IT WORKS
#   Each workbook is read back as a plain cell grid (openxlsx::read.xlsx(colNames = FALSE) — the same call
#   tables/10_crosscheck-tables.R uses) and written verbatim into the matching tab. This mirrors the table's
#   own header/footnote rows exactly, with no re-derivation of data frames and no edits to the 17 table scripts.
#   NOTE: only cell *values* are mirrored, not the xlsx styling (the green/orange sections do not transfer).
#
# AUTH (one-time, OAuth with a cached token)
#   First run opens a browser to authorize; the refresh token is cached in .secrets/ (gitignored), so every
#   run after that is non-interactive. See the README section "Publishing the data dictionary to Google Sheets".
#
# CONFIG
#   Copy config/gsheet_config.example.R to config/gsheet_config.R (gitignored) and set gsheet_id + gsheet_email.
#
# USAGE
#   Rscript scripts/14_push_tables_to_gsheet.R          # push to Google
#   Set dry_run 1<- TRUE below (or run interactively) to list what WOULD be pushed, with no auth/network.
# =========================================================================================================

library(here)
library(openxlsx)

# ---- Flags ----------------------------------------------------------------------------------------------
dry_run <- FALSE   # TRUE = read every table and print the tab names/dims that would be pushed; no network.

# ---- Locate the tables ----------------------------------------------------------------------------------
tables_dir <- here("output/tables")
files <- list.files(tables_dir, pattern = "_table\\.xlsx$", full.names = TRUE)
files <- files[!startsWith(basename(files), "~$")]   # skip Excel lock files (~$name.xlsx)
files <- sort(files)
if (length(files) == 0) {
  stop("No '*_table.xlsx' files in ", tables_dir,
       " — run the scripts/tables/09_table-*.R scripts (or 00_run_all.R with run_tables = TRUE) first.")
}

# tab name from filename: "facilities_table.xlsx" -> "facilities"
tab_name <- function(f) sub("_table$", "", tools::file_path_sans_ext(basename(f)))

# read one workbook as a headerless cell grid (empty cells come back as NA -> written as blank cells)
read_grid <- function(f) {
  openxlsx::read.xlsx(f, sheet = 1, colNames = FALSE,
                      skipEmptyRows = FALSE, skipEmptyCols = FALSE)
}

# ---- Dry run: verify the read/assemble path with no credentials -----------------------------------------
if (isTRUE(dry_run)) {
  cat("DRY RUN — would push", length(files), "tab(s) to Google Sheets:\n")
  for (f in files) {
    g <- read_grid(f)
    cat(sprintf("  %-22s %d x %d\n", tab_name(f), nrow(g), ncol(g)))
  }
  cat("\n(no authentication or network calls made)\n")
  quit(save = "no", status = 0)
}

# ---- Load config ----------------------------------------------------------------------------------------
cfg <- here("config/gsheet_config.R")
if (!file.exists(cfg)) {
  stop("Missing config/gsheet_config.R.\n",
       "  Copy config/gsheet_config.example.R to config/gsheet_config.R and fill in your\n",
       "  Google Sheet id and email. See the README: 'Publishing the data dictionary to Google Sheets'.")
}
source(cfg)  # defines gsheet_id and gsheet_email
if (!exists("gsheet_id") || !nzchar(gsheet_id) || grepl("PASTE", gsheet_id)) {
  stop("gsheet_id is not set in config/gsheet_config.R (still the placeholder).")
}
if (!exists("gsheet_email")) gsheet_email <- NULL

# ---- Authenticate (cached OAuth token in .secrets/) -----------------------------------------------------
library(googlesheets4)
dir.create(here(".secrets"), showWarnings = FALSE, recursive = TRUE)
options(gargle_oauth_cache = here(".secrets"), gargle_oauth_email = gsheet_email)
gs4_auth()   # first run: browser authorization; thereafter: silent from the cached token

ss <- as_sheets_id(gsheet_id)
existing <- sheet_names(ss)

# ---- Push each table to its tab -------------------------------------------------------------------------
pushed <- character(0)
for (f in files) {
  tab <- tab_name(f)
  g   <- read_grid(f)
  if (!(tab %in% existing)) {
    sheet_add(ss, sheet = tab)
    existing <- c(existing, tab)
  }
  try(range_clear(ss, sheet = tab), silent = TRUE)   # wipe stale cells (whole sheet) before rewriting
  range_write(ss, data = g, sheet = tab, range = "A1", col_names = FALSE, reformat = FALSE)
  pushed <- c(pushed, tab)
  cat(sprintf("pushed: %-22s (%d x %d)\n", tab, nrow(g), ncol(g)))
}

# ---- Remove the default empty 'Sheet1' a blank Google Sheet ships with ----------------------------------
leftover <- setdiff(sheet_names(ss), pushed)
for (lo in leftover) {
  if (lo %in% c("Sheet1", "Sheet 1")) try(sheet_delete(ss, sheet = lo), silent = TRUE)
}

cat("\nDone. Pushed", length(pushed), "tables to the Google Sheet.\n")
cat("View: https://docs.google.com/spreadsheets/d/", as.character(ss), "/edit\n", sep = "")
