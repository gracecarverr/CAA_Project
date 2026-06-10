# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
stacks     <- read_csv(file.path(icis_dir, "ICIS-AIR_STACK_TESTS.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/stack-tests"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(stacks)
ncol(stacks)
names(stacks)
n_distinct(stacks$PGM_SYS_ID)

# Tests per source
tests_per <- stacks |> count(PGM_SYS_ID, name = "n_tests")
summary(tests_per$n_tests)

# ---- Missingness ----------------------------------------------------------------------------------------

miss <- data.frame(
  field = names(stacks),
  n_missing = sapply(stacks, function(x) sum(is.na(x)))
)
miss$pct <- round(miss$n_missing / nrow(stacks) * 100, 1)
miss
write_csv(miss, file.path(out_dir, "missingness.csv"))

# ---- State vs EPA ---------------------------------------------------------------------------------------

tab_flag <- stacks |>
  count(STATE_EPA_FLAG, name = "n") |>
  mutate(pct = round(n / nrow(stacks) * 100, 1)) |>
  arrange(desc(n))
tab_flag
write_csv(tab_flag, file.path(out_dir, "tab_state_epa_flag.csv"))

# ---- Test status ----------------------------------------------------------------------------------------

tab_status <- stacks |>
  count(AIR_STACK_TEST_STATUS_CODE, AIR_STACK_TEST_STATUS_DESC, name = "n") |>
  mutate(pct = round(n / nrow(stacks) * 100, 1)) |>
  arrange(desc(n))
tab_status
write_csv(tab_status, file.path(out_dir, "tab_test_status.csv"))

# ---- Cross-tab: test status × facility classification --------------------------------------------------

st_class <- stacks |>
  left_join(
    facilities |> select(PGM_SYS_ID, AIR_POLLUTANT_CLASS_CODE),
    by = "PGM_SYS_ID"
  ) |>
  count(AIR_STACK_TEST_STATUS_CODE, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(AIR_STACK_TEST_STATUS_CODE, desc(n))
st_class
write_csv(st_class, file.path(out_dir, "xtab_status_by_classification.csv"))

# ---- Cross-tab: test status × state/EPA flag -----------------------------------------------------------

st_flag <- stacks |>
  count(AIR_STACK_TEST_STATUS_CODE, STATE_EPA_FLAG, name = "n") |>
  arrange(AIR_STACK_TEST_STATUS_CODE, desc(n))
st_flag
write_csv(st_flag, file.path(out_dir, "xtab_status_by_flag.csv"))
