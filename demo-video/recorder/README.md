# Recorder: Claude drives Databricks, you watch

`record.mjs` opens its own Chrome window, plays each screen scene from the shot list (clicks, typing, running
queries, asking Genie, running notebook cells) and saves the frames plus a timeline of what it did. Remotion then
adds a smooth cursor, click ripples and zooms, fast-forwards the waiting (queries running, Genie thinking) so each
scene fits your narration, and assembles the finished videos.

## One-time setup (about 10 minutes)

1. In Databricks:
   - SQL Editor: create a new **empty** query called `Demo recording`, attach your SQL warehouse, save it. Copy its URL.
   - The two Genie spaces (*Tema raw (baseline)* and *People Analytics Assistant*): build them by hand (Week 7), or
     run `python hr_people_analytics\genie\create_genie_spaces.py` after filling in `workspaceUrl` below. It needs a
     personal access token in `DATABRICKS_TOKEN`, creates both, tests them and writes their URLs into `config.json`.
   - Copy the URL of the notebook `hr_people_analytics/governance/02_hrbp_access_activity`. Make sure `01_hrbp_access_model.sql` was run today.
2. In PowerShell:
   ```
   cd $env:USERPROFILE\Videos\tema-demo\demo-video\recorder
   git pull
   npm install
   copy config.example.json config.json
   notepad config.json        # paste the URLs, check the employee for the salary question
   npm run login              # log in to Databricks in the window that opens, then press Enter in PowerShell
   ```
   The login is kept in `recorder\.profile`, so you only do this once. That folder is yours only and is not in Git.

## Recording

```
npm run warmup     # runs the queries once so the warehouse is warm (not recorded)
npm run record     # records all nine scenes, about 10 minutes
```

While it runs, leave the Chrome window alone; you can use other apps. If it can't find something on the page it
stops and tells you in PowerShell what to do by hand ("Run the notebook cell that contains ..."). Do that in the
Chrome window and press Enter in PowerShell. That waiting is cut out of the video. At the end it lists any scenes
that failed, with a screenshot `failed-<scene>.png` of what the page looked like.

To redo one scene: `node record.mjs --scene T3-06` (several: `--scene T2-02,T2-04`).

Scene T3-11 really ends an HRBP assignment, as the activity notebook does; the recorder always runs the notebook's
"put the assignment back" and "reset to HR admin" cells straight afterwards, even if something failed.

## Building the videos

```
cd ..\remotion
npm run assemble          # all three; or: npm run assemble -- T3
```

The finished videos are in `demo-video\renders\final\` (T1.mp4, T2.mp4, T3.mp4). Scenes you haven't recorded yet
show a placeholder, so you can assemble at any time. `npm run studio` lets you scrub through `FullVideo-T2` and
`FullVideo-T3` before rendering.

## Changing what happens in a scene

Each scene is a short function in `scenes.mjs` (e.g. what to type, which cell to run, where to zoom). Narration and
timing come from `../narration/scenes.json` and `durations.json`.
