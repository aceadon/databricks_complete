-- =====================================================================================
-- Tema reference build · Week 3 · the semantic schema and the naive view
-- labs/week-03, step 1. The naive view exists to show the problem (2025-Q2 "headcount" = 12,429)
-- and is marked deprecated in Week 9. Never point a dashboard or Genie at it.
-- =====================================================================================
USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS tema_hr_semantic
  COMMENT 'Tema (fictional) people metrics: certified definitions for dashboards, Genie and BI tools.';

CREATE OR REPLACE VIEW tema_hr_semantic.v_headcount_naive
COMMENT 'DEPRECATED teaching example: pre-aggregated headcount that gives the wrong answer when summed over a quarter. Use workforce_metrics.'
AS
SELECT f.snapshot_month, d.year_quarter, dept.division,
       COUNT_IF(f.is_active_month_end) AS headcount
FROM tema_hr_gold.fact_headcount_monthly f
JOIN tema_hr_gold.dim_date d ON d.month_end = f.snapshot_month
JOIN tema_hr_gold.dim_department dept ON dept.department_id = f.department_id
GROUP BY ALL;
