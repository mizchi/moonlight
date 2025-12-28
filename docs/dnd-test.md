# Drag and Drop テスト手法

このプロジェクトでは SVG エディタのドラッグ＆ドロップ操作を E2E テストする必要がある。Puppeteer と Playwright の両方のアプローチをまとめる。

## Puppeteer

### Mouse.dragAndDrop()

一括でドラッグ＆ドロップを実行するメソッド。

```typescript
await page.mouse.dragAndDrop(
  { x: startX, y: startY },
  { x: targetX, y: targetY },
  { delay: 100 }  // dragover と drop の間の待機時間（ms）
);
```

**パラメータ:**
- `start: Point` - ドラッグ開始座標
- `target: Point` - ドロップ先座標
- `options.delay?: number` - dragover と drop 間のディレイ（デフォルト: 0）

**実行シーケンス:**
1. `drag` イベント発火
2. `dragenter` イベント発火
3. `dragover` イベント発火
4. `drop` イベント発火

### 個別メソッドによる細かい制御

```typescript
// ドラッグ開始（DragData を返す）
const dragData = await page.mouse.drag(
  { x: startX, y: startY },
  { x: targetX, y: targetY }
);

// ドロップ実行
await page.mouse.drop({ x: targetX, y: targetY }, dragData);
```

### mousedown/move/up による低レベル制御

```typescript
await page.mouse.move(startX, startY);
await page.mouse.down();
await page.mouse.move(targetX, targetY, { steps: 10 });  // 段階的に移動
await page.mouse.up();
```

**steps オプション:** 移動を複数ステップに分割し、中間の mousemove イベントを発火

## Playwright

### locator.dragTo()

```typescript
await page.locator('#item-to-be-dragged').dragTo(page.locator('#item-to-drop-at'));
```

**実行シーケンス:**
1. ドラッグ対象要素にホバー
2. マウス左ボタンを押下
3. ドロップ先要素に移動
4. マウス左ボタンを解放

### 手動制御

```typescript
await page.locator('#item-to-be-dragged').hover();
await page.mouse.down();
await page.locator('#item-to-drop-at').hover();
await page.mouse.up();
```

### dragover イベントの注意点

`dragover` イベントに依存するページでは、全ブラウザで確実にイベントを発火させるために**少なくとも 2 回の mousemove** が必要。

```typescript
await page.locator('#item-to-be-dragged').hover();
await page.mouse.down();
await page.locator('#item-to-drop-at').hover();
await page.locator('#item-to-drop-at').hover();  // 2回目
await page.mouse.up();
```

## SVG 座標系でのテスト

SVG エディタでは viewBox によるスケーリングがあるため、スクリーン座標と SVG 座標の変換が必要。

```typescript
// SVG 要素の位置とサイズを取得
const svg = await page.$('#editor svg');
const box = await svg.boundingBox();

// SVG 内の座標をスクリーン座標に変換
function svgToScreen(svgX: number, svgY: number, viewBox: string, box: BoundingBox) {
  const [vbX, vbY, vbW, vbH] = viewBox.split(' ').map(Number);
  const scaleX = box.width / vbW;
  const scaleY = box.height / vbH;
  return {
    x: box.x + (svgX - vbX) * scaleX,
    y: box.y + (svgY - vbY) * scaleY
  };
}

// 使用例: SVG 座標 (100, 50) から (200, 150) へドラッグ
const start = svgToScreen(100, 50, '0 0 600 400', box);
const end = svgToScreen(200, 150, '0 0 600 400', box);
await page.mouse.dragAndDrop(start, end);
```

## テスト例

```typescript
import { test, expect } from '@playwright/test';

test('要素をドラッグして移動', async ({ page }) => {
  await page.goto('/embed.html');

  // エディタの初期化を待つ
  await page.waitForSelector('#editor svg');

  // 要素の初期位置を取得
  const element = page.locator('[data-id="el-1"]');
  const initialBox = await element.boundingBox();

  // ドラッグ操作
  await element.hover();
  await page.mouse.down();
  await page.mouse.move(initialBox.x + 100, initialBox.y + 50, { steps: 5 });
  await page.mouse.up();

  // 移動後の位置を検証
  const finalBox = await element.boundingBox();
  expect(finalBox.x).toBeCloseTo(initialBox.x + 100, 0);
  expect(finalBox.y).toBeCloseTo(initialBox.y + 50, 0);
});
```

## 参考リンク

- [Puppeteer Mouse.dragAndDrop](https://pptr.dev/api/puppeteer.mouse.draganddrop)
- [Puppeteer Mouse.drag](https://pptr.dev/api/puppeteer.mouse.drag)
- [Puppeteer Mouse.drop](https://pptr.dev/api/puppeteer.mouse.drop)
- [Playwright Drag and Drop](https://playwright.dev/docs/input#drag-and-drop)
