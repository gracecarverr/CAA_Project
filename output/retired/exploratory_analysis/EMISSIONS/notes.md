# Air Emissions — Exploratory Notes

Explored the combined emissions dataset (POLL_RPT_COMBINED_EMISSIONS). Panel: facility-pollutant-program-year combinations.

## What we checked

- **Missingness** — coverage by column
- **Records per year** — annual volume
- **Records by program** — NEI vs. CAMD vs. TRI vs. GHGRP
- **Unique facilities**

## Key numbers

- **10,411,871 records** across **162,383 unique facilities** (by `REGISTRY_ID`).
- **Records by program:** NEI/EIS (9,383,110, 90%), TRI/TRIS (798,641, 8%), GHGRP/E-GGRT (196,055, 2%), CAMD/CAMDBS (34,065, <1%).
- **Year coverage:** 2008–2024. NEI years (2008, 2011, 2014, 2017, 2020) have ~1.8–2.1M records each. Non-NEI years have ~100–110k records (TRI + GHGRP + CAMD only).
- **Missingness:** Core fields (year, registry ID, program, pollutant name, unit) are complete. `ANNUAL_EMISSION` is 0.01% missing. `NEI_TYPE` is 10% missing. `NEI_HAP_VOC_FLAG` is 44% missing (only populated for HAP-VOCs).

## Key takeaways

- NEI dominates the dataset at 90% of records because it covers all facility-pollutant combinations, not just large emitters.
- The triennial NEI reporting creates a sawtooth pattern in record counts — huge spikes in NEI years, much smaller volumes in between.
- 162,383 emissions facilities vs. 265,490 ICIS-Air `REGISTRY_ID`s means many regulated facilities have no emissions data in this dataset.
