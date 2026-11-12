# Gold layer (Weeks 1, 2 and 11): finished

Run in this order. Each file is the finished state of the lab steps named in its header.

| File | Week | Creates |
|---|---|---|
| [`01_dimensions.sql`](01_dimensions.sql) | 1 | `dim_department`, `dim_location`, `dim_job`, `dim_employee` (no sensitive fields), `dim_employee_sensitive`, `dim_manager`, `dim_date` |
| [`02_facts.sql`](02_facts.sql) | 2 | `fact_headcount_monthly`, `fact_terminations`, `fact_requisitions`, `fact_engagement`, `fact_absences`, `fact_equity_grants` |
| [`03_keys_and_comments.sql`](03_keys_and_comments.sql) | 2 | Primary and foreign keys, and a comment on every table and column. Rerunnable |
| [`04_tags.sql`](04_tags.sql) | 2 | `domain`, `hr_sensitivity`, `pii` and `compensation` tags |
| [`10_fact_ad_revenue.sql`](10_fact_ad_revenue.sql) | 11 | `fact_business_monthly` (synthetic revenue and support tickets) |

Rebuilding a table with `CREATE OR REPLACE TABLE` drops its keys, comments and tags, so rerun 03 and 04 after 01 or 02.
