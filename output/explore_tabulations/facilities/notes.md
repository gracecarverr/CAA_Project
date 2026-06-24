# ICIS-AIR Facilities — Exploration Notes

## Structure

- **279,211 rows** (air sources). **19 columns.**
- `PGM_SYS_ID`: 279,211 unique 
- `REGISTRY_ID`: 265,490 unique — multiple air sources can share a facility-level FRS ID.

## Missingness

| Field | % Missing | Note |
|---|---|---|
| `LOCAL_CONTROL_REGION_CODE/NAME` | 95.8% | Essentially unusable |
| `SIC_CODES` | 23.2% | Older classification system; `NAICS_CODES` near-complete (0%) |
| `FACILITY_TYPE_CODE` | 16.9% | Ownership type unknown for ~47k sources |
| `AIR_POLLUTANT_CLASS_CODE` | 5.5% | 15,379 sources with no emissions classification |
| `AIR_OPERATING_STATUS_CODE` | 4.5% | 12,467 sources with no operating status |
| `REGISTRY_ID` | 0.1% | 267 sources with no FRS link |
| Core identifiers (name, address, state, zip) | ~0% | Near-complete |

## Emissions classification

| Code | Description | n | % |
|---|---|---|---|
| MIN | Minor | 196,214 | 70.3% |
| SMI | Synthetic Minor | 37,446 | 13.4% |
| MAJ | Major | 19,078 | 6.8% |
| NA | Missing | 15,379 | 5.5% |
| UNK | Unknown | 7,235 | 2.6% |
| NAP | Not applicable | 2,671 | 1.0% |
| OTH | Other | 1,188 | 0.4% |

Minor sources dominate (70%). Major sources are 7% of the universe but receive disproportionate regulatory attention (Title V permitting, higher inspection frequency).

## Operating status

| Code | Description | n | % |
|---|---|---|---|
| OPR | Operating | 184,040 | 65.9% |
| CLS | Permanently Closed | 77,065 | 27.6% |
| NA | Missing | 12,467 | 4.5% |
| TMP | Temporarily Closed | 4,019 | 1.4% |
| PLN | Planned | 745 | 0.3% |
| CNS | Under Construction | 548 | 0.2% |
| SEA | Seasonal | 327 | 0.1% |

28% of the universe is permanently closed facilities. Any analysis of active regulatory burden should filter to operating sources.

## HPV status

| Status | n | % |
|---|---|---|
| No Violation Identified | 276,076 | 98.9% |
| Violation w/in 1 Year | 1,654 | 0.6% |
| Unaddressed-State | 466 | 0.2% |
| Addressed-State | 325 | 0.1% |
| Violation-Unresolved | 289 | 0.1% |
| Unaddressed-Local | 129 | <0.1% |
| Addressed-Local | 118 | <0.1% |
| Addressed-EPA | 90 | <0.1% |
| Violation Identified | 57 | <0.1% |
| Unaddressed-EPA | 7 | <0.1% |

HPV is rare (1.1% of sources have any current HPV status). State agencies lead enforcement — state-led violations outnumber EPA-led violations by a large margin.

## Facility type

| Code | n | % |
|---|---|---|
| POF | 166,753 | 59.7% |
| NA | 47,222 | 16.9% |
| NON | 40,730 | 14.6% |
| COR | 13,693 | 4.9% |
| CNG | 3,599 | 1.3% |
| CTG | 3,172 | 1.1% |
| FDF | 1,476 | 0.5% |
| STF | 1,418 | 0.5% |
| DIS | 594 | 0.2% |
| TRB | 260 | 0.1% |
| MWD | 176 | 0.1% |
| MXO | 60 | <0.1% |
| SDT | 58 | <0.1% |

17% missing. Code descriptions not included in the data — need to match against data dictionary for labels.

## Geographic distribution

Top 5 states: CO (32,397 — 11.6%), IL (28,445 — 10.2%), OK (18,359 — 6.6%), LA (13,834 — 5.0%), NY (12,623 — 4.5%).

EPA Regions 06 (18.3%), 05 (18.0%), and 08 (15.1%) hold over half the universe. Regions 09 (1.5%) and 10 (1.4%) are smallest.

## Cross-tabulation: classification × operating status

Major sources are disproportionately still operating: 71% of major sources are operating vs. 69% of minor sources. 28% of major sources are permanently closed vs. 28% of minor sources — similar rates. Synthetic minor sources: 72% operating, 27% closed.

## Cross-tabulation: classification × state

States differ in their mix. Some states (e.g., CA, AK) have relatively high shares of major sources. Others (e.g., CO, IL) are dominated by minor sources. Worth investigating whether this reflects real differences in industrial composition or differences in how states classify.
