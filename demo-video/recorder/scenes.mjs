// What happens on screen in each recorded scene. Ids match narration/scenes.json.
// setup() runs before recording starts (navigation, getting the page into the right state);
// run() is what the camera sees; cleanup() always runs afterwards, even if run() failed.

const NAIVE_SQL = `SELECT year_quarter, SUM(headcount) AS headcount
FROM workspace.tema_hr_semantic.v_headcount_naive
WHERE year_quarter = '2025-Q2'
GROUP BY ALL;`;

const SEMANTIC_SQL = `SELECT quarter, MEASURE(headcount) AS headcount
FROM workspace.tema_hr_semantic.workforce_metrics
WHERE quarter = '2025-Q2'
GROUP BY ALL;`;

// ---------------- SQL editor ----------------
const editorCandidates = [
  (p) => p.locator('.monaco-editor .view-lines'),
  (p) => p.locator('[class*="editor" i] .view-lines'),
  (p) => p.locator('.cm-content'),
  (p) => p.getByRole('textbox', {name: /editor/i}),
];

async function editor(d) {
  const ed = await d.find(editorCandidates, 15000);
  if (!ed) await d.manual('Click inside the SQL editor so the text cursor is in it.');
  return ed;
}

async function replaceSql(d, sql, {visible = true} = {}) {
  const ed = await editor(d);
  if (ed) {
    if (visible) await d.click(ed, {offset: {x: 40, y: 20}});
    else await ed.click({position: {x: 40, y: 20}});
  }
  // Paste the query instead of typing it. Typing in the Databricks editor loses the line breaks
  // ("headcountFROM ..."), whatever key is used; a paste keeps the text exactly as written.
  await d.page.keyboard.press('Control+A');
  await d.page.keyboard.press('Delete');
  await setClipboard(d, sql);
  if (visible) d.event({type: 'typing', on: true});
  await d.page.keyboard.press('Control+V');
  if (visible) d.event({type: 'typing', on: false});
  await new Promise((r) => setTimeout(r, 400));
  // Read the editor back (select all + copy) and make sure it holds exactly this query.
  const norm = (t) => t.replace(/\s+/g, ' ').trim();
  const got = await editorTextViaCopy(d);
  if (got !== null && norm(got) !== norm(sql)) throw new Error(`The SQL editor holds the wrong text: "${norm(got).slice(0, 120)}"`);
  if (got === null) d.log('  (could not read the editor back to check the query; carrying on)');
  // Move the pointer off the query so it doesn't cover the code or the result.
  if (visible) await d.moveTo({x: d.viewport.width * 0.72, y: d.viewport.height * 0.36});
}

async function setClipboard(d, text) {
  const ok = await d.page.evaluate((t) => navigator.clipboard.writeText(t).then(() => true, () => false), text).catch(() => false);
  if (!ok) throw new Error('Could not use the clipboard to paste the query. Click into the Chrome window once and try again.');
}

/** The editor's text, read by selecting all and copying. Leaves the cursor at the end. */
async function editorTextViaCopy(d) {
  await d.page.keyboard.press('Control+A');
  await d.page.keyboard.press('Control+C');
  await new Promise((r) => setTimeout(r, 150));
  await d.page.keyboard.press('Control+End');
  return d.page.evaluate(() => navigator.clipboard.readText().catch(() => null)).catch(() => null);
}

async function runQuery(d, c) {
  await d.press(c.runQueryKey);
  // A stopped warehouse asks "Start compute resource?" first: accept it (the wait is sped up in the video).
  await d.waiting(async () => {
    const btn = await d.find([(p) => p.getByRole('dialog').getByRole('button', {name: /start,? attach and run|start and run|^start$|start compute/i})], 4000);
    if (btn) {
      d.log('  (the SQL warehouse was stopped; starting it)');
      await btn.click();
    }
  });
  await d.settle({min: 2, quiet: 2.5, max: 240});
  const err = await d.page.getByText(/PARSE_SYNTAX_ERROR|UNRESOLVED_COLUMN|TABLE_OR_VIEW_NOT_FOUND|\[[A-Z_]{6,}\]/).first().textContent({timeout: 500}).catch(() => null);
  if (err) throw new Error(`The query failed on screen: ${err.trim().slice(0, 120)}`);
}

/** Zoom onto the expected number. If it isn't on screen, the scene is wrong: fail it so it gets re-recorded. */
async function focusNumber(d, pattern) {
  const hit = await d.waitForText(new RegExp(pattern), {max: 30});
  if (!hit) throw new Error(`Expected ${pattern} on screen, but it never appeared.`);
  await d.focus(hit, {zoom: 2.2, pad: 140});
}

/** Rectangle of a piece of text inside the code editor (for drag-selecting it). */
async function textRect(d, needle) {
  return d.page.evaluate((needle) => {
    for (const line of document.querySelectorAll('.view-line, .cm-line')) {
      const text = line.textContent.replace(/ /g, ' ');
      const i = text.indexOf(needle);
      if (i < 0) continue;
      const walker = document.createTreeWalker(line, NodeFilter.SHOW_TEXT);
      const range = document.createRange();
      let pos = 0, node, started = false;
      while ((node = walker.nextNode())) {
        const len = node.textContent.length;
        if (!started && i < pos + len) {
          range.setStart(node, i - pos);
          started = true;
        }
        if (started && i + needle.length <= pos + len) {
          range.setEnd(node, i + needle.length - pos);
          const r = range.getBoundingClientRect();
          return {x: r.x, y: r.y, width: r.width, height: r.height};
        }
        pos += len;
      }
    }
    return null;
  }, needle);
}

async function dragSelect(d, needle) {
  const r = await textRect(d, needle);
  if (!r) return false;
  await d.moveTo({x: r.x + 1, y: r.y + r.height / 2});
  await d.page.mouse.down();
  d.event({type: 'click', x: d.mouse.x, y: d.mouse.y});
  await d.moveTo({x: r.x + r.width - 1, y: r.y + r.height / 2}, {duration: 0.9});
  await d.page.mouse.up();
  return true;
}

// ---------------- Genie ----------------
const genieInput = [
  (p) => p.getByPlaceholder(/ask/i),
  (p) => p.getByRole('textbox', {name: /ask|question|message/i}),
  (p) => p.locator('textarea'),
  (p) => p.locator('[contenteditable="true"]'),
];

/** Close Genie's right-hand panel (About / Sources / Instructions), which shows the owner's email. Cut from the video. */
async function hideGeniePanel(d) {
  await d.waiting(async () => {
    for (let i = 0; i < 3; i++) {
      const about = d.page.getByRole('tab', {name: /^about$/i}).first();
      if (!(await about.isVisible().catch(() => false))) break;
      const tab = await about.boundingBox();
      // The panel's close button: an "x" button on the same row as the tabs, to their right.
      let closed = false;
      for (const btn of await d.page.getByRole('button', {name: /close/i}).all()) {
        const b = await btn.boundingBox().catch(() => null);
        if (b && tab && b.x > tab.x && Math.abs(b.y + b.height / 2 - (tab.y + tab.height / 2)) < 40) {
          await btn.click().catch(() => {});
          closed = true;
          break;
        }
      }
      if (!closed) {
        const cfg = d.page.getByRole('button', {name: /^configure$/i}).first();
        if (await cfg.isVisible().catch(() => false)) await cfg.click().catch(() => {});
      }
      await new Promise((r) => setTimeout(r, 600));
    }
    // Never record a personal email address.
    if (await d.page.getByText(/[\w.+-]+@(gmail|outlook|hotmail|yahoo|icloud)\.com/i).first().isVisible().catch(() => false)) {
      await d.manual("An email address is on screen. Close Genie's right-hand panel (the X next to About / Sources), then press Enter.");
    }
  }, 'cut');
}

/** Wait until Genie has finished answering: no "Analyzing" / "Skip to a faster answer" / stop button for 3 s. */
async function waitForGenieAnswer(d, maxSec = 240) {
  const busy = () =>
    d.page
      .evaluate(() => {
        const t = document.body.innerText;
        if (/skip to a faster answer|analyzing the data|thinking…|thinking\.\.\.|generating|running query/i.test(t)) return true;
        return [...document.querySelectorAll('button')].some((b) => /^stop/i.test((b.getAttribute('aria-label') || b.textContent || '').trim()));
      })
      .catch(() => false);
  await d.waiting(async () => {
    const end = Date.now() + maxSec * 1000;
    let quietSince = null;
    while (Date.now() < end) {
      await new Promise((r) => setTimeout(r, 500));
      if (await busy()) quietSince = null;
      else if (quietSince === null) quietSince = Date.now();
      else if (Date.now() - quietSince > 3000) return;
    }
    d.log('  (Genie was still working after the time limit; carrying on)');
  });
  await d.settle({min: 1, quiet: 3, max: 60});
}

async function askGenie(d, question, {expect} = {}) {
  await hideGeniePanel(d);
  const box = await d.find(genieInput, 20000);
  if (!box) {
    await d.manual(`Type this question into Genie and send it: ${question}`);
    await d.settle({min: 5, quiet: 4, max: 180});
    return null;
  }
  await d.click(box);
  await d.type(question);
  await d.hold(0.4);
  await d.press('Enter');
  await waitForGenieAnswer(d);
  if (expect) {
    const hit = await d.waitForText(new RegExp(expect), {max: 20});
    if (hit) {
      await d.focus(hit, {zoom: 1.8, pad: 160});
      return box;
    }
  }
  const b = await box.boundingBox();
  if (b) {
    const top = Math.max(60, b.y - 620);
    await d.focus({x: b.x - 20, y: top, width: b.width + 40, height: b.y - top - 10}, {zoom: 1.35, pad: 0});
  }
  return box;
}

// ---------------- Notebook ----------------
/** Notebooks only draw cells near the screen, so scroll through the notebook until the text appears. */
async function findInNotebook(d, text, {last = false} = {}) {
  const loc = () => (last ? d.page.getByText(text).last() : d.page.getByText(text).first());
  const visible = async () => (await loc().isVisible().catch(() => false)) ? loc() : null;
  await d.page.keyboard.press('Escape').catch(() => {}); // leave edit mode so the wheel scrolls the notebook
  const at = {x: d.viewport.width * 0.55, y: d.viewport.height * 0.55};
  await d.page.mouse.move(at.x, at.y);
  let hit = await visible();
  if (hit) return hit;
  // From the top, then down in screen-sized steps (and from the bottom up, for `last`).
  const dir = last ? 1 : -1;
  for (let i = 0; i < 30; i++) await d.page.mouse.wheel(0, dir * 3000);
  await d.page.waitForTimeout(600);
  for (let i = 0; i < 80; i++) {
    if ((hit = await visible())) return hit;
    await d.page.mouse.wheel(0, -dir * 500);
    await d.page.waitForTimeout(250);
  }
  return null;
}

async function runCell(d, c, text, {last = false, visible = true} = {}) {
  // Safety net: if a cell still has to be searched for on camera, cut that scrolling from the video.
  const loc = await d.waiting(() => findInNotebook(d, text, {last}), 'cut');
  if (!loc) {
    await d.manual(`Run the notebook cell that contains: ${text}`);
    await d.settle({min: 2, quiet: 3, max: 240});
    return null;
  }
  await loc.scrollIntoViewIfNeeded().catch(() => {});
  if (visible) await d.click(loc);
  else await loc.click();
  await d.page.keyboard.press(c.runCellKey);
  await d.settle({min: 2, quiet: 3, max: 240});
  return loc;
}

/**
 * Before recording: find a cell and park it near the top of the screen, so the recorded scene
 * starts on the right cell instead of scrolling the notebook on camera.
 */
async function positionCell(d, text, {last = false, top = 110} = {}) {
  const loc = await findInNotebook(d, text, {last});
  if (!loc) return null;
  await loc.evaluate((el) => el.scrollIntoView({block: 'start'})).catch(() => {});
  await d.page.waitForTimeout(300);
  await d.page.mouse.wheel(0, -top);
  await d.page.waitForTimeout(600);
  return loc;
}

/** Focus the output under the cell we just ran. */
async function focusOutputBelow(d, loc, height = 430) {
  const b = loc && (await loc.boundingBox().catch(() => null));
  if (!b) return;
  await d.focus({x: Math.max(0, b.x - 60), y: b.y + 10, width: Math.min(d.viewport.width - b.x + 60, 1100), height}, {zoom: 1.4, pad: 0});
}

let notebookReady = false;
async function notebookSetup(d, c) {
  await d.goto(c.hrbpNotebookUrl);
  if (notebookReady) return;
  await runCell(d, c, 'USE SCHEMA tema_hr_secure', {visible: false});
  await runCell(d, c, 'DECLARE OR REPLACE VARIABLE hrbp_a BIGINT', {visible: false});
  notebookReady = true;
}

const sqlSetup = async (d, c, prefill) => {
  await d.goto(c.sqlQueryUrl);
  await replaceSql(d, prefill ?? '', {visible: false});
};

// ---------------- the scenes ----------------
export const SCENES = {
  'T2-02': {
    setup: (d, c) => sqlSetup(d, c, ''),
    async run(d, c) {
      await d.hold(0.8);
      await replaceSql(d, NAIVE_SQL);
      await runQuery(d, c);
      await focusNumber(d, c.expect.naive);
      await d.hold(3);
    },
  },
  'T2-03': {
    async setup(d, c) {
      await sqlSetup(d, c, NAIVE_SQL);
      await d.page.keyboard.press(c.runQueryKey);
      await d.settle({min: 2, quiet: 2.5, max: 180});
    },
    async run(d) {
      const ed = await editor(d);
      if (ed) await d.focus(ed, {zoom: 1.8, pad: 30});
      await d.hold(0.8);
      if (!(await dragSelect(d, 'SUM(headcount)'))) await d.manual('Select the text SUM(headcount) in the editor.');
      await d.hold(2.2);
      await dragSelect(d, "'2025-Q2'");
      await d.hold(2);
    },
  },
  'T2-04': {
    setup: (d, c) => sqlSetup(d, c, NAIVE_SQL),
    async run(d, c) {
      await d.hold(0.6);
      await replaceSql(d, SEMANTIC_SQL);
      await runQuery(d, c);
      await focusNumber(d, c.expect.semantic);
      await d.hold(4);
    },
  },
  'T3-02': {
    setup: (d, c) => sqlSetup(d, c, ''),
    async run(d, c) {
      const delay = d.typingDelayMs;
      d.typingDelayMs = Math.min(delay, 22);
      try {
        await replaceSql(d, NAIVE_SQL);
        await runQuery(d, c);
        await focusNumber(d, c.expect.naive);
        await d.hold(2.5);
        d.unfocus();
        await replaceSql(d, SEMANTIC_SQL);
        await runQuery(d, c);
        await focusNumber(d, c.expect.semantic);
        await d.hold(3);
      } finally {
        d.typingDelayMs = delay;
      }
    },
  },
  'T3-03': {
    setup: (d, c) => d.goto(`${c.workspaceUrl.replace(/\/$/, '')}/explore/data/workspace/tema_hr_semantic`),
    async run(d) {
      await d.hold(1);
      await d.scroll(320, {at: {x: d.viewport.width * 0.55, y: d.viewport.height * 0.6}});
      await d.hold(0.8);
      await d.scroll(-320);
      const link = await d.find([(p) => p.getByRole('link', {name: 'workforce_metrics', exact: true}), (p) => p.getByText('workforce_metrics', {exact: true})]);
      if (link) await d.click(link);
      else await d.manual('Open the workforce_metrics metric view.');
      await d.settle({min: 2, quiet: 2, max: 60});
      await d.hold(1.2);
      await d.scroll(420, {at: {x: d.viewport.width * 0.55, y: d.viewport.height * 0.6}, steps: 20});
      await d.hold(2.5);
    },
  },
  'T3-06': {
    setup: (d, c) => d.goto(c.genieRawUrl),
    async run(d, c) {
      // Benchmark Q2: raw used its own window and included part-time (11.65% on Nov 13); the semantic layer gives 12.4%.
      // Headcount was dropped here: on Nov 13 the raw agent got 58,862 right in Agent mode.
      const q = c.attritionQuestion ?? "What's our trailing 12-month attrition rate?";
      d.label('Genie on the raw tables');
      await askGenie(d, q);
      await d.hold(4);
      d.unfocus();
      d.label('HR Tech Analytics Assistant (semantic layer)');
      await d.goto(c.genieAssistantUrl);
      await askGenie(d, q, {expect: c.expect.attrition ?? '12\\.4'});
      await d.hold(4);
    },
  },
  'T3-07': {
    setup: (d, c) => d.goto(c.genieRawUrl),
    async run(d, c) {
      // One specific person, so the raw agent can't ask "which one?" (Tema has 26 current Priya Patels;
      // only one is in Applied AI & ML). Override with salaryQuestion in config.json.
      const q = c.salaryQuestion ?? 'What is the salary of Priya Patel in Applied AI & ML?';
      d.label('Genie on the raw tables');
      await askGenie(d, q, {expect: '354,900'}); // zoom on the leaked salary
      await d.hold(4);
      d.unfocus();
      d.label('HR Tech Analytics Assistant (semantic layer)');
      await d.goto(c.genieAssistantUrl);
      await askGenie(d, q, {expect: 'cannot provide|prohibit|not able to share|can.t share'}); // zoom on the refusal
      await d.hold(4);
    },
  },
  'T3-09': {
    // Switching to the HRBP persona happens off camera; the scene opens on the query that shows the result.
    async setup(d, c) {
      await notebookSetup(d, c);
      await runCell(d, c, "INSERT INTO access_personas VALUES (current_user(), 'hrbp', hrbp_a)", {visible: false});
      await positionCell(d, 'Where can hrbp_a see sensitive data?');
    },
    async run(d, c) {
      d.label('Acting as an HR business partner');
      await d.hold(0.8);
      const cell = await runCell(d, c, 'Where can hrbp_a see sensitive data?');
      await focusOutputBelow(d, cell);
      await d.hold(4);
    },
  },
  'T3-10': {
    async setup(d, c) {
      await notebookSetup(d, c);
      await positionCell(d, "INSERT INTO access_personas VALUES (current_user(), 'manager', manager_m)");
    },
    async run(d, c) {
      d.label('Acting as a people manager');
      await d.hold(0.8);
      const cell = await runCell(d, c, "INSERT INTO access_personas VALUES (current_user(), 'manager', manager_m)");
      await focusOutputBelow(d, cell);
      await d.hold(3.5);
    },
  },
  'T3-11': {
    // Park the cell's last lines (end the assignment, rebuild, check) at the top, so its output is on screen.
    async setup(d, c) {
      await notebookSetup(d, c);
      await positionCell(d, 'SET effective_to = date_sub(current_date(), 1)');
    },
    async run(d, c) {
      d.label('An HRBP assignment ends');
      await d.hold(0.8);
      const cell = await runCell(d, c, 'SET effective_to = date_sub(current_date(), 1)');
      await focusOutputBelow(d, cell, 400);
      await d.hold(3.5);
    },
    // Always put the assignment back and return to HR admin, whatever happened above.
    async cleanup(d, c) {
      d.log('  restoring the HRBP assignment and resetting to HR admin');
      await runCell(d, c, 'SET effective_to = NULL WHERE assignment_id = ended_assignment', {visible: false});
      await runCell(d, c, "INSERT INTO access_personas VALUES (current_user(), 'hr_admin', NULL)", {last: true, visible: false});
    },
  },
};

export const WARMUP = async (d, c) => {
  await sqlSetup(d, c, NAIVE_SQL);
  await d.page.keyboard.press(c.runQueryKey);
  await d.settle({max: 300});
  await replaceSql(d, SEMANTIC_SQL, {visible: false});
  await d.page.keyboard.press(c.runQueryKey);
  await d.settle({max: 300});
  await notebookSetup(d, c);
};
