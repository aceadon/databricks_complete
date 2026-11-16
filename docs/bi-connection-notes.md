# BI connection notes (Week 11, step 1)

How to connect Tableau to a Unity Catalog metric view, and what to ask your BI team. Free Edition may limit external connections and personal access tokens. If you're blocked, these notes are the deliverable.

Databricks docs: [Use metric views with BI tools](https://docs.databricks.com/aws/en/business-semantics/metric-views/bi-tools), [BI compatibility mode](https://docs.databricks.com/aws/en/partners/bi/bi-metric-view) and [Connect Tableau to Databricks](https://docs.databricks.com/aws/en/partners/bi/tableau).

## Why Tableau needs help with a metric view

Metric view measures only work through `MEASURE()`. Tableau doesn't write `MEASURE()` itself. It writes `SUM(...)`, which is the 12,429 mistake from Week 3. There are two ways round that.

## Option A: Custom SQL (simplest, and the most reliable)

1. In Databricks, open your SQL warehouse, then **Connection details**, and copy the server hostname and HTTP path.
2. In Tableau Desktop, choose **Connect > To a Server > Databricks**. Paste the hostname and HTTP path, and sign in with **OAuth** (preferred) or a personal access token.
3. Use a **Live** connection, not an extract. An extract copies rows at one grain and loses the semi-additive logic.
4. Drag in **New Custom SQL** and paste:

   ```sql
   SELECT quarter, division, MEASURE(headcount) AS headcount
   FROM workspace.tema_hr_semantic.workforce_metrics   -- your catalog if it isn't workspace
   GROUP BY ALL
   ```

   List every column. Metric views don't support `SELECT *`.
5. Build headcount by division by quarter. Tableau will put `SUM(headcount)` on the shelf. That's fine here, because each row is already one quarter and one division.

The catch: the query fixes the grain. For headcount by month or by city, you need another Custom SQL data source, or a plain view per breakdown that wraps the `MEASURE()` query.

## Option B: BI compatibility mode (drag and drop)

Databricks rewrites Tableau's `SUM(...)` into the metric view's real measure, so you can connect to the metric view like a table.

1. Connect as in steps 1 to 3 above.
2. In the connection dialog, open **Initial SQL** and enter:

   ```sql
   SET metric_view_bi_compatibility_mode = true;
   ```

   The setting only lasts for the session, which is why it goes in Initial SQL: Tableau runs it on every new connection.
3. Pick `tema_hr_semantic.workforce_metrics` in your catalog (`workspace` by default) and build the chart.

Limits to know (from the Databricks docs):

- Leave every measure's aggregation as **SUM**. AVG returns wrong results, and Count (Distinct), Median, Variance and Standard Deviation don't work.
- Grand totals of ratios, such as attrition rate, can be wrong.
- No joins. Tableau data source joins, Top N, sets, conditional filters and LOD expressions can turn into joins and fail. Put that logic in the metric view instead.
- Don't put a measure on an axis, in a legend or in a bin (`METRIC_VIEW_MEASURE_IN_GROUP_BY`).
- It needs a SQL warehouse (or Databricks Runtime 18.0+), and the connection has to be live.

## Check

2025-Q2 headcount shows **4,176**, not 12,429. If you see 12,429, Tableau is summing month-level rows: the connection isn't going through the measure. Check the Initial SQL (option B), or that the Custom SQL uses `MEASURE()` (option A).

## Questions for the BI team

- Which Tableau versions are in use (Desktop, Server or Cloud), and is the Databricks connector current enough for OAuth?
- **Who authenticates?** With per-user OAuth, row filters and masks apply to each viewer. A shared service account means everyone sees what that account sees, which breaks the Week 8 HRBP model for HR data.
- Can published workbooks on Tableau Server or Cloud keep per-user credentials, or do they embed one?
- Are published data sources allowed to use Initial SQL? Some sites lock it down.
- Do existing workbooks define their own headcount and attrition as calculated fields? Those are the definitions to retire in the pilot.

## What I found

*(Record your result: which option, whether the quarter check passed, and any blocker. A blocker such as "Free Edition doesn't allow external tokens" is a useful finding for the rollout team.)*
