# ICIS-AIR Pollutants — Exploration Notes

## Structure

- **976,479 rows.** 7 columns.
- **255,748 unique PGM_SYS_ID** — unit of observation is source × pollutant.
- Pollutants per source: median 2, mean 3.8, max 277.
- CAS number missing for 60% of records. SRS_ID missing for 17%.

## Pollutant classification

Each pollutant record has its own classification (major/minor/SMI) — this is pollutant-specific, not facility-level.

| Classification | n | % |
|---|---|---|
| MIN | 629,694 | 64.5% |
| SMI | 140,554 | 14.4% |
| MAJ | 100,341 | 10.3% |
| UNK | 73,209 | 7.5% |
| NAP | 29,845 | 3.1% |

## Top pollutants

| Pollutant | n | % |
|---|---|---|
| FACIL (facility-level, no specific pollutant) | 141,981 | 14.5% |
| VOCs | 131,325 | 13.4% |
| Total Particulate Matter | 86,845 | 8.9% |
| Carbon monoxide | 77,117 | 7.9% |
| Nitrogen oxides (NO2) | 74,906 | 7.7% |
| PM < 10 μm | 65,125 | 6.7% |
| Sulfur dioxide | 54,225 | 5.6% |
| Total HAPs | 49,640 | 5.1% |
| Formaldehyde | 26,241 | 2.7% |

The criteria pollutants (VOCs, PM, CO, NOx, SO2) and aggregate HAPs dominate. "FACIL" is a facility-level placeholder — no specific pollutant identified. 667 unique pollutant codes total.

## Cross-tab: pollutant classification × facility classification

Mostly aligned — 95% of MAJ pollutant records are at MAJ facilities, 80% of MIN pollutant records are at MIN facilities. But there is some mismatch: 57,780 MIN-classified pollutant records are at MAJ facilities. This makes sense — a major source can be major for one pollutant and minor for others.
