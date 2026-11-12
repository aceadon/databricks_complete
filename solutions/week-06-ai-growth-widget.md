# Week 6 answer key: the AI growth widget

**Activity:** Week 6, step 3. Add one more widget that tells the AI growth story: AI headcount by month next to AI regretted attrition.

## The widget

| Setting | Value |
|---|---|
| Title | **AI: growing fast, losing the people we want to keep** |
| Type | Combo chart (bar + line, two y-axes). If your release has no combo chart, use two charts side by side with the same x-axis |
| x-axis | `month`, from Jan 2023 to Oct 2026 |
| Bars (left axis) | `MEASURE(headcount)` from `workforce_metrics`, filtered `division = 'AI'` |
| Line (right axis) | `MEASURE(regretted_attrition_rate_t12m)` from `retention_metrics`, filtered `division = 'AI'`, formatted as a percentage |
| Annotation | A vertical marker or text box at **May 2025**: "AI boom begins" |
| Filters | Don't connect the global Division filter to this widget, because it's fixed to AI. Do connect the Month filter if you want a date range |

A combo chart needs both measures in one dataset. Because the measures live in two metric views, either:

1. **Two datasets, two charts side by side.** This is simplest and keeps both datasets as pure metric views (the rule from step 2).
2. **One SQL dataset that joins the two metric views on `month`.** It's still built only on metric views, not gold tables:

```sql
SELECT w.month, w.ai_headcount, r.ai_regretted_attrition
FROM (SELECT month, MEASURE(headcount) AS ai_headcount
      FROM workspace.tema_hr_semantic.workforce_metrics
      WHERE division = 'AI' GROUP BY ALL) w
JOIN (SELECT month, MEASURE(regretted_attrition_rate_t12m) AS ai_regretted_attrition
      FROM workspace.tema_hr_semantic.retention_metrics
      WHERE division = 'AI' GROUP BY ALL) r USING (month)
ORDER BY month;
```

## What you should see (5,000 people)

| Month | AI headcount | AI regretted attrition (T12M) |
|---|---|---|
| Jan 2023 | 101 | 0.0% |
| Jan 2024 | 98 | 2.0% |
| Jan 2025 | 107 | 4.0% |
| Apr 2025 | 99 | 4.0% |
| Oct 2025 | 205 | 8.6% |
| Apr 2026 | 368 | 9.5% |
| Oct 2026 | **674** | **10.2%** (rest of Tema: 3.7%) |

Headcount is flat around 100 until April 2025, then grows almost sevenfold in 18 months. Regretted attrition climbs alongside it, to nearly three times the rest of the company.

## Things to check

- **The bars must show month-end headcount.** If the month filter is set to a quarter, each bar should be the quarter-end value, not a sum.
- **Early values look noisy.** A trailing 12-month rate on a team of about 100 moves in whole people, which is why it jumps between 0%, 1%, 2% and 3% early on. Say so in the widget description, or start the x-axis in 2024.
- **The story sentence for a VP:** "AI grew from about 100 to 674 people since May 2025, but one in ten AI employees we wanted to keep left in the last year, nearly three times the rate in the rest of Tema."
