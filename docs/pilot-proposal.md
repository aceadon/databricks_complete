# Proposal: a semantic layer workstream for our Databricks rollout

*Reference version of the Week 12 capstone, written for **Tema** (fictional, 70,000 people). Use it to check the shape and level of detail of your own proposal; your version should use your company's words, examples and numbers. Lines in* [brackets] *are where your own results go: a reference repo can't know them.*

## The problem

Tema is moving its HR tables to Databricks, but the definitions behind the numbers aren't moving with them. Asked "what was our headcount at the end of Q2 2025?", two reasonable-looking queries on the same migrated table return 58,862 and 175,524, depending on whether someone took the June value or added up three months. Attrition has the same problem: all leavers or only resignations, part-timers in or out, trailing or calendar year. Each team picks silently, leaders get different answers, and every review starts with a reconciliation.

Access to sensitive people data is the second problem. HRBPs should see salary, birthdays and equity only for the organisations of the leaders they support. Today that rule lives in a reporting tool's settings and a coverage spreadsheet, and it breaks at every reorg.

## What we showed

A working demo on synthetic data (Tema, 70,000 people):

- **One definition, every tool.** Five metric views (workforce, retention, talent acquisition, pay, experience) with 15+ KPIs. "Q2 2025 headcount" returns 58,862 in SQL, the dashboard and Genie, because the semi-additive rule lives in the definition, not in each query. The naive view returns 175,524.
- **AI answers improve with definitions.** The same 20 questions asked of Genie on raw tables and on the metric views: [raw __ / 20 vs semantic layer __ / 20, and __ / 20 after three fixes]. The raw-table agent's typical errors were summing months, dividing leavers by today's headcount, and showing one-person salary groups.
- **One access rule, enforced everywhere.** HRBP scope computed from the reporting hierarchy and dated assignments, applied by a single Unity Catalog function to masks and row filters. Ending an assignment removes access at the next rebuild with no grant changes.
- **Definitions changed like code.** Excluding part-time employees from attrition went through one pull request (definition and YAML together, before and after numbers in the description) and was deployed from Git.

## Value

| Measure | Today | With the semantic layer |
|---|---|---|
| Time to answer a new people question | [ask an HRBP: often days] | Minutes for anything the metrics cover |
| Conflicting headcount / attrition definitions | [count them: usually more than three] | One certified definition each, with a named owner |
| Dashboards and spreadsheets consolidated | [list them] | Rebuilt on metric views; the copies retired |
| Sensitive data access governed by policy | A tool setting plus a spreadsheet | One rule in Unity Catalog, audited in system tables |
| Cost of attrition we can now see | Not measured consistently | At Tema: 8,240 leavers in the 12 months to Oct 2026, 2,782 of them regretted, with $379M of annual base salary between them. At an assumed replacement cost of half a year's salary, regretted attrition costs about **$190M a year**; AI alone is 503 regretted leavers, about $67M. [Use your company's replacement-cost figure] |

## Proposal

- **First domain:** people analytics. Scored against Finance and Operations (below), it has the most visible pain, a likely sponsor, and data the migration is already moving.
- **Owners:** People Analytics lead (metric definitions and certification), HR data owner (source data, HRBP coverage in the HR system), one data engineer from the migration team (gold tables and the bundle), Security partner (access policy review).
- **90-day plan:**
  - *Weeks 1–4:* gold tables for workers, job history and requisitions on top of what the migration lands; definitions signed off for five metrics (headcount, hires, leavers, attrition, time to fill).
  - *Weeks 5–8:* metric views for those five, a Workforce Overview dashboard, a Genie agent for HRBPs, benchmark run before and after.
  - *Weeks 9–12:* HRBP access model with real logins and groups, small-group suppression, certification, the adoption and access dashboard, and a metrics council in place.
- **How it complements the table migration:** the migration moves tables; this makes them mean something. It reuses the migrated tables, adds a thin layer of definitions and access rules on top, and gives the migration team a definition of "done" for each table (the gold table checklist).

| Candidate domain (score 1–5) | People analytics | Finance | Operations |
|---|---|---|---|
| Visible pain | 5 | 4 | 3 |
| A sponsor who'd champion it | 4 | 3 | 2 |
| Data already migrated or migrating | 4 | 3 | 3 |
| Governance difficulty (5 = easiest) | 2 | 3 | 4 |
| How many leaders would notice | 5 | 4 | 2 |
| **Total** | **20** | **17** | **14** |

People data is the hardest to govern, which is exactly why showing it working is persuasive: if the access model holds for salaries, it holds anywhere.

## Asks

1. An executive sponsor in HR (the CPO's office) and one in data.
2. A named HR data owner who can get HRBP coverage and effective-dated org data into the HR system and through the migration.
3. About a day a week from one data engineer for 12 weeks.
4. Access rules agreed with HR, Legal and Security before real data is used (the governance model doc is the starting point).
5. Agreement that metric definitions change only by pull request, reviewed by their owner.

## Giveaways for the migration team (no project needed)

- The [gold table checklist](gold-table-checklist.md).
- The metric definition template from [metric-definitions.md](metric-definitions.md).
- The sensitive-data pattern: split sensitive columns into their own table, tag them, and mask by policy.

The 30-minute demo script is in [demo-script.md](demo-script.md).
