# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)
library(lubridate)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets -------------------------------------------------------------------------------------

emissions <- read_csv("data/raw/POLL_RPT_COMBINED_EMISSIONS.csv")

# ---- Begin exploration ---------------------------------------------------------------------------------------

names(emissions)

# Missingness

em_missingness <- data.frame(
    variable = names(emissions),
    n_missing = colSums(is.na(emissions)),
    pct_missing = round(colSums(is.na(emissions)) / nrow(emissions) * 100, 2)
)
write_csv(em_missingness, "output/exploratory_analysis/emissions_missingness.csv")

# Year range/records per year

em_by_year <- emissions |>
    count(REPORTING_YEAR, name = "n_records") |>
    arrange(REPORTING_YEAR)
write_csv(em_by_year, "output/exploratory_analysis/emissions_by_year.csv")
