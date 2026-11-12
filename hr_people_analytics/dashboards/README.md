# Dashboards (Week 6, and Week 9's adoption dashboard)

## Tema Workforce Overview

[`tema_workforce_overview.lvdash.json`](tema_workforce_overview.lvdash.json) is the finished Week 6 dashboard. Every dataset queries a metric view in `tema_hr_semantic`; none touches a gold table.

**Open it:** in your Git folder, click the file. Databricks opens `.lvdash.json` files as dashboards. If it opens as text instead, use **Dashboards > Create dashboard > ⋮ > Import dashboard from file** and pick it.

**Point it at the reference:** the datasets read `workspace.tema_hr_semantic`, which is your own work. To see the reference instead, edit each dataset on the **Data** tab and change `tema_hr_semantic` to `tema_ref_semantic`. Showing both side by side is a quick visual check.

> [!WARNING]
> **Untested in Databricks.** The JSON was written by hand to the dashboard file format, not exported from a workspace. If it won't import, or a widget shows an error, rebuild that widget from the table below (it takes about 20 minutes), then export your working version over this file.

| # | Widget | Dataset (all SQL on metric views) | Shape | Expect at 5,000 people |
|---|---|---|---|---|
| 1 | Headcount, October 2026 | `kpi_latest`: `MEASURE(headcount)` by division, `month = '2026-10-31'` | Counter, SUM over divisions | 5,024 |
| 2 | Change since January | `kpi_ytd`: `MEASURE(net_change)` by division, Jan to Oct 2026 | Counter | +625 |
| 3 | Division filter | Applies to widgets 1, 2, 4, 5 | Multi-select | Pick "AI": headcount 674, attrition bar shows AI only |
| 4 | Headcount by month and division | `hc_trend`: `MEASURE(headcount)` by month, division | Stacked area | Oct 2026 stack = 5,024 |
| 5 | Attrition by division, October 2026 | `attrition_latest`: `MEASURE(attrition_rate_t12m)` by division | Bar, sorted | Trust & Safety and AI highest |
| 6–7 | Hiring since May 2025, AI vs rest | `hiring_ai_vs_rest`: median days to fill and offer acceptance | Two bars | 67 vs 41 days; about 70% vs 84% |
| 8 | eNPS by survey cycle | `enps_company`: `MEASURE(enps)` by cycle | Line | −7.1 → +16.7 |
| 9–10 | AI growth story (the Week 6 "Your turn") | `ai_growth`: AI headcount joined to AI regretted attrition on `month` | Bar and line side by side | 674 people; regretted about 10% |

Design choices worth copying:

- **Datasets are pre-grouped by the dimensions the filters need** (for example `division`), so the widget only adds up things that are safe to add. Headcount adds across divisions; attrition and eNPS never get summed, which is why widgets 5, 8 and 10 use `MAX` over rows that are already one value each.
- **eNPS isn't connected to the Division filter.** It would be fine to filter it, but a whole-company line next to division bars is easier to read. Add `enps_by_cycle` to the filter if you prefer.
- **Quarter check (lab step 5):** in `hc_trend`, change the grouping to `quarter` and confirm 2025-Q2 shows 4,176, not 12,429.
- **Sharing (lab step 6):** publish with **viewer credentials** for HR data, so the Week 8 row filters and masks apply per person. Embedded credentials show every viewer what the publisher sees.

## Semantic layer adoption and access (Week 9)

Not shipped as JSON, because system table columns vary by workspace. Build it from the three datasets in [`../governance/04_adoption_and_access_queries.sql`](../governance/04_adoption_and_access_queries.sql): queries per metric view per week (stacked bar), distinct users per week (counter and line), and every access to `tema_hr_secure` (table).
