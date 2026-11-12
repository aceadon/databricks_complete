-- =====================================================================================
-- Tema reference build · Week 3 · workforce_metrics
-- Finished state after labs/week-03 (including the city dimension and the average_salary and
-- span_of_control measures). Checks: metrics/checks/workforce_checks.sql
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
