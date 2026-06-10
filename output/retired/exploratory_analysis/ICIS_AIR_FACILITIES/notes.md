# ICIS-AIR Facilities — Notes

Explored base identification table. One row per facility, no time dimension.

## What I checked

- **Missingness** — coverage by column
- **State distribution** — facility counts by state
- **Emissions classification** — major/synthetic minor/minor split (`AIR_POLLUTANT_CLASS_CODE`)
- **Operating status** — how many facilities are operating, closed, seasonal, etc.
- **HPV status** — how many facilities are currently flagged as High Priority Violators

## Key numbers

- **265,490 facilities** total.
- **Top states:** CO (32,397), IL (28,445), OK (18,359), LA (13,834), NY (12,623).
- **Emissions classification:** 196,214 minor (70%), 37,446 synthetic minor (13%), 19,078 major (7%). 15,379 missing (5.5%).
- **Operating status:** 184,040 operating (66%), 77,065 permanently closed (28%). 12,467 missing (4.5%).
- **HPV status:** 276,076 no violation identified. 1,654 with a violation within 1 year. 466 unaddressed (state), 129 unaddressed (local), 7 unaddressed (EPA).
- **Missingness concerns:** `LOCAL_CONTROL_REGION_CODE` is 96% missing — essentially unusable. `SIC_CODES` 23% missing. `FACILITY_TYPE_CODE` 17% missing. Core identifiers (name, address, state) are near-complete.

## Key takeaways

- This is the spine table — every other ICIS-Air dataset joins to it via `PGM_SYS_ID`.
- No date parsing needed; purely cross-sectional.
- `REGISTRY_ID` (FRS code) is the link to non-ICIS datasets (e.g., emissions, TRI).
