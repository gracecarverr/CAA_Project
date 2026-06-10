# ICIS-AIR Informal Actions — Exploration Notes

## Structure

- **336,410 rows.** 10 columns. Near-zero missingness (337 missing ACHIEVED_DATE).
- **60,315 unique PGM_SYS_ID** — about 22% of all sources have an informal action record.
- Every row is ACTIVITY_TYPE_CODE = "AIF" (Administrative - Informal).

## Enforcement type

| Code | Description | n | % |
|---|---|---|---|
| NOV | Notice of Violation | 323,242 | 96.1% |
| DAWL | Warning Letter | 10,488 | 3.1% |
| LREO | Other Response - Letter to Regulated Entity | 1,325 | 0.4% |
| Everything else | — | 855 | 0.3% |

Notices of violation are 96% of informal actions. Warning letters are a distant second.

## State vs EPA

| Flag | n | % |
|---|---|---|
| State | 266,008 | 79.1% |
| Local | 53,285 | 15.8% |
| EPA | 17,117 | 5.1% |

## Cross-tab: activity type × facility classification

| Classification | n | % |
|---|---|---|
| MAJ | 139,408 | 41.4% |
| MIN | 108,836 | 32.4% |
| SMI | 78,100 | 23.2% |

Major sources get the most informal actions, but the gap is narrower here than in formal actions (where MAJ was 54%). Informal enforcement is more spread across the universe.

## Cross-tab: enforcement type × state/EPA flag

NOVs are overwhelmingly state-issued (79%). Warning letters are almost exclusively state (94%). EPA issues NOVs (5% of all NOVs) and a few specialized response types (agency enforcement reviews, information request letters).

## Pipeline context

Informal actions (336k) outnumber formal actions (106k) by about 3:1. This is the first response in the enforcement pipeline — a facility gets a notice of violation before (and often instead of) a formal order or penalty.
