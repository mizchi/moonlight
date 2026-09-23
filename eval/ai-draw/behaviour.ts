/**
 * Moonlight として「意図どおりに扱える図」になっているかを、モデルに操作を
 * 流して確かめる。
 *
 * 絵として正しくても、線がただ図形に触れているだけなら、エディタで図形を
 * 動かした瞬間に外れる。ラベルがただ上に置いた文字なら、図形だけが動いて
 * 文字が取り残される。ここは人がエディタで触ったときと同じ経路（press /
 * move / release）で図形を動かし、付いてくるべきものが付いてくるかを見る。
 */

import type { Page } from '@playwright/test';
import { describeSvg, loadSvg } from '../../js/headless.js';
import { readFacts, type Facts, type Item } from './facts';
import { center, fmt, insideShape, matchEdges, matchNodes, type Check, type NodeMatch } from './judge';
import type { Task } from './tasks';

/** 動かす量。キャンバスの中で目に見えて動く程度 */
const NUDGE = { dx: 60, dy: 45 };

export type Behaviour = {
  checks: Check[];
  /** 動かしたあとの図（レポート用） */
  movedSvg?: string;
  moved?: string;
};

/** モデルの要素のうち、描かれた図形と同じ位置・大きさのもの */
function modelIdOf(shape: Item, elements: Array<{ id: string; shape: string; bbox: Item['box'] }>): string | undefined {
  const near = (a: number, b: number) => Math.abs(a - b) <= 0.5;
  return elements.find(
    (el) =>
      el.shape === shape.tag &&
      near(el.bbox.x, shape.box.x) &&
      near(el.bbox.y, shape.box.y) &&
      near(el.bbox.width, shape.box.width) &&
      near(el.bbox.height, shape.box.height),
  )?.id;
}

/** つながりの一番多い図形（動かしたとき一番多くの線が試される） */
function busiest(task: Task, nodes: NodeMatch[]): NodeMatch | undefined {
  const degree = (label: string) => task.edges.filter((e) => e.from === label || e.to === label).length;
  return [...nodes].filter((n) => n.shape).sort((a, b) => degree(b.label) - degree(a.label))[0];
}

/**
 * モデルが思っている位置と、絵に描かれた位置が合っているか。
 *
 * エディタはモデルのとおりに描く。ここがずれていると、同じ SVG がブラウザで
 * 開いたときとエディタで開いたときで違って見える。文字の幅はモデルが見積もる
 * ので、文字は中心だけを比べる。
 */
function modelVsPicture(
  facts: Facts,
  elements: Array<{ id: string; shape: string; bbox: Item['box'] }>,
): Check {
  const id = 'model-matches-picture';
  if (elements.length !== facts.items.length) {
    return {
      id,
      category: 'behaviour',
      pass: false,
      detail: `the model reads ${elements.length} elements, the picture has ${facts.items.length}`,
    };
  }
  const off: string[] = [];
  facts.items.forEach((item, i) => {
    const el = elements[i];
    if (el.shape !== item.tag) {
      off.push(`#${i} is a ${item.tag} in the picture but a ${el.shape} in the model`);
      return;
    }
    const a = center(item.box);
    const b = center(el.bbox);
    const tol = item.tag === 'text' ? 4 : 1;
    if (Math.abs(a.x - b.x) > tol || Math.abs(a.y - b.y) > tol) {
      const what = item.tag === 'text' ? `text "${item.text}"` : `${item.tag} ${item.id}`;
      off.push(`${what}: drawn around (${a.x.toFixed(0)}, ${a.y.toFixed(0)}), the model puts it at (${b.x.toFixed(0)}, ${b.y.toFixed(0)})`);
    }
  });
  return {
    id,
    category: 'behaviour',
    pass: off.length === 0,
    detail: off.length ? off.join('; ') : 'the editor will show the same picture',
  };
}

/** 読み直して書き出した絵が、元の絵と同じか（要素の並びは変わってもよい） */
function samePicture(before: Facts, after: Facts): string[] {
  const left = [...after.items];
  const lost: string[] = [];
  for (const item of before.items) {
    const at = left.findIndex(
      (o) =>
        o.tag === item.tag &&
        (o.text ?? '') === (item.text ?? '') &&
        Math.abs(o.box.x - item.box.x) <= 1 &&
        Math.abs(o.box.y - item.box.y) <= 1 &&
        Math.abs(o.box.width - item.box.width) <= 1 &&
        Math.abs(o.box.height - item.box.height) <= 1,
    );
    if (at >= 0) left.splice(at, 1);
    else lost.push(`${item.tag}${item.text ? ` "${item.text}"` : ''} ${fmt(item.box)}`);
  }
  return lost;
}

export async function checkBehaviour(page: Page, task: Task, svg: string, facts: Facts): Promise<Behaviour> {
  const checks: Check[] = [];

  // 1. モデルから見て結合が破れていないか
  const state = await describeSvg(svg);
  checks.push({
    id: 'model-consistent',
    category: 'behaviour',
    pass: state.violations.length === 0,
    detail: state.violations.length ? state.violations.join('; ') : 'every joint holds',
  });
  checks.push(modelVsPicture(facts, state.elements));

  // 2. 読み直して書き出しても同じ絵か（SVG ファースト・再編集可能）
  const reloaded = await loadSvg(svg);
  const lost = samePicture(facts, await readFacts(page, reloaded.toSvg()));
  checks.push({
    id: 'round-trip',
    category: 'behaviour',
    pass: lost.length === 0,
    detail: lost.length ? `changed when read back and written again: ${lost.join(', ')}` : 'reads back to the same picture',
  });

  // 3. 図形を動かしたら、線とラベルが付いてくるか
  const nodes = matchNodes(task.nodes, facts);
  const target = busiest(task, nodes);
  if (!target?.shape) {
    checks.push({ id: 'follows-move', category: 'behaviour', pass: false, detail: 'no labelled shape to move' });
    return { checks };
  }
  const id = modelIdOf(target.shape, reloaded.elements());
  if (!id) {
    checks.push({
      id: `follows-move:${target.label}`,
      category: 'behaviour',
      pass: false,
      detail: `could not find ${target.shape.tag} ${fmt(target.shape.box)} in the model`,
    });
    return { checks };
  }
  const c = center(target.shape.box);
  reloaded.apply(`press body ${id} ${c.x} ${c.y}\nmove ${c.x + NUDGE.dx} ${c.y + NUDGE.dy}\nrelease`);
  const movedSvg = reloaded.toSvg();
  const after = await readFacts(page, movedSvg);
  // 動かした図形は位置で探す。ラベルで探すと、ラベルが取り残されたときに線まで
  // 外れたことになり、二つの問題が区別できなくなる
  const shapeAfter = after.items.find(
    (i) =>
      i.tag === target.shape!.tag &&
      Math.abs(i.box.x - (target.shape!.box.x + NUDGE.dx)) <= 1 &&
      Math.abs(i.box.y - (target.shape!.box.y + NUDGE.dy)) <= 1,
  );
  const nodesAfter = matchNodes(task.nodes, after).map((n) =>
    n.label === target.label ? { ...n, shape: shapeAfter } : n,
  );
  const edgesAfter = matchEdges(task.edges, nodesAfter, after);
  const incident = edgesAfter.filter((e) => e.spec.from === target.label || e.spec.to === target.label);
  const detached = incident.filter((e) => !e.touching).map((e) => `${e.spec.from}–${e.spec.to}`);
  checks.push({
    id: `follows-move:${target.label}`,
    category: 'behaviour',
    pass: detached.length === 0,
    detail: detached.length
      ? `after dragging "${target.label}" by (${NUDGE.dx}, ${NUDGE.dy}) these lines no longer reach it: ${detached.join(', ')}`
      : `dragged "${target.label}" by (${NUDGE.dx}, ${NUDGE.dy}); its ${incident.length} line(s) came along`,
  });

  // ラベルは動かした図形の中にあるか。取り残されると、文字は元の場所に残る
  const movedLabel = nodesAfter.find((n) => n.label === target.label)?.text;
  const labelInside = !!movedLabel && !!shapeAfter && insideShape(shapeAfter, center(movedLabel.box));
  checks.push({
    id: `label-follows:${target.label}`,
    category: 'behaviour',
    pass: labelInside,
    detail: labelInside
      ? 'the label moved with its shape'
      : `the shape moved but the label "${target.label}" stayed behind`,
  });

  return { checks, movedSvg, moved: target.label };
}
