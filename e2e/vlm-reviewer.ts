/**
 * vlmkit の `nlAssert` に渡すレビュアー。
 *
 * nlAssert は「スクリーンショット + 自然言語の主張」を受け取り、判定そのものは
 * ここに委ねる。判定役は二通りある:
 *
 *   - API 鍵がある場合   … Anthropic / OpenRouter / Gemini を直接叩く
 *   - 鍵が無い場合       … 手元の `claude` CLI に画像を見せる（Claude Code の
 *                          実行環境ならこれで鍵なしに走る）
 *
 * どちらも使えない環境ではテスト側が skip できるように `isVlmConfigured()` を
 * 見てから呼ぶ。
 */

import { execFile } from 'node:child_process';
import { accessSync, constants } from 'node:fs';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { promisify } from 'node:util';

import type {
  NlAssertReviewRequest,
  NlAssertReviewResult,
  NlAssertReviewer,
} from '@mizchi/vlmkit/playwright';

const execFileAsync = promisify(execFile);

type ProviderName = 'anthropic' | 'openrouter' | 'gemini' | 'claude-cli';

type Provider = {
  name: ProviderName;
  /** API 鍵。claude-cli は CLI 自身の認証を使うので空。 */
  key: string;
  /** 判定に使うモデル。claude-cli では空なら CLI の既定に任せる。 */
  model: string;
  /** claude-cli のときだけ、実行する CLI の在り処 */
  command?: string;
};

const DEFAULT_MODELS: Record<ProviderName, string> = {
  anthropic: 'claude-sonnet-5',
  openrouter: 'anthropic/claude-sonnet-5',
  gemini: 'gemini-2.5-flash',
  'claude-cli': '',
};

/** `claude` CLI の在り処。無ければ null。 */
function findClaudeCli(env: NodeJS.ProcessEnv = process.env): string | null {
  if (env.VLMKIT_CLAUDE_CLI) return env.VLMKIT_CLAUDE_CLI;
  for (const dir of (env.PATH ?? '').split(delimiter)) {
    if (!dir) continue;
    const candidate = join(dir, 'claude');
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      // 次の候補へ
    }
  }
  return null;
}

/**
 * 使えるプロバイダを選ぶ。
 *
 * `VLMKIT_REVIEWER` で名指しできる。指定が無ければ、速い順（API 鍵 → CLI）に
 * 先に見つかったものを使う。
 */
export function resolveProvider(env: NodeJS.ProcessEnv = process.env): Provider | null {
  const modelFor = (name: ProviderName) => env.VLMKIT_MODEL || DEFAULT_MODELS[name];
  const api = (name: ProviderName, key: string | undefined): Provider | null =>
    key ? { name, key, model: modelFor(name) } : null;
  const cli = (): Provider | null => {
    const command = findClaudeCli(env);
    return command
      ? { name: 'claude-cli', key: '', model: modelFor('claude-cli'), command }
      : null;
  };

  const requested = env.VLMKIT_REVIEWER as ProviderName | undefined;
  if (requested) {
    switch (requested) {
      case 'anthropic':
        return api('anthropic', env.ANTHROPIC_API_KEY);
      case 'openrouter':
        return api('openrouter', env.OPENROUTER_API_KEY);
      case 'gemini':
        return api('gemini', env.GEMINI_API_KEY);
      case 'claude-cli':
        return cli();
      default:
        return null;
    }
  }

  return (
    api('anthropic', env.ANTHROPIC_API_KEY) ??
    api('openrouter', env.OPENROUTER_API_KEY) ??
    api('gemini', env.GEMINI_API_KEY) ??
    cli()
  );
}

/** VLM 判定を走らせられる環境かどうか */
export function isVlmConfigured(env: NodeJS.ProcessEnv = process.env): boolean {
  return resolveProvider(env) !== null;
}

/** 判定役の名前（テストのログ用） */
export function reviewerName(env: NodeJS.ProcessEnv = process.env): string {
  const provider = resolveProvider(env);
  if (!provider) return 'none';
  return provider.model ? `${provider.name} (${provider.model})` : provider.name;
}

/** 判定役が一つも無いときにテストへ出す理由 */
export const VLM_SKIP_REASON =
  'no VLM reviewer available — install the `claude` CLI, or set ANTHROPIC_API_KEY, OPENROUTER_API_KEY or GEMINI_API_KEY';

function toBase64(image: NlAssertReviewRequest['image']): string {
  if (typeof image === 'string') return image;
  return Buffer.from(image).toString('base64');
}

function toBuffer(image: NlAssertReviewRequest['image']): Buffer {
  if (typeof image === 'string') return Buffer.from(image, 'base64');
  return Buffer.from(image);
}

function prompt(request: NlAssertReviewRequest): string {
  const context = request.metadata
    ? `\n\nContext (the model's own account of what it drew — use it only to interpret the image, never as evidence on its own):\n${JSON.stringify(request.metadata, null, 2)}`
    : '';
  return [
    'You are checking a rendered SVG diagram against one claim about it.',
    'Judge only from the image. The claim is about what is visible: shape counts, and whether line ends actually touch the shapes they are said to touch.',
    '',
    `Claim: ${request.assertion}`,
    context,
    '',
    'Answer with a single JSON object and nothing else:',
    '{"pass": true|false, "reasoning": "one or two sentences", "confidence": 0.0-1.0}',
  ].join('\n');
}

function parseVerdict(text: string): NlAssertReviewResult {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) {
    return { pass: false, reasoning: `reviewer did not return JSON: ${text.slice(0, 200)}` };
  }
  try {
    const parsed = JSON.parse(match[0]) as Partial<NlAssertReviewResult>;
    return {
      pass: parsed.pass === true,
      reasoning: parsed.reasoning ?? '(no reasoning given)',
      confidence: parsed.confidence,
    };
  } catch (error) {
    return { pass: false, reasoning: `reviewer returned unparsable JSON: ${String(error)}` };
  }
}

async function askAnthropic(
  provider: Provider,
  request: NlAssertReviewRequest,
): Promise<NlAssertReviewResult> {
  const response = await fetch(
    `${process.env.ANTHROPIC_BASE_URL ?? 'https://api.anthropic.com'}/v1/messages`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': provider.key,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: provider.model,
        max_tokens: 512,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: { type: 'base64', media_type: 'image/png', data: toBase64(request.image) },
              },
              { type: 'text', text: prompt(request) },
            ],
          },
        ],
      }),
    },
  );
  if (!response.ok) {
    throw new Error(`Anthropic returned ${response.status}: ${await response.text()}`);
  }
  const body = (await response.json()) as { content: Array<{ type: string; text?: string }> };
  const text = body.content.filter((p) => p.type === 'text').map((p) => p.text ?? '').join('');
  return parseVerdict(text);
}

async function askOpenRouter(
  provider: Provider,
  request: NlAssertReviewRequest,
): Promise<NlAssertReviewResult> {
  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${provider.key}`,
    },
    body: JSON.stringify({
      model: provider.model,
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt(request) },
            {
              type: 'image_url',
              image_url: { url: `data:image/png;base64,${toBase64(request.image)}` },
            },
          ],
        },
      ],
    }),
  });
  if (!response.ok) {
    throw new Error(`OpenRouter returned ${response.status}: ${await response.text()}`);
  }
  const body = (await response.json()) as {
    choices: Array<{ message: { content: string } }>;
  };
  return parseVerdict(body.choices[0]?.message?.content ?? '');
}

async function askGemini(
  provider: Provider,
  request: NlAssertReviewRequest,
): Promise<NlAssertReviewResult> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${provider.model}:generateContent`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': provider.key },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt(request) },
              { inline_data: { mime_type: 'image/png', data: toBase64(request.image) } },
            ],
          },
        ],
      }),
    },
  );
  if (!response.ok) {
    throw new Error(`Gemini returned ${response.status}: ${await response.text()}`);
  }
  const body = (await response.json()) as {
    candidates: Array<{ content: { parts: Array<{ text?: string }> } }>;
  };
  const text = body.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
  return parseVerdict(text);
}

/**
 * 手元の `claude` CLI に判定させる。
 *
 * API 鍵の代わりに CLI 自身の認証を使うので、Claude Code の実行環境なら
 * 鍵を用意せずに自然言語アサーションを走らせられる。画像は一時ファイルに
 * 書き出して読ませる（CLI に画像を直接流す口が無いため）。
 *
 * 読むこと以外はさせない: Read だけを許可し、書き込み・実行・ネットワークの
 * ツールは明示的に禁じる。作業ディレクトリも一時ディレクトリにして、
 * 判定がリポジトリ側の設定に引きずられないようにする。
 */
async function askClaudeCli(
  provider: Provider,
  request: NlAssertReviewRequest,
): Promise<NlAssertReviewResult> {
  const timeout = Number(process.env.VLMKIT_CLI_TIMEOUT_MS ?? 240_000);
  const dir = await mkdtemp(join(tmpdir(), 'vlm-nlassert-'));
  const image = join(dir, 'screenshot.png');
  try {
    await writeFile(image, toBuffer(request.image));
    const args = [
      '-p',
      `Read the image at ${image}, then judge it.\n\n${prompt(request)}`,
      '--allowedTools',
      'Read',
      '--disallowedTools',
      'Bash',
      'Edit',
      'Write',
      'WebFetch',
      'WebSearch',
      '--output-format',
      'text',
    ];
    if (provider.model) args.push('--model', provider.model);
    const { stdout } = await execFileAsync(provider.command ?? 'claude', args, {
      cwd: dir,
      timeout,
      maxBuffer: 8 * 1024 * 1024,
    });
    return parseVerdict(stdout);
  } catch (error) {
    // CLI が動かなかったのは「主張が偽だった」ではない。ここで pass:false を
    // 返すと、判定役が壊れている状態と絵が主張を否定した状態が区別できなくなる
    // （とくに下の判別テストが、何も見ずに緑になる）。他のプロバイダと同じく投げる。
    const reason = error instanceof Error ? error.message : String(error);
    throw new Error(`claude CLI reviewer failed: ${reason}`);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

/** 設定済みのプロバイダに判定させるレビュアーを作る */
export function createReviewer(env: NodeJS.ProcessEnv = process.env): NlAssertReviewer {
  const provider = resolveProvider(env);
  if (!provider) {
    throw new Error(`no VLM provider configured — ${VLM_SKIP_REASON}`);
  }
  return async (request) => {
    switch (provider.name) {
      case 'anthropic':
        return askAnthropic(provider, request);
      case 'openrouter':
        return askOpenRouter(provider, request);
      case 'gemini':
        return askGemini(provider, request);
      default:
        return askClaudeCli(provider, request);
    }
  };
}
