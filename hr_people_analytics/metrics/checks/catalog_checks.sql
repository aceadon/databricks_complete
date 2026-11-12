-- =====================================================================================
-- Tema reference · Week 5 · the Phase 2 checkpoint, one short MEASURE() query each (5,000 people)
-- =====================================================================================
-- 1. Voluntary attrition by division, this year vs last (see attrition_truth.sql for the values)
SELECT month, division, MEASURE(voluntary_attrition_rate_t12m) AS voluntary
FROM workspace.tema_hr_semantic.retention_metrics
WHERE month IN ('2025-10-31', '2026-10-31')
GROUP BY ALL ORDER BY division, month;

-- 2. Lowest average compa-ratio by job level: IC4 ≈ 1.024 (ignore E1, E2: one person each)
SELECT job_level, MEASURE(avg_compa_ratio) AS avg_compa_ratio, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.pay_metrics WHERE month = '2026-10-31'
GROUP BY ALL ORDER BY avg_compa_ratio;

-- 3. AI vs rest since the AI boom, filled roles: median 67 vs 41 days, offer acceptance ≈ 70% vs 84%
SELECT is_ai_division, MEASURE(median_time_to_fill_days) AS median_days,
       MEASURE(offer_acceptance_rate) AS offer_acceptance, MEASURE(requisitions) AS requisitions
FROM workspace.tema_hr_semantic.talent_acquisition_metrics
WHERE opened_date >= '2025-05-01' AND status = 'Filled'
GROUP BY ALL;

-- 4. Headcount at the end of each quarter of 2026 (quarter-end values, not sums)
SELECT quarter, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.workforce_metrics WHERE year = 2026
GROUP BY ALL ORDER BY quarter;

-- 5. eNPS by cycle: -7.1, -1.4, +3.8, +8.7, +12.8, +12.2, +16.7
SELECT survey_cycle, MEASURE(enps) AS enps, MEASURE(responses) AS responses
FROM workspace.tema_hr_semantic.experience_metrics
GROUP BY ALL ORDER BY survey_cycle;

-- 6. Open requisitions today: 79
SELECT MEASURE(open_requisitions) FROM workspace.tema_hr_semantic.talent_acquisition_metrics;
