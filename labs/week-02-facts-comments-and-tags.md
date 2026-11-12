# Week 2: Fact tables, comments and tags

**Phase 1** · about 5 hours

## Goal

Finish Tema's star schema with the fact tables, then document it well enough that someone who has never seen the data (or Genie) could use it from Catalog Explorer alone, and could tell which columns are sensitive.

## Before you start

- Week 1 done: 7 dimension tables in `tema_hr_gold`.
- A branch `week-02`.

## Steps

### 1. Build the fact tables

Create `hr_people_analytics/gold/02_facts.sql`:

```sql
USE CATALOG workspace;
USE SCHEMA tema_hr_gold;

-- One row per employee per month they were employed. The workhorse for headcount and attrition.
CREATE OR REPLACE TABLE fact_headcount_monthly AS
SELECT h.snapshot_month, h.employee_id, h.department_id, h.job_id, h.location_id, h.manager_id,
       h.annual_base_salary, h.fte, h.tenure_months,
       h.is_active_month_end, h.is_hire_in_month, h.is_termination_in_month,
       h.is_termination_in_month AND e.termination_type = 'Voluntary'      AS is_voluntary_termination_in_month,
       h.is_termination_in_month AND coalesce(e.is_regretted, false)       AS is_regretted_termination_in_month,
       h.tenure_months < 12                                                AS is_first_year,
       e.employment_type
FROM tema_hr_raw.headcount_monthly h
JOIN tema_hr_raw.employees e ON e.employee_id = h.employee_id;

-- One row per leaver.
CREATE OR REPLACE TABLE fact_terminations AS
SELECT employee_id, termination_date, last_day(termination_date) AS termination_month,
       termination_type, termination_reason, is_regretted, hire_date,
       department_id, job_id, location_id, manager_id
FROM dim_employee
WHERE termination_date IS NOT NULL;

-- One row per opened role.
CREATE OR REPLACE TABLE fact_requisitions AS
SELECT r.*,
       CASE WHEN r.status = 'Filled' THEN datediff(r.filled_date, r.opened_date) END AS days_to_fill
FROM tema_hr_raw.requisitions r;

-- One row per survey response, with the respondent's team at the time.
CREATE OR REPLACE TABLE fact_engagement AS
SELECT s.response_id, s.employee_id, s.survey_cycle, s.survey_date, s.enps_score,
       CASE WHEN s.enps_score >= 9 THEN 'Promoter'
            WHEN s.enps_score >= 7 THEN 'Passive' ELSE 'Detractor' END AS enps_category,
       s.engagement_score, s.manager_score, s.wellbeing_score, s.growth_score,
       h.department_id, h.job_id, h.location_id, h.manager_id
FROM tema_hr_raw.engagement_surveys s
LEFT JOIN tema_hr_raw.headcount_monthly h
  ON h.employee_id = s.employee_id AND h.snapshot_month = last_day(s.survey_date);
```

**Your turn.** Write `fact_absences` (one row per absence, with the employee's department at the month the absence started) and `fact_equity_grants` (one row per grant, straight from `equity_grants`). Use `fact_engagement` as your pattern.

<details>
<summary>Answer</summary>

```sql
CREATE OR REPLACE TABLE fact_absences AS
SELECT a.absence_id, a.employee_id, a.start_date, a.end_date, a.absence_type, a.days_absent,
       last_day(a.start_date) AS absence_month,
       h.department_id, h.job_id, h.location_id, h.manager_id
FROM tema_hr_raw.absences a
LEFT JOIN tema_hr_raw.headcount_monthly h
  ON h.employee_id = a.employee_id AND h.snapshot_month = last_day(a.start_date);

CREATE OR REPLACE TABLE fact_equity_grants AS
SELECT grant_id, employee_id, grant_date, grant_type, grant_value_usd, grant_price_usd, shares, vesting_years
FROM tema_hr_raw.equity_grants;
```

</details>

### 2. Declare keys

Keys are informational in Databricks (not enforced), but tools including Genie and BI tools use them to join correctly.

```sql
ALTER TABLE dim_department ALTER COLUMN department_id SET NOT NULL;
ALTER TABLE dim_department ADD CONSTRAINT pk_dim_department PRIMARY KEY (department_id);

ALTER TABLE fact_headcount_monthly ADD CONSTRAINT fk_hc_department
  FOREIGN KEY (department_id) REFERENCES dim_department (department_id);
```

**Your turn.** Add primary keys to every `dim_` table and the foreign keys from `fact_headcount_monthly` to `dim_job`, `dim_location` and `dim_employee`.

> [!WARNING]
> **Untested in Databricks.** If `ADD CONSTRAINT` complains, check the column is `NOT NULL` first and that the table is a Unity Catalog managed table (it should be).

### 3. Write comments, the cheapest semantic layer there is

Start with Databricks: in Catalog Explorer, open `fact_headcount_monthly` and click **AI generate** for the table and column descriptions. Read every one critically. Then fix them in SQL so the fix lives in Git:

```sql
COMMENT ON TABLE fact_headcount_monthly IS
  'One row per employee per month they were employed at any point in that month (month-end snapshot). Use is_active_month_end for headcount. Headcount is semi-additive: add across departments, never across months.';

ALTER TABLE fact_headcount_monthly ALTER COLUMN snapshot_month
  COMMENT 'Last day of the month this row describes. Join to dim_date.month_end.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_active_month_end
  COMMENT 'True if the person was still employed at the end of the month. Use this to count headcount.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN is_termination_in_month
  COMMENT 'True in the month the person left. Leavers count in attrition for this month but not in month-end headcount.';
ALTER TABLE fact_headcount_monthly ALTER COLUMN fte
  COMMENT 'Full-time equivalent: 1.0 for full-time, less for part-time.';
```

**Your turn.** Put comments on every gold table and column in `hr_people_analytics/gold/03_comments_and_tags.sql`. Every table comment should state the **grain** ("one row per..."). Watch for these, which AI comments usually get wrong:

- `is_regretted`: the company wanted to keep this person. Only set for leavers.
- `tenure_months`: months since hire at the snapshot, not time in the current role.
- `days_to_fill`: calendar days from opened to filled; empty for open or cancelled roles.
- `enps_score`: 0 to 10. 9–10 promoters, 7–8 passives, 0–6 detractors.
- `annual_base_salary`: USD, already adjusted for location.

### 4. Tag what's sensitive

```sql
ALTER TABLE fact_headcount_monthly SET TAGS ('domain' = 'people');

ALTER TABLE dim_employee_sensitive SET TAGS ('domain' = 'people', 'hr_sensitivity' = 'restricted');
ALTER TABLE dim_employee_sensitive ALTER COLUMN date_of_birth  SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'date_of_birth');
ALTER TABLE dim_employee_sensitive ALTER COLUMN national_id    SET TAGS ('hr_sensitivity' = 'restricted', 'pii' = 'government_id');
ALTER TABLE fact_headcount_monthly ALTER COLUMN annual_base_salary SET TAGS ('hr_sensitivity' = 'restricted', 'compensation' = 'base_pay');
```

**Your turn.** Tag every table `domain = people`, and tag every personal and pay column (including `gender`, `personal_email`, `home_postcode`, `grant_value_usd`, `shares`). These are the same tag names the Week 8 governance model uses.

> [!WARNING]
> **Untested in Databricks.** Plain tags should work. *Governed* tags (where the allowed values are controlled) may need account-level permissions Free Edition doesn't give you; if `SET TAGS` refuses a key, try a different key name and note what happened.

### 5. The stranger test

Open Catalog Explorer in a private browser window as if you've never seen Tema. Using only table and column descriptions, try to answer: "How would I count leavers in Q1 2026?" and "Where's salary, and am I allowed to use it?" Fix any description that didn't help.

### 6. Fill in the checklist and commit

Work through the [gold table checklist](../docs/gold-table-checklist.md) for `fact_headcount_monthly` and tick what's done. Commit `02_facts.sql`, `03_comments_and_tags.sql` and the checklist, then open a pull request.

## Checkpoint

- [ ] `tema_hr_gold` has 13 tables: 7 dimensions and 6 facts.
- [ ] Every table has a comment that states its grain; no column is missing a comment.
- [ ] Sensitive columns are tagged `hr_sensitivity = restricted`.

```sql
-- At 5,000 people: 195,904 headcount rows; 2,183 terminations; 2,948 requisitions; 23,252 survey responses
SELECT 'fact_headcount_monthly' t, COUNT(*) n FROM tema_hr_gold.fact_headcount_monthly UNION ALL
SELECT 'fact_terminations', COUNT(*) FROM tema_hr_gold.fact_terminations UNION ALL
SELECT 'fact_requisitions', COUNT(*) FROM tema_hr_gold.fact_requisitions UNION ALL
SELECT 'fact_engagement',   COUNT(*) FROM tema_hr_gold.fact_engagement;

-- Columns with no comment (expect 0 rows)
SELECT table_name, column_name FROM workspace.information_schema.columns
WHERE table_schema = 'tema_hr_gold' AND (comment IS NULL OR comment = '');

-- Tagged columns (expect your sensitive columns)
SELECT * FROM workspace.information_schema.column_tags WHERE schema_name = 'tema_hr_gold';
```

## Why this matters at work

Comments and tags look like housekeeping, but they're what Genie, dashboards and every new analyst read first. A table whose comment says "headcount is semi-additive" prevents a whole class of wrong answers before any metric exists. Turn your finished gold table checklist into a half-page you can hand the migration team: "here's what 'done' should mean for a table we migrate."
