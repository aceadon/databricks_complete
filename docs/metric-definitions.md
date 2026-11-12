# Metric definitions

One entry per metric. The metric view YAML in `hr_people_analytics/metrics/` must match these definitions.

---

# Workforce metrics

**Metric view:** `workspace.tema_hr_semantic.workforce_metrics`
**Source file:** [`hr_people_analytics/metrics/workforce_metrics.sql`](../hr_people_analytics/metrics/workforce_metrics.sql)
**Grain:** `workspace.tema_hr_gold.fact_headcount_monthly`, one row per employee per month they were employed
**Joins:** `dim_date` (as `dt`, on `snapshot_month = month_end`), `dim_department` (as `dept`), `dim_job` (as `job`), `dim_location` (as `loc`)

### Dimensions

| Dimension | Display name | Comes from |
|---|---|---|
| `month` | Month | `fact_headcount_monthly.snapshot_month` (month-end date) |
| `quarter` | Quarter | `dim_date.year_quarter` (for example `2025-Q2`) |
| `year` | Year | `dim_date.year` |
| `division` | Division | `dim_department.division` |
| `department` | Department | `dim_department.department_name` |
| `job_level` | Job level | `dim_job.job_level` |
| `job_track` | Job track | `dim_job.job_track` |
| `region` | Region | `dim_location.region` |
| `city` | City | `dim_location.city` |
| `employment_type` | Employment type | `fact_headcount_monthly.employment_type` (Full-time or Part-time) |

### How the measures behave over time

- **Semi-additive (last month wins):** Headcount, FTE, Average base salary and Span of control. Each uses `window: order: month, range: current, semiadditive: last`, so a quarter or a year shows the value for its **last month**, not a sum. These still add up across departments, divisions and other non-time dimensions.
- **Additive:** Hires, Leavers and Net change. A quarter is the sum of its months.

---

## Headcount

| | |
|---|---|
| **Definition** | People employed at the end of the period |
| **Owner** | People Analytics lead |
| **Formula** | `COUNT(DISTINCT employee_id) FILTER (WHERE is_active_month_end)` |
| **Time behaviour** | Semi-additive: for a quarter or year, the last month's value. Add across departments, never across months |
| **Includes** | Full-time and part-time employees |
| **Excludes** | People not active at month end, such as anyone who left during the month |
| **Synonyms** | employees, number of people, staff |
| **Metric view** | `workspace.tema_hr_semantic.workforce_metrics.headcount` |
| **Status** | Certified (Week 9) |
| **Caveats** | A part-timer counts as 1. Use FTE when comparing cost or capacity |

## FTE

| | |
|---|---|
| **Definition** | Full-time equivalents at the end of the period |
| **Owner** | People Analytics lead |
| **Formula** | `SUM(fte) FILTER (WHERE is_active_month_end)` |
| **Time behaviour** | Semi-additive, like Headcount |
| **Includes** | Full-time employees (FTE 1.0) and part-time employees at their FTE (0.5, 0.6 or 0.8 in the Tema data) |
| **Excludes** | People not active at month end |
| **Metric view** | `workspace.tema_hr_semantic.workforce_metrics.fte` |
| **Status** | Certified (Week 9) |
| **Caveats** | Part-time FTE comes from the HR record; a change in hours shows up from the next month end |

## Hires

| | |
|---|---|
| **Definition** | People who joined in the period |
| **Owner** | People Analytics lead |
| **Formula** | `COUNT(1) FILTER (WHERE is_hire_in_month)` |
| **Time behaviour** | Additive: a quarter is the sum of its months |
| **Includes** | Full-time and part-time hires |
| **Excludes** | Internal transfers and promotions (not hires). Rehires are not modelled in Tema |
| **Metric view** | `workspace.tema_hr_semantic.workforce_metrics.hires` |
| **Status** | Certified (Week 9) |
| **Caveats** | Counts employee-month rows flagged as a hire month, not distinct people |

## Leavers

| | |
|---|---|
| **Definition** | People who left in the period, voluntary and involuntary |
| **Owner** | People Analytics lead |
| **Formula** | `COUNT(1) FILTER (WHERE is_termination_in_month)` |
| **Time behaviour** | Additive |
| **Includes** | Voluntary and involuntary leavers |
| **Excludes** | Internal transfers. Unlike the attrition rates, this simple count still includes part-time leavers after the Week 10 change |
| **Metric view** | `workspace.tema_hr_semantic.workforce_metrics.leavers` |
| **Status** | Certified (Week 9) |
| **Caveats** | The fact table also has voluntary and regretted flags. Their trailing 12-month rates live in `retention_metrics` |

## Net change

| | |
|---|---|
| **Definition** | Hires minus leavers |
| **Owner** | People Analytics lead |
| **Formula** | `MEASURE(hires) - MEASURE(leavers)` |
| **Time behaviour** | Additive, because both inputs are additive |
| **Includes** | Same as Hires and Leavers |
| **Excludes** | Internal transfers |
| **Metric view** | `workspace.tema_hr_semantic.workforce_metrics.net_change` |
| **Status** | Certified (Week 9) |
| **Caveats** | People who move between departments are not hires or leavers, so Net change for one department will not always match the change in its Headcount |

## Average base salary

| | |
|---|---|
| **Definition** | Average annual base salary of people employed at the end of the period |
| **Owner** | People Analytics lead |
| **Formula** | `AVG(annual_base_salary) FILTER (WHERE is_active_month_end)` |
| **Time behaviour** | Semi-additive: the last month's average |
| **Includes** | Full-time and part-time employees |
| **Excludes** | People not active at month end. Bonus and equity are not included |
| **Metric view** | `workspace.tema_hr_semantic.workforce_metrics.average_salary` |
| **Status** | Certified (Week 9) |
| **Caveats** | Salary is sensitive. Small groups (for example one city and job level) can reveal an individual's pay, so this needs suppression or access rules before sharing widely |

## Span of control

| | |
|---|---|
| **Definition** | Number of non-managers per manager at the end of the period |
| **Owner** | People Analytics lead |
| **Formula** | Distinct active employees whose job is not a manager job ÷ distinct active employees whose job is a manager job (`dim_job.is_manager`) |
| **Time behaviour** | Semi-additive: the last month's ratio |
| **Includes** | Everyone active at month end, split by `job.is_manager` |
| **Excludes** | People not active at month end |
| **Metric view** | `workspace.tema_hr_semantic.workforce_metrics.span_of_control` |
| **Status** | Certified (Week 9) |
| **Caveats** | This is a ratio for the slice, not the average of each manager's direct reports. A slice with no managers (for example a single job level of ICs) divides by zero |

---

# Retention metrics

**Metric view:** `workspace.tema_hr_semantic.retention_metrics`
**Source file:** [`hr_people_analytics/metrics/retention_metrics.sql`](../hr_people_analytics/metrics/retention_metrics.sql) (Week 4, changed in Week 10)
**Grain:** `workspace.tema_hr_gold.fact_headcount_monthly`, one row per employee per month they were employed
**Joins:** same as Workforce metrics (`dt`, `dept`, `job`, `loc`)

### Rules shared by every attrition rate

- **Shape:** leavers in the 12 months ending with the period ÷ average month-end headcount over the same 12 months. Always divide the two totals; never average monthly rates.
- **Window:** the 12 months *including* the period's month. October 2026 means November 2025 to October 2026. Check with `checks/attrition_truth.sql`: 12.9% for October 2026 (13.1% before Week 10). If the metric view returns a slightly higher number (13.3% before Week 10), its `trailing 12 month` window excludes the current month, and this line must be changed to say so.
- **Time behaviour:** each rate is already a 12-month figure, so for a quarter or year it shows the value at the **last month** (semi-additive). Never add or average across months.
- **Last day of the month:** a person who leaves on the last day of a month is a leaver **in that month** (`termination_date <= month_end`), and is not in that month's month-end headcount. Someone leaving on 31 October counts in October, not November.
- **Transfers:** a move between departments is not a leaver, at Tema or in the department they left. A leaver is counted in the department, job and location they held on their last day. A transferred person sits in each department's average headcount only for the months they were there.
- **Part-time employees (changed in Week 10):** excluded from every attrition rate, from both the leavers and the average headcount. Approved by the People Analytics lead with the CHRO's delegate, because it changes a number reported to the leadership team. Effect at 5,000 people, October 2026: 13.1% → 12.9% (608 / 4,655 → 581 / 4,488). Excluding part-timers from leavers only would give 12.5%, which is wrong.
- **Interns and contractors:** not in the Tema data. The workforce is employees only. If interns are added later, decide and record here whether they are excluded, the same way as part-timers.
- **Rehires:** not modelled in the Tema data. Each `employee_id` has at most one hire and one leaving date.

## Attrition rate (trailing 12 months)

| | |
|---|---|
| **Definition** | Share of the workforce that left over the last 12 months, for any reason. The default meaning of "attrition" at Tema |
| **Owner** | People Analytics lead |
| **Formula** | `MEASURE(leavers_t12m) / MEASURE(avg_headcount_t12m)`, where `leavers_t12m = COUNT(1) FILTER (WHERE is_termination_in_month)` and `avg_headcount_t12m = COUNT(1) FILTER (WHERE is_active_month_end) / COUNT(DISTINCT snapshot_month)`, both over the trailing 12 months |
| **Time behaviour** | Trailing 12 months, semi-additive (last month wins). See the shared rules above |
| **Includes** | Voluntary and involuntary leavers (including layoffs), Full-time employees only |
| **Excludes** | Part-time employees (Week 10). Internal transfers. Interns and contractors (none in the Tema data) |
| **Synonyms** | attrition, turnover, attrition rate, churn |
| **Metric view** | `workspace.tema_hr_semantic.retention_metrics.attrition_rate_t12m` |
| **Status** | Certified (Week 9) |
| **Caveats** | Check values at 5,000 people: 11.8% for October 2025, 12.9% for October 2026 (581 leavers ÷ 4,488 average headcount); before the Week 10 change 12.0% and 13.1%. A layoff month (January 2023) lifts this rate for the next 12 months, so use the voluntary rate to judge whether people are choosing to leave |

## Voluntary attrition rate (trailing 12 months)

| | |
|---|---|
| **Definition** | Share of the workforce that resigned over the last 12 months |
| **Owner** | People Analytics lead |
| **Formula** | `MEASURE(voluntary_leavers_t12m) / MEASURE(avg_headcount_t12m)`, where `voluntary_leavers_t12m = COUNT(1) FILTER (WHERE is_voluntary_termination_in_month)` (`termination_type = 'Voluntary'`) |
| **Time behaviour** | Trailing 12 months, semi-additive (last month wins) |
| **Includes** | People who resigned, for any reason (career growth, compensation, manager, relocation, work-life balance, competitor offer, other) |
| **Excludes** | Part-time employees (Week 10). Involuntary leavers (performance, restructuring, policy violation, layoffs). Internal transfers. Interns and contractors (none in the Tema data) |
| **Synonyms** | voluntary turnover, resignation rate, voluntary attrition |
| **Metric view** | `workspace.tema_hr_semantic.retention_metrics.voluntary_attrition_rate_t12m` |
| **Status** | Certified (Week 9) |
| **Caveats** | Denominator is the **whole** workforce, not only people who could resign. Check values at 5,000 people: 9.3% for October 2025, 9.9% for October 2026 (9.4% and 10.0% before Week 10). Voluntary + involuntary = all attrition |

## Regretted attrition rate (trailing 12 months)

| | |
|---|---|
| **Definition** | Share of the workforce that left over the last 12 months whom Tema wanted to keep |
| **Owner** | People Analytics lead |
| **Formula** | `MEASURE(regretted_leavers_t12m) / MEASURE(avg_headcount_t12m)`, where `regretted_leavers_t12m = COUNT(1) FILTER (WHERE is_regretted_termination_in_month)` (`is_regretted = true`) |
| **Time behaviour** | Trailing 12 months, semi-additive (last month wins) |
| **Includes** | Leavers flagged `is_regretted`. In practice these are all voluntary leavers, because involuntary leavers are always `false` |
| **Excludes** | Part-time employees (Week 10). Involuntary leavers. Voluntary leavers not flagged as regretted. Current employees (`is_regretted` is only set for leavers, and the fact flag treats empty as false). Internal transfers. Interns and contractors (none in the Tema data) |
| **Synonyms** | regretted turnover, regretted losses, regrettable attrition |
| **Metric view** | `workspace.tema_hr_semantic.retention_metrics.regretted_attrition_rate_t12m` |
| **Status** | Certified (Week 9) |
| **Caveats** | A subset of voluntary attrition, so it is always lower. Denominator is the whole workforce, not "people we'd regret losing". Check values at 5,000 people: 3.6% for October 2025, 4.2% for October 2026 (4.3% before Week 10); AI is highest at about 10%. Who sets the flag, and when, needs an owner: a flag recorded by the manager after the person leaves can be biased |

## First-year attrition rate (trailing 12 months)

| | |
|---|---|
| **Definition** | Share of people in their first year at Tema who left over the last 12 months |
| **Owner** | People Analytics lead |
| **Formula** | `MEASURE(first_year_leavers_t12m) / MEASURE(first_year_avg_headcount_t12m)`, where both pieces add `AND is_first_year` (`tenure_months < 12`) to the leavers and headcount filters above |
| **Time behaviour** | Trailing 12 months, semi-additive (last month wins) |
| **Includes** | Voluntary and involuntary leavers with under 12 months' tenure. The denominator is only people with under 12 months' tenure, not the whole workforce |
| **Excludes** | Part-time employees (Week 10). Leavers with 12 months' tenure or more. Internal transfers (tenure counts from hire date, so a transfer does not restart someone's first year). Interns and contractors (none in the Tema data) |
| **Synonyms** | new hire attrition, early attrition, first-year turnover |
| **Metric view** | `workspace.tema_hr_semantic.retention_metrics.first_year_attrition_rate_t12m` |
| **Status** | Certified (Week 9) |
| **Caveats** | Tenure is measured at the **month end** of each row, so someone who leaves on day 360 but whose month end falls after their first anniversary counts as a second-year leaver. Check values at 5,000 people: 20.9% for October 2025, 24.0% for October 2026 (21.3% and 24.0% before Week 10), close to double the overall rate. For a voluntary-only version, add a separate measure (`first_year_voluntary_attrition_rate_t12m`) rather than filtering this one |


---

# Talent acquisition metrics

**Metric view:** `workspace.tema_hr_semantic.talent_acquisition_metrics`
**Source file:** [`hr_people_analytics/metrics/talent_acquisition_metrics.sql`](../hr_people_analytics/metrics/talent_acquisition_metrics.sql) (Week 5)
**Grain:** `workspace.tema_hr_gold.fact_requisitions`, one row per opened role
**Dimensions:** `opened_month`, `opened_date`, `status`, `division`, `is_ai_division`, `department`, `job_level`

## Median time to fill

| | |
|---|---|
| **Definition** | Typical number of calendar days from opening a role to filling it |
| **Owner** | Head of Talent Acquisition |
| **Formula** | `MEDIAN(days_to_fill)`, where `days_to_fill = datediff(filled_date, opened_date)` for filled roles |
| **Time behaviour** | Not additive. Slice by `opened_date` or `opened_month`: a role belongs to the month it was opened |
| **Includes** | Filled requisitions |
| **Excludes** | Open and cancelled requisitions (they have no time to fill) |
| **Synonyms** | time to hire, days to fill, time to fill |
| **Metric view** | `talent_acquisition_metrics.median_time_to_fill_days` |
| **Status** | Certified (Week 9) |
| **Caveats** | Median, not mean, because a few very slow senior searches skew the average. Since May 2025 at 5,000 people: AI 67 days vs 41 for the rest. Calendar days, not working days. "Time to hire" sometimes means application to offer; Tema's means opened to filled |

## Offer acceptance rate

| | |
|---|---|
| **Definition** | Share of offers made that candidates accepted |
| **Owner** | Head of Talent Acquisition |
| **Formula** | `SUM(offers_accepted) / SUM(offers_extended)` |
| **Time behaviour** | Ratio of totals: never average the rates of several months |
| **Includes** | All requisitions in the slice, including ones still open that have extended offers |
| **Excludes** | Nothing |
| **Metric view** | `talent_acquisition_metrics.offer_acceptance_rate` |
| **Status** | Certified (Week 9) |
| **Caveats** | Since May 2025, filled roles at 5,000 people: AI about 70% vs 84% elsewhere, the clearest sign of a competitive AI market |

## Applicants per hire

| | |
|---|---|
| **Definition** | Applicants per filled role |
| **Owner** | Head of Talent Acquisition |
| **Formula** | `SUM(applicants) FILTER (status = 'Filled') / COUNT(1) FILTER (status = 'Filled')` |
| **Time behaviour** | Ratio of totals |
| **Includes** | Filled requisitions only |
| **Excludes** | Open and cancelled requisitions |
| **Metric view** | `talent_acquisition_metrics.applicants_per_hire` |
| **Status** | Certified (Week 9) |
| **Caveats** | Assumes one hire per requisition, which holds in the Tema data |

## Open requisitions

| | |
|---|---|
| **Definition** | Roles currently open |
| **Owner** | Head of Talent Acquisition |
| **Formula** | `COUNT(1) FILTER (WHERE status = 'Open')` |
| **Time behaviour** | A current-state count, not a history. It can't tell you how many roles were open last March |
| **Includes** | Requisitions with status Open |
| **Excludes** | Filled and cancelled requisitions |
| **Synonyms** | open roles, open reqs, vacancies |
| **Metric view** | `talent_acquisition_metrics.open_requisitions` |
| **Status** | Certified (Week 9) |
| **Caveats** | 79 at 5,000 people. A history of open roles would need a monthly snapshot fact |

---

# Pay metrics

**Metric view:** `workspace.tema_hr_semantic.pay_metrics` (restricted: not granted to the broad audience)
**Source file:** [`hr_people_analytics/metrics/pay_metrics.sql`](../hr_people_analytics/metrics/pay_metrics.sql) (Weeks 5 and 9)
**Grain:** `fact_headcount_monthly`, same joins as Workforce metrics
**Safe version for dashboards:** `tema_hr_semantic.pay_by_level_safe` (Week 9)

## Average compa-ratio

| | |
|---|---|
| **Definition** | How people are paid relative to the midpoint of their salary band, adjusted for location |
| **Owner** | Head of Total Rewards |
| **Formula** | `AVG(annual_base_salary / (salary_band_mid × location_pay_factor))` over people active at period end |
| **Time behaviour** | Semi-additive: the last month's value |
| **Includes** | Full-time and part-time employees (salary is the full-time rate) |
| **Excludes** | People not active at month end. Bonus and equity |
| **Synonyms** | compa ratio, pay vs midpoint |
| **Metric view** | `pay_metrics.avg_compa_ratio`; suppressed version `pay_metrics.avg_compa_ratio_safe` |
| **Status** | Certified (Week 9), restricted |
| **Caveats** | 1.00 = paid at midpoint. October 2026: IC4 lowest (about 1.02), M1 highest (about 1.10). E1 and E2 are one person each and must never be shown. Without `location_pay_factor`, everyone outside San Francisco looks underpaid |

## Salary vs department average (stretch)

| | |
|---|---|
| **Definition** | Each person's salary relative to their department's average in the same month, averaged over the slice |
| **Owner** | Head of Total Rewards |
| **Formula** | `AVG(salary / department average salary)`, the denominator fixed at department grain (an LOD expression) |
| **Time behaviour** | Semi-additive |
| **Includes / Excludes** | As Average compa-ratio |
| **Metric view** | Not built in the reference: LOD syntax is new. The truth query is in `solutions/week-05-experience-and-pay-metrics.sql` |
| **Status** | Proposed |
| **Caveats** | Always about 1.00 when grouped by department; useful only when grouped by something finer |

## Pay equity (gender compa-ratio gap)

| | |
|

---

# Experience metrics

**Metric view:** `workspace.tema_hr_semantic.experience_metrics`
**Source file:** [`hr_people_analytics/metrics/experience_metrics.sql`](../hr_people_analytics/metrics/experience_metrics.sql) (Week 5)
**Grain:** `fact_engagement`, one row per survey response (May and November each year)

## eNPS

| | |
|---|---|
| **Definition** | Employee net promoter score: how likely people are to recommend Tema as a place to work |
| **Owner** | Employee Listening lead |
| **Formula** | `100 × (promoters − detractors) / responses`, where promoters score 9–10 and detractors 0–6 |
| **Time behaviour** | One value per survey cycle. Never add or average across cycles or divisions; the metric view recomputes it for any slice |
| **Includes** | Every response in the cycle |
| **Excludes** | People who didn't respond |
| **Synonyms** | employee net promoter score, net promoter |
| **Metric view** | `experience_metrics.enps` |
| **Status** | Certified (Week 9) |
| **Caveats** | −7.1 in 2023-H1 (after the January 2023 layoffs) to +16.7 in 2026-H1. Averaging the raw 0–10 score gives about 7.6, which is not eNPS. Report only for groups of 5 or more respondents |

## Engagement score

| | |
|---|---|
| **Definition** | Average engagement index, 1 (low) to 5 (high) |
| **Owner** | Employee Listening lead |
| **Formula** | `AVG(engagement_score)` |
| **Time behaviour** | One value per cycle |
| **Includes / Excludes** | As eNPS |
| **Metric view** | `experience_metrics.engagement_score` (and `manager_score`) |
| **Status** | Certified (Week 9) |
| **Caveats** | Individual answers are confidential: aggregates only, minimum 5 respondents |

---

# Business metrics (Week 11)

**Metric view:** `workspace.tema_hr_semantic.business_metrics`
**Source file:** [`hr_people_analytics/metrics/business_metrics.sql`](../hr_people_analytics/metrics/business_metrics.sql)
**Grain:** `fact_business_monthly`, one row per month. **Synthetic** numbers sized for 70,000 people

| Measure | Owner | Formula | Time behaviour | Caveats |
|---|---|---|---|---|
| `ad_revenue` | Finance (FP&A) | `SUM(ad_revenue_usd)` | Additive | 2026-Q4 has only October: check `months_with_data` |
| `support_tickets` | Advertiser Support operations | `SUM(support_tickets)` | Additive | Opened tickets, not resolved |
| `months_with_data` | People Analytics lead | `COUNT(1)` | Additive | Exists to catch partial periods |

**Revenue per employee** (cross-domain, Week 11): quarter's `ad_revenue` ÷ quarter-end `headcount`. A ratio of an additive measure and a semi-additive one, so compute it from the two metric views in one query, never by summing monthly ratios. 2025-Q2 at 5,000 people: about $189.6k (revenue is sized for 70,000 people, so compare the trend, not the level).
