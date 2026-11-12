# Week 8: HRBP access model

**Phase 4** · about 6 hours · the governance centrepiece

## Goal

Show, acting as different people, that an HR business partner (HRBP) sees salaries, birthdays and equity **only for the organisations of the leaders they support**, even when one HRBP covers several leaders across divisions and one leader has two HRBPs, and that access ends the moment an assignment ends.

This is the problem your company has today. Read the [governance README](../hr_people_analytics/governance/README.md) before you start; it explains the model and has the "what each persona sees" table you'll be testing against.

## Before you start

- Week 0 done (the governance scripts read `tema_hr_raw`, so they don't depend on Weeks 1 to 7).
- A branch `week-08`.

## Learn (about 1.5 hours)

Databricks docs: **row filters and column masks**, **ABAC policies**, `current_user()` and `is_account_group_member()`, and recursive CTEs (`WITH RECURSIVE`). For each, answer: does it apply to the table owner? (Masks and filters do, which is what makes this lab work in a one-person workspace.)

## Steps

### 1. Sketch the problem on paper

Before running anything, draw a small org: a VP with two directors, each with two managers. Put HRBP A on the VP and HRBP B on one director. Answer:

- Who can A see? Who can B see? Who can both see?
- Can A see the VP's own salary? (The model says no: executives are carved out.)
- If the VP's assignment to A ends tomorrow, what should A see?

Keep the sketch; you'll check your answers against the real thing.

### 2. Build the model

Open `hr_people_analytics/governance/01_hrbp_access_model.sql` and run it top to bottom. As each cell runs, read its explanation. It builds, in `tema_hr_secure`:

1. `org_closure`: every (leader, person below them) pair, from a recursive CTE.
2. `hrbp_scope`: who each HRBP covers today, from dated `hrbp_assignments`.
3. `can_see_sensitive()`: the one function every rule calls.
4. Column masks on `employee_profile` and a row filter on `equity_grants`.
5. Tags on every sensitive column.

> [!WARNING]
> **Untested in Databricks.** The scope logic was tested locally in DuckDB, not in Databricks. Likely trouble spots:
> - **Recursive CTE** limits or syntax: Databricks added `WITH RECURSIVE` recently; check you're on serverless or a current SQL warehouse. If it hits a depth or row limit, the org is only about seven levels deep, so a limit of 10 is plenty.
> - **SQL session variables** (`DECLARE VARIABLE`, `SET VAR`) used in the activity: same advice.
> - **Masks referencing another table** (the personas table) inside a function: if Databricks refuses, note the error; it's the part that most needs fixing.

### 3. Work through the activity

Open `02_hrbp_access_activity.sql`. It finds real examples in your data, then has you **act as**:

| Step | Acting as | Look for |
|---|---|---|
| 1 | HR admin | Everything visible: your baseline |
| 2 | An HRBP covering leaders in more than one division | Salaries and birthdays only inside those leaders' organisations; never for the leaders themselves |
| 3 | The second HRBP of a shared leader | Two HRBPs both see one organisation, plus their own other areas |
| 4 | A people manager | Birthday (month and day only) for direct reports, nothing else |
| 5 | An employee | Their own record only |
| 6 | The first HRBP after an assignment ends | Access disappears |
| 7 | The first HRBP, using aggregates | Masks change what "average salary" means |

Run the self-checks after each step. Compare what you see with the persona table in the README and with your paper sketch.

### 4. Your turn: change a policy

Pick one of the built-in policy choices and change it in `can_see_sensitive()` (or the mask functions):

- Let HRBPs see leavers for 90 days after they leave.
- Let HRBPs see the VP they support (remove the executive carve-out).
- Let secondary HRBPs see salary but not national ID.

Rerun the relevant activity step and confirm the change. Notice you changed **one function**, and every mask and filter followed.

### 5. Your turn: the production version

In `docs/people-data-governance-model.md`, fill in the **Roles and what they can see** table for Tema, then add a section **From demo to production** answering:

- What replaces `access_personas`? (Hint: a login-to-employee mapping from the HR system, plus groups like `hr_admins`.)
- What rebuilds `org_closure` and `hrbp_scope`, and how often?
- How would an **ABAC policy** apply the same masks to every column tagged `hr_sensitivity = restricted`, including tables created next year? (The README has a sketch.)

> [!WARNING]
> **Untested in Databricks.** Creating ABAC policies and governed tags may need account-level permissions that Free Edition doesn't have. If so, write the policy SQL in the doc and note it couldn't be run.

### 6. Commit

Commit your policy change and the governance doc, then open a pull request. In the PR description, paste the before-and-after result of your policy change. That's a governance change reviewed like code.

## Checkpoint

- [ ] Acting as HRBP A, salaries are visible exactly for A's scope plus A's own record (the activity's self-check passes).
- [ ] Two HRBPs who share a leader both see that leader's organisation.
- [ ] Neither HRBP sees the leader's own salary.
- [ ] Ending an assignment removes access with no other change.
- [ ] You can explain in two minutes, without notes, why static table or department grants can't do this.

## Why this matters at work

At most companies this rule lives in a reporting tool's security settings, a spreadsheet of who-covers-whom, and someone's memory, and it breaks at every reorg. Putting it in Unity Catalog means **one rule, enforced everywhere**: SQL, dashboards, Genie, notebooks and BI tools all get the same answer about who can see what, and it updates when the HR system does. Bring the [questions for your team](../hr_people_analytics/governance/README.md#questions-to-take-to-your-team) to your HR and Security colleagues; they're the conversation that turns this demo into a pilot.
