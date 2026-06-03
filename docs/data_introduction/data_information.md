# Information about Air Stationary Source Data

## ICIS-Air Datasets

- Focus on data at the plant level, treats the entire facility as one unit rather than looking at individual emission points, processes, or stacks. Data at plant-level: 
* General source information (identification number, name)
* High priority violator (HPV) information
* Air Program information (addressing each regulatory area that a facility is subject to). 
- Uses FRS code. 

> ICIS-Air records included in the download files are those where the operating status is planned (has applied for a construction permit), under construction, operating, temporarily closed, seasonal, or permanently closed.

 > https://echo.epa.gov/tools/data-downloads/icis-air-download-summary

### Facility/Source Level Identifying Data (ICIS-AIR_FACILITIES.csv)

- Name, address, county, state, EPA region, SIC/NAICS codes, operating status, and HPV status for each facility. Primary key: `PGM_SYS_ID`.
- **Cross-section.** One row per facility; no time dimension.

### Air Programs (ICIS-AIR_PROGRAMS.csv)

- Regulatory air programs each facility is subject to (e.g., Title V, NSPS, NESHAP), with program-level operating status and dates.
- **Panel.** Multiple programs per facility, each with begin/updated dates.

### Air Program Subparts (ICIS-AIR_PROGRAM_SUBPARTS.csv)

- Specific subpart requirements within each air program applicable to a facility.
- **Cross-section.** Facility–program–subpart combinations; no time dimension.

### Air Pollutants (ICIS-AIR_POLLUTANTS.csv)

- Pollutants tracked at each facility, with pollutant codes, CAS numbers, and emissions classification (major/minor).
- **Cross-section.** Facility–pollutant combinations; no time dimension.

### Air Full Compliance Evaluations (FCEs) and Partial Compliance Evaluations (PCEs)

- Records of on-site inspections and off-site compliance reviews, including responsible agency, date, and applicable programs.
- **Event-level panel.** Multiple dated evaluations per facility over time.

### Air Stack Tests (ICIS-AIR_STACK_TESTS.csv) 

- Stack test results by facility, including pollutants tested and pass/fail status.
- **Event-level panel.** Multiple dated tests per facility over time.

### Air Title V Certifications (ICIS-AIR_TITLEV_CERTS.csv)

- Annual Title V compliance certifications submitted by facilities, with deviation flags.
- **Event-level panel.** Multiple dated certifications per facility over time.

### ICIS-Air Formal Actions (ICIS-AIR_FORMAL_ACTIONS.csv)

- Formal enforcement actions (e.g., consent agreements, judicial orders) with settlement dates and penalty amounts.
- **Event-level panel.** Multiple dated actions per facility over time.

### ICIS-Air Informal Actions (ICIS-AIR_INFORMAL_ACTIONS.csv)

- Informal enforcement actions (e.g., notices of violation, warning letters) with dates achieved.
- **Event-level panel.** Multiple dated actions per facility over time.

### Case File High Priority Violations (HPVs) and Federally Reportable Violations (FRVs) (ICIS-AIR_VIOLATION_HISTORY.csv)

- HPV and FRV case file records tracking violation discovery, day-zero date, and resolution date by facility.
- **Event-level panel.** Multiple dated violations per facility, with discovery-to-resolution timeline.

## Air Emissions Download Summary (POLL_RPT_COMBINED_EMISSIONS.csv)

- Emissions data for stationary sources from four EPA air programs: National Emissions Inventory (NEI), Greenhouse Gas Reporting Program (GHGRP), Toxics Release Inventory (TRI), and Clean Air Markets (CAMD). 
- Emissions presented as facility-level aggregates and organized by pollutant and EPA program.
- Uses FRS code. 

> https://echo.epa.gov/tools/data-downloads/air-emissions-download-summary

## AFS Dataset (FROZEN DATA AS OF OCTOBER 17,2024)

- Emissions, compliance, and enforcement data on stationary sources of air pollution. 
- Data rolled up to plant level. 

> https://echo.epa.gov/system/files/AFS_Data_Download.pdf

## CAA Pipeline Dataset

- Shows links between Compliance Monitoring Activities (CMA) to any related violations and/or enforcement actions. 

> https://echo.epa.gov/tools/data-downloads/caa-pipeline-download-summary


