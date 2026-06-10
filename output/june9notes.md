# June 9 — Data Exploration Notes

## What I explored today

Systematic exploration of all five ICIS-Air tables: Facilities, Programs, Violations, Compliance Monitoring (FCEs/PCEs), and Formal Actions. Also investigated reclassification signals related to the 2020 "once in always in" policy reversal.

Scripts written:
- `01_explore-facilities.R`
- `02_explore-programs.R`
- `03_explore-violations.R` (renamed from reclassification script)
- `04_explore-compliance.R`
- `05_explore-enforcement.R`
- `02_reclassification-signals.R`
- `03_reclass-nonoilgas.R`

---

## The universe

- 279,211 source-level records in ICIS-Air Facilities.
- 265,490 unique REGISTRY_IDs (facility-level). Most sources map 1:1 to a facility.
- 70% minor, 13% synthetic minor, 7% major, 6% missing/unknown.
- 66% operating, 28% permanently closed.

## Programs

- 456,601 program records across 266,744 sources. Median source holds 1 program; mean 1.71.
- SIP is the baseline (53% of records). MACT (13%) and NSPS (13%) are the main technology standards. Title V (6%) is the major source operating permit.
- Title V tracks major source status closely: it appears on ~88% of major sources but only ~3% of minor sources. That's the regulatory cliff.
- FESOP skews synthetic minor (57% of FESOP records are SMI) — this is the synthetic minor permit, as expected.
- NESHAP (Part 61) has a 60% closure rate — legacy program being replaced by MACT (Part 63).

## The enforcement pipeline

The data tracks four stages: monitoring → violation → formal action → (resolution). EPA's role escalates at each step.

| Stage | Records | Unique sources | EPA share |
|---|---|---|---|
| Compliance monitoring | 1,802,044 | 150,927 (54% of universe) | 3% |
| Violations | 101,147 | 35,336 (13%) | 5% |
| Formal actions | 105,656 | 37,216 (13%) | 15% |
| — Judicial actions | 5,330 | — | 53% |

- States conduct 88% of inspections and detect 76% of violations.
- EPA's share jumps from 3% at monitoring to 15% at enforcement to 53% of judicial actions. States rarely go to court.
- 74% of HPVs (high priority violations) are at major sources. HPV policy is designed around major sources.
- Local agencies play a bigger role in HPV detection (34%) than in FRV detection (7%).

## Compliance monitoring

- Every record is an inspection. Two dominant types: FCE On-Site (36%) and PCE Off-Site (35%).
- Major sources get inspected at a much higher per-facility rate than minor sources. FCE On-Site counts are roughly equal across MAJ/MIN/SMI in absolute terms, but there are 10x fewer major sources.
- EPA's monitoring skews off-site. States do the on-site work.

## Enforcement

- 95% of formal actions are administrative, 5% judicial.
- 83% are state administrative orders (SCAAAO).
- Median penalty: $5,500. Mean: $79,370. Max: $100.7M. Heavily right-skewed.
- Major sources receive disproportionate enforcement action in both administrative (54%) and judicial (53%) categories.

## Reclassification investigation (dead end)

Investigated whether the 2020 "once in always in" reversal left traces in the data.

- Found 2,805 operating facilities with closed MACT programs (strongest signal of reclassification).
- 1,098 post-2018 closures. Oklahoma dominates (492, mostly oil/gas). NAICS 211 and SIC 1311 (oil/gas extraction) are half the story. MACT Subpart ZZZZ (RICE engines) is 66% of records.
- Split into oil/gas (571) and non-oil/gas (527). The non-oil/gas group is diverse: utilities, auto body shops, mining, fabricated metals, hospitals.
- Matched non-oil/gas facilities to NEI emissions: only 14 of 195 with data ever exceeded either HAP threshold. Median HAP emissions well under 1 tpy. These were formally major by potential-to-emit but actually emitting at minor-source levels.
- 2017→2020 panel (85 facilities): median emissions change is essentially zero.
- Pace is steady (~100-165/year), no spike after the 2020 rule.
- Conclusion: reclassification is mostly a paperwork event, not a behavioral change. No outcome to study. Consistent with EPA's own RIA predictions.

Also searched for other natural experiments:
- SSM SIP Call (2015) — has existing research (Lim 2021 JEEM), and the D.C. Circuit largely vacated it in 2024.
- 2015 ozone NAAQS (70 ppb) — nonattainment literature is well occupied (Greenstone, Walker, Curtis lineage).
- Major source threshold bunching — active working paper presented at AEA 2025.

None of these are clear open fields.

## What I still haven't explored

- AFS tables (5 tables, frozen at 2014).
- Emissions data (beyond what was used in reclassification checks).
- Informal actions (if a separate table exists).
- Joining across tables to build a facility-level panel.

## Open questions

- Why does California have 15% of all violation records?
- The per-facility inspection rate gap between major and minor sources — how large is it exactly?
- State-level variation in enforcement intensity — which states inspect more, find more violations, take more actions per violation?
- The 50% Title V closure rate — is this reclassification or facility closure?
- 18% of minor sources have MACT records. Data quality, or real?
