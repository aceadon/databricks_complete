-- =====================================================================================
-- Tema reference build · Week 5 · experience_metrics
-- labs/week-05, step 2 ("Your turn"). eNPS by cycle: -7.1 (2023-H1) to +16.7 (2026-H1).
-- =====================================================================================
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.experience_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema engagement survey results, twice a year (May and November). One row per response. Report aggregates only."
source: workspace.tema_hr_gold.fact_engagement
joins:
  - name: dept
    source: workspace.tema_hr_gold.dim_department
    on: source.department_id = dept.department_id
dimensions:
  - name: survey_cycle
    expr: source.survey_cycle
    display_name: Survey cycle
  - name: division
    expr: dept.division
    display_name: Division
  - name: department
    expr: dept.department_name
    display_name: Department
measures:
  - name: responses
    display_name: Responses
    expr: COUNT(1)
  - name: enps
    display_name: eNPS
    comment: "% promoters (9-10) minus % detractors (0-6). Ranges from -100 to +100. Never average enps_score."
    synonyms: ["employee net promoter score", "net promoter"]
    expr: try_divide(100.0 * (COUNT(1) FILTER (WHERE source.enps_score >= 9) - COUNT(1) FILTER (WHERE source.enps_score <= 6)), COUNT(1))
  - name: engagement_score
    display_name: Engagement score
    comment: "Average engagement index, 1 (low) to 5 (high)."
    expr: AVG(source.engagement_score)
  - name: manager_score
    display_name: Manager score
    comment: "Average rating of the direct manager, 1 to 5."
    expr: AVG(source.manager_score)
$$;
