# ICIS-AIR FCEs/PCEs — Exploratory Notes

Explored the compliance evaluation table. Event-level panel: multiple dated inspections per facility over time.

## What we checked

- **Missingness** — coverage by column
- **FCE vs PCE split** — distribution by evaluation type
- **Agency distribution** — state vs. EPA vs. local
- **Inspections per year** — annual counts using `ACTUAL_END_DATE`
- **Bad dates** — documented and cleaned

## Data quality issues

- **Bad dates found.** 18 records with impossible years (pre-1900) due to data entry errors in the source data. Documented in `fces_pces_bad_dates.csv` and converted to NA.
- **Suspicious early dates.** A handful of records in 1900, 1916, 1957 (1 each) are likely also data entry errors but not automatically cleaned. Real inspection data appears to start in the early 1970s.

## Key numbers

- **1,802,044 records** across an estimated ~130k+ unique facilities.
- **Evaluation types:** FCE On-Site (639,462), PCE Off-Site (628,430), PCE On-Site (370,070) are the top three. FCE Off-Site is rare (21,661).
- **Agency:** State-led (S) dominates with ~65% of inspections. Local agencies handle ~20%, EPA ~5%.
- **Year range:** Meaningful data starts ~1972; runs through mid-2026.
- **Missingness:** Core fields are complete. `PROGRAM_CODES` and `ACTIVITY_PURPOSE_DESC` have some missingness.
