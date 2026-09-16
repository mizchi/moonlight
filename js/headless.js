/**
 * @mizchi/moonlight/headless — ブラウザなしで図を組み立てる
 *
 * エディタは DOM が要るが、図そのものを作る部分（シーンのモデル、ジョイント、
 * SVG の書き出し）は要らない。ここはその部分だけを Node から使えるようにした
 * 入口で、AI に図を描かせるときの土台でもある。
 *
 *   import { createScene } from '@mizchi/moonlight/headless';
 *
 *   const scene = createScene();
 *   scene.apply(`
 *     rect box 80 80 120 80
 *     circle dot 400 200 40
 *     line link 200 120 360 200
 *     join link start box right
 *     join link end dot left
 *   `);
 *   scene.toSvg();       // Moonlight SVG
 *   scene.describe();    // 「何がどこにあるか」の一文
 *   scene.violations();  // 破れているジョイント（空なら健全）
 */

import {
  runScenario as _runScenario,
  applyToSvg as _applyToSvg,
  describeSvg as _describeSvg,
} from '../_build/js/release/build/entries/model-js/model-js.js';

/** 既定のキャンバス寸法 */
export const DEFAULT_WIDTH = 640;
export const DEFAULT_HEIGHT = 420;

/**
 * SVG を読むには DOMParser が要る。ブラウザなら最初からあり、Node には無いので
 * happy-dom から借りる。一度用意したら使い回す。
 */
let domReady = null;
async function ensureDomParser() {
  if (typeof globalThis.DOMParser === 'function') return;
  if (domReady) return domReady;
  domReady = (async () => {
    let happy;
    try {
      happy = await import('happy-dom');
    } catch {
      throw new Error(
        'reading an SVG needs a DOMParser. Install happy-dom (`npm i happy-dom`), ' +
          'or run on a platform that provides DOMParser.',
      );
    }
    const window = new happy.Window();
    globalThis.DOMParser = window.DOMParser;
  })();
  return domReady;
}

/** SVG の <svg> タグから width/height を読む。読めなければ既定値。 */
function sizeOf(svg, options = {}) {
  const read = (attr) => {
    const found = new RegExp(`\\b${attr}="(\\d+(?:\\.\\d+)?)"`).exec(svg);
    return found ? Number(found[1]) : undefined;
  };
  return {
    width: options.width ?? read('width') ?? DEFAULT_WIDTH,
    height: options.height ?? read('height') ?? DEFAULT_HEIGHT,
  };
}

/** モデルが返す JSON をほどく。ok が false なら投げる。 */
function unwrap(json, what) {
  let result;
  try {
    result = JSON.parse(json);
  } catch (error) {
    throw new Error(`${what}: the model returned something that is not JSON (${error})`);
  }
  if (!result.ok) throw new Error(`${what}: ${result.error ?? 'unknown error'}`);
  return result;
}

/**
 * エラーの行番号を、いま渡されたテキスト基準に直す。
 *
 * モデルは積み上げたシナリオ全体で行を数えるので、そのままでは呼び出し側が
 * 書いた文面と突き合わせられない（AI に直させるときに特に効く）。
 */
function renumber(message, offset) {
  if (offset <= 0) return message;
  return message.replace(/line (\d+):/, (whole, n) => {
    const line = Number(n) - offset;
    return line > 0 ? `line ${line}:` : whole;
  });
}

/**
 * シーン。
 *
 * 状態として持つのは「土台の SVG（あれば）」と「積み上げたシナリオ行」だけで、
 * 問い合わせのたびにモデルを通し直す。途中状態を持たないぶん、同じ入力からは
 * 必ず同じ絵が出る。
 */
class Scene {
  /** @param {{ svg?: string|null, width?: number, height?: number }} [options] */
  constructor(options = {}) {
    this.base = options.svg ?? null;
    this.width = options.width ?? DEFAULT_WIDTH;
    this.height = options.height ?? DEFAULT_HEIGHT;
    this.source = '';
  }

  /**
   * シナリオを足す。文法は docs/headless.md を参照。
   * 解析に失敗したときは、その行を含めて投げ、シーンは元のまま。
   * @param {string} scenario
   * @returns {Scene} 自分自身（続けて書けるように）
   */
  apply(scenario) {
    const written = this.source ? this.source.split('\n').length : 0;
    const next = this.source ? `${this.source}\n${scenario}` : scenario;
    // 先に通してみて、通ったときだけ採る
    try {
      this.#evaluate(next);
    } catch (error) {
      throw new Error(renumber(error instanceof Error ? error.message : String(error), written));
    }
    this.source = next;
    return this;
  }

  /** いまのシーンを Moonlight SVG にする */
  toSvg() {
    return this.#state().svg;
  }

  /** いまのシーンを一文で説明する（AI が現状を掴むため） */
  describe() {
    return this.#state().description;
  }

  /** 要素の一覧（id, 図形, 座標, バウンディングボックス） */
  elements() {
    return this.#state().elements;
  }

  /** 線と図形の結合 */
  joints() {
    return this.#state().joints;
  }

  /** 破れている結合。空でなければ、線が繋がっているつもりの場所から外れている */
  violations() {
    return this.#state().violations;
  }

  /** 絵を見て確かめられる主張（vlmkit などに渡す用） */
  claims() {
    return this.#state().claims;
  }

  /** モデルが返すものをまとめて受け取る */
  inspect() {
    return this.#state();
  }

  #state() {
    return this.#evaluate(this.source);
  }

  #evaluate(source) {
    if (this.base === null) {
      return unwrap(_runScenario(source, this.width, this.height), 'scenario');
    }
    return unwrap(_applyToSvg(this.base, source, this.width, this.height), 'scenario');
  }
}

/**
 * 空のシーンを作る。
 * @param {{ width?: number, height?: number }} [options]
 */
export function createScene(options = {}) {
  return new Scene(options);
}

/**
 * 既存の Moonlight SVG を読み込んで、続きを編集できるシーンにする。
 *
 * DOMParser が要るので非同期。一度読んだあとの操作は同期で済む。
 * @param {string} svg
 * @param {{ width?: number, height?: number }} [options]
 */
export async function loadSvg(svg, options = {}) {
  await ensureDomParser();
  const { width, height } = sizeOf(svg, options);
  // 読めるかどうかをここで確かめる（後で分かるより、読んだ時点で分かるほうがよい）
  unwrap(_describeSvg(svg, width, height), 'loadSvg');
  return new Scene({ svg, width, height });
}

/**
 * SVG を読んで中身を説明するだけ（シーンを持ち回らない用）。
 * @param {string} svg
 * @param {{ width?: number, height?: number }} [options]
 */
export async function describeSvg(svg, options = {}) {
  await ensureDomParser();
  const { width, height } = sizeOf(svg, options);
  return unwrap(_describeSvg(svg, width, height), 'describeSvg');
}

/**
 * SVG を PNG にする。
 *
 * ラスタライズはブラウザに任せるので playwright が要る。入れていなければ
 * その旨を投げる。
 * @param {string} svg
 * @param {{ scale?: number, background?: string }} [options]
 * @returns {Promise<Uint8Array>}
 */
export async function toPng(svg, options = {}) {
  let playwright;
  try {
    playwright = await import('playwright');
  } catch {
    throw new Error('writing a PNG needs playwright. Install it (`npm i -D playwright`).');
  }
  const scale = options.scale ?? 1;
  const { width, height } = sizeOf(svg);
  const browser = await playwright.chromium.launch(
    process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE
      ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE }
      : {},
  );
  try {
    const page = await browser.newPage({
      viewport: { width: Math.ceil(width), height: Math.ceil(height) },
      deviceScaleFactor: scale,
    });
    const background = options.background ?? '#ffffff';
    await page.setContent(
      `<!doctype html><body style="margin:0;background:${background}">${svg}</body>`,
    );
    const target = page.locator('svg').first();
    return await target.screenshot({ type: 'png' });
  } finally {
    await browser.close();
  }
}
