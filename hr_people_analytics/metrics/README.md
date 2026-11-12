# Metric views (Weeks 3 to 11): finished

| File | Week | Creates in `tema_hr_semantic` |
|---|---|---|
| [`00_semantic_schema.sql`](00_semantic_schema.sql) | 3 | The schema, and `v_headcount_naive` (the wrong way, kept for the demo; deprecated in Week 9) |
| [`workforce_metrics.sql`](workforce_metrics.sql) | 3 | Headcount, FTE, hires, leavers, net change, average salary, span of control |
| [`retention_metrics.sql`](retention_metrics.sql) | 4, 10 | Attrition, voluntary, regretted and first-year (trailing 12 months), part-time excluded from Week 10. The Week 4 version is in [`../../reference/snapshots/`](../../reference/snapshots/) |
| [`talent_acquisition_metrics.sql`](talent_acquisition_metrics.sql) | 5 | Requisitions, open requisitions, median time to fill, offer acceptance, applicants per hire |
| [`experience_metrics.sql`](experience_metrics.sql) | 5 | eNPS, engagement, manager score, responses |
| [`pay_metrics.sql`](pay_metrics.sql) | 5, 9 | Compa-ratio (and its small-group-safe version), average salary, headcount. Restricted |
| [`pay_by_level_safe.sql`](pay_by_level_safe.sql) | 9 | A suppressed view for dashboards: groups under 5 come back empty |
| [`business_metrics.sql`](business_metrics.sql) | 11 | Ad revenue, support tickets, months with data |
| [`checks/`](checks/) | 3–11 | Truth queries and checkpoint queries with the expected numbers |

Each file holds one `CREATE OR REPLACE VIEW … WITH METRICS LANGUAGE YAML` statement and nothing else, so `databricks.yml` can deploy it (Week 10). Every measure has an entry in [docs/metric-definitions.md](../../docs/metric-definitions.md); if the two disagree, the definition wins and the YAML gets fixed.
