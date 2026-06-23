# ICIS-AIR Violation History — Exploration Notes

## Structure

- **101,147 rows.** 16 columns.
- **35,336 unique PGM_SYS_ID** — most sources have no violations at all (universe is ~279k sources).
- Unit of observation: one violation record per source × compliance determination.

## Missingness

| Field | % Missing | Note |
|---|---|---|
| AIR_LCON_CODE | 81.3% | Local control region — unusable |
| DSCV_PATHWAY_DATE | 62.0% | Discovery pathway date |
| HPV_DAYZERO_DATE | 56.0% | Missing = FRV, not HPV |
| NFTC_PATHWAY_DATE | 47.2% | Notification pathway date |
| EARLIEST_FRV_DETERM_DATE | 37.9% | |
| HPV_RESOLVED_DATE | 32.0% | |
| POLLUTANT_CODES/DESCS | 12.9% | |
| STATE_CODE | 4.7% | 4,800 records |

## Agency type

| Agency | n | % |
|---|---|---|
| State | 77,301 | 76.4% |
| Local | 19,029 | 18.8% |
| U.S. EPA | 4,805 | 4.8% |

States dominate violation detection. EPA directly identifies less than 5% of violations.

## Enforcement response: FRV vs HPV

| Code | n | % |
|---|---|---|
| FRV (federally reportable violation) | 56,657 | 56% |
| HPV (high priority violation) | 44,490 | 44% |

Roughly even split. Of the 44,457 HPVs with a day-zero date, 40,460 (91%) are resolved. 3,997 remain unresolved.

## Program codes

Top violation programs: CAASIP (38.4%), CAATVP (28.3%), CAASIP+CAATVP (6.6%), CAANSPS (3.5%), CAAMACT (3.4%). SIP and Title V dominate. Note: PROGRAM_CODES can contain multiple codes in one field.

## State

Top 5: CA (14.9%), PA (9.0%), TX (5.4%), OK (4.6%), MI (4.6%). California has 3x the violations of the #3 state.

## Cross-tab: enforcement response × facility classification

- **HPV skews major:** 32,890 of 44,490 HPVs (74%) are at major sources. Makes sense — HPV policy targets major sources.
- **FRV is more spread out:** 24,537 MAJ (43%), 17,010 SMI (30%), 13,838 MIN (24%).

## Cross-tab: enforcement response × agency type

- **FRV:** 91% state-detected, 7% local, 2% EPA.
- **HPV:** 58% state, 34% local, 8% EPA. Local agencies play a bigger role in HPV detection than in FRV.
