/**
 * AI に頼む作図の課題。
 *
 * 一つの課題は「人がふつうに頼む言い方（prompt）」と、その意図を機械で確かめる
 * ための仕様からなる。仕様は三つの物差しで読む:
 *
 *   - nodes / edges / relations … Moonlight のモデルと描かれた SVG から、図の
 *     構造が頼んだとおりかを決定的に確かめる（judge.ts）
 *   - claims                    … 絵を見て確かめる主張。vlmkit の nlAssert に渡す
 *   - oracle                    … 人が書いた正解のシナリオ。判定そのものが正しいかの
 *                                 検算に使う（正解が落ちるなら、壊れているのは判定か
 *                                 Moonlight のほう）
 *
 * ラベルは図形の中の文字で指す。AI が付ける ID は分からないので、「"Parse" と
 * 書かれた図形」のように、見た目で名指しする。
 */

/** 図形の種類。box は矩形、round は円か楕円、any はどれでもよい */
export type NodeShape = 'box' | 'round' | 'any';

export type NodeSpec = {
  /** 図形の中に書かれているはずの文字 */
  label: string;
  shape: NodeShape;
};

export type EdgeSpec = {
  from: string;
  to: string;
  /** 向きのある矢印か（start が from、end が to に付いているべきか） */
  directed: boolean;
};

/** 配置の決まり。a と b はラベル */
export type Relation =
  | { kind: 'row'; labels: string[] }
  | { kind: 'column'; labels: string[] }
  | { kind: 'above' | 'below' | 'leftOf' | 'rightOf'; a: string; b: string };

export type Task = {
  id: string;
  title: string;
  /** AI に渡す依頼文 */
  prompt: string;
  /**
   * 編集の課題では、最初にある図。base.svg として渡す。エディタで描いた図と同じ
   * 形の SVG をそのまま書く（シナリオで作ると、その版の文法でできる図に縛られる）
   */
  base?: string;
  nodes: NodeSpec[];
  edges: EdgeSpec[];
  relations: Relation[];
  /** 編集の課題で、動かしてはいけない図形（ラベル） */
  unchanged?: string[];
  /** 編集の課題で、この量だけ動いているべき図形（許容 ±20） */
  moved?: { label: string; dx: number; dy: number };
  /** 絵を見て確かめる主張（vlmkit nlAssert） */
  claims: string[];
  /** 正解のシナリオ。base があるときは base.svg に apply する */
  oracle: string;
};

/** どの課題にも当てる、読みやすさの主張 */
export const COMMON_CLAIMS = [
  'Every piece of text can be read: no text overlaps another text, and no line passes through a text.',
];

/** エディタが書き出すのと同じ形の図（ラベルは図形に結び付き、線は両端が結合している） */
const editorSvg = (...parts: string[]) =>
  [
    '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="420" viewBox="0 0 640 420" data-moonlight="1.0">',
    '  <defs>',
    '    <marker id="arrow-end" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">',
    '      <path d="M0,0 L0,6 L9,3 z" fill="currentColor"/>',
    '    </marker>',
    '  </defs>',
    '  <rect width="100%" height="100%" fill="#ffffff"/>',
    ...parts.map((part) => `  ${part}`),
    '</svg>',
  ].join('\n');
const box = (id: string, x: number, y: number) =>
  `<rect x="${x}" y="${y}" width="120" height="60" data-id="${id}" fill="none" stroke="#000000" stroke-width="1"/>`;
const joint = (id: string, x1: number, y1: number, x2: number, y2: number, from: string, to: string) =>
  `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" data-id="${id}" data-connection-start="${from}" data-connection-end="${to}" fill="none" stroke="#000000" stroke-width="1"/>`;
const caption = (parent: string, x: number, y: number, text: string) =>
  `<text x="${x}" y="${y}" font-size="16" text-anchor="middle" dominant-baseline="middle" data-id="${parent}-label" data-parent-id="${parent}" fill="#000000">${text}</text>`;

// 読み込むと ID は文書の順に el-1, el-2 … と振り直される（矩形 A, B, 線, ラベル…）
const THREE_BOXES_BASE = editorSvg(
  box('a', 60, 170),
  box('b', 260, 170),
  joint('ab', 180, 200, 260, 200, 'a:right', 'b:left'),
  caption('a', 120, 200, 'A'),
  caption('b', 320, 200, 'B'),
);

const ROW_OF_THREE_BASE = editorSvg(
  box('a', 40, 120),
  box('b', 260, 120),
  box('c', 480, 120),
  joint('ab', 160, 150, 260, 150, 'a:right', 'b:left'),
  joint('bc', 380, 150, 480, 150, 'b:right', 'c:left'),
  caption('a', 100, 150, 'A'),
  caption('b', 320, 150, 'B'),
  caption('c', 540, 150, 'C'),
);

export const TASKS: Task[] = [
  {
    id: 'pipeline',
    title: '3 段のパイプライン（矢印）',
    prompt:
      'Draw a left-to-right pipeline of three boxes labeled "Parse", "Check" and "Emit". Draw an arrow from Parse to Check and an arrow from Check to Emit.',
    nodes: [
      { label: 'Parse', shape: 'box' },
      { label: 'Check', shape: 'box' },
      { label: 'Emit', shape: 'box' },
    ],
    edges: [
      { from: 'Parse', to: 'Check', directed: true },
      { from: 'Check', to: 'Emit', directed: true },
    ],
    relations: [{ kind: 'row', labels: ['Parse', 'Check', 'Emit'] }],
    claims: [
      'Three rectangles labeled "Parse", "Check" and "Emit" are arranged in a row from left to right.',
      'An arrow goes from the "Parse" rectangle to the "Check" rectangle and another from "Check" to "Emit"; each arrow has a visible arrowhead pointing at the rectangle it goes to.',
      'Each label is inside its rectangle and does not touch or cross the rectangle\'s outline.',
    ],
    oracle: `
rect parse 40 170 140 70
label parse Parse
rect check 250 170 140 70
label check Check
rect emit 460 170 140 70
label emit Emit
arrow p2c 180 205 250 205
join p2c start parse right
join p2c end check left
arrow c2e 390 205 460 205
join c2e start check right
join c2e end emit left
`,
  },
  {
    id: 'hub',
    title: 'ハブと 4 方向のスポーク',
    prompt:
      'Draw a hub-and-spoke diagram: a circle labeled "Hub" in the middle of the canvas, and four boxes labeled "North", "East", "South" and "West" placed above, to the right of, below and to the left of the hub. Connect each box to the hub with a line.',
    nodes: [
      { label: 'Hub', shape: 'round' },
      { label: 'North', shape: 'box' },
      { label: 'East', shape: 'box' },
      { label: 'South', shape: 'box' },
      { label: 'West', shape: 'box' },
    ],
    edges: [
      { from: 'Hub', to: 'North', directed: false },
      { from: 'Hub', to: 'East', directed: false },
      { from: 'Hub', to: 'South', directed: false },
      { from: 'Hub', to: 'West', directed: false },
    ],
    relations: [
      { kind: 'above', a: 'North', b: 'Hub' },
      { kind: 'rightOf', a: 'East', b: 'Hub' },
      { kind: 'below', a: 'South', b: 'Hub' },
      { kind: 'leftOf', a: 'West', b: 'Hub' },
    ],
    claims: [
      'A circle labeled "Hub" is in the middle, with rectangles labeled "North", "East", "South" and "West" above it, to its right, below it and to its left.',
      'Each of the four rectangles is joined to the circle by its own line, and every line touches both shapes it joins.',
      'Each label is inside its shape and does not touch or cross the shape\'s outline.',
    ],
    oracle: `
circle hub 320 210 45
label hub Hub
rect north 260 30 120 50
label north North
rect east 480 185 120 50
label east East
rect south 260 340 120 50
label south South
rect west 40 185 120 50
label west West
line hn 320 165 320 80
join hn start hub top
join hn end north bottom
line he 365 210 480 210
join he start hub right
join he end east left
line hs 320 255 320 340
join hs start hub bottom
join hs end south top
line hw 275 210 160 210
join hw start hub left
join hw end west right
`,
  },
  {
    id: 'layers',
    title: '縦に積んだ 3 層',
    prompt:
      'Draw a three-layer architecture stacked vertically: a box "UI" on top, a box "API" in the middle and a box "DB" at the bottom. Connect UI to API and API to DB with lines.',
    nodes: [
      { label: 'UI', shape: 'box' },
      { label: 'API', shape: 'box' },
      { label: 'DB', shape: 'box' },
    ],
    edges: [
      { from: 'UI', to: 'API', directed: false },
      { from: 'API', to: 'DB', directed: false },
    ],
    relations: [{ kind: 'column', labels: ['UI', 'API', 'DB'] }],
    claims: [
      'Three rectangles labeled "UI", "API" and "DB" are stacked vertically in that order from top to bottom.',
      '"UI" is connected to "API" by a line and "API" is connected to "DB" by a line; each line touches both rectangles.',
    ],
    oracle: `
rect ui 220 40 200 70
label ui UI
rect api 220 175 200 70
label api API
rect db 220 310 200 70
label db DB
line ua 320 110 320 175
join ua start ui bottom
join ua end api top
line ad 320 245 320 310
join ad start api bottom
join ad end db top
`,
  },
  {
    id: 'cycle',
    title: '4 つの円の輪（矢印）',
    prompt:
      'Draw four circles labeled "1", "2", "3" and "4" in a ring: 1 at the top, 2 on the right, 3 at the bottom and 4 on the left. Connect them with arrows 1→2, 2→3, 3→4 and 4→1.',
    nodes: [
      { label: '1', shape: 'round' },
      { label: '2', shape: 'round' },
      { label: '3', shape: 'round' },
      { label: '4', shape: 'round' },
    ],
    edges: [
      { from: '1', to: '2', directed: true },
      { from: '2', to: '3', directed: true },
      { from: '3', to: '4', directed: true },
      { from: '4', to: '1', directed: true },
    ],
    relations: [
      { kind: 'above', a: '1', b: '3' },
      { kind: 'rightOf', a: '2', b: '4' },
      { kind: 'above', a: '1', b: '2' },
      { kind: 'below', a: '3', b: '2' },
    ],
    claims: [
      'Four circles labeled 1, 2, 3 and 4 form a ring, with 1 at the top, 2 on the right, 3 at the bottom and 4 on the left.',
      'Arrows go from 1 to 2, from 2 to 3, from 3 to 4 and from 4 back to 1, each with a visible arrowhead at the circle it points to.',
    ],
    oracle: `
circle n1 320 80 40
label n1 1
circle n2 480 210 40
label n2 2
circle n3 320 340 40
label n3 3
circle n4 160 210 40
label n4 4
arrow e12 360 80 480 170
join e12 start n1 right
join e12 end n2 top
arrow e23 480 250 360 340
join e23 start n2 bottom
join e23 end n3 right
arrow e34 280 340 160 250
join e34 start n3 left
join e34 end n4 bottom
arrow e41 160 170 280 80
join e41 start n4 top
join e41 end n1 left
`,
  },
  {
    id: 'tree',
    title: '組織図（木）',
    prompt:
      'Draw an org chart: a box "CEO" at the top; below it, side by side, boxes "CTO" (left) and "CFO" (right); below CTO, boxes "Dev A" and "Dev B" side by side. Connect each manager to the people who report to them with lines.',
    nodes: [
      { label: 'CEO', shape: 'box' },
      { label: 'CTO', shape: 'box' },
      { label: 'CFO', shape: 'box' },
      { label: 'Dev A', shape: 'box' },
      { label: 'Dev B', shape: 'box' },
    ],
    edges: [
      { from: 'CEO', to: 'CTO', directed: false },
      { from: 'CEO', to: 'CFO', directed: false },
      { from: 'CTO', to: 'Dev A', directed: false },
      { from: 'CTO', to: 'Dev B', directed: false },
    ],
    relations: [
      { kind: 'above', a: 'CEO', b: 'CTO' },
      { kind: 'above', a: 'CEO', b: 'CFO' },
      { kind: 'leftOf', a: 'CTO', b: 'CFO' },
      { kind: 'above', a: 'CTO', b: 'Dev A' },
      { kind: 'above', a: 'CTO', b: 'Dev B' },
      { kind: 'leftOf', a: 'Dev A', b: 'Dev B' },
    ],
    claims: [
      'A rectangle labeled "CEO" is at the top, and rectangles labeled "CTO" and "CFO" are side by side below it, with "CTO" on the left.',
      'Rectangles labeled "Dev A" and "Dev B" are side by side below "CTO".',
      'Lines connect CEO to CTO, CEO to CFO, CTO to Dev A and CTO to Dev B, and there are no other connections.',
    ],
    oracle: `
rect ceo 260 30 120 50
label ceo CEO
rect cto 140 160 120 50
label cto CTO
rect cfo 380 160 120 50
label cfo CFO
rect deva 40 300 120 50
label deva Dev A
rect devb 240 300 120 50
label devb Dev B
line l1 320 80 200 160
join l1 start ceo bottom
join l1 end cto top
line l2 320 80 440 160
join l2 start ceo bottom
join l2 end cfo top
line l3 200 210 100 300
join l3 start cto bottom
join l3 end deva top
line l4 200 210 300 300
join l4 start cto bottom
join l4 end devb top
`,
  },
  {
    id: 'japanese',
    title: '日本語のラベル（矢印）',
    prompt: '「受付」「審査」「承認」という 3 つの箱を左から右に並べ、受付 → 審査 → 承認 の順に矢印でつないでください。',
    nodes: [
      { label: '受付', shape: 'box' },
      { label: '審査', shape: 'box' },
      { label: '承認', shape: 'box' },
    ],
    edges: [
      { from: '受付', to: '審査', directed: true },
      { from: '審査', to: '承認', directed: true },
    ],
    relations: [{ kind: 'row', labels: ['受付', '審査', '承認'] }],
    claims: [
      'Three rectangles labeled "受付", "審査" and "承認" are arranged in a row from left to right.',
      'Arrows go from "受付" to "審査" and from "審査" to "承認", each with a visible arrowhead pointing at the rectangle it goes to.',
    ],
    oracle: `
rect r1 40 170 140 70
label r1 受付
rect r2 250 170 140 70
label r2 審査
rect r3 460 170 140 70
label r3 承認
arrow a1 180 205 250 205
join a1 start r1 right
join a1 end r2 left
arrow a2 390 205 460 205
join a2 start r2 right
join a2 end r3 left
`,
  },
  {
    id: 'edit-add',
    title: '既存の図に足す',
    prompt:
      'The file base.svg already contains two boxes "A" and "B" connected by a line, with A on the left. Add a third box "C" to the right of B and connect B to C the same way A is connected to B. Do not move A or B.',
    base: THREE_BOXES_BASE,
    nodes: [
      { label: 'A', shape: 'box' },
      { label: 'B', shape: 'box' },
      { label: 'C', shape: 'box' },
    ],
    edges: [
      { from: 'A', to: 'B', directed: false },
      { from: 'B', to: 'C', directed: false },
    ],
    relations: [{ kind: 'row', labels: ['A', 'B', 'C'] }],
    unchanged: ['A', 'B'],
    claims: [
      'Three rectangles labeled "A", "B" and "C" are in a row from left to right.',
      'A line connects A to B and another line connects B to C; each line touches both rectangles it connects.',
    ],
    // base の ID は読み込みで振り直される（B の矩形は el-2）
    oracle: `
rect c 460 170 120 60
label c C
line bc 380 200 460 200
join bc start el-2 right
join bc end c left
`,
  },
  {
    id: 'edit-move',
    title: '既存の図の箱を動かす',
    prompt:
      'The file base.svg has three boxes "A", "B" and "C" in a row, connected A–B and B–C. Move box B (together with its label) 120 px down so that the diagram forms a V. The connections must stay attached to the boxes.',
    base: ROW_OF_THREE_BASE,
    nodes: [
      { label: 'A', shape: 'box' },
      { label: 'B', shape: 'box' },
      { label: 'C', shape: 'box' },
    ],
    edges: [
      { from: 'A', to: 'B', directed: false },
      { from: 'B', to: 'C', directed: false },
    ],
    relations: [
      { kind: 'below', a: 'B', b: 'A' },
      { kind: 'below', a: 'B', b: 'C' },
    ],
    unchanged: ['A', 'C'],
    moved: { label: 'B', dx: 0, dy: 120 },
    claims: [
      'The rectangle labeled "B" sits lower than the rectangles labeled "A" and "C", so the three form a V shape.',
      'A line connects A to B and another line connects B to C, and each line touches both rectangles it connects.',
      'The label "B" is inside its rectangle.',
    ],
    // B の矩形は el-2。ラベルは図形に結び付いているので、矩形を動かせば付いてくる
    oracle: `
press body el-2 320 150
move 320 270
release
`,
  },
];

/** AI_DRAW_TASKS=pipeline,hub のように絞る */
export function selectTasks(filter = process.env.AI_DRAW_TASKS): Task[] {
  if (!filter) return TASKS;
  const wanted = new Set(filter.split(',').map((s) => s.trim()).filter(Boolean));
  const unknown = [...wanted].filter((id) => !TASKS.some((t) => t.id === id));
  if (unknown.length > 0) {
    throw new Error(`unknown task id(s): ${unknown.join(', ')} (known: ${TASKS.map((t) => t.id).join(', ')})`);
  }
  return TASKS.filter((t) => wanted.has(t.id));
}
