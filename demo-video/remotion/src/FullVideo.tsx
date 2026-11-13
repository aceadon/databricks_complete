// The finished videos: graphics + screen recordings + narration, scene by scene, following narration/scenes.json.
import React from 'react';
import {AbsoluteFill, Audio, CalculateMetadataFunction, Sequence, interpolate, staticFile, useCurrentFrame} from 'remotion';
import scenesJson from '../../narration/scenes.json';
import durationsJson from '../../narration/durations.json';
import {DATA} from './data';
import {C} from './theme';
import {Spiel30} from './Spiel30';
import {Capture, ScreenScene, fitCapture} from './ScreenScene';
import {
  AccessRule, BenchmarkCard, CostCallout, EndCard, FutureState, GapIntro, GapSummary, LowerThird, NumberReveal, QuestionCard, SectionCard, TitleCard,
} from './Graphics';

const FPS = 30;
const GAP = 0.5; // seconds of breathing room after each line
const D = durationsJson as unknown as Record<string, number>;
const sec = (id: string) => D[id] ?? 6;

// What's on screen for each scene. 'fill' takes whatever time the narration leaves.
type Part = {g: keyof typeof GRAPHICS; sec?: number} | {screen: true};
const PLAN: Record<string, Part[]> = {
  'T2-01': [{g: 'TitleCard-2min', sec: 4}, {g: 'GapIntro'}],
  'T2-02': [{screen: true}],
  'T2-03': [{screen: true}],
  'T2-04': [{screen: true}],
  'T2-05': [{g: 'NumberReveal'}],
  'T2-06': [{g: 'CostCallout-Tema'}],
  'T2-07': [{g: 'FutureState'}],
  'T3-01': [{g: 'TitleCard-5min', sec: 4}, {g: 'GapIntro'}],
  'T3-02': [{g: 'SectionCard-1', sec: 3.5}, {screen: true}],
  'T3-03': [{screen: true}],
  'T3-04': [{g: 'CostCallout-AI'}],
  'T3-05': [{g: 'QuestionCard-Attrition'}],
  'T3-06': [{g: 'SectionCard-2', sec: 3.5}, {screen: true}],
  'T3-07': [{screen: true}],
  'T3-08': [{g: DATA.benchmark.raw === null ? 'Statement-AI' : 'BenchmarkCard'}],
  'T3-09': [{g: 'SectionCard-3', sec: 3.5}, {screen: true}],
  'T3-10': [{screen: true}],
  'T3-11': [{screen: true}],
  'T3-12': [{g: 'AccessRule'}],
  'T3-13': [{g: 'GapSummary'}],
};
const LOWER_THIRD_ON = new Set(['T2-02', 'T3-02']);

const GRAPHICS = {
  'TitleCard-2min': () => <TitleCard tier="The 2-minute proof" />,
  'TitleCard-5min': () => <TitleCard tier="The 5-minute walk-through" />,
  GapIntro: () => <GapIntro />,
  NumberReveal: () => <NumberReveal />,
  'CostCallout-Tema': ({cue}: GProps) => <CostCallout withAI={false} cue={cue} />,
  'CostCallout-AI': () => <CostCallout withAI />,
  FutureState: () => <FutureState />,
  'EndCard-2min': () => <EndCard ask="Thirty minutes to see if this works here?" sub="One certified definition per metric, one access rule, every tool reading from it." />,
  'EndCard-5min': () => <EndCard ask="A 90-day pilot on people analytics" sub="An HR sponsor, a named HR data owner, and about a day a week from one data engineer." />,
  'SectionCard-1': () => <SectionCard n={1} title={'The numbers don’t agree'} who="HR leadership · People Ops · HR Tech" />,
  'SectionCard-2': () => <SectionCard n={2} title="AI gives confident, wrong answers" who="Anyone excited about Genie" />,
  'SectionCard-3': () => <SectionCard n={3} title={'Access doesn’t follow the org'} who="HRBPs · Security · Legal" />,
  'QuestionCard-Attrition': () => <QuestionCard q={'If every VP, HRBP, and leader could see their org’s cost of attrition, what decisions could we make to transform our company?'} />,
  'Statement-AI': () => <QuestionCard statement q="Same AI, same data. AI is only as good as the definitions under it." />,
  BenchmarkCard: () => <BenchmarkCard />,
  AccessRule: () => <AccessRule />,
  GapSummary: () => <GapSummary />,
};

type Block = {from: number; len: number; part: Part; sceneId: string; cap?: Capture | null; k?: number; cue?: number};
type GProps = {cue?: number};

// Graphics that animate on a spoken phrase: the scene and the words that trigger it.
const CUES: Record<string, RegExp> = {'T2-06': /number can be|evaluated by/i};

/** Frame (from the start of the scene) where `re` is first spoken, from the clip's captions; else a guess from the text. */
const cueFrame = async (sceneId: string, re: RegExp, text: string): Promise<number> => {
  try {
    const r = await fetch(staticFile(`audio/${sceneId}.srt`));
    if (r.ok) {
      const blocks = (await r.text()).split(/\r?\n\r?\n/);
      const words = re.source.split('|')[0].split(' ')[0];
      for (const b of blocks) {
        const m = b.match(/(\d+):(\d+):(\d+),(\d+) -->/);
        if (m && new RegExp(words, 'i').test(b)) return Math.max(0, Math.round((+m[1] * 3600 + +m[2] * 60 + +m[3] + +m[4] / 1000) * FPS) - 4);
      }
    }
  } catch {}
  const plain = text.replace(/<[^>]+>/g, '');
  const i = plain.search(re);
  return Math.round(((i < 0 ? 0.7 : i / plain.length) * sec(sceneId)) * FPS);
};
type Props = {video: 'T1' | 'T2' | 'T3'; blocks: Block[]; audio: {id: string; from: number}[]; spielParts: number[]};

export const spielPartsFrames = () => ['T1-01', 'T1-02', 'T1-03', 'T1-04', 'T1-05'].map((id, i) => Math.ceil((sec(id) + (i === 4 ? 2.5 : 0.4)) * FPS));

const exists = async (path: string) => {
  try {
    const r = await fetch(staticFile(path), {method: 'HEAD'});
    return r.ok;
  } catch {
    return false;
  }
};

export const calcFullVideo: CalculateMetadataFunction<Props> = async ({props}) => {
  const video = scenesJson.videos.find((v) => v.id === props.video)!;
  const audio: Props['audio'] = [];
  if (props.video === 'T1') {
    const parts = spielPartsFrames();
    let from = 0;
    for (const [i, s] of video.scenes.entries()) {
      if (await exists(`audio/${s.id}.mp3`)) audio.push({id: s.id, from});
      from += parts[i];
    }
    return {durationInFrames: from, props: {...props, blocks: [], audio, spielParts: parts}};
  }
  const blocks: Block[] = [];
  let from = 0;
  for (const s of video.scenes) {
    const parts = PLAN[s.id] ?? [{g: 'GapIntro'}];
    const fixed = parts.reduce((a, p) => a + ('sec' in p && p.sec ? p.sec : 0), 0);
    let fill = Math.max(sec(s.id) + GAP - fixed, 2);
    let cap: Capture | null = null;
    let k = 1;
    if (parts.some((p) => 'screen' in p)) {
      try {
        const r = await fetch(staticFile(`capture/${s.id}/capture.json`));
        if (r.ok) cap = await r.json();
      } catch {}
      if (cap) {
        const fit = fitCapture(cap, fill);
        k = fit.k;
        fill = Math.max(fill, fit.length + 0.3);
      }
    }
    if (await exists(`audio/${s.id}.mp3`)) audio.push({id: s.id, from});
    for (const part of parts) {
      const len = Math.ceil(('sec' in part && part.sec ? part.sec : fill) * FPS);
      const cue = 'g' in part && CUES[s.id] ? await cueFrame(s.id, CUES[s.id], s.text) : undefined;
      blocks.push({from, len, part, sceneId: s.id, cap, k, cue});
      from += len;
    }
  }
  return {durationInFrames: from, props: {...props, blocks, audio, spielParts: []}};
};

const Fade: React.FC<{len: number; children: React.ReactNode}> = ({len, children}) => {
  const f = useCurrentFrame();
  const o = interpolate(f, [0, 8, len - 8, len], [0, 1, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return <AbsoluteFill style={{opacity: o, background: C.bg}}>{children}</AbsoluteFill>;
};

export const FullVideo: React.FC<Props> = ({video, blocks, audio, spielParts}) => (
  <AbsoluteFill style={{background: C.bg}}>
    {video === 'T1' ? (
      <Spiel30 parts={spielParts} />
    ) : (
      blocks.map((b, i) => {
        const G = 'g' in b.part ? GRAPHICS[b.part.g] : null;
        const firstScreen = 'screen' in b.part && !blocks.slice(0, i).some((x) => x.sceneId === b.sceneId && 'screen' in x.part);
        return (
          <Sequence key={i} from={b.from} durationInFrames={b.len}>
            <Fade len={b.len}>{G ? <G cue={b.cue} /> : <ScreenScene cap={b.cap ?? null} k={b.k ?? 1} sceneId={b.sceneId} />}</Fade>
            {firstScreen && LOWER_THIRD_ON.has(b.sceneId) && (
              <Sequence from={15} durationInFrames={6 * FPS}>
                <LowerThird title="Tema is fictional" sub="70,000 synthetic people, built at our scale on purpose" />
              </Sequence>
            )}
          </Sequence>
        );
      })
    )}
    {audio.map((a) => (
      <Sequence key={a.id} from={a.from}>
        <Audio src={staticFile(`audio/${a.id}.mp3`)} />
      </Sequence>
    ))}
  </AbsoluteFill>
);
