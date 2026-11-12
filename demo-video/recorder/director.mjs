// The Director records one scene: it streams the page's frames to JPEG files and logs what it does
// (mouse moves, clicks, typing, zooms, waits) so Remotion can draw a smooth cursor, zoom the camera
// and speed up the waiting parts to fit the narration.
import {mkdirSync, rmSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import readline from 'node:readline';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export class Director {
  constructor(page, {outRoot, viewport, outWidth = 1920, typingDelayMs = 40, log = console.log}) {
    this.page = page;
    this.outRoot = outRoot;
    this.viewport = viewport;
    this.scale = outWidth / viewport.width; // CSS px -> output px
    this.typingDelayMs = typingDelayMs;
    this.log = log;
    this.mouse = {x: viewport.width / 2, y: viewport.height / 2};
    this.recording = false;
  }

  // ---------- recording ----------
  async start(sceneId) {
    this.sceneId = sceneId;
    this.dir = join(this.outRoot, sceneId);
    rmSync(this.dir, {recursive: true, force: true});
    mkdirSync(this.dir, {recursive: true});
    this.frames = [];
    this.events = [];
    this.segments = [];
    this.segKind = 'action';
    this.cdp = await this.page.context().newCDPSession(this.page);
    this.t0 = Date.now() / 1000;
    this.segStart = 0;
    let n = 0;
    this.cdp.on('Page.screencastFrame', async (f) => {
      const file = `f${String(++n).padStart(6, '0')}.jpg`;
      try {
        writeFileSync(join(this.dir, file), Buffer.from(f.data, 'base64'));
        const ts = (f.metadata.timestamp ?? Date.now() / 1000) - this.t0;
        this.frames.push({file, t: +ts.toFixed(3)});
      } catch {}
      this.cdp.send('Page.screencastFrameAck', {sessionId: f.sessionId}).catch(() => {});
    });
    await this.cdp.send('Page.startScreencast', {format: 'jpeg', quality: 92, maxWidth: 1920, maxHeight: 1080, everyNthFrame: 1});
    this.recording = true;
    // Nudge a repaint so there is a first frame even on a static page.
    await this.page.evaluate(() => {
      const d = document.createElement('div');
      d.style.cssText = 'position:fixed;left:0;top:0;width:1px;height:1px;opacity:0.01;pointer-events:none';
      document.body.appendChild(d);
      setTimeout(() => d.remove(), 100);
    }).catch(() => {});
    await sleep(300);
    this.event({type: 'cursor', x: this.mouse.x, y: this.mouse.y});
  }

  async stop() {
    if (!this.recording) return;
    await sleep(400);
    this.closeSegment();
    await this.cdp.send('Page.stopScreencast').catch(() => {});
    await this.cdp.detach().catch(() => {});
    this.recording = false;
    const end = this.now();
    const capture = {
      scene: this.sceneId,
      width: 1920,
      height: 1080,
      scale: this.scale,
      duration: +end.toFixed(3),
      frames: this.frames.sort((a, b) => a.t - b.t),
      events: this.events,
      segments: this.segments,
    };
    writeFileSync(join(this.dir, 'capture.json'), JSON.stringify(capture));
    this.log(`  saved ${this.frames.length} frames, ${end.toFixed(1)} s (${this.waitTotal().toFixed(1)} s of waiting, sped up later)`);
  }

  now() {
    return Date.now() / 1000 - this.t0;
  }
  event(e) {
    if (this.recording) this.events.push({t: +this.now().toFixed(3), ...e});
  }
  closeSegment() {
    const t = this.now();
    if (t - this.segStart > 0.01) this.segments.push({kind: this.segKind, start: +this.segStart.toFixed(3), end: +t.toFixed(3)});
    this.segStart = t;
  }
  waitTotal() {
    return this.segments.filter((s) => s.kind === 'wait').reduce((a, s) => a + s.end - s.start, 0);
  }
  /** Everything inside fn is "waiting" (loading, query running): Remotion fast-forwards it. */
  async waiting(fn) {
    if (!this.recording) return fn();
    this.closeSegment();
    this.segKind = 'wait';
    try {
      return await fn();
    } finally {
      this.closeSegment();
      this.segKind = 'action';
    }
  }

  // ---------- pop-ups ----------
  /** Close Databricks pop-ups (tours, "what's new", feature announcements) that block clicks. */
  async dismissDialogs() {
    for (let i = 0; i < 4; i++) {
      const dlg = this.page.locator('[role="dialog"][aria-modal="true"], [role="alertdialog"]').first();
      if (!(await dlg.isVisible().catch(() => false))) return;
      const btn = dlg.getByRole('button', {name: /^(close|got it|dismiss|skip( tour)?|not now|maybe later|no,? thanks|ok|done|continue)$/i}).first();
      if (await btn.isVisible().catch(() => false)) await btn.click().catch(() => {});
      else {
        const x = dlg.locator('button[aria-label*="close" i]').first();
        if (await x.isVisible().catch(() => false)) await x.click().catch(() => {});
        else await this.page.keyboard.press('Escape');
      }
      await sleep(500);
    }
  }

  // ---------- finding things ----------
  /** First visible match among candidate locators, or null. */
  async find(candidates, timeout = 8000) {
    const list = Array.isArray(candidates) ? candidates : [candidates];
    if (!this.recording) await this.dismissDialogs();
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      for (const c of list) {
        const loc = typeof c === 'function' ? c(this.page) : c;
        try {
          const first = loc.first();
          if (await first.isVisible()) return first;
        } catch {}
      }
      await sleep(250);
    }
    return null;
  }

  /** Ask the person at the keyboard to do a step by hand. Recording continues; this time is fast-forwarded. */
  async manual(instruction) {
    this.log(`\n  >>> Couldn't do this automatically. In the Chrome window: ${instruction}`);
    this.log('  >>> Then press Enter here to carry on.');
    await this.waiting(async () => {
      const rl = readline.createInterface({input: process.stdin, output: process.stdout});
      await new Promise((r) => rl.question('', () => (rl.close(), r())));
    });
  }

  async box(target) {
    if (target && typeof target.boundingBox === 'function') {
      await target.scrollIntoViewIfNeeded().catch(() => {});
      return target.boundingBox();
    }
    return target; // {x, y, width?, height?}
  }

  // ---------- acting ----------
  async moveTo(target, {duration = 0.7, offset} = {}) {
    const b = await this.box(target);
    if (!b) return;
    const x = offset ? b.x + offset.x : b.x + (b.width ?? 0) / 2;
    const y = offset ? b.y + offset.y : b.y + (b.height ?? 0) / 2;
    const from = {...this.mouse};
    const dist = Math.hypot(x - from.x, y - from.y);
    const dur = Math.max(0.25, Math.min(duration, 0.25 + dist / 1400));
    this.event({type: 'move', x0: from.x, y0: from.y, x1: x, y1: y, dur: +dur.toFixed(3)});
    const steps = Math.max(5, Math.round(dur * 30));
    for (let i = 1; i <= steps; i++) {
      const p = i / steps;
      const e = p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2;
      await this.page.mouse.move(from.x + (x - from.x) * e, from.y + (y - from.y) * e);
      await sleep((dur * 1000) / steps);
    }
    this.mouse = {x, y};
  }

  async click(target, {clickCount = 1, offset} = {}) {
    await this.moveTo(target, {offset});
    await sleep(120);
    this.event({type: 'click', x: this.mouse.x, y: this.mouse.y});
    await this.page.mouse.click(this.mouse.x, this.mouse.y, {clickCount});
    await sleep(250);
  }

  /** Type like a person. For code editors, closes autocomplete before each new line. */
  async type(text, {codeEditor = false} = {}) {
    this.event({type: 'typing', on: true});
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      await this.page.keyboard.type(lines[i], {delay: this.typingDelayMs});
      if (i < lines.length - 1) {
        if (codeEditor) await this.page.keyboard.press('Escape');
        await this.page.keyboard.press('Enter');
      }
    }
    if (codeEditor) await this.page.keyboard.press('Escape');
    this.event({type: 'typing', on: false});
  }

  async press(key) {
    this.event({type: 'key', key});
    await this.page.keyboard.press(key);
    await sleep(150);
  }

  async scroll(dy, {steps = 12, at} = {}) {
    if (at) await this.moveTo(at);
    for (let i = 0; i < steps; i++) {
      await this.page.mouse.wheel(0, dy / steps);
      await sleep(40);
    }
  }

  /** Hold still (on camera, not sped up). */
  async hold(sec) {
    await sleep(sec * 1000);
  }

  /** Wait until the page stops changing (query results, Genie answers). Fast-forwarded in the edit. */
  async settle({min = 1.5, quiet = 2.5, max = 90} = {}) {
    await this.waiting(async () => {
      const start = Date.now();
      let last = -1;
      let stableSince = Date.now();
      while (Date.now() - start < max * 1000) {
        await sleep(500);
        const sig = await this.page
          .evaluate(() => {
            const busy = document.querySelectorAll('[aria-busy="true"], [role="progressbar"], .spinner, [data-testid*="spinner" i], [class*="loading" i]').length;
            return document.body.innerText.length * 10 + Math.min(busy, 9);
          })
          .catch(() => last);
        if (sig !== last) {
          last = sig;
          stableSince = Date.now();
        }
        if (Date.now() - start > min * 1000 && Date.now() - stableSince > quiet * 1000 && sig % 10 === 0) return;
      }
      this.log('  (page still changing after the time limit; carrying on)');
    });
  }

  async waitForText(re, {max = 90} = {}) {
    let found = null;
    await this.waiting(async () => {
      found = await this.find([(p) => p.getByText(re)], max * 1000);
    });
    return found;
  }

  /** Zoom the camera onto an element or rectangle (CSS px). */
  async focus(target, {zoom = 1.6, pad = 24} = {}) {
    const b = await this.box(target);
    if (!b) return;
    const s = this.scale;
    this.event({
      type: 'focus',
      x: (b.x - pad) * s,
      y: (b.y - pad) * s,
      w: ((b.width ?? 0) + 2 * pad) * s,
      h: ((b.height ?? 0) + 2 * pad) * s,
      zoom,
    });
  }
  unfocus() {
    this.event({type: 'unfocus'});
  }
  /** A caption pill shown in the corner of the video, e.g. which Genie space this is. */
  label(text) {
    this.event({type: 'label', text});
  }

  // ---------- navigation (not recorded unless called during a scene) ----------
  async goto(url) {
    await this.waiting(async () => {
      await this.page.goto(url, {waitUntil: 'domcontentloaded', timeout: 120000});
    });
    await this.settle({min: 2, quiet: 2, max: 60});
    await this.dismissDialogs();
  }
}
