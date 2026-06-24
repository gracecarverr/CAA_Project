# Clean Air Act Administrative Data Project

This repository contains exploratory R code and reference materials for studying U.S. EPA Clean Air Act (CAA) stationary-source regulation. It works with current ICIS-Air records, the legacy Air Facility System (AFS), ECHO pipeline and emissions exports, and Facility Registry Service (FRS) identifiers.

The repository is not yet a finished replication package or a final analysis. Its current products are:

- exploratory summaries of the major ICIS-Air datasets;
- formatted Excel data dictionaries for ICIS-Air, AFS, emissions, and pipeline files;
- an AFS-to-ICIS-Air facility crosswalk built through FRS; and
- a balanced 2015–2025 facility-year skeleton for major Title V electric utilities.

Raw EPA downloads are intentionally excluded from Git because they are large. Generated summaries, reference PDFs, and the current derived panel files are tracked.

## Quick start

### 1. Install R packages

Use R 4.x and install the packages used across the repository:

```r
install.packages(c(
  "here", "readr", "dplyr", "tidyr", "lubridate",
  "ggplot2", "scales", "patchwork", "openxlsx"
))
```

All active scripts use `here::here()` to resolve paths from the repository root. Run them from anywhere inside the cloned repository; no `setwd()` edits are needed.

### 2. Add the raw data

Place unzipped EPA files under `data/raw/` using the layout below. These files are ignored by Git and must be downloaded separately.

```text
data/raw/
├── ICIS-AIR_downloads/
│   ├── ICIS-AIR_FACILITIES.csv
│   ├── ICIS-AIR_FCES_PCES.csv
│   ├── ICIS-AIR_FORMAL_ACTIONS.csv
│   ├── ICIS-AIR_INFORMAL_ACTIONS.csv
│   ├── ICIS-AIR_POLLUTANTS.csv
│   ├── ICIS-AIR_PROGRAMS.csv
│   ├── ICIS-AIR_PROGRAM_SUBPARTS.csv
│   ├── ICIS-AIR_STACK_TESTS.csv
│   ├── ICIS-AIR_TITLEV_CERTS.csv
│   └── ICIS-AIR_VIOLATION_HISTORY.csv
├── afs_downloads/
│   ├── AFS_ACTIONS.csv
│   ├── AFS_AIR_PRG_HIST_COMPLIANCE.csv
│   ├── AFS_FACILITIES.csv
│   ├── AFS_HPV_HISTORY.csv
│   └── AIR_PROGRAM.csv
├── PIPELINE_CAA_00_COMPLETE.csv
└── POLL_RPT_COMBINED_EMISSIONS.csv
```

Primary download pages:

- [ICIS-Air downloads](https://echo.epa.gov/tools/data-downloads/icis-air-download-summary)
- [ECHO data downloads, including AFS and emissions](https://echo.epa.gov/tools/data-downloads)
- [FRS downloads](https://echo.epa.gov/tools/data-downloads/frs-download-summary)

Historical ICIS-Air snapshots may also be stored in `data/raw/wayback_snapshots/`. They are present in the working data archive but are not used by the active scripts described below.

### 3. Run the desired workflow

Run the dependency check and save an R session record:

```bash
Rscript scripts/00_run_all.R
```

By default, `00_run_all.R` does not rebuild the slower exploratory or Excel outputs. Set `run_exploration` and/or `run_tables` to `TRUE` near the top of that script to run those groups.

Build the current Title V electric-utility panel skeleton separately:

```bash
Rscript scripts/01_titlev_utility_panel_skeleton.R
```

Individual scripts can also be run directly, for example:

```bash
Rscript scripts/explore/05_explore-formal-actions.R
Rscript scripts/tables/09_table-formal-actions.R
```

## Repository guide

| Folder | What is there | How to use it |
|---|---|---|
| `data/raw/` | Local, immutable EPA downloads. The contents are ignored by Git. | Download and unzip source data here using the filenames above. Scripts read from this folder but should never modify it. |
| `data/frs_downloads/` | Large local FRS files, also ignored by Git. | Put `FRS_PROGRAM_LINKS.csv` here before running `scripts/explore/10_frs-crosswalk.R`. |
| `data/derived/` | Analysis-ready files created from raw inputs. | Read these in later analysis scripts. Rebuild the Title V files with `scripts/01_titlev_utility_panel_skeleton.R`; do not edit generated CSVs by hand. |
| `scripts/` | Entry points for reproducibility and the current panel build. | Start with `00_run_all.R`; run `01_titlev_utility_panel_skeleton.R` independently for the utility panel. |
| `scripts/explore/` | Dataset-specific profiling and the FRS crosswalk. | Run individual scripts while learning or checking a raw dataset, or enable `run_exploration` in `00_run_all.R`. Outputs go to `output/explore/`. |
| `scripts/tables/` | Builders for formatted Excel data dictionaries plus a workbook cross-check. | Run an individual `09_table-*.R` file or enable `run_tables` in `00_run_all.R`. Run `10_crosscheck-tables.R` afterward to compare supported workbooks with frozen references. |
| `scripts/plots/` | Reserved for plot-building code. | Currently empty; the tracked files in `output/plots/` are historical outputs and do not have active generator scripts here. |
| `output/explore/` | CSV summaries, tabulations, missingness checks, notes, and FRS crosswalk outputs. | Inspect these for data structure and quality findings. They are descriptive outputs, not final research results. |
| `output/tables/` | Generated `.xlsx` data dictionaries. | Open these for compact descriptions of raw-table fields and distributions. `backup_hardcoded/` contains frozen, hand-checked workbooks used by the cross-check script. |
| `output/plots/` | Existing diagnostic figures. | Treat these as historical artifacts unless and until their generating scripts are restored. |
| `output/retired/` | Superseded exploratory summaries and synthesis notes. | Use only for project history or comparison. Do not treat this folder as the current pipeline. |
| `docs/clean_air_act_info/` | PDF overviews of the CAA and EPA emissions programs. | Use as background reading on the regulatory setting and source programs. |
| `docs/data_information/data_briefs/` | Short PDF briefs on ICIS-Air and pipeline data. | Use for dataset orientation before working with the raw files. |
| `docs/data_information/data_dictionaries/` | PDF data dictionaries for AFS, ICIS-Air, and pipeline data. | Use as static reference documentation; the Excel summaries in `output/tables/` are more dataset-specific. |
| `docs/literature/` | Project literature, currently including Shimshack (2014). | Use for research context. This is not an exhaustive bibliography. |

The repository also contains a local `.secrets/` directory for credentials used outside the active scripts. It is ignored by Git and should never be committed.

## Active scripts and outputs

### Project runner

`scripts/00_run_all.R`

- checks that the declared R packages are installed;
- optionally runs every script in `scripts/explore/`;
- optionally runs every `scripts/tables/09_table-*.R` builder; and
- writes `output/sessionInfo.txt`.

The optional groups are off by default. The runner does not call the Title V panel script or the table cross-check.

### Title V electric-utility panel

`scripts/01_titlev_utility_panel_skeleton.R`

This standalone script identifies major-emissions electric utilities using NAICS `2211` or SIC `4911`, then keeps facilities with at least one recorded regulatory interaction in every year from 2015 through 2025. Interactions include evaluations, violations, formal or informal actions, and Title V certifications.

It writes:

- `data/derived/titlev_utility_panel_skeleton.csv`: one row per retained facility-year, with activity flags;
- `data/derived/titlev_utility_panel_facilities.csv`: one row per retained facility, with attributes and activity totals.

The script builds a panel scaffold only. It does not yet construct final treatment, outcome, emissions, penalty, or violation-status variables. Its sample definition can be changed through `YEARS`, `NAICS_REGEX`, `SIC_CODES`, and `TITLEV_DEF` near the top of the file.

`data/derived/pipeline_sample_rows.csv` is a small checked-in sample of the pipeline export; it is not generated by the panel script.

### Exploratory profiles

| Script | Main input | Output folder |
|---|---|---|
| `01_explore-facilities.R` | `ICIS-AIR_FACILITIES.csv` | `output/explore/facilities/` |
| `02_explore-programs.R` | Programs and facilities | `output/explore/programs/` |
| `03_explore-violations.R` | Violation history and facilities | `output/explore/violations/` |
| `04_explore-compliance.R` | FCE/PCE evaluations and facilities | `output/explore/compliance/` |
| `05_explore-formal-actions.R` | Formal actions and facilities | `output/explore/formal-actions/` |
| `06_explore-informal.R` | Informal actions and facilities | `output/explore/informal/` |
| `07_explore-pollutants.R` | Pollutants and facilities | `output/explore/pollutants/` |
| `08_explore-stack-tests.R` | Stack tests and facilities | `output/explore/stack-tests/` |
| `09_explore-pipeline.R` | ECHO pipeline plus related ICIS-Air tables | `output/explore/pipeline/` |
| `10_frs-crosswalk.R` | AFS facilities, ICIS-Air facilities, and FRS program links | `output/explore/frs_crosswalk/` |

The FRS crosswalk script is the only exploratory script that needs `data/frs_downloads/FRS_PROGRAM_LINKS.csv`. It maps legacy `AFS_ID` values to modern ICIS-Air `PGM_SYS_ID` values through `REGISTRY_ID`.

### Excel data dictionaries

The `scripts/tables/09_table-*.R` files create workbooks in `output/tables/` for:

- five legacy AFS tables;
- ICIS-Air facilities, programs, program subparts, compliance evaluations, violations, formal actions, informal actions, pollutants, stack tests, and Title V certifications;
- combined emissions; and
- the ECHO pipeline export.

`scripts/tables/10_crosscheck-tables.R` compares generated workbooks against matching files in `output/tables/backup_hardcoded/`. Tables without a frozen backup are skipped.

## Data model

The main identifiers are:

- `PGM_SYS_ID`: ICIS-Air source/program-system identifier and the primary join key across ICIS-Air tables;
- `REGISTRY_ID`: FRS identifier used to link a physical facility across EPA systems;
- `AFS_ID`: legacy AFS facility identifier.

One `REGISTRY_ID` can be associated with multiple `PGM_SYS_ID` values, so it is important to choose deliberately between the physical-facility and air-source levels of analysis. The FRS crosswalk bridges AFS and ICIS-Air as:

```text
AFS_ID → REGISTRY_ID → PGM_SYS_ID
```

## Data availability and repository policy

All source data used here are public EPA administrative data. No confidential or restricted records are required.

Because the downloads are several gigabytes, `data/raw/` and `data/frs_downloads/` are excluded from version control. The repository tracks code, compact derived files, exploratory summaries, reference documentation, and selected generated workbooks. It also ignores `.DS_Store`, `.tex`, credential files, R history, and Excel lock files.

Do not commit:

- raw EPA downloads;
- FRS bulk files;
- `.secrets/` or other credentials;
- `config/gsheet_config.R`; or
- manually created temporary files.

## Current limitations

- The research question and final estimand are still under development.
- The Title V utility output is a balanced panel skeleton, not a finished analysis dataset.
- `00_run_all.R` requires manual flag changes to regenerate exploratory and table outputs.
- Historical plots and retired outputs are tracked, but they are not part of the active reproducible workflow.
- Raw-download dates are not recorded in a machine-readable manifest, so users should document the vintage of any newly downloaded EPA files.

## License

See [LICENSE](LICENSE).
