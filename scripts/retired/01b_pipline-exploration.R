# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets -------------------------------------------------------------------------------------

pipeline <- read_csv("data/raw/PIPELINE_CAA_00_COMPLETE.csv")

# ---- Output directory ------------------------------------------------------------------------------------

out_dir <- "output/exploratory_analysis/CAA_PIPELINE"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -------------------------------------------------------------------------------------

nrow(pipeline)
n_distinct(pipeline$SOURCE_ID)

# Flag combinations
flag_combos <- pipeline |>
  count(PIPELINE_FLAG, EVAL_FLAG, VIOL_FLAG, FOUND_VIOLATION, EA_FLAG, name = "n_records") |>
  arrange(desc(n_records))
write_csv(flag_combos, file.path(out_dir, "pipeline_flag_combinations.csv"))

# Unique counts (filter NAs before counting distinct)
pipeline_counts <- pipeline |>
  summarise(
    n_rows = n(),
    n_facilities = n_distinct(SOURCE_ID),
    n_violations = n_distinct(VIOL_ACTIVITY_ID[!is.na(VIOL_ACTIVITY_ID)]),
    n_evals = n_distinct(EVAL_ACTIVITY_ID[!is.na(EVAL_ACTIVITY_ID)]),
    n_actions = n_distinct(EA_ACTIVITY_ID[!is.na(EA_ACTIVITY_ID)])
  )
write_csv(pipeline_counts, file.path(out_dir, "pipeline_counts.csv"))

# Example facility with moderate activity (10-20 rows)
example_facility <- pipeline |>
  count(SOURCE_ID, sort = TRUE) |>
  filter(n >= 10, n <= 20) |>
  head(1) |>
  pull(SOURCE_ID)

pipeline |>
  filter(SOURCE_ID == example_facility) |>
  select(SOURCE_ID, PIPELINE_FLAG, EVAL_FLAG, VIOL_FLAG, FOUND_VIOLATION, EA_FLAG,
         EVAL_ACTIVITY_ID, EVAL_DATE,
         VIOL_ACTIVITY_ID, VIOL_TYPE, VIOL_START_DATE,
         EA_ACTIVITY_ID, EA_TYPE, EA_DATE, EA_PENALTY_AMT) |>
  arrange(VIOL_ACTIVITY_ID, EVAL_ACTIVITY_ID, EA_ACTIVITY_ID) |>
  write_csv(file.path(out_dir, "pipeline_example_facility.csv"))
