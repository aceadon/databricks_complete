-- =====================================================================================
-- Tema reference build · Week 1 · gold dimensions
-- Finished state of hr_people_analytics/gold/01_dimensions.sql (labs/week-01, steps 3 to 7).
-- Creates 7 tables in tema_hr_gold. Sensitive personal fields live only in dim_employee_sensitive.
-- Checkpoint at 5,000 people: dim_employee 7,207 · dim_employee_sensitive 7,207 · dim_manager 592 · dim_date 48
-- =====================================================================================
USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS tema_hr_gold
  COMMENT 'Tema (fictional) people analytics star schema. Clean, documented tables for metrics, dashboards and Genie. Synthetic data only.';
USE SCHEMA tema_hr_gold;

CREATE OR REPLACE TABLE dim_department AS
SELECT department_id, department_name, division, cost_center
FROM tema_hr_raw.departments;

CREATE OR REPLACE TABLE dim_location AS
SELECT location_id, city, country, region, location_pay_factor
FROM tema_hr_raw.locations;

CREATE OR REPLACE TABLE dim_job AS
SELECT job_id, job_title, job_family, job_level,
       CASE LEFT(job_level, 1) WHEN 'I' THEN 'Individual contributor'
                               WHEN 'M' THEN 'Manager' ELSE 'Executive' END AS job_track,
       is_manager, salary_band_min, salary_band_mid, salary_band_max
FROM tema_hr_raw.jobs;

-- One row per person ever employed, with their latest assignment. No sensitive fields.
CREATE OR REPLACE TABLE dim_employee AS
WITH last_assignment AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY effective_from DESC) AS rn
  FROM tema_hr_raw.job_history
)
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS employee_name,
       e.work_email,
       e.hire_date, e.termination_date, e.termination_type, e.termination_reason, e.is_regretted,
       e.employment_type, e.hire_source,
       e.termination_date IS NULL AS is_current_employee,
       a.department_id, a.job_id, a.location_id, a.manager_id
FROM tema_hr_raw.employees e
JOIN last_assignment a ON a.employee_id = e.employee_id AND a.rn = 1;

-- Week 1 "Your turn": gender sits here, with the other protected personal data (see solutions/week-01-dimensions.sql).
CREATE OR REPLACE TABLE dim_employee_sensitive AS
SELECT employee_id, date_of_birth, gender, national_id, personal_email, home_postcode
FROM tema_hr_raw.employees;

CREATE OR REPLACE TABLE dim_manager AS
SELECT m.employee_id AS manager_id, m.employee_name AS manager_name,
       j.job_level AS manager_level, m.department_id AS manager_department_id,
       m.is_current_employee AS is_current_manager
FROM dim_employee m
JOIN dim_job j ON j.job_id = m.job_id
WHERE m.employee_id IN (SELECT DISTINCT manager_id FROM tema_hr_raw.job_history WHERE manager_id IS NOT NULL);

-- Month grain: join to facts on month_end = snapshot_month.
CREATE OR REPLACE TABLE dim_date AS
SELECT last_day(month_start) AS month_end,
       month_start,
       year(month_start) AS year,
       quarter(month_start) AS quarter,
       concat(year(month_start), '-Q', quarter(month_start)) AS year_quarter,
       date_format(month_start, 'MMM yyyy') AS month_label,
       month(month_start) IN (3, 6, 9, 12) AS is_quarter_end
FROM (SELECT explode(sequence(DATE'2023-01-01', DATE'2026-12-01', INTERVAL 1 MONTH)) AS month_start);
