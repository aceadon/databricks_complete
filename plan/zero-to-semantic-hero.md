# Zero to Semantic Hero on Databricks (People Analytics edition)

A learning-and-building plan for becoming the person at your company who knows how to turn Databricks tables into trusted, reusable business meaning, and who can show why that matters. The running project uses **HR and employee data**.

*Written November 2026. Databricks ships fast and several features below are in Preview or Beta, so check the linked docs before relying on a status.*

---

## Why this plan exists

The rollout team is moving tables. That is necessary, but on its own it recreates the old warehouse in a new place: hundreds of tables, every analyst rewriting "headcount" in their own SQL, every dashboard a little different, and AI assistants guessing what columns mean.

The **semantic layer** is the part that turns tables into a business asset:

| Without a semantic layer | With one |
|---|---|
| HR, Finance and leadership each report a different headcount | One governed `Headcount` metric, used everywhere |
| "Attrition rate" calculated three different ways | One certified definition, with an owner |
| Genie/AI answers vary and can't be trusted | Genie grounds answers in certified definitions |
| Salary and personal data either locked away or overexposed | Managers see aggregates, HR partners see their division, nobody sees what they shouldn't |
| People data lives in a separate HR tool | People metrics sit next to sales, cost and operations data, so you can ask cross-functional questions |

Your goal is to be able to **build it, explain it, and prove its value** with a working pilot.

### Why HR data works as well as sales data (and in some ways better)

| Skill | Sales version | HR version | Verdict |
|---|---|---|---|
| Star schema and joins | orders, products, stores | employees, jobs, departments, managers | Same |
| Additive measures | revenue | absence days, hires, terminations | Same |
| **Semi-additive measures** | rare | headcount: add across departments, never across months | HR teaches more |
| **Ratio of two facts** | revenue per store | attrition = leavers / average headcount | HR teaches more |
| Rolling windows | revenue trend | trailing 12-month attrition, the standard HR KPI | Same |
| Level-of-detail (LOD) | share of total | pay vs department average, compa-ratio | Same |
| Slowly changing history | rare | promotions and transfers over time | HR teaches more |
| **Governance** | light | salary, date of birth, IDs, manager-only views, small-group suppression | HR teaches much more |
| Hierarchies | product categories | manager → director → division | HR teaches more |
| Business value story | revenue | turnover cost, time to fill, engagement | Same, and resonates with every leader |

HR is also a domain where definitions are fought over (whether contractors count, part-time FTE, the date someone actually leaves), which is exactly the problem a semantic layer solves.

> **Important:** use only the **synthetic data** in this repo in your personal workspace. Never put real employee data into a personal or trial workspace. When you pilot at work, do it in your company's workspace with HR, Legal and Security involved.

---

## What "the semantic layer" means on Databricks today

Databricks doesn't ship a single product named "semantic layer." It is a set of Unity Catalog capabilities that work together. Learn them as one stack:

1. **Unity Catalog foundations.** Catalogs, schemas, tables, views, owners, comments, and tags. Good names and descriptions are the cheapest semantic layer there is.
2. **Unity Catalog Metrics (metric views).** KPIs defined once in YAML or a low-code editor, with dimensions, measures, joins, windows, and level-of-detail logic. Queried with `MEASURE()` from SQL, dashboards, Genie, and external BI tools. Local metric views (scoped to a dashboard) went GA in August 2026; multi-fact relationships and materialization are in Public Preview.
3. **Business meaning.** Unity Catalog Semantics brings together metrics, a **Business Glossary** (preview), and **Domains** (Public Preview) so terms and assets are organized the way the business thinks.
4. **Genie Ontology.** A self-updating context layer (Public Preview, on by default since August 2026) that feeds your metrics, descriptions, and usage into Genie so its answers use your definitions.
5. **Consumption.** AI/BI Dashboards, **Genie Agents** (formerly Genie Spaces), **Genie One** (the business-user "coworker"), Databricks One, and external tools such as Power BI and Tableau.
6. **Governance and trust.** Governed tags, data classification, ABAC policies (GA), row filters and column masks, lineage (including external lineage, GA), certification and deprecation tags, and system tables for usage.

The plan walks up this stack, building one connected project as you go.

---

## The running project: Tema

**Tema** is a fictional software company that sells ads on its social media platform. Free Edition has no HR sample data, so this repo includes a generator: [`hr_people_analytics/00_generate_hr_data.py`](../hr_people_analytics/00_generate_hr_data.py). By default it builds Tema at about **70,000 employees**, the same scale as your company, tracked monthly from January 2023 to October 2026.

**Tema's story (built into the data):**

- **Six divisions, 23 departments:** Engineering (Core Platform, Feed & Ranking, Ads Engineering, Infrastructure & SRE, Security, Mobile & Web), **AI** (AI Research, Applied AI & ML, AI Infrastructure), Product & Design, Ads Business (Ads Sales, Agency & Partner Management, Advertiser Support, Marketing), Trust & Safety (content moderation operations and Policy), and Corporate.
- **Ten locations** from San Francisco and New York to Dublin, Bangalore and Sao Paulo, with location-based pay.
- **A real org chart:** CEO, about 20 SVPs, 140 VPs, 1,000 directors and 7,000 first-line managers, five layers deep. Manager-based access rules only feel real at this depth.
- **A People organisation:** a Chief People Officer reporting to the CEO, with about 70 **HR business partners (HRBPs)**. Every VP, and every director with 110 or more people below them, is supported by one or more HRBPs. Some HRBPs support several leaders across divisions, and some leaders have two HRBPs.
- **January 2023 layoffs:** a restructuring round, a slow 2023, and morale (eNPS) that dips and then recovers over two years.
- **The AI boom:** the AI team grows from about 1,100 people in April 2025 to over 8,000 by October 2026. AI hires skew senior and come in above band, roles take much longer to fill, and AI attrition is high, with about half of it regretted and "competitor offer" as a top reason.
- **High-churn frontline teams:** Trust & Safety Operations and Advertiser Support turn over at roughly twice the rate of Engineering.
- **Planted findings:** low engagement and below-band pay predict leaving, some managers keep their people much longer than others, first-year attrition is high, and there's a small gender pay gap inside salary bands.

| Table | What's in it | Rows at 70,000 employees (approx.) |
|---|---|---|
| `employees` | One row per person ever employed: hire/termination dates, reason, regretted or not, and **sensitive fields** (date of birth, gender, national ID, personal email, postcode) | 100,000 |
| `job_history` | Every hire, promotion, transfer and merit increase with effective dates (slowly changing history) | 265,000 |
| `headcount_monthly` | Month-end snapshot of everyone employed in the month, with hire and leaver flags | 2.8 million |
| `departments`, `jobs`, `locations` | Dimensions, including salary bands per job and location pay factors | small |
| `requisitions` | Open, filled and cancelled roles with applicants, interviews and offers | 30,000 |
| `absences` | Sick, vacation, parental and other leave | 900,000 |
| `engagement_surveys` | Twice-yearly eNPS, engagement, manager, wellbeing and growth scores | 300,000 |
| `performance_reviews` | Annual 1 to 5 ratings with the reviewing manager | 160,000 |
| `equity_grants` | New hire, annual refresh, promotion and AI retention stock grants, with a fictional TEMA share price | 115,000 |
| `hrbp_assignments` | Which HRBP supports which leader, primary or secondary, with start and end dates | 280 |

**Why build it at full size?** For learning the concepts, a few thousand employees is enough. For showing people at work, scale matters: numbers that look like your company are more convincing, small-group suppression and manager-hierarchy filters only become meaningful with thousands of managers, and you'll see real query performance (and a reason to try materialization). The generator takes a `target_headcount` setting, so use 5,000 for quick experiments and 70,000 for demos. A full run takes a few minutes.

---

## How to use this plan

- **Pace:** about 12 weeks at 4 to 6 hours a week. Phases can stretch or compress.
- **Every phase ends with three things:** something you built, a checkpoint you can self-test against, and a "business translation" you can reuse at work.
- **Weekly lab sheets:** [labs/](../labs/README.md) has one sheet per week with step-by-step instructions, a checkpoint with the numbers to expect, and a note on why it matters at work.
- **Store your work in this repo** (`aceadon/databricks`) using Databricks Git folders, so it becomes a portfolio and a reusable template for your company.

---

## Phase 0: Set up your personal workspace (week 0, about 2 hours)

**Do**

1. Sign up for **Databricks Free Edition** at the [Free Edition page](https://docs.databricks.com/aws/en/getting-started/free-edition). It's free, serverless-only, and quota-limited, but it includes Unity Catalog, SQL warehouses, notebooks, AI/BI dashboards, Genie, Genie Code, and Lakeflow.
   - If you hit a Free Edition limit (check the limitations page linked from the signup docs), a 14-day full trial on AWS, Azure, or GCP is the fallback. Save trial time for features Free Edition lacks.
2. Explore the UI: Catalog Explorer, SQL Editor, Workspace, Dashboards, Genie.
3. Connect this GitHub repo through **Workspace > Create > Git folder**.
4. Open `hr_people_analytics/00_generate_hr_data.py` as a notebook, set the `catalog` widget to your workspace catalog (often `workspace` in Free Edition), leave `schema` as `tema_hr_raw`, and run it. Start with `target_headcount` at 5,000 to check everything works (about a minute), then rerun at 70,000 (a few minutes). If Free Edition runs out of memory at full size, try 30,000.
5. Turn on Genie Code (the in-product assistant) and use it as a tutor throughout.

**Checkpoint:** you can query `tema_hr_raw.headcount_monthly` in the SQL editor and commit a change to GitHub from the workspace.

**Business translation:** try answering "What's our headcount?" with raw SQL. Notice the questions you have to decide first (as of when? part-timers as 1 or as FTE? people who left mid-month?). Write them down. Those decisions are what a semantic layer captures, and they're your first argument for it.

---

## Phase 1: Lakehouse and Unity Catalog fundamentals (weeks 1 to 2)

**Learn**

- Lakehouse basics: Delta tables, serverless SQL warehouses, notebooks vs SQL editor.
- The Unity Catalog object model: metastore > catalog > schema > table/view/volume/function/model.
- Ownership, `GRANT`/`REVOKE`, groups, and least privilege.
- Medallion architecture (bronze, silver, gold) and why the semantic layer sits on top of gold.
- Slowly changing dimensions (type 2) using `job_history`.
- Lineage in Catalog Explorer.

**Build**

- An `tema_hr_gold` schema with a clean star: `fact_headcount_monthly`, `fact_terminations`, `fact_absences`, `fact_engagement`, `fact_requisitions`, `dim_employee` (no sensitive fields), `dim_employee_sensitive` (the sensitive fields, kept separate), `dim_department`, `dim_job`, `dim_location`, `dim_manager`, `dim_date`.
- Table and column **comments** on every gold object. Try "AI-generated comments" in Catalog Explorer, then correct them; HR definitions need to be exact.
- **Tags**: `domain=people`, and `sensitivity=confidential` on salary and personal columns.

**Checkpoint:** someone who has never seen this data could understand the gold tables from Catalog Explorer alone, and could tell which columns are sensitive.

**Resources:** Databricks Academy "Get Started with Databricks for Data Analysis" and "Data Governance with Unity Catalog" (free self-paced courses), Unity Catalog docs.

**Business translation:** a half-page "what good gold tables look like" checklist you could hand the migration team, including how to separate sensitive columns.

---

## Phase 2: Unity Catalog Metrics, the core skill (weeks 3 to 5)

This is the heart of the plan. Spend the most time here. HR metrics are a great teacher because several of them are deceptively hard.

**Learn**

- What a metric view is and how it differs from a regular view: dimensions and measures are separate, and aggregation happens at query time at whatever grain the user asks for.
- Syntax: `CREATE VIEW ... WITH METRICS LANGUAGE YAML AS $$ ... $$`, the YAML spec (`source`, `joins`, `dimensions`, `measures`, `filter`, display names, formats, synonyms), and querying with `MEASURE()`.
- The low-code metric view editor and local metric views inside dashboards.
- **Window measures**, especially **semi-additive** measures (headcount at period end) and **trailing windows** (12-month attrition).
- Level-of-detail (LOD) expressions, parameters, median/percentile, multi-fact relationships, and materialization (Public Preview).
- Permissions on metric views and how they inherit from Unity Catalog.

**Build**

1. A first metric view on the monthly snapshot:

   ```sql
   CREATE OR REPLACE VIEW workspace.tema_hr_semantic.workforce_metrics
   WITH METRICS LANGUAGE YAML AS $$
   version: 1.1
   source: workspace.tema_hr_gold.fact_headcount_monthly
   joins:
     - name: dept
       source: workspace.tema_hr_gold.dim_department
       on: source.department_id = dept.department_id
     - name: job
       source: workspace.tema_hr_gold.dim_job
       on: source.job_id = job.job_id
   dimensions:
     - name: Month
       expr: source.snapshot_month
     - name: Department
       expr: dept.department_name
     - name: Division
       expr: dept.division
     - name: Job Level
       expr: job.job_level
   measures:
     - name: Headcount
       expr: COUNT(DISTINCT source.employee_id) FILTER (WHERE source.is_active_month_end)
       window:
         - order: Month
           range: current
           semiadditive: last
     - name: FTE
       expr: SUM(source.fte) FILTER (WHERE source.is_active_month_end)
       window:
         - order: Month
           range: current
           semiadditive: last
     - name: Hires
       expr: COUNT(1) FILTER (WHERE source.is_hire_in_month)
     - name: Leavers
       expr: COUNT(1) FILTER (WHERE source.is_termination_in_month)
     - name: Average Salary
       expr: AVG(source.annual_base_salary)
   $$;

   SELECT Division, MEASURE(Headcount), MEASURE(Leavers)
   FROM workspace.tema_hr_semantic.workforce_metrics
   WHERE Month BETWEEN '2026-01-01' AND '2026-10-31'
   GROUP BY ALL;
   ```

   Notice that `Headcount` for January to October returns October's number, not the sum of ten months. That's the semi-additive window doing its job. (Check the current YAML version and window syntax in the docs; window measures have been evolving.)

2. A people metrics catalog of 12 to 15 KPIs:
   - **Workforce:** headcount, FTE, net change, span of control, internal mobility rate.
   - **Retention:** monthly attrition rate (leavers / average headcount), trailing 12-month attrition, voluntary and regretted attrition, first-year attrition.
   - **Talent acquisition:** time to fill, offer acceptance rate, applicants per hire, open requisitions.
   - **Pay:** compa-ratio (salary / (band midpoint × location pay factor)), pay vs department average (LOD), gender pay gap within level.
   - **Experience:** eNPS (% promoters − % detractors), engagement score, absence rate, average rating.
3. A **metric definitions doc** in this repo: each metric's business definition, owner, formula, inclusions and exclusions (contractors? part-timers?), and caveats. In HR this document matters as much as the code.

**Checkpoint:** with short `MEASURE()` queries and no hand-written joins or windows, you can answer:
- "What's our trailing 12-month voluntary attrition by division, and how does it compare with last year?"
- "Which job levels have the lowest average compa-ratio?"
- "How does time to fill and offer acceptance for AI roles compare with the rest of Tema since the AI boom began?"
- "What's headcount at the end of each quarter this year?" (and it's correct)

**Business translation:** pick three people metrics your company argues about today (headcount is almost always one). Draft how each would be defined as a metric view and list the decisions someone has to sign off. This becomes your pilot candidate list.

---

## Phase 3: AI/BI Dashboards and Genie on top of the semantic layer (weeks 6 to 7)

**Learn**

- AI/BI Dashboards: datasets, using metric views as datasets, dashboard relationships (GA), variables, filters, scheduling and sharing, Git folders for dashboards.
- **Genie Agents** (formerly Genie Spaces): adding metric views and tables as sources, instructions, example SQL, trusted assets, benchmarks, and the knowledge store (local descriptions, hidden columns).
- **Genie One** for business users, and **Databricks One** as the business-user entry point.
- Agent mode in Genie for multi-step analysis ("why did attrition rise in Support?").

**Build**

1. A **Workforce Overview** dashboard built only on your metric views: headcount trend, attrition by division, hiring funnel, engagement vs attrition.
2. A Genie Agent called "People Analytics Assistant" that uses the metric views first. Write instructions that encode HR rules, for example "never show results for groups under 5 people" and "attrition always means trailing 12-month unless asked otherwise".
3. A **benchmark set** of 20 HR questions with expected answers. Run it twice: once with Genie pointed at the raw `tema_hr_raw` tables, once with your metric views, comments and instructions. Record accuracy for each. Good questions to include:
   - "How many people did we have at the end of Q2 2025?" (raw tables usually sum months and get it wrong)
   - "How much has the AI team grown since the start of 2025, and what's its regretted attrition?"
   - "What's our attrition rate this year?"
   - "Which managers have the highest regretted attrition?"
   - "Do people who leave have lower engagement scores beforehand?"

**Checkpoint:** your benchmark shows a measurable accuracy gain from the semantic layer. This before-and-after number is your strongest single argument at work.

**Business translation:** a 3-slide story. The question an HR business partner asked, the wrong or inconsistent answer from raw tables, and the right answer from governed metrics.

---

## Phase 4: Governance and trust (weeks 8 to 9)

HR data is where governance stops being theory. This phase is longer and richer than it would be with sales data.

**Learn**

- Governed tags and automatic data classification (watch it find dates of birth, emails and IDs).
- ABAC policies (GA), row filters, and column masks, and how they apply through metric views, dashboards and Genie.
- Aggregate-only access: giving people metrics without row-level access to the tables underneath.
- Certification and deprecation tags so users know which assets to trust.
- Lineage, including external lineage to BI tools.
- **Business Glossary** and **Domains** in Unity Catalog Semantics (check current preview status).
- System tables (`system.access.audit`, `system.query.history`, lineage tables) to see who uses what and who accessed sensitive data.
- Data quality monitoring for the gold tables beneath your metrics.

**Build**

1. **The HRBP access model** ([hr_people_analytics/governance](../hr_people_analytics/governance/README.md)). This is the centrepiece of the phase and tackles a problem your company has today: HRBPs should see sensitive data only for the organisations of the leaders they support, where one HRBP can cover several leaders across areas and one leader can have several HRBPs. You'll:
   - build an **org closure table** (every leader to every recursive report) with a recursive CTE,
   - derive each HRBP's **scope** from dated coverage assignments,
   - put all the rules in **one function**, then apply it through **column masks** (birth date, birthday, national ID, personal email, postcode, salary, equity) and a **row filter** (equity grants),
   - **act as** an HR admin, two HRBPs who share a leader, a manager and an employee, and see exactly what each can see,
   - end an assignment and watch access disappear, and see how masks change what an "average salary" means.
2. Turn the demo into production thinking: swap the persona table for groups and an HR identity mapping, and sketch the **ABAC policy** that applies the same masks to every column tagged `hr_sensitivity = restricted`.
3. A **small-group suppression** rule: a view or Genie instruction that hides any breakdown with fewer than 5 people, so nobody can work out an individual's salary or rating.
4. Give an `all_employees` group access to the metric view only (headcount by department, for example) and confirm they cannot query the underlying tables.
5. Certify your gold tables and metric views; deprecate one old view to see how it surfaces.
6. Glossary terms for each KPI, linked to the metric views, and a `People` domain.
7. A **semantic layer adoption and access dashboard** from system tables: which metrics are queried, by whom, and every access to sensitive columns.

**Checkpoint:** you can demo, acting as different people, that an HRBP sees salaries, birthdays and equity only for the organisations they support, a manager sees only what they should about their team, and nobody sees data they shouldn't, including through dashboards and Genie.

**Business translation:** a one-page governance model for people data: who owns each metric definition, how a metric gets certified, how changes are reviewed, and how access maps to HR roles. This is also the document that will reassure your HR and Legal teams.

---

## Phase 5: Tooling, engineering practice, and the wider ecosystem (weeks 10 to 11)

**Learn**

- **Metric views as code:** keep YAML in Git, deploy with Databricks Asset Bundles or dbt, and review changes through pull requests.
- **BI interoperability:** connecting Power BI and Tableau to metric views, and importing existing Power BI/Tableau models and workbooks into Databricks (GA for dashboards; model import in beta for metrics).
- **Open Semantic Interchange (OSI)** and the open-source metric view implementation in Apache Spark and Unity Catalog OSS, and what that means for avoiding lock-in.
- Third-party semantic and catalog tools (dbt Semantic Layer, AtScale, Cube, Atlan) and where each fits or overlaps with Unity Catalog Metrics.
- HR system integration patterns: how data from Workday, SuccessFactors, or similar systems typically lands in Databricks (Lakeflow Connect has connectors for several HR systems; check which match your company).
- Exposing metrics to agents: Genie Agent APIs, Unity Catalog functions as tools, MCP. (Your project eBooks on agents, context engineering, and Decision Fabric go deep here.)

**Build**

1. Move your metric YAML into this repo with a deploy bundle, and change one metric definition (for example, excluding interns from attrition) through a pull request.
2. Connect Power BI Desktop or Tableau (trial) to a metric view, or document the steps if you can't install them.
3. A cross-domain question: join your people metrics with a cost or sales metric (make a small synthetic ad revenue or support ticket table for Tema), for example "ad revenue per employee", "AI headcount cost vs AI-driven revenue" or "Advertiser Support headcount vs ticket volume". This is the kind of question the semantic layer makes possible and an HR tool can't answer.
4. Write a short comparison: Unity Catalog Metrics vs your company's current HR reporting or BI semantic models.

**Checkpoint:** a metric change goes from Git to the workspace without hand edits, and you can explain the trade-offs of each external tool.

---

## Phase 6: Capstone and the champion plan (week 12 and beyond)

**Build a pilot proposal for your company**

1. **Pick one domain** with visible pain. People analytics is a strong first choice if you can get HR as a sponsor, because headcount and attrition disagreements are universal and leaders feel them. Finance or operations work too.
2. **Recreate the pattern** from Tema on that domain: gold tables, metric views, a Genie Agent, a dashboard, and governance. For HR, do this in the company workspace with HR, Legal and Security agreeing access rules first.
3. **Measure value** with numbers leadership cares about:
   - Genie answer accuracy before vs after (from your benchmark method).
   - Time for HR partners or managers to get an answer (from days to minutes).
   - Number of conflicting headcount or attrition definitions retired.
   - The cost of attrition you can now see: leavers × typical replacement cost (often quoted as a significant share of annual salary; use your company's own figure).
   - Dashboards, spreadsheets or BI models consolidated.
   - Adoption from system tables.
4. **Write the case** for adding a semantic layer workstream to the rollout: problem, demo, numbers, proposed owners, a 90-day plan, and how it complements (not competes with) the table migration.

**Champion habits**

- Run a 30-minute "one headcount number" demo for the migration team and one HR or business team.
- Offer a metric-definition template, a gold-table checklist and a sensitive-data pattern that the migration team can adopt at almost no cost.
- Start a small "metrics council" with business owners for the first domain.

---

## Credentials worth considering

- **Databricks Certified Data Analyst Associate**: closest match to this plan (SQL, dashboards, Genie, Unity Catalog).
- **Databricks Certified Data Engineer Associate**: useful credibility with the migration team.
- **Generative AI Engineer Associate**: optional, if you go further into agents on top of the semantic layer.

Check Databricks Academy for current exam guides, since exam content gets refreshed as features change.

---

## Resources

**Official**

- [Databricks Free Edition](https://docs.databricks.com/aws/en/getting-started/free-edition)
- Unity Catalog metric views docs (search "metric views" in Databricks docs for the YAML reference, window measures, and the `MEASURE()` function)
- [AI/BI and Genie One release notes 2026](https://learn.microsoft.com/en-us/azure/databricks/ai-bi/release-notes/2026): watch this monthly
- Databricks Academy free self-paced courses (Data Analysis, Unity Catalog governance, AI/BI)
- Databricks Community forums, especially the Free Edition help board

**Context and analysis**

- [Data + AI Summit 2026 announcements (Atlan)](https://atlan.com/know/ai-agent/databricks/databricks-data-ai-summit-2026-announcements/)
- [What is Unity Catalog Metrics? (Atlan)](https://atlan.com/know/ai-agent/databricks/unity-catalog-metrics/)
- [DAIS 2026 governance recap (Databricks Community)](https://community.databricks.com/t5/data-governance/recap-data-ai-summit-2026-data-governance-simplify-governance/m-p/160963)

**Already in this project**

- *Building Genie One on Databricks*: Phase 3
- *Context Engineering on Databricks*: Phases 3 and 5 (why semantics improve AI answers)
- *Decision Fabric on Databricks*: Phase 6 (business value framing)
- *Agent Concepts*, *Building Agents*, *Agent Bricks Stock Decision Agent*: Phase 5 and beyond

---

## Repo layout

```
README.md
plan/
  zero-to-semantic-hero.md      this plan
labs/                           one lab sheet per week (weeks 0 to 12)
hr_people_analytics/
  README.md                     dataset overview, run order, schema naming
  00_generate_hr_data.py        synthetic Tema data generator (Phase 0)
  gold/                         SQL to build gold tables (Phase 1)
  metrics/                      metric view definitions (Phase 2)
  dashboards/                   dashboard definitions (Phase 3)
  genie/                        Genie Agent instructions and benchmark (Phase 3)
  governance/                   HRBP access model and activity (Phase 4)
docs/
  metric-definitions.md         template with two worked examples (Phase 2)
  gold-table-checklist.md       (Phase 1)
  people-data-governance-model.md   template (Phase 4)
  pilot-proposal.md             template (Phase 6)
```

Work on a branch and merge into `main` through a pull request, so each phase's changes are reviewable, the same way you'd want metric changes reviewed at work.

---

## Progress tracker

| Phase | Focus | Target week | Done |
|---|---|---|---|
| 0 | Workspace setup and data generation | 0 | ☑ |
| 1 | Unity Catalog fundamentals | 1 to 2 | ☑ |
| 2 | Unity Catalog Metrics | 3 to 5 | ☑ |
| 3 | Dashboards and Genie | 6 to 7 | ☑ |
| 4 | Governance and trust | 8 to 9 | ☑ |
| 5 | Tooling and ecosystem | 10 to 11 | ☑ |
| 6 | Capstone and champion plan | 12+ | ☑ |
