import { test, expect, type Page } from '@playwright/test';
import { nlAssert, NlAssertError } from '@mizchi/vlmkit/playwright';
import {
  createReviewer,
  isVlmConfigured,
  positiveMs,
  reviewerName,
  VLM_SKIP_REASON,
} from './vlm-reviewer';

/**
 * 視覚モデルのテスト。
 *
 * 一つのシナリオテキストから三つを引き出して突き合わせる:
 *   1. セマンティックモデルの予測（@mizchi/moonlight/interaction）
 *   2. 本物のマウス操作をしたあとのエディタの状態
 *   3. 描かれた絵（vlmkit の自然言語アサーションで確かめる）
 *
 * 1 と 2 が食い違えば、モデルか実装のどちらかが嘘をついている。
 * 2 と 3 が食い違えば、状態は正しいのに絵になっていない。
 * どちらの向きのずれも、この一本のテストで拾える。
 */

type ModelResult = {
  ok: boolean;
  error?: string;
  initialSvg: string;
  svg: string;
  description: string;
  claims: string[];
  violations: string[];
  selection: string[];
  elements: Array<{
    id: string;
    shape: string;
    x: number;
    y: number;
    x2?: number;
    y2?: number;
    bbox: { x: number; y: number; width: number; height: number };
  }>;
  joints: Array<{
    line: string;
    endpoint: 'start' | 'end';
    target: string;
    anchor: string;
    x: number;
    y: number;
  }>;
};

declare global {
  interface Window {
    harness: {
      editor: {
        importSvg(svg: string): void;
        exportSvg(): string;
        getElements(): Array<{ id: string; x: number; y: number }>;
        getSelectedIds(): string[];
        select(id: string): void;
        deselect(): void;
      };
      model(scenario: string, width?: number, height?: number): ModelResult;
      load(scenario: string): { svg: string; ids: Record<string, string> };
      mapId(id: string): string;
      elements(): Array<{ id: string; x: number; y: number }>;
      STAGE_WIDTH: number;
      STAGE_HEIGHT: number;
    };
  }
}

const HARNESS = '/e2e/fixtures/scene-harness.html';
const STAGE_WIDTH = 640;
const STAGE_HEIGHT = 420;

/** エディタが描くキャンバス。ツールバーのアイコンも svg なので viewBox で絞る。 */
function canvas(page: Page) {
  return page.locator(`#stage svg[viewBox="0 0 ${STAGE_WIDTH} ${STAGE_HEIGHT}"]`).first();
}

async function openHarness(page: Page) {
  await page.goto(HARNESS);
  await page.waitForSelector('body[data-harness-ready="1"]');
  await expect(canvas(page)).toBeVisible();
}

/** シナリオをモデルに通した結果を取り出す */
async function runModel(page: Page, scenario: string): Promise<ModelResult> {
  const result = await page.evaluate((s) => window.harness.model(s), scenario);
  if (!result.ok) throw new Error(`scenario did not parse: ${result.error}`);
  return result;
}

/**
 * シナリオの初期シーンをエディタに読み込ませ、ID の対応表を受け取る。
 * エディタは取り込み時に ID を振り直すので、以降の比較はこの表を通す。
 */
async function loadScene(page: Page, scenario: string): Promise<Record<string, string>> {
  const { ids } = await page.evaluate((s) => window.harness.load(s), scenario);
  await page.waitForTimeout(80);
  return ids;
}

/** シーン座標を、実際にクリックできる画面座標へ直す */
async function toScreen(page: Page, x: number, y: number) {
  const box = await canvas(page).boundingBox();
  expect(box).not.toBeNull();
  return {
    x: box!.x + (x / STAGE_WIDTH) * box!.width,
    y: box!.y + (y / STAGE_HEIGHT) * box!.height,
  };
}

/** シーン座標のあいだを本物のマウスでドラッグする */
async function dragScene(
  page: Page,
  from: { x: number; y: number },
  to: { x: number; y: number },
) {
  const a = await toScreen(page, from.x, from.y);
  const b = await toScreen(page, to.x, to.y);
  await page.mouse.move(a.x, a.y);
  await page.mouse.down();
  // 途中の move を挟まないとドラッグとして扱われない
  await page.mouse.move((a.x + b.x) / 2, (a.y + b.y) / 2, { steps: 5 });
  await page.mouse.move(b.x, b.y, { steps: 5 });
  await page.mouse.up();
  await page.waitForTimeout(120);
}

/** ハンドル（リサイズ・線端点）を掴んで、シーン座標まで運ぶ */
async function dragHandleTo(page: Page, handle: string, to: { x: number; y: number }) {
  const knob = page.locator(`#stage svg [data-handle="${handle}"]`).first();
  await expect(knob, `handle "${handle}" should be on screen`).toBeVisible();
  const box = await knob.boundingBox();
  expect(box).not.toBeNull();
  const target = await toScreen(page, to.x, to.y);
  await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
  await page.mouse.down();
  await page.mouse.move(target.x, target.y, { steps: 8 });
  await page.mouse.up();
  await page.waitForTimeout(120);
}

/** エディタが今持っている要素を id -> 座標の形で取り出す */
async function editorPositions(page: Page) {
  const elements = await page.evaluate(() => window.harness.elements());
  return new Map(elements.map((el) => [el.id, { x: el.x, y: el.y }]));
}

/** モデルの予測とエディタの実際を、要素ごとに突き合わせる */
async function expectEditorMatchesModel(
  page: Page,
  model: ModelResult,
  ids: Record<string, string>,
  tolerance = 1.5,
) {
  const actual = await editorPositions(page);
  for (const predicted of model.elements) {
    const editorId = ids[predicted.id] ?? predicted.id;
    const got = actual.get(editorId);
    expect(got, `element ${predicted.id} should still exist in the editor`).toBeDefined();
    expect(
      Math.abs(got!.x - predicted.x),
      `${predicted.id}.x — model says ${predicted.x}, editor says ${got!.x}`,
    ).toBeLessThanOrEqual(tolerance);
    expect(
      Math.abs(got!.y - predicted.y),
      `${predicted.id}.y — model says ${predicted.y}, editor says ${got!.y}`,
    ).toBeLessThanOrEqual(tolerance);
  }
  expect(actual.size, 'the editor should hold exactly the elements the model predicts').toBe(
    model.elements.length,
  );
}

/** エディタが書き出した SVG から、その線の端点を読む */
async function editorLineEndpoints(page: Page, editorId: string) {
  const svg: string = await page.evaluate(() => window.harness.editor.exportSvg());
  const tag = svg.match(new RegExp(`<line[^>]*\\bdata-id="${editorId}"[^>]*>`))?.[0];
  expect(tag, `the exported SVG should carry line ${editorId}`).toBeDefined();
  const num = (name: string) => {
    const found = tag!.match(new RegExp(`\\b${name}="([-\\d.]+)"`));
    expect(found, `line ${editorId} should carry ${name}`).not.toBeNull();
    return Number(found![1]);
  };
  return { x1: num('x1'), y1: num('y1'), x2: num('x2'), y2: num('y2') };
}

/** data-connection-* は取り込み後の ID で書かれるので、対応表で組み立てる */
function connectionAttr(
  ids: Record<string, string>,
  side: 'start' | 'end',
  targetId: string,
  anchor: string,
) {
  return `data-connection-${side}="${ids[targetId] ?? targetId}:${anchor}"`;
}

// =============================================================================
// シナリオ
// =============================================================================

/** 矩形と円を線でつなぎ、矩形を動かす */
const BRIDGE = `
rect r1 80 80 100 70
circle c1 420 200 50
line l1 180 115 370 200
join l1 start r1 right
join l1 end c1 left
`;

const BRIDGE_DRAG_RECT = `${BRIDGE}
press body r1 130 115
move 210 245
release
`;

/** 線の端点を図形のアンカーまで運んで結合させる */
const SNAP_ENDPOINT = `
rect target 380 150 120 90
line l1 80 300 200 320
press handle l1 line-end 200 320
move 382 197
release
`;

/** 結合済みの図形をリサイズする */
const RESIZE_JOINTED = `${BRIDGE}
press handle r1 se 180 150
move 250 230
release
`;

/** 三つの図形を二本の線でつないだ鎖 a — b — c */
const CHAIN = `
rect a 40 60 90 70
circle b 290 95 45
ellipse c 520 95 70 45
line l1 130 95 245 95
line l2 335 95 450 95
join l1 start a right
join l1 end b left
join l2 start b right
join l2 end c left
`;

/**
 * 鎖の奥側（b — c 間）の線を下へ引く。
 * 結合先の b と c は連れて動き、手前の a — b 間の線は a に残ったまま伸びる。
 */
const CHAIN_DRAG_MIDDLE_LINE = `${CHAIN}
press body l2 390 95
move 390 300
release
`;

test.describe('Visual model — semantic prediction vs. real interaction', () => {
  test.beforeEach(async ({ page }) => {
    await openHarness(page);
  });

  test('the model predicts where a dragged shape lands', async ({ page }) => {
    const model = await runModel(page, BRIDGE_DRAG_RECT);
    expect(model.violations, model.violations.join('\n')).toEqual([]);

    const ids = await loadScene(page, BRIDGE);
    await dragScene(page, { x: 130, y: 115 }, { x: 210, y: 245 });

    await expectEditorMatchesModel(page, model, ids);
  });

  test('a line stays attached to both shapes through a drag', async ({ page }) => {
    const model = await runModel(page, BRIDGE_DRAG_RECT);
    expect(model.joints).toHaveLength(2);

    const ids = await loadScene(page, BRIDGE);
    await dragScene(page, { x: 130, y: 115 }, { x: 210, y: 245 });

    // エディタが書き出した SVG に接続情報が残っていること
    const svg = await page.evaluate(() => window.harness.editor.exportSvg());
    expect(svg).toContain(connectionAttr(ids, 'start', 'r1', 'right'));
    expect(svg).toContain(connectionAttr(ids, 'end', 'c1', 'left'));

    // 端点がモデルの言う座標に載っていること
    const line = model.elements.find((el) => el.id === 'l1');
    expect(line).toBeDefined();
    const start = model.joints.find((j) => j.endpoint === 'start');
    const end = model.joints.find((j) => j.endpoint === 'end');
    expect({ x: line!.x, y: line!.y }).toEqual({ x: start!.x, y: start!.y });
    expect({ x: line!.x2, y: line!.y2 }).toEqual({ x: end!.x, y: end!.y });
  });

  test('dropping an endpoint near an anchor creates the joint the model predicts', async ({
    page,
  }) => {
    const model = await runModel(page, SNAP_ENDPOINT);
    expect(model.joints).toHaveLength(1);
    expect(model.joints[0]).toMatchObject({ target: 'target', anchor: 'left' });
    expect(model.violations, model.violations.join('\n')).toEqual([]);

    const ids = await loadScene(page, SNAP_ENDPOINT.split('press')[0]);
    // 端点ハンドルは選択中にだけ出る
    await page.evaluate(() => window.harness.editor.select(window.harness.mapId('l1')));
    await page.waitForTimeout(80);
    await dragHandleTo(page, 'line-end', { x: 382, y: 197 });

    const svg = await page.evaluate(() => window.harness.editor.exportSvg());
    expect(svg).toContain(connectionAttr(ids, 'end', 'target', 'left'));
  });

  test('resizing a jointed shape drags the line end along with its anchor', async ({ page }) => {
    const model = await runModel(page, RESIZE_JOINTED);
    expect(model.violations, model.violations.join('\n')).toEqual([]);

    const ids = await loadScene(page, BRIDGE);
    await page.evaluate(() => window.harness.editor.select(window.harness.mapId('r1')));
    await page.waitForTimeout(80);
    await dragHandleTo(page, 'se', { x: 250, y: 230 });

    const svg = await page.evaluate(() => window.harness.editor.exportSvg());
    expect(svg).toContain(connectionAttr(ids, 'start', 'r1', 'right'));
    // 矩形が大きくなった分、右辺のアンカーは右へ動く
    const predicted = model.joints.find((j) => j.endpoint === 'start');
    expect(predicted!.x).toBeGreaterThan(180);
  });

  /**
   * 線の胴体を掴むと結合先の図形も連れて動く。そのとき、連れて動いた図形に
   * ぶら下がる「別の」線まで追随しないと、鎖の手前側が宙に浮いて接続が切れて見える。
   */
  test('dragging a line in a chain leaves no joint behind', async ({ page }) => {
    const model = await runModel(page, CHAIN_DRAG_MIDDLE_LINE);
    expect(model.violations, model.violations.join('\n')).toEqual([]);
    expect(model.joints).toHaveLength(4);

    const ids = await loadScene(page, CHAIN);
    await dragScene(page, { x: 390, y: 95 }, { x: 390, y: 300 });

    await expectEditorMatchesModel(page, model, ids);

    // 四本のジョイントがどれも外れていない
    const svg = await page.evaluate(() => window.harness.editor.exportSvg());
    expect(svg).toContain(connectionAttr(ids, 'start', 'a', 'right'));
    expect(svg).toContain(connectionAttr(ids, 'end', 'b', 'left'));
    expect(svg).toContain(connectionAttr(ids, 'start', 'b', 'right'));
    expect(svg).toContain(connectionAttr(ids, 'end', 'c', 'left'));

    // a — b 間の線は、動いていない a に残ったまま b の新しいアンカーまで伸びる
    const tolerance = 1.5;
    const l1 = await editorLineEndpoints(page, ids['l1']);
    const onA = model.joints.find((j) => j.target === 'a')!;
    const onB = model.joints.find((j) => j.line === 'l1' && j.endpoint === 'end')!;
    expect(Math.abs(l1.x1 - onA.x), `l1 start x — model says ${onA.x}`).toBeLessThanOrEqual(
      tolerance,
    );
    expect(Math.abs(l1.y1 - onA.y), `l1 start y — model says ${onA.y}`).toBeLessThanOrEqual(
      tolerance,
    );
    expect(Math.abs(l1.x2 - onB.x), `l1 end x — model says ${onB.x}`).toBeLessThanOrEqual(
      tolerance,
    );
    expect(Math.abs(l1.y2 - onB.y), `l1 end y — model says ${onB.y}`).toBeLessThanOrEqual(
      tolerance,
    );
  });

  test('the editor round-trips the scene the model describes', async ({ page }) => {
    const model = await runModel(page, BRIDGE);
    const ids = await loadScene(page, BRIDGE);

    const exported = await page.evaluate(() => window.harness.editor.exportSvg());
    for (const el of model.elements) {
      expect(exported, `exported SVG should mention ${el.id}`).toContain(
        `data-id="${ids[el.id]}"`,
      );
    }
  });
});

test.describe('Visual model — what the picture must show (vlmkit)', () => {
  test.skip(!isVlmConfigured(), VLM_SKIP_REASON);
  // 判定役が CLI のときは主張ごとにエージェントが立ち上がるので、既定の 30 秒では足りない
  test.setTimeout(positiveMs(process.env.VLMKIT_TEST_TIMEOUT_MS, 900_000));

  /**
   * モデルの主張をひとつずつレビュアーに見せ、絵が支持しないものを集める。
   * シナリオごとに同じ手順を踏むので、判定の部分だけここにまとめる。
   */
  async function expectPictureSupportsModel(page: Page, model: ModelResult) {
    const stage = page.locator('#stage');
    const reviewer = createReviewer();
    const failures: string[] = [];

    console.log(`[vlmkit] reviewer: ${reviewerName()}`);
    console.log(`[vlmkit] ${model.claims.length} claim(s) to check`);

    /** 主張をひとつ判定させる。通れば null、落ちれば理由を返す。 */
    const ask = async (claim: string): Promise<string | null> => {
      try {
        const verdict = await nlAssert({
          assertion: claim,
          target: stage,
          metadata: { scene: model.description },
          reviewer,
        });
        console.log(`[vlmkit] PASS  ${claim}\n          ${verdict.reasoning}`);
        return null;
      } catch (error) {
        // 判定役が壊れている（鍵切れ・CLI 不在）のは主張が偽なのとは別の話なので、
        // NlAssertError 以外はそのまま投げる
        if (!(error instanceof NlAssertError)) throw error;
        console.log(`[vlmkit] FAIL  ${claim}\n          ${error.result.reasoning}`);
        return error.result.reasoning ?? '(no reasoning given)';
      }
    };

    for (const claim of model.claims) {
      const first = await ask(claim);
      if (first === null) continue;

      // 判定役は毎回同じ答えを返すとは限らない。落ちた主張だけもう一度訊いて、
      // 二度とも落ちたときに失敗とする。絵が本当に主張に反していれば二度落ちる。
      // 一度目だけ落ちたときは、揺れたことをログに残しておく。
      console.log(`[vlmkit] RETRY ${claim}`);
      const second = await ask(claim);
      if (second === null) {
        console.log(`[vlmkit] WOBBLE ${claim}\n          1回目だけ落ちた: ${first}`);
        continue;
      }
      failures.push(`${claim}\n    -> ${first}\n    -> ${second}`);
    }

    expect(failures, `the rendering contradicts the model:\n${failures.join('\n')}`).toEqual([]);
  }

  test('the rendered scene matches every claim the model makes', async ({ page }) => {
    await openHarness(page);
    const model = await runModel(page, BRIDGE_DRAG_RECT);

    await loadScene(page, BRIDGE);
    await dragScene(page, { x: 130, y: 115 }, { x: 210, y: 245 });

    await expectPictureSupportsModel(page, model);
  });

  /**
   * 鎖の線を掴んだあとの絵。取り残された線は「端が図形に触れている」という
   * 主張を絵として裏切るので、座標を見ずにここで捕まえられる。
   */
  test('no line is left dangling after a chain is dragged by its line', async ({ page }) => {
    await openHarness(page);
    const model = await runModel(page, CHAIN_DRAG_MIDDLE_LINE);

    await loadScene(page, CHAIN);
    await dragScene(page, { x: 390, y: 95 }, { x: 390, y: 300 });

    await expectPictureSupportsModel(page, model);
  });

  /**
   * 判定役の効き目そのものを確かめる。
   *
   * 上のテストは「主張が全部通ること」しか見ていないので、何を見せても pass と
   * 答えるレビュアーでも緑になる。逆に、常に落ちるレビュアー（鍵切れ、CLI の
   * 不在、壊れた応答）なら偽の主張を投げるだけのテストが緑になる。どちらの
   * 壊れ方も見逃さないよう、同じレビュアーに真偽ひとつずつ通し、
   * 真を通し・偽を落とすことの両方を要求する。
   */
  test('the reviewer tells a true claim from a false one', async ({ page }) => {
    await openHarness(page);
    await loadScene(page, BRIDGE);

    const stage = page.locator('#stage');
    const reviewer = createReviewer();

    // 絵が支持する主張。落ちれば nlAssert がここで投げる。
    const accepted = await nlAssert({
      assertion: 'The image contains at least one rectangle and at least one circle.',
      target: stage,
      reviewer,
    });
    expect(accepted.pass).toBe(true);
    console.log(`[vlmkit] control — true claim accepted: ${accepted.reasoning}`);

    // 絵が否定する主張。
    const falseClaim = 'The image contains exactly 7 triangle shapes, and no rectangles at all.';
    let rejected: NlAssertError | null = null;
    try {
      await nlAssert({ assertion: falseClaim, target: stage, reviewer });
    } catch (error) {
      if (!(error instanceof NlAssertError)) throw error;
      rejected = error;
    }

    expect(rejected, 'the reviewer must not rubber-stamp a false claim').not.toBeNull();
    expect(rejected!.result.pass).toBe(false);
    console.log(`[vlmkit] control — false claim rejected: ${rejected!.result.reasoning}`);
  });
});
