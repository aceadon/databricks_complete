"""Create the two Week 7 Genie Agents (spaces) through the Databricks API, then test them.

  Tema raw (baseline)          every table in workspace.tema_hr_raw, no instructions
  People Analytics Assistant   the metric views in workspace.tema_hr_semantic, the instructions from
                               instructions.md and the example SQL from example_queries.sql

Then it asks both "How many people did we have at the end of Q2 2025?" and prints what each answered, and
writes the two space URLs into demo-video/recorder/config.json if that file exists.

Needs only Python 3.9+. Authentication: a personal access token in the DATABRICKS_TOKEN environment variable
(Settings > Developer > Access tokens). The token is never printed or written anywhere.

  python create_genie_spaces.py                     # host is taken from demo-video/recorder/config.json
  python create_genie_spaces.py --host https://dbc-....cloud.databricks.com
  python create_genie_spaces.py --recreate          # move existing spaces with these names to trash first
  python create_genie_spaces.py --test-only         # just ask the test question again
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
RECORDER_CONFIG = REPO / "demo-video" / "recorder" / "config.json"
CATALOG = "workspace"
RAW_SCHEMA = "tema_hr_raw"
SEMANTIC_SCHEMA = "tema_hr_semantic"
# The assistant's sources (instructions.md). pay_metrics is left out on purpose: it has unsuppressed pay.
SEMANTIC_SOURCES = ["workforce_metrics", "retention_metrics", "talent_acquisition_metrics", "experience_metrics",
                    "pay_by_level_safe", "business_metrics"]
RAW_TITLE = "Tema raw (baseline)"
ASSISTANT_TITLE = "People Analytics Assistant"
TEST_QUESTION = "How many people did we have at the end of Q2 2025?"


class Api:
    def __init__(self, host, token):
        self.host = host.rstrip("/")
        self.token = token

    def call(self, method, path, body=None, ok404=False):
        req = urllib.request.Request(
            self.host + path,
            method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"},
        )
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=120) as r:
                    raw = r.read()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as e:
                if e.code == 404 and ok404:
                    return None
                if e.code in (429, 500, 502, 503) and attempt < 3:
                    time.sleep(2 ** attempt * 2)
                    continue
                detail = e.read().decode(errors="replace")[:800]
                raise SystemExit(f"\nDatabricks returned {e.code} for {method} {path.split('?')[0]}:\n{detail}")
            except urllib.error.URLError as e:
                if attempt < 3:
                    time.sleep(2 ** attempt * 2)
                    continue
                raise SystemExit(f"Couldn't reach {self.host}: {e.reason}")


def new_ids():
    """32-char lowercase hex ids that sort in creation order (the API rejects unsorted lists)."""
    base = time.time_ns() // 1000
    n = 0
    while True:
        n += 1
        yield f"{base:016x}{n:016x}"


def list_objects(api, schema):
    out, token = [], None
    while True:
        q = {"catalog_name": CATALOG, "schema_name": schema, "max_results": 200}
        if token:
            q["page_token"] = token
        r = api.call("GET", "/api/2.1/unity-catalog/tables?" + urllib.parse.urlencode(q), ok404=True) or {}
        out += r.get("tables", [])
        token = r.get("next_page_token")
        if not token:
            return out


def parse_examples(path, existing):
    """example_queries.sql: '-- question' comment lines followed by a SQL statement ending in ';'."""
    text = path.read_text(encoding="utf-8")
    examples = []
    for m in re.finditer(r"^-- (?!=)(.+\?)\s*\n((?:(?!--).*\n?)+?;)", text, re.M):
        question, sql = m.group(1).strip(), m.group(2).strip()
        used = set(re.findall(rf"{SEMANTIC_SCHEMA}\.(\w+)", sql))
        if used <= existing:
            examples.append((question, sql))
        else:
            print(f"  skipping example '{question}' (needs {', '.join(sorted(used - existing))}, not built yet)")
    return examples


def instructions_text():
    md = (HERE / "instructions.md").read_text(encoding="utf-8")
    m = re.search(r"```text\n(.*?)```", md, re.S)
    if not m:
        raise SystemExit("Couldn't find the ```text block in instructions.md")
    return m.group(1).strip()


def lines(s):
    return [ln + "\n" for ln in s.split("\n")[:-1]] + [s.split("\n")[-1]]


def find_space(api, title):
    token = None
    while True:
        r = api.call("GET", "/api/2.0/genie/spaces" + (f"?page_token={token}" if token else "")) or {}
        for s in r.get("spaces", []):
            if s.get("title") == title:
                return s
        token = r.get("next_page_token")
        if not token:
            return None


def pick_warehouse(api, wanted):
    whs = (api.call("GET", "/api/2.0/sql/warehouses") or {}).get("warehouses", [])
    if wanted:
        return wanted
    if not whs:
        raise SystemExit("No SQL warehouse found. Create one (or pass --warehouse-id).")
    whs.sort(key=lambda w: (w.get("state") != "RUNNING", w.get("name", "")))
    print(f"  using SQL warehouse '{whs[0].get('name')}'")
    return whs[0]["id"]


def create_space(api, title, description, warehouse_id, parent_path, serialized):
    body = {"title": title, "description": description, "warehouse_id": warehouse_id,
            "serialized_space": json.dumps(serialized)}
    if parent_path:
        body["parent_path"] = parent_path
    r = api.call("POST", "/api/2.0/genie/spaces", body)
    return r.get("space_id") or r.get("id")


def ask(api, space_id, question, timeout=300):
    r = api.call("POST", f"/api/2.0/genie/spaces/{space_id}/start-conversation", {"content": question})
    cid = r.get("conversation_id") or r.get("conversation", {}).get("id")
    mid = r.get("message_id") or r.get("message", {}).get("id")
    path = f"/api/2.0/genie/spaces/{space_id}/conversations/{cid}/messages/{mid}"
    start, delay, msg = time.time(), 2, {}
    while time.time() - start < timeout:
        msg = api.call("GET", path)
        if msg.get("status") in ("COMPLETED", "FAILED", "CANCELLED", "QUERY_RESULT_EXPIRED"):
            break
        time.sleep(delay)
        delay = min(delay * 1.5, 10)
    out = {"status": msg.get("status"), "text": [], "sql": None, "rows": None}
    for a in msg.get("attachments") or []:
        if a.get("text"):
            out["text"].append(a["text"].get("content", ""))
        if a.get("query"):
            out["sql"] = a["query"].get("query")
            aid = a.get("attachment_id") or a.get("id")
            res = api.call("GET", f"{path}/attachments/{aid}/query-result", ok404=True) or {}
            sr = res.get("statement_response", res)
            cols = [c.get("name") for c in (sr.get("manifest", {}).get("schema", {}).get("columns") or [])]
            data = (sr.get("result") or {}).get("data_array") or []
            out["rows"] = (cols, data[:5])
    return out


def space_url(host, space_id, org):
    return f"{host.rstrip('/')}/genie/rooms/{space_id}" + (f"?o={org}" if org else "")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host")
    p.add_argument("--warehouse-id")
    p.add_argument("--recreate", action="store_true")
    p.add_argument("--test-only", action="store_true")
    args = p.parse_args()

    cfg = json.loads(RECORDER_CONFIG.read_text(encoding="utf-8")) if RECORDER_CONFIG.exists() else {}
    host = args.host or os.environ.get("DATABRICKS_HOST") or cfg.get("workspaceUrl", "")
    if not host.startswith(("https://", "http://")):
        raise SystemExit("Pass --host https://<your-workspace>.cloud.databricks.com (or set workspaceUrl in recorder/config.json).")
    host = re.match(r"https?://[^/?#]+", host).group(0)
    org = None
    for v in cfg.values():
        m = re.search(r"[?&]o=(\d+)", v) if isinstance(v, str) else None
        if m:
            org = m.group(1)
            break
    token = os.environ.get("DATABRICKS_TOKEN")
    if not token:
        raise SystemExit("DATABRICKS_TOKEN is not set in this shell. Create a token in Settings > Developer > Access tokens.")
    api = Api(host, token)
    me = api.call("GET", "/api/2.0/preview/scim/v2/Me") or {}
    print(f"Connected to {host} as {me.get('userName', 'you')}")

    ids = new_ids()
    spaces = {}
    if not args.test_only:
        warehouse = pick_warehouse(api, args.warehouse_id)
        parent = f"/Users/{me['userName']}" if me.get("userName") else None

        raw_tables = sorted(t["full_name"] for t in list_objects(api, RAW_SCHEMA) if t.get("table_type") != "VIEW")
        if not raw_tables:
            raise SystemExit(f"No tables found in {CATALOG}.{RAW_SCHEMA}. Run 00_generate_hr_data.py first.")
        sem = {t["name"]: t for t in list_objects(api, SEMANTIC_SCHEMA)}
        present = [n for n in SEMANTIC_SOURCES if n in sem]
        if "workforce_metrics" not in present:
            raise SystemExit(f"{CATALOG}.{SEMANTIC_SCHEMA}.workforce_metrics doesn't exist yet (Week 3).")
        metric_views = sorted(f"{CATALOG}.{SEMANTIC_SCHEMA}.{n}" for n in present if sem[n].get("table_type") == "METRIC_VIEW")
        plain_views = sorted(f"{CATALOG}.{SEMANTIC_SCHEMA}.{n}" for n in present if sem[n].get("table_type") != "METRIC_VIEW")
        print(f"  raw tables: {len(raw_tables)}; semantic sources: {', '.join(present)}")

        examples = parse_examples(HERE / "example_queries.sql", set(present))
        raw_space = {"version": 2, "data_sources": {"tables": [{"identifier": t} for t in raw_tables]}}
        assistant_space = {
            "version": 2,
            "config": {"sample_questions": [{"id": next(ids), "question": [TEST_QUESTION]}]},
            "data_sources": {},
            "instructions": {
                "text_instructions": [{"id": next(ids), "content": lines(instructions_text())}],
                "example_question_sqls": [{"id": next(ids), "question": [q], "sql": lines(s)} for q, s in examples],
            },
        }
        if plain_views:
            assistant_space["data_sources"]["tables"] = [{"identifier": t} for t in plain_views]
        if metric_views:
            assistant_space["data_sources"]["metric_views"] = [{"identifier": t} for t in metric_views]

        for title, desc, ser in (
            (RAW_TITLE, "Week 7 baseline: Tema's raw HR tables with no instructions. Expected to get things wrong.", raw_space),
            (ASSISTANT_TITLE, "Week 7: Tema's certified HR metrics (metric views) with instructions and example SQL.", assistant_space),
        ):
            existing = find_space(api, title)
            if existing and args.recreate:
                api.call("DELETE", f"/api/2.0/genie/spaces/{existing['space_id']}")
                print(f"  moved the old '{title}' to trash")
                existing = None
            if existing:
                print(f"  '{title}' already exists, keeping it (use --recreate to rebuild)")
                spaces[title] = existing["space_id"]
            else:
                spaces[title] = create_space(api, title, desc, warehouse, parent, ser)
                print(f"  created '{title}'")
    else:
        for title in (RAW_TITLE, ASSISTANT_TITLE):
            s = find_space(api, title)
            if not s:
                raise SystemExit(f"'{title}' doesn't exist yet. Run without --test-only.")
            spaces[title] = s["space_id"]

    urls = {t: space_url(host, sid, org) for t, sid in spaces.items()}
    for t, u in urls.items():
        print(f"\n{t}: {u}")
    if RECORDER_CONFIG.exists():
        cfg["genieRawUrl"] = urls[RAW_TITLE]
        cfg["genieAssistantUrl"] = urls[ASSISTANT_TITLE]
        RECORDER_CONFIG.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
        print(f"\nWrote both URLs into {RECORDER_CONFIG}")

    print(f"\nTesting both with: {TEST_QUESTION}  (expected: the assistant says 58,862 at 70,000 people)")
    for t in (RAW_TITLE, ASSISTANT_TITLE):
        r = ask(api, spaces[t], TEST_QUESTION)
        print(f"\n--- {t}: {r['status']}")
        for txt in r["text"]:
            print(txt.strip()[:600])
        if r["sql"]:
            print("SQL:", " ".join(r["sql"].split())[:400])
        if r["rows"]:
            cols, rows = r["rows"]
            print("Result:", cols, rows)


if __name__ == "__main__":
    main()
