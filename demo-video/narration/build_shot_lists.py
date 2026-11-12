"""Rebuild ../shot-lists.md from scenes.json and durations.json. Run after editing either."""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
data = json.loads((HERE / "scenes.json").read_text(encoding="utf-8"))
dur = json.loads((HERE / "durations.json").read_text(encoding="utf-8"))
src = "measured from the audio" if dur.get("_source", "").startswith("audio") else "estimated (regenerate after the audio exists)"


def mmss(t):
    return f"{int(t // 60)}:{int(t % 60):02}"


out = [
    "# Shot lists",
    "",
    "Generated from `narration/scenes.json` by `narration/build_shot_lists.py`. Edit the JSON, not this file.",
    f"Timings are {src}.",
    "",
    "**How to use this when recording:** keep this page on a second screen. For each `screen` scene, do the action in Databricks "
    "slowly and silently (the narration is added later), pause two seconds before and after each click, and record each scene as its "
    "own clip named by its scene id. `graphic` scenes need no recording: the clip is in `renders/`.",
    "",
]
for v in data["videos"]:
    total = sum(dur.get(s["id"], 0) for s in v["scenes"])
    out += [f"## {v['id']}: {v['title']} ({v['length_target']}, narration {mmss(total)})", "", v["notes"], ""]
    out += ["| Scene | At | Length | Picture | What to do on screen | Narration |", "|---|---|---|---|---|---|"]
    t = 0.0
    for s in v["scenes"]:
        d = dur.get(s["id"], 0)
        text = re.sub(r'<break time="([\d.]+)s" />', r"*(pause)*", s["text"]).replace("|", "\\|")
        pic = ("🎬 Screen" if s["visual"] == "screen" else "🎨 Graphic") + f": {s['graphic']}"
        out.append(f"| {s['id']} | {mmss(t)} | {d:.0f}s | {pic} | {s['action']} | {text} |")
        t += d
    out.append("")
(HERE.parent / "shot-lists.md").write_text("\n".join(out), encoding="utf-8")
print("Wrote shot-lists.md")
