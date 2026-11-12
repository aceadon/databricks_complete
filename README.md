# Databricks semantic layer labs: complete reference

The **finished** version of the 12-week [zero to semantic hero](plan/zero-to-semantic-hero.md) labs, built on **Tema**, a fictional social media ads company with about 70,000 employees. It holds everything in the [learning repo](https://github.com/aceadon/databricks) plus the output of every exercise: gold tables, metric view YAML, governance, dashboard, Genie set-up, the asset bundle and the filled-in documents.

Use it to check your own work, not to skip it: each lab is worth doing yourself first. Everything here is synthetic. Never load real employee data into a personal or trial workspace.

## Stand it up quickly

About 15 minutes at 5,000 people. You don't need to delete or change anything you've already built.

1. **Check your GitHub token covers this repo.** If your Databricks Git credential is a fine-grained GitHub token limited to one repo, add `databricks_complete` to it (GitHub > Settings > Developer settings > tokens), or create a new one. A classic token with `repo` scope already works.
2. **Add the Git folder.** **Workspace > Create > Git folder**, paste `https://github.com/aceadon/databricks_complete`, name it `databricks_complete`. Keep your own repo's Git folder as it is.
3. **Data: only if you don't have it already.** Both repos read the same `workspace.tema_hr_raw` tables. If `SHOW TABLES IN workspace.tema_hr_raw` lists 12 tables, skip this step. Otherwise open `hr_people_analytics/00_generate_hr_data.py`, set `target_headcount` to `5000`, attach **Serverless**, **Run all** (about 2 minutes). Use 5,000 if you want the lab checkpoint numbers to match; 70,000 works too, and then step 5 compares with the reference instead.
4. **Build everything.** Open `reference/00_build_reference`, attach **Serverless**, leave the widgets at their defaults (`through_week` 12), **Run all**. It creates the gold tables, all six metric views, the safe pay view, the HRBP access model and the business data in `tema_ref_gold`, `tema_ref_semantic` and `tema_ref_secure`. The last cell lists what it built, and the cell before it shows any step your workspace refused.
5. **Check it.** Open `reference/01_check_my_work`, **Run all**. Set `my_prefix` to `tema_ref` to confirm the reference itself matches the lab numbers, or leave it at `tema_hr` to check your own work.
6. **Dashboard (optional).** Click `hr_people_analytics/dashboards/tema_workforce_overview.lvdash.json`. On the **Data** tab change `tema_hr_semantic` to `tema_ref_semantic` in each dataset, then publish.
7. **Genie (optional).** **Genie > New**, add the metric views in `tema_ref_semantic` (not `pay_metrics`), paste the text from `hr_people_analytics/genie/instructions.md`, and add the queries in `genie/example_queries.sql` as examples.
8. **HRBP activity (optional).** Open `hr_people_analytics/governance/02_hrbp_access_activity.sql`, change `USE SCHEMA tema_hr_secure` to `tema_ref_secure` at the top, and run it cell by cell.

**Want the reference to *be* your `tema_hr_*` schemas** (for example to demo from the names the labs use, or to deploy with `databricks.yml`)? In step 4 set `reference_prefix` to `tema_hr`. That replaces your own gold, semantic and secure objects, so commit your work first.

## Import it into Databricks (details)

Keep your own repo as one Git folder and add this one as a second, so you can open them side by side.

1. **Workspace > Create > Git folder**, paste `https://github.com/aceadon/databricks_complete`, and name the folder `databricks_complete`.
2. Generate the data if you haven't: open `hr_people_analytics/00_generate_hr_data.py` (from either repo, they're the same), set `target_headcount` to `5000`, **Run all**. The checkpoint numbers in the labs are for 5,000 people.
3. Open [`reference/00_build_reference`](reference/00_build_reference.py), attach **Serverless**, **Run all**. It builds the finished state into `tema_ref_gold`, `tema_ref_semantic` and `tema_ref_secure`, **next to** your own `tema_hr_*` schemas, without touching them. Set `through_week` to the week you've just finished so the numbers match that lab.
4. Open [`reference/01_check_my_work`](reference/01_check_my_work.py) and **Run all**. You get one row per checkpoint: ✅ match, 🟡 a known alternative (with what it means), ❌ differs (with the reference file to compare), or ⬜ not built.

More on both notebooks, and how to compare things a query can't check: [reference/README.md](reference/README.md).

## Where each week's finished output lives

| Week | Lab | Finished output in this repo |
|---|---|---|
| 0 | [Set up and meet Tema](labs/week-00-setup-and-meet-tema.md) | [`plan/notes/week-00.md`](plan/notes/week-00.md) |
| 1 | [Unity Catalog and dimensions](labs/week-01-unity-catalog-and-dimensions.md) | [`gold/01_dimensions.sql`](hr_people_analytics/gold/01_dimensions.sql) |
| 2 | [Facts, comments and tags](labs/week-02-facts-comments-and-tags.md) | [`gold/02_facts.sql`](hr_people_analytics/gold/02_facts.sql), [`03_keys_and_comments.sql`](hr_people_analytics/gold/03_keys_and_comments.sql), [`04_tags.sql`](hr_people_analytics/gold/04_tags.sql), [`docs/gold-table-checklist.md`](docs/gold-table-checklist.md) |
| 3 | [First metric view](labs/week-03-first-metric-view.md) | [`metrics/workforce_metrics.sql`](hr_people_analytics/metrics/workforce_metrics.sql), [`docs/metric-definitions.md`](docs/metric-definitions.md) |
| 4 | [Attrition](labs/week-04-attrition-metrics.md) | [`reference/snapshots/retention_metrics_week04.sql`](reference/snapshots/retention_metrics_week04.sql), [`metrics/checks/attrition_truth.sql`](hr_people_analytics/metrics/checks/attrition_truth.sql) |
| 5 | [People metrics catalog](labs/week-05-people-metrics-catalog.md) | [`talent_acquisition_metrics.sql`](hr_people_analytics/metrics/talent_acquisition_metrics.sql), [`experience_metrics.sql`](hr_people_analytics/metrics/experience_metrics.sql), [`pay_metrics.sql`](hr_people_analytics/metrics/pay_metrics.sql), pay equity entry in the definitions doc |
| 6 | [Workforce dashboard](labs/week-06-workforce-dashboard.md) | [`dashboards/tema_workforce_overview.lvdash.json`](hr_people_analytics/dashboards/) |
| 7 | [Genie and the benchmark](labs/week-07-genie-and-benchmark.md) | [`genie/`](hr_people_analytics/genie/): instructions, example SQL, 20 questions with expected answers |
| 8 | [HRBP access model](labs/week-08-hrbp-access-model.md) | [`governance/01_hrbp_access_model.sql`](hr_people_analytics/governance/01_hrbp_access_model.sql), [`docs/people-data-governance-model.md`](docs/people-data-governance-model.md) |
| 9 | [Trust and audit](labs/week-09-trust-and-audit.md) | [`pay_by_level_safe.sql`](hr_people_analytics/metrics/pay_by_level_safe.sql), [`governance/03_…`](hr_people_analytics/governance/03_trust_certification_and_access.sql), [`04_…`](hr_people_analytics/governance/04_adoption_and_access_queries.sql) |
| 10 | [Metrics as code](labs/week-10-metrics-as-code.md) | [`databricks.yml`](databricks.yml), [`metrics/retention_metrics.sql`](hr_people_analytics/metrics/retention_metrics.sql) (part-time excluded), [`docs/examples/bundle-ci.yml`](docs/examples/bundle-ci.yml) |
| 11 | [BI and cross-domain](labs/week-11-bi-and-cross-domain.md) | [`gold/10_fact_ad_revenue.sql`](hr_people_analytics/gold/10_fact_ad_revenue.sql), [`business_metrics.sql`](hr_people_analytics/metrics/business_metrics.sql), [`docs/semantic-tools-comparison.md`](docs/semantic-tools-comparison.md), [`docs/bi-connection-notes.md`](docs/bi-connection-notes.md) |
| 12 | [Pilot proposal](labs/week-12-capstone-pilot-proposal.md) | [`docs/pilot-proposal.md`](docs/pilot-proposal.md), [`docs/demo-script.md`](docs/demo-script.md) |

The answer keys for each lab's "Your turn" steps, with explanations and common mistakes, are in [`solutions/`](solutions/README.md). The files above are those answers assembled into one runnable build.

## What's in the repo

| Folder | What it holds |
|---|---|
| [`reference/`](reference/) | The build and check notebooks, and the Week 4 snapshot of retention metrics |
| [`hr_people_analytics/`](hr_people_analytics/) | The finished build: generator, gold, metrics, dashboards, Genie, governance |
| [`labs/`](labs/), [`plan/`](plan/) | The lab sheets and plan, unchanged from the learning repo |
| [`solutions/`](solutions/) | Answer keys with explanations |
| [`docs/`](docs/) | Every document filled in: definitions, governance model, comparison, proposal |
| [`databricks.yml`](databricks.yml) | The Week 10 bundle that deploys every metric view |

## Untested in Databricks

Like the labs, this was written before anyone ran it end to end in a workspace. The SQL and expected numbers were checked against the same generated data locally, but Databricks-only features (metric view YAML, masks, tags, the dashboard file, the bundle) were not. If something fails, the build notebook tells you the file and statement; please fix it here or open an issue, so the reference gets better for the next person.
