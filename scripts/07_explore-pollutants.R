# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
pollutants <- read_csv(file.path(icis_dir, "ICIS-AIR_POLLUTANTS.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/pollutants"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(pollutants)
ncol(pollutants)
names(pollutants)
n_distinct(pollutants$PGM_SYS_ID)

# Pollutants per source
pols_per <- pollutants |> count(PGM_SYS_ID, name = "n_pollutants")
summary(pols_per$n_pollutants)

# ---- Missingness ----------------------------------------------------------------------------------------

miss <- data.frame(
  field = names(pollutants),
  n_missing = sapply(pollutants, function(x) sum(is.na(x)))
)
miss$pct <- round(miss$n_missing / nrow(pollutants) * 100, 1)
miss
write_csv(miss, file.path(out_dir, "missingness.csv"))

# ---- Pollutant classification ---------------------------------------------------------------------------

tab_class <- pollutants |>
  count(AIR_POLLUTANT_CLASS_CODE, AIR_POLLUTANT_CLASS_DESC, name = "n") |>
  mutate(pct = round(n / nrow(pollutants) * 100, 1)) |>
  arrange(desc(n))
tab_class
write_csv(tab_class, file.path(out_dir, "tab_pollutant_class.csv"))

# ---- Top pollutants -------------------------------------------------------------------------------------

tab_pollutant <- pollutants |>
  count(POLLUTANT_CODE, POLLUTANT_DESC, name = "n") |>
  mutate(pct = round(n / nrow(pollutants) * 100, 1)) |>
  arrange(desc(n))
tab_pollutant
write_csv(tab_pollutant, file.path(out_dir, "tab_pollutant.csv"))

# ---- Cross-tab: pollutant classification × facility classification -------------------------------------

pol_fac <- pollutants |>
  left_join(
    facilities |> select(PGM_SYS_ID, fac_class = AIR_POLLUTANT_CLASS_CODE),
    by = "PGM_SYS_ID"
  ) |>
  count(AIR_POLLUTANT_CLASS_CODE, fac_class, name = "n") |>
  arrange(AIR_POLLUTANT_CLASS_CODE, desc(n))
pol_fac
write_csv(pol_fac, file.path(out_dir, "xtab_polclass_by_facclass.csv"))

# ---- Cross-tab: top 10 pollutants × pollutant classification -------------------------------------------

top10 <- tab_pollutant |> slice_head(n = 10) |> pull(POLLUTANT_CODE)

pol_by_class <- pollutants |>
  filter(POLLUTANT_CODE %in% top10) |>
  count(POLLUTANT_DESC, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(POLLUTANT_DESC, desc(n))
pol_by_class
write_csv(pol_by_class, file.path(out_dir, "xtab_top10pol_by_class.csv"))
