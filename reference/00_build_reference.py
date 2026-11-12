# Databricks notebook source
# MAGIC %md
# MAGIC # Build the Tema reference
# MAGIC
# MAGIC Runs every finished lab file in this repo, in order, to build the **answer** version of Tema next to your own work.
# MAGIC
# MAGIC | Widget | Default | What it does |
# MAGIC |---|---|---|
# MAGIC | `catalog` | `workspace` | The catalog to build in (Free Edition's default is `workspace`) |
# MAGIC | `reference_prefix` | `tema_ref` | Schemas are named `<prefix>_gold`, `<prefix>_semantic`, `<prefix>_secure`. The default keeps the reference apart from your own `tema_hr_*` schemas. Set it to `tema_hr` only if you want the reference to **replace** your work |
# MAGIC | `through_week` | `12` | Build the state at the end of this week. Use the week you've just finished, so the numbers match the lab you're on (for example, attrition is 13.1% at week 4 to 9 and 12.9% from week 10) |
# MAGIC | `include_optional` | `yes` | Also run steps that Free Edition may refuse (tags, grants, certification). Failures there are reported and skipped |
# MAGIC
# MAGIC **Before you run it:** generate the source data with `hr_people_analytics/00_generate_hr_data.py` (5,000 people for the checkpoint numbers).
# MAGIC The reference reads the same `tema_hr_raw` tables as your own work; it never changes them.
# MAGIC
# MAGIC Attach to **Serverless** and **Run all**. It takes a few minutes at 5,000 people. Then open `01_check_my_work`.
# MAGIC
# MAGIC > Untested in Databricks: every file was written and checked against the same data locally, but Databricks-only features
# MAGIC > (metric views, masks, tags) were not run. If a step fails, the error names the file and statement, so you can fix the file.

# COMMAND ----------

# MAGIC %run ./sql_runner

# COMMAND ----------

dbutils.widgets.text("catalog", "workspace")
dbutils.widgets.text("reference_prefix", "tema_ref")
dbutils.widgets.dropdown("through_week", "12", [str(w) for w in range(1, 13)])
dbutils.widgets.dropdown("include_optional", "yes", ["yes", "no"])

CATALOG = dbutils.widgets.get("catalog").strip()
PREFIX = dbutils.widgets.get("reference_prefix").strip()
THROUGH = int(dbutils.widgets.get("through_week"))
OPTIONAL = dbutils.widgets.get("include_optional") == "yes"

if PREFIX == "tema_hr":
    print("⚠️  reference_prefix is tema_hr: the reference will OVERWRITE your own gold, semantic and secure schemas.")
print(f"Building the reference through week {THROUGH} in {CATALOG}.{PREFIX}_gold / _semantic / _secure")

# COMMAND ----------

# MAGIC %md
# MAGIC ## The build plan
# MAGIC One row per file: the week it finishes, the file, and whether a failure stops the build.
# MAGIC Retention uses the Week 4 snapshot until week 10, when part-time employees are excluded.

# COMMAND ----------

REPO = "../hr_people_analytics"
retention_file = f"{REPO}/metrics/retention_metrics.sql" if THROUGH >= 10 else "./snapshots/retention_metrics_week04.sql"

PLAN = [
    # week, file, optional
    (1,  f"{REPO}/gold/01_dimensions.sql",                         False),
    (2,  f"{REPO}/gold/02_facts.sql",                              False),
    (2,  f"{REPO}/gold/03_keys_and_comments.sql",                  True),
    (2,  f"{REPO}/gold/04_tags.sql",                               True),
    (3,  f"{REPO}/metrics/00_semantic_schema.sql",                 False),
    (3,  f"{REPO}/metrics/workforce_metrics.sql",                  False),
    (4,  retention_file,                                           False),
    (5,  f"{REPO}/metrics/talent_acquisition_metrics.sql",         False),
    (5,  f"{REPO}/metrics/experience_metrics.sql",                 False),
    (5,  f"{REPO}/metrics/pay_metrics.sql",                        False),
    (8,  f"{REPO}/governance/01_hrbp_access_model.sql",            False),
    (9,  f"{REPO}/metrics/pay_by_level_safe.sql",                  False),
    (9,  f"{REPO}/governance/03_trust_certification_and_access.sql", True),
    (11, f"{REPO}/gold/10_fact_ad_revenue.sql",                    False),
    (11, f"{REPO}/metrics/business_metrics.sql",                   False),
]
# Weeks 0, 6, 7, 10 (bundle) and 12 produce notebooks, dashboards, Genie settings and documents rather than
# tables; see reference/README.md for where each finished output lives.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Check the source data exists

# COMMAND ----------

raw_tables = {r.tableName for r in spark.sql(f"SHOW TABLES IN `{CATALOG}`.tema_hr_raw").collect()}
missing = {"employees", "job_history", "headcount_monthly", "departments", "jobs", "locations", "requisitions",
           "absences", "engagement_surveys", "performance_reviews", "equity_grants", "hrbp_assignments"} - raw_tables
assert not missing, f"Run hr_people_analytics/00_generate_hr_data.py first. Missing in {CATALOG}.tema_hr_raw: {sorted(missing)}"
people = spark.sql(f"SELECT COUNT(*) AS n FROM `{CATALOG}`.tema_hr_raw.employees").first().n
print(f"tema_hr_raw has {people:,} employees ever employed" + (" (the 5,000-person build: checkpoint numbers apply)" if people == 7207 else ""))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Run it

# COMMAND ----------

SKIP_PREFIXES = ("SELECT", "WITH", "SHOW", "DESCRIBE")   # checks inside build files; 01_check_my_work runs the checks
SAFE_MEASURE = re.compile(r"\n  # Week 9: the small-group rule.*?(?=\n\$\$)", re.S)

results = []

def run_file(week, path, optional):
    text = open(path).read()
    ok = failed = 0
    for stmt in split_sql(text):
        if stmt.lstrip("( \n").upper().startswith(SKIP_PREFIXES):
            continue
        sql = retarget(stmt, CATALOG, PREFIX)
        try:
            spark.sql(sql)
            ok += 1
        except Exception as e:
            msg = str(e).split("\n")[0][:300]
            # pay_metrics: if the Week 9 CASE-around-aggregates measure is refused, build without it (lab fallback)
            if "pay_metrics" in path and SAFE_MEASURE.search(sql):
                try:
                    spark.sql(SAFE_MEASURE.sub("", sql))
                    ok += 1
                    results.append((week, path, "warning", "avg_compa_ratio_safe refused; built pay_metrics without it. Use pay_by_level_safe.", msg))
                    continue
                except Exception:
                    pass
            failed += 1
            results.append((week, path, "skipped" if optional else "FAILED", first_line(sql, 140), msg))
            if not optional:
                raise RuntimeError(f"Week {week}, {path}\n  statement: {first_line(sql, 200)}\n  error: {msg}") from None
    results.append((week, path, "ok" if not failed else "partly", f"{ok} statements run", ""))

for week, path, optional in PLAN:
    if week > THROUGH or (optional and not OPTIONAL):
        continue
    print(f"Week {week:>2}  {path}")
    run_file(week, path, optional)

# COMMAND ----------

# MAGIC %md
# MAGIC ## What happened
# MAGIC `ok` ran fully. `partly` and `skipped` are optional steps your workspace refused (common on Free Edition:
# MAGIC tags, grants to `account users`, certification). `warning` means a fallback was used.

# COMMAND ----------

display(spark.createDataFrame(results, "week INT, file STRING, status STRING, detail STRING, error STRING"))

# COMMAND ----------

display(spark.sql(f"""
  SELECT table_schema, table_name, table_type
  FROM `{CATALOG}`.information_schema.tables
  WHERE table_schema IN ('{PREFIX}_gold', '{PREFIX}_semantic', '{PREFIX}_secure')
  ORDER BY table_schema, table_name"""))
