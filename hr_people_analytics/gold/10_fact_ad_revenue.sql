-- =====================================================================================
-- Tema reference build · Week 11 · synthetic business data
-- Finished state of hr_people_analytics/gold/10_fact_ad_revenue.sql (labs/week-11, step 2).
-- Fictional monthly ad revenue and advertiser support tickets, sized for a 70,000-person company.
-- Checkpoint: 46 rows (Jan 2023 to Oct 2026).
-- =====================================================================================
USE CATALOG workspace;
USE SCHEMA tema_hr_gold;

CREATE OR REPLACE TABLE fact_business_monthly
COMMENT 'One row per month: synthetic ad revenue (USD) and advertiser support tickets for Tema. Fictional, for cross-domain demos. Both columns are additive over time.'
AS
SELECT month_end,
       ROUND(180000000 * POW(1.012, n) * (1 + 0.06 * SIN(n / 1.9))
             * CASE WHEN month_end >= '2025-05-31' THEN 1 + 0.015 * (n - 28) ELSE 1 END, -3) AS ad_revenue_usd,
       ROUND(42000 * POW(1.01, n) * (1 + 0.1 * COS(n / 2.3)))                                AS support_tickets
FROM (SELECT month_end, ROW_NUMBER() OVER (ORDER BY month_end) - 1 AS n
      FROM dim_date WHERE month_end <= '2026-10-31');

ALTER TABLE fact_business_monthly ALTER COLUMN month_end       COMMENT 'Last day of the month. Join to dim_date.month_end.';
ALTER TABLE fact_business_monthly ALTER COLUMN ad_revenue_usd  COMMENT 'Total ad revenue booked in the month, USD. Synthetic.';
ALTER TABLE fact_business_monthly ALTER COLUMN support_tickets COMMENT 'Advertiser support tickets opened in the month. Synthetic.';
ALTER TABLE fact_business_monthly SET TAGS ('domain' = 'business');
