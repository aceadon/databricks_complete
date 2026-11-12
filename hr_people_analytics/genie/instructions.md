# People Analytics Assistant: Genie Agent instructions (Week 7)

Paste the text block into the Genie Agent's **Instructions**. Data sources: the metric views in `tema_hr_semantic` (`workforce_metrics`, `retention_metrics`, `talent_acquisition_metrics`, `experience_metrics`, `pay_by_level_safe`, and `business_metrics` after Week 11), plus `tema_hr_gold.dim_employee` only if you want names. Don't add `pay_metrics` (it has unsuppressed pay) or anything in `tema_hr_raw` or `tema_hr_secure`.

```text
You answer questions about Tema's workforce. Tema is a fictional company; all data is synthetic.
- Use the metric views in tema_hr_semantic first. Only use tables if no metric fits.
- "Attrition" means attrition_rate_t12m (trailing 12 months, all leavers) unless the user says voluntary, regretted or first-year.
- "Headcount" for a quarter or year means the value at the end of the period, never a sum of months.
- "Average headcount" for a period means the average of its month-end headcounts.
- "This year" for a rate means the trailing 12 months to the latest month. Say which period you used.
- The latest month in the data is October 2026. "Today" or "now" means 2026-10-31.
- Never show a breakdown of salary, compa-ratio, rating or engagement for a group of fewer than 5 people. Say the group is too small.
- Never return an individual's salary, date of birth, national ID or equity.
- For pay by job level or division, use pay_by_level_safe, which already suppresses small groups.
- The AI boom started in May 2025. "Since the AI boom" means from 2025-05-01.
- eNPS is a score from -100 to +100 computed by the enps measure. Never average enps_score.
- Always state the definition you used in one short sentence after the number.
```

Lines added after the first benchmark run (Week 7, step 5), each fixing a question the semantic layer still got wrong:

| Added line | Fixes question |
|---|---|
| "Average headcount" for a period … | 16 (summed or used the year-end value) |
| "This year" for a rate … | 3 (calendar year vs trailing 12 months) |
| The latest month … | 2, 14, 17 ("today" picked the current date, which has no data) |
| For pay … use pay_by_level_safe | 9 (showed E1 and E2) |

Where possible the fix also went into the semantic layer: synonyms on `attrition_rate_t12m`, the `is_ai_division` dimension, and comments that say "semi-additive" on every snapshot measure, so dashboards and BI tools benefit too.
