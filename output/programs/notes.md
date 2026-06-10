# ICIS-AIR Programs — Exploration Notes

## Structure

- **456,601 rows.** 7 columns. Zero missingness.
- **266,744 unique PGM_SYS_ID** — unit of observation is source × program.
- 31 unique program codes.
- Programs per source: median 1, mean 1.71, max 15.

## Program codes

| Code | Description | n | % |
|---|---|---|---|
| CAASIP | State Implementation Plan | 240,515 | 52.7% |
| CAAMACT | MACT Standards (Part 63) | 57,396 | 12.6% |
| CAANSPS | New Source Performance Standards | 57,199 | 12.5% |
| CAATVP | Title V Permits | 28,832 | 6.3% |
| CAAGACTM | Part 63 Area Sources | 16,161 | 3.5% |
| CAAFESOP | FESOP (Non-Title V) | 12,605 | 2.8% |
| CAANSR | New Source Review | 11,979 | 2.6% |
| CAACFC | Stratospheric Ozone Protection | 8,355 | 1.8% |
| CAAPSD | Prevention of Significant Deterioration | 7,514 | 1.6% |
| CAANESH | NESHAP (Part 61) | 5,159 | 1.1% |

SIP is the baseline — over half of all program records.

## Program operating status

| Status | n | % |
|---|---|---|
| Operating | 317,772 | 69.6% |
| Permanently Closed | 129,954 | 28.5% |
| Temporarily Closed | 5,175 | 1.1% |

Tracks facility-level status closely.

## Cross-tab: program × facility classification

Key patterns from the cross-tab:
- **CAATVP (Title V)**: skews heavily MAJ (14,173 of 28,832). Only ~3% of minor sources hold Title V.
- **CAAMACT**: spread across all classes — 36k MIN, 10k MAJ, 10k SMI. Minor sources with MACT records are worth investigating.
- **CAAFESOP**: skews SMI (7,220) — this is the synthetic minor operating permit, as expected.
- **CAAPSD**: overwhelmingly MAJ (5,593 of 7,514). PSD is a major-source preconstruction program.
- **CAAGACTM (area sources)**: skews MIN (8,900) and SMI (3,795), as expected for an area source standard.

## Cross-tab: program × operating status

- CAANESH (Part 61 NESHAP): 3,096 of 5,159 are CLS (60%) — legacy program being replaced by MACT.
- CAATVP: 14,659 of 28,832 are CLS (51%) — high closure rate.
- CAAMACT: 11,291 of 57,396 are CLS (20%).
- CAASIP: 73,417 of 240,515 are CLS (31%).
