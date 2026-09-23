/**
 * vlmkit の check integrity を、描いた図に当てる。
 *
 * integrity はふつう DOM を持つページを測るが、`--elements` を使えば、描画側が
 * 測った要素の矩形と一枚の PNG だけで同じ規則を走らせられる（ブラウザ不要）。
 * 図形を入れ物、その中の文字を子として渡すと:
 *
 *   text-collision        文字どうしの重なり
 *   container-protrusion  ラベルが図形からはみ出している
 *   near-misalignment     並べたつもりの図形が数 px ずれている
 *   degenerate-render     何も描かれていない
 *
 * を見てくれる。どれも決定的（VLM は使わない）。
 */

import { execFile } from 'node:child_process';
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { REPO } from './drawer';
import type { Facts, Item } from './facts';
import { center, insideShape } from './judge';

const execFileAsync = promisify(execFile);
const VLMKIT = join(REPO, 'node_modules', '@mizchi', 'vlmkit', 'dist', 'vlmkit.mjs');

export type IntegrityFinding = { rule: string; severity: string; message: string };

export type Integrity = {
  pass: boolean;
  findings: IntegrityFinding[];
  error?: string;
};

const CLOSED = new Set(['rect', 'circle', 'ellipse']);

/** 描いた図を vlmkit の elements 形式にする。文字は、それを囲む一番小さい図形の子にする */
export function toElements(facts: Facts) {
  const rows: Array<Record<string, unknown>> = [
    { path: 'svg[0]', tag: 'svg', left: 0, top: 0, width: facts.width, height: facts.height },
  ];
  const shapes = facts.items.filter((i) => CLOSED.has(i.tag));
  const pathOf = new Map<Item, string>();
  shapes.forEach((s, i) => {
    const path = `svg[0]>${s.tag}[${i}]`;
    pathOf.set(s, path);
    rows.push({ path, tag: s.tag, id: s.id, left: s.box.x, top: s.box.y, width: s.box.width, height: s.box.height });
  });
  facts.items
    .filter((i) => i.tag === 'text')
    .forEach((t, i) => {
      const c = center(t.box);
      const holder =
        (t.parent && shapes.find((s) => s.id === t.parent)) ||
        shapes.filter((s) => insideShape(s, c)).sort((a, b) => a.box.width * a.box.height - b.box.width * b.box.height)[0];
      const parentPath = holder ? pathOf.get(holder)! : 'svg[0]';
      rows.push({
        path: `${parentPath}>text[${i}]`,
        tag: 'text',
        id: t.id,
        text: t.text ?? '',
        left: t.box.x,
        top: t.box.y,
        width: t.box.width,
        height: t.box.height,
      });
    });
  return { elements: rows };
}

export async function checkIntegrity(facts: Facts, pngPath: string, dir: string): Promise<Integrity> {
  const elementsPath = join(dir, 'elements.json');
  await writeFile(elementsPath, JSON.stringify(toElements(facts), null, 2));
  try {
    const { stdout } = await execFileAsync(
      process.execPath,
      [VLMKIT, 'check', 'integrity', '--elements', elementsPath, '--image', pngPath, '--json', '--no-ledger', '--advisory'],
      { cwd: dir, maxBuffer: 16 * 1024 * 1024 },
    );
    await writeFile(join(dir, 'integrity.json'), stdout);
    const report = JSON.parse(stdout) as { findings?: IntegrityFinding[] };
    const findings = (report.findings ?? []).map((f) => ({ rule: f.rule, severity: f.severity, message: f.message }));
    return { pass: !findings.some((f) => f.severity === 'suspect'), findings };
  } catch (error) {
    return { pass: false, findings: [], error: String(error) };
  }
}
