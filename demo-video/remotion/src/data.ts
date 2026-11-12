// Every number shown on screen lives here, so the graphics always match the narration and docs.
// Source: docs/demo-scripts-gap-selling.md (Tema, 70,000 people, data to October 2026).
export const DATA = {
  company: 'Tema',
  people: '70,000',
  naiveHeadcount: 175524,
  semanticHeadcount: 58862,
  quarterLabel: 'End of Q2 2025',
  regrettedLeavers: '2,782',
  regrettedCost: '$190M',
  aiRegrettedLeavers: '503',
  aiRegrettedCost: '$67M',
  aiGrowth: '~6×',
  // Fill these in from your Week 7 run, then render BenchmarkCard. Leave null to skip it.
  benchmark: {raw: null as number | null, semantic: null as number | null, outOf: 20},
  presenter: 'Ashley',
};
