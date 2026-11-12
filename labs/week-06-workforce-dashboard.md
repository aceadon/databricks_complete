# Week 6: The Workforce Overview dashboard

**Phase 3** · about 5 hours

## Goal

Build a **Workforce Overview** AI/BI dashboard that uses only your metric views, so every number on it matches the definitions doc, and keep its definition in Git.

## Before you start

- Weeks 3 to 5 done: four or five metric views in `tema_hr_semantic`.
- A branch `week-06`.

## Learn (about 1 hour)

Databricks docs for **AI/BI Dashboards**: datasets, visualizations, filters and parameters, using a metric view as a dataset, dashboard relationships, scheduling and sharing. Note what "local metric views" inside a dashboard are, and why you'll *not* use them here (your definitions should live in Unity Catalog, shared by every tool).

## Steps

### 1. Create the dashboard in your Git folder

**New > Dashboard**, then save it into `hr_people_analytics/dashboards/` in your Git folder so its `.lvdash.json` file is versioned. Name it **Tema Workforce Overview**.

> [!WARNING]
> **Untested in Databricks.** If you can't save a dashboard straight into a Git folder, create it in your home folder and move it, or export the JSON (**⋮ > Export**) and commit that file.

### 2. Add the metric views as datasets

On the **Data** tab, add `workforce_metrics`, `retention_metrics`, `talent_acquisition_metrics` and `experience_metrics` as datasets. Don't write SQL datasets against the gold tables. If you find you need one, that's a sign a metric or dimension is missing; add it to the metric view instead.

### 3. Build five widgets

| Widget | Dataset | Shape |
|---|---|---|
| Headcount today, and change since January | `workforce_metrics` | Two counters |
| Headcount by month, by division | `workforce_metrics` | Stacked area |
| Trailing 12-month attrition by division | `retention_metrics` | Bar, sorted, filtered to the latest month |
| Hiring funnel: median time to fill and offer acceptance, AI vs rest | `talent_acquisition_metrics` | Grouped bar |
| eNPS by survey cycle | `experience_metrics` | Line |

**Your turn.** Add one more widget that tells the AI growth story: AI headcount by month next to AI regretted attrition.

### 4. Add filters

Add a **Division** filter that applies to every widget, and a **Month** filter for the latest-month widgets. Check that filtering to "AI" changes the attrition bar and the headcount trend together.

### 5. Test the numbers against the metric views

For three widgets, run the equivalent `MEASURE()` query in the SQL editor and confirm the dashboard shows the same value. In particular, set the month filter to a quarter and make sure headcount shows the quarter-end number (4,176 for 2025-Q2), not a sum.

### 6. Share and schedule (optional)

Publish the dashboard and look at the sharing options: embedded credentials vs viewer credentials. Write one sentence in your notes on which you'd use for HR data and why (hint: viewer credentials mean row filters and masks apply per person, which you'll want after Week 8).

### 7. Commit

Commit the dashboard file and open a pull request. Look at the diff of the JSON: that's what reviewing a dashboard change at work could look like.

## Checkpoint

- [ ] The dashboard uses only metric views as datasets.
- [ ] Headcount shows 5,024 for October 2026 and 4,176 for 2025-Q2.
- [ ] Trust & Safety and AI top the attrition chart.
- [ ] The dashboard file is in `hr_people_analytics/dashboards/` on `main`.

## Why this matters at work

A dashboard built on metric views can't drift from the agreed definition, because it doesn't contain one. When Finance builds their own headcount chart on the same view next quarter, the numbers match without a reconciliation meeting. That's the moment people stop asking "which dashboard is right?", and it's an easy before-and-after to show your rollout team.
