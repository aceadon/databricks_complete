-- =====================================================================================
-- Tema reference build · Week 2 · gold facts
-- Finished state of hr_people_analytics/gold/02_facts.sql (labs/week-02, step 1, including the
-- "Your turn" fact_absences and fact_equity_grants). Run after 01_dimensions.sql.
-- Checkpoint at 5,000 people: fact_headcount_monthly 195,904 · fact_terminations 2,183 ·
-- fact_requisitions 2,948 · fact_engagement 23,252 · fact_absences 74,392 · fact_equity_grants 8,276
-- Rebuilding any table here wipes its keys, comments and tags: rerun 03 and 04 afterwards.
-- =====================================================================================
USE CATALOG workspace;
USE SCHEMA tema_hr_gold;

-- One row per employee per month they were employed. The workhorse for headcount and attrition.
CREATE OR REPLACE TABLE fact_headcount_monthly AS
SELECT h.snapshot_month, h.employee_id, h.department_id, h.job_id, h.location_id, h.manager_id,
       h.annual_base_salary, h.fte, h.tenure_months,
       h.is_active_month_end, h.is_hire_in_month, h.is_termination_in_month,
       h.is_termination_in_month AND e.termination_type = 'Voluntary'      AS is_voluntary_termination_in_month,
       h.is_termination_in_month AND coalesce(e.is_regretted, false)       AS is_regretted_termination_in_month,
       h.tenure_months < 12                                                AS is_first_year,
       e.employment_type
FROM tema_hr_raw.headcount_monthly h
JOIN tema_hr_raw.employees e ON e.employee_id = h.employee_id;

-- One row per leaver.
CREATE OR REPLACE TABLE fact_terminations AS
SELECT employee_id, termination_date, last_day(termination_date) AS termination_month,
       termination_type, termination_reason, is_regretted, hire_date,
       department_id, job_id, location_id, manager_id
FROM dim_employee
WHERE termination_date IS NOT NULL;

-- One row per opened role.
CREATE OR REPLACE TABLE fact_requisitions AS
SELECT r.*,
       CASE WHEN r.status = 'Filled' THEN datediff(r.filled_date, r.opened_date) END AS days_to_fill
FROM tema_hr_raw.requisitions r;

-- One row per survey response, with the respondent's team at the time.
CREATE OR REPLACE TABLE fact_engagement AS
SELECT s.response_id, s.employee_id, s.survey_cycle, s.survey_date, s.enps_score,
       CASE WHEN s.enps_score >= 9 THEN 'Promoter'
            WHEN s.enps_score >= 7 THEN 'Passive' ELSE 'Detractor' END AS enps_category,
       s.engagement_score, s.manager_score, s.wellbeing_score, s.growth_score,
       h.department_id, h.job_id, h.location_id, h.manager_id
FROM tema_hr_raw.engagement_surveys s
LEFT JOIN tema_hr_raw.headcount_monthly h
  ON h.employee_id = s.employee_id AND h.snapshot_month = last_day(s.survey_date);

-- Week 2 "Your turn": one row per absence, with the team at the end of the month it started.
CREATE OR REPLACE TABLE fact_absences AS
SELECT a.absence_id, a.employee_id, a.start_date, a.end_date, a.absence_type, a.days_absent,
       last_day(a.start_date) AS absence_month,
       h.department_id, h.job_id, h.location_id, h.manager_id
FROM tema_hr_raw.absences a
LEFT JOIN tema_hr_raw.headcount_monthly h
  ON h.employee_id = a.employee_id AND h.snapshot_month = last_day(a.start_date);

-- Week 2 "Your turn": one row per equity grant.
CREATE OR REPLACE TABLE fact_equity_grants AS
SELECT grant_id, employee_id, grant_date, grant_type, grant_value_usd, grant_price_usd, shares, vesting_years
FROM tema_hr_raw.equity_grants;
