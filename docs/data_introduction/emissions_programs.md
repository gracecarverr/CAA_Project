# EPA Air Emissions Programs

The POLL_RPT_COMBINED_EMISSIONS dataset combines data from four EPA programs. Each covers different pollutants, facilities, time frequencies, and measurement methods.

## NEI (National Emissions Inventory)

- EPA's most comprehensive emissions inventory.
- Covers criteria air pollutants (the NAAQS pollutants: PM, ozone precursors, SO2, NOx, CO, lead) and HAPs from all source types.
- **Triennial** — data every three years (2008, 2011, 2014, etc.).
- Broadest facility coverage but least frequent reporting.

## CAMD (Clean Air Markets Division)

- Continuous emissions monitoring from power plants, primarily for SO2 and NOx.
- These are actual measured emissions from smokestack monitors, not estimates.
- **Annual**, but narrow — only covers power plants in cap-and-trade programs (Acid Rain Program, Cross-State Air Pollution Rule).

## GHGRP (Greenhouse Gas Reporting Program)

- Facility-level greenhouse gas emissions.
- Covers large emitters (generally 25,000+ metric tons CO2e/year).
- **Annual**, starts 2010.
- Separate from criteria pollutants — different pollutants, different units (metric tons CO2-equivalent vs. pounds).

## TRI (Toxics Release Inventory)

- Self-reported releases of toxic chemicals.
- Covers ~770 chemicals, overlaps heavily with HAPs.
- **Annual**, but comes from a different statute (EPCRA, not the Clean Air Act).
- Has its own reporting thresholds and only covers facilities in certain industry sectors with 10+ employees.
- Not every CAA facility reports to TRI, and not every TRI facility is regulated under CAA.

## Important considerations

- **Mixed units.** GHG data is in metric tons CO2-equivalent; everything else is in pounds. Cannot sum across categories without conversion.
- **Coverage gaps.** NEI's triennial schedule means non-NEI years have no criteria pollutant data from that program. The panel has holes depending on which program you're looking at.
- **Different reporting universes.** Each program has its own thresholds for which facilities must report. A facility may appear in one program but not another.
