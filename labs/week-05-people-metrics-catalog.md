# Week 5: The people metrics catalog

**Phase 2** · about 6 hours

## Goal

Round out Tema's metrics with hiring, pay and employee experience, so you have 12 to 15 certified-quality KPIs across five metric views, each with a written definition. By the end you can answer the plan's Phase 2 checkpoint questions with short `MEASURE()` queries and no hand-written joins.

## Before you start

- Weeks 3 and 4 done: `workforce_metrics` and `retention_metrics` match your truth queries.
- A branch `week-05`.

## Learn (about 1 hour)

In the metric view docs, read about **level of detail (LOD)** expressions, **percentile and median** measures, and **multi-fact relationships** (Public Preview). Decide whether each new metric needs its own view (different source table) or fits an existing one.

## Steps

### 1. Talent acquisition metrics

Create `hr_people_analytics/metrics/talent_acquisition_metrics.sql`:

```sql
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.talent_acquisition_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema hiring funnel, one row per requisition. Time to fill counts calendar days from opened to filled."
source: workspace.tema_hr_gold.fact_requisitions
joins:
  - name: dept
    source: workspace.tema_hr_gold.dim_department
    on: source.department_id = dept.department_id
  - name: job
    source: workspace.tema_hr_gold.dim_job
    on: source.job_id = job.job_id
dimensions:
  - name: opened_month
    expr: last_day(source.opened_date)
  - name: opened_date
    expr: source.opened_date
  - name: status
    expr: source.status
  - name: division
    expr: dept.division
  - name: department
    expr: dept.department_name
  - name: job_level
    expr: job.job_level
measures:
  - name: requisitions
    expr: COUNT(1)
  - name: open_requisitions
    expr: COUNT(1) FILTER (WHERE source.status = 'Open')
  - name: median_time_to_fill_days
    display_name: Median time to fill (days)
    synonyms: ["time to hire", "days to fill"]
    expr: MEDIAN(source.days_to_fill)
  - name: offer_acceptance_rate
    display_name: Offer acceptance rate
    expr: SUM(source.offers_accepted) / SUM(source.offers_extended)
  - name: applicants_per_hire
    expr: SUM(source.applicants) FILTER (WHERE source.status = 'Filled') / COUNT(1) FILTER (WHERE source.status = 'Filled')
$$;
```

Then answer: "How do time to fill and offer acceptance for AI roles compare with the rest of Tema since the AI boom began?"

```sql
SELECT division = 'AI' AS is_ai,
       MEASURE(median_time_to_fill_days), MEASURE(offer_acceptance_rate), MEASURE(requisitions)
FROM workspace.tema_hr_semantic.talent_acquisition_metrics
WHERE opened_date >= '2025-05-01' AND status = 'Filled'
GROUP BY ALL;
```

Expect AI roles to take about **67 days** (median) against **41** elsewhere, with offer acceptance about **70%** against **84%**.

> [!WARNING]
> **Untested in Databricks.** If grouping by an expression (`division = 'AI'`) on a metric view isn't allowed, add a dimension `is_ai_division` with `expr: dept.division = 'AI'` instead. That's arguably better anyway, since "AI" is a business concept worth naming.

### 2. Your turn: experience metrics

Build `experience_metrics` on `fact_engagement` with dimensions `survey_cycle`, `division`, `department` and measures:

- `enps`: percentage of promoters minus percentage of detractors, on a −100 to +100 scale.
- `engagement_score`: average engagement (1 to 5).
- `responses`: count of responses.

<details>
<summary>Answer</summary>

```sql
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.experience_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema engagement survey results, twice a year. One row per response."
source: workspace.tema_hr_gold.fact_engagement
joins:
  - name: dept
    source: workspace.tema_hr_gold.dim_department
    on: source.department_id = dept.department_id
dimensions:
  - name: survey_cycle
    expr: source.survey_cycle
  - name: division
    expr: dept.division
  - name: department
    expr: dept.department_name
measures:
  - name: responses
    expr: COUNT(1)
  - name: enps
    display_name: eNPS
    comment: "% promoters (9-10) minus % detractors (0-6). Ranges from -100 to +100."
    expr: 100.0 * (COUNT(1) FILTER (WHERE source.enps_score >= 9) - COUNT(1) FILTER (WHERE source.enps_score <= 6)) / COUNT(1)
  - name: engagement_score
    expr: AVG(source.engagement_score)
  - name: manager_score
    expr: AVG(source.manager_score)
$$;
```

eNPS by cycle should run from **−7.1** in 2023-H1 (after the layoffs) to **+16.7** in 2026-H1.

</details>

### 3. Your turn: pay metrics

Add a `pay_metrics` view on `fact_headcount_monthly` (copy the joins from `workforce_metrics`). The measure that matters is **compa-ratio**: salary divided by the midpoint of the salary band, adjusted for location.

```yaml
  - name: avg_compa_ratio
    display_name: Average compa-ratio
    comment: "Base salary / (band midpoint x location pay factor), averaged over people active at period end. 1.00 = paid at midpoint."
    expr: AVG(source.annual_base_salary / (job.salary_band_mid * loc.location_pay_factor)) FILTER (WHERE source.is_active_month_end)
    window:
      - order: month
        range: current
        semiadditive: last
```

Then answer "Which job levels have the lowest average compa-ratio?" for October 2026. Ignoring E1 and E2 (one person each, a hint of Week 9's small-group problem), **IC4** is lowest at about **1.02** and **M1** highest at about **1.10**.

**Stretch (LOD):** add `salary_vs_department_avg`, each person's salary relative to their department's average. Check the LOD section of the docs for the current syntax.

### 4. Think about the gender pay gap, but don't build it in the open

The gap inside salary bands needs `gender`, which you put in `dim_employee_sensitive`. Joining it into `pay_metrics` would let anyone with access to pay metrics slice by gender, down to tiny groups.

**Your turn.** Write a short note in `docs/metric-definitions.md` under a new **Pay equity** entry: who should see it, at what minimum group size, and whether it belongs in a separate restricted metric view. (Women's average compa-ratio is about 1.02 against 1.05 for men at 5,000 people. Week 9 is where you decide how that gets shown safely.)

### 5. Check the catalog

Your metrics should now cover the plan's list. Tick them off:

| Area | Measures |
|---|---|
| Workforce | headcount, FTE, hires, leavers, net change, span of control |
| Retention | attrition, voluntary, regretted, first-year (all trailing 12 months) |
| Talent acquisition | median time to fill, offer acceptance, applicants per hire, open requisitions |
| Pay | average compa-ratio, (stretch) salary vs department average |
| Experience | eNPS, engagement score |

### 6. Finish the definitions doc and commit

Every measure needs an entry in [docs/metric-definitions.md](../docs/metric-definitions.md) with an owner (make one up for Tema, for example "People Analytics lead"), formula, inclusions, exclusions and caveats. If the doc and the YAML disagree, fix the YAML. Commit and open a pull request.

## Checkpoint

Each of these is one short `MEASURE()` query with no joins:

- [ ] Trailing 12-month voluntary attrition by division, this year vs last.
- [ ] Lowest average compa-ratio by job level (IC4).
- [ ] AI vs rest for time to fill and offer acceptance since May 2025 (about 67 vs 41 days).
- [ ] Headcount at the end of each quarter of 2026 (correct, not summed).
- [ ] eNPS by survey cycle (−7.1 → +16.7).
- [ ] Every measure has a definition entry.

## Why this matters at work

Five small views and a definitions doc is what a working semantic layer actually looks like, and it's far less than people expect. The definitions doc is the part to show HR leaders: they won't read YAML, but they'll argue happily about whether interns count in attrition. Use this week's work to draft your **pilot candidate list**: the three people metrics your company argues about most, and the decisions someone would need to sign off for each.
