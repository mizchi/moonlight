import { test, expect, type Page, type Locator } from '@playwright/test';

/**
 * 同じ操作を、スタンドアロンと埋め込みの両方で回す。
 *
 * 二つのモードは同じ中核（create_js_editor）を通るが、外側のシェルは別物で、
 * ツールバーもキーボードの配線も違う。片方で直したつもりが他方で崩れる、という
 * 事故が起きうるので、操作の集合をひとつ書いて両方に適用する。
 *
 * 行が片方だけ落ちたら、それは「そのモードのシェルの配線が抜けている」という
 * 意味になる。
 */

type Mode = {
  name: string;
  url: string;
  /**
   * キーボードがどこまで繋がっているか。
   *
   * 埋め込みは @lib.setup_keyboard_handler だけを繋ぐので delete / escape /
   * 図形追加しか通らない。矢印・undo・複製はスタンドアロン専用シェル
   * editor_app() の setup_keyboard_listener / setup_keyboard_shortcuts 側にある。
   */
  keyboard: 'full' | 'delete-only';
  /** そのモードでの SVG の取り出し方（口がモードごとに違う） */
  exportSvg: (page: Page) => Promise<string>;
};

const MODES: Mode[] = [
  {
    name: 'standalone',
    url: '/',
    keyboard: 'full',
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
    keyboard: 'delete-only',
    exportSvg: (page) =>
      page.evaluate(() => (window as unknown as { editor: { exportSvg(): string } }).editor.exportSvg()),
  },
];

/** 書き出した SVG から図形の行だけを取り出す（キャンバス寸法はモードごとに違う） */
function shapeLines(svg: string): string[] {
  return svg
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.includes('data-id='));
}

// --- 両モード共通のヘルパー（既存スイートと同じ作法） ---

const shapes = (page: Page) => page.locator('svg rect[data-id][cursor="move"]');
const handles = (page: Page) => page.locator('svg [data-handle]');
const canvas = (page: Page) => page.locator('svg[viewBox]').first();

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
      // 両モードが同じサンプルを載せていること。ここがずれると、以降の
      // 比較がモードの違いではなく初期状態の違いになってしまう。
      await expect(shapes(page)).toHaveCount(4);
      await expect(page.locator('svg circle[data-id]')).toHaveCount(1);
      await expect(page.locator('svg ellipse[data-id]')).toHaveCount(1);
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
        await openEditor(page, mode);
        const rect = shapes(page).first();
        await select(page, rect);

        const handle = page.locator(`svg rect[data-handle="${corner}"]`).first();
        await expect(handle, `${corner} handle should be there`).toBeVisible();

        const [w0, h0] = [await num(rect, 'width'), await num(rect, 'height')];
        const pull = corner === 'se' ? [40, 30] : corner === 'nw' ? [-40, -30] : corner === 'ne' ? [40, -30] : [-40, 30];
        await dragBy(page, await centerOf(handle), pull[0], pull[1]);

        const [w1, h1] = [await num(rect, 'width'), await num(rect, 'height')];
        expect(w1 !== w0 || h1 !== h0, `${corner} should change the size`).toBe(true);
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
      const before = await page.locator('svg [data-id]').count();

      await shapes(page).first().click({ button: 'right', force: true });
      const remove = page.locator('[data-context-menu] button:has-text("Delete")').first();
      await expect(remove).toBeVisible();
      await remove.click();
      await page.waitForTimeout(200);

      expect(await page.locator('svg [data-id]').count()).toBeLessThan(before);
    });

    test('the Delete key removes the selection', async ({ page }) => {
      const before = await page.locator('svg [data-id]').count();

      await select(page, shapes(page).first());
      await page.keyboard.press('Delete');
      await page.waitForTimeout(200);

      expect(await page.locator('svg [data-id]').count()).toBeLessThan(before);
    });

    test('arrow keys nudge the selection', async ({ page }) => {
      test.skip(
        mode.keyboard !== 'full',
        'embed does not bind arrows: lib/keyboard.mbt defers them to the global handler that only editor_app() installs',
      );
      const rect = shapes(page).first();
      await select(page, rect);

      const x0 = await num(rect, 'x');
      await page.keyboard.press('ArrowRight');
      await page.waitForTimeout(200);

      expect(await num(rect, 'x')).not.toBe(x0);
    });

    test('a drag can be undone', async ({ page }) => {
      test.skip(
        mode.keyboard !== 'full',
        'embed does not bind undo: setup_keyboard_shortcuts is only called from editor_app()',
      );
      const rect = shapes(page).first();
      const x0 = await num(rect, 'x');

      await dragBy(page, await centerOf(rect), 80, 60);
      expect(await num(rect, 'x')).not.toBe(x0);

      await page.keyboard.press('Control+z');
      await page.waitForTimeout(250);
      expect(await num(rect, 'x'), 'undo should put it back').toBe(x0);
    });
  });
}

test.describe('the two modes draw the same thing', () => {
  test.use({ permissions: ['clipboard-read', 'clipboard-write'] });

  /** 各モードを開いて、操作してから SVG を取り出す */
  async function drawingOf(page: Page, mode: Mode, act?: (page: Page) => Promise<void>) {
    await openEditor(page, mode);
    if (act) await act(page);
    return shapeLines(await mode.exportSvg(page));
  }

  test('the starting scene is identical in both', async ({ page }) => {
    const [standalone, embed] = MODES;
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

    const [standalone, embed] = MODES;
    const a = await drawingOf(page, standalone, remove);
    const b = await drawingOf(page, embed, remove);

    expect(b, 'deleting the first shape should leave both with the same drawing').toEqual(a);
  });
});
