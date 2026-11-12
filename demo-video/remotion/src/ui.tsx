import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig, Easing} from 'remotion';
import {C, FONT} from './theme';

export const Bg: React.FC<{children: React.ReactNode; transparent?: boolean}> = ({children, transparent}) => (
  <AbsoluteFill
    style={{
      fontFamily: FONT,
      color: C.text,
      background: transparent ? 'transparent' : `radial-gradient(1200px 800px at 20% 10%, ${C.bg2} 0%, ${C.bg} 60%)`,
    }}
  >
    {!transparent && <Grid />}
    {children}
  </AbsoluteFill>
);

const Grid: React.FC = () => (
  <AbsoluteFill
    style={{
      opacity: 0.18,
      backgroundImage: `linear-gradient(${C.line} 1px, transparent 1px), linear-gradient(90deg, ${C.line} 1px, transparent 1px)`,
      backgroundSize: '80px 80px',
      maskImage: 'radial-gradient(circle at 50% 40%, black 0%, transparent 75%)',
    }}
  />
);

/** 0 to 1 spring that starts at `delay` frames. */
export const useIn = (delay = 0, damping = 200) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return spring({frame: frame - delay, fps, config: {damping}});
};

/** Fade + rise in at `delay`, and fade out over the last 10 frames of the composition. */
export const Rise: React.FC<{delay?: number; children: React.ReactNode; style?: React.CSSProperties; y?: number}> = ({
  delay = 0,
  children,
  style,
  y = 30,
}) => {
  const p = useIn(delay);
  return (
    <div style={{opacity: p, transform: `translateY(${(1 - p) * y}px)`, ...style}}>{children}</div>
  );
};

/** Fade the whole scene out over its last frames. */
export const SceneOut: React.FC<{children: React.ReactNode; frames?: number}> = ({children, frames = 10}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const o = interpolate(frame, [durationInFrames - frames, durationInFrames], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return <AbsoluteFill style={{opacity: o}}>{children}</AbsoluteFill>;
};

export const CountUp: React.FC<{to: number; start: number; dur?: number; style?: React.CSSProperties}> = ({
  to,
  start,
  dur = 30,
  style,
}) => {
  const frame = useCurrentFrame();
  const v = interpolate(frame, [start, start + dur], [0, to], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  return <span style={{fontVariantNumeric: 'tabular-nums', ...style}}>{Math.round(v).toLocaleString('en-US')}</span>;
};

export const Kicker: React.FC<{children: React.ReactNode; color?: string}> = ({children, color = C.muted}) => (
  <div style={{fontSize: 30, fontWeight: 600, letterSpacing: 4, textTransform: 'uppercase', color}}>{children}</div>
);

export const Pill: React.FC<{children: React.ReactNode; color: string}> = ({children, color}) => (
  <span
    style={{
      display: 'inline-block',
      padding: '10px 22px',
      borderRadius: 999,
      border: `2px solid ${color}`,
      color,
      fontSize: 28,
      fontWeight: 600,
    }}
  >
    {children}
  </span>
);

export const Footer: React.FC = () => (
  <div style={{position: 'absolute', bottom: 48, left: 96, fontSize: 22, color: C.muted, letterSpacing: 1}}>
    Tema is a fictional company · 70,000 synthetic people · data to October 2026
  </div>
);

export const TableIcon: React.FC<{size?: number; color?: string}> = ({size = 90, color = C.muted}) => (
  <svg width={size} height={size * 0.78} viewBox="0 0 100 78">
    <rect x="2" y="2" width="96" height="74" rx="8" fill="none" stroke={color} strokeWidth="4" />
    <rect x="2" y="2" width="96" height="18" rx="8" fill={color} opacity="0.5" />
    {[38, 56].map((y) => (
      <line key={y} x1="2" x2="98" y1={y} y2={y} stroke={color} strokeWidth="3" opacity="0.6" />
    ))}
    {[35, 67].map((x) => (
      <line key={x} x1={x} x2={x} y1="20" y2="76" stroke={color} strokeWidth="3" opacity="0.6" />
    ))}
  </svg>
);
