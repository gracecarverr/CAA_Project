# =========================================================================================================
# 10_crosscheck-tables.R — QA check for the data-dictionary workbooks.
# Cell-by-cell compares each freshly generated output/tables/*.xlsx against a frozen reference copy in
# output/tables/backup_hardcoded/ (an earlier hand-verified version), reporting any differences. Run this
# after regenerating the 09_table-*.R workbooks to confirm a change touched formatting/paths only, not
# the numbers in the tables. Skips any table with no backup. Paths via here::here() (anchored on .git).
# =========================================================================================================

library(here)
library(openxlsx)

tables <- c("facilities_table.xlsx", "programs_table.xlsx", "violations_table.xlsx",
            "compliance_table.xlsx", "informal_actions_table.xlsx", "pollutants_table.xlsx",
            "stack_tests_table.xlsx", "formal_actions_table.xlsx")

for (tbl in tables) {
  new_path <- file.path(here("output/tables"), tbl)
  old_path <- file.path(here("output/tables/backup_hardcoded"), tbl)

  if (!file.exists(old_path)) {
    message(sprintf("SKIP %s — no backup file", tbl))
    next
  }

  new_wb <- read.xlsx(new_path, sheet = 1, colNames = FALSE, skipEmptyRows = FALSE,
                      skipEmptyCols = FALSE)
  old_wb <- read.xlsx(old_path, sheet = 1, colNames = FALSE, skipEmptyRows = FALSE,
                      skipEmptyCols = FALSE)

  max_rows <- max(nrow(new_wb), nrow(old_wb))
  max_cols <- max(ncol(new_wb), ncol(old_wb))

  diffs <- 0
  diff_details <- character(0)

  for (r in 1:max_rows) {
    for (c in 1:max_cols) {
      new_val <- if (r <= nrow(new_wb) && c <= ncol(new_wb)) new_wb[r, c] else NA
      old_val <- if (r <= nrow(old_wb) && c <= ncol(old_wb)) old_wb[r, c] else NA

      if (is.na(new_val) && is.na(old_val)) next

      match <- FALSE
      if (!is.na(new_val) && !is.na(old_val)) {
        if (new_val == old_val) {
          match <- TRUE
        } else {
          nv <- suppressWarnings(as.numeric(new_val))
          ov <- suppressWarnings(as.numeric(old_val))
          if (!is.na(nv) && !is.na(ov) && abs(nv - ov) < 0.01) {
            match <- TRUE
          }
        }
      }

      if (!match) {
        diffs <- diffs + 1
        if (diffs <= 20) {
          diff_details <- c(diff_details,
            sprintf("  Row %d, Col %d: OLD='%s' vs NEW='%s'", r + 1, c,
                    as.character(old_val), as.character(new_val)))
        }
      }
    }
  }

  if (diffs == 0) {
    message(sprintf("OK   %s — all cells match", tbl))
  } else {
    message(sprintf("DIFF %s — %d cells differ (old: %dx%d, new: %dx%d)",
                    tbl, diffs, nrow(old_wb), ncol(old_wb), nrow(new_wb), ncol(new_wb)))
    for (d in diff_details) message(d)
    if (diffs > 20) message(sprintf("  ... and %d more differences", diffs - 20))
  }
}
