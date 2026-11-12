-- =====================================================================================
-- Week 11 answer key, step 3: business_metrics and the cross-domain questions
-- Save the view as hr_people_analytics/metrics/business_metrics.sql. Untested in Databricks.
-- =====================================================================================

CREATE OR REPLACE VIEW workspace.tema_hr_semantic.business_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema (fictional) monthly ad revenue and advertiser support tickets. Synthetic, sized for a 70,000-person company. Both measures are additive over time."
source: workspace.tema_hr_gold.fact_business_monthly
joins:
  - name: dt
    source: workspace.tema_hr_gold.dim_date
    on: source.month_end = dt.month_end
dimensions:
  - name: month
    expr: source.month_end
    display_name: Month
  - name: quarter
    expr: dt.year_quarter
    display_name: Quarter
  - name: year
    expr: dt.year
    display_name: Year
measures:
  - name: ad_revenue
    display_name: Ad revenue (USD)
    comment: "Total ad revenue in the period. Additive: a quarter is the sum of its months."
    synonyms: ["revenue", "sales", "ad sales"]
    expr: SUM(source.ad_revenue_usd)
  - name: support_tickets
    display_name: Advertiser support tickets
    expr: SUM(source.support_tickets)
  - name: months_with_data
    display_name: Months with data
    comment: "Number of months in the period that have data. Use it to spot partial periods: 2026-Q4 only has October."
    expr: COUNT(1)
$$;

-- Note the names: the dimension that matches workforce_metrics must be called the same (month, quarter)
-- and hold the same values (month-end dates, 'YYYY-Qn'), or the join below silently returns nothing.

-- -------------------------------------------------------------------------------------
-- Option 1. Revenue per employee by quarter
-- -------------------------------------------------------------------------------------
SELECT p.quarter, b.revenue, p.headcount,
       ROUND(b.revenue / p.headcount) AS revenue_per_employee
FROM (SELECT quarter, MEASURE(headcount) AS headcount
      FROM workspace.tema_hr_semantic.workforce_metrics GROUP BY ALL) p
JOIN (SELECT quarter, MEASURE(ad_revenue) AS revenue, MEASURE(months_with_data) AS months
      FROM workspace.tema_hr_semantic.business_metrics GROUP BY ALL) b USING (quarter)
WHERE b.months = 3                       -- drop 2026-Q4, which only has October
ORDER BY quarter;

-- Expected at 5,000 people (headcount = quarter-end, revenue = sum of 3 months):
--   2023-Q1  4,076  $561.6M  $137.8k        2025-Q1  4,090  $750.0M  $183.4k
--   2023-Q4  3,943  $580.2M  $147.2k        2025-Q2  4,176  $792.0M  $189.6k
--   2024-Q1  3,943  $649.0M  $164.6k        2025-Q4  4,399  $844.0M  $191.9k
--   2024-Q4  4,046  $670.2M  $165.6k        2026-Q2  4,720  $1,071.9M $227.1k
--                                           2026-Q3  4,926  $1,068.5M $216.9k
-- Story: revenue per employee rose from about $138k to $227k a quarter, and kept rising after the AI
-- launch in May 2025 even as headcount grew 18%, then dipped slightly in 2026-Q3 as AI hiring outpaced
-- revenue growth. (The revenue is sized for 70,000 people, so the absolute value per employee is about
-- 14 times too high at 5,000. Compare the trend, not the level.)
--
-- Two traps this query avoids:
--   1. Headcount summed over the quarter (12,429 for 2025-Q2) would cut revenue per employee to a third.
--   2. Including 2026-Q4 shows a collapse to about $72k, because it's one month of revenue over a full
--      quarter-end headcount. months_with_data makes that visible.

-- -------------------------------------------------------------------------------------
-- Option 2. AI cost vs revenue growth (monthly)
-- -------------------------------------------------------------------------------------
SELECT w.month, w.ai_headcount, w.ai_avg_salary,
       w.ai_headcount * w.ai_avg_salary AS ai_annual_base_payroll,   -- annualised base pay, not cost
       b.revenue AS monthly_revenue
FROM (SELECT month, MEASURE(headcount) AS ai_headcount, MEASURE(average_salary) AS ai_avg_salary
      FROM workspace.tema_hr_semantic.workforce_metrics WHERE division = 'AI' GROUP BY ALL) w
JOIN (SELECT month, MEASURE(ad_revenue) AS revenue
      FROM workspace.tema_hr_semantic.business_metrics GROUP BY ALL) b USING (month)
ORDER BY month;
-- Expected: April 2025, 99 AI people, about $28.0M annual base payroll, $263.3M monthly revenue.
-- October 2026, 674 people, about $186.5M payroll (6.7x), $363.4M revenue (1.4x).
-- Caveat to state: base salary only. Equity, bonus, benefits and compute costs are missing, and AI hires
-- came in above band, so true AI cost grew even faster.

-- -------------------------------------------------------------------------------------
-- Option 3. Support load: tickets per Advertiser Support employee, next to its attrition
-- -------------------------------------------------------------------------------------
SELECT w.month, b.tickets, w.headcount,
       ROUND(b.tickets / w.headcount) AS tickets_per_employee,
       r.attrition
FROM (SELECT month, MEASURE(headcount) AS headcount
      FROM workspace.tema_hr_semantic.workforce_metrics
      WHERE department = 'Advertiser Support' GROUP BY ALL) w
JOIN (SELECT month, MEASURE(support_tickets) AS tickets
      FROM workspace.tema_hr_semantic.business_metrics GROUP BY ALL) b USING (month)
JOIN (SELECT month, MEASURE(attrition_rate_t12m) AS attrition
      FROM workspace.tema_hr_semantic.retention_metrics
      WHERE department = 'Advertiser Support' GROUP BY ALL) r USING (month)
ORDER BY month;
-- Expected tickets per employee: Jan 2023 183, Jan 2024 208, Jan 2025 209, Oct 2025 223, Oct 2026 271.
-- Headcount stays flat (about 240 to 265) while tickets grow about 1% a month, so load per person is up
-- by half since 2023. Whether attrition follows load is the question to put to the business; with
-- synthetic data, any correlation is a feature of the generator, so say so.

-- -------------------------------------------------------------------------------------
-- Multi-fact alternative (Public Preview): one view over both facts
-- -------------------------------------------------------------------------------------
-- The two-view join works today but leaves the "same grain" rule to whoever writes the query. A multi-fact
-- metric view declares both facts and their shared dimensions once, so MEASURE(ad_revenue) / MEASURE(headcount)
-- can be a measure (revenue_per_employee) that Genie and BI tools get right too. Check the docs for the
-- current syntax, then compare: does the multi-fact version get 2025-Q2 right (about $189.6k)?
