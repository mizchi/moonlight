# Moonlight - 軽量 SVG エディタ

MoonBit + luna ライブラリで Excalidraw 風の軽量 SVG エディタを実装するプロジェクト。

## 目標

- SVG をそのまま扱える（rect, circle, line, text など簡単な図形）
- エディタ自体を軽量に保つ
- WYSIWYG エディタに組み込み可能

## プロジェクト構造

```
src/
├── lib.mbt           # エントリーポイント
├── types.mbt         # データモデル定義
├── scene.mbt         # Scene 管理
├── render.mbt        # SVG レンダリング
├── events.mbt        # イベントハンドリング
└── svg/              # SVG 要素ヘルパー（将来）
```

## 依存ライブラリ

- `mizchi/luna` - Signal ベースの UI ライブラリ
- `mizchi/js` - JavaScript FFI

## luna ライブラリ概要

### Signal（リアクティブ値）

```moonbit
let count = @luna.signal(0)       // Signal 作成
count.get()                        // 値取得
count.set(1)                       // 値設定
count.update(fn(n) { n + 1 })      // 更新

let doubled = @luna.memo(() => count.get() * 2)  // 派生値
@luna.effect(() => { ... })        // 副作用
@luna.batch(() => { ... })         // バッチ更新
```

### VNode（仮想ノード）

```moonbit
// 基本型
pub enum Node[E] {
  Element(VElement[E])      // HTML/SVG 要素
  Text(String)              // 静的テキスト
  DynamicText(() -> String) // 動的テキスト
  Fragment(Array[Node[E]])  // フラグメント
  Show(...)                 // 条件付き
  For(...)                  // リスト
  ...
}

// 汎用要素作成
@luna.h(tag: String, attrs: Array[(String, Attr[E])], children: Array[Node[E]])

// Attr 型
pub enum Attr[E] {
  VStatic(String)           // 静的値
  VDynamic(() -> String)    // Signal 連動
  VHandler(EventHandler[E]) // イベントハンドラ
}
```

### DOM 要素（ブラウザ用）

```moonbit
using @element {div, span, button, text, text_dyn, events}

div(class="foo", [
  button(on=events().click(_ => ...), [text("Click")])
])

// 任意タグは @luna.h() で作成
@luna.h("svg", [("viewBox", @luna.attr_static("0 0 100 100"))], [...])
```

### SVG 要素の作成

luna には SVG ヘルパーがないため、`@luna.h()` を使用：

```moonbit
fn svg_rect(x: Double, y: Double, w: Double, h: Double) -> @luna.Node[E] {
  @luna.h("rect", [
    ("x", @luna.attr_static(x.to_string())),
    ("y", @luna.attr_static(y.to_string())),
    ("width", @luna.attr_static(w.to_string())),
    ("height", @luna.attr_static(h.to_string())),
  ], [])
}
```

## 開発コマンド

```bash
moon check              # 型チェック
moon fmt                # フォーマット
moon build              # ビルド
pnpm dev               # 開発サーバー (Vite)
```

## データモデル設計

### 要素型（SVG 写像）

SVG 仕様に準拠した最小限のデータモデル：

```moonbit
// 基本座標
pub struct Point { x: Double, y: Double }

// 共通スタイル
pub struct Style {
  fill: String?
  stroke: String?
  stroke_width: Double?
  opacity: Double?
}

// 要素の種類
pub enum ShapeType {
  Rect(width: Double, height: Double, rx: Double?, ry: Double?)
  Circle(r: Double)
  Ellipse(rx: Double, ry: Double)
  Line(x2: Double, y2: Double)
  Polyline(points: Array[Point])
  Path(d: String)
  Text(content: String, font_size: Double?)
}

// 図形要素
pub struct Element {
  id: String
  x: Double                    // 基準 X 座標
  y: Double                    // 基準 Y 座標
  shape: ShapeType             // 図形タイプ
  style: Style                 // スタイル
  transform: String?           // SVG transform
  selected: Bool               // 選択状態（UI 用）
}
```

### Scene 管理

```moonbit
pub struct Scene {
  elements: @luna.Signal[Array[Element]]  // 要素リスト
  selected_ids: @luna.Signal[Array[String]]  // 選択中の ID
  viewport: @luna.Signal[Viewport]  // 表示領域
}

pub struct Viewport {
  scroll_x: Double
  scroll_y: Double
  zoom: Double
}
```

## Luna 使用上の注意点

### SVG 要素の作成

Luna の `create_element` は `document.createElement()` を使用するため、SVG 要素には使えない。
SVG は `createElementNS` が必要なため、FFI で直接呼び出す：

```moonbit
let svg_ns : String = "http://www.w3.org/2000/svg"

extern "js" fn create_svg_element_ffi(tag : String, ns : String) -> @js.Any =
  #| (tag, ns) => document.createElementNS(ns, tag)
```

### 外部 DOM の統合

FFI で作成した DOM を Luna ツリーに統合するには `@element.dom_node()` を使用：

```moonbit
let svg : @js.Any = create_svg_element_ffi("svg", svg_ns)
let node : @js_dom.Node = svg.cast()
@element.dom_node(node)  // DomNode として使用可能
```

### Effect の初回実行

`@luna.effect` は作成時に即座に実行される。Ref の初期化後に実行したい場合は初回スキップフラグを使う：

```moonbit
let is_first_run : Ref[Bool] = { val: true }
let _ = @luna.effect(fn() {
  let _ = signal.get()  // 依存関係を登録
  if is_first_run.val {
    is_first_run.val = false
    return
  }
  // 2回目以降の処理
})
```

## 参考

- Excalidraw: `tmp/excalidraw/`
- luna ドキュメント: `.mooncakes/mizchi/luna/docs/ja/`
- **Luna 改善提案**: `docs/proposal-luna.md`
