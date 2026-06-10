# Data Availability and Provenance Statements, and Instructions for Replicators

> INSTRUCTIONS: This README follows the [AEA template README](https://social-science-data-editors.github.io/template_README/) for social science replication packages. This project is in the exploratory/pre-analysis phase. Sections will be updated as the project develops.

## Overview

This project uses EPA administrative data on Clean Air Act stationary source regulation to study [research question TBD]. The data cover facility characteristics, regulatory program participation, compliance monitoring, violation history, and enforcement actions for the universe of CAA-regulated stationary sources in the United States.

All code is in R. The exploration scripts produce summary tables (CSV) and notes (Markdown) characterizing each dataset. No final analysis has been conducted yet.

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
  - `readr`
  - `dplyr`
  - `tidyr`
  - `ggplot2`
  - `lubridate`

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
│   ├── raw/              # Immutable raw downloads
│   │   ├── ICIS-AIR_downloads/
│   │   ├── afs_downloads/
│   │   ├── POLL_RPT_COMBINED_EMISSIONS.csv
│   │   ├── PIPELINE_CAA_00_COMPLETE.csv
│   │   └── ECHO_EXPORTER_HEADER.csv
│   ├── derived/          # (empty — no derived datasets yet)
│   └── clean/            # (empty — no cleaned datasets yet)
├── scripts/
│   ├── 01_explore-facilities.R
│   ├── 02_explore-programs.R
│   ├── 02_reclassification-signals.R
│   ├── 03_explore-violations.R
│   ├── 03_reclass-nonoilgas.R
│   ├── 04_explore-compliance.R
│   ├── 05_explore-enforcement.R
│   └── retired/
├── output/
│   ├── facilities/
│   ├── programs/
│   ├── violations/
│   ├── compliance/
│   ├── enforcement/
│   ├── reclassification/
│   └── june9notes.md
├── docs/
│   └── data_introduction/
└── README.md
```

### Scripts

| Script | Description |
|---|---|
| `01_explore-facilities.R` | Structure, missingness, and tabulations for ICIS-Air Facilities |
| `02_explore-programs.R` | Structure, missingness, and tabulations for ICIS-Air Programs |
| `02_reclassification-signals.R` | Investigates traces of major→minor reclassification in the data |
| `03_explore-violations.R` | Structure, missingness, and tabulations for ICIS-Air Violation History |
| `03_reclass-nonoilgas.R` | Non-oil/gas reclassification analysis with emissions matching |
| `04_explore-compliance.R` | Structure, missingness, and tabulations for ICIS-Air FCEs/PCEs |
| `05_explore-enforcement.R` | Structure, missingness, and tabulations for ICIS-Air Formal Actions |

## Instructions to Replicators

1. Download all data files from ECHO (URLs above) and place them in the appropriate subdirectories under `data/raw/`.
2. Open each script in R and update the `setwd()` path to your local project directory.
3. Run scripts in numeric order. Each script is self-contained — it loads its own data and writes output to the corresponding `output/` subdirectory.

## List of Tables and Programs

This project is in the exploratory phase. Scripts produce summary CSVs and notes files, not final paper tables. See `output/june9notes.md` for a synthesis of exploration results.

## References

U.S. Environmental Protection Agency. *ICIS-Air Data Downloads.* Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads/icis-air-download-summary

U.S. Environmental Protection Agency. *AFS Data Downloads.* Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads#afs

U.S. Environmental Protection Agency. *Combined Emissions Data Downloads.* Enforcement and Compliance History Online (ECHO). https://echo.epa.gov/tools/data-downloads#emissions

U.S. Environmental Protection Agency. *AFS Data Download Summary.* https://echo.epa.gov/system/files/AFS_Data_Download.pdf
