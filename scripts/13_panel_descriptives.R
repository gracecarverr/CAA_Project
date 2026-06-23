# =========================================================================================================
# 13_panel_descriptives.R
#
# PURPOSE
#   Descriptive statistics and figures for the balanced Title V electric-utility panel. Pure
#   description (no causal claims); the output motivates and frames the later identification work.
#
# INPUT   data/derived/title_v_utility_panel.csv   (built by 12_title_v_utility_panel.R)
# OUTPUT  output/panel_descriptives/   CSV tables (summary stats, transitions, variance decomposition,
#                                      enforcement cascade, COVID comparison) and PNG figures fig1-fig6
#
# Each numbered section is one self-contained analysis; see the comment under each header for what it
# shows and why. Paths use here::here() (anchored on .git) so the script runs from any directory.
# =========================================================================================================

# ---- Load packages --------------------------------------------------------------------------------------

library(here)        # project-root-relative paths
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)      # dollar_format(), axis label helpers
library(patchwork)   # stacking the two-panel penalty figure (fig3)

out_dir <- here("output/panel_descriptives")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)  # ensure target exists on a fresh clone

panel <- read_csv(here("data/derived/title_v_utility_panel.csv"), show_col_types = FALSE)
n_fac <- n_distinct(panel$PGM_SYS_ID)
cat("Panel:", n_fac, "facilities x 10 years =", nrow(panel), "rows\n")

# ==================================================================================================
# 1. SUMMARY STATISTICS
# ==================================================================================================

summary_stats <- panel |>
  summarise(
    across(c(n_eval_total, n_fce, n_pce,
             n_violations, n_hpv, n_frv, n_hpv_resolved,
             n_formal_actions, n_penalty_actions, total_penalty, max_penalty,
             n_informal_actions, n_nov, n_warning_letters,
             n_stack_tests, n_stack_fail, n_certs,
             any_eval, any_fce, any_violation, any_hpv, any_deviation, any_cert,
             any_formal_action, any_epa_formal,
             any_informal_action, any_epa_informal,
             any_stack_test, any_stack_fail),
           list(mean = ~round(mean(.x), 3), sd = ~round(sd(.x), 3),
                min = ~min(.x), max = ~max(.x)),
           .names = "{.col}__{.fn}")
  ) |>
  pivot_longer(everything(),
               names_to = c("variable", "stat"),
               names_sep = "__") |>
  pivot_wider(names_from = stat, values_from = value)

write_csv(summary_stats, file.path(out_dir, "summary_statistics.csv"))
cat("\nSummary statistics:\n")
print(summary_stats, n = 30)

# ==================================================================================================
# 2. TIME SERIES: national rates for all enforcement channels
# ==================================================================================================

ts <- panel |>
  group_by(year) |>
  summarise(
    pct_eval = mean(any_eval) * 100,
    pct_fce = mean(any_fce) * 100,
    pct_violation = mean(any_violation) * 100,
    pct_deviation = mean(any_deviation) * 100,
    pct_formal = mean(any_formal_action) * 100,
    pct_informal = mean(any_informal_action) * 100,
    pct_stack = mean(any_stack_test) * 100,
    pct_stack_fail = mean(any_stack_fail) * 100,
    mean_penalty = mean(total_penalty),
    median_penalty_if_any = median(total_penalty[total_penalty > 0]),
    .groups = "drop"
  )

write_csv(ts, file.path(out_dir, "time_series_national.csv"))

# Fig 1: Monitoring & compliance time series
ts_monitor <- ts |>
  select(year,
         `Any evaluation` = pct_eval,
         `FCE (on/off-site)` = pct_fce,
         `Stack test` = pct_stack,
         `Title V cert filed` = pct_deviation) |>
  pivot_longer(-year, names_to = "measure", values_to = "pct") |>
  mutate(measure = factor(measure, levels = c("Any evaluation", "FCE (on/off-site)",
                                               "Stack test", "Title V cert filed")))

p1 <- ggplot(ts_monitor, aes(x = year, y = pct, color = measure)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_vline(xintercept = 2020, linetype = "dashed", color = "gray40") +
  annotate("text", x = 2020.1, y = 92, label = "COVID\nmemo",
           hjust = 0, size = 3, color = "gray40") +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "Monitoring and compliance activity rates",
       subtitle = paste0("Balanced panel of ", n_fac, " Title V electric utilities"),
       x = "Year", y = "% of facilities", color = NULL) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "fig1_monitoring_time_series.png"), p1, width = 9, height = 5.5, dpi = 200)

# Fig 2: Enforcement response time series
ts_enf <- ts |>
  select(year,
         Violation = pct_violation,
         `Informal action` = pct_informal,
         `Formal action` = pct_formal,
         `Stack test failure` = pct_stack_fail) |>
  pivot_longer(-year, names_to = "measure", values_to = "pct") |>
  mutate(measure = factor(measure, levels = c("Violation", "Informal action",
                                               "Formal action", "Stack test failure")))

p2 <- ggplot(ts_enf, aes(x = year, y = pct, color = measure)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  geom_vline(xintercept = 2020, linetype = "dashed", color = "gray40") +
  annotate("text", x = 2020.1, y = max(ts_enf$pct) * 0.95, label = "COVID\nmemo",
           hjust = 0, size = 3, color = "gray40") +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "Violations and enforcement actions",
       subtitle = paste0("Balanced panel of ", n_fac, " Title V electric utilities"),
       x = "Year", y = "% of facilities", color = NULL) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "fig2_enforcement_time_series.png"), p2, width = 9, height = 5.5, dpi = 200)

# Fig 3: Two-panel penalty figure — extensive margin (top) vs intensive margin (bottom).
# A single "mean penalty per facility-year" series is dominated by a handful of multi-million-dollar
# cases and hides the real trend. Splitting it shows the two margins move differently: the SHARE of
# facilities penalized falls over time (top), while the MEDIAN penalty among those penalized is roughly
# flat (bottom) — i.e. fewer facilities are fined, not smaller fines. Both panels share the year axis.
penalty_by_year <- panel |>
  group_by(year) |>
  summarise(
    pct_penalized = mean(total_penalty > 0) * 100,                 # extensive margin
    median_penalty_if_pos = median(total_penalty[total_penalty > 0]),  # intensive margin
    .groups = "drop"
  )

p3a <- ggplot(penalty_by_year, aes(x = year, y = pct_penalized)) +
  geom_line(linewidth = 1, color = "#b2182b") +
  geom_point(size = 2.5, color = "#b2182b") +
  geom_vline(xintercept = 2020, linetype = "dashed", color = "gray40") +
  annotate("text", x = 2020.1, y = max(penalty_by_year$pct_penalized) * 0.95,
           label = "COVID\nmemo", hjust = 0, size = 3, color = "gray40") +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "% of facilities receiving a penalty",
       x = NULL, y = "% of facilities") +
  theme_minimal(base_size = 12)

p3b <- ggplot(penalty_by_year, aes(x = year, y = median_penalty_if_pos)) +
  geom_line(linewidth = 1, color = "#2166ac") +
  geom_point(size = 2.5, color = "#2166ac") +
  geom_vline(xintercept = 2020, linetype = "dashed", color = "gray40") +
  scale_x_continuous(breaks = 2016:2025) +
  scale_y_continuous(labels = dollar_format()) +
  labs(title = "Median penalty (conditional on penalty > $0)",
       x = "Year", y = "Median penalty ($)") +
  theme_minimal(base_size = 12)

p3 <- p3a / p3b +
  plot_annotation(
    title = "Penalty trends: fewer facilities penalized, stable penalty size",
    subtitle = paste0("Balanced panel of ", n_fac, " Title V electric utilities"),
    theme = theme(plot.title = element_text(size = 14, face = "bold"),
                  plot.subtitle = element_text(size = 11))
  )

ggsave(file.path(out_dir, "fig3_penalty_trends.png"), p3, width = 9, height = 7, dpi = 200)

cat("Saved: fig1, fig2, fig3\n")

# ==================================================================================================
# 3. ENFORCEMENT CASCADE: what fraction of violations lead to actions?
# ==================================================================================================

cascade <- panel |>
  filter(any_violation == 1) |>
  summarise(
    n_facility_years = n(),
    pct_informal = round(mean(any_informal_action) * 100, 1),
    pct_formal = round(mean(any_formal_action) * 100, 1),
    pct_penalty = round(mean(n_penalty_actions > 0) * 100, 1),
    mean_penalty_if_any = round(mean(total_penalty[total_penalty > 0]), 0),
    median_penalty_if_any = round(median(total_penalty[total_penalty > 0]), 0)
  )

cascade_no_viol <- panel |>
  filter(any_violation == 0) |>
  summarise(
    n_facility_years = n(),
    pct_informal = round(mean(any_informal_action) * 100, 1),
    pct_formal = round(mean(any_formal_action) * 100, 1),
    pct_penalty = round(mean(n_penalty_actions > 0) * 100, 1)
  )

cat("\n=== ENFORCEMENT CASCADE ===\n")
cat("Among facility-years WITH a violation:\n")
print(cascade)
cat("\nAmong facility-years WITHOUT a violation:\n")
print(cascade_no_viol)

write_csv(bind_rows(
  cascade |> mutate(group = "With violation"),
  cascade_no_viol |> mutate(group = "No violation")
), file.path(out_dir, "enforcement_cascade.csv"))

# ==================================================================================================
# 4. VARIANCE DECOMPOSITION: all key outcomes
# ==================================================================================================
# Splits each outcome's variance into BETWEEN-facility (differences in facility long-run means) and
# WITHIN-facility (year-to-year movement around a facility's own mean). This is a feasibility check for
# fixed-effects designs: facility FEs absorb the between component, so they only have identifying power
# if a meaningful share of variation is within-facility. A high within share => FE estimation is viable.
# between = var(facility means); within = total - between (the standard one-way ANOVA decomposition).

decompose_var <- function(panel, varname) {
  fac_means <- panel |>
    group_by(PGM_SYS_ID) |>
    summarise(fac_mean = mean(.data[[varname]]), .groups = "drop")
  total <- var(panel[[varname]])
  between <- var(fac_means$fac_mean)
  within <- total - between
  data.frame(variable = varname, total_var = total, between_var = between, within_var = within,
             pct_between = round(between / total * 100, 1),
             pct_within = round(within / total * 100, 1))
}

variance_decomp <- bind_rows(
  decompose_var(panel, "any_violation"),
  decompose_var(panel, "any_eval"),
  decompose_var(panel, "any_deviation"),
  decompose_var(panel, "any_formal_action"),
  decompose_var(panel, "any_informal_action"),
  decompose_var(panel, "any_stack_test"),
  decompose_var(panel, "total_penalty")
)

write_csv(variance_decomp, file.path(out_dir, "variance_decomposition.csv"))
cat("\nVariance decomposition:\n")
print(variance_decomp)

# ==================================================================================================
# 5. VIOLATION PERSISTENCE & ENFORCEMENT RESPONSE
# ==================================================================================================

transitions <- panel |>
  arrange(PGM_SYS_ID, year) |>
  group_by(PGM_SYS_ID) |>
  mutate(
    violation_lag = lag(any_violation),
    formal_lag = lag(any_formal_action),
    informal_lag = lag(any_informal_action),
    penalty_lag = lag(as.integer(total_penalty > 0))
  ) |>
  ungroup() |>
  filter(!is.na(violation_lag))

cat("\n=== VIOLATION TRANSITIONS ===\n")
trans_table <- transitions |>
  group_by(violation_lag) |>
  summarise(
    n = n(),
    pct_violation_next = round(mean(any_violation) * 100, 1),
    pct_formal_next = round(mean(any_formal_action) * 100, 1),
    pct_informal_next = round(mean(any_informal_action) * 100, 1),
    .groups = "drop"
  ) |>
  mutate(violation_lag = ifelse(violation_lag == 1, "Violated in t-1", "No violation in t-1"))

print(trans_table)
write_csv(trans_table, file.path(out_dir, "violation_transitions.csv"))

# Does formal action in t-1 reduce violation in t?
cat("\n=== FORMAL ACTION EFFECT ON FUTURE VIOLATIONS ===\n")
cat("P(violation in t | formal action in t-1):\n")
transitions |>
  group_by(formal_lag) |>
  summarise(n = n(), pct_violation = round(mean(any_violation) * 100, 1), .groups = "drop") |>
  mutate(formal_lag = ifelse(formal_lag == 1, "Formal action in t-1", "No formal action in t-1")) |>
  print()

cat("\nConditional on violation in t-1:\n")
transitions |>
  filter(violation_lag == 1) |>
  group_by(formal_lag) |>
  summarise(n = n(), pct_violation = round(mean(any_violation) * 100, 1), .groups = "drop") |>
  mutate(formal_lag = ifelse(formal_lag == 1, "Formal action in t-1", "No formal action in t-1")) |>
  print()

# Does penalty in t-1 reduce violation in t?
cat("\n=== PENALTY EFFECT ON FUTURE VIOLATIONS ===\n")
cat("P(violation in t | penalty in t-1):\n")
transitions |>
  group_by(penalty_lag) |>
  summarise(n = n(), pct_violation = round(mean(any_violation) * 100, 1), .groups = "drop") |>
  mutate(penalty_lag = ifelse(penalty_lag == 1, "Penalty in t-1", "No penalty in t-1")) |>
  print()

cat("\nConditional on violation in t-1:\n")
transitions |>
  filter(violation_lag == 1) |>
  group_by(penalty_lag) |>
  summarise(n = n(), pct_violation = round(mean(any_violation) * 100, 1), .groups = "drop") |>
  mutate(penalty_lag = ifelse(penalty_lag == 1, "Penalty in t-1", "No penalty in t-1")) |>
  print()

# ==================================================================================================
# 6. DETERRENCE: inspection → future violation
# ==================================================================================================
# Descriptive deterrence check: is being inspected in t-1 associated with fewer violations in t?
# The UNCONDITIONAL version is confounded by targeting/detection — inspections are sent to riskier
# facilities and mechanically reveal violations, so inspected facilities can look MORE violating.
# The CONDITIONAL version restricts to facilities with NO violation in t-1, comparing inspected vs
# not-inspected facilities that were both "clean" at t-1. It is not a causal estimate (inspection is
# still non-random), but it strips out the most obvious detection bias and is the more honest contrast.

cat("\n=== DETERRENCE (INSPECTION → FUTURE VIOLATION) ===\n")
cat("Unconditional:\n")
transitions |>
  group_by(eval_lag = lag(any_eval)) |>
  filter(!is.na(eval_lag)) |>
  summarise(n = n(), pct_violation = round(mean(any_violation) * 100, 1), .groups = "drop") |>
  print()

deterrence <- panel |>
  arrange(PGM_SYS_ID, year) |>
  group_by(PGM_SYS_ID) |>
  mutate(eval_lag = lag(any_eval), violation_lag = lag(any_violation)) |>
  ungroup() |>
  filter(!is.na(eval_lag))

cat("\nConditional on no violation in t-1:\n")
deterrence |>
  filter(violation_lag == 0) |>
  group_by(eval_lag) |>
  summarise(n = n(), pct_violation = round(mean(any_violation) * 100, 1), .groups = "drop") |>
  mutate(eval_lag = ifelse(eval_lag == 1, "Inspected in t-1", "Not inspected in t-1")) |>
  print()

# ==================================================================================================
# 7. COVID COMPARISON: all enforcement channels
# ==================================================================================================
# Compares monitoring/enforcement rates across three periods bracketing EPA's March 2020 COVID
# enforcement-discretion memo. The COVID window is defined as 2020-2021 (the memo took effect in 2020;
# it was rescinded in 2021), with 2016-2019 as the pre-period and 2022-2025 as the post-period. This is
# a simple before/during/after description, NOT a difference-in-differences — there is no control group
# unaffected by the federal memo, so any change here is suggestive, not an estimated policy effect.

covid <- panel |>
  mutate(period = case_when(
    year %in% 2016:2019 ~ "Pre-COVID (2016-19)",
    year %in% 2020:2021 ~ "COVID (2020-21)",
    year %in% 2022:2025 ~ "Post-COVID (2022-25)"
  )) |>
  group_by(period) |>
  summarise(
    facility_years = n(),
    pct_eval = round(mean(any_eval) * 100, 1),
    pct_fce = round(mean(any_fce) * 100, 1),
    pct_violation = round(mean(any_violation) * 100, 1),
    pct_deviation = round(mean(any_deviation) * 100, 1),
    pct_formal = round(mean(any_formal_action) * 100, 1),
    pct_informal = round(mean(any_informal_action) * 100, 1),
    pct_stack = round(mean(any_stack_test) * 100, 1),
    pct_stack_fail = round(mean(any_stack_fail) * 100, 1),
    mean_penalty = round(mean(total_penalty), 0),
    .groups = "drop"
  )

write_csv(covid, file.path(out_dir, "covid_comparison.csv"))
cat("\n=== COVID COMPARISON ===\n")
print(covid)

# ==================================================================================================
# 8. STATE-BY-YEAR HEATMAP: inspection rate
# ==================================================================================================

state_counts <- panel |> distinct(PGM_SYS_ID, STATE) |> count(STATE) |> filter(n >= 15)

state_year <- panel |>
  filter(STATE %in% state_counts$STATE) |>
  group_by(STATE, year) |>
  summarise(pct_eval = mean(any_eval) * 100, .groups = "drop")

p4 <- ggplot(state_year, aes(x = year, y = reorder(STATE, pct_eval, FUN = mean), fill = pct_eval)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_gradient2(low = "#d73027", mid = "#fee08b", high = "#1a9850",
                       midpoint = 75, limits = c(0, 100), name = "% inspected") +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "Inspection rate by state and year",
       subtitle = "States with 15+ facilities in the balanced panel",
       x = "Year", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank())

ggsave(file.path(out_dir, "fig4_state_year_heatmap.png"), p4, width = 10, height = 8, dpi = 200)

# ==================================================================================================
# 9. ENFORCEMENT INTENSITY BY STATE
# ==================================================================================================

state_enf <- panel |>
  filter(STATE %in% state_counts$STATE) |>
  group_by(STATE) |>
  summarise(
    n_facilities = n_distinct(PGM_SYS_ID),
    pct_eval = round(mean(any_eval) * 100, 1),
    pct_violation = round(mean(any_violation) * 100, 1),
    pct_formal = round(mean(any_formal_action) * 100, 1),
    pct_informal = round(mean(any_informal_action) * 100, 1),
    mean_penalty = round(mean(total_penalty), 0),
    .groups = "drop"
  ) |>
  arrange(desc(pct_formal))

write_csv(state_enf, file.path(out_dir, "state_enforcement_summary.csv"))

p5 <- ggplot(state_enf, aes(x = pct_eval, y = pct_violation)) +
  geom_point(aes(size = n_facilities), alpha = 0.6, color = "#2166ac") +
  geom_text(aes(label = STATE), size = 2.5, nudge_y = 0.5) +
  geom_smooth(method = "lm", se = TRUE, color = "#b2182b", linewidth = 0.7) +
  scale_size_continuous(range = c(2, 8), name = "Facilities") +
  labs(title = "State inspection rate vs. violation rate",
       subtitle = paste0(n_fac, " Title V electric utilities, 2016-2025"),
       x = "% facility-years with any evaluation",
       y = "% facility-years with any violation") +
  theme_minimal(base_size = 13)

ggsave(file.path(out_dir, "fig5_state_inspection_vs_violation.png"), p5, width = 9, height = 7, dpi = 200)

# ==================================================================================================
# 10. PENALTY DISTRIBUTION
# ==================================================================================================

penalties <- panel |> filter(total_penalty > 0)
cat("\n=== PENALTY DISTRIBUTION (facility-years with penalty > 0) ===\n")
cat("N:", nrow(penalties), "\n")
cat("Mean: $", round(mean(penalties$total_penalty), 0), "\n")
cat("Median: $", round(median(penalties$total_penalty), 0), "\n")
cat("P25: $", round(quantile(penalties$total_penalty, 0.25), 0), "\n")
cat("P75: $", round(quantile(penalties$total_penalty, 0.75), 0), "\n")
cat("P95: $", round(quantile(penalties$total_penalty, 0.95), 0), "\n")
cat("Max: $", round(max(penalties$total_penalty), 0), "\n")

p6 <- ggplot(penalties, aes(x = total_penalty)) +
  geom_histogram(bins = 50, fill = "#b2182b", color = "white") +
  scale_x_log10(labels = dollar_format()) +
  labs(title = "Distribution of penalties (facility-years with penalty > $0)",
       subtitle = paste0("N = ", nrow(penalties), " facility-years out of ", nrow(panel)),
       x = "Total penalty (log scale)", y = "Facility-years") +
  theme_minimal(base_size = 13)

ggsave(file.path(out_dir, "fig6_penalty_distribution.png"), p6, width = 8, height = 5, dpi = 200)

# ==================================================================================================
# 11. ENFORCEMENT ESCALATION: informal → formal → penalty pipeline
# ==================================================================================================

escalation <- panel |>
  arrange(PGM_SYS_ID, year) |>
  group_by(PGM_SYS_ID) |>
  mutate(
    informal_lag = lag(any_informal_action),
    formal_lag = lag(any_formal_action),
    violation_lag = lag(any_violation)
  ) |>
  ungroup() |>
  filter(!is.na(informal_lag))

cat("\n=== ENFORCEMENT ESCALATION ===\n")
cat("P(formal action in t | informal action in t-1):\n")
escalation |>
  group_by(informal_lag) |>
  summarise(
    n = n(),
    pct_formal = round(mean(any_formal_action) * 100, 1),
    pct_penalty = round(mean(total_penalty > 0) * 100, 1),
    .groups = "drop"
  ) |>
  mutate(informal_lag = ifelse(informal_lag == 1, "Informal in t-1", "No informal in t-1")) |>
  print()

cat("\nConditional on violation in t-1:\n")
escalation |>
  filter(violation_lag == 1) |>
  group_by(informal_lag) |>
  summarise(
    n = n(),
    pct_formal = round(mean(any_formal_action) * 100, 1),
    pct_penalty = round(mean(total_penalty > 0) * 100, 1),
    .groups = "drop"
  ) |>
  mutate(informal_lag = ifelse(informal_lag == 1, "Informal in t-1", "No informal in t-1")) |>
  print()

write_csv(
  escalation |>
    mutate(
      history = paste0(
        ifelse(violation_lag == 1, "Viol", "NoViol"), " + ",
        ifelse(informal_lag == 1, "Informal", "NoInformal"), " + ",
        ifelse(formal_lag == 1, "Formal", "NoFormal")
      )
    ) |>
    group_by(history) |>
    summarise(
      n = n(),
      pct_violation_t = round(mean(any_violation) * 100, 1),
      pct_formal_t = round(mean(any_formal_action) * 100, 1),
      pct_penalty_t = round(mean(total_penalty > 0) * 100, 1),
      mean_penalty_t = round(mean(total_penalty), 0),
      .groups = "drop"
    ) |>
    arrange(desc(pct_violation_t)),
  file.path(out_dir, "escalation_matrix.csv")
)

cat("\nAll outputs saved to:", out_dir, "\n")
