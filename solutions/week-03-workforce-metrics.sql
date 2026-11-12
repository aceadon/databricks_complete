-- =====================================================================================
-- Week 3 answer key: workforce_metrics with the step 4 and step 5 additions
--   Step 4: a `city` dimension (from loc.city), added in the UI editor and copied back here
--   Step 5: `average_salary` and `span_of_control` measures
-- This is the whole file hr_people_analytics/metrics/workforce_metrics.sql should end up as.
-- Untested in Databricks: see the lab's warning box if the YAML is refused.
-- =====================================================================================
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.workforce_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema workforce size and movement. Headcount and FTE are month-end, semi-additive over time."
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
  - name: job_track
    expr: job.job_track
    display_name: Job track
  - name: region
    expr: loc.region
    display_name: Region
  # Step 4: added in the UI editor. The editor may write the keys in a different order or add
  # quotes; that's fine as long as name and expr match.
  - name: city
    expr: loc.city
    display_name: City
  - name: employment_type
    expr: source.employment_type
    display_name: Employment type
measures:
  - name: headcount
    display_name: Headcount
    comment: "People employed at the end of the period. Semi-additive: for a quarter or year, the last month's value."
    synonyms: ["employees", "number of people", "staff"]
    expr: COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: fte
    display_name: FTE
    comment: "Full-time equivalents at the end of the period. Semi-additive like headcount."
    expr: SUM(source.fte) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: hires
    display_name: Hires
    comment: "People who joined in the period. Additive: a quarter is the sum of its months."
    expr: COUNT(1) FILTER (WHERE source.is_hire_in_month)
  - name: leavers
    display_name: Leavers
    comment: "People who left in the period, voluntary and involuntary."
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
  - name: net_change
    display_name: Net change
    comment: "Hires minus leavers."
    expr: MEASURE(hires) - MEASURE(leavers)
  # Step 5
  - name: average_salary
    display_name: Average base salary
    comment: "Average annual base salary (USD, location-adjusted, full-time rate) of people employed at the end of the period. Semi-additive: for a quarter or year, the last month's value. Restricted: see Week 9."
    synonyms: ["average pay", "mean salary"]
    expr: AVG(source.annual_base_salary) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: span_of_control
    display_name: Span of control
    comment: "Active non-managers divided by active managers (manager and executive levels) at the end of the period. A ratio of populations, not the average number of direct reports."
    expr: >
      COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end AND NOT job.is_manager)
      / COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end AND job.is_manager)
    window:
      - order: month
        range: current
        semiadditive: last
$$;

-- -------------------------------------------------------------------------------------
-- Checks (expected values at 5,000 people, computed from the generator in DuckDB)
-- -------------------------------------------------------------------------------------

-- City: Oct 2026 headcount by city should add up to 5,024.
-- San Francisco 1,263 · New York 610 · Bangalore 576 · Seattle 554 · London 533 · Austin 360
-- Dublin 334 · Toronto 277 · Sao Paulo 269 · Singapore 248
SELECT city, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.workforce_metrics
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY headcount DESC;

-- Average salary and span of control
--   Oct 2026: average salary ≈ $151,239, span ≈ 7.49
--   Year 2025 (semi-additive, so December 2025): ≈ $136,789, span ≈ 7.32
SELECT year, MEASURE(average_salary) AS average_salary, MEASURE(span_of_control) AS span
FROM workspace.tema_hr_semantic.workforce_metrics
WHERE year IN (2025, 2026)
GROUP BY ALL ORDER BY year;

-- Truth query for the same numbers
SELECT f.snapshot_month,
       ROUND(AVG(f.annual_base_salary) FILTER (WHERE f.is_active_month_end)) AS average_salary,
       ROUND(COUNT_IF(f.is_active_month_end AND NOT j.is_manager)
             / COUNT_IF(f.is_active_month_end AND j.is_manager), 2)        AS span_of_control
FROM workspace.tema_hr_gold.fact_headcount_monthly f
JOIN workspace.tema_hr_gold.dim_job j ON j.job_id = f.job_id
WHERE f.snapshot_month IN ('2025-12-31', '2026-10-31')
GROUP BY ALL ORDER BY 1;

-- -------------------------------------------------------------------------------------
-- The design questions, answered
-- -------------------------------------------------------------------------------------
-- Should average_salary be semi-additive?
--   Yes. "Average salary in 2025" should mean the average of the people on payroll at the end of 2025
--   (≈ $136,789), the same population as headcount. Without the window it becomes the average over
--   every person-month in the year (≈ $133,899): it weights people by months employed and mixes in
--   people who left. Neither is wrong, but they answer different questions, so name the choice in
--   docs/metric-definitions.md and get it signed off.
--
-- span_of_control caveats worth writing down:
--   * It is a population ratio (≈ 7.49 in Oct 2026). The average number of direct reports per manager
--     is different (≈ 8.48), because managers' direct reports include other managers. If leaders ask
--     "how many reports does a typical manager have?", that needs a different measure built from
--     manager_id.
--   * is_manager comes from the job level (M and E), not from whether someone has reports.
--   * By department it can mislead: a department's ICs may report to a manager in another department.
