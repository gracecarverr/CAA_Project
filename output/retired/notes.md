# Exploratory Analysis — Synthesis

## Overview

Initial exploration of EPA Clean Air Act stationary source data. 10 ICIS-Air tables covering 279,211 regulated air sources (265,490 unique facilities by `REGISTRY_ID`), plus a combined emissions dataset with 10.4 million records across 162,383 facilities.

## Dataset summary

| Dataset | Records | Unique Facilities | Key Finding |
|---|---|---|---|
| **Facilities** | 279,211 rows (air sources) | 265,490 (by `REGISTRY_ID`) | Spine table. 70% minor, 7% major. 28% permanently closed. |
| **Violation History** | 101,147 | 35,336 | 56% FRV, 44% HPV. Median resolution 309 days. 9% unresolved. |
| **FCEs/PCEs** | 1,802,044 | ~130k+ | FCE On-Site (639k) and PCE Off-Site (628k) dominate. 65% state-led. |
| **Formal Actions** | 105,656 | — | 95% administrative formal. Median penalty $5,500, mean $79,370. |
| **Informal Actions** | 336,410 | — | 3:1 ratio over formal actions. 79% state-led. |
| **Programs** | 456,350 | 266,744 | SIP is 53% of records. Median 1 program per facility. |
| **Program Subparts** | 186,308 | — | Engine standards (RICE, spark/compression ignition) dominate. |
| **Stack Tests** | 646,332 | — | 89% pass. `POLLUTANT_DESCS` is 100% empty. |
| **Title V Certs** | 2,563,435 | — | Deviation flag 57% missing. Of populated, 33% report deviations. |
| **Pollutants** | 976,479 | 255,748 | Median 2 pollutants/facility. CAS number 60% missing. |
| **Emissions** | 10,411,871 | 162,383 | NEI is 90% of records. Only 162k of 265k facilities match. |

## Enforcement picture

The data follows the expected enforcement pyramid. Informal actions (336k) outnumber formal actions (106k) roughly 3:1 — most enforcement starts with warnings and NOVs before escalating. Serious violations (HPV/FRV) total 101k across 35,336 facilities.

Violations are heavily concentrated among repeat offenders: 55% of facilities with any violation have exactly one, while the maximum is 1,013. Median HPV resolution time is 309 days (mean 546 days); 9% remain unresolved.

Penalties are heavily right-skewed: median $5,500, mean $79,370, max $100.7 million. The 25th percentile is $2,000 and the 75th is $18,903.

State agencies lead enforcement at every stage: 65% of inspections, 65% of formal actions, 79% of informal actions. EPA directly handles ~5–15% depending on the activity. Local agencies handle the remainder.

## Emissions picture

The combined emissions dataset merges four EPA programs with different scopes, frequencies, and units:

- **NEI** (EIS): 9.4M records. Triennial (2008, 2011, 2014, 2017, 2020). Criteria pollutants and HAPs. Most comprehensive coverage but least frequent.
- **TRI** (TRIS): 799k records. Annual. Toxic chemical releases (~770 chemicals).
- **GHGRP** (E-GGRT): 196k records. Annual, starts 2010. Greenhouse gases from large emitters (25k+ metric tons CO2e/year).
- **CAMD** (CAMDBS): 34k records. Annual. Measured SO2/NOx from power plants in cap-and-trade programs.

NEI's triennial schedule creates a sawtooth pattern: ~1.8–2.1M records in NEI years, ~100–110k in non-NEI years.

Units differ across programs — pounds for NEI/TRI/CAMD, metric tons CO2e for GHGRP. Cannot sum across programs without conversion.

## Compliance monitoring

Stack tests pass 89% of the time; only 3% fail. Title V certifications are the largest event table (2.6M records). The deviation flag — the key self-reported compliance indicator — is 57% missing. Of records where it's populated, about one-third report deviations.

## Data quality issues

**Bad dates.** Data entry errors producing impossible years (0218, 0217, 1010, 1012, etc.) found in violation history (4 records) and FCEs/PCEs (18 records). Documented in `*_bad_dates.csv` files and set to NA. Additional suspicious early dates in FCEs (1900, 1916, 1957 — 1 record each) are likely also errors but not automatically cleaned.

**Missingness of analytical interest:**
- Title V `FACILITY_RPT_DEVIATION_FLAG`: 57% missing — severely limits use as a compliance indicator.
- Stack test `POLLUTANT_DESCS`: 100% empty. `POLLUTANT_CODES` is 37% missing. Limits ability to identify what was tested.
- Pollutants `CHEMICAL_ABSTRACT_SERVICE_NMBR` (CAS): 60% missing — limits linkage to toxicological or health data.
- Violation history `HPV_DAYZERO_DATE`: 56% missing (only populated for HPVs, not FRVs). `DSCV_PATHWAY_DATE`: 62% missing.

**Mixed units.** Emissions data combines pounds and metric tons CO2e. Must handle separately or convert before any aggregation.

## Join architecture

- **Within ICIS-Air:** `PGM_SYS_ID` links all 10 tables. One row per air source in the Facilities spine.
- **ICIS-Air → Emissions:** `REGISTRY_ID` (FRS code). ~14k air sources share a `REGISTRY_ID`, so multiple `PGM_SYS_ID`s can map to one emissions record.
- **Coverage gap:** Only 162,383 of 265,490 ICIS-Air facilities (by `REGISTRY_ID`) appear in the emissions data. Many regulated facilities have no emissions records in this dataset.

## Decisions still needed

- **Panel structure:** facility-year? facility-quarter? facility-pollutant-year?
- **Unit of analysis:** `PGM_SYS_ID` (air source) vs. `REGISTRY_ID` (facility)?
- **Emissions scope:** All four programs or a subset?
- **AFS inclusion:** Has quarterly compliance status not available in ICIS-Air, but `AFS_ID` has no clean crosswalk to `PGM_SYS_ID`.
- **NEI gap years:** How to handle triennial reporting — interpolate, leave as missing, or restrict to NEI years only?
