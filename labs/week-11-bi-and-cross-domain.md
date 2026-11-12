# Week 11: BI tools and cross-domain questions

**Phase 5** · about 6 hours

## Goal

Show that the semantic layer reaches beyond Databricks: connect a BI tool to a metric view, then answer a question no HR system can, by putting people metrics next to business data. Finish with a short comparison of where Unity Catalog Metrics fits among other semantic tools.

## Before you start

- Weeks 3 to 10 done.
- Optional: Power BI Desktop (Windows) or a Tableau trial.
- A branch `week-11`.

## Steps

### 1. Connect a BI tool

Follow the Databricks docs for connecting **Power BI** or **Tableau** to Unity Catalog metric views. Build one chart: headcount by division by quarter. Check that the quarter values are quarter-end headcount (4,176 for 2025-Q2), not a sum.

If you can't install either tool, write the steps from the docs in `docs/bi-connection-notes.md` with the questions you'd ask your BI team (which tool, gateway, who authenticates, whether row filters pass through per user).

> [!WARNING]
> **Untested in Databricks.** BI connectivity to metric views is new and differs by tool. Free Edition may limit external connections or personal access tokens. If you hit a block, document it; that's a useful finding for your rollout team.

### 2. Create a little business data for Tema

Free Edition has no Tema revenue data, so make some. Create `hr_people_analytics/gold/10_fact_ad_revenue.sql`:

```sql
USE CATALOG workspace;
USE SCHEMA tema_hr_gold;

-- Synthetic monthly ad revenue and support tickets for Tema. Fictional numbers.
CREATE OR REPLACE TABLE fact_business_monthly
COMMENT 'Synthetic monthly ad revenue (USD) and advertiser support tickets for Tema. Fictional, for cross-domain demos.'
AS
SELECT month_end,
       ROUND(180000000 * POW(1.012, n) * (1 + 0.06 * SIN(n / 1.9))
             * CASE WHEN month_end >= '2025-05-31' THEN 1 + 0.015 * (n - 28) ELSE 1 END, -3) AS ad_revenue_usd,
       ROUND(42000 * POW(1.01, n) * (1 + 0.1 * COS(n / 2.3)))                                AS support_tickets
FROM (SELECT month_end, ROW_NUMBER() OVER (ORDER BY month_end) - 1 AS n
      FROM dim_date WHERE month_end <= '2026-10-31');
```

Revenue grows steadily and picks up after the AI launch in May 2025. (These numbers are made up and sized for a 70,000-person company; they don't need to be realistic, only plausible.)

### 3. Answer a cross-domain question

**Your turn.** Build a `business_metrics` metric view on `fact_business_monthly`, then answer at least one of:

- **Revenue per employee** by quarter: `ad_revenue_usd` ÷ headcount. How has it changed since the AI boom?
- **AI cost vs revenue growth**: AI headcount × average AI salary against revenue growth.
- **Support load**: support tickets per Advertiser Support employee by month, next to Advertiser Support attrition.

<details>
<summary>Hint: two metric views, one query</summary>

You can join two metric views' results on their shared dimension:

```sql
SELECT p.quarter, b.revenue / p.headcount AS revenue_per_employee
FROM (SELECT quarter, MEASURE(headcount) AS headcount
      FROM workspace.tema_hr_semantic.workforce_metrics GROUP BY ALL) p
JOIN (SELECT quarter, MEASURE(ad_revenue) AS revenue
      FROM workspace.tema_hr_semantic.business_metrics GROUP BY ALL) b USING (quarter)
ORDER BY quarter;
```

Also try the **multi-fact relationships** feature (Public Preview) so one metric view covers both facts, and compare.

</details>

### 4. Ask Genie the same question

Add `business_metrics` to your Genie Agent and ask "What's our revenue per employee by quarter?" Does it get the semi-additive headcount right when it divides?

### 5. Write the comparison

Create `docs/semantic-tools-comparison.md`, one page:

| | Unity Catalog Metrics | dbt Semantic Layer | Power BI / Tableau models | Your company today |
|---|---|---|---|---|
| Where definitions live | | | | |
| Who can use them (SQL, BI, AI) | | | | |
| Governance (masks, row filters) | | | | |
| Change process | | | | |
| Lock-in | | | | |

Add a short paragraph on where tools like AtScale, Cube and Atlan fit, and on how HR data usually lands in Databricks (for example Lakeflow Connect for Workday or similar; check what your company uses).

### 6. Commit

Commit the new table, metric view, notes and comparison, and open a pull request.

## Checkpoint

- [ ] A BI tool shows a metric view correctly, or you've documented the steps and blockers.
- [ ] One cross-domain answer, such as revenue per employee by quarter, from metric views.
- [ ] The comparison page is filled in, including your company's current setup.

## Why this matters at work

An HR system can tell you headcount; it can't tell you revenue per employee, or whether Advertiser Support churn follows ticket volume. Those questions need people data and business data under the same definitions, which is exactly what a company-wide semantic layer provides and a departmental tool can't. This is the argument that gets leaders outside HR interested.
