# Moonlight を Markdown Editor に組み込む指示書

Luna ベースの Markdown Editor に Moonlight SVG エディタを組み込むためのガイド。

## 概要

Moonlight は以下の2つの組み込み方式を提供:

1. **JavaScript API (推奨)**: `MoonlightEditor.create()` で動的にエディタを生成
2. **WebComponent**: `<moonlight-editor>` カスタム要素として使用

Markdown Editor との統合では **JavaScript API** を推奨。理由:
- Luna の Signal システムと直接連携可能
- イベントコールバックで双方向同期が容易
- SVG のインポート/エクスポートが柔軟

---

## 1. 依存関係のセットアップ

### 1.1 MoonBit パッケージとして追加

```bash
moon add mizchi/moonlight
```

### 1.2 JavaScript エントリポイントで読み込み

```typescript
// editor.ts
import 'mbt:mizchi/moonlight/embed';
```

これにより `window.MoonlightEditor` がグローバルに登録される。

---

## 2. 基本的な組み込み

### 2.1 エディタの作成

```typescript
const container = document.getElementById('svg-editor');

const editor = MoonlightEditor.create(container, {
  width: 600,          // キャンバス幅 (px)
  height: 400,         // キャンバス高さ (px)
  docWidth: 600,       // SVG viewBox 幅
  docHeight: 400,      // SVG viewBox 高さ
  zoom: 1.0,           // 初期ズーム
  theme: 'light',      // 'light' | 'dark'
  readonly: false,     // 読み取り専用モード
  initialSvg: null,    // 初期 SVG 文字列 (オプション)
});
```

### 2.2 SVG のインポート/エクスポート

```typescript
// Markdown から抽出した SVG を読み込み
editor.importSvg(svgString);

// 編集結果を SVG として取得
const svg = editor.exportSvg();

// エディタをクリア
editor.clear();
```

---

## 3. Luna との統合パターン

### 3.1 Signal で SVG 状態を管理

```moonbit
// Markdown ドキュメント内の SVG を Signal で管理
let svg_content : @luna.Signal[String] = @luna.signal("")

// エディタから変更を受け取る
fn setup_editor_sync(editor : @js.Any) -> Unit {
  // 変更イベントを購読
  let _ = editor.onChange(fn() {
    let new_svg = editor.exportSvg()
    svg_content.set(new_svg)
  })

  // Signal 変更時にエディタを更新（双方向バインディング）
  let _ = @luna.effect(fn() {
    let svg = svg_content.get()
    if svg.length() > 0 {
      editor.importSvg(svg)
    }
  })
}
```

### 3.2 Markdown ブロックとして埋め込み

```moonbit
fn svg_block(svg_signal : @luna.Signal[String]) -> @luna.Node[@luna.DomEvent] {
  let container_ref : Ref[@js.Any?] = { val: None }
  let editor_ref : Ref[@js.Any?] = { val: None }

  // コンテナ div を作成
  let container = @element.div(
    id="svg-editor-container",
    [],
  )

  // マウント後にエディタを初期化
  let _ = @luna.effect(fn() {
    match container_ref.val {
      Some(el) => {
        let editor = create_moonlight_editor(el, svg_signal.get())
        editor_ref.val = Some(editor)

        // 変更を Signal に反映
        editor.onChange(fn() {
          svg_signal.set(editor.exportSvg())
        })
      }
      None => ()
    }
  })

  container
}
```

---

## 4. イベント API

### 4.1 利用可能なイベント

```typescript
// 要素が変更された時
editor.onChange(callback: () => void): () => void

// 要素が選択された時
editor.onSelect(callback: (ids: string[]) => void): () => void

// 選択が解除された時
editor.onDeselect(callback: () => void): () => void

// エディタがフォーカスを得た時
editor.onFocus(callback: () => void): () => void

// エディタがフォーカスを失った時
editor.onBlur(callback: () => void): () => void

// ツールモードが変更された時 ('select' | 'freedraw')
editor.onModeChange(callback: (mode: string) => void): () => void

// 要素が追加された時
editor.onElementAdd(callback: (id: string) => void): () => void

// 要素が削除された時
editor.onElementDelete(callback: (id: string) => void): () => void
```

### 4.2 購読解除

各イベントメソッドは解除関数を返す:

```typescript
const unsubscribe = editor.onChange(() => {
  console.log('changed');
});

// 後で解除
unsubscribe();
```

---

## 5. 操作 API

### 5.1 選択操作

```typescript
// 特定の要素を選択
editor.select(['el-1', 'el-2']);

// 全要素を選択
editor.selectAll();

// 選択解除
editor.deselect();

// 選択中の要素 ID を取得
const ids = editor.getSelectedIds();
```

### 5.2 要素操作

```typescript
// 全要素を取得
const elements = editor.getElements();

// ID で要素を取得
const element = editor.getElementById('el-1');

// 要素を削除
editor.deleteElements(['el-1', 'el-2']);
```

### 5.3 モード切替

```typescript
// フリードローモードに切替
editor.setMode('freedraw');

// 選択モードに切替
editor.setMode('select');

// 現在のモードを取得
const mode = editor.getMode(); // 'select' | 'freedraw'
```

### 5.4 読み取り専用

```typescript
// 読み取り専用に設定
editor.setReadonly(true);

// 編集可能に戻す
editor.setReadonly(false);

// 現在の状態を取得
const isReadonly = editor.isReadonly();
```

### 5.5 フォーカス

```typescript
// フォーカス状態を確認
const hasFocus = editor.hasFocus();

// プログラムからフォーカス
editor.focus();

// フォーカスを外す
editor.blur();
```

---

## 6. Markdown Editor 統合例

### 6.1 コードブロック拡張

````markdown
```moonlight-svg
<svg viewBox="0 0 400 300">
  <rect x="50" y="50" width="100" height="80" fill="#4a90d9" />
</svg>
```
````

### 6.2 パーサー拡張 (MoonBit)

```moonbit
/// SVG コードブロックを検出してエディタに置換
fn parse_svg_blocks(markdown : String) -> Array[Block] {
  let blocks : Array[Block] = []
  // moonlight-svg コードブロックを検出
  let pattern = "```moonlight-svg\n"
  // ... パース処理
  blocks
}

/// ブロックをレンダリング
fn render_block(block : Block) -> @luna.Node[@luna.DomEvent] {
  match block {
    SvgBlock(svg_content) => {
      // Moonlight エディタとして表示
      svg_editor_component(svg_content)
    }
    TextBlock(text) => {
      // 通常のテキスト
      @element.p([], [text(text)])
    }
  }
}
```

### 6.3 編集モードの切り替え

```moonbit
/// プレビュー/編集モード切り替え
fn svg_block_with_toggle(
  svg : @luna.Signal[String],
  is_editing : @luna.Signal[Bool],
) -> @luna.Node[@luna.DomEvent] {
  @luna.show(
    is_editing.get(),
    // 編集モード: Moonlight エディタ
    then_=fn() { moonlight_editor(svg) },
    // プレビューモード: 静的 SVG 表示
    else_=fn() { svg_preview(svg) },
  )
}
```

---

## 7. スタイリング

### 7.1 コンテナサイズ

エディタはコンテナのサイズに依存しない。`width`/`height` オプションで指定:

```css
#svg-editor-container {
  /* コンテナ自体のスタイル */
  border: 1px solid #ccc;
  border-radius: 8px;
  overflow: hidden;
}
```

### 7.2 テーマ

```typescript
// ダークテーマ
const editor = MoonlightEditor.create(container, {
  theme: 'dark',
  // ...
});
```

---

## 8. 注意点

### 8.1 破棄処理

コンポーネントがアンマウントされる際は `destroy()` を呼ぶ:

```typescript
editor.destroy();
```

### 8.2 フォーカス競合

Markdown Editor と Moonlight Editor でキーボードフォーカスが競合する場合:

```typescript
// Moonlight がフォーカスを持っている間は Markdown Editor のショートカットを無効化
editor.onFocus(() => {
  markdownEditor.disableShortcuts();
});

editor.onBlur(() => {
  markdownEditor.enableShortcuts();
});
```

### 8.3 SVG フォーマット

Moonlight が出力する SVG は `data-moonlight-*` 属性を含む。これにより再編集が可能:

```xml
<svg viewBox="0 0 400 300" data-moonlight-version="1">
  <rect data-id="el-1" data-moonlight="true" ... />
</svg>
```

プレーン SVG（`data-moonlight` 属性なし）も読み込めるが、移動のみ可能でリサイズ不可。

---

## 9. 実装チェックリスト

- [ ] `mizchi/moonlight` パッケージを追加
- [ ] embed モジュールをインポート
- [ ] SVG ブロックの Signal 管理を実装
- [ ] `MoonlightEditor.create()` でエディタ初期化
- [ ] `onChange` で Markdown ドキュメントと同期
- [ ] フォーカス管理（ショートカット競合対策）
- [ ] 破棄処理 (`destroy()`) を実装
- [ ] プレビュー/編集モード切り替え UI

---

## 10. 参考ファイル

- `examples/embed.html` - 基本的な組み込み例
- `examples/preview.html` - プレビューモード例
- `embed.ts` - JavaScript エントリポイント
- `src/embed/entry.mbt` - MoonBit エントリポイント
- `src/main.mbt` - API 実装詳細
