# Databricks notebook source
# MAGIC %md
# MAGIC # SQL runner helpers
# MAGIC Shared by `00_build_reference` and `01_check_my_work` (they `%run` this notebook). Nothing to run here on its own.
# MAGIC
# MAGIC - `split_sql(text)` splits a `.sql` file into statements, respecting quotes, comments and `$$ ... $$` metric view YAML.
# MAGIC - `retarget(sql, catalog, prefix)` rewrites `workspace.` and the `tema_hr_gold / tema_hr_semantic / tema_hr_secure`
# MAGIC   schema names, so the reference can be built next to your own work without touching it.
# MAGIC   `tema_hr_raw` is never renamed: the generated source data is shared.

# COMMAND ----------

import re

RENAMED_SCHEMAS = ("gold", "semantic", "secure")


def split_sql(text: str) -> list:
    """Split SQL text into statements on top-level semicolons.

    Skips -- line comments and /* */ block comments, and keeps '...', "...", `...` and $$...$$ intact.
    Returns statements with comment-only content removed (empty statements are dropped).
    """
    stmts, buf, i, n = [], [], 0, len(text)
    while i < n:
        c, nxt = text[i], text[i + 1] if i + 1 < n else ""
        if c == "-" and nxt == "-":                       # line comment: drop it
            j = text.find("\n", i)
            i = n if j == -1 else j
            continue
        if c == "/" and nxt == "*":                       # block comment: drop it
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue
        if c == "$" and nxt == "$":                       # $$ ... $$ body (metric view YAML)
            j = text.find("$$", i + 2)
            j = n if j == -1 else j + 2
            buf.append(text[i:j]); i = j
            continue
        if c in ("'", '"', "`"):                          # quoted string or identifier
            j = i + 1
            while j < n:
                if text[j] == "\\" and c != "`":
                    j += 2; continue
                if text[j] == c:
                    if j + 1 < n and text[j + 1] == c:    # doubled quote escape
                        j += 2; continue
                    break
                j += 1
            buf.append(text[i:j + 1]); i = j + 1
            continue
        if c == ";":
            stmt = "".join(buf).strip()
            if stmt:
                stmts.append(stmt)
            buf, i = [], i + 1
            continue
        buf.append(c); i += 1
    stmt = "".join(buf).strip()
    if stmt:
        stmts.append(stmt)
    return stmts


def retarget(sql: str, catalog: str = "workspace", prefix: str = "tema_hr") -> str:
    """Point a reference statement at another catalog and schema prefix."""
    if prefix != "tema_hr":
        sql = re.sub(r"\btema_hr_(" + "|".join(RENAMED_SCHEMAS) + r")\b", prefix + r"_\1", sql)
    if catalog != "workspace":
        sql = re.sub(r"\bworkspace(?=\.)", catalog, sql)
        sql = re.sub(r"(?i)(CATALOG\s+)workspace\b", r"\1" + catalog, sql)
    return sql


def first_line(sql: str, width: int = 110) -> str:
    line = " ".join(sql.split())
    return line if len(line) <= width else line[: width - 1] + "…"
