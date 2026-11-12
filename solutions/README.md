# Solutions

Answer keys for every "Your turn" activity in the weekly lab sheets in `labs/`. Try each activity first, then compare.

These files sit apart from the working SQL in `hr_people_analytics/` so they never overwrite your own work. None of them has been run in Databricks yet. The expected numbers are for Tema at **5,000 people (seed 42)**, computed by rebuilding the data from `00_generate_hr_data.py` in DuckDB with the same definitions.

| Week | Activity | Answer key |
|---|---|---|
| 0 | Decisions behind "what's our headcount?" | [week-00-headcount-decisions.md](week-00-headcount-decisions.md) |
| 1 | Department on 2025-01-01; where `gender` belongs | [week-01-dimensions.sql](week-01-dimensions.sql) |
| 2 | `fact_absences` and `fact_equity_grants` | [week-02-facts.sql](week-02-facts.sql) |
| 2 | Primary and foreign keys; comments on every table and column | [week-02-keys-and-comments.sql](week-02-keys-and-comments.sql) |
| 2 | Tag what's sensitive | [week-02-tags.sql](week-02-tags.sql) |
| 3 | `city` dimension; `average_salary` and `span_of_control` | [week-03-workforce-metrics.sql](week-03-workforce-metrics.sql) |
| 4 | Last year by division, for a VP; first-year attrition | [week-04-retention-metrics.sql](week-04-retention-metrics.sql) |
| 5 | `experience_metrics`; `pay_metrics` and compa-ratio; LOD stretch | [week-05-experience-and-pay-metrics.sql](week-05-experience-and-pay-metrics.sql) |
| 5 | Pay equity definition entry | [week-05-pay-equity-note.md](week-05-pay-equity-note.md) |
| 6 | AI growth widget | [week-06-ai-growth-widget.md](week-06-ai-growth-widget.md) |
| 7 | Expected answers for all 20 benchmark questions | [week-07-benchmark-answers.md](week-07-benchmark-answers.md) |
| 8 | Change a policy (all three options) | [week-08-policy-changes.sql](week-08-policy-changes.sql) |
| 8 | Roles table and "From demo to production" | [week-08-governance-production.md](week-08-governance-production.md) |
| 9 | Small-group suppression; adoption and access dashboard | [week-09-suppression-and-adoption.sql](week-09-suppression-and-adoption.sql) |
| 10 | `warehouse_id` variable and tasks for every metric view | [week-10-databricks.yml](week-10-databricks.yml) |
| 10 | Part-time exclusion and the updated truth query | [week-10-part-time-exclusion.sql](week-10-part-time-exclusion.sql) |
| 11 | `business_metrics` and the cross-domain questions | [week-11-business-metrics.sql](week-11-business-metrics.sql) |

Week 12 (the pilot proposal) has no "Your turn" steps. A finished example proposal and demo script are in [`docs/pilot-proposal.md`](../docs/pilot-proposal.md) and [`docs/demo-script.md`](../docs/demo-script.md).

**Rebuilds:** any `CREATE OR REPLACE TABLE` drops that table's constraints, comments and tags, so rerun the Week 2 keys, comments and tags files after rebuilding gold tables.
