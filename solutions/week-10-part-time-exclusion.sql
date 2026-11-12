-- =====================================================================================
-- Week 10 answer key, step 3: exclude part-time employees from attrition
--   (a) the change to retention_metrics.sql
--   (b) the Week 4 truth query with the same exclusion, and the metric view check
-- Untested in Databricks.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- (a) retention_metrics.sql: add the exclusion to EVERY building block, numerators AND
--     denominators. Only the changed measures are shown; the rates don't change because
--     they're built from these.
-- -------------------------------------------------------------------------------------
/*
  - name: leavers_t12m
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month AND source.employment_type <> 'Part-time')
    window: [...unchanged...]
  - name: voluntary_leavers_t12m
    expr: COUNT(1) FILTER (WHERE source.is_voluntary_termination_in_month AND source.employment_type <> 'Part-time')
  - name: regretted_leavers_t12m
    expr: COUNT(1) FILTER (WHERE source.is_regretted_termination_in_month AND source.employment_type <> 'Part-time')
  - name: avg_headcount_t12m
    expr: COUNT(1) FILTER (WHERE source.is_active_month_end AND source.employment_type <> 'Part-time') / COUNT(DISTINCT source.snapshot_month)
  - name: first_year_leavers_t12m
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month AND source.is_first_year AND source.employment_type <> 'Part-time')
  - name: first_year_avg_headcount_t12m
    expr: COUNT(1) FILTER (WHERE source.is_active_month_end AND source.is_first_year AND source.employment_type <> 'Part-time') / COUNT(DISTINCT source.snapshot_month)
  - name: leavers   # the simple monthly count: decide, and say so in the definitions doc
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
*/
-- Also update the comment on attrition_rate_t12m, e.g. "...Excludes part-time employees from both
-- leavers and headcount." The definition and the YAML change in the same pull request.
--
-- The classic mistake: excluding part-timers from leavers but not from average headcount. That gives
-- 581 / 4,655 = 12.5%, which understates attrition because the denominator still has part-timers.
-- Excluding from both gives 12.9%.

-- -------------------------------------------------------------------------------------
-- (b) Week 4 truth query, with the same exclusion
-- -------------------------------------------------------------------------------------
WITH monthly AS (
  SELECT snapshot_month,
         COUNT_IF(is_active_month_end)                AS headcount,
         COUNT_IF(is_termination_in_month)            AS leavers,
         COUNT_IF(is_voluntary_termination_in_month)  AS voluntary_leavers,
         COUNT_IF(is_regretted_termination_in_month)  AS regretted_leavers
  FROM workspace.tema_hr_gold.fact_headcount_monthly
  WHERE employment_type <> 'Part-time'          -- the only change
  GROUP BY ALL
)
SELECT snapshot_month,
       SUM(leavers)  OVER w AS leavers_t12m,
       AVG(headcount) OVER w AS avg_headcount_t12m,
       ROUND(100 * SUM(leavers) OVER w / AVG(headcount) OVER w, 1)           AS attrition_t12m_pct,
       ROUND(100 * SUM(voluntary_leavers) OVER w / AVG(headcount) OVER w, 1) AS voluntary_t12m_pct,
       ROUND(100 * SUM(regretted_leavers) OVER w / AVG(headcount) OVER w, 1) AS regretted_t12m_pct
FROM monthly
WINDOW w AS (ORDER BY snapshot_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW)
ORDER BY snapshot_month DESC;

-- Expected at 5,000 people, all employees → excluding part-time:
--                       Oct 2025            Oct 2026
--   Leavers (T12M)        499 → 473           608 → 581
--   Avg headcount       4,151 → 3,997       4,655 → 4,488
--   Attrition           12.0% → 11.8%       13.1% → 12.9%
--   Voluntary            9.4% →  9.3%       10.0% →  9.9%
--   Regretted            3.6% →  3.6%        4.3% →  4.2%
--   First-year          21.3% → 20.9%       24.0% → 24.0%
-- By division, Oct 2026, the biggest move is Trust & Safety, 22.2% → 21.6%: about 11% of its people are
-- part-time, against 2% to 4% elsewhere.

-- Metric view check: the two sides should match (expect 0 rows)
SELECT m.month, m.attrition, t.attrition
FROM (SELECT month, ROUND(100 * MEASURE(attrition_rate_t12m), 1) AS attrition
      FROM workspace.tema_hr_semantic.retention_metrics GROUP BY ALL) m
JOIN (
  WITH monthly AS (
    SELECT snapshot_month, COUNT_IF(is_active_month_end) AS headcount, COUNT_IF(is_termination_in_month) AS leavers
    FROM workspace.tema_hr_gold.fact_headcount_monthly
    WHERE employment_type <> 'Part-time' GROUP BY ALL)
  SELECT snapshot_month AS month,
         ROUND(100 * SUM(leavers) OVER w / AVG(headcount) OVER w, 1) AS attrition
  FROM monthly WINDOW w AS (ORDER BY snapshot_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW)
) t USING (month)
WHERE m.attrition <> t.attrition;
-- If every month differs slightly, your metric view's trailing window probably excludes the current
-- month (the 13.3% issue from Week 4): change the truth query's window to match what you documented.

-- For the PR description: "October 2026 trailing 12-month attrition goes from 13.1% to 12.9% (voluntary
-- 10.0% to 9.9%). Sign-off: Head of People Analytics as metric owner, with the CHRO's delegate, because it
-- changes a number reported to the leadership team."
