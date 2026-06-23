# =========================================================================================================
# 00_run_all.R — master script that reproduces the analysis pipeline end to end.
#
# WHAT IT DOES
#   1. Locates the project root and checks that all required R packages are installed.
#   2. Sources the analysis pipeline (scripts 10 -> 11 -> 12 -> 13) in order.
#   3. Optionally runs the exploratory and data-dictionary scripts (off by default; see flags below).
#   4. Writes a session/version record to output/sessionInfo.txt for reproducibility.
#
# HOW TO RUN
#   - From a terminal:        Rscript scripts/00_run_all.R       (run from the repository root)
#   - From RStudio:           open caa_project in RStudio and source this file.
#   This script self-locates, so `Rscript /abs/path/to/scripts/00_run_all.R` also works from anywhere.
#
# PATHS
#   Every script resolves paths with here::here(), which anchors on the project's .git directory.
#   here() only needs the working directory to be inside the repo; this script guarantees that by
#   moving the working directory to the project root before doing anything else.
# =========================================================================================================

# ---- Locate the project root ----------------------------------------------------------------------------
# Find this script's own path (works whether it is run via Rscript or sourced), then set the working
# directory to its parent's parent: scripts/00_run_all.R -> <repo root>. This makes here() resolve
# correctly even if the script was invoked by absolute path from an unrelated directory.
get_this_script_path <- function() {
  cmd <- commandArgs(trailingOnly = FALSE)
  file_flag <- grep("^--file=", cmd, value = TRUE)
  if (length(file_flag) == 1) return(normalizePath(sub("^--file=", "", file_flag)))
  if (!is.null(sys.frames()[[1]]$ofile)) return(normalizePath(sys.frames()[[1]]$ofile))  # sourced
  NA_character_
}
.script_path <- get_this_script_path()
if (!is.na(.script_path)) setwd(dirname(dirname(.script_path)))

# ---- 0. Dependency check (base R only, so it runs before any library() call) ----------------------------
required <- c("here", "readr", "dplyr", "tidyr", "lubridate",
              "ggplot2", "scales", "patchwork", "openxlsx")
missing  <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), ".\n",
       "Install them with:\n  install.packages(c(",
       paste(sprintf('"%s"', missing), collapse = ", "), "))", call. = FALSE)
}
cat("All", length(required), "required packages are installed.\n")

library(here)
cat("Project root:", here(), "\n")

# ---- Options: which optional script groups to run -------------------------------------------------------
# The analysis pipeline (10-13) always runs. The two groups below are slower and not required to
# reproduce the panel and its descriptives; flip to TRUE to regenerate them.
run_exploration <- FALSE   # scripts/explore/*       per-table profiling CSVs
run_tables      <- FALSE   # scripts/tables/09_table-*  data-dictionary .xlsx workbooks
push_to_gsheet  <- FALSE   # mirror output/tables/*.xlsx to one Google Sheet, values only (needs config)
publish_gdrive  <- FALSE   # publish output/tables/*.xlsx to a Drive folder as formatted Sheets (needs config)

# ---- Helper: source one script with a labeled banner ----------------------------------------------------
run_script <- function(rel_path) {
  cat("\n", strrep("=", 95), "\n>>> RUNNING: ", rel_path, "\n", strrep("=", 95), "\n", sep = "")
  source(here(rel_path), echo = FALSE)
}

# ---- 1. Optional: exploratory profiling -----------------------------------------------------------------
if (run_exploration) {
  for (f in sort(list.files(here("scripts/explore"), pattern = "\\.R$"))) {
    run_script(file.path("scripts/explore", f))
  }
}

# ---- 2. Optional: data-dictionary tables ----------------------------------------------------------------
if (run_tables) {
  for (f in sort(list.files(here("scripts/tables"), pattern = "^09_table.*\\.R$"))) {
    run_script(file.path("scripts/tables", f))
  }
}

# ---- 2b. Optional: mirror the tables to Google (values to one Sheet, or formatted Sheets to a folder) ---
# Wrapped in try() so missing/incomplete Google config warns but never aborts the pipeline.
if (push_to_gsheet) try(run_script("scripts/14_push_tables_to_gsheet.R"))
if (publish_gdrive) try(run_script("scripts/15_publish_tables_gdrive.R"))

# ---- 3. Analysis pipeline (required, in order) ----------------------------------------------------------
run_script("scripts/10_oiai_reclassification_panel.R")  # OIAI reclassification panel (Wayback snapshots)
run_script("scripts/11_data_quality_audit.R")           # data-quality audit (console report)
run_script("scripts/12_title_v_utility_panel.R")        # builds data/derived/title_v_utility_panel.csv
run_script("scripts/13_panel_descriptives.R")           # descriptives + figures for the panel

# ---- 4. Record the session for reproducibility ----------------------------------------------------------
dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)
writeLines(capture.output(sessionInfo()), here("output/sessionInfo.txt"))
cat("\nDone. Session and package versions written to", here("output/sessionInfo.txt"), "\n")
