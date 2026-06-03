# ICIS-Air Data Dictionary

> Source: https://echo.epa.gov/tools/data-downloads/icis-air-download-summary

All files join on `PGM_SYS_ID`, the unique facility identifier. `ACTIVITY_ID` uniquely identifies specific activities (inspections, actions, violations) within a facility.

---

## ICIS-AIR_FACILITIES.csv

Facility and source-level identification data for air pollution sources.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Alphanumeric program system identifier; uniquely identifies each air source |
| REGISTRY_ID | Char | 12 | Facility Registry Service (FRS) ID linking regulatory records |
| FACILITY_NAME | Char | 80 | Official or legal name of the plant |
| STREET_ADDRESS | Char | 35 | First line of street address or site entrance identifier |
| CITY | Char | 60 | City where plant is physically located |
| COUNTY_NAME | Char | 100 | County where plant is physically located |
| STATE | Char | 2 | Two-character postal abbreviation |
| ZIP_CODE | Char | 14 | Five or nine-digit zip code |
| EPA_REGION | Char | 2 | EPA Regional office code (01–10) |
| SIC_CODES | Char | 4000 | Four-character Standard Industrial Classification codes |
| NAICS_CODES | Char | 4000 | North American Industry Classification System codes |
| FACILITY_TYPE_CODE | Char | 3 | Code indicating government or private facility type |
| AIR_POLLUTANT_CLASS_CODE | Char | 3 | Source emissions classification (MAJ/SMI/MIN/UNK/OTH/NAP) |
| AIR_POLLUTANT_CLASS_DESC | Char | 100 | Description of pollutant classification |
| AIR_OPERATING_STATUS_CODE | Char | 5 | Operational condition code (OPR/SEA/TMP/CNS/PLN/CLS/NES/NER/LDF/NED) |
| AIR_OPERATING_STATUS_DESC | Char | 100 | Description of operating status |
| CURRENT_HPV | Char | 80 | High Priority Violator status and enforcement information |
| AIR_LOCAL_CONTROL_REGION_CODE | Char | 3 | Local Control Region code with jurisdiction |
| AIR_LOCAL_CONTROL_REGION_NAME | Char | 100 | Local Control Region name |

---

## ICIS-AIR_PROGRAMS.csv

Air regulatory programs applicable to facilities.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier linking to facilities |
| PROGRAM_CODE | Char | 9 | Nine-character code identifying regulatory air program |
| PROGRAM_DESC | Char | 100 | Description of the air program |
| AIR_OPERATING_STATUS_CODE | Char | 5 | Operational condition for the air program |
| AIR_OPERATING_STATUS_DESC | Char | 100 | Description of program operating status |
| BEGIN_DATE | Date | — | Date that data were entered in the program system |
| UPDATED_DATE | Date | — | Date information was last updated |

---

## ICIS-AIR_PROGRAM_SUBPARTS.csv

Air program subparts detailing specific regulatory requirements.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| PROGRAM_CODE | Char | 9 | Air program code |
| PROGRAM_DESC | Char | 100 | Program description |
| AIR_PROGRAM_SUBPART_CODE | Char | 20 | Code indicating applicable air program subparts |
| AIR_PROGRAM_SUBPART_DESC | Char | 200 | Description of the subpart |

---

## ICIS-AIR_POLLUTANTS.csv

Pollutants tracked at the air program level.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| POLLUTANT_CODE | Num | — | Numeric code that identifies a pollutant |
| POLLUTANT_DESC | Char | 2000 | Pollutant description |
| SRS_ID | Char | 9 | Substance Registry Services ID |
| CHEMICAL_ABSTRACT_SERVICE_NMBR | Char | 9 | Chemical Abstract Service (CAS) number |
| AIR_POLLUTANT_CLASS_CODE | Char | 3 | Pollutant emissions classification |
| AIR_POLLUTANT_CLASS_DESC | Char | 100 | Emissions classification description |

---

## ICIS-AIR_FCES_PCES.csv

Full Compliance Evaluations (FCEs) and Partial Compliance Evaluations (PCEs).

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| ACTIVITY_ID | Num | — | Unique identifier for an activity performed at or related to a particular site |
| STATE_EPA_FLAG | Char | 1 | Agency in charge (Local/State/EPA) |
| ACTIVITY_TYPE_CODE | Char | 3 | Code describing civil enforcement activity type |
| ACTIVITY_TYPE_DESC | Char | 100 | Description of activity type |
| COMP_MONITOR_TYPE_CODE | Char | 3 | Compliance monitoring action type code |
| COMP_MONITOR_TYPE_DESC | Char | 100 | Compliance monitoring type description |
| ACTUAL_END_DATE | Date | 10 | Calendar date of inspection |
| PROGRAM_CODES | Char | 4000 | Applicable regulatory program codes |
| ACTIVITY_PURPOSE_DESC | Char | 100 | Description of compliance evaluation purpose |

---

## ICIS-AIR_STACK_TESTS.csv

Stack test results and compliance monitoring data.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| ACTIVITY_ID | Num | — | Activity identifier |
| COMP_MONITOR_TYPE_CODE | Char | 3 | Compliance monitoring action type code |
| COMP_MONITOR_TYPE_DESC | Char | 100 | Monitoring type description |
| STATE_EPA_FLAG | Char | 1 | Responsible agency identifier |
| ACTUAL_END_DATE | Date | 7 | Test completion date |
| POLLUTANT_CODES | Char | 4000 | Numeric pollutant codes tested |
| POLLUTANT_DESCS | Char | 4000 | Descriptions of tested pollutants |
| AIR_STACK_TEST_STATUS_CODE | Char | 3 | Stack test result code (FAI/PSS/PEN/INC/NA) |
| AIR_STACK_TEST_STATUS_DESC | Char | 100 | Stack test status description |

---

## ICIS-AIR_TITLEV_CERTS.csv

Title V operating permit annual compliance certifications.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| ACTIVITY_ID | Num | — | Activity identifier |
| COMP_MONITOR_TYPE_CODE | Char | 3 | Compliance monitoring action type code |
| COMP_MONITOR_TYPE_DESC | Char | 100 | Monitoring type description |
| STATE_EPA_FLAG | Char | 1 | Responsible agency identifier |
| ACTUAL_END_DATE | Date | 7 | Certification date |
| FACILITY_RPT_DEVIATION_FLAG | Char | 1 | Flag indicating facility-reported deviations during review |

---

## ICIS-AIR_FORMAL_ACTIONS.csv

Formal enforcement actions and penalties.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| ACTIVITY_ID | Num | — | Activity identifier |
| ENF_IDENTIFIER | Char | 25 | Number used to uniquely identify multiple occurrences of enforcement |
| ACTIVITY_TYPE_CODE | Char | 3 | Civil enforcement activity type code |
| ACTIVITY_TYPE_DESC | Char | 100 | Activity type description |
| STATE_EPA_FLAG | Char | 1 | Responsible agency identifier |
| ENF_TYPE_CODE | Char | 7 | Code identifying action type against plant |
| ENF_TYPE_DESC | Char | 100 | Enforcement type description |
| SETTLEMENT_ENTERED_DATE | Date | 7 | Date settlement signed by judge and entered by clerk |
| PENALTY_AMOUNT | Num | — | Civil penalty amount assessed or agreed upon |

---

## ICIS-AIR_INFORMAL_ACTIONS.csv

Informal enforcement actions and compliance orders.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| ACTIVITY_ID | Num | — | Activity identifier |
| ENF_IDENTIFIER | Char | 25 | Enforcement action unique identifier |
| ACTIVITY_TYPE_CODE | Char | 3 | Civil enforcement activity type code |
| ACTIVITY_TYPE_DESC | Char | 100 | Activity type description |
| STATE_EPA_FLAG | Char | 1 | Responsible agency identifier |
| ENF_TYPE_CODE | Char | 7 | Enforcement action type code |
| ENF_TYPE_DESC | Char | 100 | Enforcement type description |
| ACHIEVED_DATE | Date | 7 | Date informal action achieved |
| OFFICIAL_FLG | Char | 1 | Official action flag |

---

## ICIS-AIR_VIOLATION_HISTORY.csv

High Priority Violations (HPVs) and Federally Reportable Violations (FRVs) case file data.

| Field | Type | Length | Description |
|---|---|---|---|
| PGM_SYS_ID | Char | 30 | Program system identifier |
| ACTIVITY_ID | Num | — | Activity identifier |
| AGENCY_TYPE_DESC | Char | 100 | Environmental agency responsible for enforcement |
| STATE_CODE | Char | 2 | State identifier |
| AIR_LCON_CODE | Char | 3 | Local Control Region code |
| COMP_DETERMINATION_UID | Char | 25 | Unique identifier for the case file activity |
| ENF_RESPONSE_POLICY_CODE | Char | 3 | Enforcement response policy type (HPV/FRV) |
| PROGRAM_CODES | Char | 4000 | Applicable program codes |
| PROGRAM_DESCS | Char | 4000 | Program descriptions |
| POLLUTANT_CODES | Char | 4000 | Associated pollutant codes |
| POLLUTANT_DESCS | Char | 4000 | Pollutant descriptions |
| EARLIEST_FRV_DETERM_DATE | Date | 7 | Earliest Federally Reportable Violation determination date |
| HPV_DAYZERO_DATE | Date | 7 | Date facility entered HPV status |
| HPV_RESOLVED_DATE | Date | 7 | Date facility resolved HPV status |
| DSCV_PATHWAY_DATE | Date | — | Date violation was discovered |
| NFTC_PATHWAY_DATE | Date | — | Date facility was notified |
