# Week 10: Metrics as code

**Phase 5** · about 6 hours

## Goal

Change a metric definition the way you'd want it changed at work: edit it in Git, review it in a pull request, and deploy it to the workspace automatically, with no hand edits in the UI.

## Before you start

- Weeks 3 to 9 done; your metric view `.sql` files are in `hr_people_analytics/metrics/`.
- The [Databricks CLI](https://docs.databricks.com/aws/en/dev-tools/cli/) installed on your laptop, or use the workspace web terminal if you have one.
- A branch `week-10`.

## Learn (about 1.5 hours)

1. Databricks docs: **Databricks Asset Bundles** (now sometimes called Declarative Automation Bundles): `databricks.yml`, targets, resources, `bundle validate` and `bundle deploy`.
2. Skim how dbt can manage metric views, so you can compare the two later.
3. Read about the **Open Semantic Interchange (OSI)** and the open-source metric view implementation in Apache Spark and Unity Catalog OSS. Note what it means for lock-in.

## Steps

### 1. Add a bundle to the repo

Create `databricks.yml` at the repo root:

```yaml
bundle:
  name: tema_semantic_layer

variables:
  catalog:
    default: workspace

resources:
  jobs:
    deploy_metric_views:
      name: Deploy Tema metric views
      tasks:
        - task_key: workforce_metrics
          sql_task:
            file:
              path: ./hr_people_analytics/metrics/workforce_metrics.sql
            warehouse_id: ${var.warehouse_id}
        - task_key: retention_metrics
          depends_on: [{ task_key: workforce_metrics }]
          sql_task:
            file:
              path: ./hr_people_analytics/metrics/retention_metrics.sql
            warehouse_id: ${var.warehouse_id}

targets:
  dev:
    default: true
    mode: development
```

**Your turn.** Add a `warehouse_id` variable (find your SQL warehouse ID under **SQL Warehouses**), and add tasks for your other metric view files.

> [!WARNING]
> **Untested in Databricks.** Bundle schemas change; run `databricks bundle validate` and fix what it reports. A job that runs SQL files is one simple pattern. Your workspace may offer something more direct for metric views; check the docs. Free Edition may not let you create jobs on a SQL warehouse; if so, try a notebook task on serverless that runs the files with `spark.sql()`.

### 2. Deploy and run

```bash
databricks auth login --host <your-workspace-url>
databricks bundle validate
databricks bundle deploy
databricks bundle run deploy_metric_views
```

Check in Catalog Explorer that the metric views were recreated (look at **Last modified**).

### 3. Change a definition through a pull request

The business request: *"Interns shouldn't count in attrition."* Tema has no interns, so use a real equivalent: **exclude part-time employees from attrition**.

1. On `week-10`, change `retention_metrics.sql` so every attrition building block excludes `employment_type = 'Part-time'`.
2. Update the attrition entries in `docs/metric-definitions.md` to match. The definition and the code change in the **same** pull request.
3. Open the pull request. In the description, write the before and after attrition for October 2026, and who would sign off this change at a real company.
4. Merge, then deploy from `main` with `databricks bundle deploy` and `bundle run`.

**Your turn.** Rerun your Week 4 truth query with the same exclusion and confirm the metric view matches.

### 4. Optional: automate the deploy

Add a GitHub Actions workflow that runs `databricks bundle validate` on every pull request and `bundle deploy` on merge to `main`. You'll need a workspace token stored as a GitHub secret. Never commit a token to the repo.

### 5. Commit

Commit `databricks.yml` and your notes, open a pull request, and merge.

## Checkpoint

- [ ] `databricks bundle deploy` recreates all your metric views from Git.
- [ ] The part-time change went through a pull request with the definition and YAML changed together.
- [ ] After deploying, the metric view matches your updated truth query.
- [ ] You can explain in a paragraph what OSI is and why it matters for avoiding lock-in.

## Why this matters at work

Metric definitions are business policy. When someone changes how attrition is calculated, leaders need to know who changed it, when, why, and who approved it. Git and pull requests give you that for free, and bundles mean the workspace can't drift from what was approved. This is the practice that lets a "metrics council" work at a real company: proposals are pull requests, and approval is a review.
