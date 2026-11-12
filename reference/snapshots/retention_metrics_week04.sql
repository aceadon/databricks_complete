-- =====================================================================================
-- Tema reference build · Week 4 snapshot of retention_metrics (before the Week 10 change)
-- The reference build uses this file when you build "through week" 4 to 9, so the numbers match
-- the Week 4 checkpoint: 13.1% for October 2026. From Week 10 on, the build uses
-- hr_people_analytics/metrics/retention_metrics.sql, which excludes part-time employees (12.9%).
-- =====================================================================================
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.retention_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema attrition. Rates divide leavers by average month-end headcount over the same trailing 12 months."
source: workspace.tema_hr_gold.fact_headcount_monthly
joins:
  - name: dt
    source: workspace.tema_hr_gold.dim_date
    on: source.snapshot_month = dt.month_end
  - name: dept
    source: workspace.tema_hr_gold.dim_department
    on: source.department_id = dept.department_id
  - name: job
    source: workspace.tema_hr_gold.dim_job
    on: source.job_id = job.job_id
  - name: loc
    source: workspace.tema_hr_gold.dim_location
    on: source.location_id = loc.location_id
dimensions:
  - name: month
    expr: source.snapshot_month
    display_name: Month
  - name: quarter
    expr: dt.year_quarter
    display_name: Quarter
  - name: year
    expr: dt.year
    display_name: Year
  - name: division
    expr: dept.division
    display_name: Division
  - name: department
    expr: dept.department_name
    display_name: Department
  - name: job_level
    expr: job.job_level
    display_name: Job level
  - name: region
    expr: loc.region
    display_name: Region
measures:
  # Every ratio uses try_divide: an empty window (for example a month the trailing range reaches
  # before the data starts, or a slice with no first-year people) returns NULL instead of a
  # DIVIDE_BY_ZERO error, which serverless SQL raises because ANSI mode is on.
  # Building blocks over the trailing 12 months ending with the period
  - name: leavers_t12m
    display_name: Leavers (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: voluntary_leavers_t12m
    display_name: Voluntary leavers (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_voluntary_termination_in_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: regretted_leavers_t12m
    display_name: Regretted leavers (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_regretted_termination_in_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: avg_headcount_t12m
    display_name: Average headcount (trailing 12 months)
    expr: try_divide(COUNT(1) FILTER (WHERE source.is_active_month_end), COUNT(DISTINCT source.snapshot_month))
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  # The rates people actually ask for
  - name: attrition_rate_t12m
    display_name: Attrition rate (trailing 12 months)
    comment: "All leavers in the 12 months ending with the period, divided by average month-end headcount over those months. The default meaning of 'attrition' at Tema."
    synonyms: ["attrition", "turnover", "attrition rate", "churn"]
    format:
      type: percentage
    expr: try_divide(MEASURE(leavers_t12m), MEASURE(avg_headcount_t12m))
  - name: voluntary_attrition_rate_t12m
    display_name: Voluntary attrition rate (trailing 12 months)
    comment: "People who resigned in the trailing 12 months, divided by the same average headcount as attrition_rate_t12m."
    synonyms: ["voluntary turnover", "resignations rate"]
    expr: try_divide(MEASURE(voluntary_leavers_t12m), MEASURE(avg_headcount_t12m))
  - name: regretted_attrition_rate_t12m
    display_name: Regretted attrition rate (trailing 12 months)
    comment: "Leavers the company wanted to keep, divided by the same average headcount as attrition_rate_t12m."
    synonyms: ["regretted turnover", "regretted losses"]
    expr: try_divide(MEASURE(regretted_leavers_t12m), MEASURE(avg_headcount_t12m))
  # Week 4 "Your turn": people who leave before their one-year mark
  - name: first_year_leavers_t12m
    display_name: First-year leavers (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month AND source.is_first_year)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: first_year_avg_headcount_t12m
    display_name: First-year average headcount (trailing 12 months)
    expr: try_divide(COUNT(1) FILTER (WHERE source.is_active_month_end AND source.is_first_year), COUNT(DISTINCT source.snapshot_month))
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: first_year_attrition_rate_t12m
    display_name: First-year attrition rate (trailing 12 months)
    comment: "Leavers with under 12 months' tenure in the trailing 12 months, divided by the average month-end headcount of people with under 12 months' tenure."
    synonyms: ["new hire attrition", "early attrition", "first year turnover"]
    format:
      type: percentage
    expr: try_divide(MEASURE(first_year_leavers_t12m), MEASURE(first_year_avg_headcount_t12m))
  # Simple monthly flow, additive over time. Counts everyone, part-time included: it answers
  # "how many people left", not "what is our attrition rate".
  - name: leavers
    display_name: Leavers
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
$$;
