# =========================================================================================================
# 15_publish_tables_gdrive.R   (Option C — formatting-preserving)
#
# PURPOSE
#   Publish each data-dictionary workbook in output/tables/ to Google Drive as a NATIVE Google Sheet,
#   collected in one Drive folder. Uploading an .xlsx with type = "spreadsheet" lets Google convert it,
#   which carries over most of the formatting (the green/orange section fills, bold headers, merged
#   cells, column widths) — unlike scripts/14, which mirrors values only into a single tabbed Sheet.
#   Trade-off: this produces one folder of separate Sheets (one per table), not tabs in a single document.
#   Re-running updates the same Sheets in place (no duplicates), so the folder stays current.
#
# AUTH (one more browser consent than script 14)
#   Uses the narrow `drive.file` scope — the app can only see and manage files it creates, never the rest
#   of your Drive. The first run opens a browser; tick the Google Drive permission box. The token caches in
#   .secrets/ (gitignored); runs after that are non-interactive. (This is a different scope than script 14's
#   Sheets token, so it is a separate one-time consent.)
#
# CONFIG  (config/gsheet_config.R)
#   gsheet_email     — your Google account (selects the cached token).
#   gdrive_folder_id — OPTIONAL. If set, publish into that folder. If blank/absent, the script finds or
#                      creates a folder named "CAA Data Dictionary" and prints its id to pin if you like.
#
# USAGE
#   Rscript scripts/15_publish_tables_gdrive.R          # publish/refresh
#   Set dry_run <- TRUE below to list what WOULD be published, with no auth/network.
# =========================================================================================================

library(here)

# ---- Flags ----------------------------------------------------------------------------------------------
dry_run          <- FALSE  # TRUE = list the tables that would be published; no auth, no network.
replace_existing <- FALSE  # FALSE = update Sheets in place (keeps their ids/links). TRUE = trash + re-upload
                           #         fresh each run — use only if an in-place update ever lands as an Excel
                           #         file instead of a native Sheet.
folder_name      <- "CAA Data Dictionary"

# ---- Locate the tables ----------------------------------------------------------------------------------
tables_dir <- here("output/tables")
files <- list.files(tables_dir, pattern = "_table\\.xlsx$", full.names = TRUE)
files <- sort(files[!startsWith(basename(files), "~$")])   # skip Excel lock files
if (length(files) == 0) {
  stop("No '*_table.xlsx' files in ", tables_dir,
       " — run scripts/tables/09_table-*.R (or 00_run_all.R with run_tables = TRUE) first.")
}
sheet_name <- function(f) sub("_table$", "", tools::file_path_sans_ext(basename(f)))

# ---- Dry run --------------------------------------------------------------------------------------------
if (isTRUE(dry_run)) {
  cat("DRY RUN — would publish ", length(files), " Google Sheet(s) to Drive folder '", folder_name, "':\n", sep = "")
  for (f in files) cat("  ", sheet_name(f), "  <-  ", basename(f), "\n", sep = "")
  cat("\n(no authentication or network calls made)\n")
  quit(save = "no", status = 0)
}

# ---- Load config ----------------------------------------------------------------------------------------
cfg <- here("config/gsheet_config.R")
if (!file.exists(cfg)) {
  stop("Missing config/gsheet_config.R. Copy config/gsheet_config.example.R to config/gsheet_config.R ",
       "and set gsheet_email (and optionally gdrive_folder_id). See the README.")
}
source(cfg)
if (!exists("gsheet_email")) gsheet_email <- NULL

# ---- Authenticate (drive.file scope; cached token in .secrets/) -----------------------------------------
library(googledrive)
dir.create(here(".secrets"), showWarnings = FALSE, recursive = TRUE)
options(gargle_oauth_cache = here(".secrets"), gargle_oauth_email = gsheet_email)
drive_auth(scopes = "https://www.googleapis.com/auth/drive.file")

# ---- Resolve the target folder --------------------------------------------------------------------------
if (exists("gdrive_folder_id") && nzchar(gdrive_folder_id) && !grepl("PASTE", gdrive_folder_id)) {
  folder <- as_id(gdrive_folder_id)
} else {
  hits <- drive_find(type = "folder", pattern = paste0("^", folder_name, "$"))
  folder <- if (nrow(hits) >= 1) as_id(hits$id[1]) else drive_mkdir(folder_name)
  cat("Drive folder '", folder_name, "' id: ", as.character(as_id(folder)), "\n", sep = "")
  cat("(optional: set gdrive_folder_id to this in config/gsheet_config.R to pin it)\n")
}

# ---- Publish each table as a native Google Sheet --------------------------------------------------------
for (f in files) {
  nm <- sheet_name(f)
  if (replace_existing) {
    old <- drive_ls(folder, pattern = paste0("^", nm, "$"))
    if (nrow(old) >= 1) drive_trash(old)
    drive_upload(f, path = folder, name = nm, type = "spreadsheet")
  } else {
    # drive_put = update the file of this name in the folder if it exists, else create it (converting to Sheet)
    drive_put(media = f, path = folder, name = nm, type = "spreadsheet")
  }
  cat("published:", nm, "\n")
}

cat("\nDone. Published", length(files), "formatted tables to the Drive folder '", folder_name, "'.\n", sep = "")
cat("Open Drive (https://drive.google.com) and look in that folder; Share the folder to give collaborators access.\n")
