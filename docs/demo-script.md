# The 30-minute demo (Week 12, step 4)

Run on the 70,000-person Tema. Every query is in this repo; the SQL editor tab order below keeps you from hunting.

| Min | Show | Say | Where |
|---|---|---|---|
| 0–5 | `SUM(headcount)` from `v_headcount_naive` for 2025-Q2 (175,524), then `MEASURE(headcount)` from `workforce_metrics` (58,862) | "Same table, same question. The definition decides, not the person typing." | `metrics/checks/workforce_checks.sql` |
| 5–10 | Attrition by division in one short query, then the attrition entry in the definitions doc, then the Week 10 pull request | "Every choice has an owner and a review, and the code and the definition change together." | `metrics/checks/attrition_truth.sql`, `docs/metric-definitions.md` |
| 10–17 | The same three questions to the raw-table Genie and the People Analytics Assistant (Q2 headcount, attrition, an individual's salary), then the score | "AI is only as good as the definitions under it." | `genie/benchmark_questions.md` |
| 17–24 | Act as an HRBP covering two divisions, the second HRBP of a shared VP, and a manager; end one assignment | "One rule in Unity Catalog. Every tool gets the same answer about who can see what." | `governance/02_hrbp_access_activity.sql` |
| 24–30 | The proposal: value table, 90-day plan, asks | "It builds on the migration; it doesn't compete with it." | `docs/pilot-proposal.md` |

**Before you present:** rerun `reference/00_build_reference` and the governance model on the 70,000-person data the same day (HRBP scope uses today's date), open each tab, and run every query once so the warehouse is warm. Keep the Workforce Overview dashboard open as the fallback if a live query is slow.

**Likely questions:** "Can't Power BI do this?" (it can for its own users; this works for SQL, Genie and every BI tool at once). "Who maintains it?" (metric owners via pull requests; one engineer part-time). "Is it safe to point AI at HR data?" (only through governed metrics with suppression, which is what the demo shows).

Shorter versions (30 seconds, 2 minutes, 5 minutes) built on Gap Selling are in [demo-scripts-gap-selling.md](demo-scripts-gap-selling.md).
