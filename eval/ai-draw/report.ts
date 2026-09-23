/**
 * 一回の評価の結果をまとめる（Playwright の globalTeardown として走る）。
 *
 * 課題ごとの result.json を読み、summary.json と report.md を書く。report.md は
 * 課題ごとに、描いた絵・落ちた検査・判定役の理由を並べる。
 */

import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { ClaimVerdict } from '../../e2e/vlm-reviewer';
import type { Driver, Metrics } from './drawer';
import type { Integrity } from './integrity';
import type { Check } from './judge';

export type Scores = {
  structure: boolean;
  legibility: boolean;
  behaviour: boolean;
  /** vlmkit nlAssert。走らせなかったら null */
  visual: boolean | null;
  /** vlmkit check integrity */
  integrity: boolean | null;
  /** 全部を満たした: 頼んだとおりに描け、Moonlight として扱える */
  intended: boolean;
};

export type Result = {
  task: string;
  title: string;
  driver: Driver;
  prompt: string;
  error?: string;
  checks: Check[];
  claims: ClaimVerdict[];
  integrity?: Integrity;
  metrics: Metrics;
  scores: Scores;
};

export function score(checks: Check[], claims: ClaimVerdict[], integrity: Integrity | undefined, drew: boolean): Scores {
  const all = (category: Check['category']) => drew && checks.filter((c) => c.category === category).every((c) => c.pass);
  const structure = all('structure');
  const legibility = all('legibility');
  const behaviour = all('behaviour');
  const visual = claims.length ? claims.every((c) => c.pass) : null;
  const integ = integrity ? integrity.pass : null;
  return {
    structure,
    legibility,
    behaviour,
    visual,
    integrity: integ,
    intended: structure && legibility && behaviour && visual !== false && integ !== false,
  };
}

const mark = (v: boolean | null) => (v === null ? '–' : v ? '✅' : '❌');

/** 検査の ID から、課題をまたいで数えるための種類を取る（edge:A→B → edge） */
const kindOf = (id: string) => id.split(':')[0];

export function renderReport(runId: string, results: Result[]): string {
  const lines: string[] = [];
  const drivers = [...new Set(results.map((r) => r.driver))].join(', ');
  const models = [...new Set(results.map((r) => r.metrics.model).filter(Boolean))].join(', ') || '–';
  lines.push(`# AI 作図の評価 — ${runId}`, '');
  lines.push(`描き手: ${drivers}　モデル: ${models}　課題: ${results.length}`, '');

  const rate = (key: keyof Scores) => {
    const judged = results.filter((r) => r.scores[key] !== null);
    return judged.length ? `${judged.filter((r) => r.scores[key]).length}/${judged.length}` : '–';
  };
  lines.push('| | 構造 | 読みやすさ | ふるまい | 見た目 (vlmkit) | integrity (vlmkit) | 意図どおり |');
  lines.push('|---|---|---|---|---|---|---|');
  lines.push(
    `| **合計** | ${rate('structure')} | ${rate('legibility')} | ${rate('behaviour')} | ${rate('visual')} | ${rate('integrity')} | **${rate('intended')}** |`,
  );
  for (const r of results) {
    const s = r.scores;
    lines.push(
      `| [${r.task}](#${r.task}) | ${mark(s.structure)} | ${mark(s.legibility)} | ${mark(s.behaviour)} | ${mark(s.visual)} | ${mark(s.integrity)} | ${mark(s.intended)} |`,
    );
  }
  lines.push('');

  // 課題をまたいで何が落ちたか（どこに手を入れるべきかの手がかり）
  const failing = new Map<string, Set<string>>();
  for (const r of results) {
    for (const c of r.checks.filter((c) => !c.pass)) {
      const k = kindOf(c.id);
      if (!failing.has(k)) failing.set(k, new Set());
      failing.get(k)!.add(r.task);
    }
    if (r.integrity) {
      for (const f of r.integrity.findings.filter((f) => f.severity === 'suspect')) {
        const k = `integrity:${f.rule}`;
        if (!failing.has(k)) failing.set(k, new Set());
        failing.get(k)!.add(r.task);
      }
    }
  }
  if (failing.size > 0) {
    lines.push('## 落ちた検査（課題をまたいで）', '');
    lines.push('| 検査 | 落ちた課題 |', '|---|---|');
    for (const [k, tasks] of [...failing.entries()].sort((a, b) => b[1].size - a[1].size)) {
      lines.push(`| \`${k}\` | ${tasks.size}/${results.length}: ${[...tasks].join(', ')} |`);
    }
    lines.push('');
  }

  lines.push('## 進め方（道具の使い方）', '');
  lines.push('| 課題 | ターン | 道具 | moonlight 呼び出し | CLI の失敗 | 断られた | 案内を読んだ | PNG を見た | 時間 | 費用 |');
  lines.push('|---|---|---|---|---|---|---|---|---|---|');
  for (const r of results) {
    const m = r.metrics;
    const cli = Object.entries(m.cli)
      .map(([k, v]) => `${k}×${v}`)
      .join(' ');
    lines.push(
      `| ${r.task} | ${m.turns ?? '–'} | ${m.toolCalls} | ${cli || '–'} | ${m.cliErrors} | ${m.denied} | ${m.readGuide ? 'yes' : 'no'} | ${m.lookedAtPng ? 'yes' : 'no'} | ${(m.durationMs / 1000).toFixed(0)}s | ${m.costUsd !== undefined ? `$${m.costUsd.toFixed(3)}` : '–'} |`,
    );
  }
  lines.push('');

  for (const r of results) {
    lines.push(`## ${r.task}`, '', `**${r.title}** — ${mark(r.scores.intended)}`, '');
    lines.push('> ' + r.prompt.replace(/\n/g, '\n> '), '');
    if (r.error) lines.push(`⚠️ ${r.error}`, '');
    lines.push(`| 描いた図 | 一番つながりの多い図形を動かしたあと |`, `|---|---|`);
    lines.push(`| ![](${r.task}/drawing.png) | ![](${r.task}/moved.png) |`, '');
    const failed = r.checks.filter((c) => !c.pass);
    const passed = r.checks.filter((c) => c.pass);
    if (failed.length) {
      lines.push('落ちた検査:', '');
      for (const c of failed) lines.push(`- ❌ \`${c.id}\` (${c.category}) — ${c.detail}`);
      lines.push('');
    }
    lines.push(`<details><summary>通った検査 ${passed.length}</summary>`, '');
    for (const c of passed) lines.push(`- ✅ \`${c.id}\` — ${c.detail}`);
    lines.push('', '</details>', '');
    if (r.claims.length) {
      lines.push('vlmkit nlAssert:', '');
      for (const v of r.claims) {
        lines.push(`- ${v.pass ? '✅' : '❌'}${v.wobbled ? ' (聞き直して通った)' : ''} ${v.claim}`);
        if (!v.pass) for (const why of v.reasoning) lines.push(`  - ${why}`);
      }
      lines.push('');
    }
    if (r.integrity) {
      const findings = r.integrity.findings;
      lines.push(`vlmkit check integrity: ${findings.length ? '' : 'findings なし'}`, '');
      for (const f of findings) lines.push(`- ${f.severity === 'suspect' ? '❌' : 'ℹ️'} \`${f.rule}\` ${f.message}`);
      if (r.integrity.error) lines.push(`- ⚠️ ${r.integrity.error}`);
      lines.push('');
    }
    if (r.metrics.finalMessage) lines.push(`AI の最後の一言: “${r.metrics.finalMessage}”`, '');
  }
  return lines.join('\n');
}

/** 二回の評価を並べる（手を入れる前と後など）。課題は ID で突き合わせる */
export function renderComparison(beforeId: string, before: Result[], afterId: string, after: Result[]): string {
  const lines: string[] = [];
  const pick = (rs: Result[], task: string) => rs.find((r) => r.task === task);
  const tasks = [...new Set([...before.map((r) => r.task), ...after.map((r) => r.task)])].sort();
  // 判定しなかった（null の）課題は数えない。全部 null なら「–」
  const rate = (rs: Result[], key: keyof Scores) => {
    const judged = rs.filter((r) => r.scores[key] !== null);
    return judged.length ? `${judged.filter((r) => r.scores[key]).length}/${judged.length}` : '–';
  };
  const sum = (rs: Result[], f: (m: Metrics) => number | undefined) =>
    rs.reduce((acc, r) => acc + (f(r.metrics) ?? 0), 0);
  lines.push(`## ${beforeId} → ${afterId}`, '');
  lines.push('| | 構造 | 読みやすさ | ふるまい | 見た目 | integrity | 意図どおり | ターン計 | 費用計 | 時間計 |');
  lines.push('|---|---|---|---|---|---|---|---|---|---|');
  for (const [name, rs] of [
    [beforeId, before],
    [afterId, after],
  ] as const) {
    lines.push(
      `| ${name} | ${rate(rs, 'structure')} | ${rate(rs, 'legibility')} | ${rate(rs, 'behaviour')} | ${rate(rs, 'visual')} | ${rate(rs, 'integrity')} | **${rate(rs, 'intended')}** | ${sum(rs, (m) => m.turns)} | $${sum(rs, (m) => m.costUsd).toFixed(2)} | ${(sum(rs, (m) => m.durationMs) / 1000).toFixed(0)}s |`,
    );
  }
  lines.push('', '| 課題 | 意図どおり | ターン | 費用 | 時間 | 断られた |', '|---|---|---|---|---|---|');
  for (const task of tasks) {
    const b = pick(before, task);
    const a = pick(after, task);
    const cell = (f: (r: Result) => string) => `${b ? f(b) : '–'} → ${a ? f(a) : '–'}`;
    lines.push(
      `| ${task} | ${cell((r) => mark(r.scores.intended))} | ${cell((r) => String(r.metrics.turns ?? '–'))} | ${cell((r) => (r.metrics.costUsd !== undefined ? `$${r.metrics.costUsd.toFixed(2)}` : '–'))} | ${cell((r) => `${(r.metrics.durationMs / 1000).toFixed(0)}s`)} | ${cell((r) => String(r.metrics.denied))} |`,
    );
  }
  lines.push('');
  return lines.join('\n');
}

function readResults(runDir: string): Result[] {
  const results: Result[] = [];
  if (!existsSync(runDir)) return results;
  for (const name of readdirSync(runDir).sort()) {
    const file = join(runDir, name, 'result.json');
    if (existsSync(file)) results.push(JSON.parse(readFileSync(file, 'utf8')) as Result);
  }
  return results;
}

export function writeReport(runDir: string): void {
  const results = readResults(runDir);
  if (results.length === 0) return;
  const runId = runDir.split('/').pop() ?? runDir;
  writeFileSync(join(runDir, 'summary.json'), JSON.stringify(results.map(({ task, scores, metrics }) => ({ task, scores, metrics })), null, 2));
  let report = renderReport(runId, results);
  // AI_DRAW_COMPARE=<別の run> があれば、その run と並べた表を先頭に置く
  const other = process.env.AI_DRAW_COMPARE;
  if (other) {
    const before = readResults(join(runDir, '..', other));
    if (before.length > 0) {
      const [title, ...rest] = report.split('\n');
      report = [title, '', renderComparison(other, before, runId, results), ...rest].join('\n');
    }
  }
  writeFileSync(join(runDir, 'report.md'), report);
  console.log(`\n[ai-draw] report: ${join(runDir, 'report.md')}`);
}

export default async function globalTeardown(): Promise<void> {
  if (process.env.AI_DRAW_RUN_DIR) writeReport(process.env.AI_DRAW_RUN_DIR);
}

// 走らせ直さずに report.md を作り直す:
//   node --experimental-strip-types eval/ai-draw/report.ts eval/ai-draw/runs/<run> [<比べる run>]
if (process.argv[1] && import.meta.url === `file://${process.argv[1]}`) {
  if (process.argv[3]) process.env.AI_DRAW_COMPARE = process.argv[3];
  writeReport(process.argv[2]);
}
