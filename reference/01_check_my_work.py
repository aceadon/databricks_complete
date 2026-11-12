# Databricks notebook source
# MAGIC %md
# MAGIC # Check my work
# MAGIC
# MAGIC Compares **your** Tema build with the checkpoint numbers in the lab sheets and with the reference build, week by week.
# MAGIC
# MAGIC | Widget | Default | What it does |
# MAGIC |---|---|---|
# MAGIC | `catalog` | `workspace` | Where your schemas live |
# MAGIC | `my_prefix` | `tema_hr` | Your schemas: `tema_hr_gold`, `tema_hr_semantic`, `tema_hr_secure` |
# MAGIC | `reference_prefix` | `tema_ref` | The schemas `00_build_reference` built. Leave it blank to compare with the lab numbers only |
# MAGIC | `through_week` | `12` | Check weeks up to this one. Later weeks are left out, so nothing shows as missing before you've done it |
# MAGIC
# MAGIC **How to read the result**
# MAGIC
# MAGIC - ✅ **match**: your number equals the expected one.
# MAGIC - 🟡 **explained**: your number is a known alternative (for example, attrition before the Week 10 change). The note says what it means.
# MAGIC - ❌ **differs**: compare your file with the reference file named in the `reference_file` column.
# MAGIC - ⬜ **not built**: the table or view isn't there, or the query failed. The error says why.
# MAGIC
# MAGIC Expected numbers are for Tema at **5,000 people** (seed 42). If you generated another size, the notebook compares you with
# MAGIC the reference build instead, which needs `00_build_reference` run on the same data.
# MAGIC
# MAGIC Weeks 0, 6, 7, 10 and 12 also produce things a query can't check (notes, a dashboard, Genie scores, a bundle deploy, a proposal).
# MAGIC The last cell lists them with the finished version to compare against.

# COMMAND ----------

dbutils.widgets.text("catalog", "workspace")
dbutils.widgets.text("my_prefix", "tema_hr")
dbutils.widgets.text("reference_prefix", "tema_ref")
dbutils.widgets.dropdown("through_week", "12", [str(w) for w in range(0, 13)])

CATALOG = dbutils.widgets.get("catalog").strip()
MINE = dbutils.widgets.get("my_prefix").strip()
REF = dbutils.widgets.get("reference_prefix").strip()
THROUGH = int(dbutils.widgets.get("through_week"))

# COMMAND ----------

# MAGIC %md
# MAGIC ## The checks
# MAGIC Each check is one query returning one value. `{raw}`, `{gold}`, `{sem}` and `{sec}` are filled in with your schemas
# MAGIC (or the reference's). `expected` is the 5,000-person checkpoint value; `alternatives` are known, explainable other answers.

# COMMAND ----------

PART_TIME = THROUGH >= 10   # from Week 10, attrition excludes part-time employees

def att(week4, week10):
    """Attrition checkpoints change in Week 10. Return (expected, alternatives)."""
    if PART_TIME:
        return week10, {week4: "Matches the Week 4 definition. Fine until you've done the Week 10 part-time change."}
    return week4, {week10: "Part-time employees are excluded: that's the Week 10 change, ahead of schedule."}

GOLD_TABLES = ["dim_department", "dim_location", "dim_job", "dim_employee", "dim_employee_sensitive", "dim_manager", "dim_date",
               "fact_headcount_monthly", "fact_terminations", "fact_requisitions", "fact_engagement", "fact_absences", "fact_equity_grants"]
in_gold = ", ".join(f"'{t}'" for t in GOLD_TABLES)

def mv(view, measure, where="", scale=1, digits=1):
    w = f"WHERE {where}" if where else ""
    return f"SELECT ROUND({scale} * MEASURE({measure}), {digits}) FROM {{sem}}.{view} {w}"

M = "hr_people_analytics/metrics"
G = "hr_people_analytics/gold"
V = "hr_people_analytics/governance"
ret = f"{M}/retention_metrics.sql" if PART_TIME else "reference/snapshots/retention_metrics_week04.sql"

CHECKS = [
  # week, check, sql, expected (5,000 people), alternatives, reference file
  (0, "Source tables in tema_hr_raw", "SELECT COUNT(*) FROM {cat}.information_schema.tables WHERE table_schema = 'tema_hr_raw'", 12, {}, "hr_people_analytics/00_generate_hr_data.py"),
  (0, "employees rows", "SELECT COUNT(*) FROM {raw}.employees", 7207, {}, "hr_people_analytics/00_generate_hr_data.py"),
  (0, "headcount_monthly rows", "SELECT COUNT(*) FROM {raw}.headcount_monthly", 195904, {}, "hr_people_analytics/00_generate_hr_data.py"),
  (0, "Query A: every October 2026 row", "SELECT COUNT(*) FROM {raw}.headcount_monthly WHERE snapshot_month = '2026-10-31'", 5065, {}, "labs/week-00-setup-and-meet-tema.md"),
  (0, "Query B: active at end of October 2026", "SELECT COUNT(*) FROM {raw}.headcount_monthly WHERE snapshot_month = '2026-10-31' AND is_active_month_end", 5024, {}, "labs/week-00-setup-and-meet-tema.md"),
  (0, "Query D: the wrong Q2 2025 'headcount'", "SELECT COUNT(*) FROM {raw}.headcount_monthly WHERE snapshot_month BETWEEN '2025-04-01' AND '2025-06-30' AND is_active_month_end", 12429, {}, "labs/week-00-setup-and-meet-tema.md"),

  (1, "Dimension tables present (of 7)", f"SELECT COUNT(*) FROM {{cat}}.information_schema.tables WHERE table_schema = '{{gold_name}}' AND table_name IN ({in_gold}) AND table_name LIKE 'dim%'", 7, {}, f"{G}/01_dimensions.sql"),
  (1, "dim_employee rows", "SELECT COUNT(*) FROM {gold}.dim_employee", 7207, {}, f"{G}/01_dimensions.sql"),
  (1, "dim_employee_sensitive rows", "SELECT COUNT(*) FROM {gold}.dim_employee_sensitive", 7207, {}, f"{G}/01_dimensions.sql"),
  (1, "dim_manager rows", "SELECT COUNT(*) FROM {gold}.dim_manager", 592, {}, f"{G}/01_dimensions.sql"),
  (1, "dim_date rows", "SELECT COUNT(*) FROM {gold}.dim_date", 48, {}, f"{G}/01_dimensions.sql"),
  (1, "Sensitive columns left in dim_employee", "SELECT COUNT(*) FROM {cat}.information_schema.columns WHERE table_schema = '{gold_name}' AND table_name = 'dim_employee' AND column_name IN ('date_of_birth', 'national_id', 'personal_email', 'home_postcode', 'gender')", 0, {}, f"{G}/01_dimensions.sql"),
  (1, "Duplicate employee_id in dim_employee", "SELECT COUNT(*) FROM (SELECT employee_id FROM {gold}.dim_employee GROUP BY ALL HAVING COUNT(*) > 1)", 0, {}, f"{G}/01_dimensions.sql"),

  (2, "Star schema tables present (of 13)", f"SELECT COUNT(*) FROM {{cat}}.information_schema.tables WHERE table_schema = '{{gold_name}}' AND table_name IN ({in_gold})", 13, {}, f"{G}/02_facts.sql"),
  (2, "fact_headcount_monthly rows", "SELECT COUNT(*) FROM {gold}.fact_headcount_monthly", 195904, {}, f"{G}/02_facts.sql"),
  (2, "fact_terminations rows", "SELECT COUNT(*) FROM {gold}.fact_terminations", 2183, {}, f"{G}/02_facts.sql"),
  (2, "fact_requisitions rows", "SELECT COUNT(*) FROM {gold}.fact_requisitions", 2948, {}, f"{G}/02_facts.sql"),
  (2, "fact_engagement rows", "SELECT COUNT(*) FROM {gold}.fact_engagement", 23252, {}, f"{G}/02_facts.sql"),
  (2, "fact_absences rows (Your turn)", "SELECT COUNT(*) FROM {gold}.fact_absences", 74392, {}, f"{G}/02_facts.sql"),
  (2, "fact_equity_grants rows (Your turn)", "SELECT COUNT(*) FROM {gold}.fact_equity_grants", 8276, {}, f"{G}/02_facts.sql"),
  (2, "Dimensions with a primary key (of 7)", "SELECT COUNT(DISTINCT table_name) FROM {cat}.information_schema.table_constraints WHERE table_schema = '{gold_name}' AND constraint_type = 'PRIMARY KEY' AND table_name LIKE 'dim%'", 7, {}, f"{G}/03_keys_and_comments.sql"),
  (2, "Star schema columns with no comment", f"SELECT COUNT(*) FROM {{cat}}.information_schema.columns WHERE table_schema = '{{gold_name}}' AND table_name IN ({in_gold}) AND (comment IS NULL OR comment = '')", 0, {}, f"{G}/03_keys_and_comments.sql"),
  (2, "Tables with no comment", f"SELECT COUNT(*) FROM {{cat}}.information_schema.tables WHERE table_schema = '{{gold_name}}' AND table_name IN ({in_gold}) AND (comment IS NULL OR comment = '')", 0, {}, f"{G}/03_keys_and_comments.sql"),
  (2, "Columns tagged hr_sensitivity = restricted (8 or more)", "SELECT LEAST(COUNT(*), 8) FROM {cat}.information_schema.column_tags WHERE schema_name = '{gold_name}' AND tag_name = 'hr_sensitivity' AND tag_value = 'restricted'", 8, {}, f"{G}/04_tags.sql"),

  (3, "Headcount 2025-Q2 (not 12,429)", mv("workforce_metrics", "headcount", "quarter = '2025-Q2'", digits=0), 4176, {12429: "Summed over three months: the window needs semiadditive: last."}, f"{M}/workforce_metrics.sql"),
  (3, "Headcount October 2026", mv("workforce_metrics", "headcount", "month = '2026-10-31'", digits=0), 5024, {}, f"{M}/workforce_metrics.sql"),
  (3, "Hires, year to date 2026", mv("workforce_metrics", "hires", "month BETWEEN '2026-01-01' AND '2026-10-31'", digits=0), 1126, {}, f"{M}/workforce_metrics.sql"),
  (3, "Leavers, year to date 2026", mv("workforce_metrics", "leavers", "month BETWEEN '2026-01-01' AND '2026-10-31'", digits=0), 501, {}, f"{M}/workforce_metrics.sql"),
  (3, "Net change, year to date 2026", mv("workforce_metrics", "net_change", "month BETWEEN '2026-01-01' AND '2026-10-31'", digits=0), 625, {}, f"{M}/workforce_metrics.sql"),
  (3, "AI headcount October 2026", mv("workforce_metrics", "headcount", "month = '2026-10-31' AND division = 'AI'", digits=0), 674, {}, f"{M}/workforce_metrics.sql"),
  (3, "San Francisco headcount October 2026 (city dimension)", mv("workforce_metrics", "headcount", "month = '2026-10-31' AND city = 'San Francisco'", digits=0), 1263, {}, f"{M}/workforce_metrics.sql"),
  (3, "Average salary October 2026", mv("workforce_metrics", "average_salary", "month = '2026-10-31'", digits=0), 151239, {}, f"{M}/workforce_metrics.sql"),
  (3, "Average salary for 2025 (= December 2025)", mv("workforce_metrics", "average_salary", "year = 2025", digits=0), 136789, {133899: "Average over every person-month in 2025: average_salary has no semiadditive window. Defensible if documented, but not the reference choice."}, f"{M}/workforce_metrics.sql"),
  (3, "Span of control October 2026", mv("workforce_metrics", "span_of_control", "month = '2026-10-31'", digits=2), 7.49, {}, f"{M}/workforce_metrics.sql"),

  (4, "Attrition (T12M) October 2026, %", mv("retention_metrics", "attrition_rate_t12m", "month = '2026-10-31'", 100), *att(13.1, 12.9), ret),
  (4, "Attrition (T12M) October 2025, %", mv("retention_metrics", "attrition_rate_t12m", "month = '2025-10-31'", 100), *att(12.0, 11.8), ret),
  (4, "Voluntary attrition October 2026, %", mv("retention_metrics", "voluntary_attrition_rate_t12m", "month = '2026-10-31'", 100), *att(10.0, 9.9), ret),
  (4, "Regretted attrition October 2026, %", mv("retention_metrics", "regretted_attrition_rate_t12m", "month = '2026-10-31'", 100), *att(4.3, 4.2), ret),
  (4, "Trust & Safety attrition October 2026, %", mv("retention_metrics", "attrition_rate_t12m", "month = '2026-10-31' AND division = 'Trust & Safety'", 100), *att(22.2, 21.6), ret),
  (4, "AI regretted attrition October 2026, %", mv("retention_metrics", "regretted_attrition_rate_t12m", "month = '2026-10-31' AND division = 'AI'", 100), *att(10.2, 10.1), ret),
  (4, "First-year attrition October 2026, % (Your turn)", mv("retention_metrics", "first_year_attrition_rate_t12m", "month = '2026-10-31'", 100), 24.0, {}, ret),

  (5, "Median days to fill, AI, filled since May 2025", mv("talent_acquisition_metrics", "median_time_to_fill_days", "opened_date >= '2025-05-01' AND status = 'Filled' AND division = 'AI'", digits=0), 67, {}, f"{M}/talent_acquisition_metrics.sql"),
  (5, "Median days to fill, rest of Tema, since May 2025", mv("talent_acquisition_metrics", "median_time_to_fill_days", "opened_date >= '2025-05-01' AND status = 'Filled' AND division <> 'AI'", digits=0), 41, {}, f"{M}/talent_acquisition_metrics.sql"),
  (5, "Offer acceptance, AI, since May 2025, %", mv("talent_acquisition_metrics", "offer_acceptance_rate", "opened_date >= '2025-05-01' AND status = 'Filled' AND division = 'AI'", 100), 69.8, {}, f"{M}/talent_acquisition_metrics.sql"),
  (5, "Open requisitions", mv("talent_acquisition_metrics", "open_requisitions", digits=0), 79, {}, f"{M}/talent_acquisition_metrics.sql"),
  (5, "eNPS 2023-H1 (Your turn)", mv("experience_metrics", "enps", "survey_cycle = '2023-H1'"), -7.1, {}, f"{M}/experience_metrics.sql"),
  (5, "eNPS 2026-H1 (Your turn)", mv("experience_metrics", "enps", "survey_cycle = '2026-H1'"), 16.7, {}, f"{M}/experience_metrics.sql"),
  (5, "IC4 average compa-ratio October 2026", mv("pay_metrics", "avg_compa_ratio", "month = '2026-10-31' AND job_level = 'IC4'", digits=2), 1.02, {0.33: "Divided by the band midpoint without location_pay_factor? That's the common mistake."}, f"{M}/pay_metrics.sql"),
  (5, "M1 average compa-ratio October 2026", mv("pay_metrics", "avg_compa_ratio", "month = '2026-10-31' AND job_level = 'M1'", digits=2), 1.10, {}, f"{M}/pay_metrics.sql"),

  (8, "org_closure: CEO's org = active headcount - 1 (0 means yes)", "SELECT (SELECT COUNT(*) FROM {sec}.current_assignment) - 1 - COUNT(*) FROM {sec}.org_closure o JOIN {sec}.current_assignment c ON c.employee_id = o.ancestor_id WHERE c.job_level = 'E1'", 0, {}, f"{V}/01_hrbp_access_model.sql"),
  (8, "org_closure rows", "SELECT COUNT(*) FROM {sec}.org_closure", 24363, {}, f"{V}/01_hrbp_access_model.sql"),
  (8, "employee_profile rows (active employees)", "SELECT COUNT(*) FROM {sec}.employee_profile", 5024, {}, f"{V}/01_hrbp_access_model.sql"),
  (8, "can_see_sensitive() exists", "SELECT COUNT(*) FROM {cat}.information_schema.routines WHERE routine_schema = '{sec_name}' AND routine_name = 'can_see_sensitive'", 1, {}, f"{V}/01_hrbp_access_model.sql"),
  (8, "HRBPs with a scope today (compare with reference; depends on today's date)", "SELECT COUNT(DISTINCT hrbp_employee_id) FROM {sec}.hrbp_scope", None, {}, f"{V}/01_hrbp_access_model.sql"),

  (9, "pay_by_level_safe: small groups showing a value (must be 0)", "SELECT COUNT(*) FROM {sem}.pay_by_level_safe WHERE month = '2026-10-31' AND is_suppressed AND avg_compa_ratio IS NOT NULL", 0, {}, f"{M}/pay_by_level_safe.sql"),
  (9, "pay_by_level_safe: suppressed groups October 2026", "SELECT COUNT_IF(is_suppressed) FROM {sem}.pay_by_level_safe WHERE month = '2026-10-31'", 13, {}, f"{M}/pay_by_level_safe.sql"),

  (10, "Attrition excludes part-time (October 2026, %)", mv("retention_metrics", "attrition_rate_t12m", "month = '2026-10-31'", 100), 12.9, {13.1: "Part-time employees are still included: make the Week 10 change.", 12.5: "Excluded from leavers but not from average headcount: change the denominator too."}, f"{M}/retention_metrics.sql"),

  (11, "fact_business_monthly rows", "SELECT COUNT(*) FROM {gold}.fact_business_monthly", 46, {}, f"{G}/10_fact_ad_revenue.sql"),
  (11, "Ad revenue 2025-Q2, $M", mv("business_metrics", "ad_revenue", "quarter = '2025-Q2'", 1e-6), 792.0, {}, f"{M}/business_metrics.sql"),
  (11, "Revenue per employee 2025-Q2, $k", "SELECT ROUND((SELECT MEASURE(ad_revenue) FROM {sem}.business_metrics WHERE quarter = '2025-Q2') / (SELECT MEASURE(headcount) FROM {sem}.workforce_metrics WHERE quarter = '2025-Q2') / 1000, 1)", 189.6, {63.7: "Headcount was summed over the quarter (12,429) instead of quarter-end."}, f"{M}/business_metrics.sql"),
]

# COMMAND ----------

def fill(sql, prefix):
    return sql.format(cat=CATALOG, raw=f"{CATALOG}.tema_hr_raw",
                      gold=f"{CATALOG}.{prefix}_gold", sem=f"{CATALOG}.{prefix}_semantic", sec=f"{CATALOG}.{prefix}_secure",
                      gold_name=f"{prefix}_gold", sec_name=f"{prefix}_secure")

def value(sql, prefix):
    try:
        v = spark.sql(fill(sql, prefix)).first()[0]
        return (float(v) if v is not None else None), None
    except Exception as e:
        return None, str(e).split("\n")[0][:200]

def same(a, b):
    return a is not None and b is not None and abs(float(a) - float(b)) < 1e-6 + 1e-9 * abs(float(b))

people = spark.sql(f"SELECT COUNT(*) FROM {CATALOG}.tema_hr_raw.employees").first()[0]
FIVE_K = people == 7207
print(f"Data: {people:,} employees ever employed. " + ("Comparing with the 5,000-person checkpoint numbers." if FIVE_K
      else "Not the 5,000-person build, so comparing with the reference build only."))

rows = []
for week, name, sql, expected, alts, ref_file in CHECKS:
    if week > THROUGH:
        continue
    mine, err = value(sql, MINE)
    ref, _ = value(sql, REF) if REF else (None, None)
    target = expected if (FIVE_K and expected is not None) else ref
    if err:
        status, note = "⬜ not built", err
    elif target is None:
        status, note = "· info", "No fixed answer: compare with the reference column."
    elif same(mine, target):
        status, note = "✅ match", ""
    elif FIVE_K and any(same(mine, a) for a in alts):
        status, note = "🟡 explained", next(alts[a] for a in alts if same(mine, a))
    else:
        status, note = "❌ differs", f"Compare with {ref_file}"
    rows.append((week, name, status, mine, target, ref, note, ref_file))

result = spark.createDataFrame(rows, "week INT, check STRING, status STRING, yours DOUBLE, expected DOUBLE, reference DOUBLE, note STRING, reference_file STRING")
display(result)

# COMMAND ----------

summary = {}
for r in rows:
    summary.setdefault(r[0], {"✅": 0, "🟡": 0, "❌": 0, "⬜": 0, "·": 0})
    summary[r[0]][r[2][0]] += 1
for w, s in sorted(summary.items()):
    verdict = "done" if s["❌"] == 0 and s["⬜"] == 0 else "needs a look"
    print(f"Week {w:>2}: {s['✅']} match, {s['🟡']} explained, {s['❌']} differ, {s['⬜']} not built  →  {verdict}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## What a query can't check
# MAGIC
# MAGIC | Week | Output | Compare with |
# MAGIC |---|---|---|
# MAGIC | 0 | `plan/notes/week-00.md`: decisions behind one headcount number | `plan/notes/week-00.md` in this repo, and `solutions/week-00-headcount-decisions.md` |
# MAGIC | 1 | One sentence on where `gender` belongs | `solutions/week-01-dimensions.sql` |
# MAGIC | 2 | The stranger test and the gold table checklist | `docs/gold-table-checklist.md` |
# MAGIC | 3–5 | Definitions doc entries | `docs/metric-definitions.md` |
# MAGIC | 6 | The Tema Workforce Overview dashboard | `hr_people_analytics/dashboards/` (import the `.lvdash.json`, or rebuild from its README) |
# MAGIC | 7 | Genie instructions, example SQL, the 20-question benchmark and your scores | `hr_people_analytics/genie/` |
# MAGIC | 8 | The persona walk-through, your policy change, the roles table | `hr_people_analytics/governance/02_hrbp_access_activity.sql`, `solutions/week-08-*`, `docs/people-data-governance-model.md` |
# MAGIC | 9 | Grants, certification, the adoption dashboard, the governance doc | `hr_people_analytics/governance/03_*.sql` and `04_*.sql`, `docs/people-data-governance-model.md` |
# MAGIC | 10 | `databricks.yml`, the part-time pull request, OSI notes | `databricks.yml`, `docs/metric-definitions.md`, `docs/semantic-tools-comparison.md` |
# MAGIC | 11 | BI connection notes and the tools comparison | `docs/bi-connection-notes.md`, `docs/semantic-tools-comparison.md` |
# MAGIC | 12 | The pilot proposal and the 30-minute demo | `docs/pilot-proposal.md`, `docs/demo-script.md` |
