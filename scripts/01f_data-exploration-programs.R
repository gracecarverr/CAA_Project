# ---- Load packages --------------------------------------------------------------------------------------

library(readr)
library(dplyr)

# ---- Set working directory --------------------------------------------------------------------------------

setwd("/Users/grace/Downloads/CAA_Project")

# ---- Load datasets ---------------------------------------------------------------------------------------

icis_dir <- "data/raw/ICIS-AIR_downloads"
icis_files <- list.files(icis_dir, pattern = "\\.csv$", full.names = TRUE)
icis_data <- lapply(icis_files, read_csv)
names(icis_data) <- gsub("-", "_", tools::file_path_sans_ext(basename(icis_files)))
list2env(icis_data, envir = .GlobalEnv)

# ---- Output directory ------------------------------------------------------------------------------------

out_dir <- "output/exploratory_analysis/ICIS_AIR_PROGRAMS"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Begin exploration -----------------------------------------------------------------------------------

nrow(ICIS_AIR_PROGRAMS)
n_distinct(ICIS_AIR_PROGRAMS$PGM_SYS_ID) # 266,744

# Missingness
prog_miss <- data.frame(
  variable = names(ICIS_AIR_PROGRAMS),
  n_missing = colSums(is.na(ICIS_AIR_PROGRAMS)),
  pct_missing = round(colSums(is.na(ICIS_AIR_PROGRAMS)) / nrow(ICIS_AIR_PROGRAMS) * 100, 2)
)
write_csv(prog_miss, file.path(out_dir, "programs_missingness.csv"))

# Most common programs
prog_by_type <- ICIS_AIR_PROGRAMS |>
  count(PROGRAM_CODE, PROGRAM_DESC, name = "n_records") |>
  arrange(desc(n_records))
write_csv(prog_by_type, file.path(out_dir, "programs_by_type.csv"))

# Programs per facility
prog_per_facility <- ICIS_AIR_PROGRAMS |>
  count(PGM_SYS_ID, name = "n_programs") |>
  summarise(
    n_facilities = n(),
    mean_programs = round(mean(n_programs), 2),
    median_programs = median(n_programs),
    max_programs = max(n_programs)
  )
write_csv(prog_per_facility, file.path(out_dir, "programs_per_facility.csv"))
