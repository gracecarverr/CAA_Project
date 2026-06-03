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

- The base identification table — one row per regulated air source. Contains everything needed to locate, classify, and identify a facility.
- **Cross-section.** One row per facility; no time dimension.
- **Key fields:**
    - `PGM_SYS_ID` — the primary key across all ICIS-Air tables. An alphanumeric ID that uniquely identifies each air source; format varies by state but typically combines census state code, FIPS county code, local control district number, and a sequence number.
    - `REGISTRY_ID` — Facility Registry Service (FRS) ID. Links ICIS-Air records to other EPA datasets (e.g., emissions, TRI).
    - `SIC_CODES` / `NAICS_CODES` — industry classification. A facility can have multiple codes (concatenated in one field). SIC is the older system; NAICS is current.
    - `AIR_POLLUTANT_CLASS_CODE` — emissions classification based on the Alabama Power decision / 1993 EPA guidance:
        - `MAJ` = Major | `SMI` = Synthetic Minor | `MIN` = Minor | `UNK` = Unknown | `OTH` = Other | `NAP` = Not applicable
    - `AIR_OPERATING_STATUS_CODE` — operational condition:
        - `OPR` = Operating | `SEA` = Seasonal | `TMP` = Temporarily Closed | `CNS` = Under Construction | `PLN` = Planned | `CLS` = Permanently Closed | `NES` = NESHAP Spraying | `NER` = NESHAP Renovation | `LDF` = Landfill | `NED` = NESHAP Demolition
    - `CURRENT_HPV` — High Priority Violator status. Values indicate addressed/unaddressed status and lead agency (e.g., "Unaddressed-State", "Addressed-EPA").
    - `FACILITY_TYPE_CODE` — ownership type (e.g., `COR` = Corporation, `STF` = State Government, `FDF` = Federal Facility, `TRB` = Tribal Government, `IND` = Individual).

### Air Programs (ICIS-AIR_PROGRAMS.csv)

- Lists each regulatory air program a facility is subject to. A single facility can appear under multiple programs (e.g., Title V and NSPS simultaneously). Each row is a facility–program combination.
- **Panel.** Multiple programs per facility, each with begin/updated dates.
- **Key fields:**
    - `PROGRAM_CODE` / `PROGRAM_DESC` — the specific CAA regulatory program (e.g., Title V, NESHAP, NSPS, SIP). The nine-character code identifies which regulatory area applies.
    - `AIR_OPERATING_STATUS_CODE` — same codes as Facilities, but here they describe the status of the facility *within that specific program* (a facility can be operating under one program and closed under another).
    - `BEGIN_DATE` — date the facility entered the program system.
    - `UPDATED_DATE` — date the program record was last modified.

### Air Program Subparts (ICIS-AIR_PROGRAM_SUBPARTS.csv)

- Drills one level deeper than Programs. Identifies the specific regulatory subparts within a program that apply to a facility (e.g., a facility subject to NESHAP might fall under subpart DDDDD for industrial boilers).
- **Cross-section.** Facility–program–subpart combinations; no time dimension.
- **Key fields:**
    - `PROGRAM_CODE` / `PROGRAM_DESC` — parent program.
    - `AIR_PROGRAM_SUBPART_CODE` / `AIR_PROGRAM_SUBPART_DESC` — the specific regulatory subpart.

### Air Pollutants (ICIS-AIR_POLLUTANTS.csv)

- Lists the specific pollutants associated with each facility. One row per facility–pollutant combination.
- **Cross-section.** No time dimension.
- **Key fields:**
    - `POLLUTANT_CODE` / `POLLUTANT_DESC` — numeric code and name of the pollutant.
    - `SRS_ID` — Substance Registry Services ID; EPA's internal substance identifier.
    - `CHEMICAL_ABSTRACT_SERVICE_NMBR` — CAS number. Standard chemical identifier; useful for linking to toxicological or health data.
    - `AIR_POLLUTANT_CLASS_CODE` — same major/synthetic minor/minor classification as in Facilities, but here at the pollutant level (a facility's classification can differ by pollutant).

### Air Full Compliance Evaluations (FCEs) and Partial Compliance Evaluations (PCEs)

- Records of compliance monitoring activities — the inspections and reviews that determine whether a facility is meeting its CAA obligations. FCEs are comprehensive; PCEs focus on a specific aspect.
- **Event-level panel.** Multiple dated evaluations per facility over time.
- **Key fields:**
    - `ACTIVITY_ID` — unique identifier for this specific evaluation event.
    - `STATE_EPA_FLAG` — which agency conducted the evaluation (state/local agency vs. EPA).
    - `ACTIVITY_TYPE_CODE` — type of enforcement activity:
        - `AIF` = Administrative, Informal | `AFR` = Administrative, Formal | `JDC` = Judicial
    - `COMP_MONITOR_TYPE_CODE` — what kind of compliance monitoring was done:
        - `FOO` = FCE On-Site | `FFO` = FCE Off-Site | `PCE` = PCE On-Site | `PFF` = PCE Off-Site | `POC` = PCE CEMS/CMS Audit | `POI` = PCE On-Site Interview | `POM` = PCE Monitoring/Sampling | `POR` = PCE Record/Report Review
    - `ACTUAL_END_DATE` — date of the inspection/review.
    - `PROGRAM_CODES` — which regulatory programs the evaluation covered.

### Air Stack Tests (ICIS-AIR_STACK_TESTS.csv) 

- Results of emissions testing at facility stacks. Stack tests are a direct measurement of what a facility is actually emitting, as opposed to modeled or self-reported estimates.
- **Event-level panel.** Multiple dated tests per facility over time.
- **Key fields:**
    - `ACTIVITY_ID` — unique identifier for this test event.
    - `COMP_MONITOR_TYPE_CODE` / `COMP_MONITOR_TYPE_DESC` — type of compliance monitoring.
    - `STATE_EPA_FLAG` — responsible agency.
    - `ACTUAL_END_DATE` — date the test was completed.
    - `POLLUTANT_CODES` / `POLLUTANT_DESCS` — which pollutants were tested (can be multiple, concatenated).
    - `AIR_STACK_TEST_STATUS_CODE` — result:
        - `PSS` = Pass | `FAI` = Fail | `PEN` = Pending | `INC` = Incomplete | `NA` = Not applicable

### Air Title V Certifications (ICIS-AIR_TITLEV_CERTS.csv)

- Title V of the CAA requires major sources to hold a comprehensive operating permit and submit annual compliance certifications. This table records those submissions.
- **Event-level panel.** Multiple dated certifications per facility over time.
- **Key fields:**
    - `ACTIVITY_ID` — unique identifier for this certification event.
    - `STATE_EPA_FLAG` — responsible agency.
    - `ACTUAL_END_DATE` — date of certification.
    - `FACILITY_RPT_DEVIATION_FLAG` — whether the facility self-reported deviations from permit requirements during the certification period. A key indicator of compliance problems.

### ICIS-Air Formal Actions (ICIS-AIR_FORMAL_ACTIONS.csv)

- Formal enforcement responses to violations — actions with legal force, such as consent agreements, administrative orders, and judicial actions. These carry penalties and/or binding compliance schedules.
- **Event-level panel.** Multiple dated actions per facility over time.
- **Key fields:**
    - `ACTIVITY_ID` — unique identifier for this action.
    - `ENF_IDENTIFIER` — groups multiple activities belonging to the same enforcement case.
    - `ACTIVITY_TYPE_CODE` — type of enforcement activity:
        - `AIF` = Administrative, Informal | `AFR` = Administrative, Formal | `JDC` = Judicial
    - `ENF_TYPE_CODE` / `ENF_TYPE_DESC` — specific type of enforcement action taken.
    - `STATE_EPA_FLAG` — responsible agency.
    - `SETTLEMENT_ENTERED_DATE` — date the settlement was signed by a judge and entered by the clerk. Marks the formal resolution.
    - `PENALTY_AMOUNT` — civil penalty assessed or agreed upon, in dollars.

### ICIS-Air Informal Actions (ICIS-AIR_INFORMAL_ACTIONS.csv)

- Informal enforcement responses — actions without direct legal force, such as notices of violation (NOVs), warning letters, and phone calls. These typically precede formal action and signal that the agency has identified a problem.
- **Event-level panel.** Multiple dated actions per facility over time.
- **Key fields:**
    - `ACTIVITY_ID` — unique identifier for this action.
    - `ENF_IDENTIFIER` — groups multiple activities belonging to the same enforcement case.
    - `ACTIVITY_TYPE_CODE` — same codes as Formal Actions (AIF/AFR/JDC).
    - `ENF_TYPE_CODE` / `ENF_TYPE_DESC` — specific type of informal action.
    - `STATE_EPA_FLAG` — responsible agency.
    - `ACHIEVED_DATE` — date the informal action was achieved/completed.
    - `OFFICIAL_FLG` — whether the action is an official agency action.

### Case File High Priority Violations (HPVs) and Federally Reportable Violations (FRVs) (ICIS-AIR_VIOLATION_HISTORY.csv)

- The most serious violations in the ICIS-Air system. HPVs are violations that EPA considers serious enough to warrant a formal response; FRVs are violations that states must report to EPA. This table tracks the full lifecycle of each violation from discovery to resolution.
- **Event-level panel.** Multiple dated violations per facility, with discovery-to-resolution timeline.
- **Key fields:**
    - `ACTIVITY_ID` — unique identifier for this violation record.
    - `AGENCY_TYPE_DESC` — which level of government is handling enforcement.
    - `COMP_DETERMINATION_UID` — unique identifier for the case file activity.
    - `ENF_RESPONSE_POLICY_CODE` — violation severity:
        - `HPV` = High Priority Violation | `FRV` = Federally Reportable Violation
    - `PROGRAM_CODES` / `PROGRAM_DESCS` — which regulatory programs were violated.
    - `POLLUTANT_CODES` / `POLLUTANT_DESCS` — pollutants involved.
    - `EARLIEST_FRV_DETERM_DATE` — date the violation was first determined to be federally reportable.
    - `HPV_DAYZERO_DATE` — date the facility entered HPV status. "Day zero" starts the clock on EPA's enforcement response timeline.
    - `HPV_RESOLVED_DATE` — date the HPV was resolved. The gap between day-zero and resolution is a measure of enforcement speed.
    - `DSCV_PATHWAY_DATE` — date the violation was discovered.
    - `NFTC_PATHWAY_DATE` — date the facility was notified of the violation.

## Air Emissions Download Summary (POLL_RPT_COMBINED_EMISSIONS.csv)

- Emissions data for stationary sources from four EPA air programs: National Emissions Inventory (NEI), Greenhouse Gas Reporting Program (GHGRP), Toxics Release Inventory (TRI), and Clean Air Markets (CAMD). 
- Emissions presented as facility-level aggregates and organized by pollutant and EPA program.
- **Panel.** Facility–pollutant–program–year combinations. GHG data begins 2010; CAMD/TRI from 2008; NEI is triennial (2008, 2011, 2014, etc.).
- Joins to ICIS-Air via `REGISTRY_ID` (FRS code).
- **Key fields:**
    - `REPORTING_YEAR` — calendar year of the emission report. Frequency varies by program: CAMD, TRI, and GHG report annually; NEI is triennial.
    - `REGISTRY_ID` — Facility Registry Service ID. The join key to other EPA datasets including ICIS-Air Facilities.
    - `PGM_SYS_ACRNM` — which EPA program the emission data comes from:
        - `EIS` = NEI (National Emissions Inventory) | `E-GGRT` = GHGRP (Greenhouse Gas Reporting Program) | `TRIS` = TRI (Toxics Release Inventory) | `CAMDBS` = CAMD (Clean Air Markets Division)
    - `PGM_SYS_ID` — program-specific facility identifier. Format varies: 7-digit for NEI/GHGRP, 15-character for TRI, 4-digit for CAMD.
    - `POLLUTANT_NAME` — name of the tracked pollutant.
    - `ANNUAL_EMISSION` — pollutant emission value for the facility and year.
    - `UNIT_OF_MEASURE` — measurement units. Pounds for TRI/NEI/CAMD; metric tons CO2-equivalent per year (MTCO2e/yr) for GHG.
    - `NEI_TYPE` — pollutant category:
        - `CAP` = Criteria Air Pollutant | `GHG` = Greenhouse Gas | `HAP` = Hazardous Air Pollutant | `OTH` = Other
    - `NEI_HAP_VOC_FLAG` — "HAP-VOC" indicates the pollutant is a volatile organic compound classified as hazardous.

> https://echo.epa.gov/tools/data-downloads/air-emissions-download-summary

## AFS Dataset (FROZEN DATA AS OF OCTOBER 17,2024)

- Emissions, compliance, and enforcement data on stationary sources of air pollution. 
- Data rolled up to plant level. 

> https://echo.epa.gov/system/files/AFS_Data_Download.pdf

## CAA Pipeline Dataset

- Shows links between Compliance Monitoring Activities (CMA) to any related violations and/or enforcement actions. 

> https://echo.epa.gov/tools/data-downloads/caa-pipeline-download-summary


