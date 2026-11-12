# Gold table checklist

A short list to share with the migration team. A table that passes is ready for metric views, dashboards and Genie.

- [x] **Clear grain**: the table comment states what one row is ("one row per employee per month").
- [x] **Business names**: tables and columns use the words the business uses, not source-system codes.
- [x] **Every table and column has a comment**, checked by someone who knows the data (AI-generated comments are a starting point, not the answer).
- [x] **Keys are documented**: primary key and foreign keys declared (informational constraints) so tools can join correctly.
- [x] **Sensitive columns are separated or tagged**: personal data and compensation either live in their own table or are tagged (`hr_sensitivity`, `pii`) and masked.
- [x] **An owner is set**: a group, not a person, owns the table.
- [x] **Dates and flags are explicit**: effective dates, `is_current`, `is_active` rather than logic hidden in queries.
- [x] **Quality is monitored**: freshness and basic checks (row counts, nulls in keys) run on a schedule.
- [x] **Certified or marked draft**: users can tell whether to trust it.

## Applied to `fact_headcount_monthly` (Week 2, reference)

| Item | How the reference meets it |
|---|---|
| Clear grain | Table comment: "One row per employee per month they were employed…" |
| Business names | `is_active_month_end`, `is_termination_in_month`, `annual_base_salary` |
| Every column commented | `03_keys_and_comments.sql`; the checkpoint query returns 0 rows |
| Keys | Primary key (`snapshot_month`, `employee_id`); foreign keys to dim_department, dim_job, dim_location, dim_employee, dim_manager, dim_date |
| Sensitive columns | `annual_base_salary` tagged `hr_sensitivity = restricted`, `compensation = base_pay`; personal fields live only in `dim_employee_sensitive` |
| Owner | In Free Edition the owner is you. In production, a group such as `people-analytics-engineering` |
| Dates and flags explicit | `snapshot_month` plus five boolean flags; no logic hidden in queries |
| Quality monitored | Row count and duplicate-key checks in `03_keys_and_comments.sql` and `reference/01_check_my_work`; in production, a scheduled job or data quality monitoring |
| Certified | `system.certification_status = certified` (Week 9) |
