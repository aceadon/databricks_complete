# Week 1: Unity Catalog and the dimension tables

**Phase 1** · about 5 hours

## Goal

Understand how Unity Catalog organises data and who can see it, then build the first half of Tema's gold layer: the dimension tables, with sensitive personal data split into its own table from day one.

## Before you start

- Week 0 done: `workspace.tema_hr_raw` has 12 tables.
- A branch `week-01` in your Git folder.

## Learn (about 2 hours)

Work through these, then check yourself with the questions below.

1. Databricks Academy, **Get Started with Databricks for Data Analysis** (free, self-paced). Skim what you know.
2. Unity Catalog docs: the object model (metastore > catalog > schema > table, view, volume, function) and privileges (`USE CATALOG`, `USE SCHEMA`, `SELECT`, ownership).
3. Read about the medallion architecture (bronze, silver, gold). Tema's `tema_hr_raw` plays the role of bronze/silver; you're building gold.

**Check yourself:** Why does a user need `USE SCHEMA` as well as `SELECT` on a table? Who owns a table you create, and what can an owner do? Why does the semantic layer sit on gold rather than raw?

## Steps

### 1. Explore permissions on what you already have

```sql
USE CATALOG workspace;
SHOW GRANTS ON SCHEMA tema_hr_raw;
DESCRIBE TABLE EXTENDED tema_hr_raw.employees;   -- look for Owner
```

In Catalog Explorer, open `tema_hr_raw.employees` and look at the **Permissions**, **Lineage** and **Details** tabs. Lineage is nearly empty because the data was written from pandas. It fills in once you build tables with SQL.

> [!WARNING]
> **Untested in Databricks.** Free Edition is single-user, so you may not be able to create groups or grant to anyone else. Read the grants rather than change them; Week 9 comes back to access.

### 2. Meet the slowly changing history

`job_history` is a type 2 slowly changing dimension: one row per period someone held a job, with `effective_from`, `effective_to` and `is_current`.

```sql
-- One person's career at Tema
SELECT * FROM tema_hr_raw.job_history
WHERE employee_id = (SELECT employee_id FROM tema_hr_raw.job_history
                     WHERE change_reason = 'Promotion' LIMIT 1)
ORDER BY effective_from;

-- What changes most often?
SELECT change_reason, COUNT(*) FROM tema_hr_raw.job_history GROUP BY ALL ORDER BY 2 DESC;
```

**Your turn.** Write a query that returns the department each employee was in on **2025-01-01**. Then count people per department on that date.

<details>
<summary>Answer</summary>

```sql
SELECT d.department_name, COUNT(*) AS people
FROM tema_hr_raw.job_history h
JOIN tema_hr_raw.departments d ON d.department_id = h.department_id
JOIN tema_hr_raw.employees e ON e.employee_id = h.employee_id
WHERE h.effective_from <= '2025-01-01'
  AND (h.effective_to IS NULL OR h.effective_to >= '2025-01-01')
  AND e.hire_date <= '2025-01-01'
  AND (e.termination_date IS NULL OR e.termination_date > '2025-01-01')
GROUP BY ALL ORDER BY people DESC;
```

The `effective_from <= date AND (effective_to IS NULL OR effective_to >= date)` pattern is the heart of every "as of" question in HR. Remember it.

</details>

### 3. Create the gold schema

In your Git folder, create a SQL notebook `hr_people_analytics/gold/01_dimensions.sql` and start it with:

```sql
USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS tema_hr_gold
  COMMENT 'Tema (fictional) people analytics star schema. Clean, documented tables for metrics, dashboards and Genie. Synthetic data only.';
USE SCHEMA tema_hr_gold;
```

### 4. Build the simple dimensions

```sql
CREATE OR REPLACE TABLE dim_department AS
SELECT department_id, department_name, division, cost_center
FROM tema_hr_raw.departments;

CREATE OR REPLACE TABLE dim_location AS
SELECT location_id, city, country, region, location_pay_factor
FROM tema_hr_raw.locations;

CREATE OR REPLACE TABLE dim_job AS
SELECT job_id, job_title, job_family, job_level,
       CASE LEFT(job_level, 1) WHEN 'I' THEN 'Individual contributor'
                               WHEN 'M' THEN 'Manager' ELSE 'Executive' END AS job_track,
       is_manager, salary_band_min, salary_band_mid, salary_band_max
FROM tema_hr_raw.jobs;
```

Job levels run IC1 to IC6 for individual contributors, M1 (manager), M2 (senior manager), M3 (director), M4 (VP), M5 (SVP), and E1/E2 for the CEO and Chief People Officer.

### 5. Build the employee dimension, without the sensitive fields

The employee dimension has one row per person ever employed, with their **latest** assignment. Sensitive fields go in a separate table that you'll lock down later.

```sql
CREATE OR REPLACE TABLE dim_employee AS
WITH last_assignment AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY effective_from DESC) AS rn
  FROM tema_hr_raw.job_history
)
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS employee_name,
       e.work_email,
       e.hire_date, e.termination_date, e.termination_type, e.termination_reason, e.is_regretted,
       e.employment_type, e.hire_source,
       e.termination_date IS NULL AS is_current_employee,
       a.department_id, a.job_id, a.location_id, a.manager_id
FROM tema_hr_raw.employees e
JOIN last_assignment a ON a.employee_id = e.employee_id AND a.rn = 1;

CREATE OR REPLACE TABLE dim_employee_sensitive AS
SELECT employee_id, date_of_birth, gender, national_id, personal_email, home_postcode
FROM tema_hr_raw.employees;
```

**Your turn.** Decide whether `gender` belongs in `dim_employee` or `dim_employee_sensitive`, and write one sentence in your notes on why. (Here it's in the sensitive table. The pay gap metric in Week 5 then has to deal with that, which is the point.)

### 6. Build the manager dimension

```sql
CREATE OR REPLACE TABLE dim_manager AS
SELECT m.employee_id AS manager_id, m.employee_name AS manager_name,
       j.job_level AS manager_level, m.department_id AS manager_department_id,
       m.is_current_employee AS is_current_manager
FROM dim_employee m
JOIN dim_job j ON j.job_id = m.job_id
WHERE m.employee_id IN (SELECT DISTINCT manager_id FROM tema_hr_raw.job_history WHERE manager_id IS NOT NULL);
```

### 7. Build a date dimension (monthly)

Everything in Tema is reported by month, so a month-grain date table is enough.

```sql
CREATE OR REPLACE TABLE dim_date AS
SELECT last_day(month_start) AS month_end,
       month_start,
       year(month_start) AS year,
       quarter(month_start) AS quarter,
       concat(year(month_start), '-Q', quarter(month_start)) AS year_quarter,
       date_format(month_start, 'MMM yyyy') AS month_label,
       month(month_start) IN (3, 6, 9, 12) AS is_quarter_end
FROM (SELECT explode(sequence(DATE'2023-01-01', DATE'2026-12-01', INTERVAL 1 MONTH)) AS month_start);
```

Join to facts on `month_end = snapshot_month`.

### 8. Look at lineage, then commit

Open `dim_employee` in Catalog Explorer, **Lineage** tab. You should see it built from `employees` and `job_history`. Commit the notebook to `week-01`, push, and open a pull request.

## Checkpoint

- [ ] `tema_hr_gold` has 7 tables: `dim_department`, `dim_location`, `dim_job`, `dim_employee`, `dim_employee_sensitive`, `dim_manager`, `dim_date`.
- [ ] `dim_employee` has no date of birth, national ID, personal email, postcode or gender.
- [ ] You can explain the type 2 "as of" pattern without looking.

```sql
-- At 5,000 people expect: 7,207 / 7,207 / 592 / 48 / NULL
SELECT (SELECT COUNT(*) FROM tema_hr_gold.dim_employee)            AS employees,
       (SELECT COUNT(*) FROM tema_hr_gold.dim_employee_sensitive)  AS sensitive_rows,
       (SELECT COUNT(*) FROM tema_hr_gold.dim_manager)             AS managers,
       (SELECT COUNT(*) FROM tema_hr_gold.dim_date)                AS months,
       (SELECT COUNT(*) FROM tema_hr_gold.dim_employee
        GROUP BY employee_id HAVING COUNT(*) > 1 LIMIT 1)          AS duplicate_ids;  -- NULL means none
```

## Why this matters at work

The migration team is probably copying source tables one to one, sensitive columns included. Splitting `dim_employee` from `dim_employee_sensitive` costs nothing at build time and makes every later access decision simpler: most people get the first table, very few get the second. That one pattern is worth suggesting to the rollout team this week.
