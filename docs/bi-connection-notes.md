# BI connection notes (Week 11, step 1)

Reference notes for connecting a BI tool to Unity Catalog metric views. Free Edition may limit external connections and personal access tokens; if you're blocked, these notes are the deliverable.

## Steps (Power BI)

1. In Databricks, open your SQL warehouse, **Connection details**, and copy the server hostname and HTTP path.
2. In Power BI Desktop: **Get data > Azure Databricks** (or **Databricks**), paste them, sign in with OAuth (preferred) or a personal access token.
3. Pick `workspace.tema_hr_semantic.workforce_metrics`. Use **DirectQuery**, so every visual sends a query and the metric view does the aggregation. Import mode would copy pre-aggregated rows and lose the semi-additive logic.
4. Build: headcount by division by quarter.
5. **Check:** 2025-Q2 shows **4,176**, not 12,429. If you see 12,429, the tool is summing rows the connector returned at month grain: the connection isn't using the metric view's measure, so check the connector version and the metric view docs for BI tools.

## Steps (Tableau)

Same idea with the Databricks connector (hostname, HTTP path, OAuth), a live connection rather than an extract, and the same 4,176 check.

## Questions for the BI team

- Which tool is the company standard, and which connector version supports metric views?
- Is there a gateway (Power BI on-premises data gateway) between the BI service and Databricks?
- **Who authenticates?** Per-user OAuth means row filters and masks apply to each viewer. A shared service account means everyone sees what the account sees, which breaks the Week 8 HRBP model for HR data.
- Can published reports use per-user credentials in the BI service, not only on the desktop?
- Do existing BI models define their own headcount and attrition? Those are the definitions to retire in the pilot.

## What I found

*(Record your result: which tool, whether the quarter check passed, and any blocker. A blocker such as "Free Edition doesn't allow external tokens" is a useful finding for the rollout team.)*
