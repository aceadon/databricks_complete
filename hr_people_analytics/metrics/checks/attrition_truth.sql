-- =====================================================================================
-- Tema reference · Weeks 4 and 10 · attrition truth query
-- Hand-written attrition you trust, to test retention_metrics against.
-- Set the filter in `monthly` to match the definition you are testing:
--   Week 4 definition (all employees):         Oct 2026 = 608 / 4,655 = 13.1%  (Oct 2025 12.0%)
--   Week 10 definition (part-time excluded):    Oct 2026 = 581 / 4,488 = 12.9%  (Oct 2025 11.8%)
-- Voluntary 10.0% -> 9.9%, regretted 4.3% -> 4.2%, first-year 24.0% -> 24.0%.
-- =====================================================================================
WITH monthly AS (
  SELECT snapshot_month,
         COUNT_IF(is_active_month_end)                       AS headcount,
         COUNT_IF(is_termination_in_month)                   AS leavers,
         COUNT_IF(is_voluntary_termination_in_month)         AS voluntary_leavers,
         COUNT_IF(is_regretted_termination_in_month)         AS regretted_leavers,
         COUNT_IF(is_termination_in_month AND is_first_year) AS first_year_leavers,
         COUNT_IF(is_active_month_end AND is_first_year)     AS first_year_headcount
  FROM workspace.tema_hr_gold.fact_headcount_monthly
  WHERE employment_type <> 'Part-time'     -- Week 10 definition. Delete this line for the Week 4 definition.
  GROUP BY ALL
)
SELECT snapshot_month,
       SUM(leavers)   OVER w AS leavers_t12m,
       AVG(headcount) OVER w AS avg_headcount_t12m,
       ROUND(100 * SUM(leavers) OVER w / AVG(headcount) OVER w, 1)                       AS attrition_t12m_pct,
       ROUND(100 * SUM(voluntary_leavers) OVER w / AVG(headcount) OVER w, 1)             AS voluntary_t12m_pct,
       ROUND(100 * SUM(regretted_leavers) OVER w / AVG(headcount) OVER w, 1)             AS regretted_t12m_pct,
       ROUND(100 * SUM(first_year_leavers) OVER w / AVG(first_year_headcount) OVER w, 1) AS first_year_t12m_pct
FROM monthly
WINDOW w AS (ORDER BY snapshot_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW)
ORDER BY snapshot_month DESC;

-- Metric view vs truth, every month (expect 0 rows)
SELECT m.month, m.attrition AS metric_view, t.attrition AS truth
FROM (SELECT month, ROUND(100 * MEASURE(attrition_rate_t12m), 1) AS attrition
      FROM workspace.tema_hr_semantic.retention_metrics GROUP BY ALL) m
JOIN (
  WITH monthly AS (
    SELECT snapshot_month, COUNT_IF(is_active_month_end) AS headcount, COUNT_IF(is_termination_in_month) AS leavers
    FROM workspace.tema_hr_gold.fact_headcount_monthly
    WHERE employment_type <> 'Part-time' GROUP BY ALL)
  SELECT snapshot_month AS month, ROUND(100 * SUM(leavers) OVER w / AVG(headcount) OVER w, 1) AS attrition
  FROM monthly WINDOW w AS (ORDER BY snapshot_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW)
) t USING (month)
WHERE m.attrition <> t.attrition;
-- If every month is off a little, the metric view's trailing window probably excludes the current month
-- (the 13.3% issue in labs/week-04). Document which convention you use in docs/metric-definitions.md.

-- By division, Oct 2026 (Week 4 definition): Trust & Safety 22.2%, AI 20.6%, Ads Business 15.8%,
-- Corporate 10.6%, Product & Design 10.6%, Engineering 7.9%. AI regretted 10.2% (highest).
SELECT division,
       MEASURE(attrition_rate_t12m)           AS attrition,
       MEASURE(voluntary_attrition_rate_t12m) AS voluntary,
       MEASURE(regretted_attrition_rate_t12m) AS regretted,
       MEASURE(first_year_attrition_rate_t12m) AS first_year
FROM workspace.tema_hr_semantic.retention_metrics
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY attrition DESC;
