import React from 'react';
import {AbsoluteFill, interpolate, Sequence, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {C} from './theme';
import {DATA} from './data';
import {Bg, CountUp, Kicker, Pill, Rise, TableIcon, useIn} from './ui';
import {QuestionCard} from './Graphics';

const Caption: React.FC<{children: React.ReactNode; delay?: number}> = ({children, delay = 0}) => (
  <Rise delay={delay} style={{position: 'absolute', bottom: 110, left: 0, right: 0, textAlign: 'center'}}>
    <div style={{fontSize: 64, fontWeight: 800}}>{children}</div>
  </Rise>
);

const MoveTables: React.FC = () => {
  const frame = useCurrentFrame();
  const rows = [0, 1, 2, 3];
  return (
    <Bg>
      <AbsoluteFill>
        <div style={{position: 'absolute', left: 160, top: 170, width: 420, textAlign: 'center'}}>
          <Kicker>Legacy HR systems</Kicker>
        </div>
        <div style={{position: 'absolute', right: 160, top: 150, width: 560, height: 560, border: `4px solid ${C.good}`, borderRadius: 32, background: 'rgba(46,196,166,0.06)'}}>
          <div style={{textAlign: 'center', marginTop: 30}}>
            <Kicker color={C.good}>Databricks</Kicker>
          </div>
        </div>
        {rows.map((r) => {
          const start = 10 + r * 9;
          const t = interpolate(frame, [start, start + 34], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic)});
          const x = interpolate(t, [0, 1], [300, 1380]);
          const y = 250 + r * 110 + Math.sin(t * Math.PI) * -40;
          return (
            <div key={r} style={{position: 'absolute', left: x, top: y}}>
              <TableIcon size={120} color={t > 0.95 ? C.good : C.muted} />
            </div>
          );
        })}
      </AbsoluteFill>
      <Caption delay={45}>
        The rollout only moves <span style={{color: C.accent}}>tables</span>.
      </Caption>
    </Bg>
  );
};

const TwoAnswers: React.FC = () => {
  const l = useIn(18);
  const r = useIn(60);
  return (
    <Bg>
      <AbsoluteFill style={{alignItems: 'center'}}>
        <Rise style={{marginTop: 110, textAlign: 'center'}}>
          <TableIcon size={150} color={C.good} />
          <div style={{fontSize: 30, color: C.muted, marginTop: 10}}>One migrated table · headcount at the end of Q2 2025</div>
        </Rise>
        <svg width={1920} height={160} style={{position: 'absolute', top: 330}}>
          <path d={`M960 0 C 960 80, 560 60, 560 ${150 * l}`} stroke={C.good} strokeWidth={5} fill="none" opacity={l} />
          <path d={`M960 0 C 960 80, 1360 60, 1360 ${150 * r}`} stroke={C.accent} strokeWidth={5} fill="none" opacity={r} />
        </svg>
        <div style={{position: 'absolute', top: 500, left: 260, width: 600, textAlign: 'center', opacity: l}}>
          <div style={{fontSize: 150, fontWeight: 800, color: C.good}}>
            <CountUp to={DATA.semanticHeadcount} start={18} />
          </div>
          <div style={{fontSize: 32, color: C.muted}}>one analyst's query</div>
        </div>
        <div style={{position: 'absolute', top: 500, right: 260, width: 600, textAlign: 'center', opacity: r}}>
          <div style={{fontSize: 150, fontWeight: 800, color: C.accent}}>
            <CountUp to={DATA.naiveHeadcount} start={60} />
          </div>
          <div style={{fontSize: 32, color: C.muted}}>another's: three months, added up</div>
        </div>
      </AbsoluteFill>
      <Caption delay={90}>Same table. Two answers.</Caption>
    </Bg>
  );
};

const FiveAttritions: React.FC = () => {
  const versions = ['Voluntary ÷ today’s headcount', 'All leavers ÷ average headcount', 'Excluding interns', 'Rolling 12 months', 'Calendar year to date'];
  const frame = useCurrentFrame();
  return (
    <Bg>
      <AbsoluteFill style={{padding: '110px 160px'}}>
        <Rise>
          <div style={{fontSize: 96, fontWeight: 800}}>
            Attrition<span style={{color: C.accent}}> ×5</span>
          </div>
        </Rise>
        <div style={{position: 'relative', marginTop: 40, height: 520}}>
          {versions.map((v, i) => {
            const p = interpolate(frame, [8 + i * 6, 22 + i * 6], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
            return (
              <div
                key={v}
                style={{
                  position: 'absolute',
                  top: i * 92,
                  left: i * 40,
                  opacity: p,
                  transform: `translateX(${(1 - p) * -80}px) rotate(${(i - 2) * -0.8}deg)`,
                  background: C.panel,
                  border: `2px solid ${C.line}`,
                  borderRadius: 18,
                  padding: '20px 34px',
                  fontSize: 40,
                  fontWeight: 600,
                  width: 780,
                }}
              >
                {v}
              </div>
            );
          })}
          <Rise delay={55} style={{position: 'absolute', right: 0, top: 120, width: 640}}>
            <div style={{background: '#1E5133', border: '3px solid #3FA36B', borderRadius: 20, padding: '34px 40px'}}>
              <div style={{fontSize: 26, color: '#BFE8CF', fontWeight: 600, letterSpacing: 2}}>WHO CAN SEE WHOSE SALARY?</div>
              <div style={{fontSize: 32, fontWeight: 700, marginTop: 14, fontFamily: 'monospace'}}>hrbp_coverage_FINAL_v3.xlsx</div>
              <div style={{display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6, marginTop: 22, opacity: 0.6}}>
                {Array.from({length: 12}).map((_, i) => (
                  <div key={i} style={{height: 22, background: '#3FA36B', borderRadius: 3}} />
                ))}
              </div>
            </div>
          </Rise>
        </div>
      </AbsoluteFill>
    </Bg>
  );
};

const Layer: React.FC = () => {
  const band = useIn(20);
  const tools = ['Tableau dashboards', 'SQL queries', 'AI agents'];
  return (
    <Bg>
      <AbsoluteFill style={{padding: '90px 180px', justifyContent: 'center'}}>
        <div style={{display: 'flex', gap: 40}}>
          {tools.map((t, i) => (
            <Rise key={t} delay={50 + i * 8} style={{flex: 1}}>
              <div style={{background: C.panel, borderRadius: 22, padding: '28px 20px', textAlign: 'center', border: `2px solid ${C.good}`}}>
                <div style={{fontSize: 34, fontWeight: 600, color: C.muted}}>{t}</div>
                <div style={{fontSize: 64, fontWeight: 800, color: C.good, marginTop: 6}}>
                  {DATA.semanticHeadcount.toLocaleString('en-US')} ✓
                </div>
              </div>
            </Rise>
          ))}
        </div>
        <div
          style={{
            marginTop: 60,
            height: 200,
            borderRadius: 28,
            background: `linear-gradient(90deg, ${C.good}, #1F8F7A)`,
            opacity: band,
            transform: `scaleX(${0.6 + 0.4 * band})`,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            boxShadow: `0 0 ${80 * band}px rgba(46,196,166,0.45)`,
            color: C.bg,
          }}
        >
          <div style={{fontSize: 64, fontWeight: 800}}>Semantic layer</div>
          <div style={{fontSize: 34, fontWeight: 600}}>every metric and every access rule, defined once</div>
        </div>
        <Rise delay={4} style={{marginTop: 60}}>
          <div style={{display: 'flex', justifyContent: 'center', gap: 60, alignItems: 'center'}}>
            {[0, 1, 2, 3, 4].map((i) => (
              <TableIcon key={i} size={110} />
            ))}
          </div>
          <div style={{textAlign: 'center', fontSize: 30, color: C.muted, marginTop: 16}}>The migrated tables, unchanged</div>
        </Rise>
      </AbsoluteFill>
    </Bg>
  );
};

/** The whole 30-second spiel. `parts` are the five scene lengths in frames (from the narration audio). */
export const Spiel30: React.FC<{parts: number[]}> = ({parts}) => {
  const comps = [MoveTables, TwoAnswers, FiveAttritions, Layer, () => <QuestionCard statement q="The table migration is the foundation. The semantic layer delivers trust." />];
  let from = 0;
  return (
    <AbsoluteFill style={{background: C.bg}}>
      {comps.map((Comp, i) => {
        const s = (
          <Sequence key={i} from={from} durationInFrames={parts[i]}>
            <Fade len={parts[i]}>
              <Comp />
            </Fade>
          </Sequence>
        );
        from += parts[i];
        return s;
      })}
    </AbsoluteFill>
  );
};

const Fade: React.FC<{len: number; children: React.ReactNode}> = ({len, children}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const o = interpolate(frame, [0, 6, len - 6, len], [0, 1, 1, len > 3 * fps ? 0 : 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return <AbsoluteFill style={{opacity: o}}>{children}</AbsoluteFill>;
};
