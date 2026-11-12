# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "6"
# ///
# MAGIC %md
# MAGIC # Generate synthetic HR data for Tema
# MAGIC
# MAGIC **Tema** is a fictional software company that sells ads on its social media platform.
# MAGIC This notebook creates a realistic, fully synthetic HR dataset for learning the Databricks
# MAGIC semantic layer. **No real people.** Never load real employee data into a personal or trial workspace.
# MAGIC
# MAGIC Monthly history from Jan 2023 to Oct 2026, scaled by the `target_headcount` widget
# MAGIC (default 70,000 employees at the end; use 5,000 for a quick run).
# MAGIC
# MAGIC Storyline and planted patterns:
# MAGIC - **Jan 2023 restructuring**: a round of layoffs, then a slow 2023 with limited backfills.
# MAGIC - **AI boom**: the AI division grows roughly sixfold from May 2025, hires skew senior and highly paid,
# MAGIC   and AI talent gets poached, so regretted attrition there is high.
# MAGIC - Trust & Safety Operations (content moderation) and Advertiser Support churn the most.
# MAGIC - Low engagement and below-band pay raise the chance of leaving; first-year attrition is high.
# MAGIC - Some managers have much better engagement (and lower attrition) than others.
# MAGIC - A small unexplained gender pay gap exists inside salary bands.
# MAGIC
# MAGIC
# MAGIC People organisation: a Chief People Officer reports to the CEO, with an HR Business Partners team
# MAGIC (about one HRBP per 950 employees). Every VP, and every director with 110+ recursive reports, is supported
# MAGIC by one or more HRBPs (`hrbp_assignments`); some HRBPs cover several leaders across divisions.
# MAGIC `equity_grants` holds new hire, refresh, promotion and AI retention grants. See `governance/` for the
# MAGIC HRBP access model built on these tables.
# MAGIC
# MAGIC Simplifications: salaries are in USD with a location factor; people managers never leave,
# MAGIC so the reporting hierarchy stays stable; new manager roles are filled by promotion or external hire.

# COMMAND ----------

import math
import numpy as np
import pandas as pd

COMPANY = "Tema"
EMAIL_DOMAIN = "tema.example"
AS_OF = pd.Timestamp("2026-10-31")
START = pd.Timestamp("2023-01-01")
AI_BOOM_START = pd.Timestamp("2025-05-01")
SPAN_TARGET = 9          # ICs per first-line manager before a new manager is added
DIRECTOR_SPAN = 7        # managers per director before a new director is added
VP_SPAN = 8              # directors per vice president before another VP is added
SVP_SPAN = 8             # vice presidents per senior vice president before another SVP is added

FIRST = ["Aisha", "Ben", "Carla", "Diego", "Elena", "Farid", "Grace", "Hiro", "Ines", "Jamal",
         "Kira", "Liam", "Maya", "Noah", "Olu", "Priya", "Quinn", "Rosa", "Sam", "Tara",
         "Umar", "Vera", "Wei", "Ximena", "Yusuf", "Zoe", "Ana", "Bilal", "Chloe", "Dev",
         "Emma", "Felix", "Gita", "Hugo", "Ivy", "Jon", "Lena", "Marco", "Nadia", "Omar",
         "Paula", "Raj", "Sofia", "Tom", "Uma", "Victor", "Wendy", "Yara", "Zane", "Leo",
         "Arjun", "Beatriz", "Chidi", "Daniela", "Eitan", "Fatima", "Gabriel", "Hana", "Ivan", "Julia",
         "Kwame", "Lucia", "Mateo", "Nia", "Oscar", "Pooja", "Rafael", "Sara", "Tomas", "Valentina"]
LAST = ["Adams", "Bauer", "Chen", "Diaz", "Evans", "Fischer", "Garcia", "Haddad", "Ito", "Jones",
        "Khan", "Lopez", "Martin", "Nguyen", "Okafor", "Patel", "Quinn", "Rossi", "Silva", "Tanaka",
        "Usman", "Varga", "Wang", "Xu", "Yilmaz", "Zhang", "Brown", "Costa", "Dubois", "Eriksen",
        "Ferreira", "Gomez", "Hughes", "Iqbal", "Kowalski", "Larsen", "Mendes", "Novak", "Olsen", "Park",
        "Reddy", "Santos", "Murphy", "Kim", "Mensah", "Sharma", "Oliveira", "Walsh", "Lee", "Ahmed"]

# location_id, city, country, region, pay factor
LOCATIONS = pd.DataFrame([
    (1, "San Francisco", "United States", "Americas", 1.00),
    (2, "New York", "United States", "Americas", 0.97),
    (3, "Seattle", "United States", "Americas", 0.95),
    (4, "Austin", "United States", "Americas", 0.85),
    (5, "Toronto", "Canada", "Americas", 0.72),
    (6, "Sao Paulo", "Brazil", "Americas", 0.42),
    (7, "London", "United Kingdom", "EMEA", 0.78),
    (8, "Dublin", "Ireland", "EMEA", 0.74),
    (9, "Singapore", "Singapore", "APAC", 0.75),
    (10, "Bangalore", "India", "APAC", 0.32),
], columns=["location_id", "city", "country", "region", "location_pay_factor"])
LOC_PAY = dict(zip(LOCATIONS.location_id, LOCATIONS.location_pay_factor))
LOC_PROFILE = {  # location mix by kind of team (same order as LOCATIONS)
    "tech":     [0.30, 0.10, 0.18, 0.06, 0.08, 0.02, 0.10, 0.04, 0.04, 0.08],
    "ai":       [0.45, 0.12, 0.15, 0.00, 0.06, 0.00, 0.14, 0.00, 0.03, 0.05],
    "business": [0.14, 0.24, 0.04, 0.08, 0.06, 0.08, 0.16, 0.08, 0.08, 0.04],
    "ops":      [0.02, 0.02, 0.00, 0.14, 0.00, 0.18, 0.02, 0.20, 0.08, 0.34],
    "corp":     [0.30, 0.20, 0.08, 0.10, 0.04, 0.02, 0.10, 0.06, 0.04, 0.06],
}

# department_id, name, division, cost_center, start share, attrition factor, pay factor, location profile, hire level mix
DEPTS = [
    (101, "Core Platform", "Engineering", "CC-1010", 0.090, 0.85, 1.35, "tech", "eng"),
    (102, "Feed & Ranking", "Engineering", "CC-1020", 0.050, 0.85, 1.40, "tech", "eng"),
    (103, "Ads Engineering", "Engineering", "CC-1030", 0.060, 0.85, 1.38, "tech", "eng"),
    (104, "Infrastructure & SRE", "Engineering", "CC-1040", 0.055, 0.90, 1.30, "tech", "eng"),
    (105, "Security Engineering", "Engineering", "CC-1050", 0.020, 0.85, 1.35, "tech", "eng"),
    (106, "Mobile & Web Clients", "Engineering", "CC-1060", 0.045, 0.90, 1.30, "tech", "eng"),
    (201, "AI Research", "AI", "CC-2010", 0.004, 1.20, 1.90, "ai", "ai"),
    (202, "Applied AI & ML", "AI", "CC-2020", 0.010, 1.25, 1.60, "ai", "ai"),
    (203, "AI Infrastructure", "AI", "CC-2030", 0.004, 1.15, 1.55, "ai", "ai"),
    (301, "Product Management", "Product & Design", "CC-3010", 0.040, 0.95, 1.30, "tech", "std"),
    (302, "Design & UX Research", "Product & Design", "CC-3020", 0.030, 0.95, 1.15, "tech", "std"),
    (303, "Data Science & Analytics", "Product & Design", "CC-3030", 0.030, 0.95, 1.25, "tech", "std"),
    (401, "Ads Sales", "Ads Business", "CC-4010", 0.100, 1.30, 1.05, "business", "std"),
    (402, "Agency & Partner Management", "Ads Business", "CC-4020", 0.040, 1.10, 1.00, "business", "std"),
    (403, "Advertiser Support", "Ads Business", "CC-4030", 0.060, 1.50, 0.65, "ops", "ops"),
    (404, "Marketing", "Ads Business", "CC-4040", 0.040, 1.05, 1.00, "business", "std"),
    (501, "Trust & Safety Operations", "Trust & Safety", "CC-5010", 0.100, 1.90, 0.55, "ops", "ops"),
    (502, "Policy", "Trust & Safety", "CC-5020", 0.012, 0.90, 1.05, "corp", "std"),
    (601, "Finance", "Corporate", "CC-6010", 0.030, 0.90, 1.05, "corp", "std"),
    (602, "People", "Corporate", "CC-6020", 0.030, 0.95, 0.95, "corp", "std"),
    (603, "Legal", "Corporate", "CC-6030", 0.015, 0.80, 1.25, "corp", "std"),
    (604, "IT", "Corporate", "CC-6040", 0.025, 0.95, 1.00, "corp", "std"),
    (605, "Workplace & Facilities", "Corporate", "CC-6050", 0.020, 1.10, 0.70, "ops", "ops"),
    # Small fixed teams created directly, never through regular hiring (share 0)
    (600, "Office of the CEO", "Corporate", "CC-6000", 0.0, 1.00, 1.00, "corp", "std"),
    (607, "HR Business Partners", "Corporate", "CC-6070", 0.0, 0.90, 1.00, "corp", "std"),
]
FIXED_DEPTS = {600, 607}
HRBP_PER_EMPLOYEES = 950        # roughly one HR business partner per this many employees
DIRECTOR_HRBP_THRESHOLD = 110   # directors with at least this many recursive reports get their own HRBP
DEPT_IDS = [d[0] for d in DEPTS]
DEPT = {d[0]: dict(name=d[1], division=d[2], share=d[4], attr=d[5], pay=d[6], loc=d[7], mix=d[8]) for d in DEPTS}
DEPT_SHARE = np.array([d[4] for d in DEPTS]); DEPT_SHARE = DEPT_SHARE / DEPT_SHARE.sum()
AI_DEPTS = {d for d in DEPT_IDS if DEPT[d]["division"] == "AI"}
DIVISIONS = sorted({d[2] for d in DEPTS})
DEPARTMENTS = pd.DataFrame([d[:4] for d in DEPTS], columns=["department_id", "department_name", "division", "cost_center"])

# level, is_manager, base midpoint (USD, San Francisco, pay factor 1.0), title
LEVELS = [
    ("IC1", False, 85000, "Associate"), ("IC2", False, 110000, "Specialist"), ("IC3", False, 140000, "Senior"),
    ("IC4", False, 175000, "Staff"), ("IC5", False, 215000, "Senior Staff"), ("IC6", False, 270000, "Principal"),
    ("M1", True, 190000, "Manager"), ("M2", True, 225000, "Senior Manager"), ("M3", True, 270000, "Director"),
    ("M4", True, 340000, "Vice President"), ("M5", True, 430000, "Senior Vice President"),
    ("E1", True, 600000, "Chief Executive Officer"),
    ("E2", True, 450000, "Chief People Officer"),
]
HRBP_TITLES = {"IC3": "HR Business Partner", "IC4": "Senior HR Business Partner", "IC5": "Principal HR Business Partner"}
EQUITY_HIRE_VALUE = {"IC3": 40000, "IC4": 90000, "IC5": 160000, "IC6": 300000, "M1": 100000, "M2": 160000,
                     "M3": 300000, "M4": 600000, "M5": 1200000, "E1": 4000000, "E2": 1500000}
LEVEL_ORDER = [l[0] for l in LEVELS]
HIRE_MIX = {  # IC hire level probabilities IC1..IC6
    "eng": [0.18, 0.30, 0.27, 0.15, 0.08, 0.02],
    "ai":  [0.03, 0.12, 0.25, 0.28, 0.22, 0.10],
    "std": [0.25, 0.32, 0.24, 0.12, 0.06, 0.01],
    "ops": [0.55, 0.30, 0.10, 0.04, 0.01, 0.00],
}


def _jobs():
    rows, jid = [], 1000
    for d in DEPTS:
        for lvl, is_mgr, mid, title in LEVELS:
            if (lvl == "E1") != (d[0] == 600) or (lvl == "E2" and d[0] != 602) or (d[0] == 607 and lvl not in HRBP_TITLES):
                continue
            m = round(mid * d[6], -3) if lvl not in ("E1", "E2") else mid
            if lvl in ("E1", "E2"):
                t = title
            elif d[0] == 607:
                t = HRBP_TITLES[lvl]
            elif lvl == "M5":
                t = f"{title}, {d[2]}"
            elif is_mgr:
                t = f"{title}, {d[1]}"
            else:
                t = f"{title} {d[1]}"
            rows.append((jid, d[0], d[1], t, lvl, is_mgr, round(m * 0.8, -3), m, round(m * 1.2, -3)))
            jid += 1
    return pd.DataFrame(rows, columns=["job_id", "department_id", "job_family", "job_title", "job_level",
                                       "is_manager", "salary_band_min", "salary_band_mid", "salary_band_max"])


def generate(target_headcount: int = 70000, seed: int = 42) -> dict:
    """Simulate Tema month by month. Returns a dict of pandas DataFrames (without the monthly snapshot,
    which `headcount_snapshots` builds month by month to keep memory low)."""
    rng = np.random.default_rng(seed)
    jobs = _jobs()
    job_of = {(r.department_id, r.job_level): r.job_id for r in jobs.itertuples()}
    band_mid = dict(zip(jobs.job_id, jobs.salary_band_mid))
    level_of = dict(zip(jobs.job_id, jobs.job_level))
    start_headcount = int(target_headcount / 1.145)

    people, history = {}, []          # employee_id -> person dict; closed job history rows
    state = {}                        # employee_id -> current assignment
    next_id = [1000001]
    org = {d: dict(vps=[], directors=[], managers=[]) for d in DEPT_IDS}
    span = {}                         # manager_id -> direct report count
    span_cap = {}                     # manager_id -> preferred maximum span of control
    mgr_quality = {}                  # manager_id -> latent quality
    dept_ics = {d: set() for d in DEPT_IDS}   # active individual contributors per department
    managers_all = set()

    def pick_location(dept):
        return int(rng.choice(LOCATIONS.location_id, p=LOC_PROFILE[DEPT[dept]["loc"]]))

    def new_person(hire_date, dept, level, manager_id, location_id=None, quality=0.0):
        eid = next_id[0]; next_id[0] += 1
        gender = str(rng.choice(["Female", "Male", "Non-binary", "Undisclosed"], p=[0.45, 0.51, 0.02, 0.02]))
        age = int(np.clip(rng.normal(29 + 2.6 * LEVEL_ORDER.index(level), 6), 21, 68))
        dob = hire_date - pd.Timedelta(days=int(age * 365.25 + rng.integers(0, 365)))
        fn, ln = str(rng.choice(FIRST)), str(rng.choice(LAST))
        loc = location_id or pick_location(dept)
        job_id = job_of[(dept, level)]
        compa = rng.normal(1.0, 0.08) * (0.97 if gender == "Female" else 1.0)
        if dept in AI_DEPTS and hire_date >= AI_BOOM_START:
            compa *= 1.06   # AI hires during the boom come in above band
        emp_type = "Part-time" if (DEPT[dept]["loc"] == "ops" and rng.random() < 0.10) else (
            "Part-time" if rng.random() < 0.02 else "Full-time")
        people[eid] = dict(
            employee_id=eid, first_name=fn, last_name=ln,
            work_email=f"{fn.lower()}.{ln.lower()}.{eid % 100000}@{EMAIL_DOMAIN}",
            personal_email=f"{fn.lower()}{ln.lower()}{rng.integers(10, 99)}@mail.example",
            date_of_birth=dob.normalize(), gender=gender,
            national_id=f"NID-{rng.integers(100000000, 999999999)}",
            home_postcode=f"{rng.integers(10000, 99999)}",
            hire_date=hire_date.normalize(), termination_date=pd.NaT, termination_type=None,
            termination_reason=None, is_regretted=None, employment_type=emp_type,
            hire_source=str(rng.choice(["Referral", "Job board", "Agency", "Careers site", "University"],
                                       p=[0.28, 0.25, 0.12, 0.25, 0.10])),
            _talent=rng.normal(), _engagement=rng.normal() * 0.8 + 0.6 * quality, _mgr_quality=quality,
        )
        state[eid] = dict(employee_id=eid, department_id=dept, job_id=job_id, location_id=loc,
                          manager_id=manager_id, annual_base_salary=round(band_mid[job_id] * LOC_PAY[loc] * compa, -2),
                          fte=float(rng.choice([0.5, 0.6, 0.8])) if emp_type == "Part-time" else 1.0,
                          effective_from=hire_date.normalize(), change_reason="Hire")
        if manager_id is not None:
            span[manager_id] = span.get(manager_id, 0) + 1
        return eid

    def change(eid, when, reason, **kw):
        cur = state[eid]
        if when <= cur["effective_from"]:   # same-day or back-dated change: fold into the current row
            cur.update(kw)
            return
        closed = dict(cur); closed["effective_to"] = when - pd.Timedelta(days=1)
        history.append(closed)
        new = dict(cur); new.update(kw); new["effective_from"] = when; new["change_reason"] = reason
        state[eid] = new

    def make_manager(eid, quality):
        managers_all.add(eid); mgr_quality[eid] = quality; span.setdefault(eid, 0)
        if DEPT[state[eid]["department_id"]]["loc"] == "ops":   # frontline ops teams run wider spans
            span_cap[eid] = int(rng.integers(SPAN_TARGET + 2, SPAN_TARGET + 11))
        else:
            span_cap[eid] = int(rng.integers(SPAN_TARGET - 4, SPAN_TARGET + 5))

    # --- Executive layer -------------------------------------------------------
    old = lambda lo, hi: START - pd.Timedelta(days=int(rng.integers(lo, hi)))
    ceo = new_person(old(3000, 5000), 600, "E1", None, 1); make_manager(ceo, 0.5)
    cpo = new_person(old(1200, 3000), 602, "E2", ceo, 1); make_manager(cpo, 0.8)
    svp = {}

    def pick_svp(dept, when):
        if dept == 602:          # People reports to the Chief People Officer
            return cpo
        div = DEPT[dept]["division"]
        open_svps = [x for x in svp[div] if span[x] < SVP_SPAN]
        if open_svps or when is None:
            return (open_svps or svp[div])[0]
        x = new_person(when, dept, "M5", ceo, None, 0.0); make_manager(x, rng.normal())
        svp[div].append(x)
        return x
    for div in DIVISIONS:
        home = next(d for d in DEPT_IDS if DEPT[d]["division"] == div)
        s = new_person(old(1500, 5000), home, "M5", ceo, 1); make_manager(s, rng.normal()); svp[div] = [s]
    for d in DEPT_IDS:
        if d in FIXED_DEPTS:
            continue
        h = new_person(old(900, 4500), d, "M4", pick_svp(d, None), 1); make_manager(h, rng.normal())
        org[d]["vps"].append(h)

    # HR business partners report directly to the Chief People Officer and never leave (simplification)
    hrbps = []
    for _ in range(max(3, round(target_headcount / HRBP_PER_EMPLOYEES))):
        lvl = str(rng.choice(list(HRBP_TITLES), p=[0.30, 0.45, 0.25]))
        h = new_person(old(200, 3000), 607, lvl, cpo, None, 0.8)
        managers_all.add(h); hrbps.append(h)

    def add_director(dept, when):
        vps = [v for v in org[dept]["vps"] if span[v] < VP_SPAN]
        if vps:
            vp = vps[0]
        else:
            vp = new_person(when, dept, "M4", pick_svp(dept, when), None, 0.0); make_manager(vp, rng.normal())
            org[dept]["vps"].append(vp)
        did = new_person(when, dept, "M3", vp, None, 0.0); make_manager(did, rng.normal())
        org[dept]["directors"].append(did)
        return did

    def add_manager(dept, when, allow_promotion=True):
        dirs = [x for x in org[dept]["directors"] if span[x] < DIRECTOR_SPAN]
        director = dirs[0] if dirs else add_director(dept, when)
        q = rng.normal()
        level = "M2" if rng.random() < 0.25 else "M1"
        candidates = [e for e in list(dept_ics[dept])[:400]
                      if level_of[state[e]["job_id"]] in ("IC4", "IC5") and people[e]["hire_date"] < when]
        if allow_promotion and candidates and rng.random() < 0.5:
            mid = candidates[int(rng.integers(len(candidates)))]
            span[state[mid]["manager_id"]] -= 1
            dept_ics[dept].discard(mid)
            nj = job_of[(dept, level)]
            change(mid, when, "Promotion", job_id=nj, manager_id=director,
                   annual_base_salary=round(max(state[mid]["annual_base_salary"] * 1.10,
                                                band_mid[nj] * LOC_PAY[state[mid]["location_id"]] * 0.92), -2))
            span[director] += 1
            people[mid]["_mgr_quality"] = q
        else:
            mid = new_person(when, dept, level, director, None, 0.0)
        make_manager(mid, q)
        org[dept]["managers"].append(mid)
        return mid

    def choose_manager(dept, when):
        ms = org[dept]["managers"]
        for _ in range(4):
            if not ms:
                break
            m = ms[int(rng.integers(len(ms)))]
            if span[m] < span_cap[m]:
                return m
        open_ms = [m for m in ms[-30:] if span[m] < span_cap[m]]
        return open_ms[0] if open_ms else add_manager(dept, when)

    def hire_ic(when, dept=None, level=None, location_id=None):
        if dept is None:
            dept = int(rng.choice(DEPT_IDS, p=DEPT_SHARE))
        if level is None:
            level = f"IC{int(rng.choice(6, p=HIRE_MIX[DEPT[dept]['mix']])) + 1}"
        mgr = choose_manager(dept, when)
        eid = new_person(when, dept, level, mgr, location_id, mgr_quality[mgr])
        dept_ics[dept].add(eid)
        return eid

    # --- Initial population, hired over the previous 12 years ------------------
    while len(people) < start_headcount:
        hire_ic(START - pd.Timedelta(days=int(min(rng.exponential(1000), 4300)) + 1))

    requisitions, absences, surveys, reviews = [], [], [], []
    req_id = [5000001]

    def add_requisition(dept, job_id, location_id, opened, filled, hired, status):
        senior = level_of[job_id] in ("IC5", "IC6")
        applicants = int(rng.integers(8, 60) if senior else rng.integers(20, 250))
        interviews = int(max(1, applicants * rng.uniform(0.05, 0.15)))
        offers = {"Filled": int(rng.choice([1, 1, 1, 2, 2 if dept in AI_DEPTS else 1])), "Cancelled": 0, "Open": 0}[status]
        requisitions.append((req_id[0], dept, job_id, location_id, opened.normalize(),
                             filled.normalize() if filled is not None else pd.NaT, status, hired,
                             applicants, interviews, offers, 1 if status == "Filled" else 0))
        req_id[0] += 1

    def time_to_fill(dept, job_id):
        base = rng.gamma(4, 10)
        if dept in AI_DEPTS:
            base *= 1.6
        if level_of[job_id] in ("IC5", "IC6"):
            base *= 1.4
        return pd.Timedelta(days=int(base) + 5)

    months = pd.date_range(START, AS_OF, freq="MS")
    for ms in months:
        me = ms + pd.offsets.MonthEnd(0)
        ndays = me.day
        ics = [e for d in DEPT_IDS for e in dept_ics[d] if people[e]["hire_date"] <= me]
        backfill_rate = 0.60 if ms.year == 2023 else 0.88
        growth = {2023: 0.0, 2024: 0.0060, 2025: 0.0070, 2026: 0.0065}[ms.year]

        # Jan 2023 restructuring
        layoff = set()
        if ms == START:
            non_ai = [e for e in ics if state[e]["department_id"] not in AI_DEPTS]
            layoff = set(rng.choice(non_ai, size=int(0.05 * len(non_ai)), replace=False).tolist())
            for e in people:   # morale dips after the layoffs and recovers over the following cycles
                people[e]["_engagement"] -= 0.45

        # Terminations, vectorised risk then per-person handling
        arr = np.array(ics)
        tenure = np.array([(ms - people[e]["hire_date"]).days / 30.4 for e in ics])
        compa = np.array([state[e]["annual_base_salary"] / (band_mid[state[e]["job_id"]] * LOC_PAY[state[e]["location_id"]]) for e in ics])
        attr = np.array([DEPT[state[e]["department_id"]]["attr"] for e in ics])
        eng = np.array([people[e]["_engagement"] for e in ics])
        is_ai = np.array([state[e]["department_id"] in AI_DEPTS for e in ics])
        rate = 0.0075 * attr * np.where(tenure < 12, 1.7, 1.0) * np.where(compa < 0.92, 1.5, 1.0) * np.exp(-0.45 * eng)
        rate = rate * np.where(is_ai & (ms >= AI_BOOM_START), 1.35, 1.0) * (0.8 if ms.year == 2023 else 1.0)
        leaving = set(arr[rng.random(len(arr)) < rate].tolist()) | layoff
        backfills = []
        for e in leaving:
            p, a = people[e], state[e]
            day = max(ms + pd.Timedelta(days=int(rng.integers(0, ndays))), p["hire_date"])
            if e in layoff:
                p.update(termination_type="Involuntary", termination_reason="Restructuring", is_regretted=False)
                day = ms + pd.Timedelta(days=int(rng.integers(9, 20)))
            else:
                vol = rng.random() < (0.55 if p["_talent"] < -0.8 else 0.82)
                c = a["annual_base_salary"] / (band_mid[a["job_id"]] * LOC_PAY[a["location_id"]])
                if vol:
                    if a["department_id"] in AI_DEPTS and ms >= AI_BOOM_START:
                        w = np.array([0.20, 0.38, 0.06, 0.06, 0.06, 0.04, 0.20])
                    else:
                        w = np.array([0.28, 0.24 if c < 0.95 else 0.14, 0.18 if p["_mgr_quality"] < -0.5 else 0.08,
                                      0.10, 0.12, 0.08, 0.02])
                    reason = str(rng.choice(["Career growth", "Compensation", "Manager", "Relocation",
                                             "Work-life balance", "Other", "Competitor offer"], p=w / w.sum()))
                    hot = a["department_id"] in AI_DEPTS and ms >= AI_BOOM_START   # AI talent is in demand
                    p.update(termination_type="Voluntary", termination_reason=reason,
                             is_regretted=bool(p["_talent"] > (-0.3 if hot else 0.3)))
                else:
                    p.update(termination_type="Involuntary", is_regretted=False,
                             termination_reason=str(rng.choice(["Performance", "Restructuring", "Policy violation"], p=[0.65, 0.25, 0.10])))
            p["termination_date"] = day.normalize()
            dept_ics[a["department_id"]].discard(e)
            span[a["manager_id"]] -= 1
            if rng.random() < backfill_rate and e not in layoff:
                backfills.append((e, day))
        # Backfill requisitions (after all leavers are removed, so nobody leaving gets promoted)
        for e, day in backfills:
            a = state[e]
            opened = day + pd.Timedelta(days=int(rng.integers(0, 14)))
            fill = opened + time_to_fill(a["department_id"], a["job_id"])
            if fill > AS_OF:
                add_requisition(a["department_id"], a["job_id"], a["location_id"], opened, None, None, "Open")
            elif rng.random() < 0.94:
                new = hire_ic(fill, a["department_id"], level_of[a["job_id"]], a["location_id"])
                add_requisition(a["department_id"], state[new]["job_id"], a["location_id"], opened, fill, new, "Filled")
            else:
                add_requisition(a["department_id"], a["job_id"], a["location_id"], opened, None, None, "Cancelled")

        # Growth hiring, plus the AI boom
        def growth_hire(dept=None):
            new = hire_ic(ms + pd.Timedelta(days=int(rng.integers(0, ndays))), dept)
            a = state[new]
            add_requisition(a["department_id"], a["job_id"], a["location_id"],
                            people[new]["hire_date"] - time_to_fill(a["department_id"], a["job_id"]),
                            people[new]["hire_date"], new, "Filled")
        for _ in range(rng.poisson(len(ics) * growth)):
            growth_hire()
        if ms >= AI_BOOM_START:
            ai_now = sum(len(dept_ics[d]) for d in AI_DEPTS)
            for _ in range(rng.poisson(ai_now * 0.115)):
                growth_hire(int(rng.choice(sorted(AI_DEPTS), p=[0.30, 0.50, 0.20])))

        # March: merit increases and promotions (using last year's rating)
        if ms.month == 3:
            last = {r[0]: r[2] for r in reviews if r[1] == ms.year - 1}
            for e in [x for d in DEPT_IDS for x in dept_ics[d]] + list(managers_all):
                p, a = people[e], state[e]
                if p["hire_date"] >= ms or not pd.isna(p["termination_date"]):
                    continue
                r = last.get(e); lvl = level_of[a["job_id"]]
                tenure_m = (ms - p["hire_date"]).days / 30.4
                if (r is not None and r >= 4 and tenure_m > 18 and lvl in ("IC1", "IC2", "IC3", "IC4", "IC5")
                        and a["department_id"] not in FIXED_DEPTS
                        and rng.random() < 0.33):
                    nj = job_of[(a["department_id"], f"IC{int(lvl[2]) + 1}")]
                    sal = round(max(a["annual_base_salary"] * rng.uniform(1.08, 1.13), band_mid[nj] * LOC_PAY[a["location_id"]] * 0.9), -2)
                    change(e, ms, "Promotion", job_id=nj, annual_base_salary=sal)
                elif r is not None:
                    pct = {1: 0.0, 2: 0.01, 3: 0.03, 4: 0.04, 5: 0.055}[r] - (0.003 if p["gender"] == "Female" else 0)
                    if a["department_id"] in AI_DEPTS and ms.year >= 2026:
                        pct += 0.03   # retention adjustments for AI talent
                    change(e, ms, "Merit increase", annual_base_salary=round(a["annual_base_salary"] * (1 + pct), -2))

        # Internal transfers (some engineers move into AI during the boom)
        for e in ics:
            if (rng.random() > 0.0025 or e in managers_all or people[e]["hire_date"] >= ms
                    or not pd.isna(people[e]["termination_date"])):
                continue
            a = state[e]
            if ms >= AI_BOOM_START and DEPT[a["department_id"]]["division"] == "Engineering" and rng.random() < 0.5:
                nd = int(rng.choice(sorted(AI_DEPTS), p=[0.2, 0.5, 0.3]))
            else:
                nd = int(rng.choice(DEPT_IDS, p=DEPT_SHARE))
            if nd == a["department_id"]:
                continue
            mgr = choose_manager(nd, ms)
            span[a["manager_id"]] -= 1; span[mgr] += 1
            dept_ics[a["department_id"]].discard(e); dept_ics[nd].add(e)
            change(e, ms, "Transfer", department_id=nd, job_id=job_of[(nd, level_of[a["job_id"]])], manager_id=mgr)
            people[e]["_engagement"] = 0.7 * people[e]["_engagement"] + 0.3 * mgr_quality[mgr]

        # Everyone employed at some point this month
        roster = ics + [e for e in managers_all if people[e]["hire_date"] <= me]
        roster += [e for d in DEPT_IDS for e in dept_ics[d] if ms <= people[e]["hire_date"] <= me]
        roster = list(dict.fromkeys(roster))
        eng = np.array([people[e]["_engagement"] for e in roster])

        # Absences (vectorised counts)
        counts = rng.poisson(0.35 * np.exp(-0.3 * eng))
        for e, k in zip(roster, counts):
            p = people[e]
            for _ in range(k):
                s = ms + pd.Timedelta(days=int(rng.integers(0, ndays)))
                if s < p["hire_date"] or (not pd.isna(p["termination_date"]) and s > p["termination_date"]):
                    continue
                typ = str(rng.choice(["Sick", "Vacation", "Personal", "Parental", "Bereavement"], p=[0.40, 0.45, 0.10, 0.02, 0.03]))
                days = int(rng.integers(40, 90)) if typ == "Parental" else int(
                    rng.choice([1, 2, 3, 5, 10]) if typ == "Vacation" else rng.choice([1, 1, 2, 3, 5]))
                absences.append((e, s.normalize(), (s + pd.Timedelta(days=days - 1)).normalize(), typ, days))

        # Engagement surveys in May and November
        if ms.month in (5, 11):
            cycle = f"{ms.year}-{'H1' if ms.month == 5 else 'H2'}"
            sdate = (ms + pd.Timedelta(days=14)).normalize()
            for e in roster:
                p = people[e]
                if (not pd.isna(p["termination_date"]) and p["termination_date"] < sdate) or p["hire_date"] > sdate or rng.random() > 0.80:
                    continue
                z = p["_engagement"] + rng.normal(0, 0.5)
                mq = mgr_quality.get(state[e]["manager_id"], 0.0)
                surveys.append((e, cycle, sdate, int(np.clip(round(8.0 + 1.6 * z), 0, 10)),
                                float(np.clip(round(3.7 + 0.6 * z, 1), 1, 5)),
                                float(np.clip(round(3.8 + 0.7 * mq + 0.3 * rng.normal(), 1), 1, 5)),
                                float(np.clip(round(3.5 + 0.5 * z + 0.3 * rng.normal(), 1), 1, 5)),
                                float(np.clip(round(3.4 + 0.5 * z + 0.2 * p["_talent"], 1), 1, 5))))
            for e in roster:
                mq = mgr_quality.get(state[e]["manager_id"], 0.0)
                people[e]["_engagement"] = 0.85 * people[e]["_engagement"] + 0.09 * mq + rng.normal(0, 0.2)
            if ms >= AI_BOOM_START:   # post-restructuring recovery, and AI-boom strain in Trust & Safety
                for e in dept_ics[501]:
                    people[e]["_engagement"] -= 0.05

        # Annual performance reviews in December
        if ms.month == 12:
            for e in roster:
                p = people[e]
                if (not pd.isna(p["termination_date"]) and p["termination_date"] <= me) or (me - p["hire_date"]).days < 180:
                    continue
                if state[e]["manager_id"] is None:
                    continue
                z = p["_talent"] + 0.3 * p["_engagement"] + rng.normal(0, 0.6)
                r = int(np.digitize(z, [-1.6, -0.7, 0.8, 1.7]) + 1)
                reviews.append((e, ms.year, r, state[e]["manager_id"]))

    # --- Assemble tables --------------------------------------------------------
    for e, a in state.items():
        row = dict(a); row["effective_to"] = people[e]["termination_date"]
        history.append(row)
    hist = pd.DataFrame(history)
    hist = hist[hist.effective_to.isna() | (hist.effective_to >= hist.effective_from)]
    hist = hist.sort_values(["employee_id", "effective_from"]).reset_index(drop=True)
    hist["is_current"] = hist.effective_to.isna()
    hist["manager_id"] = hist["manager_id"].astype("Int64")

    emp = pd.DataFrame(list(people.values()))
    emp = emp[[c for c in emp.columns if not c.startswith("_")]]

    rating_label = {1: "Below expectations", 2: "Partially meets", 3: "Meets", 4: "Exceeds", 5: "Outstanding"}
    rev = pd.DataFrame(reviews, columns=["employee_id", "review_year", "rating", "reviewer_id"])
    rev.insert(3, "rating_label", rev.rating.map(rating_label))
    absn = pd.DataFrame(absences, columns=["employee_id", "start_date", "end_date", "absence_type", "days_absent"])
    absn.insert(0, "absence_id", np.arange(7000001, 7000001 + len(absn)))
    surv = pd.DataFrame(surveys, columns=["employee_id", "survey_cycle", "survey_date", "enps_score", "engagement_score",
                                          "manager_score", "wellbeing_score", "growth_score"])
    surv.insert(0, "response_id", np.arange(8000001, 8000001 + len(surv)))
    reqs = pd.DataFrame(requisitions, columns=["requisition_id", "department_id", "job_id", "location_id", "opened_date",
                                               "filled_date", "status", "hired_employee_id", "applicants", "interviews",
                                               "offers_extended", "offers_accepted"])
    reqs["hired_employee_id"] = reqs["hired_employee_id"].astype("Int64")

    # --- HR business partner coverage ------------------------------------------------
    # VPs, and directors with a large organisation, are supported by one or more HRBPs.
    # HRBPs can support several leaders, sometimes in different divisions.
    active = {e for e, p in people.items() if pd.isna(p["termination_date"]) and p["hire_date"] <= AS_OF}
    children = {}
    for e in active:
        m = state[e]["manager_id"]
        if m is not None and m in active:
            children.setdefault(m, []).append(e)
    org_size = {}

    def count(e):
        org_size[e] = sum(1 + count(c) for c in children.get(e, []))
        return org_size[e]
    count(ceo)
    lvl_now = {e: level_of[state[e]["job_id"]] for e in active}
    leaders = [e for e in active if state[e]["department_id"] not in (FIXED_DEPTS | {602}) and org_size.get(e, 0) > 0 and (
        lvl_now[e] == "M4" or (lvl_now[e] == "M3" and org_size[e] >= DIRECTOR_HRBP_THRESHOLD))]
    leaders.sort(key=lambda e: (DEPT[state[e]["department_id"]]["division"], state[e]["department_id"], -org_size[e]))
    weight = {e: org_size[e] for e in leaders}
    per_hrbp = sum(weight.values()) / len(hrbps)
    assignments, i, load = [], 0, 0.0

    def start_date(leader, hrbp, lo=pd.Timestamp("2024-01-01")):
        d = lo + pd.Timedelta(days=int(rng.integers(0, (pd.Timestamp("2026-09-30") - lo).days)))
        return max(d, people[leader]["hire_date"], people[hrbp]["hire_date"])

    for e in leaders:
        primary = hrbps[i]
        frm = start_date(e, primary)
        assignments.append([primary, e, "Primary", frm, pd.NaT])
        if rng.random() < 0.25:                      # a previous HRBP covered this leader before
            prev = hrbps[int(rng.integers(len(hrbps)))]
            p_from = max(people[e]["hire_date"], people[prev]["hire_date"], START)
            if prev != primary and p_from < frm - pd.Timedelta(days=60):
                assignments.append([prev, e, "Primary", p_from, frm - pd.Timedelta(days=1)])
        big = org_size[e] >= per_hrbp
        if big or rng.random() < 0.12:              # second HRBP for big orgs, plus some cross-area cover
            sec = hrbps[int(rng.integers(len(hrbps)))]
            if sec != primary:
                assignments.append([sec, e, "Secondary", start_date(e, sec), pd.NaT])
        load += weight[e]
        if load >= per_hrbp * 0.95 and i < len(hrbps) - 1:
            i, load = i + 1, 0.0
    hrbp_asg = pd.DataFrame(assignments, columns=["hrbp_employee_id", "leader_employee_id", "coverage_role",
                                                  "effective_from", "effective_to"])
    hrbp_asg.insert(0, "assignment_id", np.arange(9000001, 9000001 + len(hrbp_asg)))

    # --- Equity grants (fictional TEMA share price) ------------------------------------
    def share_price(d):
        t = np.maximum((d - START).dt.days.to_numpy() / (AS_OF - START).days, -1.5)
        return np.round(42 * (118 / 42) ** t * (1 + 0.08 * np.sin(t * 9)), 2)

    hist_lvl = hist.assign(job_level=hist.job_id.map(level_of))
    base = hist_lvl.job_level.map(EQUITY_HIRE_VALUE)
    factor = hist_lvl.department_id.map(lambda d: DEPT[d]["pay"]) * hist_lvl.location_id.map(LOC_PAY)
    hire_rows = hist_lvl.change_reason.eq("Hire") & base.notna()
    promo_rows = hist_lvl.change_reason.eq("Promotion") & base.notna()
    boom = hist_lvl.department_id.isin(AI_DEPTS) & (hist_lvl.effective_from >= AI_BOOM_START)
    g_hire = pd.DataFrame(dict(employee_id=hist_lvl.employee_id[hire_rows], grant_date=hist_lvl.effective_from[hire_rows],
                               grant_type="New hire",
                               grant_value_usd=(base * factor * np.where(boom, 1.6, 1.0))[hire_rows]))
    g_promo = pd.DataFrame(dict(employee_id=hist_lvl.employee_id[promo_rows], grant_date=hist_lvl.effective_from[promo_rows],
                                grant_type="Promotion", grant_value_usd=(0.3 * base * factor)[promo_rows]))
    ref = rev[rev.rating >= 3].assign(grant_date=pd.to_datetime((rev.review_year + 1).astype(str) + "-03-15"))
    ref = ref[ref.grant_date <= AS_OF].merge(hist_lvl, on="employee_id")
    ref = ref[(ref.effective_from <= ref.grant_date) & (ref.effective_to.isna() | (ref.effective_to >= ref.grant_date))]
    ref = ref[ref.job_level.isin(EQUITY_HIRE_VALUE)]
    ref_val = (ref.job_level.map(EQUITY_HIRE_VALUE) * ref.department_id.map(lambda d: DEPT[d]["pay"])
               * ref.location_id.map(LOC_PAY) * ref.rating.map({3: 0.20, 4: 0.30, 5: 0.45}))
    g_ref = pd.DataFrame(dict(employee_id=ref.employee_id, grant_date=ref.grant_date, grant_type="Annual refresh",
                              grant_value_usd=ref_val))
    ret_date = pd.Timestamp("2026-02-15")
    ret = ref[(ref.grant_date == pd.Timestamp("2026-03-15")) & (ref.rating >= 4) & ref.department_id.isin(AI_DEPTS)]
    g_ret = pd.DataFrame(dict(employee_id=ret.employee_id, grant_date=ret_date, grant_type="Retention",
                              grant_value_usd=0.6 * ret.job_level.map(EQUITY_HIRE_VALUE) * ret.department_id.map(
                                  lambda d: DEPT[d]["pay"]) * ret.location_id.map(LOC_PAY)))
    eq = pd.concat([g_hire, g_promo, g_ref, g_ret], ignore_index=True)
    eq["grant_value_usd"] = np.round(eq.grant_value_usd * rng.lognormal(0, 0.2, len(eq)), -2)
    eq = eq.sort_values(["grant_date", "employee_id"]).reset_index(drop=True)
    eq["grant_price_usd"] = share_price(eq.grant_date)
    eq["shares"] = np.round(eq.grant_value_usd / eq.grant_price_usd).astype(int)
    eq["vesting_years"] = 4
    eq.insert(0, "grant_id", np.arange(6000001, 6000001 + len(eq)))

    return {
        "locations": LOCATIONS,
        "departments": DEPARTMENTS,
        "jobs": jobs,
        "employees": emp,
        "job_history": hist[["employee_id", "effective_from", "effective_to", "is_current", "change_reason",
                             "department_id", "job_id", "location_id", "manager_id", "annual_base_salary", "fte"]],
        "requisitions": reqs,
        "absences": absn,
        "engagement_surveys": surv,
        "performance_reviews": rev,
        "equity_grants": eq,
        "hrbp_assignments": hrbp_asg,
    }


def headcount_snapshots(tables: dict):
    """Yield one DataFrame per month: everyone employed at any point in the month, with their assignment
    at month end (or on their last day) and hire / leaver flags."""
    hist, emp = tables["job_history"], tables["employees"][["employee_id", "hire_date", "termination_date"]]
    for ms in pd.date_range(START, AS_OF, freq="MS"):
        me = ms + pd.offsets.MonthEnd(0)
        h = hist[(hist.effective_from <= me) & (hist.effective_to.isna() | (hist.effective_to >= ms))]
        h = h.sort_values("effective_from").groupby("employee_id").tail(1).merge(emp, on="employee_id")
        h = h[(h.hire_date <= me) & (h.termination_date.isna() | (h.termination_date >= ms))]
        yield pd.DataFrame(dict(
            snapshot_month=me.normalize(), employee_id=h.employee_id, department_id=h.department_id,
            job_id=h.job_id, location_id=h.location_id, manager_id=h.manager_id,
            annual_base_salary=h.annual_base_salary, fte=h.fte,
            tenure_months=((me - h.hire_date).dt.days / 30.4375).astype(int),
            is_active_month_end=h.termination_date.isna() | (h.termination_date > me),
            is_hire_in_month=h.hire_date >= ms,
            is_termination_in_month=h.termination_date.notna() & (h.termination_date <= me),
        ))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write the tables to Unity Catalog
# MAGIC Set the widgets, then run. At 70,000 employees expect several minutes; `headcount_monthly`
# MAGIC is about 3 million rows. If you hit memory limits, lower `target_headcount`.

# COMMAND ----------

def _to_spark_ready(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for c in out.columns:
        if pd.api.types.is_datetime64_any_dtype(out[c]):
            out[c] = out[c].dt.date.astype(object).where(out[c].notna(), None)
        elif not (pd.api.types.is_numeric_dtype(out[c]) or pd.api.types.is_bool_dtype(out[c])):
            out[c] = pd.Series([None if pd.isna(v) else (v.item() if hasattr(v, "item") else v)
                                for v in out[c]], index=out.index, dtype=object)
    return out


def _write(df, table, mode="overwrite", chunk=400_000):
    for i in range(0, max(len(df), 1), chunk):
        (spark.createDataFrame(_to_spark_ready(df.iloc[i:i + chunk]))
         .write.mode(mode if i == 0 else "append").option("overwriteSchema", "true").saveAsTable(table))


if __name__ == "__main__" and "dbutils" in globals():
    dbutils.widgets.text("catalog", "workspace")
    dbutils.widgets.text("schema", "tema_hr_raw")
    dbutils.widgets.text("target_headcount", "70000")
    catalog, schema = dbutils.widgets.get("catalog"), dbutils.widgets.get("schema")
    target = int(dbutils.widgets.get("target_headcount"))
    spark.sql(f"CREATE SCHEMA IF NOT EXISTS `{catalog}`.`{schema}` "
              f"COMMENT 'Synthetic HR source data for {COMPANY} (fictional). Not real people.'")
    tables = generate(target)
    for name, df in tables.items():
        _write(df, f"`{catalog}`.`{schema}`.`{name}`")
        print(f"{catalog}.{schema}.{name}: {len(df):,} rows")
    batch, first, total = [], True, 0
    for snap in headcount_snapshots(tables):
        batch.append(snap)
        if sum(len(b) for b in batch) > 400_000:
            _write(pd.concat(batch), f"`{catalog}`.`{schema}`.`headcount_monthly`", "overwrite" if first else "append")
            total += sum(len(b) for b in batch); batch, first = [], False
    if batch:
        _write(pd.concat(batch), f"`{catalog}`.`{schema}`.`headcount_monthly`", "overwrite" if first else "append")
        total += sum(len(b) for b in batch)
    print(f"{catalog}.{schema}.headcount_monthly: {total:,} rows")