-- =====================================================================================
-- Tema reference build · Week 9 · aggregate-only access, certification and deprecation
-- labs/week-09, steps 2 and 3. Small-group suppression lives with the metrics:
-- metrics/pay_metrics.sql (avg_compa_ratio_safe) and metrics/pay_by_level_safe.sql.
-- Untested in Databricks. The reference build runs this file as OPTIONAL: Free Edition is
-- single-user and may refuse grants to `account users` or the system certification tag.
-- =====================================================================================
USE CATALOG workspace;

-- -------------------------------------------------------------------------------------
-- Step 2. Aggregate-only access: a broad group gets metric views, never the tables underneath.
-- -------------------------------------------------------------------------------------
GRANT USE CATALOG ON CATALOG workspace TO `account users`;
GRANT USE SCHEMA ON SCHEMA workspace.tema_hr_semantic TO `account users`;
GRANT SELECT ON VIEW workspace.tema_hr_semantic.workforce_metrics TO `account users`;
GRANT SELECT ON VIEW workspace.tema_hr_semantic.retention_metrics TO `account users`;
GRANT SELECT ON VIEW workspace.tema_hr_semantic.experience_metrics TO `account users`;
GRANT SELECT ON VIEW workspace.tema_hr_semantic.talent_acquisition_metrics TO `account users`;
GRANT SELECT ON VIEW workspace.tema_hr_semantic.pay_by_level_safe TO `account users`;
-- Deliberately NOT granted: anything in tema_hr_gold, tema_hr_raw or tema_hr_secure, and pay_metrics
-- (it has the unsuppressed avg_compa_ratio and average_salary; a metric view grant covers every measure).

-- Proof from grants (the Week 9 checkpoint)
SHOW GRANTS ON SCHEMA workspace.tema_hr_semantic;
SHOW GRANTS ON SCHEMA workspace.tema_hr_gold;      -- expect no `account users` rows

-- What the docs say (write this in your governance doc): a metric view runs its source query with the
-- view owner's rights, like a standard view, so readers need SELECT on the metric view only, not on
-- the gold tables. Row filters and column masks on the source tables still apply to the reader.
-- Check the current "metric view permissions" page before relying on this at work.

-- -------------------------------------------------------------------------------------
-- Step 3. Certify and deprecate
-- Certification is a system tag in current releases. If SET TAGS refuses the key, use the
-- Certified / Deprecated badges in Catalog Explorer instead and note it.
-- -------------------------------------------------------------------------------------
ALTER VIEW workspace.tema_hr_semantic.workforce_metrics          SET TAGS ('system.certification_status' = 'certified');
ALTER VIEW workspace.tema_hr_semantic.retention_metrics          SET TAGS ('system.certification_status' = 'certified');
ALTER VIEW workspace.tema_hr_semantic.talent_acquisition_metrics SET TAGS ('system.certification_status' = 'certified');
ALTER VIEW workspace.tema_hr_semantic.experience_metrics         SET TAGS ('system.certification_status' = 'certified');
ALTER VIEW workspace.tema_hr_semantic.pay_metrics                SET TAGS ('system.certification_status' = 'certified');
ALTER TABLE workspace.tema_hr_gold.fact_headcount_monthly        SET TAGS ('system.certification_status' = 'certified');
ALTER TABLE workspace.tema_hr_gold.dim_employee                  SET TAGS ('system.certification_status' = 'certified');
ALTER VIEW workspace.tema_hr_semantic.v_headcount_naive          SET TAGS ('system.certification_status' = 'deprecated');

-- Step 5 (adoption and access dashboard queries) is in 04_adoption_and_access_queries.sql.
