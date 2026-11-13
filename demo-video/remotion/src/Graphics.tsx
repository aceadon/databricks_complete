import React from 'react';
import {AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {C} from './theme';
import {DATA} from './data';
import {Bg, CountUp, Footer, Kicker, Pill, Rise, SceneOut, TableIcon, useIn} from './ui';

const pad: React.CSSProperties = {padding: '120px 140px', display: 'flex', flexDirection: 'column'};

export const TitleCard: React.FC<{tier: string}> = ({tier}) => {
  const bar = useIn(14);
  return (
    <Bg>
      <SceneOut>
        <AbsoluteFill style={{...pad, justifyContent: 'center'}}>
          <Rise>
            <Kicker color={C.good}>{tier}</Kicker>
          </Rise>
          <Rise delay={6}>
            <div style={{fontSize: 108, fontWeight: 800, lineHeight: 1.05, marginTop: 24, maxWidth: 1500}}>
              Why HR needs a semantic layer
            </div>
          </Rise>
          <div style={{height: 8, width: 360 * bar, background: C.accent, borderRadius: 4, marginTop: 40}} />
          <Rise delay={18}>
            <div style={{fontSize: 40, color: C.muted, marginTop: 36, maxWidth: 1300}}>
              The migration moves our tables. This makes them mean the same thing everywhere.
            </div>
          </Rise>
        </AbsoluteFill>
        <Footer />
      </SceneOut>
    </Bg>
  );
};

export const GapIntro: React.FC = () => {
  const items = [
    {k: 'Meaning', d: 'What counts as headcount, attrition, a regretted leaver'},
    {k: 'AI answers', d: 'What Genie is allowed to answer, and how'},
    {k: 'Access', d: 'Who may see salary, birthdays, equity'},
  ];
  return (
    <Bg>
      <SceneOut>
        <AbsoluteFill style={pad}>
          <Rise>
            <Kicker>The migration moves tables</Kicker>
          </Rise>
          <Rise delay={6}>
            <div style={{fontSize: 76, fontWeight: 800, marginTop: 16}}>Three things don't move with them</div>
          </Rise>
          <div style={{display: 'flex', gap: 40, marginTop: 80}}>
            {items.map((it, i) => (
              <Rise key={it.k} delay={20 + i * 14} style={{flex: 1}}>
                <div style={{background: C.panel, borderRadius: 24, padding: 48, borderTop: `8px solid ${C.accent}`, height: 340}}>
                  <div style={{fontSize: 30, color: C.accent, fontWeight: 700}}>0{i + 1}</div>
                  <div style={{fontSize: 56, fontWeight: 700, marginTop: 12}}>{it.k}</div>
                  <div style={{fontSize: 32, color: C.muted, marginTop: 20, lineHeight: 1.35}}>{it.d}</div>
                </div>
              </Rise>
            ))}
          </div>
          <Rise delay={70}>
            <div style={{fontSize: 34, color: C.muted, marginTop: 56}}>
              Today they live in individual queries, BI tool settings and a coverage spreadsheet.
            </div>
          </Rise>
        </AbsoluteFill>
      </SceneOut>
    </Bg>
  );
};

export const NumberReveal: React.FC = () => {
  const frame = useCurrentFrame();
  const strike = interpolate(frame, [70, 90], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return (
    <Bg>
      <SceneOut>
        <AbsoluteFill style={pad}>
          <Rise>
            <Kicker>Same table · same question · {DATA.quarterLabel} headcount</Kicker>
          </Rise>
          <div style={{display: 'flex', gap: 60, marginTop: 90}}>
            <Rise delay={8} style={{flex: 1}}>
              <div style={{background: C.panel, borderRadius: 28, padding: 56, border: `3px solid ${C.accent}`}}>
                <Pill color={C.accent}>Raw migrated table</Pill>
                <div style={{fontSize: 150, fontWeight: 800, marginTop: 30, position: 'relative', color: C.accent}}>
                  <CountUp to={DATA.naiveHeadcount} start={12} />
                  <div style={{position: 'absolute', left: 0, top: '52%', height: 10, width: `${strike * 100}%`, background: C.text, borderRadius: 5}} />
                </div>
                <div style={{fontSize: 32, color: C.muted, marginTop: 10}}>April + May + June, added up</div>
              </div>
            </Rise>
            <Rise delay={40} style={{flex: 1}}>
              <div style={{background: C.panel, borderRadius: 28, padding: 56, border: `3px solid ${C.good}`}}>
                <Pill color={C.good}>Through the semantic layer</Pill>
                <div style={{fontSize: 150, fontWeight: 800, marginTop: 30, color: C.good}}>
                  <CountUp to={DATA.semanticHeadcount} start={44} />
                </div>
                <div style={{fontSize: 32, color: C.muted, marginTop: 10}}>Last month of the period, never a sum</div>
              </div>
            </Rise>
          </div>
          <Rise delay={96}>
            <div style={{fontSize: 40, marginTop: 70, fontWeight: 600}}>
              For a company of {DATA.people} people. Nothing warns you.
            </div>
          </Rise>
        </AbsoluteFill>
        <Footer />
      </SceneOut>
    </Bg>
  );
};

export const CostCallout: React.FC<{withAI: boolean; cue?: number}> = ({withAI, cue}) => {
  const frame = useCurrentFrame();
  // When the split starts, the headline shrinks toward the left to make room for the column of parts.
  const shrink = !withAI && cue !== undefined ? interpolate(frame, [cue - 12, cue + 6], [1, 0.8], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic)}) : 1;
  return (
  <Bg>
    <SceneOut>
      <AbsoluteFill style={{...pad, justifyContent: 'center', transform: `scale(${shrink})`, transformOrigin: '140px 540px'}}>
        <Rise>
          <Kicker>Once attrition means one thing, you can cost it</Kicker>
        </Rise>
        <div style={{display: 'flex', alignItems: 'flex-end', gap: 80, marginTop: 40}}>
          <Rise delay={8}>
            <div style={{fontSize: 260, fontWeight: 800, lineHeight: 1, color: C.amber}}>{DATA.regrettedCost}</div>
            <div style={{fontSize: 44, fontWeight: 600, marginTop: 16}}>a year, to replace regretted leavers</div>
            <div style={{fontSize: 32, color: C.muted, marginTop: 12}}>
              {DATA.regrettedLeavers} people in the last 12 months · at half a salary each
            </div>
          </Rise>
          {withAI && (
            <Rise delay={50}>
              <div style={{background: C.panel, borderRadius: 24, padding: '40px 48px', borderLeft: `8px solid ${C.accent}`, marginBottom: 20}}>
                <div style={{fontSize: 28, color: C.muted, fontWeight: 600}}>THE AI TEAM ALONE ({DATA.aiGrowth} GROWTH)</div>
                <div style={{fontSize: 110, fontWeight: 800, color: C.accent, lineHeight: 1.1}}>{DATA.aiRegrettedCost}</div>
                <div style={{fontSize: 32}}>{DATA.aiRegrettedLeavers} regretted leavers</div>
              </div>
            </Rise>
          )}
        </div>
      </AbsoluteFill>
      {!withAI && cue !== undefined && <CostSplits start={cue} />}
      <Footer />
    </SceneOut>
  </Bg>
  );
};

/** The $190M splitting into groups: curved lines grow from the number to a column of parts that add up to it. */
const CostSplits: React.FC<{start: number}> = ({start}) => {
  const frame = useCurrentFrame();
  const rows = DATA.costSplits;
  // The big number sits on the left of the 1920x1080 frame; the lines leave from just right of it.
  const from = {x: 862, y: 512};
  const colX = 1190;
  const rowH = 128;
  const top = 540 - ((rows.length - 1) * rowH) / 2 - 40;
  const STAGGER = 9;
  const DRAW = 16;
  const sumAt = start + rows.length * STAGGER + DRAW + 6;
  const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
  return (
    <AbsoluteFill>
      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
        {rows.map((r, i) => {
          const y = top + i * rowH;
          const t0 = start + i * STAGGER;
          const p = interpolate(frame, [t0, t0 + DRAW], [0, 1], {...clamp, easing: Easing.inOut(Easing.cubic)});
          const d = `M ${from.x} ${from.y} C ${from.x + 170} ${from.y}, ${colX - 190} ${y}, ${colX - 24} ${y}`;
          return (
            <g key={r.label} opacity={p > 0 ? 1 : 0}>
              <path d={d} fill="none" stroke={C.amber} strokeOpacity={0.75} strokeWidth={4} strokeLinecap="round" pathLength={1} strokeDasharray={1} strokeDashoffset={1 - p} />
              <circle cx={colX - 24} cy={y} r={7 * p} fill={C.amber} />
            </g>
          );
        })}
        <circle cx={from.x} cy={from.y} r={9 * interpolate(frame, [start, start + 6], [0, 1], clamp)} fill={C.amber} />
      </svg>
      {rows.map((r, i) => {
        const y = top + i * rowH;
        const t = start + i * STAGGER + DRAW - 4;
        const o = interpolate(frame, [t, t + 10], [0, 1], clamp);
        return (
          <div
            key={r.label}
            style={{
              position: 'absolute',
              left: colX,
              top: y - 52,
              width: 600,
              height: 104,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              opacity: o,
              transform: `translateX(${(1 - o) * 24}px)`,
              background: C.panel,
              borderRadius: 18,
              padding: '0 32px',
              boxSizing: 'border-box',
              borderLeft: `6px solid ${C.amber}`,
            }}
          >
            <div>
              <div style={{fontSize: 36, fontWeight: 700}}>{r.label}</div>
              <div style={{fontSize: 24, color: C.muted, marginTop: 4}}>{r.leavers} regretted leavers</div>
            </div>
            <div style={{fontSize: 66, fontWeight: 800, color: C.amber}}>{r.cost}</div>
          </div>
        );
      })}
      {(() => {
        const y = top + (rows.length - 1) * rowH + 52 + 22;
        const o = interpolate(frame, [sumAt, sumAt + 10], [0, 1], clamp);
        return (
          <div style={{position: 'absolute', left: colX, top: y, width: 600, opacity: o}}>
            <div style={{height: 3, background: C.amber, opacity: 0.6, transform: `scaleX(${o})`, transformOrigin: 'right'}} />
            <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginTop: 10, padding: '0 32px 0 38px'}}>
              <div style={{fontSize: 26, color: C.muted}}>Adds up to</div>
              <div style={{fontSize: 46, fontWeight: 800, color: C.amber}}>= {DATA.regrettedCost}</div>
            </div>
          </div>
        );
      })()}
    </AbsoluteFill>
  );
};

export const SectionCard: React.FC<{n: number; title: string; who: string}> = ({n, title, who}) => {
  const p = useIn(0);
  return (
    <Bg>
      <SceneOut>
        <AbsoluteFill style={{...pad, justifyContent: 'center'}}>
          <div style={{fontSize: 340, fontWeight: 800, color: C.accent, opacity: 0.9 * p, lineHeight: 0.9, transform: `translateX(${(1 - p) * -60}px)`}}>
            {n}
          </div>
          <Rise delay={8}>
            <Kicker>Gap {n} of 3</Kicker>
          </Rise>
          <Rise delay={12}>
            <div style={{fontSize: 92, fontWeight: 800, marginTop: 12}}>{title}</div>
          </Rise>
          <Rise delay={20}>
            <div style={{fontSize: 36, color: C.muted, marginTop: 20}}>{who}</div>
          </Rise>
        </AbsoluteFill>
      </SceneOut>
    </Bg>
  );
};

export const QuestionCard: React.FC<{q: string; statement?: boolean}> = ({q, statement = false}) => (
  <Bg>
    <SceneOut>
      <AbsoluteFill style={{...pad, justifyContent: 'center', alignItems: 'center', textAlign: 'center'}}>
        <Rise>
          {!statement && <div style={{fontSize: 180, color: C.good, fontWeight: 800, lineHeight: 0.8}}>?</div>}
        </Rise>
        <Rise delay={8}>
          <div style={{fontSize: 76, fontWeight: 700, maxWidth: 1500, lineHeight: 1.2, marginTop: 30}}>{q}</div>
        </Rise>
      </AbsoluteFill>
    </SceneOut>
  </Bg>
);

export const BenchmarkCard: React.FC = () => {
  const {raw, semantic, outOf} = DATA.benchmark;
  const r = raw ?? 0;
  const s = semantic ?? 0;
  const pr = useIn(16);
  const ps = useIn(36);
  const Bar: React.FC<{label: string; v: number; p: number; color: string}> = ({label, v, p, color}) => (
    <div style={{marginTop: 50}}>
      <div style={{display: 'flex', justifyContent: 'space-between', fontSize: 40, fontWeight: 600}}>
        <span>{label}</span>
        <span style={{color}}>
          {(Math.round(v * p * 2) / 2).toLocaleString('en-US', {maximumFractionDigits: 1})} / {outOf}
        </span>
      </div>
      <div style={{height: 56, background: C.panel, borderRadius: 16, marginTop: 16}}>
        <div style={{height: 56, width: `${(v / outOf) * 100 * p}%`, background: color, borderRadius: 16}} />
      </div>
    </div>
  );
  return (
    <Bg>
      <SceneOut>
        <AbsoluteFill style={{...pad, justifyContent: 'center'}}>
          <Rise>
            <Kicker>Same AI · same data · 20 benchmark questions</Kicker>
          </Rise>
          <Bar label="Genie on raw tables" v={r} p={pr} color={C.accent} />
          <Bar label="Genie on the semantic layer" v={s} p={ps} color={C.good} />
          <Rise delay={60}>
            <div style={{fontSize: 40, marginTop: 70, fontWeight: 600}}>AI is only as good as the definitions under it.</div>
          </Rise>
        </AbsoluteFill>
      </SceneOut>
    </Bg>
  );
};

/** HRBP rule: a small org tree; the two supported leaders' subtrees light up, the leaders themselves stay out. */
export const AccessRule: React.FC = () => {
  const frame = useCurrentFrame();
  const W = 1640;
  type N = {x: number; y: number; scope: 0 | 1 | 2; leader?: boolean};
  const nodes: N[] = [{x: W / 2, y: 40, scope: 0}];
  const leaders = [300, 820, 1340];
  leaders.forEach((lx, li) => {
    nodes.push({x: lx, y: 150, scope: 0, leader: li !== 1});
    [-150, 0, 150].forEach((dx) => {
      nodes.push({x: lx + dx, y: 260, scope: li === 1 ? 0 : 1});
      [-45, 45].forEach((dd) => nodes.push({x: lx + dx + dd, y: 350, scope: li === 1 ? 0 : 2}));
    });
  });
  const lit = interpolate(frame, [40, 70], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const deep = interpolate(frame, [60, 90], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const color = (n: N) => {
    if (n.leader) return C.amber;
    if (n.scope === 1) return lit > 0.5 ? C.good : C.line;
    if (n.scope === 2) return deep > 0.5 ? C.good : C.line;
    return C.line;
  };
  const edges: [N, N][] = [];
  nodes.forEach((n) => {
    const parent = nodes.filter((p) => p.y < n.y && p.y >= n.y - 120).sort((a, b) => Math.abs(a.x - n.x) - Math.abs(b.x - n.x))[0];
    if (parent) edges.push([parent, n]);
  });
  return (
    <Bg>
      <SceneOut>
        <AbsoluteFill style={{...pad, padding: '90px 140px'}}>
          <Rise>
            <Kicker>One rule in Unity Catalog</Kicker>
          </Rise>
          <Rise delay={6}>
            <div style={{fontSize: 56, fontWeight: 700, marginTop: 14, maxWidth: 1600, lineHeight: 1.2}}>
              An HR business partner sees sensitive data for the <span style={{color: C.good}}>orgs</span> of the leaders they{' '}
              <span style={{color: C.good}}>currently support</span>.
            </div>
          </Rise>
          <Rise delay={20} style={{marginTop: 50}}>
            <svg width={W} height={400}>
              {edges.map(([a, b], i) => (
                <line key={i} x1={a.x} y1={a.y} x2={b.x} y2={b.y} stroke={color(b) === C.good ? C.good : C.line} strokeWidth={3} opacity={0.7} />
              ))}
              {nodes.map((n, i) => (
                <circle key={i} cx={n.x} cy={n.y} r={n.y < 100 ? 22 : n.leader !== undefined && n.y === 150 ? 20 : 15} fill={color(n)} />
              ))}
            </svg>
          </Rise>
          <div style={{display: 'flex', gap: 30, marginTop: 30}}>
            <Rise delay={90}><Pill color={C.good}>Salary · birthdays · equity visible</Pill></Rise>
            <Rise delay={100}><Pill color={C.amber}>Supported leaders: executives stay out</Pill></Rise>
            <Rise delay={110}><Pill color={C.muted}>Everyone else: name and title only</Pill></Rise>
          </div>
        </AbsoluteFill>
      </SceneOut>
    </Bg>
  );
};

const Col: React.FC<{title: string; color: string; items: string[]; delay: number}> = ({title, color, items, delay}) => (
  <div style={{flex: 1}}>
    <Rise delay={delay}>
      <Kicker color={color}>{title}</Kicker>
    </Rise>
    {items.map((t, i) => (
      <Rise key={t} delay={delay + 10 + i * 10}>
        <div style={{display: 'flex', gap: 24, alignItems: 'baseline', marginTop: 34}}>
          <div style={{width: 18, height: 18, borderRadius: 9, background: color, flexShrink: 0, transform: 'translateY(-4px)'}} />
          <div style={{fontSize: 42, lineHeight: 1.3}}>{t}</div>
        </div>
      </Rise>
    ))}
  </div>
);

// cue: frame where the narration reaches "The future state"; the right column comes in on it.
export const GapSummary: React.FC<{cue?: number}> = ({cue = 140}) => (
  <Bg>
    <SceneOut>
      <AbsoluteFill style={pad}>
        <Rise>
          <div style={{fontSize: 80, fontWeight: 800}}>The gap</div>
        </Rise>
        <div style={{display: 'flex', gap: 100, marginTop: 60}}>
          <Col
            title="Today"
            color={C.accent}
            delay={10}
            items={['Our data warehouse is moving to Databricks', 'Definitions live in people’s heads', 'Access lives in a spreadsheet', 'AI is off limits, or struggles to earn trust']}
          />
          <Col
            title="Future state"
            color={C.good}
            delay={Math.max(20, cue - 10)}
            items={['Every HR number certified once, the same everywhere', 'Sensitive data governed by one auditable rule', 'Definitions change only through a reviewed diff', 'An AI assistant with consistent, usable HR answers']}
          />
        </div>
      </AbsoluteFill>
    </SceneOut>
  </Bg>
);

export const FutureState: React.FC = () => (
  <Bg>
    <SceneOut>
      <AbsoluteFill style={pad}>
        <Rise>
          <Kicker color={C.good}>The future state</Kicker>
        </Rise>
        <div style={{marginTop: 30}}>
          <Col
            title=""
            color={C.good}
            delay={6}
            items={['One certified definition per metric, with a named owner', 'One access rule', 'Every tool, including AI, reading only what the user may see']}
          />
        </div>
        <Rise delay={70}>
          <div style={{fontSize: 46, fontWeight: 700, marginTop: 80}}>
            The migration is the foundation. <span style={{color: C.good}}>This is what makes it trustworthy and secure for HR.</span>
          </div>
        </Rise>
      </AbsoluteFill>
    </SceneOut>
  </Bg>
);

export const EndCard: React.FC<{ask: string; sub: string}> = ({ask, sub}) => (
  <Bg>
    <AbsoluteFill style={{...pad, justifyContent: 'center'}}>
      <Rise>
        <Kicker color={C.good}>Next step</Kicker>
      </Rise>
      <Rise delay={6}>
        <div style={{fontSize: 96, fontWeight: 800, marginTop: 20, maxWidth: 1500, lineHeight: 1.1}}>{ask}</div>
      </Rise>
      <Rise delay={16}>
        <div style={{fontSize: 40, color: C.muted, marginTop: 34, maxWidth: 1400, lineHeight: 1.35}}>{sub}</div>
      </Rise>
      <Rise delay={26}>
        <div style={{fontSize: 34, marginTop: 60, fontWeight: 600}}>{DATA.presenter} · HR Tech, People Ops</div>
      </Rise>
    </AbsoluteFill>
    <Footer />
  </Bg>
);

/** Transparent lower third to lay over screen recordings. */
export const LowerThird: React.FC<{title: string; sub: string}> = ({title, sub}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const pin = useIn(0, 20);
  const out = interpolate(frame, [durationInFrames - 15, durationInFrames], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return (
    <Bg transparent>
      <div style={{position: 'absolute', left: 80, bottom: 90, opacity: out, transform: `translateX(${(1 - pin) * -500}px)`}}>
        <div style={{background: 'rgba(13,27,38,0.92)', borderLeft: `10px solid ${C.good}`, borderRadius: 14, padding: '24px 40px'}}>
          <div style={{fontSize: 40, fontWeight: 700}}>{title}</div>
          <div style={{fontSize: 28, color: C.muted, marginTop: 6}}>{sub}</div>
        </div>
      </div>
    </Bg>
  );
};

export {TableIcon};
