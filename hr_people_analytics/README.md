# Tema people analytics

The running project for the [zero to semantic hero plan](../plan/zero-to-semantic-hero.md). **Tema** is a fictional software company that sells ads on its social media platform, with about 70,000 employees and an AI team that has grown roughly sixfold since May 2025. All data is synthetic.

## Run order

This is the **finished** version: every file is the end state of its lab. `reference/00_build_reference` runs them all in this order for you.

| Step | Notebook / folder | Weeks | Creates |
|---|---|---|---|
| 0 | [`00_generate_hr_data.py`](00_generate_hr_data.py) | 0 | `tema_hr_raw` schema: 12 source tables |
| 1 | [`gold/`](gold/) | 1, 2, 11 | `tema_hr_gold` star schema with keys, comments and tags, plus synthetic business data |
| 2 | [`metrics/`](metrics/) | 3–5, 9–11 | `tema_hr_semantic`: six metric views and a suppressed pay view |
| 3 | [`dashboards/`](dashboards/), [`genie/`](genie/) | 6, 7 | Workforce Overview dashboard, Genie instructions, example SQL and the benchmark |
| 4 | [`governance/`](governance/) | 8, 9 | `tema_hr_secure` HRBP access model, the act-as activity, grants, certification and audit queries |

## Source tables (`tema_hr_raw`)

| Table | Grain |
|---|---|
| `employees` | One row per person ever employed, including sensitive fields |
| `job_history` | One row per job assignment period (hire, promotion, transfer, merit increase) |
| `headcount_monthly` | One row per employee per month they were employed |
| `departments`, `jobs`, `locations` | Dimensions |
| `requisitions` | One row per opened role |
| `absences` | One row per absence |
| `engagement_surveys` | One row per survey response (twice a year) |
| `performance_reviews` | One row per employee per year |
| `equity_grants` | One row per stock grant |
| `hrbp_assignments` | One row per HRBP-to-leader coverage period |

## Schema naming

`tema_hr_raw` (generated source) → `tema_hr_gold` (clean star schema) → `tema_hr_semantic` (metric views) → `tema_hr_secure` (governed, masked tables). All live in your workspace catalog, usually `workspace` in Free Edition.
