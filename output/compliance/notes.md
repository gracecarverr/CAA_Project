# ICIS-AIR Compliance Monitoring (FCEs/PCEs) — Exploration Notes

## Structure

- **1,802,044 rows.** 10 columns. Zero missingness on core fields.
- **150,927 unique PGM_SYS_ID** — about 54% of all sources have at least one compliance monitoring record.
- Every row is ACTIVITY_TYPE_CODE = "INS" (Inspection/Evaluation). No other activity types.
- PROGRAM_CODES missing 41.5%, ACTIVITY_PURPOSE_DESC missing 39.8%.

## Monitoring type

| Code | Description | n | % |
|---|---|---|---|
| FOO | FCE On-Site | 639,462 | 35.5% |
| PFF | PCE Off-Site | 628,430 | 34.9% |
| PCE | PCE On-Site | 370,070 | 20.5% |
| POR | PCE Record/Report Review | 99,120 | 5.5% |
| POM | PCE Monitoring/Sampling | 37,658 | 2.1% |
| FFO | FCE Off-Site | 21,661 | 1.2% |

FCE On-Site and PCE Off-Site are the two dominant monitoring types, together 70% of records. FCEs are full compliance evaluations (comprehensive); PCEs are partial.

## State vs EPA

| Flag | n | % |
|---|---|---|
| State | 1,580,066 | 87.7% |
| Local | 168,411 | 9.3% |
| EPA | 53,567 | 3.0% |

States conduct 88% of all compliance monitoring. EPA directly conducts only 3%.

## Cross-tab: monitor type × facility classification

FCE On-Site (the most thorough inspection type) is roughly even across MAJ (218k), MIN (222k), and SMI (191k). Given that there are far fewer major sources (~19k) than minor (~196k), major sources get inspected at a much higher per-facility rate.

## Cross-tab: state/EPA flag × monitor type

EPA's monitoring skews toward off-site methods: 23,425 PCE Off-Site vs 11,723 FCE On-Site. States do the bulk of on-site inspections.
