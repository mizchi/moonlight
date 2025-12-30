# Moonlight モジュール分離設計

## 目標

- 必要な機能のみをバンドルできる構造
- ユースケースに応じた軽量なエントリポイント
- 依存関係の明確化

## 現状の問題

```
src/ (main) = 91KB
├── model + core + components + render + import + ui + ...
└── 全てが1つのバンドルに含まれる
```

→ ビューアーだけ欲しい場合も全機能がバンドルされる

## 提案するモジュール構造

```
src/
├── model/              # 純粋データ型（依存なし、WASM 対応）
│   ├── types.mbt       # Element, Style, ShapeType
│   ├── topology.mbt    # 接続トポロジー計算
│   ├── element_ops.mbt # 要素操作
│   └── command.mbt     # Undo/Redo
│
├── bezier_fit/         # ベジェ近似（依存なし、WASM 対応）
│
├── render/             # SVG レンダリング（純粋関数）★新規
│   ├── svg.mbt         # Element → SVG 文字列
│   ├── export.mbt      # 完全な SVG ドキュメント出力
│   └── moon.pkg.json   # import: [model]
│
├── import/             # SVG パース（FFI 必要）★新規
│   ├── parse.mbt       # SVG 文字列 → Element[]
│   └── moon.pkg.json   # import: [model, js]
│
├── editor/             # インタラクティブ編集★新規
│   ├── state.mbt       # EditorState 管理
│   ├── events.mbt      # イベントハンドラ
│   ├── interaction.mbt # ドラッグ、リサイズ
│   └── moon.pkg.json   # import: [model, render, luna]
│
├── components/         # UI コンポーネント（現状維持）
│
├── webcomponent/       # カスタム要素ラッパー（現状維持）
│
└── entries/            # ビルドエントリポイント★新規
    ├── viewer/         # model + render（読み取り専用）
    ├── editor/         # model + render + import + editor
    └── full/           # 全機能
```

## 依存関係グラフ

```
                    ┌─────────────┐
                    │   model     │  (純粋、WASM 対応)
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
    ┌─────▼─────┐    ┌─────▼─────┐    ┌─────▼─────┐
    │  render   │    │  import   │    │bezier_fit │
    │(SVG出力)  │    │(SVGパース)│    │(曲線近似) │
    └─────┬─────┘    └─────┬─────┘    └───────────┘
          │                │
          └───────┬────────┘
                  │
            ┌─────▼─────┐
            │  editor   │  (状態 + インタラクション)
            └─────┬─────┘
                  │
         ┌────────┼────────┐
         │        │        │
   ┌─────▼──┐ ┌───▼────┐ ┌─▼──────────┐
   │  UI    │ │ embed  │ │webcomponent│
   └────────┘ └────────┘ └────────────┘
```

## ユースケース別バンドル

### 1. Viewer（読み取り専用）

```javascript
// 約 30KB（目標）
import { renderSvg } from '@moonlight/render'
import { Element } from '@moonlight/model'

const svg = renderSvg(elements)
container.innerHTML = svg
```

必要モジュール: `model` + `render`

### 2. Static Editor（編集、状態なし）

```javascript
// 約 50KB（目標）
import { renderSvg, exportSvg } from '@moonlight/render'
import { importSvg } from '@moonlight/import'

const elements = importSvg(svgString)
// ... 操作
const output = exportSvg(elements)
```

必要モジュール: `model` + `render` + `import`

### 3. Interactive Editor（フル編集）

```javascript
// 約 80KB（目標）
import { Editor } from '@moonlight/editor'

const editor = new Editor(container)
editor.load(svgString)
editor.onchange = (svg) => console.log(svg)
```

必要モジュール: `model` + `render` + `import` + `editor`

### 4. WebComponent（ドロップイン）

```html
<!-- 約 100KB（目標）-->
<script src="moonlight.js"></script>
<moonlight-editor></moonlight-editor>
```

必要モジュール: 全て

## 実装計画

### Phase 1: render モジュール分離

1. `src/render.mbt` から純粋関数を抽出
2. `src/render/` ディレクトリを作成
3. `moon.pkg.json` で model のみ依存

### Phase 2: import モジュール分離

1. `src/import.mbt` を `src/import/` に移動
2. FFI 依存を明確化

### Phase 3: editor モジュール分離

1. 状態管理を `src/editor/state.mbt` に
2. イベント処理を `src/editor/events.mbt` に
3. UI 描画を `src/editor/ui.mbt` に

### Phase 4: エントリポイント作成

1. `src/entries/viewer/` - 最小構成
2. `src/entries/editor/` - 編集機能
3. `src/entries/full/` - 全機能

### Phase 5: ビルド設定

1. rolldown で複数エントリポイント
2. tree-shaking の確認
3. サイズ測定・最適化

## サイズ目標

| エントリポイント | 非圧縮 | gzip |
|------------------|--------|------|
| viewer           | 60KB   | 20KB |
| static-editor    | 100KB  | 35KB |
| interactive      | 160KB  | 55KB |
| full + wc        | 200KB  | 70KB |

## 注意点

- MoonBit の tree-shaking は関数レベル
- `is-main: true` のパッケージのみビルド可能
- 循環参照に注意（model → render → editor の一方向）
