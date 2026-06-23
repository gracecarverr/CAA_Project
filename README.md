# Data Availability and Provenance Statements, and Instructions for Replicators

> INSTRUCTIONS: This README follows the [AEA template README](https://social-science-data-editors.github.io/template_README/) for social science replication packages. This project is in the exploratory/pre-analysis phase. Sections will be updated as the project develops.

## Overview

This project uses EPA administrative data on Clean Air Act stationary source regulation to study [research question TBD]. The data cover facility characteristics, regulatory program participation, compliance monitoring, violation history, and enforcement actions for the universe of CAA-regulated stationary sources in the United States.

All code is in R. Exploratory scripts profile each dataset (CSV summaries and Excel data-dictionary workbooks); the numbered analysis pipeline (scripts `10`–`13`) builds a balanced facility-year panel of Title V electric utilities and its descriptive statistics. No paper tables have been finalized yet.

## Data Availability and Provenance Statements

### Summary of Availability

- [x] All data are publicly available.

All data used in this project are downloaded from the U.S. Environmental Protection Agency's Enforcement and Compliance History Online (ECHO) system. No restricted or confidential data are used.

### ICIS-Air Data

Data on CAA-regulated facilities, programs, compliance monitoring, violations, and enforcement actions.

- **Source:** U.S. EPA, Enforcement and Compliance History Online (ECHO), ICIS-Air module
- **URL:** https://echo.epa.gov/tools/data-downloads/icis-air-download-summary
- **Access:** Public. No registration required. Bulk CSV download.
- **Time coverage:** Current as of download date.
- **Citation:** U.S. Environmental Protection Agency. ICIS-Air Data Downloads. Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads/icis-air-download-summary

### AFS Data (Air Facility System)

Legacy data on CAA-regulated facilities, frozen as of October 17, 2014. AFS was the predecessor system to ICIS-Air.

- **Source:** U.S. EPA, Enforcement and Compliance History Online (ECHO), AFS archive
- **URL:** https://echo.epa.gov/tools/data-downloads#afs
- **Access:** Public. No registration required. Bulk CSV download.
- **Time coverage:** Frozen at October 17, 2014.
- **Citation:** U.S. Environmental Protection Agency. AFS Data Downloads. Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads#afs

### Emissions Data

Facility-level pollutant emissions from the National Emissions Inventory (NEI) and other reporting programs, accessed through ECHO.

- **Source:** U.S. EPA, Enforcement and Compliance History Online (ECHO), Combined Emissions data
- **URL:** https://echo.epa.gov/tools/data-downloads#emissions
- **Access:** Public. No registration required. Bulk CSV download.
- **Time coverage:** Multiple NEI reporting years (2008, 2011, 2014, 2017, 2020).
- **Citation:** U.S. Environmental Protection Agency. Combined Emissions Data Downloads. Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads#emissions

### Pipeline / ECHO Exporter Data

Supplementary facility-level data from ECHO.

- **Source:** U.S. EPA, Enforcement and Compliance History Online (ECHO)
- **URL:** https://echo.epa.gov/tools/data-downloads
- **Access:** Public. No registration required.
- **Citation:** U.S. Environmental Protection Agency. ECHO Data Downloads. https://echo.epa.gov/tools/data-downloads

## Dataset List

| File | Source | Notes | Provided |
|---|---|---|---|
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_FACILITIES.csv` | ICIS-Air | Facility characteristics, classification, location | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_PROGRAMS.csv` | ICIS-Air | Regulatory program participation by source | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_FCES_PCES.csv` | ICIS-Air | Compliance monitoring (inspections) | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_VIOLATION_HISTORY.csv` | ICIS-Air | Violation records (FRV and HPV) | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_FORMAL_ACTIONS.csv` | ICIS-Air | Formal enforcement actions and penalties | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_INFORMAL_ACTIONS.csv` | ICIS-Air | Informal enforcement actions | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_POLLUTANTS.csv` | ICIS-Air | Pollutant-level records | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_PROGRAM_SUBPARTS.csv` | ICIS-Air | MACT/NSPS subpart detail | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_STACK_TESTS.csv` | ICIS-Air | Stack test results | Yes |
| `data/raw/ICIS-AIR_downloads/ICIS-AIR_TITLEV_CERTS.csv` | ICIS-Air | Title V certification records | Yes |
| `data/raw/afs_downloads/AFS_FACILITIES.csv` | AFS | Facility characteristics (frozen 2014) | Yes |
| `data/raw/afs_downloads/AIR_PROGRAM.csv` | AFS | Air program records (frozen 2014) | Yes |
| `data/raw/afs_downloads/AFS_ACTIONS.csv` | AFS | Enforcement actions (frozen 2014) | Yes |
| `data/raw/afs_downloads/AFS_AIR_PRG_HIST_COMPLIANCE.csv` | AFS | Historical compliance (frozen 2014) | Yes |
| `data/raw/afs_downloads/AFS_HPV_HISTORY.csv` | AFS | HPV history (frozen 2014) | Yes |
| `data/raw/POLL_RPT_COMBINED_EMISSIONS.csv` | ECHO Emissions | Facility-level emissions, multiple NEI years | Yes |
| `data/raw/PIPELINE_CAA_00_COMPLETE.csv` | ECHO Pipeline | Supplementary facility data | Yes |
| `data/raw/ECHO_EXPORTER_HEADER.csv` | ECHO Exporter | Column headers for ECHO exporter | Yes |

## Computational Requirements

### Software Requirements

- R (version 4.x)
  - `here` (project-root-relative paths)
  - `readr`
  - `dplyr`
  - `tidyr`
  - `lubridate`
  - `ggplot2`
  - `scales`
  - `patchwork`
  - `openxlsx`

All scripts resolve file paths with `here::here()`, which anchors on the project's `.git` directory.
There is no `setwd()` to edit: run scripts with the working directory anywhere inside the repository
(opening the project in RStudio, or `cd`-ing into the repo before running, both satisfy this).

### Controlled Randomness

- [x] No pseudo-random number generator is used in this project.

### Memory, Runtime, and Storage Requirements

- **Storage:** ~2.5 GB for raw data.
- **Runtime:** Individual exploration scripts run in under 5 minutes each. The emissions-dependent scripts (`02_reclassification-signals.R`) take 1–2 minutes due to the size of the emissions file (~880 MB).
- [x] Can be run on a standard desktop/laptop.

## Description of Programs/Code

All code is in `scripts/`. Output goes to `output/`. Raw data in `data/raw/` is never modified.

### Directory Structure

```
CAA_Project/
├── data/
│   ├── raw/                      # Immutable raw downloads (never modified)
│   │   ├── ICIS-AIR_downloads/   # current ICIS-Air bulk download
│   │   ├── afs_downloads/        # legacy AFS archive (frozen 2014)
│   │   ├── wayback_snapshots/    # archived ICIS-Air snapshots (for the OIAI panel)
│   │   ├── POLL_RPT_COMBINED_EMISSIONS.csv
│   │   ├── PIPELINE_CAA_00_COMPLETE.csv
│   │   └── ECHO_EXPORTER_HEADER.csv
│   └── derived/                  # Rebuilt from code (e.g. title_v_utility_panel.csv)
├── scripts/
│   ├── 00_run_all.R              # master script — runs the pipeline end to end
│   ├── 10_oiai_reclassification_panel.R
│   ├── 11_data_quality_audit.R
│   ├── 12_title_v_utility_panel.R
│   ├── 13_panel_descriptives.R
│   ├── explore/                  # 01–09: per-dataset exploratory profiling
│   └── tables/                   # 09_table-*: data-dictionary workbooks + 10_crosscheck
├── output/
│   ├── explore/                  # exploratory CSVs by dataset
│   ├── tables/                   # data-dictionary .xlsx workbooks
│   ├── panel_descriptives/       # figures + tables from 13_panel_descriptives.R
│   └── sessionInfo.txt           # package/version record (written by 00_run_all.R)
├── docs/
└── README.md
```

All scripts resolve paths with `here::here()` (anchored on `.git`); raw data in `data/raw/` is never modified.

### Scripts

| Script | Description |
|---|---|
| `scripts/00_run_all.R` | Master script: checks dependencies, runs the pipeline, writes `sessionInfo.txt` |
| `scripts/10_oiai_reclassification_panel.R` | Tracks major/minor reclassification around the 2018 "Once In Always In" reversal across archived snapshots |
| `scripts/11_data_quality_audit.R` | Reproduces the figures in `output/data_quality_findings.md` (console report) |
| `scripts/12_title_v_utility_panel.R` | Builds the balanced Title V electric-utility panel → `data/derived/title_v_utility_panel.csv` |
| `scripts/13_panel_descriptives.R` | Descriptive statistics and figures for the panel → `output/panel_descriptives/` |
| `scripts/explore/01–09_*.R` | Per-dataset exploratory profiling (missingness, tabulations) → `output/explore/` |
| `scripts/tables/09_table-*.R` | Per-dataset data-dictionary workbooks → `output/tables/` |
| `scripts/tables/10_crosscheck-tables.R` | QA: compares regenerated workbooks against a frozen reference set |

## Instructions to Replicators

1. Download all data files from ECHO (URLs above) and place them in the appropriate subdirectories under `data/raw/` (see the Dataset List above).
2. Install the required R packages (see Software Requirements). From R:
   `install.packages(c("here","readr","dplyr","tidyr","lubridate","ggplot2","scales","patchwork","openxlsx"))`
3. Reproduce the analysis pipeline. From a terminal at the repository root, run `Rscript scripts/00_run_all.R` (or open the project in RStudio and source `scripts/00_run_all.R`). This checks dependencies, builds the derived panel `data/derived/title_v_utility_panel.csv`, regenerates the descriptive output in `output/panel_descriptives/`, and writes a version record to `output/sessionInfo.txt`.
4. Scripts can also be run individually in numeric order; each is self-contained and resolves its own paths via `here::here()` — there is no `setwd()` to edit. To also regenerate the exploratory CSVs and data-dictionary workbooks, set `run_exploration` / `run_tables` to `TRUE` near the top of `00_run_all.R`.

## Publishing the data dictionary to Google Sheets (optional)

`scripts/14_push_tables_to_gsheet.R` mirrors every workbook in `output/tables/` into a single Google Sheet, one table per tab, so collaborators can view the data dictionary online. Re-running it refreshes the Sheet, so it stays current with the local tables. (Only cell *values* are mirrored, not the spreadsheet styling — the colored sections do not transfer.)

**One-time setup** (uses OAuth; you authorize once in a browser and the token is cached for later runs):

0. Install `httpuv` first — `install.packages("httpuv")` — so the browser authorization completes automatically. Without it, googlesheets4 falls back to a manual "paste this code" flow that is easy to get wrong.
1. Create a blank Google Sheet you own and copy its id from the URL — the token between `/d/` and `/edit`: `https://docs.google.com/spreadsheets/d/<THIS_IS_THE_ID>/edit`.
2. Copy the config template and fill in your values:
   `cp config/gsheet_config.example.R config/gsheet_config.R` — then set `gsheet_id` and `gsheet_email`.
3. Authorize once **in an interactive R session** (so the browser can open and redirect back) — e.g. in RStudio or the VS Code R console, run `source("scripts/14_push_tables_to_gsheet.R")`. A browser opens; **on the consent screen, tick the "See, edit, create, and delete all your Google Sheets spreadsheets" box** (Google leaves it unchecked by default — skipping it causes a `403 ACCESS_TOKEN_SCOPE_INSUFFICIENT` error). The refresh token is then cached in `.secrets/`, and every run after that is non-interactive (including `Rscript`).

**After setup**, push with `Rscript scripts/14_push_tables_to_gsheet.R`, or set `push_to_gsheet <- TRUE` (with `run_tables <- TRUE`) near the top of `00_run_all.R` to rebuild the tables and push them in one run. To preview what would be pushed without authenticating, set `dry_run <- TRUE` near the top of the script.

### Option C — formatted Sheets in a Drive folder (`scripts/15_publish_tables_gdrive.R`)

Script 14 mirrors *values* into one tabbed Sheet. If you want the **formatting** (the colored section fills, bold headers, merged cells) to carry over, use script 15 instead: it uploads each workbook to a Google Drive folder and lets Google convert it to a native Sheet, which preserves most of the styling. The trade-off is structure — you get one folder with a separate Sheet per table, rather than tabs in a single document.

It reuses the same `config/gsheet_config.R` (just `gsheet_email`; `gdrive_folder_id` is optional — blank auto-creates a folder named "CAA Data Dictionary"). It needs a **separate one-time Drive authorization** because it uses a different, narrower scope than script 14:

1. Run `source("scripts/15_publish_tables_gdrive.R")` in an interactive R session.
2. On the consent screen, **tick the Google Drive file-access box** ("See, edit, create, and delete only the specific Google Drive files you use with this app"). The token caches in `.secrets/`.

After setup: `Rscript scripts/15_publish_tables_gdrive.R`, or `publish_gdrive <- TRUE` in `00_run_all.R`. Re-running updates the same Sheets in place (no duplicates). Google's converter approximates some styles (close, not pixel-perfect).

`config/gsheet_config.R` and `.secrets/` are gitignored — your Sheet id and OAuth token are never committed.

## List of Tables and Programs

This project is in the exploratory phase. Scripts produce summary CSVs and notes files, not final paper tables. See `output/june9notes.md` for a synthesis of exploration results.

## References

U.S. Environmental Protection Agency. *ICIS-Air Data Downloads.* Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads/icis-air-download-summary

U.S. Environmental Protection Agency. *AFS Data Downloads.* Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads#afs

U.S. Environmental Protection Agency. *Combined Emissions Data Downloads.* Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads#emissions

U.S. Environmental Protection Agency. *AFS Data Download Summary.* https://echo.epa.gov/system/files/AFS_Data_Download.pdf
