-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Tema HRBP access model
-- MAGIC
-- MAGIC Builds the governance model from [README.md](README.md): HR business partners (HRBPs) see sensitive
-- MAGIC data (birthdays, national IDs, salary, equity) **only for the organisations they support**, meaning
-- MAGIC everyone who reports, directly or indirectly, to a leader they are assigned to.
-- MAGIC
-- MAGIC Prerequisite: run `../00_generate_hr_data.py` first. This notebook reads `tema_hr_raw` and creates
-- MAGIC everything in a new schema, `tema_hr_secure`. Change the catalog below if yours isn't `workspace`.
-- MAGIC
-- MAGIC Uses recursive CTEs, SQL session variables, row filters and column masks. Run it on serverless
-- MAGIC compute or a recent SQL warehouse.

-- COMMAND ----------

USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS tema_hr_secure
  COMMENT 'Tema (fictional) HR data with HRBP-scoped access to sensitive fields. Synthetic data only.';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Who reports to whom: the org closure table
-- MAGIC One row for every (leader, person below them) pair, at any depth. This is what makes "recursive reports"
-- MAGIC cheap to check. Rebuild it whenever the org changes (for example in a daily job), and scope follows reorgs automatically.

-- COMMAND ----------

CREATE OR REPLACE TABLE tema_hr_secure.current_assignment
COMMENT 'Current job, department and manager for every active employee.'
AS
SELECT h.employee_id, h.manager_id, h.department_id, h.job_id, j.job_level, j.job_title, h.location_id,
       h.annual_base_salary
FROM tema_hr_raw.job_history h
JOIN tema_hr_raw.employees e ON e.employee_id = h.employee_id
JOIN tema_hr_raw.jobs j ON j.job_id = h.job_id
WHERE h.is_current AND e.termination_date IS NULL;

CREATE OR REPLACE TABLE tema_hr_secure.org_closure
COMMENT 'Every leader to every person in their organisation (recursive reports), with depth.'
AS
WITH RECURSIVE closure (ancestor_id, employee_id, depth) AS (
  SELECT manager_id, employee_id, 1
  FROM tema_hr_secure.current_assignment
  WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT c.manager_id, cl.employee_id, cl.depth + 1
  FROM closure cl
  JOIN tema_hr_secure.current_assignment c ON c.employee_id = cl.ancestor_id
  WHERE c.manager_id IS NOT NULL
)
SELECT ancestor_id, employee_id, depth FROM closure;

-- Sanity check: the CEO should have every other active employee below them.
SELECT (SELECT count(*) FROM tema_hr_secure.current_assignment) - 1 AS expected,
       count(*) AS ceo_org_size
FROM tema_hr_secure.org_closure o
JOIN tema_hr_secure.current_assignment c ON c.employee_id = o.ancestor_id
WHERE c.job_level = 'E1';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. HRBP scope
-- MAGIC An HRBP's scope is the union of the organisations of every leader they currently support, as primary or
-- MAGIC secondary partner. Two policy decisions are built in, and you can change them:
-- MAGIC - **Executive carve-out:** VPs and above (levels M4, M5, E1, E2) are never in an HRBP's scope, including the
-- MAGIC   leader they support. Executive pay is handled by a separate executive compensation team.
-- MAGIC - **Only current assignments count.** When an assignment ends, access ends with it.

-- COMMAND ----------

CREATE OR REPLACE VIEW tema_hr_secure.hrbp_scope_detail
COMMENT 'Why each employee is in an HRBP scope: which leader and which assignment.'
AS
SELECT a.hrbp_employee_id, a.leader_employee_id, a.coverage_role, o.employee_id, o.depth
FROM tema_hr_raw.hrbp_assignments a
JOIN tema_hr_secure.org_closure o ON o.ancestor_id = a.leader_employee_id
JOIN tema_hr_secure.current_assignment c ON c.employee_id = o.employee_id
WHERE a.effective_from <= current_date()
  AND (a.effective_to IS NULL OR a.effective_to >= current_date())
  AND c.job_level NOT IN ('M4', 'M5', 'E1', 'E2');

CREATE OR REPLACE TABLE tema_hr_secure.hrbp_scope
COMMENT 'One row per (HRBP, employee they may see sensitive data for). Rebuild with the org closure.'
AS
SELECT DISTINCT hrbp_employee_id, employee_id FROM tema_hr_secure.hrbp_scope_detail;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Personas: who is the current user acting as?
-- MAGIC In production you would map each login to an employee record (work email = login) and use groups such as
-- MAGIC `hr_admins` and `hrbps`. In a personal workspace you are the only user, so this table lets you **act as**
-- MAGIC any Tema employee and role, and see exactly what they would see.
-- MAGIC
-- MAGIC Roles: `hr_admin` (sees everything), `hrbp`, `manager`, `employee`.

-- COMMAND ----------

CREATE TABLE IF NOT EXISTS tema_hr_secure.access_personas (
  user_email STRING NOT NULL,
  role STRING NOT NULL,
  acting_as_employee_id BIGINT
) COMMENT 'Maps a login to the Tema employee and role it acts as. Stand-in for an HR identity directory plus groups.';

-- Start as an HR admin, so your own work isn't masked. The activity notebook switches personas.
DELETE FROM tema_hr_secure.access_personas WHERE user_email = current_user();
INSERT INTO tema_hr_secure.access_personas VALUES (current_user(), 'hr_admin', NULL);

CREATE OR REPLACE FUNCTION tema_hr_secure.acting_role() RETURNS STRING
RETURN (SELECT max(role) FROM tema_hr_secure.access_personas WHERE user_email = current_user());

CREATE OR REPLACE FUNCTION tema_hr_secure.acting_as() RETURNS BIGINT
RETURN (SELECT max(acting_as_employee_id) FROM tema_hr_secure.access_personas WHERE user_email = current_user());

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Access rules as functions
-- MAGIC Every rule lives in one place. Masks and row filters call these functions, so changing a rule here changes
-- MAGIC it on every table that uses it.

-- COMMAND ----------

CREATE OR REPLACE FUNCTION tema_hr_secure.can_see_sensitive(emp_id BIGINT) RETURNS BOOLEAN
COMMENT 'HR admins, the employee themself, and HRBPs whose scope includes the employee.'
RETURN coalesce(tema_hr_secure.acting_role() = 'hr_admin', false)
    OR coalesce(tema_hr_secure.acting_as() = emp_id, false)
    OR (coalesce(tema_hr_secure.acting_role() = 'hrbp', false) AND EXISTS (
          SELECT 1 FROM tema_hr_secure.hrbp_scope s
          WHERE s.hrbp_employee_id = tema_hr_secure.acting_as() AND s.employee_id = emp_id));

CREATE OR REPLACE FUNCTION tema_hr_secure.is_direct_manager_of(emp_id BIGINT) RETURNS BOOLEAN
COMMENT 'True when the acting employee is the direct manager of emp_id.'
RETURN EXISTS (
  SELECT 1 FROM tema_hr_secure.current_assignment c
  WHERE c.employee_id = emp_id AND c.manager_id = tema_hr_secure.acting_as());

-- Column masks. The first argument is the column being masked; the rest come from USING COLUMNS.
CREATE OR REPLACE FUNCTION tema_hr_secure.mask_date(val DATE, emp_id BIGINT) RETURNS DATE
RETURN CASE WHEN tema_hr_secure.can_see_sensitive(emp_id) THEN val END;

CREATE OR REPLACE FUNCTION tema_hr_secure.mask_amount(val DOUBLE, emp_id BIGINT) RETURNS DOUBLE
RETURN CASE WHEN tema_hr_secure.can_see_sensitive(emp_id) THEN val END;

CREATE OR REPLACE FUNCTION tema_hr_secure.mask_text(val STRING, emp_id BIGINT) RETURNS STRING
RETURN CASE WHEN tema_hr_secure.can_see_sensitive(emp_id) THEN val END;

-- Birthdays (month and day only) are also visible to the direct manager, e.g. for team celebrations.
CREATE OR REPLACE FUNCTION tema_hr_secure.mask_birthday(val STRING, emp_id BIGINT) RETURNS STRING
RETURN CASE WHEN tema_hr_secure.can_see_sensitive(emp_id) OR tema_hr_secure.is_direct_manager_of(emp_id) THEN val END;

-- National ID: full value only for HR admins and the employee; HRBPs in scope see the last four characters.
CREATE OR REPLACE FUNCTION tema_hr_secure.mask_national_id(val STRING, emp_id BIGINT) RETURNS STRING
RETURN CASE
  WHEN coalesce(tema_hr_secure.acting_role() = 'hr_admin', false) OR coalesce(tema_hr_secure.acting_as() = emp_id, false) THEN val
  WHEN tema_hr_secure.can_see_sensitive(emp_id) THEN concat('NID-*****', right(val, 4))
END;

-- Row filter: whole rows of equity grants are only visible within scope.
CREATE OR REPLACE FUNCTION tema_hr_secure.sensitive_row_filter(emp_id BIGINT) RETURNS BOOLEAN
RETURN tema_hr_secure.can_see_sensitive(emp_id);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Secured tables
-- MAGIC - `employee_profile`: every active employee is visible (name, team, title), but sensitive **columns are masked**
-- MAGIC   outside your scope.
-- MAGIC - `equity_grants`: sensitive **rows are filtered** out entirely outside your scope.

-- COMMAND ----------

CREATE OR REPLACE TABLE tema_hr_secure.employee_profile
COMMENT 'Active Tema employees. Sensitive columns are masked outside the viewer''s HRBP scope.'
AS
SELECT e.employee_id, e.first_name, e.last_name, e.work_email,
       d.department_name, d.division, c.job_title, c.job_level, c.manager_id, l.city, e.hire_date,
       e.date_of_birth,
       date_format(e.date_of_birth, 'MM-dd') AS birthday,
       e.national_id, e.personal_email, e.home_postcode,
       c.annual_base_salary,
       coalesce(g.equity_granted_4y_usd, 0) AS equity_granted_4y_usd
FROM tema_hr_raw.employees e
JOIN tema_hr_secure.current_assignment c ON c.employee_id = e.employee_id
JOIN tema_hr_raw.departments d ON d.department_id = c.department_id
JOIN tema_hr_raw.locations l ON l.location_id = c.location_id
LEFT JOIN (
  SELECT employee_id, sum(grant_value_usd) AS equity_granted_4y_usd
  FROM tema_hr_raw.equity_grants
  WHERE grant_date > add_months(current_date(), -48)
  GROUP BY employee_id
) g ON g.employee_id = e.employee_id;

ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN date_of_birth SET MASK tema_hr_secure.mask_date USING COLUMNS (employee_id);
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN birthday SET MASK tema_hr_secure.mask_birthday USING COLUMNS (employee_id);
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN national_id SET MASK tema_hr_secure.mask_national_id USING COLUMNS (employee_id);
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN personal_email SET MASK tema_hr_secure.mask_text USING COLUMNS (employee_id);
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN home_postcode SET MASK tema_hr_secure.mask_text USING COLUMNS (employee_id);
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN annual_base_salary SET MASK tema_hr_secure.mask_amount USING COLUMNS (employee_id);
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN equity_granted_4y_usd SET MASK tema_hr_secure.mask_amount USING COLUMNS (employee_id);

CREATE OR REPLACE TABLE tema_hr_secure.equity_grants
COMMENT 'Equity grants. Rows are only visible within the viewer''s HRBP scope.'
AS SELECT * FROM tema_hr_raw.equity_grants;

ALTER TABLE tema_hr_secure.equity_grants SET ROW FILTER tema_hr_secure.sensitive_row_filter ON (employee_id);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Tag what's sensitive
-- MAGIC Tags make the policy discoverable in Catalog Explorer, and are what ABAC policies match on (see the README).

-- COMMAND ----------

ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN date_of_birth SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'date_of_birth');
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN birthday SET TAGS ('hr_sensitivity' = 'confidential');
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN national_id SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'government_id');
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN personal_email SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'email');
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN home_postcode SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'address');
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN annual_base_salary SET TAGS ('hr_sensitivity' = 'restricted', 'compensation' = 'base_pay');
ALTER TABLE tema_hr_secure.employee_profile ALTER COLUMN equity_granted_4y_usd SET TAGS ('hr_sensitivity' = 'restricted', 'compensation' = 'equity');
ALTER TABLE tema_hr_secure.equity_grants SET TAGS ('hr_sensitivity' = 'restricted', 'compensation' = 'equity');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Done. Now open `02_hrbp_access_activity.sql` and start acting as different people.
