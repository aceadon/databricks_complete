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
  await d.page.keyboard.press('Control+A');
  await d.page.keyboard.press('Delete');
  const lines = sql.split('\n');
  if (visible) {
    // Type line by line. After each line, make sure a new line really started: in the Databricks editor
    // Enter can be swallowed, which fused "headcount" and "FROM" into one word.
    for (let i = 0; i < lines.length; i++) {
      await d.type(lines[i], {codeEditor: true});
      if (i === lines.length - 1) break;
      const before = await lineCount(d);
      await d.page.keyboard.press('Escape');
      await d.page.keyboard.insertText('\n');
      await new Promise((r) => setTimeout(r, 200));
      if ((await lineCount(d)) <= before) {
        await d.page.keyboard.press('Shift+Enter');
        await new Promise((r) => setTimeout(r, 200));
        if ((await lineCount(d)) <= before) await d.page.keyboard.insertText(' '); // keep it valid on one line
      }
    }
  } else await d.page.keyboard.insertText(sql);
  // Check what the editor holds before anything runs. If it's wrong, put the query in as one line,
  // which can't be mangled by line breaks.
  const norm = (t) => t.replace(/\s+/g, ' ').trim();
  let got = await editorText(d);
  if (got !== null && norm(got) !== norm(sql)) {
    d.log(`  (the editor text came out wrong, fixing it: "${norm(got).slice(0, 90)}")`);
    await d.page.keyboard.press('Control+A');
    await d.page.keyboard.press('Delete');
    await d.page.keyboard.insertText(lines.join(' '));
    await new Promise((r) => setTimeout(r, 300));
    got = await editorText(d);
    if (got !== null && norm(got) !== norm(sql)) throw new Error(`The SQL editor holds the wrong text: "${norm(got).slice(0, 120)}"`);
  }
}

async function lineCount(d) {
  return d.page.evaluate(() => document.querySelectorAll('.monaco-editor .view-line, .cm-line').length).catch(() => 0);
}

/** The code editor's text, top to bottom, or null if it can't be read. */
async function editorText(d) {
  return d.page
    .evaluate(() => {
      const lines = [...document.querySelectorAll('.monaco-editor .view-line, .cm-line')];
      if (!lines.length) return null;
      lines.sort((a, b) => a.getBoundingClientRect().top - b.getBoundingClientRect().top);
      return lines.map((l) => l.textContent.replace(/\u00a0/g, ' ')).join('\n');
    })
    .catch(() => null);
}

async function runQuery(d, c) {
  await d.press(c.runQueryKey);
  await d.settle({min: 2, quiet: 2.5, max: 180});
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

async function askGenie(d, question) {
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
  await d.settle({min: 6, quiet: 4, max: 180});
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
  const loc = await findInNotebook(d, text, {last});
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
      const q = 'How many people did we have at the end of Q2 2025?';
      d.label('Genie on the raw tables');
      await askGenie(d, q);
      await d.hold(3);
      d.unfocus();
      d.label('HR Tech Analytics Assistant (semantic layer)');
      await d.goto(c.genieAssistantUrl);
      await askGenie(d, q);
      await d.hold(3);
    },
  },
  'T3-07': {
    setup: (d, c) => d.goto(c.genieRawUrl),
    async run(d, c) {
      const q = `What's ${c.salaryEmployee}'s salary?`;
      d.label('Genie on the raw tables');
      await askGenie(d, q);
      await d.hold(2.5);
      d.unfocus();
      d.label('HR Tech Analytics Assistant (semantic layer)');
      await d.goto(c.genieAssistantUrl);
      await askGenie(d, q);
      await d.hold(3);
    },
  },
  'T3-09': {
    setup: notebookSetup,
    async run(d, c) {
      d.label('Acting as an HR business partner');
      await runCell(d, c, "INSERT INTO access_personas VALUES (current_user(), 'hrbp', hrbp_a)");
      await d.hold(1);
      const cell = await runCell(d, c, 'Where can hrbp_a see sensitive data?');
      await focusOutputBelow(d, cell);
      await d.hold(4);
    },
  },
  'T3-10': {
    setup: notebookSetup,
    async run(d, c) {
      d.label('Acting as a people manager');
      const cell = await runCell(d, c, "INSERT INTO access_personas VALUES (current_user(), 'manager', manager_m)");
      await focusOutputBelow(d, cell);
      await d.hold(3.5);
    },
  },
  'T3-11': {
    setup: notebookSetup,
    async run(d, c) {
      d.label('An HRBP assignment ends');
      const cell = await runCell(d, c, 'DECLARE OR REPLACE VARIABLE ended_assignment');
      await focusOutputBelow(d, cell, 300);
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
