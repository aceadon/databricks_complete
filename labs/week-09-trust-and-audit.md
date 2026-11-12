# Week 9: Trust: suppression, certification and audit

**Phase 4** · about 6 hours

## Goal

Make the semantic layer safe and trustworthy for everyone, not only HRBPs: hide breakdowns small enough to identify a person, let a broad group use metrics without touching the tables underneath, mark what's certified, and see who's using what.

## Before you start

- Weeks 3 to 8 done.
- A branch `week-09`.

## Steps

### 1. Small-group suppression

At 5,000 people, "average compa-ratio by job level" includes E1 and E2, which are one person each. Anyone can read the CEO's pay from that chart.

```sql
-- See the problem
SELECT job_level, MEASURE(avg_compa_ratio), MEASURE(headcount)
FROM workspace.tema_hr_semantic.pay_metrics   -- add a headcount measure to pay_metrics if it lacks one
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY 3;
```

**Your turn.** Build a suppressed version. Two approaches; try both and decide which you'd recommend:

1. **A suppressed view** on top of the metric view, used by dashboards:

   ```sql
   CREATE OR REPLACE VIEW workspace.tema_hr_semantic.pay_by_level_safe AS
   SELECT month, division, job_level,
          CASE WHEN headcount >= 5 THEN avg_compa_ratio END AS avg_compa_ratio,
          CASE WHEN headcount >= 5 THEN headcount END       AS headcount
   FROM (SELECT month, division, job_level,
                MEASURE(avg_compa_ratio) AS avg_compa_ratio, MEASURE(headcount) AS headcount
         FROM workspace.tema_hr_semantic.pay_metrics GROUP BY ALL);
   ```

2. **A rule inside the measure**, so the metric itself returns nothing for small groups:

   ```yaml
     - name: avg_compa_ratio_safe
       expr: CASE WHEN COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end) >= 5
                  THEN AVG(source.annual_base_salary / (job.salary_band_mid * loc.location_pay_factor)) FILTER (WHERE source.is_active_month_end) END
   ```

Note the weakness of both: someone can still subtract. Division total minus every other level can reveal a suppressed value. Write one sentence in your governance doc on how you'd handle that (common answers: suppress the second-smallest group too, or only allow fixed breakdowns).

> [!WARNING]
> **Untested in Databricks.** A `CASE` around aggregates inside a windowed measure may not be allowed. If option 2 fails, use option 1 and note it.

### 2. Aggregate-only access

The goal: a broad audience can query headcount and attrition by department but can't read rows in `tema_hr_gold`.

```sql
GRANT USE CATALOG ON CATALOG workspace TO `account users`;
GRANT USE SCHEMA ON SCHEMA workspace.tema_hr_semantic TO `account users`;
GRANT SELECT ON VIEW workspace.tema_hr_semantic.workforce_metrics TO `account users`;
GRANT SELECT ON VIEW workspace.tema_hr_semantic.retention_metrics TO `account users`;
-- Nothing granted on tema_hr_gold or tema_hr_raw
```

Then check the documentation on how metric view permissions interact with the underlying tables (does the reader need `SELECT` on the source? does the view run as its owner?). Write down what you find.

> [!WARNING]
> **Untested in Databricks.** Free Edition is single-user, so you can't log in as someone else to test this. Read `SHOW GRANTS` instead, and treat the real test as something to do in your company workspace. If `account users` isn't a valid principal in Free Edition, note the error.

### 3. Certify and deprecate

In Catalog Explorer, mark your gold tables and metric views as **certified**, and mark `v_headcount_naive` (from Week 3) as **deprecated**. Then:

- Search for "headcount" in Catalog Explorer and see how certified and deprecated assets appear.
- Ask your Genie Agent about headcount and see whether it avoids the deprecated view.

> [!WARNING]
> **Untested in Databricks.** Certification may be a system tag (`system.certification_status` or similar) or a UI badge depending on your release. Check the docs for the current mechanism.

### 4. Glossary terms and a People domain

If **Business Glossary** and **Domains** are available in your workspace (both in preview), create:

- A `People` domain containing `tema_hr_gold` and `tema_hr_semantic`.
- Glossary terms for Headcount, Attrition rate, eNPS and Compa-ratio, each linked to its metric and with the definition from your definitions doc.

If they're not available, note it and move on; your definitions doc covers the same ground.

### 5. Who's using what: the adoption and access dashboard

System tables record who queried what. Start with:

```sql
-- Queries against your semantic layer, by user and day
SELECT date(start_time) AS day, executed_by, COUNT(*) AS queries
FROM system.query.history
WHERE statement_text ILIKE '%tema_hr_semantic%'
GROUP BY ALL ORDER BY day DESC;

-- Reads of restricted HR tables
SELECT event_time, user_identity.email, action_name, request_params
FROM system.access.audit
WHERE request_params::string ILIKE '%tema_hr_secure%'
ORDER BY event_time DESC
LIMIT 100;
```

**Your turn.** Build a small dashboard, **Semantic layer adoption and access**, with: queries per metric view per week, distinct users, and every access to `tema_hr_secure`. Save it next to the Workforce dashboard.

> [!WARNING]
> **Untested in Databricks.** System tables may need to be enabled by an admin, and Free Edition may expose only some of them. Column names change between releases; run `DESCRIBE system.query.history` first. If they're unavailable, write the queries anyway; you'll need them at work.

### 6. Finish the governance model and commit

Complete [docs/people-data-governance-model.md](../docs/people-data-governance-model.md): roles, metric ownership and certification, the access lifecycle, minimum group size, and open decisions. Commit everything and open a pull request.

## Checkpoint

- [ ] No pay or rating breakdown on any dashboard or safe view shows a group under 5 people.
- [ ] You can show, from grants, that a broad group has metric views but not tables.
- [ ] Certified and deprecated assets are visibly different in Catalog Explorer.
- [ ] An adoption and access dashboard exists (or its queries are written).
- [ ] The governance model doc is complete enough to hand to HR, Legal and Security.

## Why this matters at work

People data is where a semantic layer either earns trust or gets shut down. Suppression and aggregate-only access mean managers and leaders can self-serve without anyone seeing a colleague's pay. Certification tells people which numbers to use. Audit lets Security say yes, because they can see what happened. The governance model doc is the one to give your HR and Legal teams; it reassures them before they ask.
