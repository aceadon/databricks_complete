# Week 5 answer key: the Pay equity entry

**Activity:** Week 5, step 4. Add a **Pay equity** entry to `docs/metric-definitions.md` covering who should see it, at what minimum group size, and whether it belongs in a separate restricted metric view.

There's no single right answer. A strong entry makes each decision explicit and says who signs it off. Here's one you can compare yours with:

---

## Pay equity (gender compa-ratio gap)

| | |
|---|---|
| **Definition** | Difference in average compa-ratio between women and men doing comparable jobs (same job level, and ideally same job family and location) |
| **Owner** | Head of Total Rewards, with Legal sign-off |
| **Formula** | Average compa-ratio (base salary ÷ (band midpoint × location pay factor)) for women minus the same for men, among people active at period end. Report the gap within each job level first, then a headcount-weighted overall gap |
| **Includes** | Full-time and part-time employees (compa-ratio uses the full-time rate, so part-time doesn't distort it) |
| **Excludes** | Executives (E1, E2, and M5 unless the group is large enough), people with gender Undisclosed, and Non-binary employees as a separate group unless it meets the minimum size |
| **Who can see it** | Total Rewards, HR leadership and Legal see the full breakdown. HRBPs see it for their own scope, at or above the minimum group size. Managers and the broad audience see no gender split at all, only the company-level result if leadership chooses to publish it |
| **Minimum group size** | 10 people on **each** side of every comparison (for example at least 10 women and 10 men at IC4 in a division). Smaller groups are suppressed, and so is the next-smallest group in the same breakdown, so nobody can recover a suppressed value by subtraction |
| **Metric view** | A separate restricted view, `tema_hr_secure.pay_equity_metrics`, joining `dim_employee_sensitive` for gender. Not in `pay_metrics`, because adding gender there would let anyone with pay access slice by gender down to tiny groups |
| **Status** | Draft. Needs Total Rewards and Legal approval before certification |
| **Caveats** | At 5,000 people the raw gap is about 1.02 (women) vs 1.05 (men). A gap inside the same level is what the planted data shows; a gap across levels (fewer women in senior jobs) is a different problem and needs a different metric. Pay equity analysis can be legally privileged at some companies, so check with Legal before building a dashboard |

---

## Why each choice

- **A separate restricted view.** Access is granted per object in Unity Catalog. Putting gender in its own view means the grant on that view is the policy, and nobody gets it by accident through `pay_metrics`.
- **A higher threshold than Week 9's 5.** Pay by gender is more sensitive than headcount by department, and a comparison has two groups that both need protecting.
- **Suppress the next-smallest group as well.** Without this, a division total minus every shown level reveals the hidden one (the Week 9 subtraction problem).
- **Owner plus Legal.** Pay equity numbers can end up in regulatory reports (for example UK gender pay gap reporting, or the EU Pay Transparency Directive). The definition has to match what the company would publish.
