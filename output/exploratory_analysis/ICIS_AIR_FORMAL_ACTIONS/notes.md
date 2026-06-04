# ICIS-AIR Formal Actions — Exploratory Notes

Explored the formal enforcement actions table. Event-level panel: multiple dated actions per facility over time.

## What we checked

- **Missingness** — coverage by column
- **Action type distribution** — administrative formal vs. judicial
- **Agency distribution** — state vs. local vs. EPA
- **Penalty amounts** — summary statistics for non-zero penalties

## Key numbers

- **105,656 records** total.
- **Action types:** 100,326 administrative formal (95%), 5,330 judicial (5%).
- **Agency:** State-led (69,080, 65%), local (20,866, 20%), EPA (15,710, 15%).
- **Penalties (non-zero):** 72,314 actions had a positive penalty. Mean $79,370, median $5,500. 25th percentile $2,000, 75th percentile $18,903. Max $100,728,768.
- **Missingness:** Near-complete across all fields. `SETTLEMENT_ENTERED_DATE` is 0.04% missing. `PENALTY_AMOUNT` is complete (zeros included).
