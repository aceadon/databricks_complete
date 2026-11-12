-- =====================================================================================
-- Week 5 answer key
--   Step 2: experience_metrics
--   Step 3: pay_metrics, the compa-ratio question, and the LOD stretch
-- Save each view in its own file in hr_people_analytics/metrics/. Untested in Databricks.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- Step 2. experience_metrics (hr_people_analytics/metrics/experience_metrics.sql)
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.experience_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema engagement survey results, twice a year (May and November). One row per response. Report aggregates only."
source: workspace.tema_hr_gold.fact_engagement
joins:
  - name: dept
    source: workspace.tema_hr_gold.dim_department
    on: source.department_id = dept.department_id
dimensions:
  - name: survey_cycle
    expr: source.survey_cycle
    display_name: Survey cycle
  - name: division
    expr: dept.division
    display_name: Division
  - name: department
    expr: dept.department_name
    display_name: Department
measures:
  - name: responses
    display_name: Responses
    expr: COUNT(1)
  - name: enps
    display_name: eNPS
    comment: "% promoters (9-10) minus % detractors (0-6). Ranges from -100 to +100. Never average enps_score."
    synonyms: ["employee net promoter score", "net promoter"]
    expr: 100.0 * (COUNT(1) FILTER (WHERE source.enps_score >= 9) - COUNT(1) FILTER (WHERE source.enps_score <= 6)) / COUNT(1)
  - name: engagement_score
    display_name: Engagement score
    comment: "Average engagement index, 1 (low) to 5 (high)."
    expr: AVG(source.engagement_score)
  - name: manager_score
    display_name: Manager score
    comment: "Average rating of the direct manager, 1 to 5."
    expr: AVG(source.manager_score)
$$;

-- Check: eNPS, responses and engagement by cycle (5,000 people)
--   2023-H1  -7.1  3,205  3.45   <- after the January 2023 layoffs
--   2023-H2  -1.4  3,179  3.50
--   2024-H1  +3.8  3,172  3.54
--   2024-H2  +8.7  3,200  3.59
--   2025-H1 +12.8  3,318  3.62
--   2025-H2 +12.2  3,435  3.62
--   2026-H1 +16.7  3,743  3.66
SELECT survey_cycle, MEASURE(enps), MEASURE(responses), MEASURE(engagement_score)
FROM workspace.tema_hr_semantic.experience_metrics
GROUP BY ALL ORDER BY survey_cycle;

-- Common mistakes:
--  * AVG(enps_score) gives about 7.6, which is not eNPS at all.
--  * Integer division: 100 * (a - b) / COUNT(1) can round to whole numbers in some engines; 100.0 avoids it.
--  * No time dimension other than survey_cycle: summing eNPS across cycles is meaningless, and it is not
--    additive across divisions either (it's a ratio), which a metric view handles for you.

-- -------------------------------------------------------------------------------------
-- Step 3. pay_metrics (hr_people_analytics/metrics/pay_metrics.sql)
-- Includes a headcount measure and a division dimension, which Week 9 needs.
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.pay_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema pay positioning. Month-end snapshot of active employees; all measures are semi-additive over time. Restricted: pay data."
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
  - name: quarter
    expr: dt.year_quarter
  - name: year
    expr: dt.year
  - name: division
    expr: dept.division
  - name: department
    expr: dept.department_name
  - name: job_level
    expr: job.job_level
  - name: job_track
    expr: job.job_track
  - name: region
    expr: loc.region
measures:
  - name: headcount
    display_name: Headcount
    comment: "People employed at period end. Shown next to pay so small groups are visible."
    expr: COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: avg_compa_ratio
    display_name: Average compa-ratio
    comment: "Base salary / (band midpoint x location pay factor), averaged over people active at period end. 1.00 = paid at midpoint."
    synonyms: ["compa ratio", "pay vs midpoint"]
    expr: AVG(source.annual_base_salary / (job.salary_band_mid * loc.location_pay_factor)) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: average_salary
    display_name: Average base salary
    expr: AVG(source.annual_base_salary) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
$$;

-- "Which job levels have the lowest average compa-ratio?" for October 2026
SELECT job_level, MEASURE(avg_compa_ratio) AS avg_compa_ratio, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.pay_metrics
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY avg_compa_ratio;

-- Expected (5,000 people):
--   E1 0.819 (1 person)  E2 0.998 (1)   <- ignore: one person each, and it shows the CEO's pay
--   IC4 1.024 (630)  M2 1.029  IC2 1.030  IC3 1.030  IC1 1.035  IC5 1.038  IC6 1.042
--   M4 1.061 (23)  M3 1.068  M5 1.072 (6)  M1 1.095 (380)
-- Answer: IC4 is lowest (about 1.02), M1 highest (about 1.10).

-- Common mistake: dividing by salary_band_mid alone. The bands are at San Francisco pay, so without
-- location_pay_factor everyone outside San Francisco looks badly underpaid (Bangalore staff would show
-- a compa-ratio around 0.33).

-- -------------------------------------------------------------------------------------
-- Stretch (LOD): salary vs department average
-- -------------------------------------------------------------------------------------
-- Level-of-detail syntax in metric views is new; check the current docs. The idea, as a measure:
/*
  - name: salary_vs_department_avg
    display_name: Salary vs department average
    comment: "Average of each person's salary divided by their department's average salary in the same month. 1.00 = paid like the department."
    expr: AVG(source.annual_base_salary / <department average at the same month, via an LOD/fixed expression>) FILTER (WHERE source.is_active_month_end)
*/
-- If LOD isn't available, the same number from a plain query, which you can use as the truth:
SELECT month, department, ROUND(AVG(salary / dept_avg), 3) AS salary_vs_department_avg
FROM (
  SELECT f.snapshot_month AS month, d.department_name AS department, f.annual_base_salary AS salary,
         AVG(f.annual_base_salary) OVER (PARTITION BY f.snapshot_month, f.department_id) AS dept_avg
  FROM workspace.tema_hr_gold.fact_headcount_monthly f
  JOIN workspace.tema_hr_gold.dim_department d ON d.department_id = f.department_id
  WHERE f.is_active_month_end
)
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY department;
-- At the department level this is always about 1.00, by construction. It gets interesting when you slice
-- by something else, for example by job_level or gender within department: that's the point of an LOD,
-- the denominator stays at department grain while the query groups by something finer.
