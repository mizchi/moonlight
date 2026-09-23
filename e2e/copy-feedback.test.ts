import { test, expect, type Page } from '@playwright/test';
import { PNG } from 'pngjs';
import {
  createReviewer,
  isVlmConfigured,
  positiveMs,
  reviewClaims,
  reviewerName,
  VLM_SKIP_REASON,
} from './vlm-reviewer';

/**
 * コピーしたときの知らせ（src/ui.mbt の render_notice）のテスト。
 *
 * クリップボードは目に見えないので、写せたのか、写せなかったのかを画面の下に
 * 短く出す。SVG のテキスト（Ctrl+Shift+C とツールバーの Copy SVG）も、要素の
 * コピー（Ctrl+C）も、三つの殻すべてで知らせる。
 */

const SHELLS = [
  { name: 'standalone', url: '/', hasModal: false },
  { name: 'embed', url: '/examples/embed.html', hasModal: true },
  { name: 'embed-url', url: '/?mode=embed', hasModal: true },
];

const COPIED_SVG = 'Copied SVG to the clipboard';
const BLOCKED = 'Could not copy: the browser blocked clipboard access';

const notice = (page: Page) => page.locator('[data-notice]');
/** 知らせの本体（出ているときだけある） */
const toast = (page: Page) => notice(page).locator('div');
const canvas = (page: Page) => page.locator('svg[viewBox]').first();
const shapes = (page: Page) => canvas(page).locator('rect[data-id][cursor="move"]');

async function open(page: Page, url: string) {
  await page.goto(url);
  await expect(shapes(page).first()).toBeVisible();
  await page.waitForTimeout(200);
  // 埋め込みの殻はキャンバスにフォーカスがあるときだけキーを受ける
  const box = (await canvas(page).boundingBox())!;
  await page.mouse.click(box.x + 6, box.y + 6);
  await page.waitForTimeout(100);
}

/** 画面の 1 ピクセルの色 */
async function pixel(page: Page, x: number, y: number) {
  const png = PNG.sync.read(await page.screenshot({ clip: { x: Math.round(x), y: Math.round(y), width: 1, height: 1 } }));
  return { r: png.data[0], g: png.data[1], b: png.data[2] };
}

test.use({ permissions: ['clipboard-read', 'clipboard-write'] });

for (const shell of SHELLS) {
  test.describe(`${shell.name}: copy feedback`, () => {
    test.beforeEach(async ({ page }) => {
      await open(page, shell.url);
    });

    test('nothing is shown before anything is copied', async ({ page }) => {
      await expect(notice(page)).toHaveAttribute('role', 'status');
      await expect(toast(page)).toHaveCount(0);
      // 知らせが無いあいだ、領域は大きさを持たない（キャンバスに見えない板を残さない）
      const box = await notice(page).boundingBox();
      expect(box === null || box.height === 0, 'the empty notice area should take no space').toBe(true);
    });

    test('Ctrl+Shift+C copies the SVG and says so, then the notice goes away', async ({ page }) => {
      await page.keyboard.press('Control+Shift+KeyC');
      await expect(notice(page)).toHaveText(COPIED_SVG);
      await expect(toast(page)).toBeVisible();

      const svg = await page.evaluate(() => navigator.clipboard.readText());
      expect(svg, 'the clipboard should hold the SVG').toContain('data-moonlight');

      // 画面の中に収まっている
      const box = (await toast(page).boundingBox())!;
      const viewport = page.viewportSize()!;
      expect(box.x).toBeGreaterThanOrEqual(0);
      expect(box.x + box.width).toBeLessThanOrEqual(viewport.width);
      expect(box.y + box.height).toBeLessThanOrEqual(viewport.height);

      await expect(toast(page), 'the notice should disappear by itself').toHaveCount(0, { timeout: 5000 });
    });

    test('Ctrl+C says how many elements it took', async ({ page }) => {
      await shapes(page).first().click({ force: true });
      await page.waitForTimeout(120);
      await page.keyboard.press('Control+c');
      await expect(notice(page)).toHaveText('Copied 1 element');

      await page.keyboard.press('Control+a');
      await page.keyboard.press('Control+c');
      await expect(notice(page)).toHaveText(/^Copied \d+ elements$/);
    });

    test('when the browser refuses, the notice says so in red', async ({ page }) => {
      await page.evaluate(() => {
        (navigator.clipboard as unknown as { writeText: () => Promise<void> }).writeText = () =>
          Promise.reject(new DOMException('denied', 'NotAllowedError'));
      });
      await page.keyboard.press('Control+Shift+KeyC');
      await expect(notice(page)).toHaveText(BLOCKED);
      await expect(toast(page)).toHaveCSS('background-color', 'rgb(185, 28, 28)');
    });

    if (shell.hasModal) {
      test('in the fullscreen editor the notice shows on top of the modal, above its toolbar', async ({ page }) => {
        await page.locator('button[aria-label="Edit in fullscreen"]').click();
        await expect(page.locator('button[aria-label="Close"]')).toBeVisible();

        const copy = page.getByRole('button', { name: 'Copy SVG (Ctrl+Shift+C)' });
        await copy.click();
        await expect(notice(page)).toHaveText(COPIED_SVG);

        // 左の余白の色が知らせの地の色そのまま（モーダルの暗幕の下なら暗くなる）
        const box = (await toast(page).boundingBox())!;
        const { r, g, b } = await pixel(page, box.x + 5, box.y + box.height / 2);
        const [er, eg, eb] = [0x1f, 0x29, 0x37];
        expect(
          Math.abs(r - er) + Math.abs(g - eg) + Math.abs(b - eb),
          `the notice should be painted on top (got rgb(${r}, ${g}, ${b}))`,
        ).toBeLessThanOrEqual(12);

        // ツールバーより上に出る。下に出すと、押したボタンのツールチップ（ボタンの
        // 下に出る）に隠れて読めない
        const button = (await copy.boundingBox())!;
        expect(box.y + box.height, 'the notice should sit above the toolbar of the modal').toBeLessThanOrEqual(button.y);
      });
    }
  });
}

test.describe('standalone: copy feedback details', () => {
  test.beforeEach(async ({ page }) => {
    await open(page, '/');
  });

  test('the Copy SVG button in the toolbar says so too', async ({ page }) => {
    await page.getByRole('button', { name: 'Copy SVG (Ctrl+Shift+C)' }).click();
    await expect(notice(page)).toHaveText(COPIED_SVG);
  });

  test('a later notice is not cut short by the timer of an earlier one', async ({ page }) => {
    await shapes(page).first().click({ force: true });
    await page.waitForTimeout(120);
    await page.keyboard.press('Control+c');
    await expect(notice(page)).toHaveText('Copied 1 element');

    await page.waitForTimeout(1500);
    await page.keyboard.press('Control+Shift+KeyC');
    await expect(notice(page)).toHaveText(COPIED_SVG);

    // 最初の知らせのタイマー（2.2 秒）が過ぎても、後の知らせは残っている
    await page.waitForTimeout(1000);
    expect(await notice(page).textContent()).toBe(COPIED_SVG);
    await expect(toast(page)).toHaveCount(0, { timeout: 5000 });
  });

  test('the notice does not block clicks under it', async ({ page }) => {
    await page.keyboard.press('Control+Shift+KeyC');
    await expect(toast(page)).toBeVisible();
    const box = (await toast(page).boundingBox())!;
    const hit = await page.evaluate(
      ({ x, y }) => {
        const el = document.elementFromPoint(x, y);
        return el ? el.closest('[data-notice]') === null : false;
      },
      { x: box.x + box.width / 2, y: box.y + box.height / 2 },
    );
    expect(hit, 'a click on the notice should reach what is under it').toBe(true);
  });
});

test.describe('copy feedback — what the notice looks like (vlmkit)', () => {
  test.skip(!isVlmConfigured(), VLM_SKIP_REASON);
  test.setTimeout(positiveMs(process.env.VLMKIT_TEST_TIMEOUT_MS, 900_000));

  /** 知らせは 2.2 秒で消えるので、出ているうちに撮った一枚を判定役に見せる */
  async function shotWithNotice(page: Page, act: () => Promise<void>) {
    await act();
    await expect(toast(page)).toBeVisible();
    const image = await page.screenshot();
    return { screenshot: async () => image };
  }

  test('the notice is easy to read and covers nothing it should not', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    console.log(`[vlmkit] reviewer: ${reviewerName()}`);
    const reviewer = createReviewer();
    const failures: string[] = [];

    await open(page, '/');
    const copied = await shotWithNotice(page, () => page.keyboard.press('Control+Shift+KeyC'));
    failures.push(
      ...(await reviewClaims(
        [
          'Near the bottom center of the screen, below the white document, a small dark message says "Copied SVG to the clipboard", and its text is easy to read.',
          'The message at the bottom does not cover any part of the white document or of the drawing on it.',
        ],
        copied,
        reviewer,
      )),
    );

    await page.waitForTimeout(2600);
    await page.evaluate(() => {
      (navigator.clipboard as unknown as { writeText: () => Promise<void> }).writeText = () =>
        Promise.reject(new DOMException('denied', 'NotAllowedError'));
    });
    const blocked = await shotWithNotice(page, () => page.keyboard.press('Control+Shift+KeyC'));
    failures.push(
      ...(await reviewClaims(
        ['Near the bottom center of the screen, a red message says that copying failed because the browser blocked clipboard access; its text is easy to read.'],
        blocked,
        reviewer,
      )),
    );

    await open(page, '/examples/embed.html');
    await page.locator('button[aria-label="Edit in fullscreen"]').click();
    await expect(page.locator('button[aria-label="Close"]')).toBeVisible();
    const copy = page.getByRole('button', { name: 'Copy SVG (Ctrl+Shift+C)' });
    const inModal = await shotWithNotice(page, () => copy.click());
    failures.push(
      ...(await reviewClaims(
        ['Inside the editor dialog, just above its bottom toolbar, a small dark message says "Copied SVG to the clipboard"; every word of it is visible, and no tooltip or other element covers it.'],
        inModal,
        reviewer,
      )),
    );

    expect(failures, `the notice does not look as it should:\n${failures.join('\n')}`).toEqual([]);
  });
});
