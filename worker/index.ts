// Cloudflare Workers - CORS 付きで WebComponent を配布

export interface Env {
  ASSETS: Fetcher;
}

// CORS ヘッダー
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Max-Age': '86400',
};

// キャッシュ設定（1日）
const cacheHeaders = {
  'Cache-Control': 'public, max-age=86400',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // OPTIONS リクエスト（CORS プリフライト）
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders,
      });
    }

    // GET/HEAD 以外は拒否
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: corsHeaders,
      });
    }

    // ルートへのアクセスは ES Module 版にリダイレクト
    if (url.pathname === '/' || url.pathname === '') {
      return Response.redirect(`${url.origin}/moonlight-editor.js`, 302);
    }

    // 静的アセットを取得
    const response = await env.ASSETS.fetch(request);

    // アセットが見つからない場合
    if (!response.ok) {
      return new Response('Not Found', {
        status: 404,
        headers: corsHeaders,
      });
    }

    // Content-Type を設定
    const contentType = getContentType(url.pathname);

    // CORS とキャッシュヘッダーを追加
    const newHeaders = new Headers(response.headers);
    Object.entries(corsHeaders).forEach(([key, value]) => {
      newHeaders.set(key, value);
    });
    Object.entries(cacheHeaders).forEach(([key, value]) => {
      newHeaders.set(key, value);
    });
    if (contentType) {
      newHeaders.set('Content-Type', contentType);
    }

    return new Response(response.body, {
      status: response.status,
      headers: newHeaders,
    });
  },
};

function getContentType(pathname: string): string | null {
  if (pathname.endsWith('.js')) {
    return 'application/javascript; charset=utf-8';
  }
  if (pathname.endsWith('.mjs')) {
    return 'application/javascript; charset=utf-8';
  }
  if (pathname.endsWith('.css')) {
    return 'text/css; charset=utf-8';
  }
  if (pathname.endsWith('.json')) {
    return 'application/json; charset=utf-8';
  }
  if (pathname.endsWith('.svg')) {
    return 'image/svg+xml';
  }
  if (pathname.endsWith('.wasm')) {
    return 'application/wasm';
  }
  return null;
}
