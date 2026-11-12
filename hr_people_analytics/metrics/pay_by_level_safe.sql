-- =====================================================================================
-- Tema reference build · Week 9 · pay_by_level_safe
-- labs/week-09, step 1, approach 1: a suppressed view on top of pay_metrics. Run after pay_metrics.sql.
-- Groups under 5 people come back NULL (13 division x level groups in Oct 2026 at 5,000 people).
-- =====================================================================================
CREATE OR REPLACE VIEW workspace.tema_hr_semantic.pay_by_level_safe
COMMENT 'Average compa-ratio by month, division and job level. Groups under 5 people are suppressed (NULL). Use this for dashboards.'
AS
SELECT month, division, job_level,
       CASE WHEN headcount >= 5 THEN avg_compa_ratio END AS avg_compa_ratio,
       CASE WHEN headcount >= 5 THEN headcount END       AS headcount,
       headcount < 5                                     AS is_suppressed
FROM (SELECT month, division, job_level,
             MEASURE(avg_compa_ratio) AS avg_compa_ratio, MEASURE(headcount) AS headcount
      FROM workspace.tema_hr_semantic.pay_metrics GROUP BY ALL);
