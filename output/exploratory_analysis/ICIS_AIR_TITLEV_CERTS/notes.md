# ICIS-AIR Title V Certifications — Exploratory Notes

Explored the Title V annual compliance certification table. Event-level panel: multiple dated certifications per facility over time.

## What we checked

- **Missingness** — coverage by column
- **Deviation flag distribution** — whether facilities self-reported deviations
- **Agency distribution** — state vs. local vs. EPA

## Key numbers

- **2,563,435 records** total.
- **Deviation flag:** NA/missing (1,457,440, 57%), No deviation (740,090, 29%), Deviation reported (365,905, 14%).
- **Agency:** State-led (2,097,970, 82%), local (458,785, 18%), EPA (6,680, <1%).
- **Missingness concerns:** `FACILITY_RPT_DEVIATION_FLAG` is 57% missing — the key compliance indicator is unavailable for over half the records. `ACTUAL_END_DATE` is 1% missing.

## Key takeaways

- This is the largest ICIS-Air event table (2.6M records), reflecting annual certification requirements for major sources.
- The deviation flag is the most analytically interesting field — it's a self-reported compliance indicator — but 57% missingness severely limits its usefulness.
- Of the records where the flag is populated, about one-third report deviations (365,905 out of 1,105,995).
