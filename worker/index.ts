// Cloudflare Workers - 静的サイト + WebComponent の CORS 対応

export interface Env {
  ASSETS: Fetcher;
}

// CORS ヘッダー（moonlight-editor.*.js 用）
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // moonlight-editor.*.js へのアクセスは CORS ヘッダーを付与
    if (url.pathname.startsWith('/moonlight-editor.')) {
      // OPTIONS リクエスト（CORS プリフライト）
      if (request.method === 'OPTIONS') {
        return new Response(null, {
          status: 204,
          headers: corsHeaders,
        });
      }

      const response = await env.ASSETS.fetch(request);
      if (!response.ok) {
        return response;
      }

      // CORS ヘッダーを追加
      const newHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        newHeaders.set(key, value);
      });

      return new Response(response.body, {
        status: response.status,
        headers: newHeaders,
      });
    }

    // それ以外は静的アセットをそのまま返す
    return env.ASSETS.fetch(request);
  },
};
