# ICIS-AIR Formal Actions — Exploration Notes

## Structure

- **105,656 rows.** 10 columns. Near-zero missingness (41 missing SETTLEMENT_ENTERED_DATE).
- **37,216 unique PGM_SYS_ID** — about 13% of all sources have a formal action record.

## Activity type

| Code | Description | n | % |
|---|---|---|---|
| AFR | Administrative - Formal | 100,326 | 95% |
| JDC | Judicial | 5,330 | 5% |

Almost all enforcement is administrative. Judicial actions are rare.

## Enforcement type

| Code | Description | n | % |
|---|---|---|---|
| SCAAAO | Administrative Order | 87,461 | 82.8% |
| 113D1 | CAA 113D1 Action For Penalty | 6,661 | 6.3% |
| CIV | Civil Judicial Action | 5,300 | 5.0% |
| 113A | CAA 113A Admin Compliance Order (Non-Penalty) | 4,766 | 4.5% |

State administrative orders dominate (83%). Federal penalty actions (113D1) and civil judicial actions are the serious escalations.

## State vs EPA

| Flag | n | % |
|---|---|---|
| State | 69,080 | 65.4% |
| Local | 20,866 | 19.7% |
| EPA | 15,710 | 14.9% |

EPA has a bigger share of enforcement actions (15%) than of compliance monitoring (3%) or violations (5%). EPA's role increases as severity increases through the pipeline.

## Penalties

- 72,314 actions have a nonzero penalty amount (68% of all actions).
- Median penalty: $5,500. Mean: $79,370. Max: $100.7 million.
- Heavily right-skewed — a few very large penalties pull the mean up.

## Cross-tab: activity type × facility classification

- Administrative actions: 54,052 MAJ (54%), 24,889 MIN (25%), 18,518 SMI (18%).
- Judicial actions: 2,839 MAJ (53%), 1,438 MIN (27%), 809 SMI (15%).
- Major sources receive disproportionate enforcement in both types.

## Cross-tab: activity type × state/EPA flag

- Administrative: 67% state, 21% local, 13% EPA.
- Judicial: 53% EPA, 43% state, 3% local. EPA leads judicial enforcement — states rarely go to court.
