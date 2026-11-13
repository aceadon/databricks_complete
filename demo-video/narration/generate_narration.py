"""Generate the demo narration in your ElevenLabs voice, one MP3 per scene.

Reads scenes.json next to this file and writes, for every scene:
  ../audio/<scene id>.mp3      the narration
  ../audio/<scene id>.srt      captions for that clip (starts at 0:00)
and updates durations.json with the real clip lengths, so the Remotion graphics
can be re-rendered to fit (npm run render:all in ../remotion).

Needs only Python 3.9+ (no packages). Your API key is read from the
ELEVENLABS_API_KEY environment variable and is never printed or written anywhere.

  python generate_narration.py                       # uses Demo Voice (DEFAULT_VOICE_ID below)
  python generate_narration.py --force               # regenerate every clip, e.g. after changing voice
  python generate_narration.py --voice-name "Ashley"
  python generate_narration.py --only T1             # one video
  python generate_narration.py --only T2-04 --force  # redo one scene
  python generate_narration.py --list-voices
"""
import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.elevenlabs.io/v1"
HERE = Path(__file__).resolve().parent
AUDIO = HERE.parent / "audio"
# Ashley's "Demo Voice" (set 2026-11-12). --voice-id or --voice-name override it.
DEFAULT_VOICE_ID = "raCeU2yDu9AXhX4woLSo"
MODEL = "eleven_multilingual_v2"  # supports <break time="0.4s" /> tags
SETTINGS = {"stability": 0.5, "similarity_boost": 0.8, "style": 0.0, "use_speaker_boost": True, "speed": 1.0}


def key():
    k = os.environ.get("ELEVENLABS_API_KEY")
    if not k:
        sys.exit("ELEVENLABS_API_KEY is not set in this shell.")
    return k


def call(method, path, body=None):
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"xi-api-key": key(), "Content-Type": "application/json", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"ElevenLabs returned {e.code} for {path.split('?')[0]}: {e.read().decode()[:400]}")


def voices():
    return call("GET", "/voices")["voices"]


def pick_voice(args):
    if args.voice_id:
        return args.voice_id, args.voice_id
    if not args.voice_name and DEFAULT_VOICE_ID:
        return DEFAULT_VOICE_ID, f"Demo Voice ({DEFAULT_VOICE_ID})"
    vs = voices()
    if args.voice_name:
        m = [v for v in vs if v["name"].lower() == args.voice_name.lower()]
    else:
        m = [v for v in vs if v.get("category") in ("cloned", "professional")]
    if len(m) != 1:
        print("Couldn't pick one voice. Your voices:")
        for v in vs:
            print(f"  {v['name']!r:30} category={v.get('category')}  id={v['voice_id']}")
        sys.exit("Re-run with --voice-name or --voice-id.")
    return m[0]["voice_id"], m[0]["name"]


# Ashley's rule: numbers are spoken as words. scenes.json already spells them out; this catches any
# digits added later (2025 -> "twenty twenty-five", 58,862 -> "fifty-eight thousand, eight hundred sixty-two").
# Digits glued to letters, like "Q2", are left alone.
ONES = "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen".split()
TENS = "_ _ twenty thirty forty fifty sixty seventy eighty ninety".split()


def words(n):
    if n < 20:
        return ONES[n]
    if n < 100:
        return TENS[n // 10] + ("-" + ONES[n % 10] if n % 10 else "")
    if n < 1000:
        return ONES[n // 100] + " hundred" + (" " + words(n % 100) if n % 100 else "")
    for size, name in ((10**9, "billion"), (10**6, "million"), (1000, "thousand")):
        if n >= size:
            rest = n % size
            return words(n // size) + " " + name + ((", " if rest >= 100 else " ") + words(rest) if rest else "")


def spell_numbers(text):
    def one(m):
        raw = m.group(0)
        n = int(raw.replace(",", ""))
        if "," not in raw and len(raw) == 4 and (1900 <= n <= 1999 or 2010 <= n <= 2099):  # a year
            hi, lo = divmod(n, 100)
            return words(hi) + " " + ("hundred" if lo == 0 else ("oh " + ONES[lo] if lo < 10 else words(lo)))
        return words(n)

    parts = re.split(r"(<[^>]+>)", text)  # leave <break time="0.4s" /> tags alone
    num = r"(?<![\w.,])(?:\d{1,3}(?:,\d{3})+|\d+)(?!\w|[.,]\d)"
    return "".join(pt if pt.startswith("<") else re.sub(num, one, pt) for pt in parts)


def srt_time(t):
    ms = int(round(t * 1000))
    return f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02},{ms % 1000:03}"


def captions(alignment, max_words=7):
    """Group the character timings into short caption lines."""
    chars = alignment["characters"]
    starts = alignment["character_start_times_seconds"]
    ends = alignment["character_end_times_seconds"]
    words, cur, s = [], "", None
    for c, a, b in zip(chars, starts, ends):
        if c.isspace():
            if cur:
                words.append((cur, s, e))
            cur, s = "", None
            continue
        if s is None:
            s = a
        cur += c
        e = b
    if cur:
        words.append((cur, s, e))
    lines, buf = [], []
    for w in words:
        buf.append(w)
        if len(buf) >= max_words or re.search(r"[.?!,]$", w[0]) and len(buf) >= 3:
            lines.append(buf)
            buf = []
    if buf:
        lines.append(buf)
    out = []
    for i, ln in enumerate(lines, 1):
        out.append(f"{i}\n{srt_time(ln[0][1])} --> {srt_time(ln[-1][2])}\n{' '.join(w[0] for w in ln)}\n")
    return "\n".join(out)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--voice-id")
    p.add_argument("--voice-name")
    p.add_argument("--only", nargs="*", help="video ids (T1) or scene ids (T2-04)")
    p.add_argument("--force", action="store_true", help="regenerate clips that already exist")
    p.add_argument("--list-voices", action="store_true")
    args = p.parse_args()

    if args.list_voices:
        for v in voices():
            print(f"{v['name']!r:30} category={v.get('category')}  id={v['voice_id']}")
        return

    voice_id, voice_name = pick_voice(args)
    print(f"Voice: {voice_name}")
    data = json.loads((HERE / "scenes.json").read_text(encoding="utf-8"))
    dpath = HERE / "durations.json"
    durations = json.loads(dpath.read_text(encoding="utf-8")) if dpath.exists() else {}
    AUDIO.mkdir(exist_ok=True)
    made = 0
    for video in data["videos"]:
        scenes = video["scenes"]
        for i, sc in enumerate(scenes):
            if args.only and video["id"] not in args.only and sc["id"] not in args.only:
                continue
            mp3 = AUDIO / f"{sc['id']}.mp3"
            if mp3.exists() and not args.force:
                print(f"  {sc['id']}: exists, skipped (use --force to redo)")
                continue
            plain = lambda t: re.sub(r"<[^>]+>", "", t)
            body = {"text": spell_numbers(sc["text"]), "model_id": MODEL, "voice_settings": SETTINGS}
            # Neighbouring lines keep intonation consistent across separate clips.
            if i > 0:
                body["previous_text"] = plain(scenes[i - 1]["text"])
            if i < len(scenes) - 1:
                body["next_text"] = plain(scenes[i + 1]["text"])
            r = call("POST", f"/text-to-speech/{voice_id}/with-timestamps?output_format=mp3_44100_128", body)
            mp3.write_bytes(base64.b64decode(r["audio_base64"]))
            al = r.get("alignment") or r.get("normalized_alignment")
            dur = round(al["character_end_times_seconds"][-1] + 0.25, 2)
            (AUDIO / f"{sc['id']}.srt").write_text(captions(al), encoding="utf-8")
            durations[sc["id"]] = dur
            made += 1
            print(f"  {sc['id']}: {dur:.1f}s")
    durations["_source"] = "audio: real clip lengths from generate_narration.py"
    dpath.write_text(json.dumps(durations, indent=2), encoding="utf-8")
    total = {v["id"]: round(sum(durations.get(s["id"], 0) for s in v["scenes"]), 1) for v in data["videos"]}
    print(f"Made {made} clips into {AUDIO}. Narration length per video (seconds): {total}")


if __name__ == "__main__":
    main()
