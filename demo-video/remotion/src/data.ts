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
  // $190M split by group: regretted leavers Nov 2025 to Oct 2026 at half a salary each, from the 70,000-person
  // data (seed 42). Exact: Engineering 49.8, AI 67.4, HR (People + HR Business Partners) 3.8, everyone else 68.4,
  // total 189.4. Rounded so the four add up to the $190M on screen.
  costSplits: [
    {label: 'Engineering', cost: '$50M', leavers: '621'},
    {label: 'AI', cost: '$67M', leavers: '503'},
    {label: 'HR', cost: '$4M', leavers: '69'},
    {label: 'All other teams', cost: '$69M', leavers: '1,589'},
  ],
  // Fill these in from your Week 7 run, then render BenchmarkCard. Leave null to skip it.
  benchmark: {raw: null as number | null, semantic: null as number | null, outOf: 20},
  presenter: 'Ashley',
};
