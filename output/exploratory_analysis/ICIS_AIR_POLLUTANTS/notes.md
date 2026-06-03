# ICIS-AIR Pollutants — Exploratory Notes

Explored the facility-pollutant table. Cross-sectional: one row per facility-pollutant combination, no time dimension.

## What I checked

- **Missingness** — coverage by column
- **Unique pollutants** — full list of distinct pollutants in the data
- **Pollutant frequency** — which pollutants appear at the most facilities
- **Pollutants per facility** — distribution of how many pollutants each facility is tracked for
- **Emissions classification** — major/minor/synthetic minor split at the pollutant level

## Key numbers

- **976,479 records** across **255,748 unique facilities**.
- **Pollutants per facility:** mean 3.82, median 2. 37% of facilities have only one pollutant tracked. Max is 277.
- **Most common pollutants:** FACIL (141,981 facilities), VOCs (131,325), total particulate matter (86,845), carbon monoxide (77,117), nitrogen oxides (74,906), PM10 (65,125), sulfur dioxide (54,225), total HAPs (49,640).
- **Emissions classification:** 629,694 minor (64%), 140,554 synthetic minor (14%), 100,341 major (10%), 73,209 unknown (7.5%).
- **Missingness concerns:** `CHEMICAL_ABSTRACT_SERVICE_NMBR` (CAS) is 60% missing — limits linkage to health/tox data for many records. `SRS_ID` is 17% missing. Core fields (`POLLUTANT_CODE`, `AIR_POLLUTANT_CLASS_CODE`) are complete.

## Key takeaways

- A facility's emissions classification (`AIR_POLLUTANT_CLASS_CODE`) can differ by pollutant — a facility might be major for one pollutant and minor for another. This is more granular than the facility-level classification in the Facilities table.
- `CHEMICAL_ABSTRACT_SERVICE_NMBR` (CAS number) is the universal chemical identifier. Useful if linking to toxicological or health data downstream, but 60% missing limits this without additional matching.
- `SRS_ID` is EPA's internal substance registry ID — less portable than CAS but useful within EPA systems.
- "FACIL" is the most common pollutant code — this is a facility-level placeholder, not an actual pollutant. Worth investigating whether to filter it out in analysis.
