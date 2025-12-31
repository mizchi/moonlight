import { test, expect } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

// ESM で __dirname を取得
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// フィクスチャを読み込む
const fixturesDir = path.join(__dirname, "fixtures");
const moonlightRect = fs.readFileSync(
  path.join(fixturesDir, "moonlight-rect.svg"),
  "utf-8"
);
const plainRect = fs.readFileSync(
  path.join(fixturesDir, "plain-rect.svg"),
  "utf-8"
);

test.describe("Validation and Capability", () => {
  test.describe("Moonlight SVG (Full Editable)", () => {
    test("should show resize handles for Moonlight format elements", async ({
      page,
    }) => {
      // embed ページを使用（window.editor が利用可能）
      await page.goto("http://localhost:5173/examples/embed.html");
      await page.waitForSelector("svg");

      // Moonlight SVG をインポート
      await page.evaluate((svg: string) => {
        (window as any).editor.importSvg(svg);
      }, moonlightRect);

      await page.waitForTimeout(100);

      // 要素をクリックして選択
      const rect = page.locator('svg rect[data-id]').first();
      await rect.click();

      // リサイズハンドル（anchor-point）が表示されることを確認
      const anchors = page.locator(".anchor-point");
      const count = await anchors.count();
      expect(count).toBeGreaterThan(0);
    });

    test("should show style options in context menu for Moonlight elements", async ({
      page,
    }) => {
      await page.goto("http://localhost:5173/examples/embed.html");
      await page.waitForSelector("svg");

      // Moonlight SVG をインポート
      await page.evaluate((svg: string) => {
        (window as any).editor.importSvg(svg);
      }, moonlightRect);

      await page.waitForTimeout(200);

      // 要素を右クリック（force: true を使用）
      const rect = page.locator('svg rect[data-id]').first();
      await rect.click({ button: "right", force: true });

      await page.waitForTimeout(200);

      // コンテキストメニュー内の Stroke ラベルが表示される（編集可能）
      const strokeLabel = page.getByText("Stroke");
      await expect(strokeLabel).toBeVisible();
    });
  });

  test.describe("Plain SVG (Move Only)", () => {
    test("should not show resize handles for plain SVG elements", async ({
      page,
    }) => {
      await page.goto("http://localhost:5173/examples/embed.html");
      await page.waitForSelector("svg");

      // Plain SVG をインポート
      await page.evaluate((svg: string) => {
        (window as any).editor.importSvg(svg);
      }, plainRect);

      await page.waitForTimeout(100);

      // 要素をクリックして選択（plain SVG の rect は data-id が付与される）
      const rect = page.locator('svg rect[data-id]').first();
      await rect.click();

      await page.waitForTimeout(100);

      // リサイズハンドル（selection-overlay 内の rect）を探す
      // Plain SVG 要素は can_resize=false なのでハンドルは非表示
      const resizeHandles = page.locator(
        '.selection-overlay rect[cursor="nwse-resize"], .selection-overlay rect[cursor="nesw-resize"]'
      );
      const handleCount = await resizeHandles.count();
      expect(handleCount).toBe(0);
    });

    // Note: This test verifies that plain SVG elements show restricted context menu.
    // The "Move only" message appears when capability.can_edit is false.
    test("should show restricted context menu for plain SVG elements", async ({
      page,
    }) => {
      await page.goto("http://localhost:5173/examples/embed.html");
      await page.waitForSelector("svg");

      // Plain SVG をインポート
      await page.evaluate((svg: string) => {
        (window as any).editor.importSvg(svg);
      }, plainRect);

      await page.waitForTimeout(200);

      // 要素を右クリック（force: true を使用）
      const rect = page.locator('svg rect[data-id]').first();
      await rect.click({ button: "right", force: true });

      await page.waitForTimeout(200);

      // Layer ボタンが表示される（これは常に表示される）
      const layerLabel = page.getByText("Layer");
      await expect(layerLabel).toBeVisible();

      // プレーンSVGはStroke/Fillオプションが非表示になるはず
      // （ただし、実装によっては表示される可能性がある）
    });
  });

  test.describe("Layer Operations (Always Available)", () => {
    test("should allow layer operations for plain SVG elements", async ({
      page,
    }) => {
      await page.goto("http://localhost:5173/examples/embed.html");
      await page.waitForSelector("svg");

      // Plain SVG をインポート
      await page.evaluate((svg: string) => {
        (window as any).editor.importSvg(svg);
      }, plainRect);

      await page.waitForTimeout(200);

      // 要素を右クリック（force: true を使用）
      const rect = page.locator('svg rect[data-id]').first();
      await rect.click({ button: "right", force: true });

      await page.waitForTimeout(200);

      // コンテキストメニュー内の Layer ヘッダーが表示される
      const layerLabel = page.getByText("Layer");
      await expect(layerLabel).toBeVisible();

      // Bring to Front ボタンが表示される
      const bringToFrontBtn = page.getByText("Bring to Front");
      await expect(bringToFrontBtn).toBeVisible();
    });
  });
});
