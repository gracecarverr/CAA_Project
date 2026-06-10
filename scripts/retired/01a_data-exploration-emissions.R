# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets -------------------------------------------------------------------------------------

emissions <- read_csv("data/raw/POLL_RPT_COMBINED_EMISSIONS.csv")

# ---- Output directory ------------------------------------------------------------------------------------

out_dir <- "output/exploratory_analysis/EMISSIONS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration ---------------------------------------------------------------------------------------

nrow(emissions)
n_distinct(emissions$REGISTRY_ID) # 162,383

# Missingness
em_missingness <- data.frame(
    variable = names(emissions),
    n_missing = colSums(is.na(emissions)),
    pct_missing = round(colSums(is.na(emissions)) / nrow(emissions) * 100, 2)
)
write_csv(em_missingness, file.path(out_dir, "emissions_missingness.csv"))

# Year range/records per year
em_by_year <- emissions |>
    count(REPORTING_YEAR, name = "n_records") |>
    arrange(REPORTING_YEAR)
write_csv(em_by_year, file.path(out_dir, "emissions_by_year.csv"))

# Records by program
em_by_program <- emissions |>
    count(PGM_SYS_ACRNM, name = "n_records") |>
    arrange(desc(n_records))
write_csv(em_by_program, file.path(out_dir, "emissions_by_program.csv"))

# Year range by program
em_year_by_program <- emissions |>
    group_by(PGM_SYS_ACRNM) |>
    summarise(min_year = min(REPORTING_YEAR), max_year = max(REPORTING_YEAR))
write_csv(em_year_by_program, file.path(out_dir, "emissions_year_by_program.csv"))
