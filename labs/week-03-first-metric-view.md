# Week 3: Your first metric view

**Phase 2** · about 5 hours · the start of the most important three weeks

## Goal

Build `workforce_metrics`, a Unity Catalog metric view where `headcount` is right for any period you ask about: a month, a quarter, a year, any department, without anyone writing the "last month only" logic again.

## Before you start

- Weeks 1 and 2 done: 13 documented tables in `tema_hr_gold`.
- A branch `week-03`.

## Learn (about 1.5 hours)

1. Databricks docs: **Unity Catalog metric views**. Read the overview, the YAML reference (`source`, `joins`, `dimensions`, `measures`), and the `MEASURE()` function.
2. Read the section on **window measures**, especially `semiadditive: last`.
3. If there's a Databricks Academy module on metric views or AI/BI, do it.

**Check yourself:** In a metric view, when does aggregation happen? (At query time, at whatever grain the query groups by.) What's the difference between a dimension and a measure? Why can't a normal view give you a correct quarterly headcount and a correct monthly headcount at the same time?

## Steps

### 1. Feel the problem with a normal view

```sql
USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS tema_hr_semantic
  COMMENT 'Tema (fictional) people metrics: certified definitions for dashboards, Genie and BI tools.';

CREATE OR REPLACE VIEW tema_hr_semantic.v_headcount_naive AS
SELECT f.snapshot_month, d.year_quarter, dept.division,
       COUNT_IF(f.is_active_month_end) AS headcount
FROM tema_hr_gold.fact_headcount_monthly f
JOIN tema_hr_gold.dim_date d ON d.month_end = f.snapshot_month
JOIN tema_hr_gold.dim_department dept ON dept.department_id = f.department_id
GROUP BY ALL;

-- Now ask it for a quarter. Every BI tool will SUM by default.
SELECT year_quarter, SUM(headcount) FROM tema_hr_semantic.v_headcount_naive
WHERE year_quarter = '2025-Q2' GROUP BY ALL;
```

You get **12,429**, three months added together. The right answer is the June number. A normal view can't know that, because it pre-aggregates at one grain.

### 2. Create the metric view

Create `hr_people_analytics/metrics/workforce_metrics.sql`:

```sql
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.workforce_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema workforce size and movement. Headcount and FTE are month-end, semi-additive over time."
source: workspace.tema_hr_gold.fact_headcount_monthly
joins:
  - name: dt
    source: workspace.tema_hr_gold.dim_date
    on: source.snapshot_month = dt.month_end
  - name: dept
    source: workspace.tema_hr_gold.dim_department
    on: source.department_id = dept.department_id
  - name: job
    source: workspace.tema_hr_gold.dim_job
    on: source.job_id = job.job_id
  - name: loc
    source: workspace.tema_hr_gold.dim_location
    on: source.location_id = loc.location_id
dimensions:
  - name: month
    expr: source.snapshot_month
    display_name: Month
  - name: quarter
    expr: dt.year_quarter
    display_name: Quarter
  - name: year
    expr: dt.year
    display_name: Year
  - name: division
    expr: dept.division
    display_name: Division
  - name: department
    expr: dept.department_name
    display_name: Department
  - name: job_level
    expr: job.job_level
    display_name: Job level
  - name: job_track
    expr: job.job_track
    display_name: Job track
  - name: region
    expr: loc.region
    display_name: Region
  - name: employment_type
    expr: source.employment_type
    display_name: Employment type
measures:
  - name: headcount
    display_name: Headcount
    comment: "People employed at the end of the period. Semi-additive: for a quarter or year, the last month's value."
    synonyms: ["employees", "number of people", "staff"]
    expr: COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: fte
    display_name: FTE
    comment: "Full-time equivalents at the end of the period. Semi-additive like headcount."
    expr: SUM(source.fte) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: hires
    display_name: Hires
    comment: "People who joined in the period. Additive: a quarter is the sum of its months."
    expr: COUNT(1) FILTER (WHERE source.is_hire_in_month)
  - name: leavers
    display_name: Leavers
    comment: "People who left in the period, voluntary and involuntary."
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
  - name: net_change
    display_name: Net change
    comment: "Hires minus leavers."
    expr: MEASURE(hires) - MEASURE(leavers)
$$;
```

> [!WARNING]
> **Untested in Databricks.** Metric view YAML is still evolving. If creation fails:
> - *Unknown field* `display_name`, `synonyms` or `comment` on a measure: check which `version` your workspace supports; remove those fields to get going, then add them back one at a time.
> - *Window syntax* errors: check the current window measure docs; the keys (`order`, `range`, `semiadditive`) have changed before.
> - *`MEASURE()` inside a measure* (in `net_change`) not allowed: write it as `COUNT(1) FILTER (WHERE source.is_hire_in_month) - COUNT(1) FILTER (WHERE source.is_termination_in_month)`.
> - *`window.order` must be a dimension*: it refers to `month` by its dimension name, not the column.

### 3. Query it

```sql
-- A quarter: should be June's number, not the sum
SELECT quarter, MEASURE(headcount), MEASURE(hires), MEASURE(leavers)
FROM workspace.tema_hr_semantic.workforce_metrics
WHERE quarter = '2025-Q2'
GROUP BY ALL;

-- Every quarter end this year, by division
SELECT quarter, division, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.workforce_metrics
WHERE year = 2026
GROUP BY ALL ORDER BY quarter, headcount DESC;

-- Year to date
SELECT MEASURE(headcount), MEASURE(hires), MEASURE(leavers), MEASURE(net_change)
FROM workspace.tema_hr_semantic.workforce_metrics
WHERE month BETWEEN '2026-01-01' AND '2026-10-31';
```

Notice what you *didn't* write: no joins, no "last month" logic, no `COUNT_IF`. Hires and leavers add up across months; headcount doesn't. The definition decides, not the person querying.

### 4. Try the low-code editor

In Catalog Explorer, open `workforce_metrics`. Look at how the YAML appears in the UI editor. **Your turn:** use the editor to add a dimension `city` (from `loc.city`), save, and compare the YAML it wrote with yours. Then copy the change back into your `.sql` file so Git stays the source of truth.

### 5. Your turn: average salary and span of control

Add two measures:

- `average_salary`: average `annual_base_salary` of people active at month end. Should it be semi-additive? (Think about "average salary in 2025": average of everyone who appeared in any month, or of December?)
- `span_of_control`: active non-managers divided by active managers, at month end.

<details>
<summary>Hint</summary>

```yaml
  - name: average_salary
    display_name: Average base salary
    expr: AVG(source.annual_base_salary) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
  - name: span_of_control
    display_name: Span of control
    expr: >
      COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end AND NOT job.is_manager)
      / COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end AND job.is_manager)
    window:
      - order: month
        range: current
        semiadditive: last
```

Both are period-end snapshots, so `semiadditive: last` is the defensible choice. Write that decision down; it's a definition someone should sign off. Salary is sensitive, so Week 9 will revisit who can see `average_salary`.

</details>

### 6. Start the definitions doc and commit

Open [docs/metric-definitions.md](../docs/metric-definitions.md). Headcount is already there; fill in its **Metric view** line and add entries for FTE, hires, leavers and net change. Commit and open a pull request.

## Checkpoint

- [ ] `workforce_metrics` exists and appears in Catalog Explorer as a metric view.
- [ ] Headcount for **2025-Q2 is 4,176** (not 12,429), and for October 2026 is **5,024**.
- [ ] Year to date 2026: **1,126 hires**, **501 leavers**.
- [ ] Headcount by division for October 2026 adds up to the total (Engineering 1,618, Ads Business 1,141, AI 674, Corporate 577, Product & Design 512, Trust & Safety 502).

```sql
-- Compare the metric view with a hand-written query you trust. The two columns should match.
SELECT m.month, m.hc_metric, t.hc_truth
FROM (SELECT month, MEASURE(headcount) AS hc_metric
      FROM workspace.tema_hr_semantic.workforce_metrics GROUP BY ALL) m
JOIN (SELECT snapshot_month, COUNT_IF(is_active_month_end) AS hc_truth
      FROM workspace.tema_hr_gold.fact_headcount_monthly GROUP BY ALL) t
  ON t.snapshot_month = m.month
WHERE m.hc_metric <> t.hc_truth;   -- expect 0 rows
```

## Why this matters at work

This is the demo. Show a colleague the naive view returning 12,429 for "Q2 headcount", then the metric view returning 4,176, and point out that the person asking didn't need to know anything to get it right. That's the whole case for a semantic layer in two queries: definitions live in one governed place, so every dashboard, spreadsheet export and Genie answer inherits them.
