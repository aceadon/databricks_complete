-- =====================================================================================
-- Tema reference build · Week 5 · talent_acquisition_metrics
-- labs/week-05, step 1, plus the is_ai_division dimension the lab's warning box suggests
-- ("AI" is a business concept worth naming). Since May 2025, filled roles: AI median 67 days vs 41,
-- offer acceptance about 70% vs 84%. Checks: metrics/checks/catalog_checks.sql
-- =====================================================================================
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.talent_acquisition_metrics
WITH METRICS LANGUAGE YAML AS $$
version: 1.1
comment: "Tema hiring funnel, one row per requisition. Time to fill counts calendar days from opened to filled."
source: workspace.tema_hr_gold.fact_requisitions
joins:
  - name: dept
    source: workspace.tema_hr_gold.dim_department
    on: source.department_id = dept.department_id
  - name: job
    source: workspace.tema_hr_gold.dim_job
    on: source.job_id = job.job_id
dimensions:
  - name: opened_month
    expr: last_day(source.opened_date)
    display_name: Month opened
  - name: opened_date
    expr: source.opened_date
    display_name: Date opened
  - name: status
    expr: source.status
    display_name: Status
  - name: division
    expr: dept.division
    display_name: Division
  - name: is_ai_division
    expr: dept.division = 'AI'
    display_name: Is AI division
  - name: department
    expr: dept.department_name
    display_name: Department
  - name: job_level
    expr: job.job_level
    display_name: Job level
measures:
  - name: requisitions
    display_name: Requisitions
    expr: COUNT(1)
  - name: open_requisitions
    display_name: Open requisitions
    comment: "Requisitions with status Open. Not a time series: it is today's open roles for whatever slice you pick."
    synonyms: ["open roles", "open reqs", "vacancies"]
    expr: COUNT(1) FILTER (WHERE source.status = 'Open')
  - name: median_time_to_fill_days
    display_name: Median time to fill (days)
    comment: "Median calendar days from opened to filled, over filled requisitions. Open and cancelled roles have no time to fill and are left out."
    synonyms: ["time to hire", "days to fill", "time to fill"]
    expr: MEDIAN(source.days_to_fill)
  - name: offer_acceptance_rate
    display_name: Offer acceptance rate
    comment: "Offers accepted divided by offers extended."
    expr: try_divide(SUM(source.offers_accepted), SUM(source.offers_extended))
  - name: applicants_per_hire
    display_name: Applicants per hire
    expr: try_divide(SUM(source.applicants) FILTER (WHERE source.status = 'Filled'), COUNT(1) FILTER (WHERE source.status = 'Filled'))
$$;
