# Demo scripts: why HR needs a semantic layer

Four lengths of the same story, so you can match it to the time someone gives you. Each one follows Keenan's **Gap Selling**, and each longer tier adds proof to the shorter one rather than starting over.

| Tier | When you use it | What they leave with | Live screens |
|---|---|---|---|
| **1. The 30-second spiel** | Hallway, start of a meeting, "what are you working on?" | One problem they recognise and a question they want answered | None |
| **2. The 2-minute proof** | "Show me" on a laptop, end of a 1:1 | Proof that the problem is real, on our own kind of data | 1 query, 2 results |
| **3. The 5-minute walk-through** | A slot in a team meeting, a skip-level, a curious VP | The three gaps (numbers, AI, access) and what closes them | 3 proofs |
| **4. The 30-minute demo** | A scheduled session with sponsors | A decision on the pilot | [demo-script.md](demo-script.md) and [pilot-proposal.md](pilot-proposal.md) |

All numbers are from **Tema** (fictional, 70,000 people, data to October 2026). Lines in [brackets] are for your own company's numbers: get them in discovery, because a gap is only convincing when it's the listener's own gap.

## How Gap Selling shapes these scripts

Keenan's argument is that people don't buy products, they buy a change from where they are to somewhere better. The seller's job is to understand both places in detail; the distance between them, **the gap**, is the value. A few of his rules decide how the scripts are written:

- **Current state** has five parts: the **environment** (how things work today), the **problems**, their **impact** (in time, money and risk), the **root cause**, and the **emotion** (how it feels to the person living it).
- **Future state** is what it looks like when the problem is solved, in the listener's terms, with the impact reversed.
- **"Never sell to need."** Problems get you to impact, and impact is where urgency lives. "We need a semantic layer" persuades no one; "we spent two days reconciling headcount before the board meeting" does.
- **Lead with the problem, not the product.** The phrase "semantic layer" appears late in every script below, after the listener has agreed there's a problem.
- **Show few features, each tied to a problem.** Keenan suggests no more than about six in a demo, and asking after each one whether it solves the problem you just discussed. The 5-minute tier shows three.
- **Discovery never stops.** Each tier ends with a question, because the listener's answer is what turns Tema's gap into theirs.
- **Root cause is where you earn the right to propose.** Here the root cause is the same for every audience: *the migration moves tables, but the meaning of the numbers and the rules about who sees what don't move with them.* No amount of table migration fixes that.

## The problem identification chart

Keenan has teams build this before any conversation: the problems the solution solves, the impact of each, and the root cause. Pick the rows that match the person in front of you.

| Who | Problem | Impact | Root cause |
|---|---|---|---|
| **CPO, HR leadership** | Leaders get different headcount and attrition numbers for the same question | Every review opens with reconciliation; decisions wait; HR's credibility with the exec team suffers | Each report or analyst picks a definition silently; nothing is certified or owned |
| **CPO, Finance partner** | Nobody can say what attrition costs | At Tema, regretted attrition is about **$190M a year** at half a year's salary per leaver, and nobody had the number. [Ours: ____] | Attrition is defined differently by every team, so it can't be costed consistently |
| **HR operations, People Analytics** | The same questions arrive as tickets again and again, each answered by hand | Days per answer; analysts spend their time re-deriving known numbers instead of analysis | Logic lives in individual queries, dashboards and spreadsheets, not in one shared place |
| **HRBPs** | They wait for reports, or get numbers that don't match the dashboard their VP saw | Slow, defensive conversations with leaders; workarounds in spreadsheets | No self-serve, trusted source; definitions differ between tools |
| **HRBPs, Security, Legal** | Sensitive data access (salary, birthdays, equity) is managed by tool settings and a coverage spreadsheet | Access is wrong after every reorg or handover: either too broad (exposure risk) or too narrow (HRBPs blocked) | The rule "an HRBP sees their leaders' whole org" isn't written anywhere a system can enforce |
| **Anyone excited about AI (Genie)** | AI on raw HR tables answers confidently and wrongly, and can show individual pay | Wrong numbers in front of leaders, or a privacy incident; AI gets banned from HR data | The AI has tables but no definitions and no rules, the same gap the humans have |
| **Data platform, migration team** | "Done" means the table landed; HR still doesn't trust or use it | Low adoption of the platform being paid for; HR keeps its old tools | The rollout scope stops at tables; nobody owns definitions or access by HR role |

**The emotion, so you can name it:** the dread of a VP asking "why does your number differ from Finance's?", the worry of an HRBP who isn't sure whether they're allowed to see a salary, the fatigue of answering the same ticket for the fifth time.

---

## Tier 1: the 30-second spiel

No screen. Say it, then ask the question and stop talking.

> **(Current state)** We're moving all our HR data to Databricks, which is great, but the rollout only moves tables.
>
> **(Problem and impact)** The tables arrive without their meaning. Ask "what was our headcount at the end of Q2?" of the same migrated table and you can get 58,862 or 175,524, depending on who writes the query. Attrition has five versions. And the rule about which HRBP can see whose salary lives in a spreadsheet.
>
> **(Future state)** What I've built is a thin layer on top, a semantic layer: every HR metric defined once, with an owner, and the access rules defined once, so Tableau dashboards, SQL queries and AI agents all give the same answer and respect the same privacy rules.
>
> **(Gap, as a question)** How much time does your team spend reconciling numbers before a leadership review?

**If you only have one sentence:** "The migration moves our HR tables; I'm making sure they mean the same thing everywhere, and that only the right people see the sensitive parts."

**Why it's built this way.** The 58,862 vs 175,524 contrast is the anchor: it's concrete, a little absurd, and the listener can see the cause without knowing SQL (someone added up three months). The question at the end hands the conversation back so you learn their current state, which is the point of Gap Selling.

---

## Tier 2: the 2-minute proof

One query tab open in the SQL editor: [`metrics/checks/workforce_checks.sql`](../hr_people_analytics/metrics/checks/workforce_checks.sql), the naive and the metric view headcount for 2025-Q2. Speak for 30 seconds, show for 60, close for 30.

**0:00 to 0:30. Current state and problem (no screen yet)**

> "Our Databricks rollout is moving HR's tables across. What it doesn't move is the definitions: what counts as headcount, what counts as attrition, who's allowed to see salary. Today each of those lives in somebody's query or somebody's spreadsheet. Can I show you what that means in 60 seconds? This is a fake company, Tema, 70,000 people, about our size."

**0:30 to 1:30. The proof**

1. Run the naive query. "Headcount at the end of Q2 2025, straight from the migrated table: **175,524**. For a company of 70,000."
2. "That's what happens when someone adds up April, May and June. Perfectly reasonable query, wrong answer, and nothing warns you."
3. Run the metric view query. "Same table, same question, through the semantic layer: **58,862**. The rule 'headcount is the last month of the period, never a sum' lives in the definition, so nobody can get it wrong, in SQL, on a dashboard, or with an AI agent."
4. **Anchor (Keenan's check):** "Has a number like the first one ever reached a leadership deck here?"

**1:30 to 2:00. Impact, future state and the ask**

> "Headcount is the easy one. Attrition is where it costs money: at Tema, once attrition had one definition, we could finally see that regretted leavers cost about **$190 million a year**. That's the future state: one certified definition per metric with a named owner, one access rule, and every tool, including AI, reading from it. The migration is the foundation; this is the part that makes HR trust it. Could I get 30 minutes with you and [the person who owns HR reporting] to see if this would work here?"

**If they want one more thing:** show the attrition entry in [metric-definitions.md](metric-definitions.md). "This is what 'certified' means: a plain-language definition, a formula, an owner, and what's deliberately excluded."

---

## Tier 3: the 5-minute walk-through

Three proofs, each tied to one problem from the chart. Open these tabs first, in this order:

1. [`metrics/checks/workforce_checks.sql`](../hr_people_analytics/metrics/checks/workforce_checks.sql) (headcount, naive vs metric view)
2. The Genie agent on raw tables and the **People Analytics Assistant** on the metric views, side by side (questions from [`genie/benchmark_questions.md`](../hr_people_analytics/genie/benchmark_questions.md))
3. [`governance/02_hrbp_access_activity.sql`](../hr_people_analytics/governance/02_hrbp_access_activity.sql) (act-as personas)
4. Fallback: the **Workforce Overview** dashboard, if anything is slow

**0:00 to 0:45. Current state: environment, root cause, emotion**

> "Quick context. We're rolling out Databricks, and the plan is to move our HR tables there. That's necessary, but it's only the first half. Three things don't move with the tables: what our numbers *mean*, what AI is allowed to *answer*, and who's allowed to *see* sensitive people data. Today those live in individual queries, BI-tool settings and a coverage spreadsheet. So we reconcile numbers before reviews, we're nervous about pointing AI at HR data, and HRBP access breaks at every reorg. I built a working version of the fix on a fake 70,000-person company called Tema. Three things, five minutes."

**0:45 to 2:00. Gap 1: the numbers don't agree (HR leadership, HR ops)**

- Run the naive headcount (175,524), then the metric view (58,862). "Same table, same question."
- "Every metric now has one definition with an owner: headcount, hires, leavers, attrition, time to fill, pay, engagement. Fifteen-plus KPIs across five areas."
- "And because attrition now means one thing, we can cost it. Tema lost **2,782 regretted leavers** in the last 12 months: about **$190M a year** to replace at half a salary each. AI alone, the team that grew about sixfold, is **503 regretted leavers, about $67M**."
- **Anchor:** "If we had one attrition number we trusted, what's the first decision you'd use it for?"

**2:00 to 3:15. Gap 2: AI gives confident wrong answers (anyone excited about Genie)**

Ask both agents the same two questions:

1. "How many people did we have at the end of Q2 2025?" The raw-table agent tends to sum the months; the assistant answers 58,862.
2. "What's [a named employee]'s salary?" The assistant refuses and says why; the raw one may not.

> "Same AI, same data. The difference is the definitions and rules underneath. On a 20-question benchmark, the raw-table agent scored [__ / 20] and the one on the semantic layer scored [__ / 20]. AI is only as good as the definitions under it, and the semantic layer is what makes it safe to give HR an AI assistant."

- **Anchor:** "Is anyone here already asking for AI on HR data? What's stopping it?"

**3:15 to 4:15. Gap 3: access to sensitive data doesn't follow the org (HRBPs, Security, Legal)**

Act as three people with the same query:

1. **An HRBP who covers two leaders in different divisions:** sees salary and birthdays for everyone in both leaders' whole orgs, and names and titles only for everyone else.
2. **A manager:** sees their direct reports' birthdays, no salary.
3. **End one HRBP assignment** and rebuild: that access disappears, with no tickets and no grant changes.

> "One rule in Unity Catalog: 'an HRBP sees sensitive data for the recursive orgs of the leaders they currently support.' It's computed from the reporting lines and dated assignments, handles HRBPs with several leaders and leaders with several HRBPs, keeps executives out, and applies the same way in SQL, dashboards, BI tools and Genie. Reorgs fix themselves overnight."

- **Anchor:** "How do we handle HRBP access after a reorg today?"

**4:15 to 5:00. Future state, the gap and the ask**

> "So here's the gap. Today: tables arriving in Databricks, definitions in people's heads, access in a spreadsheet, AI off-limits. Future state: every HR number certified once and the same everywhere, sensitive data governed by one auditable rule, definitions changed only by reviewed pull request, and an AI assistant HRBPs can actually use. It doesn't compete with the migration. It reuses the migrated tables and adds a thin layer on top, and it gives the migration team a definition of 'done'. The ask is a 90-day pilot on people analytics: an HR sponsor, a named HR data owner, and about a day a week from one data engineer. Who else should see this?"

---

## Tier 4: the 30-minute demo

Use [demo-script.md](demo-script.md) minute by minute, and leave with [pilot-proposal.md](pilot-proposal.md). The 5-minute tier is its skeleton: the 30-minute version adds the definitions doc and the Week 10 pull request (metrics as code), the full benchmark score, more personas, and the value table and 90-day plan. Before you run it, fill the [brackets] in both documents with what you learned in the shorter conversations.

---

## Discovery questions: turning Tema's gap into ours

Gap Selling only works when the current state is the listener's, not Tema's. Use these after Tier 1 or 2, and write the answers into the [brackets] above and into the pilot proposal's value table. Keenan's question types are in brackets.

**Environment and process** [process]
- "Walk me through how a headcount number gets into a leadership deck today."
- "When an HRBP needs salary data for their org, how do they get it, and who decides?"
- "What happens to HRBP access when a leader's org moves?"

**Problems and impact** [probing, provoking]
- "How many versions of attrition do we have? Who'd know?"
- "How long does a new people question take to answer, from ask to trusted number?"
- "When two numbers disagreed in a review, what happened next? What did it cost in time, or in trust?"
- "Do we know what regretted attrition costs us? What replacement cost would Finance accept?"
- "Has sensitive data ever gone to the wrong person, or been withheld from the right one?"

**Root cause** [probing]
- "Who owns the definition of headcount today? Is it written down?"
- "Is the migration's scope tables only, or does it include definitions and access rules?"

**Future state** [validating]
- "If every HR number matched everywhere, what would you stop doing?"
- "What would make you comfortable letting HRBPs ask an AI assistant about their org?"
- "So if I've understood: [restate their gap]. Is that right?"

---

## Adjusting for the audience

| Audience | Lead with | Use the proofs | Their words for the future state |
|---|---|---|---|
| CPO, HR leadership | The cost of attrition, numbers leaders trust | 1, then the dollar figure | "Walk into every exec review with one number" |
| HR operations, People Analytics | Repeat tickets, hand-built answers | 1 and 2 | "Answer once, reuse everywhere; analysts do analysis" |
| HRBPs | Waiting for reports, access after reorgs | 3, then 2 | "Self-serve answers for your orgs, safely" |
| Security, Legal, Privacy | Exposure risk, audit | 3, small-group suppression | "One rule, enforced and audited in one place" |
| Data platform, migration team | Adoption, a definition of "done" | 1, metrics as code | "HR actually uses what you migrated" |
| Execs outside HR | Speed and trust | Tier 1 only | "HR numbers you don't have to question" |

## Quick answers to common pushback

- **"Can't Tableau do this?"** For its own users, yes. This defines the metric once for SQL, dashboards, every BI tool and AI at the same time, so they can't drift apart.
- **"Isn't this the migration team's job?"** Their scope is moving tables, and they're doing it. This sits on top and gives them a checklist for what a finished HR table looks like.
- **"Who maintains it?"** Metric owners in HR, through reviewed pull requests; about a day a week of one engineer during the pilot.
- **"Is it safe to point AI at HR data?"** Only through governed metrics with access rules and small-group suppression, which is exactly what proof 2 and 3 show.
- **"Is this real data?"** No. Tema is synthetic and was built at our scale on purpose. Real data only goes in once HR, Legal and Security have agreed the access model.

## Before any tier

- Rebuild the reference and governance model on the 70,000-person data the same day (HRBP scope uses today's date), and run each query once so the warehouse is warm. See [demo-script.md](demo-script.md).
- Pick the employee for the salary question in advance, and the HRBP and manager personas from `02_hrbp_access_activity.sql`.
- Fill in the benchmark score from your Week 7 run.
- Practise Tier 1 out loud until it's under 30 seconds. Then stop talking after the question.

## Sources on Gap Selling

- Keenan, *Gap Selling: Getting the Customer to Yes* (2018).
- [Gap Selling: everything you need to know](https://builtin.com/articles/gap-selling) (Built In): current state, future state and the problem identification chart.
- [Gap selling](https://www.gong.io/blog/gap-selling) (Gong): "never sell to need", the five parts of the current state, and keeping demos to a few features tied to problems.
