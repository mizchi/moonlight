/**
 * 描かれた SVG から「見えている事実」を読む。
 *
 * モデルの説明（describe）は、モデルが思っている図。判定はそれではなく、
 * ブラウザが実際に描いたもの（getBBox の位置と大きさ、文字の中身、線の端の
 * 結合）で行う。両者がずれていれば、それ自体が見つけるべき不具合になる。
 */

import type { Page } from '@playwright/test';

export type Box = { x: number; y: number; width: number; height: number };

export type Joint = { target: string; anchor: string };

export type Item = {
  /** data-id（AI が付けた ID、読み込み直した図なら el-N） */
  id: string;
  tag: string;
  /** ブラウザが描いた範囲（線の太さは含まない） */
  box: Box;
  text?: string;
  line?: { x1: number; y1: number; x2: number; y2: number };
  circle?: { cx: number; cy: number; r: number };
  ellipse?: { cx: number; cy: number; rx: number; ry: number };
  start?: Joint;
  end?: Joint;
  markerStart: boolean;
  markerEnd: boolean;
  dashed: boolean;
  /** エディタのラベル（図形に結び付いた文字）なら、その図形の ID */
  parent?: string;
};

export type Facts = { width: number; height: number; items: Item[] };

/** <svg> の width / height。読めなければ既定の 640 x 420 */
export function sizeOf(svg: string): { width: number; height: number } {
  const read = (name: string, fallback: number) => {
    const m = new RegExp(`<svg[^>]*\\b${name}="(\\d+(?:\\.\\d+)?)"`).exec(svg);
    return m ? Number(m[1]) : fallback;
  };
  return { width: read('width', 640), height: read('height', 420) };
}

/** SVG をページに置いて、要素ごとの事実を読む */
export async function readFacts(page: Page, svg: string): Promise<Facts> {
  const { width, height } = sizeOf(svg);
  await page.setViewportSize({ width: Math.ceil(width), height: Math.ceil(height) });
  await page.setContent(`<!doctype html><body style="margin:0;background:#fff">${svg}</body>`);
  // 文字の寸法はフォントが読み込まれてから測る
  await page.evaluate(() => document.fonts.ready);
  const items = await page.evaluate(() => {
    const joint = (raw: string | null) => {
      if (!raw) return undefined;
      const at = raw.lastIndexOf(':');
      return at < 0 ? undefined : { target: raw.slice(0, at), anchor: raw.slice(at + 1) };
    };
    const num = (el: Element, name: string) => Number(el.getAttribute(name) ?? '0');
    return Array.from(document.querySelectorAll('svg [data-id]')).map((el) => {
      const g = el as SVGGraphicsElement;
      const b = g.getBBox();
      const tag = el.tagName.toLowerCase();
      const item: Record<string, unknown> = {
        id: el.getAttribute('data-id') ?? '',
        tag,
        box: { x: b.x, y: b.y, width: b.width, height: b.height },
        markerStart: (el.getAttribute('marker-start') ?? '').includes('url('),
        markerEnd: (el.getAttribute('marker-end') ?? '').includes('url('),
        dashed: !!el.getAttribute('stroke-dasharray'),
      };
      const parent = el.getAttribute('data-parent-id');
      if (parent) item.parent = parent;
      const start = joint(el.getAttribute('data-connection-start'));
      const end = joint(el.getAttribute('data-connection-end'));
      if (start) item.start = start;
      if (end) item.end = end;
      if (tag === 'text') item.text = (el.textContent ?? '').trim();
      if (tag === 'line') {
        item.line = { x1: num(el, 'x1'), y1: num(el, 'y1'), x2: num(el, 'x2'), y2: num(el, 'y2') };
      }
      if (tag === 'circle') item.circle = { cx: num(el, 'cx'), cy: num(el, 'cy'), r: num(el, 'r') };
      if (tag === 'ellipse') {
        item.ellipse = { cx: num(el, 'cx'), cy: num(el, 'cy'), rx: num(el, 'rx'), ry: num(el, 'ry') };
      }
      return item;
    });
  });
  return { width, height, items: items as Item[] };
}

/** 描いた絵そのもの（判定役に見せる一枚） */
export async function screenshot(page: Page): Promise<Buffer> {
  return page.locator('svg').first().screenshot({ type: 'png' });
}
