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

- The base identification table — one row per regulated air source. Contains everything needed to locate, classify, and identify a source. Multiple air sources at the same physical facility share a `REGISTRY_ID`.
- **Cross-section.** One row per air source (`PGM_SYS_ID`); no time dimension.
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

## AFS Dataset (FROZEN DATA AS OF OCTOBER 17, 2014)

- Emissions, compliance, and enforcement data on stationary sources of air pollution. Regulated sources range from large industrial facilities to small operations like dry cleaners. Excludes facilities that are solely asbestos demolition/renovation contractors or landfills.
- Data rolled up to plant level. Plant-level data treats the entire facility as one unit rather than looking at individual emission points, processes, or stacks. Data at plant-level:
    * General source information (identification number, name).
    * High Priority Violator (HPV) information.
    * Air Program information — a repeating block of data addressing each regulatory area that a facility is subject to (e.g., SIP, NSPS, NESHAP, PSD).
- Each air program offers: historical compliance status (quarterly, FY2007–present), action/activity data (inspections, enforcement actions, 1978–present), and operating status.
- Action/activity data is rolled up to the plant level to eliminate multi-counting actions entered at multiple air programs (e.g., an inspection addressing SIP, NSPS, and NSR is recorded once, with `ALL_AIR_PROGRAM_CODES` listing all three).
- Uses AFS ID (SCSC). Does not use FRS code directly.

> AFS records included in the download files are those where the operating status is planned (has applied for a construction permit), under construction, operating, temporarily closed, seasonal, or permanently closed.

> https://echo.epa.gov/system/files/AFS_Data_Download.pdf

### Facility/Source Level Identifying Data (AFS_FACILITIES.csv)

- One row per plant. Contains identification, location, classification, operating status, and compliance status.
- **Cross-section.** One row per plant (`AFS_ID`); no time dimension.
- **Key fields:**
    - `AFS_ID` — 10-character alphanumeric code uniquely identifying each permitted plant. Composed of Census FIPS state code + FIPS county code + unique AFS plant ID. Also known as SCSC in AFS.
    - `PLANT_ID` — numeric plant identifier.
    - `PLANT_NAME` / `PLANT_STREET_ADDRESS` / `PLANT_CITY` / `PLANT_COUNTY` / `STATE` / `ZIP_CODE` — location fields.
    - `EPA_REGION` — EPA region (01–10).
    - `PRIMARY_SIC_CODE` / `SECONDARY_SIC_CODE` — four-character Standard Industrial Classification codes.
    - `NAICS_CODE` — six-character North American Industry Classification System code.
    - `EPA_CLASSIFICATION_CODE` — emissions classification per the Alabama Power decision / 1993 EPA guidance:
        - `A` = Actual or potential emissions above major source thresholds | `A1` = Actual or potential controlled emissions >100 tons/year | `A2` = Actual <100 tons/year, potential uncontrolled >100 tons/year | `B` = Potential uncontrolled <100 tons/year | `SM` = Synthetic minor (below all major source thresholds) | `C` / `UK` = Unknown | `ND` = Thresholds not defined
    - `OPERATING_STATUS` — operational condition (generated from most significant air program status):
        - `O` = Operating | `C` = Under Construction | `P` = Planned | `T` = Temporarily Closed | `X` = Permanently Closed | `I` = Seasonal | `D` = NESHAP Demolition | `R` = NESHAP Renovation | `S` = NESHAP Spraying | `L` = Landfill
    - `EPA_COMPLIANCE_STATUS` — EPA's determination of compliance (worst case across EPA and state fields):
        - `0` = Unknown | `1` = In Violation – No Schedule | `2` = In Compliance – Source Test | `3` = In Compliance – Inspection | `4` = In Compliance – Certification | `5` = Meeting Compliance Schedule | `6` = In Violation – Not Meeting Schedule | `7` = In Violation – Unknown re Schedule | `8` = No Applicable State Regulation | `9` = In Compliance – Shut Down | `D` = HPV Violation (auto) | `E` = FRV Violation (auto) | `F` = HPV On Schedule (auto) | `G` = FRV On Schedule (auto) | `H` = In Compliance (auto) | `M` = In Compliance – CEMs
    - `CURRENT_HPV` — current High Priority Violator status:
        - `S` = Unaddressed, state/local lead | `T` = Addressed, state lead | `E` = Unaddressed, EPA lead | `F` = Addressed, EPA lead | `B` = Unaddressed, shared lead | `C` = Addressed, shared lead | `X` = Unaddressed, lead unassigned
    - `STATE_COMPLIANCE_STATUS` — state agency's compliance determination (same code set as `EPA_COMPLIANCE_STATUS`).
    - `FEDERALLY_REPORTABLE` — ECHO-generated flag (`Y`/`N`). `Y` if emission classification is major or synthetic minor, or subject to NSPS/NESHAP with compliance status ≠ "no applicable state regulation."
    - `AFS_GOV_FACILITY_CODE` — government facility indicator:
        - `0` = Privately owned/operated | `1` = Federal government | `2` = State government | `3` = County | `4` = Municipality | `5` = District | `6` = Tribe
    - `LOCAL_CONTROL_REGION` — two-character local control region code (meanings vary by state).

### Air Program (AIR_PROGRAM.csv)

- Lists each regulatory air program a plant is subject to, along with pollutant-level classification and compliance status. A single plant can appear under multiple programs. Each row is a plant–program combination, potentially with pollutant-level detail.
- **Panel.** Multiple programs per plant.
- **Key fields:**
    - `AFS_ID` / `PLANT_ID` — plant identifiers (join to Facilities).
    - `AIR_PROGRAM_CODE` — one-character code identifying the regulatory air program:
        - `0` = SIP | `1` = SIP under federal jurisdiction (FIP) | `3` = Non-federally reportable | `4` = CFC Tracking | `6` = PSD | `7` = NSR | `8` = NESHAP (Part 61) | `9` = NSPS | `A` = Acid Precipitation | `F` = FESOP (non-Title V) | `I` = Native American | `M` = MACT (Part 63 NESHAPS) | `T` = TIP (Tribal Implementation Plan) | `V` = Title V
    - `AIR_PROGRAM_STATUS` — operating status within this program (same codes as `OPERATING_STATUS` in Facilities).
    - `EPA_CLASSIFICATION_CODE` — emissions classification at the air program level (same codes as Facilities).
    - `EPA_COMPLIANCE_STATUS` — compliance status at the air program level (same codes as Facilities).
    - `AIR_PROGRAM_CODE_SUBPARTS` — applicable subparts, delimited by spaces (e.g., NSPS subpart `Da` for electric utility steam generators). See PDF for full subpart list.
    - `POLLUTANT_CODE` — five-character pollutant code at the air program level (see Appendix 1 in PDF for full list).
    - `CHEMICAL_ABSTRACT_SERVICE_NMBR` — CAS number for the pollutant, if it exists.
    - `POLLUTANT_CLASSIFICATION` — emissions classification at the pollutant level (same codes as `EPA_CLASSIFICATION_CODE`).
    - `POLLUTANT_COMPLIANCE_STATUS` — compliance status at the pollutant level (same codes as `EPA_COMPLIANCE_STATUS`).

### Actions (AFS_ACTIONS.csv)

- Records of compliance monitoring activities and enforcement actions, rolled up to plant level. Includes inspections (FCEs, PCEs), enforcement actions (NOVs, administrative orders, consent decrees), stack tests, Title V certification reviews, and other activities. Each row is a single action event.
- **Event-level panel.** Multiple dated actions per plant over time (1978–present).
- **Key fields:**
    - `AFS_ID` / `PLANT_ID` — plant identifiers (join to Facilities).
    - `ANU1` — action number; uniquely identifies an action record within a plant.
    - `NATIONAL_ACTION_TYPE` — two-character code identifying the compliance/enforcement activity. Key codes:
        - Inspections (FCE): `FE` = EPA FCE on-site | `FZ` = EPA FCE off-site | `FS` = State FCE on-site | `FF` = State FCE off-site | `1A` = EPA inspection level 2+ | `5C` = State inspection level 2+
        - Inspections (PCE): `ES` = EPA PCE on-site | `EX` = EPA PCE off-site | `PS` = State PCE on-site | `PX` = State PCE off-site
        - Formal enforcement: `8A` = EPA 113(a) order | `8C` = State administrative order | `6B` = EPA court consent decree | `2D` = Consent agreement filed | `9A` = 113(d) delayed compliance order | `7A` = Notice of noncompliance (Section 120)
        - Informal enforcement: `6A` = EPA NOV | `7C` = State NOV | `3E` = Warning notification of violation | `3F` = Warning substantive violation | `5A` = EPA pre-NOV letter | `LL` = EPA Section 114 letter
        - Stack tests: `2A` = EPA conducted | `3A` = Owner/operator conducted | `6C` = State conducted
        - Title V: `CB` = Title V annual compliance cert due/received | `ER` = Title V cert review by EPA | `SR` = Title V cert review by state
        - Resolution: `C4` = Final compliance | `C7` = Closeout memo | `VR` = Violation resolved
    - `NATIONAL_ACTION_DESC` — text description for the action type.
    - `DATE_ACHIEVED` — date of the completed action (YYYYMMDD format).
    - `ALL_AIR_PROGRAM_CODES` — all air programs associated with this action, space-delimited.
    - `PENALTY_AMOUNT` — civil penalty assessed or agreed to, in dollars.
    - `RESULT_CODE` — result of stack tests and Title V reviews:
        - `PP` = Stack test passed | `FF` = Stack test failed | `99` = Pending | `MC` = In compliance | `MV` = In violation | `MU` = Unknown compliance status | `FR` = Federally reportable violation | `01` = Action achieved | `02` = Not achieved
    - `POLLUTANT_CODE` — pollutant associated with the action.
    - `ALL_VIOLATING_POLL_CODES` — pollutant(s) in violation, space-delimited.
    - `ALL_VIOLATION_TYPE_CODES` — three-character violation type codes (e.g., `GC1` = Failure to obtain PSD/NSR permit, `GC8` = Emission limit violation via stack test, `M1A` = Any emission limit violation via stack testing). See PDF for full list.
    - `KEY_ACTION_NUMBERS` — links the action to violation pathway / FCE pathway(s). Up to ten pathways.
    - `CREATION_DATE` / `DATE_RECORD_IS_UPDATED` — record metadata dates.

### Historical Compliance – Air Program Level (AFS_AIR_PRG_HIST_COMPLIANCE.csv)

- Quarterly compliance status for each air program at each plant. Provides a time series of compliance determinations from FY2007 to present. This is the key panel dataset in AFS — it gives quarterly compliance status not available in ICIS-Air.
- **Panel.** One row per plant–program–quarter combination.
- **Key fields:**
    - `AFS_ID` — plant identifier (join to Facilities).
    - `AIR_PROGRAM_CODE` — which regulatory program (same codes as Air Program table).
    - `HISTORICAL_COMPLIANCE_DATE` — quarter identifier in YYQQ format. Quarters are calendar year (Q1 = Jan–Mar, Q2 = Apr–Jun, Q3 = Jul–Sep, Q4 = Oct–Dec).
    - `HISTORICAL_COMPLIANCE_STATUS` — compliance status for that quarter (same codes as `EPA_COMPLIANCE_STATUS` in Facilities).

### Historical High Priority Violation Status (AFS_HPV_HISTORY.csv)

- Tracks the lifecycle of HPV designations: when a plant entered HPV status (day zero), which agency led enforcement, and when/how the violation was resolved. Each row is one HPV episode.
- **Event-level panel.** Multiple HPV episodes per plant over time.
- **Key fields:**
    - `AFS_ID` — plant identifier (join to Facilities).
    - `HPV_DAYZERO_TYPE` — lead agency at day zero:
        - `2Z` = Federal day zero | `2E` = State day zero | `2B` = Shared enforcement lead day zero
    - `HPV_DAYZERO_DATE` — date the plant entered HPV status.
    - `HPV_RESOLVED_TYPE` — action that resolved the HPV (blank if unresolved):
        - `C3` = 113(d) penalty collected | `C7` = Closeout memo issued | `2K` = Compliance by state, no action required | `7G` = Source returned to compliance by EPA, no further action | `VR` = Violation resolved | `WD` = EPA 113(d) withdrawn | `SE` = 113(d) settlement | `2L` = Proposed SIP revision to compliance | `2M` = Source-specific SIP revision
    - `HPV_RESOLVED_DATE` — date the HPV was resolved. Gap between day-zero and resolution measures enforcement speed.

### Crosswalk to ICIS-Air

- AFS uses `AFS_ID` as its primary key. There is no clean crosswalk between `AFS_ID` and ICIS-Air's `PGM_SYS_ID`. Both are derived from state/county/plant codes but use different formatting conventions.
- AFS's key unique feature is **quarterly historical compliance status** (`AFS_AIR_PRG_HIST_COMPLIANCE`), which is not available in ICIS-Air.
- AFS data is frozen as of October 17, 2024.

## CAA Pipeline Dataset

- Shows links between Compliance Monitoring Activities (CMA) to any related violations and/or enforcement actions.
- "EPA's Enforcement and Compliance History Online (ECHO) website has implemented a new feature responding to frequent requests that Clean Air Act activities be presented showing associations between compliance monitoring, violations, and enforcement. Historically, ECHO organized data in the Detailed Facility Report (DFR) by activity type, listing compliance monitoring activities, violations, and formal and informal enforcement actions in separate tables. Now, an additional "pipeline view" will help users understand how Clean Air Act violations relate to compliance monitoring (i.e., what was the violation discovery activity?) and enforcement (i.e., what violations did enforcement actions address?)."

> https://www.fedcenter.gov/Announcements/index.cfm?id=42737&pge_id=1854&printable=1

To see this new view, navigate to the Enforcement and Compliance section of a Detailed Facility Report for any Clean Air Act permitted facility with past or current violations.

> https://echo.epa.gov/tools/data-downloads/caa-pipeline-download-summary


