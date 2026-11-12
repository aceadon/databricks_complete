# Week 12: Capstone: the pilot proposal

**Phase 6** · about 6 hours, then ongoing

## Goal

Turn twelve weeks of Tema into a proposal your company can say yes to: a semantic layer workstream alongside the table migration, starting with one domain, with a demo and numbers to back it.

## Before you start

- Everything from Weeks 0 to 11, especially the Genie benchmark score (Week 7) and the governance model (Weeks 8 and 9).
- [docs/pilot-proposal.md](../docs/pilot-proposal.md) open.
- A branch `week-12`.

## Steps

### 1. Pick the first domain

Score two or three candidate domains at your company from 1 to 5 on each:

| | People analytics | Finance | Operations / other |
|---|---|---|---|
| Visible pain (conflicting numbers, slow answers) | | | |
| A sponsor who'd champion it | | | |
| Data already migrated or migrating | | | |
| Governance difficulty | | | |
| How many leaders would notice | | | |

People analytics is a strong choice if HR will sponsor it, because headcount and attrition disagreements are universal. Write down why you chose what you chose.

### 2. Gather your numbers

Fill in what you can, from Tema and from what you know of your company:

- **Genie accuracy**: raw tables __ / 20, semantic layer __ / 20 (Week 7).
- **Time to answer**: how long does a new people question take today (ask an HRBP)? How long did it take on Tema with the metric views?
- **Conflicting definitions**: how many versions of headcount or attrition exist today? (Ask around; it's usually more than three.)
- **Cost of attrition you can now see**: leavers × replacement cost. On Tema at 70,000 people, run `MEASURE(leavers_t12m)` and use your company's own replacement-cost figure (often quoted as a significant share of annual salary).
- **Consolidation**: dashboards, spreadsheets or BI models that could be retired.

### 3. Write the proposal

Complete [docs/pilot-proposal.md](../docs/pilot-proposal.md). Keep it to two pages:

1. **The problem**, in your company's words, with one real example.
2. **What we showed**: the Tema demo and the benchmark score.
3. **Value**: the table from step 2.
4. **The proposal**: first domain, owners, and a 90-day plan (for example: weeks 1–4 gold tables and definitions for 5 metrics; weeks 5–8 metric views, dashboard and Genie Agent; weeks 9–12 governance, certification and adoption tracking).
5. **How it complements the migration**: the migration moves tables; this makes them mean something. It reuses their work and adds a thin layer on top.
6. **Asks**: a sponsor, an HR data owner, a few hours a week from a data engineer, and access rules agreed with HR, Legal and Security.

### 4. Build the 30-minute demo

Plan a demo you could run for the migration team or an HR leadership group:

| Minutes | Show | Point |
|---|---|---|
| 0–5 | The naive Q2 headcount (12,429) vs the metric view (4,176) | Definitions belong in one place |
| 5–10 | Attrition by division from one short query, and the definitions doc | Agreed meaning, owned and reviewable |
| 10–17 | Genie on raw tables vs Genie on the semantic layer, and the score | AI is only as good as the definitions |
| 17–24 | Acting as two HRBPs and a manager | One rule, enforced everywhere |
| 24–30 | The proposal and the asks | What we'd do next, and what it costs |

Rehearse it once end to end on the 70,000-person Tema.

### 5. Prepare the giveaways

Three things the migration team can adopt at almost no cost:

- The [gold table checklist](../docs/gold-table-checklist.md).
- The metric definition template from [docs/metric-definitions.md](../docs/metric-definitions.md).
- The sensitive-data pattern: split sensitive columns into their own table, tag them, and mask by policy.

### 6. Close out the plan

Tick the progress tracker in the [plan](../plan/zero-to-semantic-hero.md#progress-tracker), commit the proposal, and merge.

## Checkpoint

- [ ] A two-page proposal with a chosen domain, numbers, a 90-day plan and clear asks.
- [ ] A rehearsed 30-minute demo.
- [ ] Three giveaways ready to share.
- [ ] A date in the diary to present it.

## Champion habits (beyond week 12)

- Run the "one headcount number" demo for the migration team and for one HR or business team.
- Start a small metrics council with business owners for the first domain; proposals are pull requests.
- Keep watching the Databricks release notes monthly. Several features you used were in preview; when they go GA, that's a reason to revisit.

## Why this matters at work

You started with a rollout focused on moving tables. You now have a working example, a measured improvement, a governance model your HR team will recognise, and a plan that costs little and builds on the migration rather than competing with it. That's what makes you the person at your company who knows how to turn Databricks tables into trusted business meaning.
