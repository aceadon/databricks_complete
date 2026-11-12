-- =====================================================================================
-- Tema reference · Week 11 · cross-domain answers (5,000 people)
-- Full set with all three options and their expected values: solutions/week-11-business-metrics.sql
-- =====================================================================================
-- Revenue per employee by quarter (quarter-end headcount, 3-month revenue). 2025-Q2 ≈ $189.6k
SELECT p.quarter, b.revenue, p.headcount, ROUND(b.revenue / p.headcount) AS revenue_per_employee
FROM (SELECT quarter, MEASURE(headcount) AS headcount
      FROM workspace.tema_hr_semantic.workforce_metrics GROUP BY ALL) p
JOIN (SELECT quarter, MEASURE(ad_revenue) AS revenue, MEASURE(months_with_data) AS months
      FROM workspace.tema_hr_semantic.business_metrics GROUP BY ALL) b USING (quarter)
WHERE b.months = 3
ORDER BY quarter;
