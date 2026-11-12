-- =====================================================================================
-- Week 2 answer key: tag what's sensitive (step 4)
-- Run after 03_comments_and_tags.sql (or week-02-keys-and-comments.sql). Untested in Databricks.
-- Tag names and values match the Week 8 governance model
-- (hr_people_analytics/governance/01_hrbp_access_model.sql):
--   hr_sensitivity = restricted | confidential
--   pii            = date_of_birth | government_id | email | address   (+ gender, new here)
--   compensation   = base_pay | equity
-- Week 8 ABAC policies match on hr_sensitivity = 'restricted', so only put 'restricted' on
-- columns everyone outside an HRBP's scope should have masked.
-- =====================================================================================
USE CATALOG workspace;
USE SCHEMA tema_hr_gold;

-- -------------------------------------------------------------------------------------
-- 1. Every table: domain = people
-- -------------------------------------------------------------------------------------
ALTER TABLE dim_department         SET TAGS ('domain' = 'people');
ALTER TABLE dim_location           SET TAGS ('domain' = 'people');
ALTER TABLE dim_job                SET TAGS ('domain' = 'people');
ALTER TABLE dim_employee           SET TAGS ('domain' = 'people');
ALTER TABLE dim_employee_sensitive SET TAGS ('domain' = 'people', 'hr_sensitivity' = 'restricted');
ALTER TABLE dim_manager            SET TAGS ('domain' = 'people');
ALTER TABLE dim_date               SET TAGS ('domain' = 'people');
ALTER TABLE fact_headcount_monthly SET TAGS ('domain' = 'people');
ALTER TABLE fact_terminations      SET TAGS ('domain' = 'people');
ALTER TABLE fact_requisitions      SET TAGS ('domain' = 'people');
ALTER TABLE fact_engagement        SET TAGS ('domain' = 'people');
ALTER TABLE fact_absences          SET TAGS ('domain' = 'people');
ALTER TABLE fact_equity_grants     SET TAGS ('domain' = 'people', 'hr_sensitivity' = 'restricted', 'compensation' = 'equity');

-- -------------------------------------------------------------------------------------
-- 2. Personal columns (all in dim_employee_sensitive)
-- -------------------------------------------------------------------------------------
ALTER TABLE dim_employee_sensitive ALTER COLUMN date_of_birth  SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'date_of_birth');
ALTER TABLE dim_employee_sensitive ALTER COLUMN gender         SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'gender');
ALTER TABLE dim_employee_sensitive ALTER COLUMN national_id    SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'government_id');
ALTER TABLE dim_employee_sensitive ALTER COLUMN personal_email SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'email');
ALTER TABLE dim_employee_sensitive ALTER COLUMN home_postcode  SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'address');

-- -------------------------------------------------------------------------------------
-- 3. Pay columns
-- -------------------------------------------------------------------------------------
ALTER TABLE fact_headcount_monthly ALTER COLUMN annual_base_salary SET TAGS ('hr_sensitivity' = 'restricted', 'compensation' = 'base_pay');
ALTER TABLE fact_equity_grants     ALTER COLUMN grant_value_usd    SET TAGS ('hr_sensitivity' = 'restricted', 'compensation' = 'equity');
ALTER TABLE fact_equity_grants     ALTER COLUMN shares             SET TAGS ('hr_sensitivity' = 'restricted', 'compensation' = 'equity');

-- Deliberately NOT tagged:
--   fact_equity_grants.grant_price_usd  the company share price on a date, the same for everyone
--   dim_job.salary_band_min/mid/max     published pay ranges for a job, not anyone's pay
--   dim_job / dim_location pay factors  policy numbers, not personal data

-- -------------------------------------------------------------------------------------
-- 4. Judgment calls (optional; defensible either way, worth a line in your notes)
--    'confidential' marks them in Catalog Explorer without triggering Week 8 masks.
-- -------------------------------------------------------------------------------------
-- Directory data: known inside the company, but still personal
ALTER TABLE dim_employee ALTER COLUMN employee_name SET TAGS ('hr_sensitivity' = 'confidential', 'pii' = 'name');
ALTER TABLE dim_employee ALTER COLUMN work_email    SET TAGS ('hr_sensitivity' = 'confidential', 'pii' = 'email');
ALTER TABLE dim_manager  ALTER COLUMN manager_name  SET TAGS ('hr_sensitivity' = 'confidential', 'pii' = 'name');
-- Why someone left, and whether Tema wanted to keep them
ALTER TABLE dim_employee      ALTER COLUMN termination_reason SET TAGS ('hr_sensitivity' = 'confidential');
ALTER TABLE dim_employee      ALTER COLUMN is_regretted       SET TAGS ('hr_sensitivity' = 'confidential');
ALTER TABLE fact_terminations ALTER COLUMN termination_reason SET TAGS ('hr_sensitivity' = 'confidential');
ALTER TABLE fact_terminations ALTER COLUMN is_regretted       SET TAGS ('hr_sensitivity' = 'confidential');
-- Absence type can reveal health or family circumstances (sick, parental, bereavement)
ALTER TABLE fact_absences ALTER COLUMN absence_type SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'health');
-- Individual survey answers: report only in aggregates
ALTER TABLE fact_engagement ALTER COLUMN enps_score SET TAGS ('hr_sensitivity' = 'confidential');

-- -------------------------------------------------------------------------------------
-- Checks
-- -------------------------------------------------------------------------------------
-- Every table tagged domain = people (expect 13 rows)
SELECT table_name, tag_name, tag_value FROM workspace.information_schema.table_tags
WHERE schema_name = 'tema_hr_gold' AND tag_name = 'domain' ORDER BY table_name;

-- Tables missing the domain tag (expect 0 rows)
SELECT t.table_name FROM workspace.information_schema.tables t
LEFT ANTI JOIN workspace.information_schema.table_tags g
  ON g.schema_name = t.table_schema AND g.table_name = t.table_name AND g.tag_name = 'domain'
WHERE t.table_schema = 'tema_hr_gold';

-- Restricted columns (expect 8, or 9 with absence_type)
SELECT table_name, column_name, tag_value FROM workspace.information_schema.column_tags
WHERE schema_name = 'tema_hr_gold' AND tag_name = 'hr_sensitivity' AND tag_value = 'restricted'
ORDER BY table_name, column_name;

-- Everything tagged, one row per column
SELECT table_name, column_name, collect_list(tag_name || '=' || tag_value) AS tags
FROM workspace.information_schema.column_tags
WHERE schema_name = 'tema_hr_gold' GROUP BY ALL ORDER BY table_name, column_name;
