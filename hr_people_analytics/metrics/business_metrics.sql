-- =====================================================================================
-- Tema reference build · Week 11 · business_metrics
-- labs/week-11, step 3. Run after gold/10_fact_ad_revenue.sql. 2025-Q2 ad revenue about $792.0M;
-- revenue per employee for 2025-Q2 about $189.6k (see metrics/checks/cross_domain_checks.sql).
-- =====================================================================================

DECLARE OR REPLACE VARIABLE tema_catalog STRING DEFAULT 'workspace';  -- your catalog: see README, "Choose your catalog"
USE CATALOG IDENTIFIER(tema_catalog);
-- Metric view YAML needs full three-part names, so it says {catalog} and replace() fills in tema_catalog.
-- The YAML sits in a "..." SQL string, so it uses single quotes only (write an apostrophe as '').
DECLARE OR REPLACE VARIABLE metric_view_sql STRING;
SET VAR metric_view_sql = 'CREATE OR REPLACE VIEW ' || tema_catalog || '.tema_hr_semantic.business_metrics
WITH METRICS LANGUAGE YAML AS $$' || replace("
version: 1.1
comment: 'Tema (fictional) monthly ad revenue and advertiser support tickets. Synthetic, sized for a 70,000-person company. Both measures are additive over time.'
source: {catalog}.tema_hr_gold.fact_business_monthly
joins:
  - name: dt
    source: {catalog}.tema_hr_gold.dim_date
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
    comment: 'Total ad revenue in the period. Additive: a quarter is the sum of its months.'
    synonyms: ['revenue', 'sales', 'ad sales']
    expr: SUM(source.ad_revenue_usd)
  - name: support_tickets
    display_name: Advertiser support tickets
    expr: SUM(source.support_tickets)
  - name: months_with_data
    display_name: Months with data
    comment: 'Number of months in the period that have data. Use it to spot partial periods: 2026-Q4 only has October.'
    expr: COUNT(1)
", '{catalog}', tema_catalog) || '$$';
EXECUTE IMMEDIATE metric_view_sql;
