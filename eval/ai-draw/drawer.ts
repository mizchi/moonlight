/**
 * 図を描く側。
 *
 *   claude  … 手元の `claude` CLI をヘッドレス（-p）で動かし、`moonlight` CLI
 *             だけを道具として渡す。作業はリポジトリの外の一時ディレクトリで行い、
 *             このリポジトリの CLAUDE.md やソースに引きずられないようにする。
 *   oracle  … 課題に添えた正解のシナリオを、同じ CLI に通す（判定の検算用）。
 *
 * どちらも最後に drawing.svg を残す。AI が何をしたか（CLI を何回呼び、何回
 * 失敗し、絵を見て確かめたか）も記録する。
 */

import { execFile, spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { chmod, cp, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import type { Task } from './tasks';

const execFileAsync = promisify(execFile);

export const REPO = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const CLI = join(REPO, 'bin', 'moonlight.js');

export type Driver = 'claude' | 'oracle';

export type Metrics = {
  durationMs: number;
  model?: string;
  /** 推論の深さ（AI_DRAW_EFFORT）。指定しなければ CLI の既定 */
  effort?: string;
  turns?: number;
  costUsd?: number;
  /** 道具を使った回数 */
  toolCalls: number;
  /** moonlight のサブコマンドごとの呼び出し回数 */
  cli: Record<string, number>;
  /** moonlight が失敗を返した回数（文法エラーなど） */
  cliErrors: number;
  /** 許されていない道具を使おうとして断られた回数 */
  denied: number;
  /** 描いた絵を PNG にして目で確かめたか */
  lookedAtPng: boolean;
  /** 案内（docs/headless.md）を読んだか */
  readGuide: boolean;
  finalMessage?: string;
};

export type Drawing = {
  svg?: string;
  baseSvg?: string;
  error?: string;
  metrics: Metrics;
};

const emptyMetrics = (): Metrics => ({
  durationMs: 0,
  toolCalls: 0,
  cli: {},
  cliErrors: 0,
  denied: 0,
  lookedAtPng: false,
  readGuide: false,
});

/** 使う描き手。指定が無ければ、claude CLI があればそれ、無ければ oracle */
export function resolveDriver(env = process.env): Driver {
  const wanted = env.AI_DRAW_DRIVER;
  if (wanted === 'claude' || wanted === 'oracle') return wanted;
  if (wanted) throw new Error(`AI_DRAW_DRIVER must be "claude" or "oracle", got "${wanted}"`);
  return findClaude(env) ? 'claude' : 'oracle';
}

function findClaude(env = process.env): string | null {
  if (env.AI_DRAW_CLAUDE) return env.AI_DRAW_CLAUDE;
  for (const dir of (env.PATH ?? '').split(':')) {
    const candidate = join(dir, 'claude');
    if (dir && existsSync(candidate)) return candidate;
  }
  return null;
}

/** AI に渡す依頼文。道具の説明は CLI 自身と案内文書に任せ、ここでは繰り返さない */
export function promptFor(task: Task): string {
  return [
    'You are drawing a diagram with Moonlight, an SVG diagram editor. There is no GUI here: the only way to draw is the `moonlight` command-line tool on your PATH (run `moonlight --help`). Its guide is ./docs/headless.md.',
    '',
    task.prompt,
    '',
    'Rules:',
    '- Work in the current directory. Save the finished drawing as ./drawing.svg, written by the moonlight tool.',
    ...(task.base
      ? ['- Start from ./base.svg and change only what the request asks for. Do not redraw it from scratch.']
      : []),
    '- The drawing will be edited later in the Moonlight editor, where people drag shapes around. Build it the way Moonlight intends, not just something that looks right.',
    '- Check your result with `moonlight describe drawing.svg` before you finish.',
    '- When you are done, reply with one short line describing the drawing.',
  ].join('\n');
}

/** 作業ディレクトリを用意する（CLI の入口、案内文書、編集の課題なら base.svg） */
async function prepare(task: Task): Promise<{ work: string; baseSvg?: string }> {
  const work = await mkdtemp(join(tmpdir(), `ai-draw-${task.id}-`));
  await mkdir(join(work, 'bin'));
  await mkdir(join(work, 'docs'));
  const shim = join(work, 'bin', 'moonlight');
  await writeFile(shim, `#!/bin/sh\nexec node "${CLI}" "$@"\n`);
  await chmod(shim, 0o755);
  await cp(join(REPO, 'docs', 'headless.md'), join(work, 'docs', 'headless.md'));
  let baseSvg: string | undefined;
  if (task.base) {
    baseSvg = task.base;
    await writeFile(join(work, 'base.svg'), baseSvg);
  }
  return { work, baseSvg };
}

/**
 * 描き手の claude に残してよい CLAUDE* の環境変数（認証と通信に要るもの）。
 *
 * それ以外の CLAUDE* は渡さない。この評価を Claude Code の中で走らせると、親の
 * セッション ID・メッセージの口・推論の深さなどが環境変数で漏れ、描き手が親の
 * 一部のように振る舞う（親の scratchpad に書こうとする、など）。知らない変数も
 * 既定で落とすように、残すほうを数え上げる。ANTHROPIC_* はそのまま渡す。
 */
const CLAUDE_ENV_KEEP = new Set([
  'CLAUDE_CONFIG_DIR',
  'CLAUDE_SESSION_INGRESS_TOKEN_FILE',
  'CLAUDE_CODE_ACCOUNT_UUID',
  'CLAUDE_CODE_ORGANIZATION_UUID',
  'CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST',
  'CLAUDE_CODE_PROXY_RESOLVES_HOSTS',
  'CLAUDE_CODE_GZIP_REQUEST_BODIES',
  'CLAUDE_CODE_ENTRYPOINT',
  'CLAUDE_CODE_VERSION',
  'CLAUDE_CODE_EXECPATH',
  'CLAUDE_CODE_CONTAINER_ID',
  'CLAUDE_CODE_ENVIRONMENT_RUNNER_VERSION',
  'CLAUDE_CODE_USE_CCR_V2',
  'CLAUDE_CODE_USE_BEDROCK',
  'CLAUDE_CODE_USE_VERTEX',
]);

function childEnv(work: string, isolate: boolean): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (isolate && /^CLAUDE/.test(key) && !CLAUDE_ENV_KEEP.has(key)) continue;
    env[key] = value;
  }
  env.PATH = `${join(work, 'bin')}:${process.env.PATH ?? ''}`;
  if (isolate && process.env.AI_DRAW_EFFORT) env.CLAUDE_EFFORT = process.env.AI_DRAW_EFFORT;
  if (!env.PLAYWRIGHT_CHROMIUM_EXECUTABLE && existsSync('/opt/pw-browsers/chromium')) {
    env.PLAYWRIGHT_CHROMIUM_EXECUTABLE = '/opt/pw-browsers/chromium';
  }
  return env;
}

const CLI_COMMANDS = new Set(['render', 'apply', 'describe', 'png', '--help', '-h', 'help']);

/** stream-json の記録から、何をしたかを数える */
export function summarize(transcript: string): Omit<Metrics, 'durationMs'> {
  const m = emptyMetrics();
  for (const raw of transcript.split('\n')) {
    if (!raw.trim()) continue;
    let event: any;
    try {
      event = JSON.parse(raw);
    } catch {
      continue;
    }
    if (event.type === 'system' && event.subtype === 'init') m.model = event.model;
    if (event.type === 'assistant') {
      for (const part of event.message?.content ?? []) {
        if (part.type !== 'tool_use') continue;
        m.toolCalls++;
        const input = part.input ?? {};
        if (part.name === 'Bash' && typeof input.command === 'string') {
          // コマンドとして呼んだものだけ数える（行頭か、| && ; ( の後ろ）
          for (const hit of input.command.matchAll(/(?:^|[|;&(]\s*|\n\s*)moonlight\s+([\w-]+)/g)) {
            const sub = CLI_COMMANDS.has(hit[1]) ? hit[1] : 'other';
            m.cli[sub] = (m.cli[sub] ?? 0) + 1;
          }
          if (/headless\.md/.test(input.command)) m.readGuide = true;
        }
        if (part.name === 'Read' && typeof input.file_path === 'string') {
          if (/\.png$/i.test(input.file_path)) m.lookedAtPng = true;
          if (/headless\.md$/.test(input.file_path)) m.readGuide = true;
        }
      }
    }
    if (event.type === 'user') {
      for (const part of event.message?.content ?? []) {
        if (part.type !== 'tool_result') continue;
        const text = typeof part.content === 'string' ? part.content : JSON.stringify(part.content ?? '');
        if (/moonlight: /.test(text)) m.cliErrors++;
        if (/permission|not allowed|denied/i.test(text) && part.is_error) m.denied++;
      }
    }
    if (event.type === 'result') {
      m.turns = event.num_turns;
      m.costUsd = event.total_cost_usd;
      m.finalMessage = typeof event.result === 'string' ? event.result.trim() : undefined;
    }
  }
  return m;
}

async function runClaude(task: Task, work: string, out: string): Promise<Omit<Drawing, 'svg' | 'baseSvg'>> {
  const claude = findClaude();
  if (!claude) throw new Error('the claude CLI is not on PATH (set AI_DRAW_CLAUDE)');
  const args = [
    '-p',
    promptFor(task),
    '--tools',
    'Bash',
    'Read',
    'Write',
    'Edit',
    '--allowedTools',
    'Bash(moonlight:*)',
    'Read',
    'Write',
    'Edit',
    '--permission-mode',
    'dontAsk',
    '--output-format',
    'stream-json',
    '--verbose',
    '--no-session-persistence',
    '--max-budget-usd',
    process.env.AI_DRAW_BUDGET_USD ?? '2',
  ];
  if (process.env.AI_DRAW_MODEL) args.push('--model', process.env.AI_DRAW_MODEL);
  const timeout = Number(process.env.AI_DRAW_TIMEOUT_MS ?? 600_000);
  const started = Date.now();
  const { transcript, error } = await new Promise<{ transcript: string; error?: string }>((done) => {
    const child = spawn(claude, args, { cwd: work, env: childEnv(work, true), stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => (stdout += chunk));
    child.stderr.on('data', (chunk) => (stderr += chunk));
    const timer = setTimeout(() => child.kill('SIGTERM'), timeout);
    child.on('close', (code, signal) => {
      clearTimeout(timer);
      const why = signal ? `killed by ${signal} (timeout ${timeout}ms?)` : code ? `exited with ${code}: ${stderr.slice(-400)}` : undefined;
      done({ transcript: stdout, error: why });
    });
  });
  await writeFile(join(out, 'transcript.jsonl'), transcript);
  return {
    error,
    metrics: { ...summarize(transcript), effort: process.env.AI_DRAW_EFFORT, durationMs: Date.now() - started },
  };
}

async function runOracle(task: Task, work: string): Promise<Omit<Drawing, 'svg' | 'baseSvg'>> {
  const started = Date.now();
  await writeFile(join(work, 'scene.txt'), task.oracle);
  const args = task.base
    ? [CLI, 'apply', 'base.svg', 'scene.txt', '-o', 'drawing.svg']
    : [CLI, 'render', 'scene.txt', '-o', 'drawing.svg'];
  try {
    await execFileAsync(process.execPath, args, { cwd: work, env: childEnv(work, false) });
    return { metrics: { ...emptyMetrics(), durationMs: Date.now() - started } };
  } catch (error) {
    return { error: String(error), metrics: { ...emptyMetrics(), durationMs: Date.now() - started } };
  }
}

/** 課題を一つ描かせる。作業ディレクトリの中身は out/work に写して残す */
export async function draw(task: Task, driver: Driver, out: string): Promise<Drawing> {
  await mkdir(out, { recursive: true });
  const { work, baseSvg } = await prepare(task);
  try {
    const run = driver === 'claude' ? await runClaude(task, work, out) : await runOracle(task, work);
    const svgPath = join(work, 'drawing.svg');
    const svg = existsSync(svgPath) ? await readFile(svgPath, 'utf8') : undefined;
    await cp(work, join(out, 'work'), {
      recursive: true,
      filter: (src) => !src.includes(`${join(work, 'bin')}`) && !src.includes(`${join(work, 'docs')}`),
    });
    return {
      svg,
      baseSvg,
      error: run.error ?? (svg ? undefined : 'no drawing.svg was written'),
      metrics: run.metrics,
    };
  } finally {
    await rm(work, { recursive: true, force: true });
  }
}
