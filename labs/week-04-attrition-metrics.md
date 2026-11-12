# Week 4: Attrition, the hard metric

**Phase 2** · about 6 hours

## Goal

Build `retention_metrics` with a trailing 12-month attrition rate that anyone can slice by division, level or region and get the right answer, plus voluntary, regretted and first-year variants with names that say exactly what they are.

## Before you start

- Week 3 done: `workforce_metrics` returns 4,176 for 2025-Q2.
- A branch `week-04`.

## Why attrition is hard

Attrition is a **ratio of two facts over a rolling window**: leavers in the last 12 months divided by the *average* month-end headcount over the same 12 months. Three things go wrong in hand-written SQL:

1. The numerator and denominator get computed over different windows or filters.
2. Someone averages monthly attrition rates instead of dividing totals.
3. "Attrition" means voluntary in one report, all leavers in another, and regretted in a third.

A metric view fixes all three by defining each piece once.

## Steps

### 1. Compute the answer by hand first

Before building anything, write the answer you'll test against. Save this as `hr_people_analytics/metrics/checks/attrition_truth.sql`:

```sql
WITH monthly AS (
  SELECT snapshot_month,
         COUNT_IF(is_active_month_end)                AS headcount,
         COUNT_IF(is_termination_in_month)            AS leavers,
         COUNT_IF(is_voluntary_termination_in_month)  AS voluntary_leavers,
         COUNT_IF(is_regretted_termination_in_month)  AS regretted_leavers
  FROM workspace.tema_hr_gold.fact_headcount_monthly
  GROUP BY ALL
)
SELECT snapshot_month,
       SUM(leavers)  OVER w AS leavers_t12m,
       AVG(headcount) OVER w AS avg_headcount_t12m,
       ROUND(100 * SUM(leavers) OVER w / AVG(headcount) OVER w, 1)           AS attrition_t12m_pct,
       ROUND(100 * SUM(voluntary_leavers) OVER w / AVG(headcount) OVER w, 1) AS voluntary_t12m_pct,
       ROUND(100 * SUM(regretted_leavers) OVER w / AVG(headcount) OVER w, 1) AS regretted_t12m_pct
FROM monthly
WINDOW w AS (ORDER BY snapshot_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW)
ORDER BY snapshot_month DESC;
```

For October 2026 at 5,000 people you should get **608 leavers**, average headcount **4,655**, attrition **13.1%**, voluntary **10.0%**, regretted **4.3%**. Keep this query; it's your test.

### 2. Build the metric view

Create `hr_people_analytics/metrics/retention_metrics.sql`:

```sql
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.retention_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema attrition. Rates divide leavers by average month-end headcount over the same window."
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
  - name: quarter
    expr: dt.year_quarter
  - name: year
    expr: dt.year
  - name: division
    expr: dept.division
  - name: department
    expr: dept.department_name
  - name: job_level
    expr: job.job_level
  - name: region
    expr: loc.region
measures:
  # Building blocks over the trailing 12 months ending with the period
  - name: leavers_t12m
    display_name: Leavers (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: voluntary_leavers_t12m
    expr: COUNT(1) FILTER (WHERE source.is_voluntary_termination_in_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: regretted_leavers_t12m
    expr: COUNT(1) FILTER (WHERE source.is_regretted_termination_in_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: avg_headcount_t12m
    display_name: Average headcount (trailing 12 months)
    expr: COUNT(1) FILTER (WHERE source.is_active_month_end) / COUNT(DISTINCT source.snapshot_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  # The rates people actually ask for
  - name: attrition_rate_t12m
    display_name: Attrition rate (trailing 12 months)
    comment: "All leavers in the 12 months ending with the period, divided by average month-end headcount over those months. The default meaning of 'attrition' at Tema."
    synonyms: ["attrition", "turnover", "attrition rate", "churn"]
    format:
      type: percentage
    expr: MEASURE(leavers_t12m) / MEASURE(avg_headcount_t12m)
  - name: voluntary_attrition_rate_t12m
    display_name: Voluntary attrition rate (trailing 12 months)
    synonyms: ["voluntary turnover", "resignations rate"]
    expr: MEASURE(voluntary_leavers_t12m) / MEASURE(avg_headcount_t12m)
  - name: regretted_attrition_rate_t12m
    display_name: Regretted attrition rate (trailing 12 months)
    comment: "Leavers the company wanted to keep."
    expr: MEASURE(regretted_leavers_t12m) / MEASURE(avg_headcount_t12m)
  # Simple monthly flow, additive over time
  - name: leavers
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
$$;
```

> [!WARNING]
> **Untested in Databricks.** The parts most likely to need a fix:
> - **Does `trailing 12 month` include the current month?** If your October 2026 rate is **13.3%** instead of 13.1%, the window is the 12 months *before* October (Oct 2025 to Sep 2026). Check the docs for how to include the current month, or accept the convention and write it in the definition. Either way, the definitions doc must say which.
> - **`MEASURE()` of a windowed measure inside another measure.** If composition isn't allowed, put the ratio in your query instead: `MEASURE(leavers_t12m) / MEASURE(avg_headcount_t12m)`, and raise it as a limitation in your notes.
> - **`format`** may have a different shape in your version; remove it if it errors.

### 3. Test it against your truth query

```sql
SELECT month, MEASURE(leavers_t12m), MEASURE(avg_headcount_t12m), MEASURE(attrition_rate_t12m)
FROM workspace.tema_hr_semantic.retention_metrics
WHERE month IN ('2025-10-31', '2026-10-31')
GROUP BY ALL;
```

Expect 12.0% for October 2025 and 13.1% for October 2026.

### 4. Ask the business questions

```sql
-- "What's our trailing 12-month attrition by division, and how does it compare with last year?"
SELECT division,
       MEASURE(attrition_rate_t12m)           AS attrition,
       MEASURE(voluntary_attrition_rate_t12m) AS voluntary,
       MEASURE(regretted_attrition_rate_t12m) AS regretted
FROM workspace.tema_hr_semantic.retention_metrics
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY attrition DESC;
```

You should see Tema's story: **Trust & Safety 22.2%** and **AI 20.6%** at the top, Engineering lowest at 7.9%, and AI with the highest **regretted** rate (10.2%) because AI talent is being poached.

**Your turn.** Change the filter to `month = '2025-10-31'` to get last year, and write two sentences a VP would understand about what changed.

### 5. Your turn: first-year attrition

Add `first_year_attrition_rate_t12m`: leavers with under 12 months' tenure, divided by average headcount of people with under 12 months' tenure. Use the `is_first_year` flag.

<details>
<summary>Answer</summary>

```yaml
  - name: first_year_leavers_t12m
    expr: COUNT(1) FILTER (WHERE source.is_termination_in_month AND source.is_first_year)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: first_year_avg_headcount_t12m
    expr: COUNT(1) FILTER (WHERE source.is_active_month_end AND source.is_first_year) / COUNT(DISTINCT source.snapshot_month)
    window:
      - order: month
        range: trailing 12 month
        semiadditive: last
  - name: first_year_attrition_rate_t12m
    display_name: First-year attrition rate (trailing 12 months)
    expr: MEASURE(first_year_leavers_t12m) / MEASURE(first_year_avg_headcount_t12m)
```

Expect about **24%** for October 2026, close to double the overall rate. That's one of Tema's planted findings.

</details>

### 6. Write the definitions

In [docs/metric-definitions.md](../docs/metric-definitions.md), complete the **Attrition rate (trailing 12 months)** entry and add voluntary, regretted and first-year entries. For each, answer: does it include involuntary leavers? Interns? Transfers? Which month does a leaver on the last day of a month count in? Commit and open a pull request.

## Checkpoint

- [ ] `retention_metrics` matches your truth query: **13.1%** for October 2026 (or you've documented why the window gives 13.3%).
- [ ] By division, Trust & Safety and AI are highest; AI has the highest regretted rate.
- [ ] Every attrition measure has a name that says which kind it is, and a definition entry.

## Why this matters at work

Ask three teams at your company for last year's attrition rate and you'll likely get three numbers, each defensible. The fight usually isn't about arithmetic, it's about undocumented choices: voluntary or all, average headcount or start headcount, calendar or trailing year. Your definitions doc plus this metric view is a template for ending that argument: one owner signs off each choice, and every tool uses it. Take the "three attrition numbers" story to work; it lands with every HR leader.
