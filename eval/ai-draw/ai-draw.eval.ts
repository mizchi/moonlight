import { test, expect, type Page } from '@playwright/test';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createReviewer, isVlmConfigured, reviewEachClaim, reviewerName, type ClaimVerdict } from '../../e2e/vlm-reviewer';
import { checkBehaviour } from './behaviour';
import { draw, promptFor, resolveDriver } from './drawer';
import { readFacts, screenshot } from './facts';
import { checkIntegrity } from './integrity';
import { judge } from './judge';
import { score, type Result } from './report';
import { COMMON_CLAIMS, selectTasks, type Task } from './tasks';

/**
 * AI にヘッドレスで作図させ、頼んだとおりに描けたか・Moonlight として扱える図に
 * なっているかを測る。
 *
 *   pnpm eval:ai-draw                       # claude CLI に描かせる
 *   AI_DRAW_DRIVER=oracle pnpm eval:ai-draw # 正解のシナリオで判定を検算する
 *
 * 課題ごとに一つのテスト。検査は expect.soft で全部記録し、落ちたものが課題の
 * 失敗になる。結果は eval/ai-draw/runs/<run>/ に残り、最後に report.md に
 * まとまる。詳しくは eval/ai-draw/README.md。
 */

const DRIVER = resolveDriver();
const RUN_DIR = process.env.AI_DRAW_RUN_DIR!;
const VLM = process.env.AI_DRAW_VLM !== '0' && isVlmConfigured();

test.describe.configure({ mode: 'parallel' });

async function evaluate(page: Page, task: Task): Promise<Result> {
  const dir = join(RUN_DIR, task.id);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'prompt.txt'), promptFor(task));

  const drawing = await draw(task, DRIVER, dir);
  const base = drawing.baseSvg ? await readFacts(page, drawing.baseSvg) : undefined;
  if (drawing.baseSvg) writeFileSync(join(dir, 'base.svg'), drawing.baseSvg);
  if (!drawing.svg) {
    return {
      task: task.id,
      title: task.title,
      driver: DRIVER,
      prompt: task.prompt,
      error: drawing.error,
      checks: [],
      claims: [],
      metrics: drawing.metrics,
      scores: score([], [], undefined, false),
    };
  }

  writeFileSync(join(dir, 'drawing.svg'), drawing.svg);
  const facts = await readFacts(page, drawing.svg);
  const png = await screenshot(page);
  const pngPath = join(dir, 'drawing.png');
  writeFileSync(pngPath, png);
  writeFileSync(join(dir, 'facts.json'), JSON.stringify(facts, null, 2));

  const verdict = judge(task, facts, base);
  const behaviour = await checkBehaviour(page, task, drawing.svg, facts);
  if (behaviour.movedSvg) {
    writeFileSync(join(dir, 'moved.svg'), behaviour.movedSvg);
    writeFileSync(join(dir, 'moved.png'), await screenshot(page));
  }
  const integrity = await checkIntegrity(facts, pngPath, dir);

  let claims: ClaimVerdict[] = [];
  if (VLM) {
    console.log(`[ai-draw] ${task.id}: vlmkit reviewer ${reviewerName()}`);
    claims = await reviewEachClaim([...task.claims, ...COMMON_CLAIMS], { screenshot: async () => png }, createReviewer());
  }

  const checks = [...verdict.checks, ...behaviour.checks];
  return {
    task: task.id,
    title: task.title,
    driver: DRIVER,
    prompt: task.prompt,
    error: drawing.error,
    checks,
    claims,
    integrity,
    metrics: drawing.metrics,
    scores: score(checks, claims, integrity, true),
  };
}

for (const task of selectTasks()) {
  test(`${task.id}: ${task.title}`, async ({ page }, info) => {
    const result = await evaluate(page, task);
    writeFileSync(join(RUN_DIR, task.id, 'result.json'), JSON.stringify(result, null, 2));
    await info.attach('result.json', { path: join(RUN_DIR, task.id, 'result.json'), contentType: 'application/json' });
    if (result.error === undefined || result.checks.length > 0) {
      await info.attach('drawing.png', { path: join(RUN_DIR, task.id, 'drawing.png'), contentType: 'image/png' }).catch(() => {});
    }

    expect.soft(result.error, 'the drawer should finish and leave drawing.svg').toBeUndefined();
    for (const c of result.checks) expect.soft(c.pass, `${c.category} ${c.id}: ${c.detail}`).toBe(true);
    for (const v of result.claims) expect.soft(v.pass, `vlmkit: ${v.claim}\n${v.reasoning.join('\n')}`).toBe(true);
    if (result.integrity) {
      const findings = result.integrity.findings.filter((f) => f.severity === 'suspect').map((f) => `${f.rule}: ${f.message}`);
      expect.soft(findings, 'vlmkit check integrity').toEqual([]);
    }
  });
}
