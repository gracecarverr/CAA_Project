# CAA Stationary Source Data: Where I Am

## The data

I've been working with EPA's ICIS-Air data — the current administrative database for Clean Air Act stationary source regulation. It covers the full universe of CAA-regulated sources: 279,211 records (PGM ID) 265,490 (FRS ID), of which about 19,000 are classified as major, 37,000 as synthetic minor, and 196,000 as minor. About 66% are currently operating; 28% are permanently closed.

The data is organized around an enforcement pipeline. Each table captures a different stage:

- **Facilities** — the source universe, with classification, location, industry codes, operating status.
- **Programs** — which regulatory programs each source is subject to (SIP, Title V, MACT, NSPS, PSD, FESOP, etc.). 456k records across 267k sources. Median source holds 1 program.
- **Compliance monitoring** — inspections (FCEs and PCEs). 1.8 million records across 151k sources.
- **Violations** — FRVs and HPVs. 101k records across 35k sources.
- **Informal actions** — mostly notices of violation. 336k records across 60k sources.
- **Formal actions** — administrative orders, penalty actions, judicial actions. 106k records across 37k sources.

I also have AFS (the predecessor system, frozen at October 2014), NEI emissions data, and some supplementary ECHO files. I've done basic exploration (structure, missingness, tabulations, cross-tabs) on all the ICIS-Air tables.

## Patterns worth discussing

A few things stood out during exploration that might point toward something:

**The enforcement pipeline leaks, and it leaks differently by actor.** States conduct 88% of compliance monitoring and detect 76% of violations, but EPA's share escalates sharply up the pipeline — 5% of violations, 15% of formal actions, 53% of judicial actions. States almost never go to court. The informal-to-formal action ratio is about 3:1 — most enforcement stops at a notice of violation.

**The major/minor regulatory cliff is steep and quantified.** 88% of major sources hold Title V permits vs. 3% of minor sources. Major sources receive roughly equal absolute numbers of FCE inspections as minor sources despite being 10x fewer facilities. 74% of HPVs and 71% of stack test failures are at major sources. Half of all operating sources (93k) have nothing but a SIP record — no federal technology standard, no Title V, no preconstruction review.

**States differ a lot.** California alone accounts for 15% of all violation records. States vary in their classification mix (TX has an unusually low synthetic minor share; AR and IA have unusually high ones), their enforcement intensity, and their mix of state vs. local agency activity. Whether this reflects real differences in industrial composition, differences in regulatory practice, or differences in data reporting is an open question.

