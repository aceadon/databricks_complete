# Week 0: Set up and meet Tema

**Phase 0** · about 2 hours

## Goal

Have a working Databricks workspace connected to this repo, with Tema's HR data loaded, and write down the questions you had to answer before you could say "what's our headcount?". Those questions are why a semantic layer exists.

## Before you start

- A personal email address for the Free Edition sign-up (keep work and personal separate).
- This repo on GitHub, and a GitHub personal access token with repo access, which the Git folder will ask for.

## Steps

### 1. Create your workspace

1. Sign up for [Databricks Free Edition](https://docs.databricks.com/aws/en/getting-started/free-edition).
2. Take a ten-minute tour of the left sidebar: **Catalog** (Catalog Explorer), **SQL Editor**, **Workspace**, **Dashboards**, **Genie**. Don't build anything yet.
3. In **Catalog**, find your catalog. In Free Edition it's usually called `workspace`. Every sheet assumes that name; if yours differs, note it now.

### 2. Connect this repo

1. Go to **Workspace > Create > Git folder**, paste `https://github.com/aceadon/databricks`, and give it your GitHub token when asked.
2. Open the folder and check you can see `plan/`, `labs/` and `hr_people_analytics/`.

### 3. Generate Tema at 5,000 people

1. Open `hr_people_analytics/00_generate_hr_data.py`. Databricks shows it as a notebook.
2. Attach it to **Serverless** compute.
3. Run the first cell once so the widgets appear at the top. Set:
   - `catalog`: `workspace`
   - `schema`: `tema_hr_raw`
   - `target_headcount`: `5000`
4. **Run all.** The last cell prints a row count for each table.

> [!WARNING]
> **Untested in Databricks.** The generator has only been run locally with pandas. Things that could go wrong on serverless:
> - *An error converting a pandas DataFrame to Spark* (often about nullable integer or date columns). Copy the error and the cell; it's likely a one-line fix in `_to_spark_ready`.
> - *Out of memory.* At 5,000 this is unlikely. At 70,000 the run peaks at about 1.3 GB locally; if Free Edition can't cope, try 30,000.
> - *A widget value is ignored.* Rerun from the top after changing widgets.

### 4. Look at what you made

Open a new query in the **SQL Editor** and run:

```sql
USE CATALOG workspace;
SHOW TABLES IN tema_hr_raw;

SELECT * FROM tema_hr_raw.employees LIMIT 20;
SELECT * FROM tema_hr_raw.headcount_monthly WHERE employee_id = 1000001 ORDER BY snapshot_month;
```

Notice that `employees` has sensitive columns sitting next to ordinary ones (`date_of_birth`, `national_id`, `personal_email`), and that `headcount_monthly` has one row per person per month, with three flags: `is_active_month_end`, `is_hire_in_month`, `is_termination_in_month`.

### 5. Try to answer "what's our headcount?"

Pretend a VP just asked you. Run these and compare:

```sql
-- A: count every row for this month
SELECT COUNT(*) FROM tema_hr_raw.headcount_monthly WHERE snapshot_month = '2026-10-31';

-- B: only people still employed at month end
SELECT COUNT(*) FROM tema_hr_raw.headcount_monthly
WHERE snapshot_month = '2026-10-31' AND is_active_month_end;

-- C: FTE instead of people
SELECT SUM(fte) FROM tema_hr_raw.headcount_monthly
WHERE snapshot_month = '2026-10-31' AND is_active_month_end;

-- D: "headcount for Q2 2025", the way a hurried analyst writes it
SELECT COUNT(*) FROM tema_hr_raw.headcount_monthly
WHERE snapshot_month BETWEEN '2025-04-01' AND '2025-06-30' AND is_active_month_end;
```

**Your turn.** In a new file `plan/notes/week-00.md`, write down every decision you had to make to get one number. Aim for at least five.

<details>
<summary>Hint: decisions people usually miss</summary>

- As of when: month end, today, or average over the period?
- Do people who left during the month count?
- Part-timers as 1 person or as their FTE?
- Contractors and interns (Tema has none in this data, but your company does)?
- Which department counts for someone who transferred mid-month?
- For a quarter, the last month's number, not the sum of three months (query D triple-counts).

</details>

### 6. Turn on Genie Code and make your first commit

1. Turn on **Genie Code** (the in-product assistant) and ask it: "Explain what the is_active_month_end column in tema_hr_raw.headcount_monthly means." Judge the answer. It's guessing from the name, because nobody has told it yet.
2. In the Git folder, create a branch `week-00`, commit `plan/notes/week-00.md`, push, and open a pull request on GitHub. Merge it yourself.

## Checkpoint

- [ ] `SHOW TABLES IN tema_hr_raw` lists 12 tables.
- [ ] Query A returns **5,065** (it includes 41 people who left during October), query B returns **5,024**, and query D returns **12,429**, three months added together.
- [ ] Your notes list at least five headcount decisions.
- [ ] Your notes file is on `main` in GitHub.

```sql
-- At 5,000 people expect: employees 7,207, job_history 18,957, headcount_monthly 195,904, requisitions 2,948, hrbp_assignments 31
SELECT 'employees' t, COUNT(*) n FROM tema_hr_raw.employees UNION ALL
SELECT 'job_history', COUNT(*) FROM tema_hr_raw.job_history UNION ALL
SELECT 'headcount_monthly', COUNT(*) FROM tema_hr_raw.headcount_monthly UNION ALL
SELECT 'requisitions', COUNT(*) FROM tema_hr_raw.requisitions UNION ALL
SELECT 'hrbp_assignments', COUNT(*) FROM tema_hr_raw.hrbp_assignments;
```

When it all works at 5,000, rerun the generator at 70,000 (or 30,000 if memory runs out). Later weeks work at either size; the checkpoint numbers quoted in these sheets are for 5,000.

## Why this matters at work

Every one of those decisions is being made today, silently, in someone's spreadsheet or SQL. Two analysts who make different choices report different headcounts, and leaders stop trusting both. Moving tables to Databricks doesn't fix that, because the decisions live in the queries, not the tables. Your list is the first draft of what a semantic layer has to capture, and a concrete way to explain the problem to the rollout team.
