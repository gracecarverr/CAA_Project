# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory ------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load data ------------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
programs   <- read_csv(file.path(icis_dir, "ICIS-AIR_PROGRAMS.csv"), show_col_types = FALSE)
facilities <- read_csv(file.path(icis_dir, "ICIS-AIR_FACILITIES.csv"), show_col_types = FALSE)

# ---- Output directory -----------------------------------------------------------------------------------

out_dir <- "output/programs"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Structure ------------------------------------------------------------------------------------------

nrow(programs)
ncol(programs)
names(programs)
n_distinct(programs$PGM_SYS_ID)

# ---- Missingness ----------------------------------------------------------------------------------------

miss <- data.frame(
  field = names(programs),
  n_missing = sapply(programs, function(x) sum(is.na(x)))
)
miss$pct <- round(miss$n_missing / nrow(programs) * 100, 1)
miss
write_csv(miss, file.path(out_dir, "missingness.csv"))

# ---- Programs per source --------------------------------------------------------------------------------

progs_per <- programs |> count(PGM_SYS_ID, name = "n_programs")
summary(progs_per$n_programs)

# ---- Program code tabulation ---------------------------------------------------------------------------

tab_prog <- programs |>
  count(PROGRAM_CODE, PROGRAM_DESC, name = "n") |>
  mutate(pct = round(n / nrow(programs) * 100, 1)) |>
  arrange(desc(n))
tab_prog
write_csv(tab_prog, file.path(out_dir, "tab_program_code.csv"))

# ---- Program operating status ---------------------------------------------------------------------------

tab_status <- programs |>
  count(AIR_OPERATING_STATUS_CODE, AIR_OPERATING_STATUS_DESC, name = "n") |>
  mutate(pct = round(n / nrow(programs) * 100, 1)) |>
  arrange(desc(n))
tab_status
write_csv(tab_status, file.path(out_dir, "tab_program_status.csv"))

# ---- Cross-tab: program × facility classification ------------------------------------------------------

prog_class <- programs |>
  left_join(
    facilities |> select(PGM_SYS_ID, AIR_POLLUTANT_CLASS_CODE),
    by = "PGM_SYS_ID"
  ) |>
  count(PROGRAM_CODE, AIR_POLLUTANT_CLASS_CODE, name = "n") |>
  arrange(PROGRAM_CODE, desc(n))
prog_class
write_csv(prog_class, file.path(out_dir, "xtab_program_by_classification.csv"))

# ---- Cross-tab: program × program operating status -----------------------------------------------------

prog_status <- programs |>
  count(PROGRAM_CODE, AIR_OPERATING_STATUS_CODE, name = "n") |>
  arrange(PROGRAM_CODE, desc(n))
prog_status
write_csv(prog_status, file.path(out_dir, "xtab_program_by_status.csv"))
