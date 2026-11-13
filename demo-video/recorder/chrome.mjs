// Starts your own Google Chrome (not an automated one) with its own recording profile and a local debugging
// port, so the recorder can attach to it. Google sign-in works here because Chrome isn't under automation.
//   npm run chrome      then log in to Databricks in that window (once; the profile remembers it)
import {spawn} from 'node:child_process';
import {existsSync, readFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const cfg = existsSync(join(HERE, 'config.json')) ? JSON.parse(readFileSync(join(HERE, 'config.json'), 'utf8')) : {};
const port = String(cfg.cdpPort ?? 9222);
const candidates = [
  process.env.CHROME_PATH,
  join(process.env.PROGRAMFILES ?? 'C:\\Program Files', 'Google\\Chrome\\Application\\chrome.exe'),
  join(process.env['PROGRAMFILES(X86)'] ?? 'C:\\Program Files (x86)', 'Google\\Chrome\\Application\\chrome.exe'),
  join(process.env.LOCALAPPDATA ?? '', 'Google\\Chrome\\Application\\chrome.exe'),
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].filter(Boolean);
const chrome = candidates.find((p) => existsSync(p));
if (!chrome) {
  console.error('Could not find Chrome. Set CHROME_PATH to chrome.exe and try again.');
  process.exit(1);
}
const args = [
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${join(HERE, '.chrome-profile')}`, // Chrome only allows a debugging port on a separate profile
  '--window-size=1600,1000',
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-backgrounding-occluded-windows',
  '--disable-renderer-backgrounding',
  '--disable-background-timer-throttling',
  cfg.workspaceUrl ?? 'about:blank',
];
// Is a Chrome with the debugging port already up? Then just reuse it.
const probe = async () => {
  try {
    const r = await fetch(`http://127.0.0.1:${port}/json/version`, {signal: AbortSignal.timeout(1500)});
    return r.ok;
  } catch {
    return false;
  }
};
if (await probe()) {
  console.log(`Your recording Chrome is already running on port ${port}. Leave it open and run: npm run warmup, then npm run record`);
  process.exit(0);
}
spawn(chrome, args, {detached: true, stdio: 'ignore'}).unref();
let up = false;
for (let i = 0; i < 20 && !up; i++) {
  await new Promise((r) => setTimeout(r, 750));
  up = await probe();
}
if (!up) {
  console.error(`Chrome opened, but its debugging port ${port} isn't answering, so the recorder can't attach.`);
  console.error('This usually means a window from the recording profile was already open without the port.');
  console.error('Close every Chrome window that uses the recording profile (or run: taskkill /IM chrome.exe /F , which closes all Chrome), then run npm run chrome again.');
  process.exit(1);
}
console.log(`Chrome started with the recording profile, and port ${port} is answering.`);
console.log('If the window shows your Databricks workspace, you are logged in. If not, log in there (Google sign-in works). Leave it open.');
console.log('Then, in this window: npm run warmup, then npm run record');
