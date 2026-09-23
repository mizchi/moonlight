/**
 * 描かれたものが頼んだとおりかを、決定的に確かめる。
 *
 * 入力は facts.ts が読んだ「見えている事実」と課題の仕様だけ。AI が付けた ID は
 * 使わず、ラベルの文字で図形を名指しする（人が図を見て確かめるのと同じ手順）。
 */

import type { Box, Facts, Item } from './facts';
import type { EdgeSpec, NodeSpec, Relation, Task } from './tasks';

export type Category = 'structure' | 'legibility' | 'behaviour';

export type Check = {
  id: string;
  category: Category;
  pass: boolean;
  detail: string;
};

export type NodeMatch = {
  label: string;
  text?: Item;
  shape?: Item;
};

export type EdgeMatch = {
  spec: EdgeSpec;
  line?: Item;
  /** 両端がモデル上で結合している（図形を動かしても付いてくる） */
  joined: boolean;
  /** 見た目で両端が図形に触れている */
  touching: boolean;
  /** 向きが逆（directed のとき） */
  reversed: boolean;
};

const CLOSED = new Set(['rect', 'circle', 'ellipse']);
const TOUCH_TOLERANCE = 3;

export const normalize = (s: string) => s.replace(/\s+/g, ' ').trim().toLowerCase();

export const center = (b: Box) => ({ x: b.x + b.width / 2, y: b.y + b.height / 2 });

const area = (b: Box) => Math.max(0, b.width) * Math.max(0, b.height);

function intersection(a: Box, b: Box): number {
  const w = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
  const h = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
  return w > 0 && h > 0 ? w * h : 0;
}

/** 点が図形の中（輪郭から tol 以内の外側も含む）にあるか */
export function insideShape(shape: Item, p: { x: number; y: number }, tol = 0): boolean {
  if (shape.circle) {
    const { cx, cy, r } = shape.circle;
    return Math.hypot(p.x - cx, p.y - cy) <= r + tol;
  }
  if (shape.ellipse) {
    const { cx, cy, rx, ry } = shape.ellipse;
    const rxT = rx + tol;
    const ryT = ry + tol;
    return ((p.x - cx) / rxT) ** 2 + ((p.y - cy) / ryT) ** 2 <= 1;
  }
  const b = shape.box;
  return p.x >= b.x - tol && p.x <= b.x + b.width + tol && p.y >= b.y - tol && p.y <= b.y + b.height + tol;
}

/** 箱全体が図形の中に収まっているか（円や楕円は四隅で見る） */
function boxInsideShape(box: Box, shape: Item, tol = 1): boolean {
  const corners = [
    { x: box.x, y: box.y },
    { x: box.x + box.width, y: box.y },
    { x: box.x, y: box.y + box.height },
    { x: box.x + box.width, y: box.y + box.height },
  ];
  return corners.every((c) => insideShape(shape, c, tol));
}

/** 線分が箱を横切るか（Liang–Barsky） */
function segmentHitsBox(line: NonNullable<Item['line']>, b: Box): boolean {
  let t0 = 0;
  let t1 = 1;
  const dx = line.x2 - line.x1;
  const dy = line.y2 - line.y1;
  const edges: Array<[number, number]> = [
    [-dx, line.x1 - b.x],
    [dx, b.x + b.width - line.x1],
    [-dy, line.y1 - b.y],
    [dy, b.y + b.height - line.y1],
  ];
  for (const [p, q] of edges) {
    if (p === 0) {
      if (q < 0) return false;
      continue;
    }
    const r = q / p;
    if (p < 0) {
      if (r > t1) return false;
      if (r > t0) t0 = r;
    } else {
      if (r < t0) return false;
      if (r < t1) t1 = r;
    }
  }
  return t0 <= t1;
}

const endPoint = (line: Item, end: 'start' | 'end') =>
  end === 'start' ? { x: line.line!.x1, y: line.line!.y1 } : { x: line.line!.x2, y: line.line!.y2 };

/** 線の端が図形に触れているか（結合していなくても、見た目で） */
function touches(line: Item, end: 'start' | 'end', shape: Item | undefined): boolean {
  return !!shape && insideShape(shape, endPoint(line, end), TOUCH_TOLERANCE);
}

const joinedTo = (line: Item, end: 'start' | 'end', shape: Item | undefined) =>
  !!shape && (end === 'start' ? line.start?.target : line.end?.target) === shape.id;

const kindOk = (shape: Item, want: NodeSpec['shape']) =>
  want === 'any' || (want === 'box' ? shape.tag === 'rect' : shape.tag === 'circle' || shape.tag === 'ellipse');

/** ラベルの文字から図形を探す。エディタのラベルなら親、そうでなければ文字を囲む一番小さい図形 */
export function matchNodes(nodes: NodeSpec[], facts: Facts): NodeMatch[] {
  const texts = facts.items.filter((i) => i.tag === 'text');
  const shapes = facts.items.filter((i) => CLOSED.has(i.tag));
  return nodes.map((spec) => {
    const candidates = texts.filter((t) => normalize(t.text ?? '') === normalize(spec.label));
    const container = (t: Item): Item | undefined => {
      if (t.parent) return shapes.find((s) => s.id === t.parent);
      const c = center(t.box);
      return shapes
        .filter((s) => insideShape(s, c))
        .sort((a, b) => area(a.box) - area(b.box))[0];
    };
    // 同じ文字が二つあれば、図形の中にある方を採る
    const ranked = candidates
      .map((t) => ({ t, s: container(t) }))
      .sort((a, b) => Number(!!b.s) - Number(!!a.s));
    const best = ranked[0];
    return { label: spec.label, text: best?.t, shape: best?.s };
  });
}

/** 期待する辺ごとに、それを表している線を探す */
export function matchEdges(edges: EdgeSpec[], nodes: NodeMatch[], facts: Facts): EdgeMatch[] {
  const lines = facts.items.filter((i) => i.tag === 'line' && i.line);
  const shapeOf = (label: string) => nodes.find((n) => n.label === label)?.shape;
  return edges.map((spec) => {
    const a = shapeOf(spec.from);
    const b = shapeOf(spec.to);
    const scored = lines.map((line) => {
      const jf = joinedTo(line, 'start', a) && joinedTo(line, 'end', b);
      const jb = joinedTo(line, 'start', b) && joinedTo(line, 'end', a);
      const tf = touches(line, 'start', a) && touches(line, 'end', b);
      const tb = touches(line, 'start', b) && touches(line, 'end', a);
      // 結合 > 見た目、正しい向き > 逆向き
      const score = jf ? 4 : jb ? 3 : tf ? 2 : tb ? 1 : 0;
      return { line, jf, jb, tf, tb, score };
    });
    const best = scored.sort((x, y) => y.score - x.score)[0];
    if (!best || best.score === 0 || !a || !b) {
      return { spec, joined: false, touching: false, reversed: false };
    }
    const forward = best.jf || (!best.jb && best.tf);
    return {
      spec,
      line: best.line,
      joined: best.jf || best.jb,
      touching: best.tf || best.tb || best.jf || best.jb,
      reversed: !forward,
    };
  });
}

function relationCheck(rel: Relation, nodes: NodeMatch[]): Check {
  const box = (label: string) => nodes.find((n) => n.label === label)?.shape?.box;
  const name =
    rel.kind === 'row' || rel.kind === 'column'
      ? `${rel.kind}(${rel.labels.join(', ')})`
      : `${rel.a} ${rel.kind} ${rel.b}`;
  const id = `relation:${name}`;
  const missing = (rel.kind === 'row' || rel.kind === 'column' ? rel.labels : [rel.a, rel.b]).filter(
    (l) => !box(l),
  );
  if (missing.length > 0) {
    return { id, category: 'structure', pass: false, detail: `no shape for ${missing.join(', ')}` };
  }
  if (rel.kind === 'row' || rel.kind === 'column') {
    const boxes = rel.labels.map((l) => box(l)!);
    const main = rel.kind === 'row' ? 'x' : 'y';
    const cross = rel.kind === 'row' ? 'y' : 'x';
    const size = rel.kind === 'row' ? 'height' : 'width';
    const centers = boxes.map(center);
    const ordered = centers.every((c, i) => i === 0 || c[main] > centers[i - 1][main] + 10);
    const spread = Math.max(...centers.map((c) => c[cross])) - Math.min(...centers.map((c) => c[cross]));
    const limit = Math.max(12, 0.5 * Math.min(...boxes.map((b) => b[size])));
    const aligned = spread <= limit;
    const pass = ordered && aligned;
    const detail = pass
      ? `in order, off-axis spread ${spread.toFixed(0)}px`
      : [
          ordered ? '' : `not in ${rel.kind === 'row' ? 'left-to-right' : 'top-to-bottom'} order`,
          aligned ? '' : `not lined up (off-axis spread ${spread.toFixed(0)}px > ${limit.toFixed(0)}px)`,
        ]
          .filter(Boolean)
          .join('; ');
    return { id, category: 'structure', pass, detail };
  }
  const a = center(box(rel.a)!);
  const b = center(box(rel.b)!);
  const pass =
    rel.kind === 'above'
      ? a.y + 10 < b.y
      : rel.kind === 'below'
        ? a.y > b.y + 10
        : rel.kind === 'leftOf'
          ? a.x + 10 < b.x
          : a.x > b.x + 10;
  return {
    id,
    category: 'structure',
    pass,
    detail: `${rel.a} centre (${a.x.toFixed(0)}, ${a.y.toFixed(0)}), ${rel.b} centre (${b.x.toFixed(0)}, ${b.y.toFixed(0)})`,
  };
}

/** 課題の仕様どおりかを確かめる。base は編集の課題の、手を入れる前の図 */
export function judge(task: Task, facts: Facts, base?: Facts): { checks: Check[]; nodes: NodeMatch[]; edges: EdgeMatch[] } {
  const checks: Check[] = [];
  const nodes = matchNodes(task.nodes, facts);
  const edges = matchEdges(task.edges, nodes, facts);

  // --- 構造: 頼んだ図形・つながり・配置があるか
  for (const [i, n] of nodes.entries()) {
    const spec = task.nodes[i];
    const pass = !!n.text && !!n.shape && kindOk(n.shape, spec.shape);
    const detail = !n.text
      ? 'no text with this label'
      : !n.shape
        ? 'the label is not inside any shape'
        : !kindOk(n.shape, spec.shape)
          ? `inside a ${n.shape.tag}, expected a ${spec.shape === 'box' ? 'rectangle' : 'circle or ellipse'}`
          : `${n.shape.tag} ${n.shape.id}`;
    checks.push({ id: `node:${spec.label}`, category: 'structure', pass, detail });
  }
  for (const e of edges) {
    const name = `${e.spec.from}${e.spec.directed ? '→' : '–'}${e.spec.to}`;
    const pass = e.touching && !(e.spec.directed && e.reversed);
    const detail = !e.line
      ? 'no line joins these two shapes'
      : [
          `line ${e.line.id}`,
          e.joined ? 'joined' : 'touching only (not joined)',
          e.spec.directed && e.reversed ? 'points the wrong way' : '',
          e.spec.directed ? (e.line.markerEnd || e.line.markerStart ? 'arrowhead marker' : 'no arrowhead marker') : '',
        ]
          .filter(Boolean)
          .join(', ');
    checks.push({ id: `edge:${name}`, category: 'structure', pass, detail });
  }
  for (const rel of task.relations) checks.push(relationCheck(rel, nodes));

  // 頼んでいない図形や、頼んでいないつながり
  const used = new Set(nodes.map((n) => n.shape?.id).filter(Boolean));
  const extraShapes = facts.items.filter((i) => CLOSED.has(i.tag) && !used.has(i.id));
  const expectedPairs = new Set(
    task.edges.flatMap((e) => {
      const a = nodes.find((n) => n.label === e.from)?.shape?.id;
      const b = nodes.find((n) => n.label === e.to)?.shape?.id;
      return a && b ? [`${a}|${b}`, `${b}|${a}`] : [];
    }),
  );
  const nodeShapes = nodes.map((n) => n.shape).filter((s): s is Item => !!s);
  const unexpected: string[] = [];
  for (const line of facts.items.filter((i) => i.tag === 'line' && i.line)) {
    const at = (end: 'start' | 'end') =>
      nodeShapes.find((s) => joinedTo(line, end, s)) ?? nodeShapes.find((s) => touches(line, end, s));
    const s = at('start');
    const t = at('end');
    if (s && t && s.id !== t.id && !expectedPairs.has(`${s.id}|${t.id}`)) {
      const label = (id: string) => nodes.find((n) => n.shape?.id === id)?.label ?? id;
      unexpected.push(`${label(s.id)}–${label(t.id)} (line ${line.id})`);
    }
  }
  checks.push({
    id: 'exact',
    category: 'structure',
    pass: extraShapes.length === 0 && unexpected.length === 0,
    detail:
      [
        extraShapes.length ? `extra shapes: ${extraShapes.map((s) => `${s.tag} ${s.id}`).join(', ')}` : '',
        unexpected.length ? `unexpected connections: ${unexpected.join(', ')}` : '',
      ]
        .filter(Boolean)
        .join('; ') || 'nothing beyond what was asked',
  });

  // 編集の課題: 触ってはいけない図形と、動かすべき図形
  if (base) {
    const before = matchNodes(task.nodes, base);
    const shapeBefore = (label: string) => before.find((n) => n.label === label)?.shape?.box;
    const shapeAfter = (label: string) => nodes.find((n) => n.label === label)?.shape?.box;
    for (const label of task.unchanged ?? []) {
      const b0 = shapeBefore(label);
      const b1 = shapeAfter(label);
      const same =
        !!b0 &&
        !!b1 &&
        Math.abs(b0.x - b1.x) <= 1 &&
        Math.abs(b0.y - b1.y) <= 1 &&
        Math.abs(b0.width - b1.width) <= 1 &&
        Math.abs(b0.height - b1.height) <= 1;
      checks.push({
        id: `unchanged:${label}`,
        category: 'structure',
        pass: same,
        detail: !b0 || !b1 ? 'shape not found' : same ? 'left as it was' : `moved or resized: ${fmt(b0)} → ${fmt(b1)}`,
      });
    }
    if (task.moved) {
      const { label, dx, dy } = task.moved;
      const b0 = shapeBefore(label);
      const b1 = shapeAfter(label);
      const ddx = b0 && b1 ? center(b1).x - center(b0).x : NaN;
      const ddy = b0 && b1 ? center(b1).y - center(b0).y : NaN;
      const pass = Math.abs(ddx - dx) <= 20 && Math.abs(ddy - dy) <= 20;
      checks.push({
        id: `moved:${label}`,
        category: 'structure',
        pass,
        detail: !b0 || !b1 ? 'shape not found' : `moved by (${ddx.toFixed(0)}, ${ddy.toFixed(0)}), asked (${dx}, ${dy})`,
      });
    }
  }

  // --- 読みやすさ: ラベルが図形に収まり、重ならず、はみ出さない
  const outside = nodes
    .filter((n) => n.text && n.shape && !boxInsideShape(n.text.box, n.shape))
    .map((n) => `"${n.label}" (${fmt(n.text!.box)} in ${n.shape!.tag} ${fmt(n.shape!.box)})`);
  checks.push({
    id: 'labels-inside',
    category: 'legibility',
    pass: outside.length === 0,
    detail: outside.length ? `sticking out: ${outside.join('; ')}` : 'every label fits in its shape',
  });

  const overlaps: string[] = [];
  for (let i = 0; i < nodeShapes.length; i++) {
    for (let j = i + 1; j < nodeShapes.length; j++) {
      if (intersection(nodeShapes[i].box, nodeShapes[j].box) > 1) overlaps.push(`${nodeShapes[i].id} × ${nodeShapes[j].id}`);
    }
  }
  checks.push({
    id: 'shapes-apart',
    category: 'legibility',
    pass: overlaps.length === 0,
    detail: overlaps.length ? `overlapping: ${overlaps.join(', ')}` : 'no two shapes overlap',
  });

  const texts = facts.items.filter((i) => i.tag === 'text');
  const collisions: string[] = [];
  for (let i = 0; i < texts.length; i++) {
    for (let j = i + 1; j < texts.length; j++) {
      if (intersection(texts[i].box, texts[j].box) > 1) collisions.push(`"${texts[i].text}" × "${texts[j].text}"`);
    }
  }
  const crossings: string[] = [];
  for (const line of facts.items.filter((i) => i.tag === 'line' && i.line)) {
    for (const t of texts) {
      const inner = { x: t.box.x + 1, y: t.box.y + 1, width: t.box.width - 2, height: t.box.height - 2 };
      if (inner.width > 0 && inner.height > 0 && segmentHitsBox(line.line!, inner)) crossings.push(`line ${line.id} × "${t.text}"`);
    }
  }
  checks.push({
    id: 'text-clear',
    category: 'legibility',
    pass: collisions.length === 0 && crossings.length === 0,
    detail:
      [
        collisions.length ? `texts overlapping: ${collisions.join(', ')}` : '',
        crossings.length ? `lines through text: ${crossings.join(', ')}` : '',
      ]
        .filter(Boolean)
        .join('; ') || 'no text is covered',
  });

  const off = facts.items
    .filter(
      (i) =>
        i.box.x < -1 || i.box.y < -1 || i.box.x + i.box.width > facts.width + 1 || i.box.y + i.box.height > facts.height + 1,
    )
    .map((i) => `${i.tag} ${i.id} ${fmt(i.box)}`);
  checks.push({
    id: 'in-canvas',
    category: 'legibility',
    pass: off.length === 0,
    detail: off.length ? `outside the ${facts.width}x${facts.height} canvas: ${off.join(', ')}` : 'everything is on the canvas',
  });

  // --- ふるまい（結合）: 図形を動かしたとき線が付いてくるか。見た目の線と区別する
  for (const e of edges) {
    const name = `${e.spec.from}${e.spec.directed ? '→' : '–'}${e.spec.to}`;
    checks.push({
      id: `joined:${name}`,
      category: 'behaviour',
      pass: e.joined && !(e.spec.directed && e.reversed),
      detail: !e.line ? 'no line' : e.joined ? (e.reversed && e.spec.directed ? 'joined, but the wrong way round' : 'both ends joined') : 'the line only touches the shapes; it will not follow when they move',
    });
  }

  return { checks, nodes, edges };
}

export const fmt = (b: Box) => `(${b.x.toFixed(0)}, ${b.y.toFixed(0)}) ${b.width.toFixed(0)}x${b.height.toFixed(0)}`;
