# ICIS-AIR Stack Tests — Exploration Notes

## Structure

- **646,332 rows.** 10 columns.
- **35,603 unique PGM_SYS_ID** — about 13% of all sources have stack test records.
- Tests per source: median 3, mean 18.2, max 6,205. Heavily skewed — some facilities get tested repeatedly.
- POLLUTANT_DESCS is 100% missing. POLLUTANT_CODES missing 37%.

## State vs EPA

| Flag | n | % |
|---|---|---|
| State | 467,094 | 72.3% |
| Local | 175,363 | 27.1% |
| EPA | 3,875 | 0.6% |

EPA conducts less than 1% of stack tests. Local agencies have a larger role here (27%) than in most other tables.

## Test status

| Status | n | % |
|---|---|---|
| Pass | 573,039 | 88.7% |
| N/A | 46,143 | 7.1% |
| Fail | 20,738 | 3.2% |
| Pending | 5,834 | 0.9% |
| Incomplete | 195 | <0.1% |

89% of stack tests pass. 3.2% fail.

## Cross-tab: test status × facility classification

Failures skew major: 14,786 of 20,738 failures (71%) are at major sources. This parallels the HPV pattern — major sources get more testing and more failures in absolute terms, and far more per facility.

## Cross-tab: test status × state/EPA flag

Failures are mostly state-detected (74%), then local (26%). EPA detects less than 1% of failures.
