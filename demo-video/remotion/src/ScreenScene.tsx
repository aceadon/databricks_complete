import React from 'react';
import {AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, FONT} from './theme';

// ---------- the recorder's capture.json ----------
export type Ev =
  | {t: number; type: 'cursor'; x: number; y: number}
  | {t: number; type: 'move'; x0: number; y0: number; x1: number; y1: number; dur: number}
  | {t: number; type: 'click'; x: number; y: number}
  | {t: number; type: 'focus'; x: number; y: number; w: number; h: number; zoom: number}
  | {t: number; type: 'unfocus'}
  | {t: number; type: 'label'; text: string}
  | {t: number; type: 'typing'; on: boolean}
  | {t: number; type: 'key'; key: string};
export type Capture = {
  scene: string;
  scale: number; // CSS px -> output px, for cursor and clicks
  duration: number;
  frames: {file: string; t: number}[];
  events: Ev[];
  segments: {kind: 'action' | 'wait'; start: number; end: number}[];
};

/** How much to speed up the waiting parts so the scene fits `target` seconds. Never faster than 10x. */
export const fitCapture = (cap: Capture, target: number) => {
  const A = cap.segments.filter((s) => s.kind === 'action').reduce((a, s) => a + s.end - s.start, 0);
  const W = cap.segments.filter((s) => s.kind === 'wait').reduce((a, s) => a + s.end - s.start, 0);
  const k = W <= 0 || A + W <= target ? 1 : Math.min(1, Math.max((target - A) / W, 0.1));
  return {k, length: A + W * k};
};

/** Output seconds -> capture seconds, given the wait speed-up k. */
const toCaptureTime = (cap: Capture, k: number, out: number) => {
  let o = 0;
  for (const s of cap.segments) {
    const len = (s.end - s.start) * (s.kind === 'wait' ? k : 1);
    if (out <= o + len) return {t: s.start + (out - o) / (s.kind === 'wait' ? k : 1), waiting: s.kind === 'wait'};
    o += len;
  }
  return {t: cap.duration, waiting: false};
};

const ease = Easing.inOut(Easing.cubic);
const W = 1920;
const H = 1080;

type Cam = {s: number; cx: number; cy: number};
const camFor = (e: Ev | undefined): Cam => {
  if (!e || e.type !== 'focus') return {s: 1, cx: W / 2, cy: H / 2};
  const s = Math.max(1, Math.min(e.zoom, W / Math.max(e.w, 1), H / Math.max(e.h, 1)));
  const half = {x: W / 2 / s, y: H / 2 / s};
  return {s, cx: Math.min(Math.max(e.x + e.w / 2, half.x), W - half.x), cy: Math.min(Math.max(e.y + e.h / 2, half.y), H - half.y)};
};

const Cursor: React.FC<{x: number; y: number}> = ({x, y}) => (
  <svg width={34} height={46} viewBox="0 0 17 23" style={{position: 'absolute', left: x - 3, top: y - 2, filter: 'drop-shadow(0 2px 3px rgba(0,0,0,.35))'}}>
    <path d="M1 1 L1 18 L5.5 13.8 L8.6 21 L11.6 19.7 L8.6 12.6 L14.6 12.6 Z" fill="#111" stroke="#fff" strokeWidth="1.4" strokeLinejoin="round" />
  </svg>
);

export const ScreenScene: React.FC<{cap: Capture | null; k: number; sceneId: string}> = ({cap, k, sceneId}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  if (!cap || cap.frames.length === 0) {
    return (
      <AbsoluteFill style={{background: C.bg2, color: C.muted, fontFamily: FONT, justifyContent: 'center', alignItems: 'center', fontSize: 48}}>
        Screen recording for {sceneId} goes here (run the recorder)
      </AbsoluteFill>
    );
  }
  const {t, waiting} = toCaptureTime(cap, k, frame / fps);

  // Picture: the last frame captured at or before t.
  let lo = 0;
  let hi = cap.frames.length - 1;
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2);
    if (cap.frames[mid].t <= t) lo = mid;
    else hi = mid - 1;
  }
  const img = cap.frames[lo];

  // Camera: ease from the previous focus state to the current one over 0.7 s.
  const camEvents = cap.events.filter((e) => e.type === 'focus' || e.type === 'unfocus');
  const idx = camEvents.findLastIndex((e) => e.t <= t);
  const cur = camFor(camEvents[idx]);
  const prev = camFor(camEvents[idx - 1]);
  const p = idx < 0 ? 1 : ease(Math.min(1, (t - camEvents[idx].t) / 0.7));
  const cam: Cam = {s: prev.s + (cur.s - prev.s) * p, cx: prev.cx + (cur.cx - prev.cx) * p, cy: prev.cy + (cur.cy - prev.cy) * p};

  // Cursor: replay the recorder's moves with easing.
  const sc = cap.scale;
  let cx = W / 2;
  let cy = H / 2;
  for (const e of cap.events) {
    if (e.t > t) break;
    if (e.type === 'cursor') [cx, cy] = [e.x * sc, e.y * sc];
    if (e.type === 'move') {
      const q = ease(Math.min(1, (t - e.t) / Math.max(e.dur, 0.01)));
      cx = (e.x0 + (e.x1 - e.x0) * q) * sc;
      cy = (e.y0 + (e.y1 - e.y0) * q) * sc;
    }
  }
  const clicks = cap.events.filter((e): e is Extract<Ev, {type: 'click'}> => e.type === 'click' && t - e.t >= 0 && t - e.t < 0.5);
  const label = [...cap.events].reverse().find((e): e is Extract<Ev, {type: 'label'}> => e.type === 'label' && e.t <= t);

  return (
    <AbsoluteFill style={{background: '#fff', overflow: 'hidden'}}>
      <div
        style={{
          position: 'absolute',
          width: W,
          height: H,
          transformOrigin: '0 0',
          transform: `translate(${W / 2 - cam.cx * cam.s}px, ${H / 2 - cam.cy * cam.s}px) scale(${cam.s})`,
        }}
      >
        <Img src={staticFile(`capture/${cap.scene}/${img.file}`)} style={{width: W, height: H, display: 'block'}} />
        {clicks.map((c, i) => {
          const a = (t - c.t) / 0.5;
          return (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: c.x * sc - 30,
                top: c.y * sc - 30,
                width: 60,
                height: 60,
                borderRadius: 30,
                border: `4px solid ${C.accent}`,
                opacity: 1 - a,
                transform: `scale(${0.4 + a})`,
              }}
            />
          );
        })}
        <Cursor x={cx} y={cy} />
      </div>
      {label && (
        <div
          style={{
            position: 'absolute',
            left: 40,
            top: 36,
            fontFamily: FONT,
            fontSize: 30,
            fontWeight: 700,
            color: '#fff',
            background: 'rgba(13,27,38,0.9)',
            borderLeft: `8px solid ${C.good}`,
            borderRadius: 12,
            padding: '14px 26px',
            opacity: interpolate(t - label.t, [0, 0.3], [0, 1], {extrapolateRight: 'clamp'}),
          }}
        >
          {label.text}
        </div>
      )}
      {waiting && k < 0.7 && (
        <div style={{position: 'absolute', right: 40, top: 36, fontFamily: FONT, fontSize: 26, fontWeight: 600, color: '#fff', background: 'rgba(13,27,38,0.75)', borderRadius: 999, padding: '10px 22px'}}>
          ⏩ sped up
        </div>
      )}
    </AbsoluteFill>
  );
};
