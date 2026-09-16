import { test, expect, type Page } from '@playwright/test';

/**
 * SVG のラウンドトリップ。
 *
 * このプロジェクトは「可読な再編集可能 SVG」を基盤に置いているので、
 *   - 読み込めるはずのものが読み込めているか
 *   - 書き出したものを読み直して同じに戻るか
 *   - 書き出したものが、エディタの外でも同じ絵に見えるか
 * の三つが崩れると土台が崩れる。ここはその三つを押さえるためのテスト。
 */

const HARNESS = '/e2e/fixtures/scene-harness.html';

type Editor = {
  importSvg(svg: string): boolean;
  exportSvg(): string;
  getElements(): Array<{ id: string }>;
};

const wrap = (body: string, w = 200, h = 140) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;

async function openHarness(page: Page) {
  await page.goto(HARNESS);
  await page.waitForSelector('body[data-harness-ready="1"]');
}

/** 読み込ませて、そのまま書き出す */
async function importThenExport(page: Page, svg: string) {
  return page.evaluate((s) => {
    const ed = (window as unknown as { harness: { editor: Editor } }).harness.editor;
    const ok = ed.importSvg(s);
    return { ok, svg: ed.exportSvg(), count: ed.getElements().length };
  }, svg);
}

/** 書き出した SVG のうち、図形の行だけを取り出す */
function shapeLines(svg: string): string[] {
  return svg
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.includes('data-id='));
}

test.describe('SVG round-trip', () => {
  test.beforeEach(async ({ page }) => {
    await openHarness(page);
  });

  test('shapes inside a <g> come in', async ({ page }) => {
    // デザインツールの書き出しは中身がほぼ必ず <g> に入っている。
    // 素の図形と同じ数だけ入らないと、読み込んでも何も起きないことになる。
    const flat = await importThenExport(
      page,
      wrap('<rect x="10" y="10" width="50" height="30"/><circle cx="120" cy="30" r="18"/>'),
    );
    expect(flat.count).toBe(2);

    await openHarness(page);
    const grouped = await importThenExport(
      page,
      wrap('<g><rect x="10" y="10" width="50" height="30"/><circle cx="120" cy="30" r="18"/></g>'),
    );
    expect(grouped.ok).toBe(true);
    expect(grouped.count).toBe(2);
  });

  test('nested groups are followed all the way down', async ({ page }) => {
    const r = await importThenExport(
      page,
      wrap('<g><g><g><rect x="10" y="10" width="50" height="30"/></g><circle cx="120" cy="30" r="18"/></g></g>'),
    );
    expect(r.count).toBe(2);
  });

  test("a group's transform reaches the shapes inside it", async ({ page }) => {
    const r = await importThenExport(
      page,
      wrap('<g transform="translate(20,10)"><rect x="10" y="10" width="50" height="30"/></g>'),
    );
    expect(r.count).toBe(1);
    expect(shapeLines(r.svg)[0]).toContain('transform="translate(20,10)"');
  });

  test('nested group transforms are composed, not dropped', async ({ page }) => {
    const r = await importThenExport(
      page,
      wrap('<g transform="translate(20,10)"><g transform="rotate(15)"><rect x="10" y="10" width="50" height="30"/></g></g>'),
    );
    expect(shapeLines(r.svg)[0]).toContain('transform="translate(20,10) rotate(15)"');
  });

  test("an element's own transform survives", async ({ page }) => {
    const r = await importThenExport(
      page,
      wrap('<rect x="10" y="10" width="50" height="30" transform="translate(20,10)"/>'),
    );
    expect(shapeLines(r.svg)[0]).toContain('transform="translate(20,10)"');
  });

  test('geometry and style are unchanged by a round-trip', async ({ page }) => {
    const cases: Record<string, string> = {
      rect: wrap('<rect x="10" y="10" width="80" height="40" fill="#ff0000"/>'),
      'rect rounded': wrap('<rect x="10" y="10" width="80" height="40" rx="6" ry="6" fill="#00aa00"/>'),
      circle: wrap('<circle cx="60" cy="60" r="25" fill="#0000ff"/>'),
      ellipse: wrap('<ellipse cx="80" cy="50" rx="40" ry="20" fill="#aa00aa"/>'),
      line: wrap('<line x1="10" y1="10" x2="150" y2="90" stroke="#000000" stroke-width="2"/>'),
      polyline: wrap('<polyline points="10,10 60,60 120,20" fill="none" stroke="#333333"/>'),
      path: wrap('<path d="M10 10 L60 60 L120 10" fill="none" stroke="#333333"/>'),
      text: wrap('<text x="20" y="40" font-size="16">Hello</text>'),
      styled: wrap('<rect x="5" y="5" width="60" height="30" fill="#aabbcc" stroke="#112233" stroke-width="3" opacity="0.5"/>'),
    };

    for (const [name, input] of Object.entries(cases)) {
      await openHarness(page);
      const first = await importThenExport(page, input);
      expect(first.count, `${name} should import`).toBe(1);

      // 書き出したものを、まっさらな状態から読み直す
      await openHarness(page);
      const second = await importThenExport(page, first.svg);

      expect(second.count, `${name} should survive the round-trip`).toBe(1);
      // data-id を含めて同じであること。id が毎回ずれると、中身が同じでも
      // 保存するたびに差分が出る。
      expect(shapeLines(second.svg), `${name} should come back byte for byte`).toEqual(
        shapeLines(first.svg),
      );
    }
  });

  test('an SVG that cannot be read is reported, and leaves the drawing alone', async ({ page }) => {
    const r = await page.evaluate(() => {
      const ed = (window as unknown as { harness: { editor: Editor } }).harness.editor;
      ed.importSvg('<svg xmlns="http://www.w3.org/2000/svg"><rect x="1" y="2" width="30" height="40"/></svg>');
      const before = ed.getElements().length;
      const broken = ed.importSvg('this is not an svg at all <<<');
      const empty = ed.importSvg('<svg xmlns="http://www.w3.org/2000/svg"></svg>');
      return { before, broken, empty, after: ed.getElements().length };
    });
    expect(r.before).toBe(1);
    expect(r.broken, 'a string that is not SVG must not look like a success').toBe(false);
    expect(r.empty, 'an SVG with no shape in it must not look like a success').toBe(false);
    expect(r.after, 'a failed import must not throw the drawing away').toBe(1);
  });
});

test.describe('the exported file stands on its own', () => {
  test.use({ permissions: ['clipboard-read', 'clipboard-write'] });

  test('nothing disappears when it is opened outside the editor', async ({ page }) => {
    // 既定スタイルの図形は色を CSS 変数で持っている。変数の定義はエディタの
    // <svg style> にしか無いので、フォールバックが無いと、ファイルとして開いた
    // ときに stroke が初期値の none に落ちて線が丸ごと消える。
    await page.goto('/');
    await expect(page.locator('svg rect[data-id][cursor="move"]')).toHaveCount(4);
    await page.keyboard.press('Control+Shift+KeyC'); // SVG をクリップボードへ
    await page.waitForTimeout(300);
    const svg = await page.evaluate(() => navigator.clipboard.readText());

    expect(svg).toContain('data-moonlight');
    // フォールバックの無い var(...) が残っていないこと
    expect(svg.match(/var\(--[a-z-]+\)/g) ?? [], 'every css variable needs a fallback').toEqual([]);

    // ただのページに置いて、実際に見えるかどうかを見る
    await page.setContent(`<!doctype html><body style="margin:0">${svg}</body>`);
    const invisible = await page.evaluate(() =>
      [...document.querySelectorAll('[data-id]')]
        .map((el) => {
          const cs = getComputedStyle(el);
          const noFill = cs.fill === 'none' || cs.fill === 'rgba(0, 0, 0, 0)';
          return { id: el.getAttribute('data-id'), tag: el.tagName, invisible: noFill && cs.stroke === 'none' };
        })
        .filter((e) => e.invisible),
    );
    expect(invisible, 'no shape may vanish outside the editor').toEqual([]);
  });
});
