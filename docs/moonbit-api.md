# Moonlight MoonBit API

MoonBit から Moonlight を使用するための API ドキュメント。

## パッケージ構成

```
mizchi/moonlight
├── core      # EditorState, Signal 管理
├── model     # 純粋なデータ型と計算関数
├── lib       # UI ロジック（DOM 依存）
└── embed     # JavaScript 統合エントリポイント
```

## 基本的な型

### Point

2D 座標点。

```moonbit
pub(all) struct Point {
  x : Double
  y : Double
}
```

### ShapeType

図形の種類。

```moonbit
pub(all) enum ShapeType {
  Rect(Double, Double, Double?, Double?)  // width, height, rx?, ry?
  Circle(Double)                           // radius
  Ellipse(Double, Double)                  // rx, ry
  Line(Double, Double)                     // end_x, end_y (始点は Element.x, y)
  Polyline(Array[Point])                   // 折れ線
  Path(String, Double, Double, Double, Double)  // d, start_x, start_y, end_x, end_y
  Text(String, Double?)                    // content, font_size?
}
```

### Style

要素のスタイル。

```moonbit
pub(all) struct Style {
  fill : String?           // 塗りつぶし色
  stroke : String?         // 線色
  stroke_width : Double?   // 線幅
  opacity : Double?        // 不透明度
  stroke_dasharray : String?  // 破線パターン
  marker_start : ArrowType?   // 始点マーカー
  marker_end : ArrowType?     // 終点マーカー
  font_family : String?    // フォント
}
```

### Element

図形要素。

```moonbit
pub(all) struct Element {
  id : String              // 一意の識別子
  x : Double               // X 座標
  y : Double               // Y 座標
  shape : ShapeType        // 図形タイプ
  style : Style            // スタイル
  transform : String?      // SVG transform 属性
  parent_id : String?      // 親要素ID（子要素の場合）
  connections : LineConnections?  // 線の接続情報
}
```

### Anchor

接続点の位置。

```moonbit
pub(all) enum Anchor {
  Center
  Top
  Bottom
  Left
  Right
  TopLeft
  TopRight
  BottomLeft
  BottomRight
  LineStart   // 線の始点
  LineEnd     // 線の終点
}
```

## EditorState

エディタの状態管理。Signal ベースのリアクティブな状態。

### 作成

```moonbit
// 基本的な作成
let state = @core.EditorState::new(800, 600)

// モード指定で作成
let state = @core.EditorState::new_with_mode(800, 600, @core.Embedded)
```

### 要素操作

```moonbit
// 要素を追加
state.add_element(element)

// 要素を検索
let el : Element? = state.find_element("element-id")

// 要素を更新
state.update_element("element-id", fn(el) {
  { ..el, x: 100.0, y: 100.0 }
})

// 汎用更新ヘルパー
state.update_element_by_id("element-id", fn(el) {
  { ..el, style: { ..el.style, fill: Some("#ff0000") } }
})

// 要素を移動（接続されたラインも自動更新）
state.move_element("element-id", 200.0, 150.0)
```

### 選択操作

```moonbit
// 単一選択
state.select(Some("element-id"))

// 複数選択
state.select_multiple(["id1", "id2", "id3"])

// 選択に追加
state.add_to_selection("element-id")

// 選択から除去
state.remove_from_selection("element-id")

// 全選択
state.select_all()

// 選択中か確認
let is_sel : Bool = state.is_selected("element-id")

// 選択中のIDを取得
let selected_id : String? = state.get_selected_id()
```

### ヒットテスト

```moonbit
// 座標で要素を検索
let hit_id : String? = state.hit_test(100.0, 200.0)
```

### テーマ

```moonbit
// テーマを取得
let theme : @model.Theme = state.get_theme()

// ライトテーマ
let light = @model.Theme::light()

// ダークテーマ
let dark = @model.Theme::dark()
```

## Element 操作

### 作成

```moonbit
// 基本的な作成
let rect = @model.Element::new(
  "rect-1",
  100.0,  // x
  100.0,  // y
  @model.Rect(80.0, 60.0, None, None),
  @model.Style::default(),
)

// 親要素を指定
let text = rect.with_parent("parent-id")

// スタイルを指定
let styled = rect.with_style({ ..@model.Style::default(), fill: Some("#ff0000") })
```

### バウンディングボックス

```moonbit
let bbox : @model.BoundingBox = element.bounding_box()
// bbox.x, bbox.y, bbox.width, bbox.height
```

### ヒットテスト

```moonbit
let hit : Bool = element.hit_test(@model.Point::new(50.0, 50.0))
```

### アンカーポイント

```moonbit
// 特定のアンカー位置を取得
let point : Point = element.get_anchor_point(@model.Center)

// 全アンカーを取得
let anchors : Array[(Anchor, Point)] = element.get_all_anchors()

// 最も近いアンカーを検索
let nearest : (Anchor, Point, Double)? = element.find_nearest_anchor(
  @model.Point::new(100.0, 100.0),
  20.0,  // threshold
)
```

## JavaScript 統合

### EditorOptions

JavaScript から渡されるオプション。

```moonbit
pub(all) struct EditorOptions {
  width : Int?           // キャンバス幅
  height : Int?          // キャンバス高さ
  gridsnap : Bool        // グリッドスナップ
  theme : String?        // "light" | "dark"
  zoom : Double?         // 初期ズーム
  is_readonly : Bool     // 読み取り専用
  toolbar_visible : Bool // ツールバー表示
  initial_svg : String?  // 初期SVG
  show_help_button : Bool // ヘルプボタン表示
}
```

### JavaScript からの呼び出し

```javascript
// エディタ作成
const handle = MoonlightEditor.create(container, {
  width: 800,
  height: 600,
  theme: 'light',
  initialSvg: '<svg>...</svg>'
});

// API
handle.exportSvg();        // SVG を取得
handle.importSvg(svg);     // SVG をインポート
handle.clear();            // クリア
handle.destroy();          // 破棄
handle.hasFocus();         // フォーカス状態
handle.onChange(callback); // 変更コールバック
```

## テスト用ヘルパー

`luna_testing` パッケージで VNode のユニットテストが可能。

```moonbit
// VNode クエリ
let tag : String? = get_tag(node)
let text : String = get_all_text(node)
let found : Node? = find_by_tag(node, "button")

// アサーション
assert_tag(node, "div")
assert_text_contains(node, "Hello")
assert_has_element(node, "button")

// Signal トラッキング
let tracker = track_signal(sig)
sig.set(1)
sig.set(2)
assert_tracked_values(tracker, [0, 1, 2])
```

詳細は `src/luna_testing/README.md` を参照。

## モデル層の純粋関数

`@model` パッケージには DOM に依存しない純粋関数が含まれる。

### 要素移動

```moonbit
// 要素を移動し、関連する全ての更新を行う（純粋関数）
let updated : Array[Element] = @model.move_element_with_relations(
  elements,
  "element-id",
  new_x,
  new_y,
)
```

### リサイズ

```moonbit
// 要素をリサイズし、関連要素を更新
let updated : Array[Element] = @model.resize_element_with_relations(
  elements,
  "element-id",
  new_shape,
)
```

### バリデーション

```moonbit
// 要素を検証
let result : ValidationResult = @model.validate_elements(elements)
let capability : ElementCapability = @model.get_element_capability(result, "id")
let issues : Array[ValidationIssue] = @model.get_element_issues(result, "id")
```

### トポロジー

```moonbit
// 接続グラフを構築
let graph : ConnectionGraph = @model.build_connection_graph(elements)

// 隣接要素を取得
let neighbors : Array[String] = graph.get_neighbors("element-id")

// 最短パスを検索
let path : ShortestPath? = graph.find_shortest_path("from", "to", elements)
```
