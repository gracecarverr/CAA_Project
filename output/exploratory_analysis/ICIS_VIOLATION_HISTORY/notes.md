# ICIS-AIR Violation History — Exploratory Notes

Explored the HPV/FRV case file table. Event-level panel: multiple dated violations per facility over time.

## What we checked

- **Missingness** — coverage by column
- **Date range** — earliest/latest across HPV day-zero, resolved, FRV determination, and discovery dates
- **Violations by year** — annual counts using `HPV_DAYZERO_DATE`
- **HPV vs. FRV** — distribution of violation severity (`ENF_RESPONSE_POLICY_CODE`)
- **Violations per facility** — concentration among repeat offenders
- **Resolution time** — days from day-zero to resolved, with percentiles
- **Agency distribution** — who handles enforcement

## Data quality issues

- **Bad dates found.** Four records had impossible years (0218, 0217, 0014) due to data entry errors in the source data. Documented in `violations_bad_dates.csv` and converted to NA.
- `mdy()` parsing is inconsistent on these malformed strings across runs — sometimes it parses them, sometimes it returns NA. Defensive cleaning (flag anything pre-1970 as NA) is necessary regardless.

## Key numbers

- **101,147 records** total across **35,336 unique facilities**.
- **FRV vs. HPV:** 56,657 FRVs (56%), 44,490 HPVs (44%).
- **Violations per facility:** mean 2.86, median 1. 55% of facilities have exactly one violation. Max is 1,013 — heavy concentration in repeat offenders.
- **Date coverage:** HPV day-zero goes back to 1975; FRV determination starts 1987; discovery pathway starts 1983. All run through May 2026.
- **Resolution time (HPVs with both dates):** n = 40,459. Mean 546 days, median 309 days. 25th percentile 150 days, 75th percentile 661 days. Max 9,793 days (~27 years). 9% of HPVs are still unresolved.
- **Missingness concerns:** `HPV_DAYZERO_DATE` is 56% missing (only populated for HPVs, not FRVs). `DSCV_PATHWAY_DATE` is 62% missing. `AIR_LCON_CODE` is 81% missing. `POLLUTANT_CODES` is 13% missing.

## Key takeaways

- HPV day-zero dates range from 1975 to 2026; FRV determination starts later (1987).
- Resolution time (day-zero to resolved) is a usable measure of enforcement speed.
- `pct_unresolved` captures HPVs with a day-zero but no resolved date — still-open cases.
- Violation counts are heavily right-skewed — most facilities have one, a small number have hundreds.
