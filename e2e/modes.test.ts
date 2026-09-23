import { test, expect, type Page, type Locator } from '@playwright/test';
import { DEMO } from './demo-scene';

/**
 * 同じ操作を、エディタの三つの殻すべてに当てる。
 *
 *   /                      スタンドアロン   editor_app()
 *   /examples/embed.html   埋め込み         create_js_editor()
 *   /?mode=embed           埋め込み         create_embedded_app()
 *
 * 中核は一つだが、外側の配線は殻ごとに書かれている。片方で直したつもりが他方で
 * 崩れる、という事故が起きうるので、操作の集合をひとつ書いて全部に適用する。
 *
 * 行が一つの殻だけ落ちたら、それは「その殻の配線が抜けている」という意味になる。
 */

type Mode = {
  name: string;
  url: string;
  /** SVG の取り出し方。口が無い殻もあるので任意 */
  exportSvg?: (page: Page) => Promise<string>;
  /** フルスクリーンモーダルを持つのは埋め込みの二つだけ */
  hasModal: boolean;
};

const MODES: Mode[] = [
  {
    name: 'standalone',
    url: '/',
    hasModal: false,
    // ツールバーの Copy SVG と同じ経路（Ctrl+Shift+C）
    exportSvg: async (page) => {
      await page.keyboard.press('Control+Shift+KeyC');
      await page.waitForTimeout(300);
      return page.evaluate(() => navigator.clipboard.readText());
    },
  },
  {
    name: 'embed',
    url: '/examples/embed.html',
    hasModal: true,
    exportSvg: (page) =>
      page.evaluate(() => (window as unknown as { editor: { exportSvg(): string } }).editor.exportSvg()),
  },
  {
    // 殻としては embed と同じものを、ページ全体に開いたもの。ここだけ
    // キーボードが一つも繋がっていなかったことがあるので、並べて回す。
    name: 'embed-url',
    url: '/?mode=embed',
    hasModal: true,
  },
];

/** 書き出した SVG から図形の行だけを取り出す（キャンバス寸法はモードごとに違う） */
function shapeLines(svg: string): string[] {
  return svg
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.includes('data-id='));
}

// --- 全モード共通のヘルパー（既存スイートと同じ作法） ---

const shapes = (page: Page) => page.locator('svg rect[data-id][cursor="move"]');
const handles = (page: Page) => page.locator('svg [data-handle]');
const canvas = (page: Page) => page.locator('svg[viewBox]').first();
const everything = (page: Page) => page.locator('svg [data-id]');

/** キャンバスの見えている部分の左上（何も置かれていない背景）をクリックする */
async function clickBackground(page: Page) {
  // キャンバスが viewport より縦に長い殻では、下の方の図形を触るとページが
  // スクロールし、キャンバスの左上が画面の外へ出る。そこをクリックすると
  // ページの外を押したことになり、フォーカスがエディタから外れて以後のキーが
  // 届かなくなる。
  const box = (await canvas(page).boundingBox())!;
  await page.mouse.click(Math.max(box.x, 0) + 6, Math.max(box.y, 0) + 6);
}

/** キャンバス上の要素を並び順に読む。SVG では文書順がそのまま描画順 */
async function drawOrder(page: Page) {
  // 選択中は選択枠が混ざるので、背景をクリックして外してから読む
  await clickBackground(page);
  await page.waitForTimeout(150);
  return page
    .locator('svg [data-id]')
    .evaluateAll((els) => els.map((el) => el.getAttribute('data-id')));
}

async function num(locator: Locator, name: string) {
  return parseFloat((await locator.getAttribute(name)) ?? '0');
}

async function centerOf(locator: Locator) {
  const box = await locator.boundingBox();
  expect(box, 'the element should be on screen').not.toBeNull();
  return { x: box!.x + box!.width / 2, y: box!.y + box!.height / 2, box: box! };
}

async function dragBy(page: Page, from: { x: number; y: number }, dx: number, dy: number) {
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  // 途中の move を挟まないとドラッグとして扱われない
  await page.mouse.move(from.x + dx / 2, from.y + dy / 2, { steps: 4 });
  await page.mouse.move(from.x + dx, from.y + dy, { steps: 4 });
  await page.mouse.up();
  await page.waitForTimeout(120);
}

async function openEditor(page: Page, mode: Mode) {
  await page.goto(mode.url);
  await expect(shapes(page).first()).toBeVisible();
  await page.waitForTimeout(200);
}

async function select(page: Page, locator: Locator) {
  // 図形の上にテキストの当たり判定が重なることがあるので force
  await locator.click({ force: true });
  await page.waitForTimeout(120);
}

for (const mode of MODES) {
  test.describe(`${mode.name} mode`, () => {
    test.beforeEach(async ({ page }) => {
      await openEditor(page, mode);
    });

    test('opens with the same starting scene', async ({ page }) => {
      // 全モードが同じサンプルを載せていること。ここがずれると、以降の
      // 比較がモードの違いではなく初期状態の違いになってしまう。
      await expect(shapes(page)).toHaveCount(DEMO.rects);
      await expect(page.locator('svg circle[data-id]')).toHaveCount(DEMO.circles);
      await expect(page.locator('svg ellipse[data-id]')).toHaveCount(DEMO.ellipses);
      await expect(page.locator('svg path[data-id]')).toHaveCount(DEMO.paths);
    });

    test('a click selects, and the background deselects', async ({ page }) => {
      await select(page, shapes(page).first());
      expect(await handles(page).count(), 'selecting should raise handles').toBeGreaterThan(0);

      const box = await canvas(page).boundingBox();
      await page.mouse.click(box!.x + 8, box!.y + 8);
      await page.waitForTimeout(150);
      await expect(handles(page)).toHaveCount(0);
    });

    test('a shape can be dragged to a new position', async ({ page }) => {
      const rect = shapes(page).first();
      const [x0, y0] = [await num(rect, 'x'), await num(rect, 'y')];

      await dragBy(page, await centerOf(rect), 80, 60);

      expect(await num(rect, 'x'), 'x should follow the pointer').not.toBe(x0);
      expect(await num(rect, 'y'), 'y should follow the pointer').not.toBe(y0);
    });

    test('a shape can be resized from every corner', async ({ page }) => {
      for (const corner of ['se', 'nw', 'ne', 'sw']) {
        const rect = shapes(page).first();
        await select(page, rect);

        const handle = page.locator(`svg rect[data-handle="${corner}"]`).first();
        await expect(handle, `${corner} handle should be there`).toBeVisible();

        const [w0, h0] = [await num(rect, 'width'), await num(rect, 'height')];
        const pull = corner === 'se' ? [40, 30] : corner === 'nw' ? [-40, -30] : corner === 'ne' ? [40, -30] : [-40, 30];
        await dragBy(page, await centerOf(handle), pull[0], pull[1]);

        const [w1, h1] = [await num(rect, 'width'), await num(rect, 'height')];
        expect(w1 !== w0 || h1 !== h0, `${corner} should change the size`).toBe(true);

        // 次の角は元の大きさから始める。開き直すのでは足りない。保存する殻
        // （スタンドアロンと ?mode=embed）は前の角で広げた大きさのまま読み込むので、
        // 画面の端にある図形は、広がるたびに取っ手が画面の外へ出ていく。
        await page.keyboard.press('Control+z');
        await page.waitForTimeout(200);
        expect([await num(rect, 'width'), await num(rect, 'height')], `${corner}: undo should restore the size`).toEqual([w0, h0]);
      }
    });

    test('two shapes selected together move together', async ({ page }) => {
      const first = shapes(page).first();
      const second = shapes(page).nth(1);
      const before = [await num(first, 'x'), await num(second, 'x')];

      await select(page, first);
      await second.click({ modifiers: ['Shift'], force: true });
      await page.waitForTimeout(120);

      // 掴むのは最初の図形。二つ目の中心はテキストの当たり判定に覆われていて、
      // mouse.down が下の図形まで届かないことがある（クリックと違って force が効かない）。
      await dragBy(page, await centerOf(first), 60, 40);

      const after = [await num(first, 'x'), await num(second, 'x')];
      expect(after[0], 'the shape under the pointer should move').not.toBe(before[0]);
      expect(after[1], 'the other selected shape should move too').not.toBe(before[1]);
    });

    test('right-click opens a menu, inside the viewport', async ({ page }) => {
      const viewport = page.viewportSize()!;
      const box = await canvas(page).boundingBox();

      // 端で開いても画面からはみ出さないこと（はみ出すと項目に手が届かない）
      await canvas(page).click({
        button: 'right',
        position: { x: box!.width - 2, y: box!.height - 2 },
        force: true,
      });

      const menu = page.locator('[data-context-menu]');
      await expect(menu).toBeVisible();

      const rect = await menu.boundingBox();
      expect(rect!.x).toBeGreaterThanOrEqual(0);
      expect(rect!.y).toBeGreaterThanOrEqual(0);
      expect(rect!.x + rect!.width).toBeLessThanOrEqual(viewport.width);
      expect(rect!.y + rect!.height).toBeLessThanOrEqual(viewport.height);
    });

    test('a shape can be deleted from the context menu', async ({ page }) => {
      const before = await everything(page).count();

      await shapes(page).first().click({ button: 'right', force: true });
      const remove = page.locator('[data-context-menu] button:has-text("Delete")').first();
      await expect(remove).toBeVisible();
      await remove.click();
      await page.waitForTimeout(200);

      expect(await everything(page).count()).toBeLessThan(before);
    });

    test('the Delete key removes the selection', async ({ page }) => {
      const before = await everything(page).count();

      await select(page, shapes(page).first());
      await page.keyboard.press('Delete');
      await page.waitForTimeout(200);

      expect(await everything(page).count()).toBeLessThan(before);
    });

    test('arrow keys nudge the selection', async ({ page }) => {
      const rect = shapes(page).first();
      await select(page, rect);

      const x0 = await num(rect, 'x');
      await page.keyboard.press('ArrowRight');
      await page.waitForTimeout(200);

      // 移動量も殻ごとに揃っていること（別々に書かれていた頃はここがずれた）
      expect(await num(rect, 'x')).toBe(x0 + 5);
    });

    test('shift+arrow resizes instead of moving', async ({ page }) => {
      const rect = shapes(page).first();
      await select(page, rect);

      const [x0, w0] = [await num(rect, 'x'), await num(rect, 'width')];
      await page.keyboard.press('Shift+ArrowRight');
      await page.waitForTimeout(200);

      expect(await num(rect, 'width'), 'shift+arrow should widen it').toBe(w0 + 5);
      expect(await num(rect, 'x'), 'and leave it where it is').toBe(x0);
    });

    test('a drag can be undone', async ({ page }) => {
      const rect = shapes(page).first();
      const x0 = await num(rect, 'x');

      await dragBy(page, await centerOf(rect), 80, 60);
      expect(await num(rect, 'x')).not.toBe(x0);

      await page.keyboard.press('Control+z');
      await page.waitForTimeout(250);
      expect(await num(rect, 'x'), 'undo should put it back').toBe(x0);
    });

    test('one undo brings back everything a delete removed', async ({ page }) => {
      // ラベル付きの図形を消すと要素は複数消えるが、操作としては一回なので
      // Ctrl+Z 一回で全部戻ってほしい（半分だけ戻るのは壊れた状態）
      const before = await everything(page).count();

      await select(page, shapes(page).first());
      await page.keyboard.press('Delete');
      await page.waitForTimeout(200);
      const afterDelete = await everything(page).count();
      expect(afterDelete, 'the delete should take more than one element').toBeLessThan(before - 1);

      await page.keyboard.press('Control+z');
      await page.waitForTimeout(250);
      expect(await everything(page).count(), 'one undo should restore all of it').toBe(before);
    });

    test('Ctrl+D duplicates the selection, and Ctrl+Z takes it back', async ({ page }) => {
      const before = await everything(page).count();

      await select(page, shapes(page).first());
      await page.keyboard.press('Control+d');
      await page.waitForTimeout(250);
      expect(await everything(page).count(), 'the copy should be there').toBeGreaterThan(before);

      await page.keyboard.press('Control+z');
      await page.waitForTimeout(250);
      expect(await everything(page).count(), 'one undo should remove the whole copy').toBe(before);
    });

    test('a freehand stroke draws, deletes, undoes and redoes', async ({ page }) => {
      const strokes = page.locator('svg path[data-id]');
      // デモには手描きの ↻ が一本だけある
      const before = DEMO.paths;
      await expect(strokes, 'the demo has its own hand-drawn path').toHaveCount(before);

      // フリードローへ。キーは三つの殻で共通
      const box = await canvas(page).boundingBox();
      await clickBackground(page);
      await page.keyboard.press('p');
      await page.waitForTimeout(200);

      // 見えている範囲で描く（キャンバスが viewport より縦に長い殻がある）
      const viewport = page.viewportSize()!;
      const y = Math.min(box!.y + box!.height * 0.45, viewport.height - 140);
      const x0 = box!.x + box!.width * 0.2;
      await page.mouse.move(x0, y);
      await page.mouse.down();
      for (let i = 1; i <= 12; i++) {
        await page.mouse.move(x0 + i * 12, y - i * 2, { steps: 3 });
      }
      await page.mouse.up();
      // 描いた線は、他を触らなくてもその場で出ること
      await expect(strokes, 'the stroke should appear as soon as it is drawn').toHaveCount(before + 1);

      // 描いた直後は選択されているので、そのまま消せる
      await page.keyboard.press('Delete');
      await expect(strokes).toHaveCount(before);

      await page.keyboard.press('Control+z');
      await expect(strokes, 'undo should bring the stroke back').toHaveCount(before + 1);

      await page.keyboard.press('Control+z');
      await expect(strokes, 'a second undo should take back the drawing itself').toHaveCount(before);

      await page.keyboard.press('Control+Shift+z');
      await expect(strokes, 'redo should draw it again').toHaveCount(before + 1);
    });

    test('Ctrl+C then Ctrl+V pastes a copy, and one undo removes it', async ({ page }) => {
      const before = await everything(page).count();

      await select(page, shapes(page).first());
      await page.keyboard.press('Control+c');
      await page.keyboard.press('Control+v');
      await page.waitForTimeout(250);
      expect(await everything(page).count(), 'the paste should land').toBeGreaterThan(before);

      await page.keyboard.press('Control+z');
      await page.waitForTimeout(250);
      expect(await everything(page).count(), 'one undo should remove the whole paste').toBe(before);
    });

    test('Ctrl+A selects everything', async ({ page }) => {
      const before = await everything(page).count();

      await select(page, shapes(page).first());
      await page.keyboard.press('Control+a');
      await page.waitForTimeout(150);
      await page.keyboard.press('Delete');
      await page.waitForTimeout(250);

      expect(await everything(page).count(), 'select all + delete should empty the canvas').toBe(0);
    });

    test('undo puts a deleted shape back where it was, not on top', async ({ page }) => {
      // 消した要素が末尾に戻ると、その図形は他の図形より手前に描かれるようになる。
      // 書き出した SVG の見た目が undo の前後で変わってしまう。
      const before = await drawOrder(page);
      expect(before.length, 'the scene should not be empty').toBeGreaterThan(2);

      await select(page, shapes(page).nth(1));
      await page.keyboard.press('Delete');
      await page.waitForTimeout(200);
      expect(await drawOrder(page), 'the delete should change the scene').not.toEqual(before);

      await page.keyboard.press('Control+z');
      await page.waitForTimeout(250);
      expect(await drawOrder(page), 'undo should restore the order, not append').toEqual(before);
    });

    test('Escape closes the context menu', async ({ page }) => {
      await shapes(page).first().click({ button: 'right', force: true });
      const menu = page.locator('[data-context-menu]');
      await expect(menu).toBeVisible();

      await page.keyboard.press('Escape');
      await expect(menu, 'Escape should close the menu, not just deselect').toHaveCount(0);
    });

    test('the keyboard still works right after using the context menu', async ({ page }) => {
      // 項目のボタンは押すと DOM から消えるので、フォーカスが外に落ちやすい。
      // 落ちると keydown がエディタまで上がってこず、以後キーが死ぬ。
      const before = await everything(page).count();

      await shapes(page).first().click({ button: 'right', force: true });
      const remove = page.locator('[data-context-menu] button:has-text("Delete")').first();
      await expect(remove).toBeVisible();
      await remove.click();
      await page.waitForTimeout(200);
      expect(await everything(page).count()).toBeLessThan(before);

      // キャンバスを触らずにそのまま Ctrl+Z
      await page.keyboard.press('Control+z');
      await page.waitForTimeout(300);
      expect(await everything(page).count(), 'undo should work without clicking the canvas first').toBe(before);
    });

    test('Ctrl+Shift+Z redoes what Ctrl+Z undid', async ({ page }) => {
      const rect = shapes(page).first();
      await select(page, rect);
      const x0 = await num(rect, 'x');

      await page.keyboard.press('ArrowRight');
      await page.waitForTimeout(200);
      const moved = await num(rect, 'x');
      // 先に動いていないと、以降の比較が全部 x0 同士になって何も検査しない
      expect(moved, 'the arrow should have moved it first').not.toBe(x0);

      await page.keyboard.press('Control+z');
      await page.waitForTimeout(200);
      expect(await num(rect, 'x')).toBe(x0);

      await page.keyboard.press('Control+Shift+z');
      await page.waitForTimeout(200);
      expect(await num(rect, 'x'), 'redo should put it back where undo took it from').toBe(moved);
    });
  });
}

test.describe('the fullscreen modal', () => {
  const modalCanvas = (page: Page) => page.locator('div[style*="position: fixed"] svg[width="100%"]');

  for (const mode of MODES.filter((m) => m.hasModal)) {
    test(`${mode.name}: reopening it does not multiply the arrow step`, async ({ page }) => {
      // モーダルはかつて開くたびに window へ keydown を足していて、外す口が
      // 無かった。二回目は 2 歩、三回目は 3 歩動く。閉じても残る。
      await openEditor(page, mode);
      const outside = shapes(page).first();

      for (const round of [1, 2, 3]) {
        await page.locator('button[aria-label="Edit in fullscreen"]').click();
        await expect(page.locator('button[aria-label="Close"]')).toBeVisible();

        await modalCanvas(page).locator('rect[data-id][cursor="move"]').first().click({ force: true });
        await page.waitForTimeout(150);

        const x0 = await num(outside, 'x');
        await page.keyboard.press('ArrowRight');
        await page.waitForTimeout(200);
        expect(await num(outside, 'x'), `open #${round} should still move it one step`).toBe(x0 + 5);

        await page.keyboard.press('Escape');
        await expect(page.locator('button[aria-label="Close"]')).not.toBeVisible();
      }

      // 閉じたあとも、残骸が効いて二重に動いたりしないこと
      await select(page, outside);
      const x = await num(outside, 'x');
      await page.keyboard.press('ArrowRight');
      await page.waitForTimeout(200);
      expect(await num(outside, 'x'), 'after closing, one press is still one step').toBe(x + 5);
    });
  }
});

test.describe('the shells draw the same thing', () => {
  test.use({ permissions: ['clipboard-read', 'clipboard-write'] });

  const exportable = MODES.filter((m) => m.exportSvg);

  /** 各モードを開いて、操作してから SVG を取り出す */
  async function drawingOf(page: Page, mode: Mode, act?: (page: Page) => Promise<void>) {
    await openEditor(page, mode);
    if (act) await act(page);
    return shapeLines(await mode.exportSvg!(page));
  }

  test('the starting scene is identical in both', async ({ page }) => {
    const [standalone, embed] = exportable;
    const a = await drawingOf(page, standalone);
    const b = await drawingOf(page, embed);

    expect(a.length, 'the sample scene should not be empty').toBeGreaterThan(0);
    expect(b, 'the same scene should come out of both shells').toEqual(a);
  });

  test('the same edit lands the same way in both', async ({ page }) => {
    // 座標の変換を挟まずに済む操作を選ぶ。キャンバスの寸法がモードで違うので、
    // ピクセルで測るドラッグでは「同じ操作」にならない。
    const remove = async (page: Page) => {
      await shapes(page).first().click({ button: 'right', force: true });
      const button = page.locator('[data-context-menu] button:has-text("Delete")').first();
      await expect(button).toBeVisible();
      await button.click();
      await page.waitForTimeout(200);
    };

    const [standalone, embed] = exportable;
    const a = await drawingOf(page, standalone, remove);
    const b = await drawingOf(page, embed, remove);

    expect(b, 'deleting the first shape should leave both with the same drawing').toEqual(a);
  });
});
