// Records the Databricks screen scenes for the demo videos.
//
//   npm install                 once
//   npm run login               once: a Chrome window opens, log in to Databricks, press Enter here
//   npm run warmup              optional: runs the queries once so the warehouse is warm
//   npm run record              records every scene (or: node record.mjs --scene T2-02,T3-06)
//
// Frames and a timeline for each scene go to ../remotion/public/capture/<scene>/.
// Then, in ../remotion: npm run assemble   (builds the finished videos).
import {chromium} from 'playwright';
import {existsSync, readFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import readline from 'node:readline';
import {Director} from './director.mjs';
import {SCENES, WARMUP} from './scenes.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const opt = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};

const cfgPath = opt('config') ?? join(HERE, 'config.json');
if (!existsSync(cfgPath)) {
  console.error('No config.json yet. Copy config.example.json to config.json and fill in the URLs.');
  process.exit(1);
}
const c = JSON.parse(readFileSync(cfgPath, 'utf8'));
for (const k of ['workspaceUrl', 'sqlQueryUrl', 'genieRawUrl', 'genieAssistantUrl', 'hrbpNotebookUrl']) {
  if (!/^https?:\/\//.test(c[k] ?? '')) console.warn(`config.json: ${k} doesn't look like a URL yet; scenes that need it will fail.`);
}

const ask = (q) =>
  new Promise((r) => {
    const rl = readline.createInterface({input: process.stdin, output: process.stdout});
    rl.question(q, (a) => (rl.close(), r(a)));
  });

// 1536x864 CSS px at 125% = 1920x1080 frames: the "zoomed browser" look, readable on video.
const viewport = {width: 1536, height: 864};
const context = await chromium.launchPersistentContext(opt('profile') ?? join(HERE, '.profile'), {
  channel: c.browserChannel || undefined,
  headless: flag('headless'),
  viewport,
  deviceScaleFactor: 1.25,
  colorScheme: 'light',
  args: ['--hide-scrollbars', '--disable-infobars', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding', '--disable-background-timer-throttling'],
  ignoreDefaultArgs: ['--enable-automation'],
});
const page = context.pages()[0] ?? (await context.newPage());
const d = new Director(page, {
  outRoot: opt('out') ?? join(HERE, '..', 'remotion', 'public', 'capture'),
  viewport,
  typingDelayMs: c.typingDelayMs ?? 40,
});

try {
  if (flag('login')) {
    await page.goto(c.workspaceUrl);
    await ask('Log in to Databricks in the Chrome window. When you can see your workspace, press Enter here. ');
  } else if (flag('warmup')) {
    console.log('Warming up: running the demo queries once (not recorded)...');
    await WARMUP(d, c);
    console.log('Warm.');
  } else {
    const want = (opt('scene') ?? Object.keys(SCENES).join(',')).split(',').map((s) => s.trim()).filter(Boolean);
    const unknown = want.filter((id) => !SCENES[id]);
    if (unknown.length) throw new Error(`Unknown scene(s): ${unknown.join(', ')}. Known: ${Object.keys(SCENES).join(', ')}`);
    await page.goto(c.workspaceUrl, {waitUntil: 'domcontentloaded'});
    if (/login|signin|oauth/i.test(page.url())) throw new Error('Not logged in. Run: npm run login');
    const failed = [];
    for (const id of want) {
      const s = SCENES[id];
      console.log(`\n${id}: getting ready`);
      try {
        await s.setup?.(d, c);
        console.log(`${id}: recording`);
        await d.start(id);
        try {
          await s.run(d, c);
        } finally {
          await d.stop();
          if (s.cleanup) await s.cleanup(d, c);
        }
      } catch (e) {
        failed.push(id);
        console.error(`${id} failed: ${e.message.split('\n')[0]}`);
        await page.screenshot({path: join(HERE, `failed-${id}.png`)}).catch(() => {});
      }
    }
    console.log(failed.length ? `\nDone, but these need another go: ${failed.join(', ')} (screenshots: failed-*.png)` : '\nAll scenes recorded.');
    console.log('Next: cd ../remotion && npm run assemble');
  }
} finally {
  await context.close();
}
