# モバイルタッチイベント対応提案

## 現状

Moonlight は現在 `mousedown`, `mousemove`, `mouseup` のみを使用しており、モバイルデバイスでは動作しない。

### 現在の実装箇所
- `src/main.mbt`: `create_mousedown_handler`, `create_mousemove_handler`, `create_mouseup_handler`
- `src/render.mbt`: SVG コンテナに `mousedown`, `mousemove`, `mouseup` をバインド
- `src/lib/interaction.mbt`: FFI で `addEventListener('mousedown', ...)` 等を使用

## Luna のサポート状況

Luna は既にタッチ/ポインターイベントをサポートしている:

### イベントハンドラ型 (`luna/dom/element/event_handlers.mbt`)
```moonbit
pub type TouchEventHandler[T] = (@js_dom.TouchEvent) -> Unit
pub type PointerEventHandler[T] = (@js_dom.PointerEvent) -> Unit
pub type TouchHandler = (@js_dom.TouchEvent) -> Unit
pub type PointerHandler = (@js_dom.PointerEvent) -> Unit
```

### DSL 関数 (`luna/dom/element/dsl.mbt`)
```moonbit
// Touch events
HandlerMap::touchstart(self, handler)
HandlerMap::touchmove(self, handler)
HandlerMap::touchend(self, handler)
HandlerMap::touchcancel(self, handler)

// Pointer events (unified mouse/touch/pen)
HandlerMap::pointerdown(self, handler)
HandlerMap::pointermove(self, handler)
HandlerMap::pointerup(self, handler)
HandlerMap::pointercancel(self, handler)
HandlerMap::pointerenter(self, handler)
HandlerMap::pointerleave(self, handler)
```

### JS ユーティリティ (`luna/js/luna/src/event-utils.ts`)
```typescript
// マウス/ポインター/タッチイベントから座標を取得
function getClientPos(e: MouseEvent | PointerEvent | TouchEvent): { x, y }
function getPagePos(e: MouseEvent | PointerEvent | TouchEvent): { x, y }
```

## 提案: Pointer Events への移行

### 理由
1. **統一されたAPI**: マウス、タッチ、ペン入力を単一のイベントで処理
2. **シンプル**: Touch + Mouse の両方を処理する必要がない
3. **広いブラウザサポート**: 主要ブラウザ全てでサポート
4. **追加機能**: `pointerId` でマルチタッチ、`pressure` で筆圧検知が可能

### 変更内容

#### 1. イベント名の変更
| 現在 | 変更後 |
|------|--------|
| `mousedown` | `pointerdown` |
| `mousemove` | `pointermove` |
| `mouseup` | `pointerup` |
| - | `pointercancel` (新規) |

#### 2. 座標取得の統一
現在の `clientX`/`clientY` はそのまま使用可能（PointerEvent は MouseEvent を継承）

#### 3. タッチ固有の考慮事項
- **touch-action CSS**: スクロール/ズームとの競合を防ぐ
  ```css
  svg { touch-action: none; }
  ```
- **pointercancel**: タッチがキャンセルされた場合の処理
- **マルチタッチ**: 必要に応じて `pointerId` で識別

### 実装ステップ

#### Phase 1: 基本対応（最小限の変更）
1. `src/render.mbt` のイベント名を変更
2. `src/main.mbt` のハンドラ関数名を変更
3. `src/lib/interaction.mbt` の FFI を更新
4. SVG に `touch-action: none` を追加

#### Phase 2: ジェスチャー対応（オプション）
1. ピンチズーム（2本指でズーム）
2. パン（2本指でスクロール）
3. ダブルタップ（ダブルクリック相当）

### コード例

#### Before (mouse events)
```moonbit
pub extern "js" fn add_mousedown_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) -> Unit =
  #| (svg, handler) => svg.addEventListener('mousedown', handler)
```

#### After (pointer events)
```moonbit
pub extern "js" fn add_pointerdown_handler(
  svg : @js.Any,
  handler : (@js.Any) -> Unit,
) -> Unit =
  #| (svg, handler) => svg.addEventListener('pointerdown', handler)
```

#### SVG コンテナ
```moonbit
// touch-action: none を追加してブラウザのデフォルト動作を無効化
attrs.push(("style", "... touch-action: none; ..."))
```

## 影響範囲

### 変更が必要なファイル
- `src/main.mbt` - ハンドラ作成関数 (約50行)
- `src/render.mbt` - SVG コンテナ (約10行)
- `src/lib/interaction.mbt` - FFI 関数 (約20行)

### テスト項目
- [ ] デスクトップ: マウスでの描画・選択・移動
- [ ] モバイル: タッチでの描画・選択・移動
- [ ] タブレット: ペン入力（対応デバイスがあれば）
- [ ] ダブルタップ/ダブルクリックでのテキスト編集

## 代替案

### Touch Events + Mouse Events の併用
```javascript
svg.addEventListener('mousedown', handler)
svg.addEventListener('touchstart', (e) => {
  e.preventDefault()
  handler(e.touches[0])
})
```
- デメリット: コードの重複、両方のイベントが発火する問題

### 結論
**Pointer Events への移行を推奨**。Luna が既にサポートしており、最小限の変更で対応可能。
