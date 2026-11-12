-- =====================================================================================
-- Week 9 answer key
--   Step 1: small-group suppression, both approaches, and which to recommend
--   Step 5: queries for the "Semantic layer adoption and access" dashboard
-- Assumes pay_metrics from the Week 5 key (it has headcount and division). Untested in Databricks.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- Step 1. See the problem: 68 division x level groups in Oct 2026, 13 of them under 5 people
-- (every VP and SVP group, E1 and E2, and Trust & Safety IC6).
-- -------------------------------------------------------------------------------------
SELECT division, job_level, MEASURE(headcount) AS headcount, MEASURE(avg_compa_ratio) AS avg_compa_ratio
FROM workspace.tema_hr_semantic.pay_metrics
WHERE month = '2026-10-31'
GROUP BY ALL HAVING MEASURE(headcount) < 5
ORDER BY division, job_level;
-- If HAVING on a measure isn't allowed, wrap it: SELECT * FROM (... GROUP BY ALL) WHERE headcount < 5.

-- -------------------------------------------------------------------------------------
-- Approach 1. A suppressed view on top of the metric view
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.pay_by_level_safe
COMMENT 'Average compa-ratio by month, division and job level. Groups under 5 people are suppressed (NULL). Use this for dashboards.'
AS
SELECT month, division, job_level,
       CASE WHEN headcount >= 5 THEN avg_compa_ratio END AS avg_compa_ratio,
       CASE WHEN headcount >= 5 THEN headcount END       AS headcount,
       headcount < 5                                     AS is_suppressed
FROM (SELECT month, division, job_level,
             MEASURE(avg_compa_ratio) AS avg_compa_ratio, MEASURE(headcount) AS headcount
      FROM workspace.tema_hr_semantic.pay_metrics GROUP BY ALL);

-- Check: expect 0 rows with a value for a group under 5
SELECT * FROM workspace.tema_hr_semantic.pay_by_level_safe
WHERE month = '2026-10-31' AND is_suppressed AND avg_compa_ratio IS NOT NULL;

-- Weakness: it's fixed at month x division x level. Grouping it by division alone re-aggregates
-- an average of averages, which is wrong, and you can't slice by region at all.

-- -------------------------------------------------------------------------------------
-- Approach 2. The rule inside the measure (add to pay_metrics.sql)
-- -------------------------------------------------------------------------------------
/*
  - name: avg_compa_ratio_safe
    display_name: Average compa-ratio (suppressed under 5)
    comment: "Average compa-ratio, or empty when the group has fewer than 5 people at period end."
    expr: >
      CASE WHEN COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end) >= 5
           THEN AVG(source.annual_base_salary / (job.salary_band_mid * loc.location_pay_factor))
                FILTER (WHERE source.is_active_month_end)
      END
    window:
      - order: month
        range: current
        semiadditive: last
*/
SELECT division, job_level, MEASURE(avg_compa_ratio_safe) AS avg_compa_ratio
FROM workspace.tema_hr_semantic.pay_metrics
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY division, job_level;     -- the 13 small groups come back NULL

-- Recommendation (one defensible answer):
--   Approach 2, the rule inside the measure. It works at whatever grain someone groups by (division,
--   region, level, any combination), so the rule can't be bypassed by slicing differently, and Genie
--   and BI tools inherit it. Then grant the broad audience the _safe measure only, by putting it in
--   its own metric view, because a metric view grant covers all its measures. Approach 1 is a fallback
--   if the CASE-around-aggregates form is refused in a windowed measure.
--
-- The subtraction problem (one sentence for the governance doc):
--   "A suppressed value can be recovered by subtracting the shown groups from the division total, so
--    for pay we also suppress the next-smallest group in any breakdown that has a suppressed cell
--    (complementary suppression), and only publish fixed breakdowns for the broad audience."
-- Other acceptable answers: round or band small values, or require the total to be suppressed too.

-- -------------------------------------------------------------------------------------
-- Step 5. Adoption and access dashboard: three datasets
-- Run DESCRIBE system.query.history and DESCRIBE system.access.audit first; column names change.
-- -------------------------------------------------------------------------------------

-- Dataset 1: queries per metric view per week (bar chart, stacked by metric view)
WITH metric_views AS (
  SELECT explode(array('workforce_metrics', 'retention_metrics', 'talent_acquisition_metrics',
                       'experience_metrics', 'pay_metrics', 'business_metrics')) AS metric_view
)
SELECT date_trunc('WEEK', q.start_time) AS week,
       mv.metric_view,
       COUNT(*)                     AS queries,
       COUNT(DISTINCT q.executed_by) AS users
FROM system.query.history q
JOIN metric_views mv
  ON lower(q.statement_text) LIKE concat('%tema_hr_semantic.', mv.metric_view, '%')
WHERE q.start_time >= current_date() - INTERVAL 90 DAYS
  AND q.execution_status = 'FINISHED'
GROUP BY ALL
ORDER BY week DESC, queries DESC;

-- Dataset 2: distinct users of the semantic layer per week (counter for "this week", line for trend)
SELECT date_trunc('WEEK', start_time) AS week,
       COUNT(DISTINCT executed_by)    AS distinct_users,
       COUNT(*)                       AS queries
FROM system.query.history
WHERE lower(statement_text) LIKE '%tema_hr_semantic.%'
  AND start_time >= current_date() - INTERVAL 90 DAYS
GROUP BY ALL ORDER BY week DESC;

-- Dataset 3: every access to tema_hr_secure (table; newest first)
-- From the audit log (who touched which object)...
SELECT event_time,
       user_identity.email AS user_email,
       service_name,
       action_name,
       coalesce(request_params['full_name_arg'], request_params['name'], request_params['table_full_name']) AS object_name  -- request_params is a map
FROM system.access.audit
WHERE event_time >= current_date() - INTERVAL 90 DAYS
  AND to_json(request_params) ILIKE '%tema_hr_secure%'
ORDER BY event_time DESC;

-- ...and from query history (what they ran), which is often easier to read
SELECT start_time, executed_by, statement_type, left(statement_text, 300) AS statement_preview
FROM system.query.history
WHERE lower(statement_text) LIKE '%tema_hr_secure%'
  AND start_time >= current_date() - INTERVAL 90 DAYS
ORDER BY start_time DESC;

-- Notes:
--  * Text matching on statement_text is a heuristic: it counts a query that only mentions a view in a
--    comment, and misses access through another view. system.access.table_lineage (if available) is
--    more accurate for "which tables were read".
--  * In a single-user workspace every row is you, including the act-as personas from Week 8, which all
--    run under your login. That's the point to make at work: audit shows the login, so personas or
--    shared service accounts hide who really looked.
--  * Dashboards and Genie run queries too; with embedded credentials they show up as the publisher,
--    another reason to prefer viewer credentials for HR data.
