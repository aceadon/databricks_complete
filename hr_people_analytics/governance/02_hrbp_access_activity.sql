-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Activity: what can each person see?
-- MAGIC
-- MAGIC You'll act as five different Tema people and run the **same queries** each time. The data doesn't change;
-- MAGIC what you're allowed to see does. Run the cells in order. Prerequisite: `01_hrbp_access_model.sql`.
-- MAGIC
-- MAGIC | Step | Acting as | What to notice |
-- MAGIC |---|---|---|
-- MAGIC | 1 | HR admin | The baseline: everything is visible |
-- MAGIC | 2 | An HRBP who supports leaders in more than one division | Salaries, birthdays and equity appear only for people in those leaders' organisations, and never for the leaders themselves |
-- MAGIC | 3 | The second HRBP of a leader who has two | Two HRBPs share one organisation, and each also sees their other areas |
-- MAGIC | 4 | A people manager | Birthdays (month and day only) for direct reports, nothing else sensitive |
-- MAGIC | 5 | An individual employee | Their own record only |
-- MAGIC | 6 | The first HRBP again, after an assignment ends | Access disappears with the assignment |
-- MAGIC | 7 | The first HRBP, using metrics | Masks change what aggregate numbers mean |

-- COMMAND ----------

USE CATALOG workspace;
USE SCHEMA tema_hr_secure;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 0. Pick the people for the demo
-- MAGIC These variables find interesting cases in your data, so you don't have to look up IDs.

-- COMMAND ----------

-- An HRBP who supports leaders in more than one division (the most cross-area one)
DECLARE OR REPLACE VARIABLE hrbp_a BIGINT;
SET VAR hrbp_a = (
  SELECT d.hrbp_employee_id
  FROM (SELECT DISTINCT hrbp_employee_id, leader_employee_id FROM hrbp_scope_detail) d
  JOIN current_assignment c ON c.employee_id = d.leader_employee_id
  JOIN tema_hr_raw.departments dep ON dep.department_id = c.department_id
  GROUP BY d.hrbp_employee_id
  HAVING count(DISTINCT dep.division) > 1
  ORDER BY count(DISTINCT dep.division) DESC, count(*) DESC, d.hrbp_employee_id
  LIMIT 1);

-- A leader supported by two HRBPs, one of whom is hrbp_a if possible, and the other HRBP
DECLARE OR REPLACE VARIABLE shared_leader BIGINT;
DECLARE OR REPLACE VARIABLE hrbp_b BIGINT;
SET VAR shared_leader = (
  SELECT leader_employee_id FROM tema_hr_raw.hrbp_assignments
  WHERE effective_to IS NULL
  GROUP BY leader_employee_id
  HAVING count(DISTINCT hrbp_employee_id) > 1
  ORDER BY max(CASE WHEN hrbp_employee_id = hrbp_a THEN 1 ELSE 0 END) DESC, leader_employee_id
  LIMIT 1);
SET VAR hrbp_b = (
  SELECT min(hrbp_employee_id) FROM tema_hr_raw.hrbp_assignments
  WHERE effective_to IS NULL AND leader_employee_id = shared_leader AND hrbp_employee_id <> hrbp_a);

-- A people manager in hrbp_a's scope, and one of their direct reports
DECLARE OR REPLACE VARIABLE manager_m BIGINT;
DECLARE OR REPLACE VARIABLE employee_e BIGINT;
SET VAR manager_m = (
  SELECT min(c.manager_id) FROM current_assignment c
  JOIN hrbp_scope s ON s.employee_id = c.manager_id AND s.hrbp_employee_id = hrbp_a
  JOIN current_assignment m ON m.employee_id = c.manager_id AND m.job_level IN ('M1', 'M2'));
SET VAR employee_e = (SELECT min(employee_id) FROM current_assignment WHERE manager_id = manager_m);

SELECT p.employee_id, p.first_name, p.last_name, p.job_title, p.division,
       CASE p.employee_id WHEN hrbp_a THEN 'hrbp_a' WHEN hrbp_b THEN 'hrbp_b' WHEN shared_leader THEN 'shared_leader'
                          WHEN manager_m THEN 'manager_m' WHEN employee_e THEN 'employee_e' END AS demo_role
FROM tema_hr_raw.employees p
JOIN current_assignment c USING (employee_id)
JOIN tema_hr_raw.departments USING (department_id)
WHERE p.employee_id IN (hrbp_a, hrbp_b, shared_leader, manager_m, employee_e);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Who does hrbp_a support?
-- MAGIC Notice the leaders span different divisions, and some are directors rather than VPs.

-- COMMAND ----------

SELECT a.coverage_role, l.first_name || ' ' || l.last_name AS leader, c.job_title, d.division,
       (SELECT count(*) FROM org_closure o WHERE o.ancestor_id = a.leader_employee_id) AS recursive_reports,
       (SELECT count(*) FROM tema_hr_raw.hrbp_assignments x
         WHERE x.leader_employee_id = a.leader_employee_id AND x.effective_to IS NULL) AS hrbps_for_this_leader
FROM tema_hr_raw.hrbp_assignments a
JOIN tema_hr_raw.employees l ON l.employee_id = a.leader_employee_id
JOIN current_assignment c ON c.employee_id = a.leader_employee_id
JOIN tema_hr_raw.departments d ON d.department_id = c.department_id
WHERE a.hrbp_employee_id = hrbp_a AND a.effective_to IS NULL
ORDER BY recursive_reports DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## The probe queries
-- MAGIC You'll rerun these three after each persona switch. Copy them, or just rerun the cells below each step.
-- MAGIC 1. **Visibility summary**: how many rows and how many unmasked values you can see.
-- MAGIC 2. **Sample rows** from inside and outside the HRBP's scope, plus the shared leader.
-- MAGIC 3. **Equity grants** you can see.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Act as an HR admin

-- COMMAND ----------

DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'hr_admin', NULL);

SELECT count(*) AS employees_visible,
       count(annual_base_salary) AS salaries_visible,
       count(date_of_birth) AS birth_dates_visible,
       count(birthday) AS birthdays_visible,
       count_if(national_id NOT LIKE 'NID-*****%') AS full_national_ids_visible,
       (SELECT count(*) FROM equity_grants) AS equity_grants_visible
FROM employee_profile;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Act as hrbp_a

-- COMMAND ----------

DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'hrbp', hrbp_a);

SELECT count(*) AS employees_visible,
       count(annual_base_salary) AS salaries_visible,
       count(date_of_birth) AS birth_dates_visible,
       count(birthday) AS birthdays_visible,
       count_if(national_id NOT LIKE 'NID-*****%') AS full_national_ids_visible,
       (SELECT count(*) FROM equity_grants) AS equity_grants_visible
FROM employee_profile;

-- COMMAND ----------

-- Self-check: visible salaries should equal hrbp_a's scope plus their own record.
SELECT (SELECT count(*) FROM hrbp_scope WHERE hrbp_employee_id = hrbp_a) + 1 AS expected,
       count(annual_base_salary) AS actual,
       CASE WHEN count(annual_base_salary) = (SELECT count(*) FROM hrbp_scope WHERE hrbp_employee_id = hrbp_a) + 1
            THEN 'PASS' ELSE 'CHECK' END AS result
FROM employee_profile;

-- COMMAND ----------

-- Where can hrbp_a see sensitive data? Every division is listed, but salaries only appear where hrbp_a has scope.
SELECT division, count(*) AS employees, count(annual_base_salary) AS with_salary_visible,
       round(100 * count(annual_base_salary) / count(*), 1) AS pct_visible
FROM employee_profile GROUP BY division ORDER BY division;

-- COMMAND ----------

-- Sample rows: two people inside scope, two outside, and the leader hrbp_a supports (executive carve-out).
(SELECT 'in scope' AS sample, employee_id, first_name, last_name, job_title, division, date_of_birth, birthday,
        national_id, annual_base_salary, equity_granted_4y_usd
 FROM employee_profile WHERE employee_id IN (SELECT employee_id FROM hrbp_scope WHERE hrbp_employee_id = hrbp_a)
 ORDER BY employee_id LIMIT 2)
UNION ALL
(SELECT 'out of scope', employee_id, first_name, last_name, job_title, division, date_of_birth, birthday,
        national_id, annual_base_salary, equity_granted_4y_usd
 FROM employee_profile WHERE employee_id NOT IN (SELECT employee_id FROM hrbp_scope WHERE hrbp_employee_id = hrbp_a)
   AND job_level LIKE 'IC%'
 ORDER BY employee_id LIMIT 2)
UNION ALL
(SELECT 'supported leader', employee_id, first_name, last_name, job_title, division, date_of_birth, birthday,
        national_id, annual_base_salary, equity_granted_4y_usd
 FROM employee_profile WHERE employee_id IN (
   SELECT leader_employee_id FROM tema_hr_raw.hrbp_assignments WHERE hrbp_employee_id = hrbp_a AND effective_to IS NULL)
 ORDER BY employee_id LIMIT 1);

-- COMMAND ----------

-- Equity: rows outside scope don't exist as far as hrbp_a is concerned (row filter, not a mask).
SELECT grant_type, count(*) AS grants, round(sum(grant_value_usd)) AS total_value_usd
FROM equity_grants GROUP BY grant_type ORDER BY grants DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Act as hrbp_b, the other HRBP of the shared leader
-- MAGIC Both HRBPs can see the shared leader's organisation. Each also sees their own other areas.

-- COMMAND ----------

DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'hrbp', hrbp_b);

SELECT count(*) AS employees_visible, count(annual_base_salary) AS salaries_visible,
       (SELECT count(*) FROM equity_grants) AS equity_grants_visible
FROM employee_profile;

-- COMMAND ----------

-- How much do the two HRBPs' scopes overlap? (Computed from the scope table, so it's the same for any persona.)
SELECT count_if(a.employee_id IS NOT NULL AND b.employee_id IS NOT NULL) AS seen_by_both,
       count_if(a.employee_id IS NOT NULL AND b.employee_id IS NULL) AS only_hrbp_a,
       count_if(a.employee_id IS NULL AND b.employee_id IS NOT NULL) AS only_hrbp_b,
       (SELECT count(*) FROM org_closure o JOIN current_assignment c USING (employee_id)
         WHERE o.ancestor_id = shared_leader AND c.job_level NOT IN ('M4','M5','E1','E2')) AS shared_leader_org
FROM (SELECT employee_id FROM hrbp_scope WHERE hrbp_employee_id = hrbp_a) a
FULL OUTER JOIN (SELECT employee_id FROM hrbp_scope WHERE hrbp_employee_id = hrbp_b) b USING (employee_id);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Act as manager_m, a people manager

-- COMMAND ----------

DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'manager', manager_m);

SELECT employee_id, first_name, last_name, job_title, date_of_birth, birthday, national_id, annual_base_salary,
       CASE WHEN employee_id = manager_m THEN 'me' WHEN manager_id = manager_m THEN 'direct report' ELSE 'other' END AS relation
FROM employee_profile
WHERE employee_id = manager_m OR manager_id = manager_m OR employee_id IN (SELECT min(employee_id) FROM employee_profile)
ORDER BY relation;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Act as employee_e, an individual contributor

-- COMMAND ----------

DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'employee', employee_e);

SELECT count(*) AS employees_visible, count(annual_base_salary) AS salaries_visible,
       count(birthday) AS birthdays_visible, (SELECT count(*) FROM equity_grants) AS equity_grants_visible
FROM employee_profile;

SELECT * FROM equity_grants ORDER BY grant_date;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. An assignment ends
-- MAGIC hrbp_a stops supporting their largest leader. We end the assignment, rebuild the scope, and check again.
-- MAGIC (The last cell of this step puts it back.)

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE ended_assignment BIGINT;
SET VAR ended_assignment = (
  SELECT a.assignment_id FROM tema_hr_raw.hrbp_assignments a
  WHERE a.hrbp_employee_id = hrbp_a AND a.effective_to IS NULL
  ORDER BY (SELECT count(*) FROM org_closure o WHERE o.ancestor_id = a.leader_employee_id) DESC LIMIT 1);

UPDATE tema_hr_raw.hrbp_assignments SET effective_to = date_sub(current_date(), 1) WHERE assignment_id = ended_assignment;
CREATE OR REPLACE TABLE hrbp_scope AS SELECT DISTINCT hrbp_employee_id, employee_id FROM hrbp_scope_detail;

DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'hrbp', hrbp_a);
SELECT count(*) AS employees_visible, count(annual_base_salary) AS salaries_visible,
       (SELECT count(*) FROM equity_grants) AS equity_grants_visible
FROM employee_profile;

-- COMMAND ----------

-- Put the assignment back and rebuild the scope.
UPDATE tema_hr_raw.hrbp_assignments SET effective_to = NULL WHERE assignment_id = ended_assignment;
CREATE OR REPLACE TABLE hrbp_scope AS SELECT DISTINCT hrbp_employee_id, employee_id FROM hrbp_scope_detail;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Masks and metrics
-- MAGIC Still acting as hrbp_a. Masking happens **before** aggregation, so an average over a masked column only
-- MAGIC covers the rows you can see, while a count covers everyone. Same query, very different meaning.

-- COMMAND ----------

SELECT division,
       count(*) AS headcount,
       round(avg(annual_base_salary)) AS avg_salary_of_visible_people,
       count(annual_base_salary) AS people_in_that_average
FROM employee_profile GROUP BY division ORDER BY division;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Discuss:** if a metric view or Genie Agent sits on top of `employee_profile`, should "Average salary" be
-- MAGIC allowed for HRBPs at all? Options: (a) only show it inside their scope, (b) publish a separate aggregate-only
-- MAGIC metric with a minimum group size, or (c) restrict the metric to HR admins. Write down which your company would
-- MAGIC choose and why.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Reset
-- MAGIC Go back to being an HR admin so the rest of your work isn't masked.

-- COMMAND ----------

DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'hr_admin', NULL);
