/**
 * vlmkit の `nlAssert` に渡すレビュアー。
 *
 * nlAssert は「スクリーンショット + 自然言語の主張」を受け取り、判定そのものは
 * ここに委ねる。判定役として使えるのは Anthropic / OpenRouter / Gemini のいずれか
 * で、鍵が一つも無い環境ではテスト側が skip できるように `isVlmConfigured()` を
 * 見てから呼ぶ。
 */

import type {
  NlAssertReviewRequest,
  NlAssertReviewResult,
  NlAssertReviewer,
} from '@mizchi/vlmkit/playwright';

type Provider = {
  name: string;
  key: string;
  model: string;
};

const DEFAULT_MODELS: Record<string, string> = {
  anthropic: 'claude-sonnet-5',
  openrouter: 'anthropic/claude-sonnet-5',
  gemini: 'gemini-2.5-flash',
};

/** 使えるプロバイダを環境変数から選ぶ（先に見つかったものを使う） */
export function resolveProvider(env: NodeJS.ProcessEnv = process.env): Provider | null {
  const model = (name: string) => env.VLMKIT_MODEL || DEFAULT_MODELS[name];
  if (env.ANTHROPIC_API_KEY) {
    return { name: 'anthropic', key: env.ANTHROPIC_API_KEY, model: model('anthropic') };
  }
  if (env.OPENROUTER_API_KEY) {
    return { name: 'openrouter', key: env.OPENROUTER_API_KEY, model: model('openrouter') };
  }
  if (env.GEMINI_API_KEY) {
    return { name: 'gemini', key: env.GEMINI_API_KEY, model: model('gemini') };
  }
  return null;
}

/** VLM 判定を走らせられる環境かどうか */
export function isVlmConfigured(env: NodeJS.ProcessEnv = process.env): boolean {
  return resolveProvider(env) !== null;
}

/** 鍵が無いときにテストへ出す理由 */
export const VLM_SKIP_REASON =
  'set ANTHROPIC_API_KEY, OPENROUTER_API_KEY or GEMINI_API_KEY to run the VLM assertions';

function toBase64(image: NlAssertReviewRequest['image']): string {
  if (typeof image === 'string') return image;
  return Buffer.from(image).toString('base64');
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
      default:
        return askGemini(provider, request);
    }
  };
}
