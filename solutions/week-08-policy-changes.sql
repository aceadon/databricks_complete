-- =====================================================================================
-- Week 8 answer key, step 4: change a policy
-- All three options, each as a replacement for one object in 01_hrbp_access_model.sql.
-- Pick ONE at a time, run it, rerun the activity step named, then put the original back
-- (rerun the matching cell of 01_hrbp_access_model.sql) before trying the next.
-- Untested in Databricks.
-- =====================================================================================
USE CATALOG workspace;
USE SCHEMA tema_hr_secure;

-- Before you change anything, record the baseline as hrbp_a, so you have a "before" for your PR.
-- (Run section 0 of 02_hrbp_access_activity.sql first so hrbp_a and hrbp_b exist.)
DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'hrbp', hrbp_a);
SELECT count(*) AS employees_visible, count(annual_base_salary) AS salaries_visible,
       count_if(national_id LIKE 'NID-*****%') AS partial_national_ids_visible,
       (SELECT count(*) FROM equity_grants) AS equity_grants_visible
FROM employee_profile;


-- =====================================================================================
-- Option A. HRBPs see leavers for 90 days after they leave
-- Change: hrbp_scope_detail gains rows for recent leavers whose last manager sat in a supported
-- leader's organisation (or was the leader). Then rebuild hrbp_scope. can_see_sensitive() is untouched,
-- because it already reads hrbp_scope: one table changed, and every mask and filter follows.
-- =====================================================================================
CREATE OR REPLACE VIEW hrbp_scope_detail
COMMENT 'Why each employee is in an HRBP scope. Includes leavers for 90 days after their last day (policy option A).'
AS
WITH live_assignments AS (
  SELECT * FROM tema_hr_raw.hrbp_assignments
  WHERE effective_from <= current_date()
    AND (effective_to IS NULL OR effective_to >= current_date())
),
-- Each recent leaver's last job row: who their manager was on their last day
recent_leavers AS (
  SELECT h.employee_id, h.manager_id, j.job_level
  FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY effective_from DESC) AS rn
        FROM tema_hr_raw.job_history) h
  JOIN tema_hr_raw.employees e ON e.employee_id = h.employee_id
  JOIN tema_hr_raw.jobs j      ON j.job_id = h.job_id
  WHERE h.rn = 1
    AND e.termination_date IS NOT NULL
    AND e.termination_date >= date_sub(current_date(), 90)
),
-- A leader's organisation including the leader, so a leaver who reported straight to the leader counts
leader_org AS (
  SELECT ancestor_id, employee_id FROM org_closure
  UNION ALL
  SELECT employee_id, employee_id FROM current_assignment
)
-- Unchanged: current employees, executive carve-out applied
SELECT a.hrbp_employee_id, a.leader_employee_id, a.coverage_role, o.employee_id, o.depth
FROM live_assignments a
JOIN org_closure o ON o.ancestor_id = a.leader_employee_id
JOIN current_assignment c ON c.employee_id = o.employee_id
WHERE c.job_level NOT IN ('M4', 'M5', 'E1', 'E2')
UNION ALL
-- New: recent leavers, same carve-out
SELECT a.hrbp_employee_id, a.leader_employee_id, a.coverage_role, l.employee_id, CAST(NULL AS INT) AS depth
FROM live_assignments a
JOIN leader_org lo ON lo.ancestor_id = a.leader_employee_id
JOIN recent_leavers l ON l.manager_id = lo.employee_id
WHERE l.job_level NOT IN ('M4', 'M5', 'E1', 'E2');

CREATE OR REPLACE TABLE hrbp_scope AS SELECT DISTINCT hrbp_employee_id, employee_id FROM hrbp_scope_detail;

-- Rerun: activity step 2 (act as hrbp_a). Then this check:
-- employee_profile only lists active employees, so the change shows up in equity_grants, whose row
-- filter now lets in recent leavers' grants. Expect equity_grants_visible to go UP; employees_visible
-- stays the same (to see leavers' profiles too, employee_profile would have to include them).
SELECT count(*) AS grants_visible,
       count_if(e.termination_date IS NOT NULL) AS grants_of_leavers_visible
FROM equity_grants g JOIN tema_hr_raw.employees e USING (employee_id);

-- Watch out: the data ends on 2026-10-31 and the rule uses current_date(). If you run this after
-- late January 2027 there are no leavers in the last 90 days, and nothing changes. For the demo,
-- replace current_date() in recent_leavers with DATE'2026-10-31'.
-- Edge case to write down: if the leaver's manager has also left, the leaver isn't in anyone's
-- current org, so they drop out of scope. Production would use the org as it was on the last day.


-- =====================================================================================
-- Option B. HRBPs see the leader they support (narrowing the executive carve-out)
-- Change: add one row per live assignment for the leader themself.
-- Why not just delete the job_level filter? HRBPs support VPs (M4) and big directors (M3), and nobody
-- at M4 or above reports to them, so removing the filter changes nothing. The leader is missing because
-- org_closure lists people BELOW a leader, never the leader. Other executives stay carved out.
-- =====================================================================================
CREATE OR REPLACE VIEW hrbp_scope_detail
COMMENT 'Why each employee is in an HRBP scope. Includes the supported leader themself (policy option B).'
AS
SELECT a.hrbp_employee_id, a.leader_employee_id, a.coverage_role, o.employee_id, o.depth
FROM tema_hr_raw.hrbp_assignments a
JOIN org_closure o ON o.ancestor_id = a.leader_employee_id
JOIN current_assignment c ON c.employee_id = o.employee_id
WHERE a.effective_from <= current_date()
  AND (a.effective_to IS NULL OR a.effective_to >= current_date())
  AND c.job_level NOT IN ('M4', 'M5', 'E1', 'E2')
UNION ALL
SELECT a.hrbp_employee_id, a.leader_employee_id, a.coverage_role, a.leader_employee_id, 0 AS depth
FROM tema_hr_raw.hrbp_assignments a
JOIN current_assignment c ON c.employee_id = a.leader_employee_id     -- leader still employed
WHERE a.effective_from <= current_date()
  AND (a.effective_to IS NULL OR a.effective_to >= current_date());

CREATE OR REPLACE TABLE hrbp_scope AS SELECT DISTINCT hrbp_employee_id, employee_id FROM hrbp_scope_detail;

-- Rerun: activity step 2 and the shared-leader rows. Expect salaries_visible to go up by the number of
-- leaders hrbp_a supports, and the shared leader's salary to be visible to BOTH hrbp_a and hrbp_b.
SELECT employee_id, first_name, last_name, job_level, annual_base_salary
FROM employee_profile WHERE employee_id = shared_leader;
-- The self-check "Neither HRBP sees the leader's own salary" now fails, on purpose. Update the README's
-- persona matrix in the same pull request, because the documented policy changed.


-- =====================================================================================
-- Option C. Secondary HRBPs see salary but not national ID
-- Change: a helper function, and mask_national_id calls it. can_see_sensitive() is untouched, so
-- salary, dates and equity still follow the full scope.
-- =====================================================================================
CREATE OR REPLACE FUNCTION is_primary_hrbp_of(emp_id BIGINT) RETURNS BOOLEAN
COMMENT 'True when the acting HRBP covers emp_id through at least one PRIMARY assignment.'
RETURN coalesce(acting_role() = 'hrbp', false) AND EXISTS (
  SELECT 1 FROM hrbp_scope_detail d
  WHERE d.hrbp_employee_id = acting_as() AND d.employee_id = emp_id AND d.coverage_role = 'Primary');

CREATE OR REPLACE FUNCTION mask_national_id(val STRING, emp_id BIGINT) RETURNS STRING
RETURN CASE
  WHEN coalesce(acting_role() = 'hr_admin', false) OR coalesce(acting_as() = emp_id, false) THEN val
  WHEN can_see_sensitive(emp_id) AND is_primary_hrbp_of(emp_id) THEN concat('NID-*****', right(val, 4))
END;
-- (The mask is already attached to employee_profile.national_id, and replacing the function keeps it.)

-- Rerun: activity step 3 (act as hrbp_b). Inside the shared leader's org, if hrbp_b is the Secondary
-- HRBP there, salaries stay visible but national IDs turn NULL. Check which role hrbp_b has first:
SELECT coverage_role FROM tema_hr_raw.hrbp_assignments
WHERE hrbp_employee_id = hrbp_b AND leader_employee_id = shared_leader AND effective_to IS NULL;

SELECT count(*) AS in_shared_org,
       count(p.annual_base_salary) AS salaries_visible,
       count(p.national_id)        AS national_ids_visible     -- expect 0 if hrbp_b is Secondary here
FROM employee_profile p
JOIN org_closure o ON o.employee_id = p.employee_id AND o.ancestor_id = shared_leader;
-- Subtle case to write down: someone in two leaders' orgs where the HRBP is Primary for one and
-- Secondary for the other still shows the partial ID, because "any primary assignment" wins.


-- =====================================================================================
-- Reset: rerun sections 2 to 4 of 01_hrbp_access_model.sql to restore the original policy,
-- then switch back to HR admin.
-- =====================================================================================
DELETE FROM access_personas WHERE user_email = current_user();
INSERT INTO access_personas VALUES (current_user(), 'hr_admin', NULL);
