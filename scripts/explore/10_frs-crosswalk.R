# =========================================================================================================
# 10_frs-crosswalk.R — build a crosswalk from the legacy AFS facility id to the modern ICIS-Air facility
# id, bridged through the EPA Facility Registry Service (FRS).
#
# WHY THIS SCRIPT EXISTS
#   AFS (the pre-2014 Air Facility System) and ICIS-Air (the current system) do not share a facility id.
#   AFS uses AFS_ID (a 10-character state+county+plant code, e.g. 0900100261); ICIS-Air uses PGM_SYS_ID
#   in an unrelated format (e.g. 0100000009003E0010). A direct string match between the two yields zero
#   hits. EPA's intended join path is *through* the Facility Registry Service (FRS), whose REGISTRY_ID is
#   a universal key assigned to each physical facility across every EPA program system. This script
#   recovers that link in two hops:
#
#       AFS_ID  --(hop 1, via FRS)-->  REGISTRY_ID  --(hop 2, direct)-->  ICIS-Air PGM_SYS_ID
#
# THE KEY EMPIRICAL FINDING (hop 1)
#   FRS_PROGRAM_LINKS.csv lists, for every facility, the ids it carries in each program system, tagged by
#   PGM_SYS_ACRNM. The air-program rows (PGM_SYS_ACRNM == "AIR") carry the legacy AFS identifier *embedded*
#   in their PGM_SYS_ID. For the 18-character AIR ids (84% of them), the layout is:
#
#       O K 0 0 0 0 0 0 4 0 0 0 3 0 0 8 0 9
#       <-state-> <--pad--> <---- AFS_ID ---->
#       (2 alpha) (zeros)   (last 10 chars)
#
#   so the AFS_ID is exactly the last 10 characters of the PGM_SYS_ID. Example: OK0000004000300809 -> AFS_ID
#   4000300809 = state 40 (OK) + county 003 + plant 00809.
#
# DECISIONS, AND WHY (each is reproduced/visible in the console output below)
#   (a) Restrict hop 1 to 18-character AIR ids. The 18-char ids (234,717 of 279,245 AIR rows in our run)
#       follow the state+pad+AFS_ID layout above. The shorter ids (6-17 chars) are a different, non-AFS
#       format and do not match any AFS_ID; forcing them in only adds false structure. Section 3 prints the
#       length distribution so this restriction is auditable.
#   (b) Extract via last-10-characters, NOT "strip the state prefix + leading zeros". We tested both. The
#       last-10 rule is exact for 18-char ids. The strip-and-re-pad rule mangles a minority of ids and gives
#       *lower* coverage (52.5% vs 59.3% overall in our run), so we use last-10. Section 3 reproduces the
#       comparison.
#   (c) Read all ids as character. AFS_ID and PGM_SYS_ID have meaningful leading zeros (0900100261); reading
#       them as numeric would silently drop those and break every join.
#   (d) Read only the three FRS columns we need (col_select). FRS_PROGRAM_LINKS.csv is ~590 MB / 4.4M rows;
#       loading three columns instead of thirteen keeps memory and time reasonable.
#
# WHAT ~70% COVERAGE MEANS (and what it does NOT)
#   Hop 1 links ~70% of AFS facilities to a REGISTRY_ID (164,935 of 236,734 in our run). This is the coverage
#   provided by recognizable legacy AFS identifiers in the current FRS AIR links. For identifiers that do
#   link, the mapping is essentially exact and ~1:1 (only 208 of 164,935 linked AFS_IDs — 0.13% — map to
#   >1 REGISTRY_ID). Section 4 confirms
#   that the unmatched ~30% do not carry their recognizable 10-character AFS_ID anywhere in the tested FRS
#   AIR identifiers (0% of a sampled set appear as a substring). That does NOT mean the physical facilities
#   are absent from FRS: Sections 7-10 search for same-name/address candidates under other identifiers.
#   The unmatched group also skews toward closed/inactive facilities (operating status "O" matches at ~73%,
#   "X" at ~58%), but this pattern alone does not establish why an individual identifier is missing.
#
# INPUTS
#   data/raw/afs_downloads/AFS_FACILITIES.csv                 (AFS_ID, OPERATING_STATUS, ...)        [in repo]
#   data/raw/ICIS-AIR_downloads/ICIS-AIR_FACILITIES.csv       (PGM_SYS_ID, REGISTRY_ID, ...)          [in repo]
#   data/frs_downloads/FRS_PROGRAM_LINKS.csv                  (PGM_SYS_ACRNM, PGM_SYS_ID, REGISTRY_ID) [NOT in
#       repo — gitignored, ~590 MB]. Download the FRS "national combined" file from ECHO and unzip into
#       data/frs_downloads/:  https://echo.epa.gov/tools/data-downloads/frs-download-summary
#       (zip: https://echo.epa.gov/files/echodownloads/frs_downloads.zip). The script stops with a clear
#       message if the file is missing.
#
# OUTPUTS  (output/explore_tabulations/frs_crosswalk/)
#   afs_to_icis_crosswalk.csv   one row per linked AFS facility: AFS_ID, REGISTRY_ID, ICIS PGM_SYS_ID(s)
#   crosswalk_coverage.csv      one-row coverage summary (counts and percentages for each hop)
#   unmatched_afs_records.csv   unmatched AFS facilities and their original identifying information
#   unmatched_afs_by_status.csv unmatched counts and rates by AFS operating status
#   unmatched_afs_by_state.csv  unmatched counts and rates by state
#   unmatched_afs_exact_frs_candidates.csv
#                              exact-after-formatting FRS candidates; these are evidence, NOT accepted matches
#   unmatched_afs_exact_icis_candidates.csv
#                              exact-after-formatting ICIS candidates; these are evidence, NOT accepted matches
#   unmatched_afs_candidate_summary.csv
#                              one row per unmatched AFS_ID with candidate counts and evidence flags
#   unmatched_afs_investigation_summary.csv
#                              aggregate counts describing what the exact candidate search found
#
# REPRODUCIBILITY
#   Exploratory only — not part of the analysis pipeline (00_run_all.R). Paths resolve via here::here().
#   Raw inputs are never modified. The one stochastic step (the unmatched-substring diagnostic, which samples
#   ids for speed) sets a seed so the reported number is reproducible.
#
# IMPORTANT INTERPRETATION RULE
#   Sections 7-10 investigate the unmatched AFS records using names, addresses, and geography. They deliberately
#   do NOT add any inferred matches to the crosswalk. Even an exact normalized name/address agreement can refer
#   to the wrong facility (for example, a company can operate several sites with similar names). Candidate pairs
#   must be reviewed, and any fuzzy-matching or acceptance rule must be approved before it is implemented.
# =========================================================================================================

library(here)
library(readr)
library(dplyr)
library(tidyr)

set.seed(1)  # only the substring diagnostic in Section 4 is stochastic (it samples ids); fix it for reproducibility.

out_dir <- here("output/explore_tabulations/frs_crosswalk")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

frs_path <- here("data/frs_downloads/FRS_PROGRAM_LINKS.csv")
if (!file.exists(frs_path)) {
  stop("FRS_PROGRAM_LINKS.csv not found at ", frs_path, ".\n",
       "It is gitignored (~590 MB). Download the FRS national combined file and unzip into\n",
       "data/frs_downloads/:  https://echo.epa.gov/tools/data-downloads/frs-download-summary",
       call. = FALSE)
}

# ============================================================================================
# 1. LOAD INPUTS
#    All ids as character to preserve leading zeros (decision (c)). FRS: only the 3 needed
#    columns (decision (d)).
# ============================================================================================

afs <- read_csv(
  here("data/raw/afs_downloads/AFS_FACILITIES.csv"),
  col_types = cols(AFS_ID = col_character(), OPERATING_STATUS = col_character(), .default = col_guess()),
  show_col_types = FALSE
)
afs_ids <- unique(afs$AFS_ID)

icis <- read_csv(
  here("data/raw/ICIS-AIR_downloads/ICIS-AIR_FACILITIES.csv"),
  col_types = cols(PGM_SYS_ID = col_character(), REGISTRY_ID = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

frs <- read_csv(
  frs_path,
  col_select = c(PGM_SYS_ACRNM, PGM_SYS_ID, REGISTRY_ID),
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)
air <- frs |> filter(PGM_SYS_ACRNM == "AIR")   # the air-program rows carry the embedded AFS_ID

cat("====== INPUTS ======\n")
cat("AFS facilities (unique AFS_ID):", length(afs_ids), "\n")
cat("ICIS-Air facilities:           ", nrow(icis), "\n")
cat("FRS rows tagged 'AIR':         ", nrow(air), "\n")

# ============================================================================================
# 2. HOP 1 — EXTRACT AFS_ID FROM THE 18-CHARACTER AIR ids (last 10 characters)
# ============================================================================================

# Base-R last-10-characters (avoids a stringr dependency, which is not in the project's declared packages).
last10 <- function(x) substr(x, nchar(x) - 9L, nchar(x))

air18 <- air |>
  filter(nchar(PGM_SYS_ID) == 18) |>      # decision (a): only the 18-char ids follow the state+pad+AFS_ID layout
  mutate(afs_key = last10(PGM_SYS_ID))

# afs_id -> registry_id lookup, restricted to keys that are real AFS facilities.
afs_to_reg <- air18 |>
  filter(afs_key %in% afs_ids) |>
  distinct(AFS_ID = afs_key, REGISTRY_ID)

# ============================================================================================
# 3. HOP-1 DIAGNOSTICS — make decisions (a) and (b) auditable
# ============================================================================================

cat("\n====== HOP 1 DIAGNOSTICS ======\n")

cat("\n-- AIR PGM_SYS_ID length distribution (why we restrict to 18-char) --\n")
air |> mutate(L = nchar(PGM_SYS_ID)) |> count(L, name = "n") |> arrange(desc(n)) |> print(n = 20)

cat("\n-- Extraction method comparison (why last-10, not strip-and-repad) --\n")
# The rejected alternative: drop a 2-letter state prefix, drop leading zeros, then left-pad back to 10.
strip_derive <- function(x) {
  b   <- sub("^[A-Za-z]{2}", "", x)              # drop a leading 2-letter state code, if present
  b   <- sub("^0+", "", b)                       # drop leading zeros
  pad <- pmax(0L, 10L - nchar(b))                # left-pad back to 10 with zeros (base R; flag="0" in
  paste0(strrep("0", pad), b)                    #   formatC does NOT zero-pad character input)
}
cmp <- air |> mutate(
  m_last10 = last10(PGM_SYS_ID)       %in% afs_ids,
  m_strip  = strip_derive(PGM_SYS_ID) %in% afs_ids
)
cat("last-10 rule :", sum(cmp$m_last10), "/", nrow(cmp),
    "=", round(mean(cmp$m_last10) * 100, 1), "% match an AFS_ID\n")
cat("strip rule   :", sum(cmp$m_strip),  "/", nrow(cmp),
    "=", round(mean(cmp$m_strip)  * 100, 1), "% match an AFS_ID  (lower -> rejected)\n")

# ============================================================================================
# 4. HOP-1 COVERAGE — what fraction of AFS facilities link, is it 1:1, and why are the rest missing
# ============================================================================================

cat("\n====== HOP 1 COVERAGE ======\n")
linked_afs <- unique(afs_to_reg$AFS_ID)
cat("AFS facilities linked to a REGISTRY_ID:", length(linked_afs), "of", length(afs_ids),
    "(", round(length(linked_afs) / length(afs_ids) * 100, 1), "%)\n")
cat("Distinct REGISTRY_IDs reached:", n_distinct(afs_to_reg$REGISTRY_ID), "\n")

# 1:many check — an AFS_ID mapping to several REGISTRY_IDs would make the join ambiguous.
multi <- afs_to_reg |> count(AFS_ID, name = "n_reg") |> filter(n_reg > 1)
cat("AFS_IDs mapping to >1 REGISTRY_ID (ambiguous):", nrow(multi),
    "(", round(nrow(multi) / length(linked_afs) * 100, 2), "% of linked)\n")

# Are the unmatched AFS identifiers stored somewhere else inside the FRS AIR identifier strings?
# Search a seeded sample of unmatched AFS_IDs for appearance ANYWHERE inside any AIR id.
unmatched <- setdiff(afs_ids, linked_afs)
samp <- sample(unmatched, min(2000L, length(unmatched)))
hits <- vapply(samp, function(a) any(grepl(a, air$PGM_SYS_ID, fixed = TRUE)), logical(1))
cat("\nUnmatched AFS facilities:", length(unmatched), "\n")
cat("Of", length(samp), "sampled, found as a substring anywhere in the AIR ids:",
    sum(hits), "(", round(mean(hits) * 100, 1),
    "%) -> their AFS identifiers are absent from the tested AIR ids; this does not prove the facilities are absent\n")

# Do the unmatched skew toward closed/inactive facilities? (context for the coverage gap)
cat("\n-- Match rate by AFS OPERATING_STATUS --\n")
afs |>
  mutate(matched = AFS_ID %in% linked_afs) |>
  group_by(OPERATING_STATUS) |>
  summarise(n = n(), n_matched = sum(matched), pct_matched = round(mean(matched) * 100, 1), .groups = "drop") |>
  arrange(desc(n)) |>
  print(n = 20)

# ============================================================================================
# 5. HOP 2 — REGISTRY_ID -> ICIS-Air PGM_SYS_ID (direct join; ICIS-AIR_FACILITIES carries REGISTRY_ID)
# ============================================================================================

reg_to_icis <- icis |>
  filter(!is.na(REGISTRY_ID)) |>
  distinct(REGISTRY_ID, ICIS_PGM_SYS_ID = PGM_SYS_ID)

cat("\n====== HOP 2 (REGISTRY_ID -> ICIS-Air) ======\n")
reg_with_icis <- intersect(unique(afs_to_reg$REGISTRY_ID), unique(reg_to_icis$REGISTRY_ID))
cat("AFS-linked REGISTRY_IDs that also appear in ICIS-Air:", length(reg_with_icis),
    "of", n_distinct(afs_to_reg$REGISTRY_ID),
    "(", round(length(reg_with_icis) / n_distinct(afs_to_reg$REGISTRY_ID) * 100, 1), "%)\n")

# ============================================================================================
# 6. ASSEMBLE THE FULL CROSSWALK AND WRITE OUTPUTS
#    A facility can carry more than one ICIS PGM_SYS_ID under one REGISTRY_ID, so we collapse them
#    into a single ';'-separated field and keep one row per (AFS_ID, REGISTRY_ID).
# ============================================================================================

crosswalk <- afs_to_reg |>
  # many-to-many is expected: one REGISTRY_ID can carry several ICIS ids, and (rarely) be reached by
  # several AFS_IDs. The group_by/summarise below collapses it back to one row per (AFS_ID, REGISTRY_ID).
  left_join(reg_to_icis, by = "REGISTRY_ID", relationship = "many-to-many") |>
  group_by(AFS_ID, REGISTRY_ID) |>
  summarise(
    # Count the individual ids before replacing the column with one collapsed text string.
    n_icis_ids      = n_distinct(ICIS_PGM_SYS_ID[!is.na(ICIS_PGM_SYS_ID)]),
    ICIS_PGM_SYS_ID = paste(sort(unique(ICIS_PGM_SYS_ID[!is.na(ICIS_PGM_SYS_ID)])), collapse = ";"),
    .groups = "drop"
  ) |>
  select(AFS_ID, REGISTRY_ID, ICIS_PGM_SYS_ID, n_icis_ids) |>
  arrange(AFS_ID)

write_csv(crosswalk, file.path(out_dir, "afs_to_icis_crosswalk.csv"))

# Count unique AFS facilities, not crosswalk rows: the 208 AFS ids linked to multiple REGISTRY_IDs
# otherwise appear more than once and would slightly inflate the end-to-end coverage statistic.
afs_reaching_icis <- crosswalk |>
  filter(n_icis_ids > 0) |>
  summarise(n = n_distinct(AFS_ID)) |>
  pull(n)

coverage <- tibble(
  afs_facilities_total    = length(afs_ids),
  afs_linked_to_registry  = length(linked_afs),
  pct_afs_linked          = round(length(linked_afs) / length(afs_ids) * 100, 1),
  afs_ambiguous_multi_reg = nrow(multi),
  afs_with_any_icis_id    = afs_reaching_icis,
  pct_afs_reaching_icis   = round(afs_reaching_icis / length(afs_ids) * 100, 1)
)
write_csv(coverage, file.path(out_dir, "crosswalk_coverage.csv"))

cat("\n====== DONE ======\n")
cat("AFS facilities reaching an ICIS-Air id (end to end):", coverage$afs_with_any_icis_id,
    "(", coverage$pct_afs_reaching_icis, "% of all AFS facilities)\n")
cat("Outputs written to:", out_dir, "\n")

# ============================================================================================
# 7. PROFILE THE UNMATCHED AFS FACILITIES
#
# PURPOSE
#   The 30% coverage gap can arise for several different reasons: older closed records may never
#   have been migrated to FRS; an AFS identifier may be missing even though the physical facility
#   exists in FRS; or the record may have changed name/address over time. Before considering any
#   inferred linkage, save the unmatched records and show where the gap is concentrated.
#
# DECISION
#   These tables describe observed differences only. A lower match rate for a group is evidence
#   of unequal coverage, not proof of the administrative reason for that difference.
# ============================================================================================

unmatched_afs <- afs |>
  filter(AFS_ID %in% unmatched) |>
  select(
    AFS_ID, PLANT_ID, PLANT_NAME, PLANT_STREET_ADDRESS, PLANT_CITY, PLANT_COUNTY,
    STATE, ZIP_CODE, EPA_REGION, PRIMARY_SIC_CODE, SECONDARY_SIC_CODE, NAICS_CODE,
    EPA_CLASSIFICATION_CODE, OPERATING_STATUS, FEDERALLY_REPORTABLE
  ) |>
  arrange(AFS_ID)

write_csv(unmatched_afs, file.path(out_dir, "unmatched_afs_records.csv"))

match_status <- afs |>
  distinct(AFS_ID, OPERATING_STATUS) |>
  mutate(is_matched = AFS_ID %in% linked_afs) |>
  group_by(OPERATING_STATUS) |>
  summarise(
    afs_facilities = n(),
    matched_to_frs = sum(is_matched),
    unmatched      = sum(!is_matched),
    pct_matched    = round(matched_to_frs / afs_facilities * 100, 1),
    pct_unmatched  = round(unmatched / afs_facilities * 100, 1),
    .groups = "drop"
  ) |>
  arrange(desc(afs_facilities))

match_state <- afs |>
  distinct(AFS_ID, STATE) |>
  mutate(is_matched = AFS_ID %in% linked_afs) |>
  group_by(STATE) |>
  summarise(
    afs_facilities = n(),
    matched_to_frs = sum(is_matched),
    unmatched      = sum(!is_matched),
    pct_matched    = round(matched_to_frs / afs_facilities * 100, 1),
    pct_unmatched  = round(unmatched / afs_facilities * 100, 1),
    .groups = "drop"
  ) |>
  arrange(desc(unmatched))

write_csv(match_status, file.path(out_dir, "unmatched_afs_by_status.csv"))
write_csv(match_state,  file.path(out_dir, "unmatched_afs_by_state.csv"))

# ============================================================================================
# 8. CREATE CONSERVATIVELY STANDARDIZED COMPARISON FIELDS
#
# PURPOSE
#   Formatting differences such as capitalization, punctuation, repeated spaces, or ZIP+4 should
#   not prevent an otherwise exact comparison.
#
# DECISIONS
#   - Convert text to uppercase, replace punctuation with spaces, and collapse repeated whitespace.
#   - Compare only the first five ZIP-code digits.
#   - Do NOT remove company suffixes ("INC", "LLC"), expand street abbreviations, correct spelling,
#     or calculate fuzzy similarity. Those operations require judgment and can create false matches.
#   - Blank values are kept as NA and are never allowed to form a candidate key.
# ============================================================================================

normalize_text <- function(x) {
  x <- toupper(trimws(x))
  x <- gsub("[[:punct:]]+", " ", x)
  x <- gsub("[[:space:]]+", " ", x)
  x[x == ""] <- NA_character_
  x
}

normalize_zip5 <- function(x) {
  x <- gsub("[^0-9]", "", x)
  x <- substr(x, 1, 5)
  x[nchar(x) != 5] <- NA_character_
  x
}

unmatched_std <- unmatched_afs |>
  mutate(
    name_std    = normalize_text(PLANT_NAME),
    address_std = normalize_text(PLANT_STREET_ADDRESS),
    city_std    = normalize_text(PLANT_CITY),
    state_std   = normalize_text(STATE),
    zip5        = normalize_zip5(ZIP_CODE)
  )

# Keep a compact registry-to-program lookup before releasing the large full FRS program-link table.
# This lets the candidate output distinguish registries with an AIR link from those represented only
# in another EPA program. Presence in another program is useful evidence, but is not itself a match.
registry_programs <- frs |>
  filter(!is.na(REGISTRY_ID), !is.na(PGM_SYS_ACRNM)) |>
  distinct(REGISTRY_ID, PGM_SYS_ACRNM)

rm(cmp, air18, air, frs)
invisible(gc())

# Load the canonical FRS facility file separately. Reading only needed columns limits memory use.
frs_facilities_path <- here("data/frs_downloads/FRS_FACILITIES.csv")
if (!file.exists(frs_facilities_path)) {
  stop("FRS_FACILITIES.csv not found at ", frs_facilities_path, ".\n",
       "It is needed only for the unmatched-record investigation in Sections 8-10.",
       call. = FALSE)
}

frs_facilities <- read_csv(
  frs_facilities_path,
  col_select = c(
    REGISTRY_ID, FAC_NAME, FAC_STREET, FAC_CITY, FAC_STATE, FAC_ZIP,
    FAC_COUNTY, FAC_EPA_REGION
  ),
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) |>
  filter(!is.na(REGISTRY_ID)) |>
  distinct(REGISTRY_ID, .keep_all = TRUE) |>
  mutate(
    name_std    = normalize_text(FAC_NAME),
    address_std = normalize_text(FAC_STREET),
    city_std    = normalize_text(FAC_CITY),
    state_std   = normalize_text(FAC_STATE),
    zip5        = normalize_zip5(FAC_ZIP)
  )

# ============================================================================================
# 9. FIND EXACT-AFTER-FORMATTING FRS CANDIDATES
#
# A candidate is created when an unmatched AFS record and an FRS facility agree on at least one
# conservative key:
#   A. facility name + state + ZIP5
#   B. street address + state + ZIP5
#   C. facility name + city + state
#
# WHY THREE KEYS
#   No single field is complete or unique. Requiring several fields within each key avoids broad
#   name-only or address-only comparisons, while the three alternatives allow for one missing field.
#
# IMPORTANT
#   These are candidate records, not accepted links. A generic name or shared business address can
#   produce multiple candidates. The output records every rule that generated each candidate so a
#   reviewer can evaluate the evidence.
# ============================================================================================

candidate_name_zip <- unmatched_std |>
  filter(!is.na(name_std), !is.na(state_std), !is.na(zip5)) |>
  select(AFS_ID, name_std, state_std, zip5) |>
  inner_join(
    frs_facilities |>
      filter(!is.na(name_std), !is.na(state_std), !is.na(zip5)) |>
      select(REGISTRY_ID, name_std, state_std, zip5),
    by = c("name_std", "state_std", "zip5"),
    relationship = "many-to-many"
  ) |>
  distinct(AFS_ID, REGISTRY_ID) |>
  mutate(candidate_rule = "exact_name_state_zip5")

candidate_address_zip <- unmatched_std |>
  filter(!is.na(address_std), !is.na(state_std), !is.na(zip5)) |>
  select(AFS_ID, address_std, state_std, zip5) |>
  inner_join(
    frs_facilities |>
      filter(!is.na(address_std), !is.na(state_std), !is.na(zip5)) |>
      select(REGISTRY_ID, address_std, state_std, zip5),
    by = c("address_std", "state_std", "zip5"),
    relationship = "many-to-many"
  ) |>
  distinct(AFS_ID, REGISTRY_ID) |>
  mutate(candidate_rule = "exact_address_state_zip5")

candidate_name_city <- unmatched_std |>
  filter(!is.na(name_std), !is.na(city_std), !is.na(state_std)) |>
  select(AFS_ID, name_std, city_std, state_std) |>
  inner_join(
    frs_facilities |>
      filter(!is.na(name_std), !is.na(city_std), !is.na(state_std)) |>
      select(REGISTRY_ID, name_std, city_std, state_std),
    by = c("name_std", "city_std", "state_std"),
    relationship = "many-to-many"
  ) |>
  distinct(AFS_ID, REGISTRY_ID) |>
  mutate(candidate_rule = "exact_name_city_state")

frs_candidate_keys <- bind_rows(
  candidate_name_zip,
  candidate_address_zip,
  candidate_name_city
) |>
  group_by(AFS_ID, REGISTRY_ID) |>
  summarise(
    candidate_rules = paste(sort(unique(candidate_rule)), collapse = ";"),
    n_candidate_rules = n_distinct(candidate_rule),
    .groups = "drop"
  )

candidate_registry_programs <- registry_programs |>
  semi_join(frs_candidate_keys, by = "REGISTRY_ID") |>
  group_by(REGISTRY_ID) |>
  summarise(
    frs_programs = paste(sort(unique(PGM_SYS_ACRNM)), collapse = ";"),
    has_air_program_link = any(PGM_SYS_ACRNM == "AIR"),
    .groups = "drop"
  )

candidate_registry_icis <- reg_to_icis |>
  semi_join(frs_candidate_keys, by = "REGISTRY_ID") |>
  group_by(REGISTRY_ID) |>
  summarise(
    ICIS_PGM_SYS_ID = paste(sort(unique(ICIS_PGM_SYS_ID)), collapse = ";"),
    n_icis_ids = n_distinct(ICIS_PGM_SYS_ID),
    .groups = "drop"
  )

frs_candidates <- frs_candidate_keys |>
  left_join(
    unmatched_afs |>
      select(
        AFS_ID, AFS_NAME = PLANT_NAME, AFS_ADDRESS = PLANT_STREET_ADDRESS,
        AFS_CITY = PLANT_CITY, AFS_STATE = STATE, AFS_ZIP = ZIP_CODE,
        AFS_STATUS = OPERATING_STATUS
      ),
    by = "AFS_ID"
  ) |>
  left_join(
    frs_facilities |>
      select(
        REGISTRY_ID, FRS_NAME = FAC_NAME, FRS_ADDRESS = FAC_STREET,
        FRS_CITY = FAC_CITY, FRS_STATE = FAC_STATE, FRS_ZIP = FAC_ZIP,
        FRS_COUNTY = FAC_COUNTY
      ),
    by = "REGISTRY_ID"
  ) |>
  left_join(candidate_registry_programs, by = "REGISTRY_ID") |>
  left_join(candidate_registry_icis, by = "REGISTRY_ID") |>
  mutate(
    has_air_program_link = coalesce(has_air_program_link, FALSE),
    n_icis_ids = coalesce(n_icis_ids, 0L),
    has_icis_id = n_icis_ids > 0
  ) |>
  arrange(AFS_ID, desc(n_candidate_rules), REGISTRY_ID)

write_csv(
  frs_candidates,
  file.path(out_dir, "unmatched_afs_exact_frs_candidates.csv")
)

# ============================================================================================
# 10. CHECK FOR DIRECT EXACT-AFTER-FORMATTING ICIS-AIR CANDIDATES
#
# PURPOSE
#   An unmatched AFS facility might resemble an ICIS-Air facility even when its formal AFS identifier
#   is absent from FRS. This repeats the same conservative exact-key search directly against ICIS-Air.
#
# IMPORTANT
#   These records also remain candidates only. The script does not use them to alter the crosswalk.
# ============================================================================================

icis_std <- icis |>
  filter(!is.na(PGM_SYS_ID)) |>
  distinct(PGM_SYS_ID, .keep_all = TRUE) |>
  mutate(
    name_std    = normalize_text(FACILITY_NAME),
    address_std = normalize_text(STREET_ADDRESS),
    city_std    = normalize_text(CITY),
    state_std   = normalize_text(STATE),
    zip5        = normalize_zip5(ZIP_CODE)
  )

icis_candidate_name_zip <- unmatched_std |>
  filter(!is.na(name_std), !is.na(state_std), !is.na(zip5)) |>
  select(AFS_ID, name_std, state_std, zip5) |>
  inner_join(
    icis_std |>
      filter(!is.na(name_std), !is.na(state_std), !is.na(zip5)) |>
      select(PGM_SYS_ID, REGISTRY_ID, name_std, state_std, zip5),
    by = c("name_std", "state_std", "zip5"),
    relationship = "many-to-many"
  ) |>
  distinct(AFS_ID, PGM_SYS_ID, REGISTRY_ID) |>
  mutate(candidate_rule = "exact_name_state_zip5")

icis_candidate_address_zip <- unmatched_std |>
  filter(!is.na(address_std), !is.na(state_std), !is.na(zip5)) |>
  select(AFS_ID, address_std, state_std, zip5) |>
  inner_join(
    icis_std |>
      filter(!is.na(address_std), !is.na(state_std), !is.na(zip5)) |>
      select(PGM_SYS_ID, REGISTRY_ID, address_std, state_std, zip5),
    by = c("address_std", "state_std", "zip5"),
    relationship = "many-to-many"
  ) |>
  distinct(AFS_ID, PGM_SYS_ID, REGISTRY_ID) |>
  mutate(candidate_rule = "exact_address_state_zip5")

icis_candidate_name_city <- unmatched_std |>
  filter(!is.na(name_std), !is.na(city_std), !is.na(state_std)) |>
  select(AFS_ID, name_std, city_std, state_std) |>
  inner_join(
    icis_std |>
      filter(!is.na(name_std), !is.na(city_std), !is.na(state_std)) |>
      select(PGM_SYS_ID, REGISTRY_ID, name_std, city_std, state_std),
    by = c("name_std", "city_std", "state_std"),
    relationship = "many-to-many"
  ) |>
  distinct(AFS_ID, PGM_SYS_ID, REGISTRY_ID) |>
  mutate(candidate_rule = "exact_name_city_state")

icis_candidate_keys <- bind_rows(
  icis_candidate_name_zip,
  icis_candidate_address_zip,
  icis_candidate_name_city
) |>
  group_by(AFS_ID, PGM_SYS_ID, REGISTRY_ID) |>
  summarise(
    candidate_rules = paste(sort(unique(candidate_rule)), collapse = ";"),
    n_candidate_rules = n_distinct(candidate_rule),
    .groups = "drop"
  )

icis_candidates <- icis_candidate_keys |>
  left_join(
    unmatched_afs |>
      select(
        AFS_ID, AFS_NAME = PLANT_NAME, AFS_ADDRESS = PLANT_STREET_ADDRESS,
        AFS_CITY = PLANT_CITY, AFS_STATE = STATE, AFS_ZIP = ZIP_CODE,
        AFS_STATUS = OPERATING_STATUS
      ),
    by = "AFS_ID"
  ) |>
  left_join(
    icis |>
      transmute(
        PGM_SYS_ID, REGISTRY_ID,
        ICIS_NAME = FACILITY_NAME, ICIS_ADDRESS = STREET_ADDRESS,
        ICIS_CITY = CITY, ICIS_STATE = STATE, ICIS_ZIP = ZIP_CODE
      ) |>
      distinct(PGM_SYS_ID, REGISTRY_ID, .keep_all = TRUE),
    by = c("PGM_SYS_ID", "REGISTRY_ID")
  ) |>
  arrange(AFS_ID, desc(n_candidate_rules), PGM_SYS_ID)

write_csv(
  icis_candidates,
  file.path(out_dir, "unmatched_afs_exact_icis_candidates.csv")
)

# One-row-per-AFS summary for triage. Counts describe available candidates; they do not say that a
# candidate is correct. In particular, "one candidate" is not automatically a verified match.
candidate_summary <- unmatched_afs |>
  distinct(AFS_ID) |>
  left_join(
    frs_candidates |>
      group_by(AFS_ID) |>
      summarise(
        n_exact_frs_candidates = n_distinct(REGISTRY_ID),
        n_exact_frs_candidates_with_air = n_distinct(REGISTRY_ID[has_air_program_link]),
        n_exact_frs_candidates_with_icis = n_distinct(REGISTRY_ID[has_icis_id]),
        max_frs_candidate_rules = max(n_candidate_rules),
        .groups = "drop"
      ),
    by = "AFS_ID"
  ) |>
  left_join(
    icis_candidates |>
      group_by(AFS_ID) |>
      summarise(
        n_exact_icis_candidates = n_distinct(PGM_SYS_ID),
        max_icis_candidate_rules = max(n_candidate_rules),
        .groups = "drop"
      ),
    by = "AFS_ID"
  ) |>
  mutate(
    across(starts_with("n_"), ~ coalesce(.x, 0L)),
    across(starts_with("max_"), ~ coalesce(.x, 0L)),
    has_any_exact_frs_candidate = n_exact_frs_candidates > 0,
    has_any_exact_icis_candidate = n_exact_icis_candidates > 0
  ) |>
  arrange(AFS_ID)

write_csv(
  candidate_summary,
  file.path(out_dir, "unmatched_afs_candidate_summary.csv")
)

investigation_summary <- tibble(
  measure = c(
    "unmatched_afs_total",
    "with_any_exact_frs_candidate",
    "with_exactly_one_frs_candidate",
    "with_multiple_exact_frs_candidates",
    "with_exact_frs_candidate_having_air_link",
    "with_exact_frs_candidate_having_icis_id",
    "with_any_exact_direct_icis_candidate",
    "with_no_exact_frs_or_icis_candidate"
  ),
  n_afs_ids = c(
    nrow(candidate_summary),
    sum(candidate_summary$n_exact_frs_candidates > 0),
    sum(candidate_summary$n_exact_frs_candidates == 1),
    sum(candidate_summary$n_exact_frs_candidates > 1),
    sum(candidate_summary$n_exact_frs_candidates_with_air > 0),
    sum(candidate_summary$n_exact_frs_candidates_with_icis > 0),
    sum(candidate_summary$n_exact_icis_candidates > 0),
    sum(
      candidate_summary$n_exact_frs_candidates == 0 &
      candidate_summary$n_exact_icis_candidates == 0
    )
  )
) |>
  mutate(pct_of_unmatched = round(n_afs_ids / nrow(candidate_summary) * 100, 1))

write_csv(
  investigation_summary,
  file.path(out_dir, "unmatched_afs_investigation_summary.csv")
)

cat("\n====== UNMATCHED-RECORD INVESTIGATION ======\n")
print(investigation_summary, n = Inf)
cat("\nNo name/address candidate was added to the crosswalk.\n")
cat("Review the candidate files before approving any fuzzy matching or acceptance rule.\n")
