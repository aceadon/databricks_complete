# Week 8 answer key: roles table and "From demo to production"

**Activity:** Week 8, step 5. In `docs/people-data-governance-model.md`, fill in **Roles and what they can see**, then add a section **From demo to production**.

Below is a version you can compare with yours. The roles match what `01_hrbp_access_model.sql` actually enforces. Where a real company would usually choose differently, it says so.

---

## Roles and what they can see

| Role | Scope | Sensitive data |
|---|---|---|
| HR admin | Everyone | Everything: date of birth, full national ID, personal email, home postcode, salary, equity |
| HR business partner | The recursive organisations of every leader they currently support, as Primary or Secondary. VPs and above are excluded, including the leader they support | Inside scope: date of birth, birthday, salary, equity grants, personal email, home postcode, and national ID as the last four characters only. Outside scope: names, titles and teams only |
| People manager | Their direct reports | Birthday (month and day) only. No salary, date of birth, national ID or equity. (Many companies also give managers their team's salaries for pay reviews; Tema's model doesn't) |
| Executive compensation | VPs, SVPs, the CEO and the Chief People Officer | Pay and equity for executives. Not built in the demo; it would be a separate group with its own rule |
| Employee | Themselves | Their own full record, including national ID and equity grants |

Rules that apply to every role:

- Access follows **current** HRBP assignments and the **current** org. Ending an assignment or a reorg changes access at the next rebuild, with no grant changes.
- Masks apply before aggregation, so an average over a masked column only covers the people you can see (activity step 7).
- No breakdown of pay, rating or engagement for fewer than 5 people (Week 9).

---

## From demo to production

### What replaces `access_personas`?

A mapping from each **login** to an **employee ID**, loaded from the HR system, for example work email = Databricks login. Roles come from **account groups** rather than a table:

- `hr_admins` and `hrbps` groups, managed through SCIM from the identity provider (Okta, Entra ID), and checked in functions with `is_account_group_member('hr_admins')`.
- "Manager" isn't a group. It's derived from the org data: anyone with direct reports in `current_assignment`.
- "Employee" is everyone with a mapping row.

`acting_as()` becomes a lookup of `current_user()` in the mapping table, and `acting_role()` becomes group checks. There's no "act as" in production. Testing uses a non-production workspace with test accounts.

### What rebuilds `org_closure` and `hrbp_scope`, and how often?

A scheduled **Lakeflow job** that runs right after each HR system load (typically daily):

1. Load workers, job history and HRBP coverage from the HR system (for example Workday through Lakeflow Connect).
2. Rebuild `current_assignment`, then `org_closure` (recursive CTE), then `hrbp_scope`.
3. Run the self-checks: the CEO's org size equals active headcount − 1, no HRBP has an empty scope, and every leader with 110+ reports has at least one HRBP. If a check fails, keep yesterday's tables and alert, rather than publishing a broken scope.

Same-day changes, such as an urgent HRBP handover or a termination for cause, need an **on-demand run** of the same job. Write down the target, for example "access changes within 24 hours, or 1 hour on request".

The source of truth for HRBP coverage is the HR system, not a spreadsheet. If it isn't there today, getting it into the HR system is step one of the pilot.

### How would an ABAC policy apply the same masks everywhere?

Today each mask is attached column by column. With **attribute-based access control (ABAC)**, one policy matches on tags, so any column tagged `hr_sensitivity = restricted` is masked, including in tables created next year. The policy needs a way to find the employee each row belongs to, so tag the key columns too, for example `employee_key` on every `employee_id`:

```sql
-- Tag the column that identifies whose row it is (once per table)
ALTER TABLE tema_hr_gold.fact_headcount_monthly ALTER COLUMN employee_id SET TAGS ('employee_key');
ALTER TABLE tema_hr_gold.fact_equity_grants     ALTER COLUMN employee_id SET TAGS ('employee_key');
ALTER TABLE tema_hr_gold.dim_employee_sensitive ALTER COLUMN employee_id SET TAGS ('employee_key');

-- One policy for every restricted column in the catalog
CREATE POLICY hr_restricted_columns
ON CATALOG workspace
COMMENT 'Mask every hr_sensitivity=restricted column outside the HR scope of the viewer.'
COLUMN MASK tema_hr_secure.mask_by_scope   -- a new mask you'd write, like mask_text but for any type
TO `account users` EXCEPT `hr_admins`
FOR TABLES
MATCH COLUMNS has_tag_value('hr_sensitivity', 'restricted') AS col, has_tag('employee_key') AS emp
ON COLUMN col
USING COLUMNS (emp);


-- Whole tables of sensitive rows, like equity grants, need a ROW FILTER policy built the same way
-- (match on has_tag('employee_key'), call sensitive_row_filter). Check the current syntax in the ABAC docs.
```

Points to make in the doc:

- **The tags from Week 2 become the policy.** Tagging a new column `restricted` is enough to protect it, and forgetting to tag it is the main risk, so the gold table checklist should include "sensitive columns tagged".
- **One mask function has to handle several data types**, or you write one policy per type (dates, amounts, text). Check what the current ABAC release supports.
- **Governed tags.** In production the tag keys and allowed values (`restricted`, `confidential`) should be governed tags, so nobody can invent `restrcted` by mistake.
- **Not runnable in Free Edition.** ABAC policies and governed tags need account-level permissions. The syntax above follows the current docs as far as I know, but treat it as a sketch and check it before your pilot.

### Other production changes worth listing

| Demo | Production |
|---|---|
| Single user acting as personas | Real logins, groups from the identity provider, a test workspace for checks |
| Scope rebuilt by hand | Scheduled job after each HR load, with self-checks and alerts |
| Masks set column by column | ABAC policies on tags |
| `current_date()` decides which assignments count | The same, but the HR system's effective dates must be reliable, including future-dated changes |
| Trust the demo | Audit with `system.access.audit`: who read restricted columns, and when (Week 9) |
| HRBPs see executives' teams but not executives | A separate executive compensation group with its own policy |
