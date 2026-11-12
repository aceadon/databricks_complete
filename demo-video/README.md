# Demo videos: the Gap Selling scripts, narrated and edited

Three videos built from [`docs/demo-scripts-gap-selling.md`](../docs/demo-scripts-gap-selling.md), narrated in your ElevenLabs voice:

| Video | Length | Picture |
|---|---|---|
| **T1** The 30-second spiel | ~30 to 40 s | All animation (`Spiel30`), no screen recording |
| **T2** The 2-minute proof | ~2 min | Graphics + one SQL editor recording |
| **T3** The 5-minute walk-through | ~5 min | Graphics + recordings of SQL, Catalog Explorer, Genie and the HRBP activity |

## What's in this folder

| Path | What it is |
|---|---|
| [`shot-lists.md`](shot-lists.md) | Every scene: picture, what to click, narration, timing. Your recording script. |
| [`narration/scenes.json`](narration/scenes.json) | The single source of truth for narration and actions. Edit lines here. |
| [`narration/generate_narration.py`](narration/generate_narration.py) | Makes one MP3 + SRT per scene with your ElevenLabs voice (key from `ELEVENLABS_API_KEY`). |
| [`narration/durations.json`](narration/durations.json) | Clip lengths; the graphics are sized from these. |
| [`remotion/`](remotion/) | The motion graphics as code (React + Remotion), and the full-video assembly. |
| [`recorder/`](recorder/) | Drives Databricks in Chrome and records the screen scenes for you. See its README. |
| `audio/`, `renders/` | Generated narration and graphics. Not in Git. |

## The pipeline

1. **Narration.** `cd demo-video/narration` then `python generate_narration.py`. It finds your cloned voice, writes `audio/T1-01.mp3` etc., captions, and real lengths into `durations.json`. Listen to each clip; to change a line, edit `scenes.json` and run `python generate_narration.py --only T2-04 --force`.
2. **Graphics.** `cd demo-video/remotion`, `npm install`, `npm run render:all`. Now they match the audio lengths. `npm run studio` opens a live preview where you can scrub every graphic. All numbers come from `src/data.ts`; fill `benchmark` there if you want the benchmark card.
3. **Screen recordings** (T2 and T3 only). Either let the recorder do it (see [`recorder/README.md`](recorder/README.md)), then run `npm run assemble` in `remotion/` for finished MP4s with no editing, or record by hand: Follow `shot-lists.md`. Record silently, one clip per `screen` scene, named by scene id. Use a recorder with automatic zoom on clicks:
   - Windows: **FocuSee** or **Tella** (Tella also has a free tier to try).
   - Mac: **Screen Studio**.
   Settings: 1920×1080 browser window, browser zoom 125 % so SQL is readable, light Databricks theme, bookmarks bar and other tabs hidden, notifications off.
4. **Assemble in Descript** (or any editor). New project per video, then in scene order: graphic or screen clip on the video track, its MP3 under it. Trim each picture to its audio, stretch or freeze the last frame of screen clips if the narration runs longer, add `LowerThird-Fictional.mov` (transparent) over the first screen clip, import the SRTs or let Descript caption it. Export 1080p MP4.

Tips: keep 0.3 s of silence between scenes; add quiet background music at around −28 dB if you like; watch the first export once on a phone, where small SQL text is the usual problem.

## Before recording (from the demo scripts)

- Rebuild the reference and governance model on the 70,000-person data the same day, since HRBP scope uses today's date.
- Run each query once so the warehouse is warm, then clear the results.
- Pick the employee for the salary question, and the HRBP and manager personas from `02_hrbp_access_activity.sql`.
- Everything on screen is synthetic Tema data. Never record a workspace with real employee data.
