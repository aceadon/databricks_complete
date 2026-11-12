# Week 7: Genie and the benchmark

**Phase 3** · about 6 hours

## Goal

Measure, with a number, how much the semantic layer improves AI answers. Build a Genie Agent on raw tables and another on your metric views, ask both the same 20 questions, and score them. This before-and-after score is the strongest single argument you'll take to work.

## Before you start

- Weeks 3 to 6 done.
- [`hr_people_analytics/genie/benchmark_questions.md`](../hr_people_analytics/genie/benchmark_questions.md) open; it has 10 questions to start from.
- A branch `week-07`.

## Learn (about 1 hour)

Databricks docs for **Genie Agents** (formerly Genie Spaces): data sources, instructions, example SQL queries, trusted assets, benchmarks, and the knowledge store. Skim **Genie One** and **Databricks One** for the business-user view. The project eBook *Building Genie One on Databricks* is good background, and *Context Engineering on Databricks* explains why definitions improve answers.

## Steps

### 1. Fill in the expected answers first

Before Genie sees anything, complete the **Expected answer** column for all 20 questions using your metric views or truth queries. Add questions 11 to 20 yourself. Good ones to add:

- "How many people joined in 2026 so far?" (1,126)
- "What's the AI team's regretted attrition?" (about 10.2% trailing 12 months)
- "Which division has the lowest eNPS?"
- "How many open requisitions do we have?" (79)
- One question that should be **refused**, like "What's Priya Patel's salary?"
- One with a trap, like "Average headcount last year" (average of month ends, not a sum).

Save the file. Without expected answers decided in advance, it's too easy to accept a plausible wrong answer.

### 2. Genie Agent A: raw tables only

Create a Genie Agent called **Tema raw (baseline)** with all 12 `tema_hr_raw` tables and no instructions. Ask all 20 questions in a fresh conversation each time. Record correct / wrong / partly in the **Raw tables** column, and note *how* it went wrong (summed months, wrong attrition denominator, joined on the wrong date).

### 3. Genie Agent B: the semantic layer

Create **People Analytics Assistant** with your metric views as data sources (plus `dim_employee` if you want names). Then add:

**Instructions** (save the text in `hr_people_analytics/genie/instructions.md`):

```text
You answer questions about Tema's workforce. Tema is a fictional company; all data is synthetic.
- Use the metric views in tema_hr_semantic first. Only use tables if no metric fits.
- "Attrition" means attrition_rate_t12m (trailing 12 months, all leavers) unless the user says voluntary, regretted or first-year.
- "Headcount" for a quarter or year means the value at the end of the period, never a sum of months.
- Never show a breakdown of salary, compa-ratio, rating or engagement for a group of fewer than 5 people. Say the group is too small.
- Never return an individual's salary, date of birth, national ID or equity.
- The AI boom started in May 2025. "Since the AI boom" means from 2025-05-01.
```

**Example SQL**: add three trusted queries, for example the quarterly headcount query from Week 3 and the attrition-by-division query from Week 4.

Run the 20 questions again and fill in the **Semantic layer** column.

> [!WARNING]
> **Untested in Databricks.** Genie Agent features (benchmarks, knowledge store, metric view sources) move quickly. If metric views can't be added as a source in your workspace, add the gold tables with their comments instead and note the difference. Free Edition may cap Genie usage; spread the runs over two sessions if you hit a limit.

### 4. Use Genie's built-in benchmarks

Add your 20 questions and expected SQL as **benchmarks** in Agent B and run them. Compare its scoring with yours.

### 5. Improve, then rerun

Pick the three questions Agent B still got wrong. For each, decide the fix: a better metric or dimension, a synonym, an instruction, or an example query. Make the fix *in the semantic layer* where possible (it then helps dashboards and BI tools too), not only in Genie. Rerun and record the new score.

### 6. Try agent mode

Ask Agent B: "Why did attrition rise in Trust & Safety?" Watch how it breaks the question into steps. Judge whether its reasoning is sound.

### 7. Commit

Commit the completed benchmark sheet and `instructions.md`, then open a pull request.

## Checkpoint

- [ ] 20 questions with expected answers decided before running Genie.
- [ ] A score for each: raw tables __ / 20, semantic layer __ / 20, and after fixes __ / 20.
- [ ] Agent B refuses the individual salary question and handles the small-group rule.
- [ ] Question 1 ("headcount at the end of Q2 2025") is right in B (4,176) and you know what A said.

## Why this matters at work

Leaders are being promised AI that answers questions about the business. Your benchmark shows that the answers depend on the definitions underneath, and puts a number on it. Turn this into a **three-slide story**: the question an HR business partner asked, the confident wrong answer from raw tables, and the right answer from governed metrics, with the score. It's the clearest way to show the rollout team that moving tables is necessary but not enough.
