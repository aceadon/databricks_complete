-- =====================================================================================
-- People Analytics Assistant · trusted example SQL (Week 7, step 3)
-- Add each as an example query with the question as its title.
-- =====================================================================================

-- How many people did we have at the end of each quarter?
SELECT quarter, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.workforce_metrics
GROUP BY ALL ORDER BY quarter;

-- What is attrition by division?
SELECT division,
       MEASURE(attrition_rate_t12m)           AS attrition,
       MEASURE(voluntary_attrition_rate_t12m) AS voluntary,
       MEASURE(regretted_attrition_rate_t12m) AS regretted
FROM workspace.tema_hr_semantic.retention_metrics
WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY attrition DESC;

-- How does hiring for AI compare with the rest of Tema since the AI boom?
SELECT is_ai_division,
       MEASURE(median_time_to_fill_days) AS median_days_to_fill,
       MEASURE(offer_acceptance_rate)    AS offer_acceptance
FROM workspace.tema_hr_semantic.talent_acquisition_metrics
WHERE opened_date >= '2025-05-01' AND status = 'Filled'
GROUP BY ALL;

-- What was our average headcount last year?
SELECT AVG(headcount) AS average_headcount
FROM (SELECT month, MEASURE(headcount) AS headcount
      FROM workspace.tema_hr_semantic.workforce_metrics
      WHERE year = 2025 GROUP BY ALL);
