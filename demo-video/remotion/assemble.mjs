// Builds the finished videos: copies the narration into public/, then renders FullVideo-T1, -T2 and -T3
// to ../renders/final/. Screen scenes come from the recorder (public/capture/); any scene not recorded yet
// shows a placeholder, so you can check the edit before recording.
// Usage: npm run assemble            (all three)
//        npm run assemble -- T2      (one)
import {execFileSync} from 'node:child_process';
import {cpSync, existsSync, mkdirSync, readdirSync} from 'node:fs';

mkdirSync('public/audio', {recursive: true});
if (existsSync('../audio')) {
  for (const f of readdirSync('../audio').filter((f) => f.endsWith('.mp3') || f.endsWith('.srt'))) cpSync(`../audio/${f}`, `public/audio/${f}`);
} else console.warn('No ../audio folder yet: the videos will be silent. Run narration/generate_narration.py first.');

const videos = process.argv.slice(2).length ? process.argv.slice(2) : ['T1', 'T2', 'T3'];
mkdirSync('../renders/final', {recursive: true});
for (const v of videos) {
  const out = `../renders/final/${v}.mp4`;
  console.log(`Rendering ${v} -> ${out}`);
  const args = ['remotion', 'render', 'src/index.ts', `FullVideo-${v}`, out, '--codec=h264', '--crf=18', '--log=error'];
  if (process.env.BROWSER) args.push(`--browser-executable=${process.env.BROWSER}`);
  execFileSync('npx', args, {stdio: 'inherit', shell: process.platform === 'win32'});
}
console.log('Done. Watch them in ../renders/final/.');
