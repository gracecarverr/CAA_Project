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
#   Hop 1 links ~70% of AFS facilities to a REGISTRY_ID (164,935 of 236,734 in our run). This is a *coverage*
#   ceiling set by FRS, not a matching defect: among facilities that exist in FRS the match is essentially
#   exact and ~1:1 (only 208 of 164,935 linked AFS_IDs — 0.13% — map to >1 REGISTRY_ID). Section 4 confirms
#   the unmatched ~30% are
#   genuinely ABSENT from the FRS air-program list (0% of a sampled set appear anywhere in the AIR ids), and
#   that they skew toward closed/inactive facilities (operating status "O" matches at ~73%, "X" at ~58%).
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
#
# REPRODUCIBILITY
#   Exploratory only — not part of the analysis pipeline (00_run_all.R). Paths resolve via here::here().
#   Raw inputs are never modified. The one stochastic step (the unmatched-substring diagnostic, which samples
#   ids for speed) sets a seed so the reported number is reproducible.
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

# Are the unmatched facilities genuinely absent from FRS, or just stored under a different id?
# Search a seeded sample of unmatched AFS_IDs for appearance ANYWHERE inside any AIR id.
unmatched <- setdiff(afs_ids, linked_afs)
samp <- sample(unmatched, min(2000L, length(unmatched)))
hits <- vapply(samp, function(a) any(grepl(a, air$PGM_SYS_ID, fixed = TRUE)), logical(1))
cat("\nUnmatched AFS facilities:", length(unmatched), "\n")
cat("Of", length(samp), "sampled, found as a substring anywhere in the AIR ids:",
    sum(hits), "(", round(mean(hits) * 100, 1), "%) -> ~0% confirms they are absent from FRS, not mis-keyed\n")

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
    ICIS_PGM_SYS_ID = paste(sort(unique(ICIS_PGM_SYS_ID[!is.na(ICIS_PGM_SYS_ID)])), collapse = ";"),
    n_icis_ids      = n_distinct(ICIS_PGM_SYS_ID[!is.na(ICIS_PGM_SYS_ID)]),
    .groups = "drop"
  ) |>
  arrange(AFS_ID)

write_csv(crosswalk, file.path(out_dir, "afs_to_icis_crosswalk.csv"))

coverage <- tibble(
  afs_facilities_total    = length(afs_ids),
  afs_linked_to_registry  = length(linked_afs),
  pct_afs_linked          = round(length(linked_afs) / length(afs_ids) * 100, 1),
  afs_ambiguous_multi_reg = nrow(multi),
  afs_with_any_icis_id    = sum(crosswalk$n_icis_ids > 0),
  pct_afs_reaching_icis   = round(sum(crosswalk$n_icis_ids > 0) / length(afs_ids) * 100, 1)
)
write_csv(coverage, file.path(out_dir, "crosswalk_coverage.csv"))

cat("\n====== DONE ======\n")
cat("AFS facilities reaching an ICIS-Air id (end to end):", coverage$afs_with_any_icis_id,
    "(", coverage$pct_afs_reaching_icis, "% of all AFS facilities)\n")
cat("Outputs written to:", out_dir, "\n")
