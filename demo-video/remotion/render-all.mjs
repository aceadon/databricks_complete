// Renders every graphic to ../renders as 1080p MP4 (the lower third as a transparent .mov).
// Usage:  npm run render:all              (everything)
//         npm run render:all -- Spiel30   (just the ones you name)
// Optional: set BROWSER to a Chrome/Chromium headless shell to skip Remotion's own download.
import {execFileSync} from 'node:child_process';
import {mkdirSync, readFileSync} from 'node:fs';

const benchmarkFilled = !/raw:\s*null/.test(readFileSync('src/data.ts', 'utf8'));
const ALL = [
  'Spiel30',
  'TitleCard-2min', 'TitleCard-5min', 'GapIntro', 'NumberReveal', 'CostCallout-Tema', 'CostCallout-AI',
  'FutureState', 'EndCard-2min', 'SectionCard-1', 'SectionCard-2', 'SectionCard-3', 'QuestionCard-Attrition',
  ...(benchmarkFilled ? ['BenchmarkCard'] : []), 'AccessRule', 'GapSummary', 'EndCard-5min', 'LowerThird-Fictional',
];
const only = process.argv.slice(2);
const ids = only.length ? only : ALL;
mkdirSync('../renders', {recursive: true});
for (const id of ids) {
  const alpha = id.startsWith('LowerThird');
  const out = `../renders/${id}.${alpha ? 'mov' : 'mp4'}`;
  const args = ['remotion', 'render', 'src/index.ts', id, out, '--log=error'];
  if (alpha) args.push('--codec=prores', '--prores-profile=4444', '--pixel-format=yuva444p10le', '--image-format=png');
  else args.push('--codec=h264', '--crf=16');
  if (process.env.BROWSER) args.push(`--browser-executable=${process.env.BROWSER}`);
  console.log(`Rendering ${id} -> ${out}`);
  execFileSync('npx', args, {stdio: 'inherit', shell: process.platform === 'win32'});
}
if (!benchmarkFilled) console.log('Skipped BenchmarkCard: fill DATA.benchmark in src/data.ts to render it.');
