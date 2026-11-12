# Week 0 notes: what I had to decide to get one headcount number

Reference version of the Week 0 "Your turn" (labs/week-00, step 5). The full table, with why each one matters, is in [solutions/week-00-headcount-decisions.md](../../solutions/week-00-headcount-decisions.md).

Queries at 5,000 people: A (every October row) 5,065 · B (active at month end) 5,024 · C (FTE) lower than B · D (Q2 2025 summed) 12,429.

1. **As of when?** Month end. Headcount is a stock, so it needs a point in time.
2. **Do October leavers count?** No. Only people still employed at month end (`is_active_month_end`). That's the 41-person gap between A and B.
3. **People or FTE?** Both, as two separate metrics. Part-timers count as 1 person, or as their FTE.
4. **What does "Q2 headcount" mean?** The last month of the quarter (June: 4,176), never the sum of three months (12,429).
5. **Who is an employee?** Employees only. Tema has no contractors or interns in this data; my company does, and that's usually the biggest HR vs Finance gap.
6. **Which department for a mid-month transfer?** The department at month end, so departments add up to the total.
7. **Rows or people?** `COUNT(DISTINCT employee_id)`, in case a source ever has two rows for one person in a month.
8. **New hires in their first month?** They count from their hire date.
9. **People on long leave?** Still employed, so they count.
10. **Which dates are trusted?** `hire_date` and `termination_date` from the HR record. Backdated terminations can change past months.

Questions to take to work: 5, 9 and 10 can't be seen in Tema's data.

Genie Code, asked about `is_active_month_end` before any comments existed, guessed from the column name. Its answer sounded right but couldn't say whether leavers on the last day count. That's the gap comments close in Week 2.
