# Lab sheets

One sheet per week of the [zero to semantic hero plan](../plan/zero-to-semantic-hero.md). The plan says *what* to learn and why; these sheets say *what to do this week*, in order, and how to know it worked.

| Week | Lab | Phase | You'll finish with |
|---|---|---|---|
| 0 | [Set up and meet Tema](week-00-setup-and-meet-tema.md) | 0 | A workspace, the Tema data, and your first "what's our headcount?" argument |
| 1 | [Unity Catalog and the dimension tables](week-01-unity-catalog-and-dimensions.md) | 1 | `tema_hr_gold` with clean dimensions and a sensitive table kept apart |
| 2 | [Fact tables, comments and tags](week-02-facts-comments-and-tags.md) | 1 | A complete, documented star schema |
| 3 | [Your first metric view](week-03-first-metric-view.md) | 2 | `workforce_metrics` with a headcount that's right for any period |
| 4 | [Attrition, the hard metric](week-04-attrition-metrics.md) | 2 | `retention_metrics` with trailing 12-month attrition |
| 5 | [The people metrics catalog](week-05-people-metrics-catalog.md) | 2 | Hiring, pay and engagement metrics, and a definitions doc |
| 6 | [The Workforce Overview dashboard](week-06-workforce-dashboard.md) | 3 | A dashboard built only on metric views |
| 7 | [Genie and the benchmark](week-07-genie-and-benchmark.md) | 3 | A Genie Agent and a before-and-after accuracy score |
| 8 | [HRBP access model](week-08-hrbp-access-model.md) | 4 | Salaries and birthdays visible only to the right HRBPs |
| 9 | [Trust: suppression, certification and audit](week-09-trust-and-audit.md) | 4 | Small-group suppression, aggregate-only access, certified assets |
| 10 | [Metrics as code](week-10-metrics-as-code.md) | 5 | A metric change that goes from pull request to workspace |
| 11 | [BI tools and cross-domain questions](week-11-bi-and-cross-domain.md) | 5 | People metrics next to ad revenue, and a tool comparison |
| 12 | [Capstone: the pilot proposal](week-12-capstone-pilot-proposal.md) | 6 | A proposal and a 30-minute demo for work |

## How each sheet works

- **Goal**: what you'll have at the end, in one or two sentences.
- **Before you start**: what must already exist.
- **Steps**: numbered, with SQL to copy. "Your turn" steps leave the thinking to you, with a hidden hint or answer.
- **Checkpoint**: tick-boxes and a query that proves it worked, with the numbers to expect.
- **Why this matters at work**: the argument this week gives you for your own company.

Plan for 4 to 6 hours a week. If a week runs long, stop at the checkpoint and carry the rest over.

## Nothing here has run in Databricks yet

These sheets were written before anyone ran them in a workspace. The SQL that builds tables and the expected numbers were checked locally against the same generated data (in DuckDB, a different SQL engine), but Databricks-only features were not. You'll see a box like this wherever a step is untested:

> [!WARNING]
> **Untested in Databricks.** What might go wrong, and what to try.

When something breaks or a step is unclear, note it in the sheet (or open an issue) so the sheet gets fixed. That dry run is part of the work.

## The numbers to expect

Checkpoints quote numbers from Tema generated at **5,000 people** with the default seed. The generator is deterministic, so your numbers should match exactly; if a library version on Databricks behaves slightly differently they may be off by a little, and the shape of the story (who grows, who churns) will be the same. When you rerun at 70,000 the numbers grow but the patterns hold.

| Fact (5,000 run) | Value |
|---|---|
| Headcount at end of October 2026 | 5,024 |
| Headcount at end of June 2025 (Q2) | 4,176 |
| Wrong "headcount" from summing Apr to Jun 2025 | 12,429 |
| AI division headcount, Dec 2024 → Oct 2026 | 106 → 674 |
| Trailing 12-month attrition, Oct 2026 | 13.1% (608 leavers ÷ 4,655 average headcount) |
| Highest trailing 12-month attrition by division | Trust & Safety 22.2%, AI 20.6% |
| Median days to fill since May 2025, AI vs rest | 67 vs 41 |
| eNPS, 2023-H1 → 2026-H1 | −7.1 → +16.7 |

## Ground rules

- Everything is synthetic. Never load real employee data into a personal or trial workspace.
- Work on a branch per week and merge into `main` with a pull request (see the [repo conventions](../README.md#conventions)).
- Catalog is assumed to be `workspace` (the Free Edition default). If yours is different, change it at the top of each script.
