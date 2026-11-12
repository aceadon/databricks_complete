-- =====================================================================================
-- Week 2 answer key: fact_absences and fact_equity_grants (step 1)
-- Same as the hidden answer in the lab sheet, plus checks. Untested in Databricks.
-- =====================================================================================
USE CATALOG workspace;
USE SCHEMA tema_hr_gold;

-- One row per absence, with the employee's team at the end of the month the absence started.
CREATE OR REPLACE TABLE fact_absences AS
SELECT a.absence_id, a.employee_id, a.start_date, a.end_date, a.absence_type, a.days_absent,
       last_day(a.start_date) AS absence_month,
       h.department_id, h.job_id, h.location_id, h.manager_id
FROM tema_hr_raw.absences a
LEFT JOIN tema_hr_raw.headcount_monthly h
  ON h.employee_id = a.employee_id AND h.snapshot_month = last_day(a.start_date);

-- One row per grant, straight from the source.
CREATE OR REPLACE TABLE fact_equity_grants AS
SELECT grant_id, employee_id, grant_date, grant_type, grant_value_usd, grant_price_usd, shares, vesting_years
FROM tema_hr_raw.equity_grants;

-- Checks (at 5,000 people)
SELECT 'fact_absences' t, COUNT(*) n FROM fact_absences UNION ALL            -- 74,392
SELECT 'fact_equity_grants', COUNT(*) FROM fact_equity_grants;               -- 8,276

-- Grain holds: one row per absence and per grant (expect 0 rows each)
SELECT absence_id FROM fact_absences GROUP BY ALL HAVING COUNT(*) > 1;
SELECT grant_id   FROM fact_equity_grants GROUP BY ALL HAVING COUNT(*) > 1;

-- The LEFT JOIN found a team for every absence (expect 0). An absence can only start while
-- the person is employed, so they always have a snapshot row for that month.
SELECT COUNT(*) FROM fact_absences WHERE department_id IS NULL;

-- Why LEFT JOIN and not JOIN: if a source ever has an absence outside the snapshot, a JOIN would
-- silently drop it and undercount days absent. A LEFT JOIN keeps it with an empty department,
-- which the check above makes visible.
