import { test, expect, type Page } from '@playwright/test';
import { checkBehaviour } from './behaviour';
import { readFacts } from './facts';
import { judge, type Check } from './judge';
import { TASKS, type Task } from './tasks';

/**
 * 判定そのものの検算（AI は呼ばない）。
 *
 * エディタが書き出すのと同じ形の SVG（ラベルは図形に結び付き、矢印は両端が
 * 結合し、文字は中央揃え）を手で書き、理想の図はすべての検査を通ること、
 * わざと一か所だけ壊した図はその検査だけが落ちることを確かめる。ここが緑で
 * なければ、AI の点数は信用できない。
 */

const DEFS =
  '<defs><marker id="arrow-end" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3 z" fill="currentColor"/></marker></defs>';
const svg = (...parts: string[]) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="640" height="420" viewBox="0 0 640 420" data-moonlight="1.0">${DEFS}<rect width="100%" height="100%" fill="#ffffff"/>${parts.join('')}</svg>`;
const box = (id: string, x: number, y: number, w: number, h: number) =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" data-id="${id}" fill="#ffffff" stroke="#333333" stroke-width="2"/>`;
const ring = (id: string, cx: number, cy: number, r: number) =>
  `<circle cx="${cx}" cy="${cy}" r="${r}" data-id="${id}" fill="#ffffff" stroke="#333333" stroke-width="2"/>`;
const label = (id: string, parent: string | null, x: number, y: number, text: string) =>
  `<text x="${x}" y="${y}" font-size="16" data-id="${id}"${parent ? ` data-parent-id="${parent}"` : ''} text-anchor="middle" dominant-baseline="middle" fill="#333333">${text}</text>`;
const link = (
  id: string,
  [x1, y1, x2, y2]: number[],
  from: string | null,
  to: string | null,
  arrowhead = true,
) =>
  `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" data-id="${id}"${from ? ` data-connection-start="${from}"` : ''}${to ? ` data-connection-end="${to}"` : ''} stroke="#333333" stroke-width="2"${arrowhead ? ' marker-end="url(#arrow-end)"' : ''}/>`;

const task = (id: string): Task => TASKS.find((t) => t.id === id)!;

type Pipeline = {
  joined?: boolean;
  bound?: boolean;
  labels?: [string, string, string];
  reversed?: boolean;
  extra?: string[];
};

/** パイプラインの課題の図。既定は理想の図 */
function pipeline(o: Pipeline = {}) {
  const joined = o.joined ?? true;
  const bound = o.bound ?? true;
  const [a, b, c] = o.labels ?? ['Parse', 'Check', 'Emit'];
  const p = (s: string) => (bound ? s : null);
  const j = (s: string) => (joined ? s : null);
  return svg(
    box('parse', 40, 170, 140, 70),
    label('parse-l', p('parse'), 110, 205, a),
    box('check', 250, 170, 140, 70),
    label('check-l', p('check'), 320, 205, b),
    box('emit', 460, 170, 140, 70),
    label('emit-l', p('emit'), 530, 205, c),
    o.reversed
      ? link('p2c', [250, 205, 180, 205], j('check:left'), j('parse:right'))
      : link('p2c', [180, 205, 250, 205], j('parse:right'), j('check:left')),
    link('c2e', [390, 205, 460, 205], j('check:right'), j('emit:left')),
    ...(o.extra ?? []),
  );
}

/** ハブの課題の理想の図（丸い図形と、向きの無い線） */
const hub = svg(
  ring('hub', 320, 210, 45),
  label('hub-l', 'hub', 320, 210, 'Hub'),
  box('north', 260, 30, 120, 50),
  label('north-l', 'north', 320, 55, 'North'),
  box('east', 480, 185, 120, 50),
  label('east-l', 'east', 540, 210, 'East'),
  box('south', 260, 340, 120, 50),
  label('south-l', 'south', 320, 365, 'South'),
  box('west', 40, 185, 120, 50),
  label('west-l', 'west', 100, 210, 'West'),
  link('hn', [320, 165, 320, 80], 'hub:top', 'north:bottom', false),
  link('he', [365, 210, 480, 210], 'hub:right', 'east:left', false),
  link('hs', [320, 255, 320, 340], 'hub:bottom', 'south:top', false),
  link('hw', [275, 210, 160, 210], 'hub:left', 'west:right', false),
);

/** 3 つ並んだ箱。B を dy だけ下げ、A を ax だけずらせる（編集の課題用） */
const row = (dy = 0, ax = 0) =>
  svg(
    box('a', 40 + ax, 120, 120, 60),
    label('a-l', 'a', 100 + ax, 150, 'A'),
    box('b', 260, 120 + dy, 120, 60),
    label('b-l', 'b', 320, 150 + dy, 'B'),
    box('c', 480, 120, 120, 60),
    label('c-l', 'c', 540, 150, 'C'),
    link('ab', [160 + ax, 150, 260, 150 + dy], 'a:right', 'b:left', false),
    link('bc', [380, 150 + dy, 480, 150], 'b:right', 'c:left', false),
  );

async function failing(page: Page, t: Task, drawing: string, base?: string): Promise<string[]> {
  const baseFacts = base ? await readFacts(page, base) : undefined;
  const facts = await readFacts(page, drawing);
  const { checks } = judge(t, facts, baseFacts);
  const behaviour = await checkBehaviour(page, t, drawing, facts);
  const all: Check[] = [...checks, ...behaviour.checks];
  return all.filter((c) => !c.pass).map((c) => `${c.id} — ${c.detail}`);
}

/** 落ちた検査の ID だけ（理由は失敗時のメッセージに出す） */
const ids = (failures: string[]) => failures.map((f) => f.split(' — ')[0]).sort();

test.describe('the judge', () => {
  test('passes the ideal pipeline', async ({ page }) => {
    const f = await failing(page, task('pipeline'), pipeline());
    expect(f, f.join('\n')).toEqual([]);
  });

  test('passes the ideal hub (round shapes, lines without direction)', async ({ page }) => {
    const f = await failing(page, task('hub'), hub);
    expect(f, f.join('\n')).toEqual([]);
  });

  test('lines that only touch the shapes look right but do not follow a move', async ({ page }) => {
    const f = await failing(page, task('pipeline'), pipeline({ joined: false }));
    expect(ids(f), f.join('\n')).toEqual(['follows-move:Check', 'joined:Check→Emit', 'joined:Parse→Check']);
  });

  test('labels that are only placed on top are left behind by a move', async ({ page }) => {
    const f = await failing(page, task('pipeline'), pipeline({ bound: false }));
    expect(ids(f), f.join('\n')).toEqual(['label-follows:Check']);
  });

  test('an arrow drawn the wrong way round is caught', async ({ page }) => {
    const f = await failing(page, task('pipeline'), pipeline({ reversed: true }));
    expect(ids(f), f.join('\n')).toEqual(['edge:Parse→Check', 'joined:Parse→Check']);
  });

  test('boxes in the wrong order are caught', async ({ page }) => {
    // 一つ目と二つ目のラベルを入れ替える: 並びも、矢印の向きも崩れる
    const f = await failing(page, task('pipeline'), pipeline({ labels: ['Check', 'Parse', 'Emit'] }));
    expect(ids(f), f.join('\n')).toContain('relation:row(Parse, Check, Emit)');
  });

  test('a label that sticks out of its box is caught', async ({ page }) => {
    // 中心は箱の中のまま、左端だけ箱の外へ出す
    const nudged = pipeline().replace(
      label('parse-l', 'parse', 110, 205, 'Parse'),
      label('parse-l', 'parse', 50, 205, 'Parse'),
    );
    const f = await failing(page, task('pipeline'), nudged);
    expect(ids(f), f.join('\n')).toEqual(['labels-inside']);
  });

  test('an extra shape and a line through a label are caught', async ({ page }) => {
    const f = await failing(page, task('pipeline'), pipeline({ extra: [box('stray', 250, 40, 60, 40)] }));
    expect(ids(f), f.join('\n')).toEqual(['exact']);
    const g = await failing(page, task('pipeline'), pipeline({ extra: [link('scratch', [60, 195, 160, 215], null, null, false)] }));
    expect(ids(g), g.join('\n')).toEqual(['text-clear']);
  });

  test('an edit that moves what it should, and only that, passes', async ({ page }) => {
    const f = await failing(page, task('edit-move'), row(120), row());
    expect(f, f.join('\n')).toEqual([]);
    const g = await failing(page, task('edit-move'), row(120, -30), row());
    expect(ids(g), g.join('\n')).toEqual(['unchanged:A']);
    const h = await failing(page, task('edit-move'), row(40), row());
    expect(ids(h), h.join('\n')).toEqual(['moved:B']);
  });
});
