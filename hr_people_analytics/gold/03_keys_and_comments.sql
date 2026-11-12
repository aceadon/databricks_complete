-- =====================================================================================
-- Tema reference build · Week 2 · keys and comments
-- Finished state of hr_people_analytics/gold/03_keys_and_comments.sql (labs/week-02, steps 2 and 3).
-- Run after 01_dimensions.sql and 02_facts.sql. Safe to rerun: existing constraints are dropped first.
-- Same content as solutions/week-02-keys-and-comments.sql.
-- =====================================================================================
USE CATALOG workspace;
USE SCHEMA tema_hr_gold;

-- Make the file rerunnable: drop foreign keys first (they depend on the primary keys), then primary keys.
ALTER TABLE fact_headcount_monthly DROP CONSTRAINT IF EXISTS fk_hc_department;
ALTER TABLE fact_headcount_monthly DROP CONSTRAINT IF EXISTS fk_hc_job;
ALTER TABLE fact_headcount_monthly DROP CONSTRAINT IF EXISTS fk_hc_location;
ALTER TABLE fact_headcount_monthly DROP CONSTRAINT IF EXISTS fk_hc_employee;
ALTER TABLE fact_headcount_monthly DROP CONSTRAINT IF EXISTS fk_hc_manager;
ALTER TABLE fact_headcount_monthly DROP CONSTRAINT IF EXISTS fk_hc_month;
ALTER TABLE fact_headcount_monthly DROP CONSTRAINT IF EXISTS pk_fact_headcount_monthly;
ALTER TABLE dim_department         DROP CONSTRAINT IF EXISTS pk_dim_department;
ALTER TABLE dim_job                DROP CONSTRAINT IF EXISTS pk_dim_job;
ALTER TABLE dim_location           DROP CONSTRAINT IF EXISTS pk_dim_location;
ALTER TABLE dim_employee           DROP CONSTRAINT IF EXISTS pk_dim_employee;
ALTER TABLE dim_employee_sensitive DROP CONSTRAINT IF EXISTS pk_dim_employee_sensitive;
ALTER TABLE dim_manager            DROP CONSTRAINT IF EXISTS pk_dim_manager;
ALTER TABLE dim_date               DROP CONSTRAINT IF EXISTS pk_dim_date;

-- -------------------------------------------------------------------------------------
-- STEP 2. KEYS
-- Informational only: Databricks does not enforce them, so check for duplicates yourself.
-- A primary key column must be NOT NULL before ADD CONSTRAINT will accept it.
-- -------------------------------------------------------------------------------------

-- Primary keys on every dimension
ALTER TABLE dim_department ALTER COLUMN department_id SET NOT NULL;
ALTER TABLE dim_department ADD CONSTRAINT pk_dim_department PRIMARY KEY (department_id);

ALTER TABLE dim_job ALTER COLUMN job_id SET NOT NULL;
ALTER TABLE dim_job ADD CONSTRAINT pk_dim_job PRIMARY KEY (job_id);

ALTER TABLE dim_location ALTER COLUMN location_id SET NOT NULL;
ALTER TABLE dim_location ADD CONSTRAINT pk_dim_location PRIMARY KEY (location_id);

ALTER TABLE dim_employee ALTER COLUMN employee_id SET NOT NULL;
ALTER TABLE dim_employee ADD CONSTRAINT pk_dim_employee PRIMARY KEY (employee_id);

ALTER TABLE dim_employee_sensitive ALTER COLUMN employee_id SET NOT NULL;
ALTER TABLE dim_employee_sensitive ADD CONSTRAINT pk_dim_employee_sensitive PRIMARY KEY (employee_id);

ALTER TABLE dim_manager ALTER COLUMN manager_id SET NOT NULL;
ALTER TABLE dim_manager ADD CONSTRAINT pk_dim_manager PRIMARY KEY (manager_id);

ALTER TABLE dim_date ALTER COLUMN month_end SET NOT NULL;
ALTER TABLE dim_date ADD CONSTRAINT pk_dim_date PRIMARY KEY (month_end);

-- Foreign keys from fact_headcount_monthly (the department one is the lab's example).
-- FK columns may stay nullable; the referenced column must already be a primary key.
ALTER TABLE fact_headcount_monthly ADD CONSTRAINT fk_hc_department
  FOREIGN KEY (department_id) REFERENCES dim_department (department_id);
ALTER TABLE fact_headcount_monthly ADD CONSTRAINT fk_hc_job
  FOREIGN KEY (job_id) REFERENCES dim_job (job_id);
ALTER TABLE fact_headcount_monthly ADD CONSTRAINT fk_hc_location
  FOREIGN KEY (location_id) REFERENCES dim_location (location_id);
ALTER TABLE fact_headcount_monthly ADD CONSTRAINT fk_hc_employee
  FOREIGN KEY (employee_id) REFERENCES dim_employee (employee_id);

-- Optional extras (not asked for, but Genie and BI tools benefit)
ALTER TABLE fact_headcount_monthly ADD CONSTRAINT fk_hc_manager
  FOREIGN KEY (manager_id) REFERENCES dim_manager (manager_id);
ALTER TABLE fact_headcount_monthly ADD CONSTRAINT fk_hc_month
  FOREIGN KEY (snapshot_month) REFERENCES dim_date (month_end);
ALTER TABLE fact_headcount_monthly ALTER COLUMN snapshot_month SET NOT NULL;
ALTER TABLE fact_headcount_monthly ALTER COLUMN employee_id SET NOT NULL;
ALTER TABLE fact_headcount_monthly ADD CONSTRAINT pk_fact_headcount_monthly
  PRIMARY KEY (snapshot_month, employee_id);

-- Sanity checks, because nothing above is enforced. Every query should return 0 rows.
SELECT department_id FROM dim_department GROUP BY ALL HAVING COUNT(*) > 1;
SELECT job_id        FROM dim_job        GROUP BY ALL HAVING COUNT(*) > 1;
SELECT location_id   FROM dim_location   GROUP BY ALL HAVING COUNT(*) > 1;
SELECT employee_id   FROM dim_employee   GROUP BY ALL HAVING COUNT(*) > 1;
SELECT manager_id    FROM dim_manager    GROUP BY ALL HAVING COUNT(*) > 1;
SELECT snapshot_month, employee_id FROM fact_headcount_monthly GROUP BY ALL HAVING COUNT(*) > 1;
SELECT f.job_id FROM fact_headcount_monthly f LEFT ANTI JOIN dim_job j ON j.job_id = f.job_id;   -- orphans

-- See what you declared
SELECT table_name, constraint_name, constraint_type
FROM workspace.information_schema.table_constraints
WHERE table_schema = 'tema_hr_gold'
ORDER BY table_name, constraint_type DESC;


-- -------------------------------------------------------------------------------------
-- STEP 3. COMMENTS
-- Every table comment states the grain. Data runs Jan 2023 to Oct 2026 (as of 2026-10-31).
-- -------------------------------------------------------------------------------------

-- ===== dim_department =====
COMMENT ON TABLE dim_department IS
  'One row per department (23 departments in 6 divisions). Use division to roll departments up.';
ALTER TABLE dim_department ALTER COLUMN department_id   COMMENT 'Department identifier (primary key). Join from department_id on any fact table.';
ALTER TABLE dim_department ALTER COLUMN department_name COMMENT 'Department name, for example Trust & Safety Operations.';
ALTER TABLE dim_department ALTER COLUMN division        COMMENT 'Division the department belongs to: Engineering, AI, Product & Design, Ads Business, Trust & Safety or Corporate. The top level of the org hierarchy below the CEO.';
ALTER TABLE dim_department ALTER COLUMN cost_center     COMMENT 'Finance cost center code for the department, for example CC-5010.';

-- ===== dim_location =====
COMMENT ON TABLE dim_location IS
  'One row per office location (10 cities in Americas, EMEA and APAC).';
ALTER TABLE dim_location ALTER COLUMN location_id         COMMENT 'Location identifier (primary key).';
ALTER TABLE dim_location ALTER COLUMN city                COMMENT 'Office city.';
ALTER TABLE dim_location ALTER COLUMN country             COMMENT 'Country of the office.';
ALTER TABLE dim_location ALTER COLUMN region              COMMENT 'Global region: Americas, EMEA or APAC.';
ALTER TABLE dim_location ALTER COLUMN location_pay_factor COMMENT 'Pay multiplier for this location relative to San Francisco (1.00). Salaries are already adjusted by this; multiply salary bands by it to compare a salary with its band.';

-- ===== dim_job =====
COMMENT ON TABLE dim_job IS
  'One row per job (a level within a department, so the same level in two departments is two jobs).';
ALTER TABLE dim_job ALTER COLUMN job_id          COMMENT 'Job identifier (primary key).';
ALTER TABLE dim_job ALTER COLUMN job_title       COMMENT 'Job title, for example Senior Core Platform or Director, Policy.';
ALTER TABLE dim_job ALTER COLUMN job_family      COMMENT 'Job family. At Tema this is the department name the job belongs to.';
ALTER TABLE dim_job ALTER COLUMN job_level       COMMENT 'Career level code. IC1 to IC6 individual contributors, M1 Manager to M5 Senior Vice President, E1 CEO, E2 Chief People Officer. Higher number is more senior within a track.';
ALTER TABLE dim_job ALTER COLUMN job_track       COMMENT 'Career track derived from job_level: Individual contributor (IC), Manager (M) or Executive (E).';
ALTER TABLE dim_job ALTER COLUMN is_manager      COMMENT 'True for manager and executive levels (M and E). A job flag; it does not mean the person currently has direct reports.';
ALTER TABLE dim_job ALTER COLUMN salary_band_min COMMENT 'Bottom of the annual base salary band in USD, at San Francisco pay (location factor 1.00). Multiply by dim_location.location_pay_factor before comparing with a salary.';
ALTER TABLE dim_job ALTER COLUMN salary_band_mid COMMENT 'Midpoint of the annual base salary band in USD, at San Francisco pay (location factor 1.00). Compa-ratio = annual_base_salary / (salary_band_mid * location_pay_factor).';
ALTER TABLE dim_job ALTER COLUMN salary_band_max COMMENT 'Top of the annual base salary band in USD, at San Francisco pay (location factor 1.00). Multiply by dim_location.location_pay_factor before comparing with a salary.';

-- ===== dim_employee =====
COMMENT ON TABLE dim_employee IS
  'One row per person ever employed by Tema, current or former, with their latest assignment (current job, or last job before leaving). No sensitive personal fields; those are in dim_employee_sensitive. For history over time use fact_headcount_monthly.';
ALTER TABLE dim_employee ALTER COLUMN employee_id         COMMENT 'Employee identifier (primary key). Never reused.';
ALTER TABLE dim_employee ALTER COLUMN employee_name       COMMENT 'First and last name. Synthetic.';
ALTER TABLE dim_employee ALTER COLUMN work_email          COMMENT 'Company email address. Synthetic.';
ALTER TABLE dim_employee ALTER COLUMN hire_date           COMMENT 'First day of employment at Tema.';
ALTER TABLE dim_employee ALTER COLUMN termination_date    COMMENT 'Last day of employment. Empty for current employees.';
ALTER TABLE dim_employee ALTER COLUMN termination_type    COMMENT 'Voluntary (the person resigned) or Involuntary (Tema ended employment, including layoffs). Empty for current employees.';
ALTER TABLE dim_employee ALTER COLUMN termination_reason  COMMENT 'Main reason for leaving. Voluntary: Career growth, Compensation, Manager, Relocation, Work-life balance, Competitor offer, Other. Involuntary: Performance, Restructuring, Policy violation. Empty for current employees.';
ALTER TABLE dim_employee ALTER COLUMN is_regretted        COMMENT 'True if the company wanted to keep this person when they left (a regretted loss). Only set for leavers; empty for current employees. Involuntary leavers are always false.';
ALTER TABLE dim_employee ALTER COLUMN employment_type     COMMENT 'Full-time or Part-time.';
ALTER TABLE dim_employee ALTER COLUMN hire_source         COMMENT 'Recruiting channel the person was hired through: Referral, Job board, Agency, Careers site or University.';
ALTER TABLE dim_employee ALTER COLUMN is_current_employee COMMENT 'True if the person had not left as of the data end date (2026-10-31). Not usable for headcount at a past date; use fact_headcount_monthly.is_active_month_end.';
ALTER TABLE dim_employee ALTER COLUMN department_id       COMMENT 'Department of the latest assignment (current, or at leaving). Join to dim_department.';
ALTER TABLE dim_employee ALTER COLUMN job_id              COMMENT 'Job of the latest assignment (current, or at leaving). Join to dim_job.';
ALTER TABLE dim_employee ALTER COLUMN location_id         COMMENT 'Location of the latest assignment (current, or at leaving). Join to dim_location.';
ALTER TABLE dim_employee ALTER COLUMN manager_id          COMMENT 'employee_id of the direct manager in the latest assignment. Empty for the CEO. Join to dim_manager.manager_id.';

-- ===== dim_employee_sensitive =====
COMMENT ON TABLE dim_employee_sensitive IS
  'One row per person ever employed (same rows as dim_employee). Restricted personal data: access only for people with a need to know, such as the HRBP for that org. Join to dim_employee on employee_id. Synthetic data only.';
ALTER TABLE dim_employee_sensitive ALTER COLUMN employee_id    COMMENT 'Employee identifier (primary key). Same as dim_employee.employee_id.';
ALTER TABLE dim_employee_sensitive ALTER COLUMN date_of_birth  COMMENT 'Date of birth. Restricted personal data.';
ALTER TABLE dim_employee_sensitive ALTER COLUMN gender         COMMENT 'Self-reported gender: Female, Male, Non-binary or Undisclosed. Restricted personal data; report only in aggregates large enough not to identify anyone.';
ALTER TABLE dim_employee_sensitive ALTER COLUMN national_id    COMMENT 'Government-issued identification number. Restricted. Never needed for analytics.';
ALTER TABLE dim_employee_sensitive ALTER COLUMN personal_email COMMENT 'Personal (non-company) email address. Restricted personal data.';
ALTER TABLE dim_employee_sensitive ALTER COLUMN home_postcode  COMMENT 'Home postal code. Restricted personal data.';

-- ===== dim_manager =====
COMMENT ON TABLE dim_manager IS
  'One row per person who has directly managed someone at any point in job history, with their latest level and department. A role-playing view of dim_employee for the manager side of a join.';
ALTER TABLE dim_manager ALTER COLUMN manager_id            COMMENT 'employee_id of the manager (primary key). Join from manager_id on any fact table.';
ALTER TABLE dim_manager ALTER COLUMN manager_name          COMMENT 'Manager first and last name.';
ALTER TABLE dim_manager ALTER COLUMN manager_level         COMMENT 'Job level of the manager in their latest assignment, for example M1 or M3. Not necessarily their level when a given report reported to them.';
ALTER TABLE dim_manager ALTER COLUMN manager_department_id COMMENT 'Department of the manager in their latest assignment. Can differ from the department of their reports.';
ALTER TABLE dim_manager ALTER COLUMN is_current_manager    COMMENT 'True if the manager is still employed at Tema (2026-10-31). Does not check that they still have direct reports.';

-- ===== dim_date =====
COMMENT ON TABLE dim_date IS
  'One row per calendar month, Jan 2023 to Dec 2026 (48 rows). Facts run to Oct 2026, so Nov and Dec 2026 have no data. Join on month_end.';
ALTER TABLE dim_date ALTER COLUMN month_end      COMMENT 'Last day of the month (primary key). Join to fact_headcount_monthly.snapshot_month and the *_month columns on other facts.';
ALTER TABLE dim_date ALTER COLUMN month_start    COMMENT 'First day of the month.';
ALTER TABLE dim_date ALTER COLUMN year           COMMENT 'Calendar year.';
ALTER TABLE dim_date ALTER COLUMN quarter        COMMENT 'Calendar quarter, 1 to 4. Tema uses calendar quarters.';
ALTER TABLE dim_date ALTER COLUMN year_quarter   COMMENT 'Year and quarter label, for example 2026-Q1. Sorts correctly as text.';
ALTER TABLE dim_date ALTER COLUMN month_label    COMMENT 'Display label, for example Oct 2026. Does not sort correctly as text; sort by month_end.';
ALTER TABLE dim_date ALTER COLUMN is_quarter_end COMMENT 'True for March, June, September and December. Use it to pick quarter-end headcount.';

-- ===== fact_headcount_monthly =====
COMMENT ON TABLE fact_headcount_monthly IS
  'One row per employee per month they were employed at any point in that month (month-end snapshot). Use is_active_month_end for headcount. Headcount is semi-additive: add across departments, never across months.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN snapshot_month      COMMENT 'Last day of the month this row describes. Join to dim_date.month_end.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN employee_id         COMMENT 'The employee. Join to dim_employee.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN department_id       COMMENT 'Department at month end, or on the last day for someone who left that month. Join to dim_department.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN job_id              COMMENT 'Job at month end, or on the last day for someone who left that month. Join to dim_job.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN location_id         COMMENT 'Location at month end, or on the last day for someone who left that month. Join to dim_location.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN manager_id          COMMENT 'Direct manager (employee_id) at month end. Empty for the CEO. Join to dim_manager.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN annual_base_salary  COMMENT 'Annual base salary in USD at this snapshot, already adjusted for location. A full-time annual rate: for part-time pay multiply by fte. Excludes bonus and equity. Restricted.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN fte                 COMMENT 'Full-time equivalent: 1.0 for full-time, less for part-time.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN tenure_months       COMMENT 'Whole months since the hire date, measured at the snapshot month end. Total time at Tema, not time in the current role or job.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_active_month_end COMMENT 'True if the person was still employed at the end of the month. Use this to count headcount.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_hire_in_month    COMMENT 'True in the month the person was hired (hire_date falls in this month). Use to count hires.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_termination_in_month           COMMENT 'True in the month the person left. Leavers count in attrition for this month but not in month-end headcount.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_voluntary_termination_in_month COMMENT 'True in the month the person left, if they resigned (termination_type = Voluntary).';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_regretted_termination_in_month COMMENT 'True in the month the person left, if the company wanted to keep them (is_regretted). False for everyone else, including current employees.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_first_year       COMMENT 'True when tenure_months is under 12, i.e. in the first year at Tema.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN employment_type     COMMENT 'Full-time or Part-time, from the employee record (the current value, not tracked month by month).';

-- ===== fact_terminations =====
COMMENT ON TABLE fact_terminations IS
  'One row per leaver (each person leaves at most once). Includes layoffs. Attributes are the last assignment before leaving. For attrition rates divide by average headcount from fact_headcount_monthly.';
ALTER TABLE fact_terminations ALTER COLUMN employee_id        COMMENT 'The person who left. Join to dim_employee.';
ALTER TABLE fact_terminations ALTER COLUMN termination_date   COMMENT 'Last day of employment.';
ALTER TABLE fact_terminations ALTER COLUMN termination_month  COMMENT 'Last day of the month the person left. Join to dim_date.month_end.';
ALTER TABLE fact_terminations ALTER COLUMN termination_type   COMMENT 'Voluntary (the person resigned) or Involuntary (Tema ended employment, including layoffs).';
ALTER TABLE fact_terminations ALTER COLUMN termination_reason COMMENT 'Main reason for leaving. Voluntary: Career growth, Compensation, Manager, Relocation, Work-life balance, Competitor offer, Other. Involuntary: Performance, Restructuring, Policy violation.';
ALTER TABLE fact_terminations ALTER COLUMN is_regretted       COMMENT 'True if the company wanted to keep this person (a regretted loss). Always false for involuntary leavers.';
ALTER TABLE fact_terminations ALTER COLUMN hire_date          COMMENT 'First day of employment. Use with termination_date for tenure at leaving.';
ALTER TABLE fact_terminations ALTER COLUMN department_id      COMMENT 'Department at the time of leaving. Join to dim_department.';
ALTER TABLE fact_terminations ALTER COLUMN job_id             COMMENT 'Job at the time of leaving. Join to dim_job.';
ALTER TABLE fact_terminations ALTER COLUMN location_id        COMMENT 'Location at the time of leaving. Join to dim_location.';
ALTER TABLE fact_terminations ALTER COLUMN manager_id         COMMENT 'Direct manager (employee_id) at the time of leaving. Join to dim_manager.';

-- ===== fact_requisitions =====
COMMENT ON TABLE fact_requisitions IS
  'One row per opened role (requisition): backfills for leavers and new growth roles. Status as of 2026-10-31.';
ALTER TABLE fact_requisitions ALTER COLUMN requisition_id    COMMENT 'Requisition identifier.';
ALTER TABLE fact_requisitions ALTER COLUMN department_id     COMMENT 'Hiring department. Join to dim_department.';
ALTER TABLE fact_requisitions ALTER COLUMN job_id            COMMENT 'Job being hired for. Join to dim_job.';
ALTER TABLE fact_requisitions ALTER COLUMN location_id       COMMENT 'Location of the role. Join to dim_location.';
ALTER TABLE fact_requisitions ALTER COLUMN opened_date       COMMENT 'Date the requisition was opened.';
ALTER TABLE fact_requisitions ALTER COLUMN filled_date       COMMENT 'Date the hire started (their hire_date). Empty for open or cancelled roles.';
ALTER TABLE fact_requisitions ALTER COLUMN status            COMMENT 'Filled, Open (still being recruited at 2026-10-31) or Cancelled (closed without a hire).';
ALTER TABLE fact_requisitions ALTER COLUMN hired_employee_id COMMENT 'employee_id of the person hired. Empty unless status is Filled. Join to dim_employee.';
ALTER TABLE fact_requisitions ALTER COLUMN applicants        COMMENT 'Number of applicants for the role.';
ALTER TABLE fact_requisitions ALTER COLUMN interviews        COMMENT 'Number of candidates interviewed.';
ALTER TABLE fact_requisitions ALTER COLUMN offers_extended   COMMENT 'Number of offers made. More than 1 means at least one offer was declined. 0 for open or cancelled roles.';
ALTER TABLE fact_requisitions ALTER COLUMN offers_accepted   COMMENT '1 if an offer was accepted (status Filled), else 0.';
ALTER TABLE fact_requisitions ALTER COLUMN days_to_fill      COMMENT 'Calendar days from opened_date to filled_date. Empty for open or cancelled roles; exclude them rather than treating empty as 0. Use the median, not the average.';

-- ===== fact_engagement =====
COMMENT ON TABLE fact_engagement IS
  'One row per survey response (one per responding employee per survey cycle, twice a year in May and November). Team columns are as of the survey month. Confidential: report only in aggregates, never individual answers.';
ALTER TABLE fact_engagement ALTER COLUMN response_id      COMMENT 'Survey response identifier.';
ALTER TABLE fact_engagement ALTER COLUMN employee_id      COMMENT 'The respondent. Join to dim_employee. Confidential; do not show alongside answers.';
ALTER TABLE fact_engagement ALTER COLUMN survey_cycle     COMMENT 'Survey cycle label: YYYY-H1 (May survey) or YYYY-H2 (November survey), for example 2026-H1.';
ALTER TABLE fact_engagement ALTER COLUMN survey_date      COMMENT 'Date the survey ran (the 15th of May or November).';
ALTER TABLE fact_engagement ALTER COLUMN enps_score       COMMENT 'Answer to how likely the respondent is to recommend Tema as a place to work, 0 to 10. 9 to 10 promoters, 7 to 8 passives, 0 to 6 detractors. eNPS = % promoters minus % detractors; never average this column.';
ALTER TABLE fact_engagement ALTER COLUMN enps_category    COMMENT 'Promoter (enps_score 9 to 10), Passive (7 to 8) or Detractor (0 to 6).';
ALTER TABLE fact_engagement ALTER COLUMN engagement_score COMMENT 'Overall engagement index, 1 (low) to 5 (high).';
ALTER TABLE fact_engagement ALTER COLUMN manager_score    COMMENT 'Rating of the direct manager, 1 (low) to 5 (high).';
ALTER TABLE fact_engagement ALTER COLUMN wellbeing_score  COMMENT 'Wellbeing and workload rating, 1 (low) to 5 (high).';
ALTER TABLE fact_engagement ALTER COLUMN growth_score     COMMENT 'Career growth and development rating, 1 (low) to 5 (high).';
ALTER TABLE fact_engagement ALTER COLUMN department_id    COMMENT 'Respondent department at the end of the survey month. Join to dim_department.';
ALTER TABLE fact_engagement ALTER COLUMN job_id           COMMENT 'Respondent job at the end of the survey month. Join to dim_job.';
ALTER TABLE fact_engagement ALTER COLUMN location_id      COMMENT 'Respondent location at the end of the survey month. Join to dim_location.';
ALTER TABLE fact_engagement ALTER COLUMN manager_id       COMMENT 'Respondent direct manager at the end of the survey month. Join to dim_manager. Suppress manager-level results for small teams.';

-- ===== fact_absences =====
COMMENT ON TABLE fact_absences IS
  'One row per absence (a continuous period off). Team columns are as of the month the absence started. Absence type can reveal health or family information; treat as restricted.';
ALTER TABLE fact_absences ALTER COLUMN absence_id    COMMENT 'Absence identifier.';
ALTER TABLE fact_absences ALTER COLUMN employee_id   COMMENT 'The absent employee. Join to dim_employee.';
ALTER TABLE fact_absences ALTER COLUMN start_date    COMMENT 'First day of the absence.';
ALTER TABLE fact_absences ALTER COLUMN end_date      COMMENT 'Last day of the absence (inclusive).';
ALTER TABLE fact_absences ALTER COLUMN absence_type  COMMENT 'Sick, Vacation, Personal, Parental or Bereavement. Restricted: can reveal health or family circumstances.';
ALTER TABLE fact_absences ALTER COLUMN days_absent   COMMENT 'Calendar days from start_date to end_date inclusive (not working days). Long absences can span months; the whole count sits in absence_month.';
ALTER TABLE fact_absences ALTER COLUMN absence_month COMMENT 'Last day of the month the absence started. Join to dim_date.month_end.';
ALTER TABLE fact_absences ALTER COLUMN department_id COMMENT 'Department at the end of the month the absence started. Join to dim_department.';
ALTER TABLE fact_absences ALTER COLUMN job_id        COMMENT 'Job at the end of the month the absence started. Join to dim_job.';
ALTER TABLE fact_absences ALTER COLUMN location_id   COMMENT 'Location at the end of the month the absence started. Join to dim_location.';
ALTER TABLE fact_absences ALTER COLUMN manager_id    COMMENT 'Direct manager at the end of the month the absence started. Join to dim_manager.';

-- ===== fact_equity_grants =====
COMMENT ON TABLE fact_equity_grants IS
  'One row per equity grant (an employee can have many). Fictional TEMA stock. Restricted compensation data.';
ALTER TABLE fact_equity_grants ALTER COLUMN grant_id        COMMENT 'Grant identifier.';
ALTER TABLE fact_equity_grants ALTER COLUMN employee_id     COMMENT 'The grant recipient. Join to dim_employee.';
ALTER TABLE fact_equity_grants ALTER COLUMN grant_date      COMMENT 'Date the grant was awarded.';
ALTER TABLE fact_equity_grants ALTER COLUMN grant_type      COMMENT 'New hire, Promotion, Annual refresh (March, after a review of Meets or better) or Retention (Feb 2026, AI top performers).';
ALTER TABLE fact_equity_grants ALTER COLUMN grant_value_usd COMMENT 'Value of the grant in USD on the grant date; shares were sized from it. Total over the vesting period, not per year, and not the current value. Restricted.';
ALTER TABLE fact_equity_grants ALTER COLUMN grant_price_usd COMMENT 'Fictional TEMA share price in USD on the grant date, used to convert value into shares.';
ALTER TABLE fact_equity_grants ALTER COLUMN shares          COMMENT 'Number of shares granted (grant_value_usd / grant_price_usd, rounded). Restricted.';
ALTER TABLE fact_equity_grants ALTER COLUMN vesting_years   COMMENT 'Years over which the grant vests. Always 4 at Tema.';

-- Checkpoint: columns with no comment (expect 0 rows)
SELECT table_name, column_name FROM workspace.information_schema.columns
WHERE table_schema = 'tema_hr_gold' AND (comment IS NULL OR comment = '');
