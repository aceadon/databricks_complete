# Week 0 answer key: decisions behind "what's our headcount?"

**Activity:** Week 0, step 5. List every decision you had to make to get one headcount number (aim for five or more).

Compare your `plan/notes/week-00.md` with this list. Each decision shows the choice Tema's metric view makes later (Week 3), so you can see where each one ends up being written down.

| # | Decision | Options | Tema's choice | Why it matters (5,000-person data) |
|---|---|---|---|---|
| 1 | **As of when?** | Month end, a specific day, today, average over the period | Month end (`snapshot_month`) | Headcount is a stock, not a flow. You need a point in time. |
| 2 | **Do people who left during the month count?** | Count everyone in the snapshot, or only people still employed at month end | Only `is_active_month_end` | Query A (5,065) counts the 41 October leavers; query B (5,024) doesn't. |
| 3 | **People or FTE?** | Count people (part-timers = 1) or sum FTE | Both, as two separate metrics | Query C gives a lower number because part-timers count as 0.5 to 0.8. Cost and capacity questions want FTE. |
| 4 | **What does a quarter or year mean?** | Last month of the period, average of months, sum of months | Last month (semi-additive) | Query D returns 12,429 for Q2 2025 by adding three months. The right answer is June: 4,176. |
| 5 | **Who counts as an employee?** | Employees only, or also contractors, interns, agency staff | Employees only (Tema has no contractors in this data) | At a real company this is often the biggest gap between HR and Finance numbers. |
| 6 | **Which department for a mid-month transfer?** | Department at month end, at start, or split | Department at month end (or on the last day for a leaver) | Department totals must add up to the company total, so each person sits in one place. |
| 7 | **Counting rows or people?** | `COUNT(*)` or `COUNT(DISTINCT employee_id)` | Distinct people | Safe even if a source ever has two rows for one person in a month. |
| 8 | **Do new hires count in their first month?** | Count from hire date, or from the first full month | From hire date: someone hired on 20 October is in October's headcount | Changes month-on-month growth during hiring surges, like the AI boom. |
| 9 | **People on long leave?** | Count them, or treat as inactive | Count them (still employed) | Parental leave can last months; excluding it understates headcount and skews diversity numbers. |
| 10 | **Which date fields are trusted?** | Hire date, start date, system load date | `hire_date` and `termination_date` from the HR record | Backdated terminations can change past months' numbers when data is reloaded. |

## The point

You didn't need any new data to get five different "correct" headcounts, only different choices. Every choice above becomes a line in the Week 3 metric view (`is_active_month_end`, `semiadditive: last`, `COUNT(DISTINCT ...)`) or in `docs/metric-definitions.md`. Rows 5, 9 and 10 can't be seen in Tema's data, so they're worth asking your HR data team about at work.
