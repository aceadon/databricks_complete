-- =====================================================================================
-- Week 1 answer key: "as of" query (step 2) and where gender belongs (step 5)
-- Untested in Databricks.
-- =====================================================================================
USE CATALOG workspace;

-- -------------------------------------------------------------------------------------
-- Step 2. Department each employee was in on 2025-01-01, then people per department.
-- -------------------------------------------------------------------------------------

-- 2a. One row per person employed on 2025-01-01, with that day's department
SELECT h.employee_id, h.department_id, d.department_name
FROM tema_hr_raw.job_history h
JOIN tema_hr_raw.employees e   ON e.employee_id = h.employee_id
JOIN tema_hr_raw.departments d ON d.department_id = h.department_id
WHERE h.effective_from <= DATE'2025-01-01'
  AND (h.effective_to IS NULL OR h.effective_to >= DATE'2025-01-01')   -- the job row covering that day
  AND e.hire_date <= DATE'2025-01-01'
  AND (e.termination_date IS NULL OR e.termination_date > DATE'2025-01-01');  -- still employed that day

-- 2b. People per department on that date
SELECT d.division, d.department_name, COUNT(*) AS people
FROM tema_hr_raw.job_history h
JOIN tema_hr_raw.employees e   ON e.employee_id = h.employee_id
JOIN tema_hr_raw.departments d ON d.department_id = h.department_id
WHERE h.effective_from <= DATE'2025-01-01'
  AND (h.effective_to IS NULL OR h.effective_to >= DATE'2025-01-01')
  AND e.hire_date <= DATE'2025-01-01'
  AND (e.termination_date IS NULL OR e.termination_date > DATE'2025-01-01')
GROUP BY ALL
ORDER BY people DESC;

-- Self-checks
-- (a) Nobody should appear twice: each person has exactly one job row covering any day.
SELECT h.employee_id, COUNT(*) AS rows_on_date
FROM tema_hr_raw.job_history h
WHERE h.effective_from <= DATE'2025-01-01'
  AND (h.effective_to IS NULL OR h.effective_to >= DATE'2025-01-01')
GROUP BY ALL HAVING COUNT(*) > 1;            -- expect 0 rows

-- (b) The total should match month-end December 2024 headcount from the snapshot.
--     At 5,000 people both give 4,046. (They could differ if anyone were hired on 1 January.)
SELECT COUNT_IF(is_active_month_end) AS hc_dec_2024
FROM tema_hr_raw.headcount_monthly WHERE snapshot_month = '2024-12-31';

-- Common mistakes this avoids:
--  * Using is_current = true. That's today's job, not the job on 2025-01-01.
--  * effective_to > date instead of >=. effective_to is the LAST day in the job (inclusive).
--  * Forgetting the employment filter. Without it you get 4,048, not 4,046: a leaver's last job row
--    ends ON their termination date, so people whose last day was 2025-01-01 still match the job
--    condition. Decide whether "on that date" includes them, and write it down.

-- -------------------------------------------------------------------------------------
-- Step 5. Does gender belong in dim_employee or dim_employee_sensitive?
-- -------------------------------------------------------------------------------------
-- Answer for your notes (one sentence):
--   "Gender goes in dim_employee_sensitive, because it is protected personal data under most privacy
--    and equality laws, and combined with department, level and location it can identify individuals
--    in small teams; analysts who need it for pay equity or diversity reporting get it through a
--    restricted, aggregate-only path rather than on every employee row."
--
-- The counter-argument (also acceptable if you write it down): diversity reporting is a common,
-- legitimate use, so some companies keep gender in the main dimension and protect it with a column
-- mask instead. Either way the decision must be explicit, and Week 5's pay equity metric and Week 9's
-- small-group rule are where it bites.
