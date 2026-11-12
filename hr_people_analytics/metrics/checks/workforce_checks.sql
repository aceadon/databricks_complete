-- =====================================================================================
-- Tema reference · Week 3 · workforce_metrics checks (5,000 people)
-- =====================================================================================
-- The naive view vs the metric view: 12,429 vs 4,176
SELECT year_quarter, SUM(headcount) AS wrong_headcount
FROM workspace.tema_hr_semantic.v_headcount_naive WHERE year_quarter = '2025-Q2' GROUP BY ALL;

SELECT quarter, MEASURE(headcount) AS headcount, MEASURE(hires) AS hires, MEASURE(leavers) AS leavers
FROM workspace.tema_hr_semantic.workforce_metrics WHERE quarter = '2025-Q2' GROUP BY ALL;   -- 4,176

-- Year to date 2026: headcount 5,024 · hires 1,126 · leavers 501 · net change +625
SELECT MEASURE(headcount), MEASURE(hires), MEASURE(leavers), MEASURE(net_change)
FROM workspace.tema_hr_semantic.workforce_metrics
WHERE month BETWEEN '2026-01-01' AND '2026-10-31';

-- Oct 2026 by division: Engineering 1,618 · Ads Business 1,141 · AI 674 · Corporate 577 ·
-- Product & Design 512 · Trust & Safety 502 (total 5,024)
SELECT division, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.workforce_metrics WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY headcount DESC;

-- Oct 2026 by city: San Francisco 1,263 · New York 610 · Bangalore 576 · Seattle 554 · London 533 ·
-- Austin 360 · Dublin 334 · Toronto 277 · Sao Paulo 269 · Singapore 248
SELECT city, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.workforce_metrics WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY headcount DESC;

-- Average salary and span: Oct 2026 ≈ $151,239 and 7.49; year 2025 (= Dec 2025) ≈ $136,789 and 7.32
SELECT year, MEASURE(average_salary) AS average_salary, MEASURE(span_of_control) AS span
FROM workspace.tema_hr_semantic.workforce_metrics WHERE year IN (2025, 2026)
GROUP BY ALL ORDER BY year;

-- Metric view vs a hand-written count, every month (expect 0 rows)
SELECT m.month, m.hc_metric, t.hc_truth
FROM (SELECT month, MEASURE(headcount) AS hc_metric
      FROM workspace.tema_hr_semantic.workforce_metrics GROUP BY ALL) m
JOIN (SELECT snapshot_month, COUNT_IF(is_active_month_end) AS hc_truth
      FROM workspace.tema_hr_gold.fact_headcount_monthly GROUP BY ALL) t
  ON t.snapshot_month = m.month
WHERE m.hc_metric <> t.hc_truth;
