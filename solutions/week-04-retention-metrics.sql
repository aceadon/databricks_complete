-- =====================================================================================
-- Week 4 answer key
--   Step 4: last year by division, and two sentences for a VP
--   Step 5: first-year attrition measures (add them to the measures list of retention_metrics)
-- Untested in Databricks.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- Step 4. Same question for October 2025
-- -------------------------------------------------------------------------------------
SELECT division,
       MEASURE(attrition_rate_t12m)           AS attrition,
       MEASURE(voluntary_attrition_rate_t12m) AS voluntary,
       MEASURE(regretted_attrition_rate_t12m) AS regretted
FROM workspace.tema_hr_semantic.retention_metrics
WHERE month = '2025-10-31'
GROUP BY ALL ORDER BY attrition DESC;

-- Expected at 5,000 people (trailing 12 months, %), October 2025 → October 2026:
--   Division           Attrition      Voluntary      Regretted
--   Trust & Safety     20.8 → 22.2    17.0 → 18.1    6.8 → 7.5
--   AI                 15.6 → 20.6    14.8 → 15.0    8.6 → 10.2
--   Ads Business       14.6 → 15.8    10.7 → 12.1    4.3 → 4.5
--   Corporate           8.8 → 10.6     6.6 →  8.5    2.3 → 3.2
--   Product & Design    7.8 → 10.6     6.5 →  7.8    2.3 → 3.6
--   Engineering         9.6 →  7.9     7.7 →  5.8    2.6 → 2.1
--   Tema overall       12.0 → 13.1     9.4 → 10.0    3.6 → 4.3
--
-- Two sentences a VP would understand (one good version):
--   "Attrition rose from 12.0% to 13.1% over the past year, and the biggest jump was in AI (15.6% to
--    20.6%), where half the people we lose are people we wanted to keep, so the AI hiring push is
--    partly refilling seats competitors are emptying. Trust & Safety is still our highest-turnover
--    team at over 22%, while Engineering is the one area that improved, falling below 8%."
-- What makes it good: one headline number with its direction, the biggest change named, a "so what"
-- (regretted losses in AI), and no jargon like "T12M" or "semi-additive".

-- -------------------------------------------------------------------------------------
-- Step 5. First-year attrition: add these to the measures in retention_metrics.sql
-- -------------------------------------------------------------------------------------
/*
  - name: first_year_leavers_t12m
    display_name: First-year leavers (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month AND source.is_first_year)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: first_year_avg_headcount_t12m
    display_name: First-year average headcount (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_active_month_end AND source.is_first_year) / COUNT(DISTINCT source.snapshot_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: first_year_attrition_rate_t12m
    display_name: First-year attrition rate (trailing 12 months)
    comment: "Leavers with under 12 months' tenure in the 12 months ending with the period, divided by the average month-end headcount of people with under 12 months' tenure over the same months."
    synonyms: ["new hire attrition", "early attrition", "first year turnover"]
    format:
      type: percentage
    expr: MEASURE(first_year_leavers_t12m) / MEASURE(first_year_avg_headcount_t12m)
*/

-- Check against the metric view: expect 21.3% for Oct 2025 and 24.0% for Oct 2026
SELECT month, MEASURE(first_year_attrition_rate_t12m) AS first_year_attrition
FROM workspace.tema_hr_semantic.retention_metrics
WHERE month IN ('2025-10-31', '2026-10-31')
GROUP BY ALL ORDER BY month;

-- Truth query (add these columns to checks/attrition_truth.sql)
WITH monthly AS (
  SELECT snapshot_month,
         COUNT_IF(is_termination_in_month AND is_first_year) AS first_year_leavers,
         COUNT_IF(is_active_month_end AND is_first_year)     AS first_year_headcount
  FROM workspace.tema_hr_gold.fact_headcount_monthly
  GROUP BY ALL
)
SELECT snapshot_month,
       ROUND(100 * SUM(first_year_leavers) OVER w / AVG(first_year_headcount) OVER w, 1) AS first_year_t12m_pct
FROM monthly
WINDOW w AS (ORDER BY snapshot_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW)
ORDER BY snapshot_month DESC;

-- By division, Oct 2026: Trust & Safety 40.6%, Ads Business 34.3%, AI 25.2%, Product & Design 16.7%,
-- Corporate 16.6%, Engineering 10.7%. Trust & Safety loses two in five people within their first year.
--
-- Subtle point for the definitions doc: is_first_year uses tenure at the month end of the leaving month,
-- so someone who leaves on day 360 but whose month end falls after their first anniversary counts as a
-- second-year leaver. Fine for a dashboard, worth one line in the caveats.
