import React from 'react';
import {Composition} from 'remotion';
import durations from '../../narration/durations.json';
import {Spiel30} from './Spiel30';
import {FullVideo, calcFullVideo} from './FullVideo';
import {
  AccessRule, BenchmarkCard, CostCallout, EndCard, FutureState, GapIntro, GapSummary, LowerThird, NumberReveal, QuestionCard, SectionCard, TitleCard,
} from './Graphics';

const FPS = 30;
const D = durations as unknown as Record<string, number>;
/** Scene length in frames, plus a hold so there is room to trim in the editor. */
const f = (id: string, hold = 1) => Math.ceil(((D[id] ?? 6) + hold) * FPS);
const s = (sec: number) => Math.ceil(sec * FPS);
const HD = {width: 1920, height: 1080, fps: FPS};

export const Root: React.FC = () => {
  const spielParts = ['T1-01', 'T1-02', 'T1-03', 'T1-04', 'T1-05'].map((id, i) => f(id, i === 4 ? 2.5 : 0.4));
  return (
    <>
      <Composition id="Spiel30" component={Spiel30} durationInFrames={spielParts.reduce((a, b) => a + b, 0)} defaultProps={{parts: spielParts}} {...HD} />

      <Composition id="TitleCard-2min" component={TitleCard} durationInFrames={s(4)} defaultProps={{tier: 'The 2-minute proof'}} {...HD} />
      <Composition id="TitleCard-5min" component={TitleCard} durationInFrames={s(4)} defaultProps={{tier: 'The 5-minute walk-through'}} {...HD} />
      <Composition id="GapIntro" component={GapIntro} durationInFrames={Math.max(f('T3-01') - s(4), s(10))} {...HD} />
      <Composition id="NumberReveal" component={NumberReveal} durationInFrames={Math.max(f('T2-05'), s(7))} {...HD} />
      <Composition id="CostCallout-Tema" component={CostCallout} durationInFrames={f('T2-06')} defaultProps={{withAI: false}} {...HD} />
      <Composition id="CostCallout-AI" component={CostCallout} durationInFrames={f('T3-04')} defaultProps={{withAI: true}} {...HD} />
      <Composition id="FutureState" component={FutureState} durationInFrames={Math.max(f('T2-07'), s(8))} {...HD} />

      <Composition id="SectionCard-1" component={SectionCard} durationInFrames={s(3.5)} defaultProps={{n: 1, title: 'The numbers don’t agree', who: 'HR leadership · People Ops · HR Tech'}} {...HD} />
      <Composition id="SectionCard-2" component={SectionCard} durationInFrames={s(3.5)} defaultProps={{n: 2, title: 'AI gives confident, wrong answers', who: 'Anyone excited about Genie'}} {...HD} />
      <Composition id="SectionCard-3" component={SectionCard} durationInFrames={s(3.5)} defaultProps={{n: 3, title: 'Access doesn’t follow the org', who: 'HRBPs · Security · Legal'}} {...HD} />
      <Composition id="QuestionCard-Attrition" component={QuestionCard} durationInFrames={f('T3-05', 2)} defaultProps={{q: 'If every VP, HRBP, and leader could see their org’s cost of attrition, what decisions could we make to transform our company?'}} {...HD} />
      <Composition id="BenchmarkCard" component={BenchmarkCard} durationInFrames={f('T3-08')} {...HD} />
      <Composition id="AccessRule" component={AccessRule} durationInFrames={f('T3-12')} {...HD} />
      <Composition id="GapSummary" component={GapSummary} durationInFrames={f('T3-13')} {...HD} />

      <Composition id="LowerThird-Fictional" component={LowerThird} durationInFrames={s(6)} defaultProps={{title: 'Tema is fictional', sub: '70,000 synthetic people, built at our scale on purpose'}} {...HD} />

      {(['T1', 'T2', 'T3'] as const).map((v) => (
        <Composition key={v} id={`FullVideo-${v}`} component={FullVideo} calculateMetadata={calcFullVideo} durationInFrames={300} defaultProps={{video: v, blocks: [], audio: [], spielParts: []}} {...HD} />
      ))}
    </>
  );
};
