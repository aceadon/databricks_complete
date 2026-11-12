-- =====================================================================================
-- Tema reference build · Weeks 5 and 9 · pay_metrics
-- labs/week-05, step 3 (compa-ratio; includes headcount and division, which Week 9 needs) and
-- labs/week-09, step 1 (avg_compa_ratio_safe). Oct 2026: IC4 lowest at about 1.02, M1 highest at
-- about 1.10, ignoring E1 and E2 (one person each).
-- If the CASE-around-aggregates form of avg_compa_ratio_safe is refused, delete that measure and use
-- pay_by_level_safe.sql (approach 1) instead.
-- =====================================================================================
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
  # Week 9: the small-group rule inside the measure (approach 2 in labs/week-09, step 1).
  # Grant the broad audience this measure, never avg_compa_ratio or average_salary.
  - name: avg_compa_ratio_safe
    display_name: Average compa-ratio (suppressed under 5)
    comment: "Average compa-ratio, or empty when the group has fewer than 5 people at period end."
    expr: >
      CASE WHEN COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end) >= 5
           THEN AVG(source.annual_base_salary / (job.salary_band_mid * loc.location_pay_factor))
                FILTER (WHERE source.is_active_month_end)
      END
    window:
      - order: month
        range: current
        semiadditive: last
$$;
