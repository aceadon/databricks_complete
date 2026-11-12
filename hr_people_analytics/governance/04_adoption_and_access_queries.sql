-- =====================================================================================
-- Tema reference · Week 9, step 5 · datasets for the "Semantic layer adoption and access" dashboard
-- Needs system tables (an admin may have to enable them; Free Edition may expose only some).
-- Run DESCRIBE system.query.history and DESCRIBE system.access.audit first: column names change.
-- Not run by the reference build. Same as the end of solutions/week-09-suppression-and-adoption.sql.
-- =====================================================================================
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
