# ICIS-AIR Stack Tests — Exploratory Notes

Explored the stack test results table. Event-level panel: multiple dated tests per facility over time.

## What we checked

- **Missingness** — coverage by column
- **Pass/fail distribution** — test outcomes
- **Agency distribution** — state vs. local vs. EPA

## Key numbers

- **646,332 records** total.
- **Test results:** Pass (573,039, 89%), N/A (46,143, 7%), Fail (20,738, 3%), Pending (5,834, 1%), Incomplete (195, <0.1%). Status code missing for 46,526 (7%).
- **Agency:** State-led (467,094, 72%), local (175,363, 27%), EPA (3,875, <1%).
- **Missingness concerns:** `POLLUTANT_DESCS` is 100% missing. `POLLUTANT_CODES` is 37% missing. `AIR_STACK_TEST_STATUS_CODE` is 7% missing. `ACTUAL_END_DATE` is near-complete (5 missing).

## Key takeaways

- The vast majority of stack tests pass (89%). Only 3% fail outright.
- `POLLUTANT_DESCS` is entirely empty — only `POLLUTANT_CODES` is usable, and even that is 37% missing. Limits the ability to identify which pollutants were tested.
- EPA directly conducts very few stack tests (<1%) — nearly all are state or local.
