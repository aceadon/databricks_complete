# Reference build and checks

| Notebook | What it does |
|---|---|
| [`00_build_reference`](00_build_reference.py) | Runs every finished lab file, in order, into separate `tema_ref_*` schemas |
| [`01_check_my_work`](01_check_my_work.py) | Compares your `tema_hr_*` schemas with the lab checkpoints and with the reference, week by week |
| [`sql_runner`](sql_runner.py) | Helpers both notebooks use (splitting `.sql` files into statements, renaming schemas) |
| [`snapshots/retention_metrics_week04.sql`](snapshots/retention_metrics_week04.sql) | `retention_metrics` as it was after Week 4, before the Week 10 part-time change |

## How the build stays out of your way

The finished `.sql` files name the same schemas as the labs (`workspace.tema_hr_gold`, `tema_hr_semantic`, `tema_hr_secure`), so they read exactly like what you wrote. The build notebook rewrites those names as it runs, so the reference lands in `tema_ref_gold`, `tema_ref_semantic` and `tema_ref_secure`. Both builds read the same `tema_hr_raw` source tables, which nothing here changes.

To use the reference *as* your build (for example to catch up and start at week 8), set `reference_prefix` to `tema_hr`. That overwrites your own gold, semantic and secure schemas, so commit your work first.

## Build "through week N"

The labs change one definition along the way: in Week 10, part-time employees leave the attrition rates, which moves October 2026 attrition from 13.1% to 12.9%. Set `through_week` on both notebooks to the week you've finished, and both use the matching definition. The check notebook also recognises the other definition and marks it 🟡 with an explanation, rather than ❌.

## Comparing what a query can't check

- **Files:** open your file and the matching file here side by side, or compare branches in GitHub. The root README maps each week to its files.
- **Metric view YAML:** your keys can be in a different order, quoted differently or have different display names. What has to match is each measure's `expr`, its `window`, and the joins.
- **Dashboard:** import [`tema_workforce_overview.lvdash.json`](../hr_people_analytics/dashboards/) and point its datasets at `tema_ref_semantic` to see the reference next to yours.
- **Genie:** compare your instructions and example SQL with [`genie/`](../hr_people_analytics/genie/). Scores are yours: the reference records expected answers, not Genie's.
- **Documents:** the docs folder is filled in as one good answer, not the only one. A different owner or threshold is fine if it's written down and justified.

## Different data size

The expected numbers are for 5,000 people (seed 42). At another size, `01_check_my_work` compares you with the reference build instead, so run `00_build_reference` first on the same data.
