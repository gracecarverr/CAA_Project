# ICIS-AIR Programs — Exploratory Notes

Explored the facility-program table. Panel: multiple programs per facility, each with begin/updated dates.

## What we checked

- **Missingness** — coverage by column
- **Most common programs** — which regulatory programs appear most
- **Programs per facility** — distribution

## Key numbers

- **456,350 records** across **266,744 unique facilities**.
- **Programs per facility:** mean 1.71, median 1, max 15.
- **Most common programs:** SIP (240,515 records, 53%), MACT (57,396, 13%), NSPS (57,199, 13%), Title V (28,832, 6%).
- **Missingness:** All fields complete — no missing values in any column.

## Key takeaways

- Over half of all program records are SIP (State Implementation Plan), reflecting its role as the baseline CAA regulatory program.
- Most facilities are subject to only one program (median 1), but some are subject to up to 15.
- Many program codes appear rarely (e.g., NAAQS with 5 records, HAPS with 2). These may be data entry artifacts or legacy codes.
