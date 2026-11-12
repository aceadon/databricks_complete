# People data governance model

Completed reference version (Weeks 8 and 9). The model it describes is built in [`hr_people_analytics/governance/`](../hr_people_analytics/governance/README.md); Week 9's suppression and access pieces are in [`metrics/pay_metrics.sql`](../hr_people_analytics/metrics/pay_metrics.sql), [`metrics/pay_by_level_safe.sql`](../hr_people_analytics/metrics/pay_by_level_safe.sql) and [`governance/03_trust_certification_and_access.sql`](../hr_people_analytics/governance/03_trust_certification_and_access.sql).

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

## Minimum group size and small-group suppression (Week 9)

- **Rule:** no breakdown of pay, compa-ratio, performance rating or engagement for a group of fewer than **5 people**. Pay equity (gender) needs **10 on each side** of every comparison (see `docs/metric-definitions.md`).
- **How it's enforced:** inside the measure (`avg_compa_ratio_safe` returns empty under 5), so it holds at any grain someone groups by, and Genie and BI tools inherit it. `pay_by_level_safe` is the fixed-breakdown fallback for dashboards.
- **The subtraction problem:** a suppressed value can be recovered by subtracting the shown groups from the division total, so for pay we also suppress the next-smallest group in any breakdown with a suppressed cell (complementary suppression), and publish only fixed breakdowns to the broad audience.
- Headcount and attrition by department are not suppressed: they aren't sensitive at Tema's group sizes. Revisit if a breakdown would let someone infer who left.

## Aggregate-only access (Week 9)

| Audience | Gets | Doesn't get |
|---|---|---|
| Everyone (`account users`) | `SELECT` on `workforce_metrics`, `retention_metrics`, `talent_acquisition_metrics`, `experience_metrics`, `pay_by_level_safe` | Anything in `tema_hr_gold`, `tema_hr_raw`, `tema_hr_secure`; `pay_metrics` |
| People Analytics, Total Rewards | Also `pay_metrics` and `tema_hr_gold` | `tema_hr_secure` beyond their own row |
| HRBPs | Also `tema_hr_secure.employee_profile` and `equity_grants`, filtered and masked to their scope | Rows outside scope |

A metric view runs its source query with its owner's rights, so readers need `SELECT` on the view only. Masks and row filters on the source tables still apply to the reader. A grant on a metric view covers every measure in it, which is why pay is split: the safe measure lives where the broad audience can reach it, the raw ones don't. (Free Edition is single-user, so this was checked from `SHOW GRANTS`, not by logging in as someone else.)

## Metric ownership and certification

- **Who can propose a new metric:** anyone, as a pull request that changes the metric view YAML and `docs/metric-definitions.md` together.
- **Who approves it:** the metric's owner named in the definitions doc (for example the People Analytics lead for headcount and attrition, Total Rewards for pay), plus the CHRO's delegate when it changes a number reported to the leadership team.
- **How changes are reviewed:** a monthly metrics council of the owners reviews open pull requests. The Week 10 part-time change is the worked example: definition and YAML in one PR, before and after numbers in the description, owner approval as the review.
- **How a certified metric is marked:** the `system.certification_status = certified` tag (Catalog Explorer shows a Certified badge). Replaced assets get `deprecated`, like `v_headcount_naive`, so search and Genie steer away from them. Status in the definitions doc matches the tag.
- **Deployment:** only from `main`, by the bundle in `databricks.yml` (Week 10). Nobody edits metric views in the UI in production.

## Access lifecycle

- **Source of truth for HRBP coverage:** the HR system (HRBP-to-leader assignments with effective dates), not a spreadsheet. If it isn't there today, putting it there is the pilot's first step.
- **How fast a change reaches access:** at the next scheduled rebuild after the HR load (daily), or within an hour on request for urgent cases such as a termination for cause.
- **How access is audited:** `system.access.audit` and `system.query.history` feed the **Semantic layer adoption and access** dashboard ([queries](../hr_people_analytics/governance/04_adoption_and_access_queries.sql)): queries per metric view per week, distinct users, and every read of `tema_hr_secure`. HR and Security review the access table monthly.

## Open decisions

1. Do people managers get their team's salaries during pay reviews? Tema's model says no; many companies say yes for a review window.
2. Grace period for HRBPs to see leavers (option A in `solutions/week-08-policy-changes.sql`): 0 or 90 days?
3. Who owns executive compensation access, and is it a separate policy or a separate workspace?
4. Is gender reported to HRBPs at all, or only to Total Rewards and Legal?
5. Do engagement survey results go below division level, and at what minimum number of respondents?
