# Luna UI コンポーネントテスト設計

## 概要

Luna の UI コンポーネントをユニットテストするためのパターンを設計する。
DOM 非依存でテスト可能な範囲を最大化し、Luna 本体へのフィードバックも考慮する。

## 現状の Luna テストパターン

Luna には以下のテストパターンが存在する：

### 1. VNode 構造テスト (`vnode_test.mbt`)

```moonbit
test "h creates Element node" {
  let node : Node[Unit] = h("div", [], [])
  match node {
    Element(elem) => assert_eq(elem.tag, "div")
    _ => assert_true(false)
  }
}
```

### 2. Signal リアクティビティテスト (`signals_test.mbt`)

```moonbit
test "effect re-runs when signal changes" {
  let sig = Signal::new(0)
  let observed = { val: 0 }
  let _ = effect(fn() { observed.val = sig.get() })
  assert_eq(observed.val, 0)
  sig.set(42)
  assert_eq(observed.val, 42)
}
```

### 3. SSR レンダリングテスト (`render_test.mbt`)

```moonbit
test "render_to_string element" {
  let node : @luna.Node[Unit] = @luna.h("div", [], [@luna.text("content")])
  let result = render_to_string(node)
  assert_eq(result.html, "<div>content</div>")
}
```

## 課題

1. **VNode のパターンマッチが冗長**: 深くネストした VNode の検証が困難
2. **Dynamic 属性のテストが困難**: Signal 連動の属性を直接テストできない
3. **イベントハンドラのテストパターンがない**: ハンドラの登録確認のみ
4. **コンポーネント合成のテストパターンがない**: Fragment, Show, For などの検証

## 提案：UI テストヘルパー

### 1. VNode クエリヘルパー

```moonbit
// VNode から特定の要素を検索
fn find_element_by_tag[E](node: Node[E], tag: String) -> Node[E]?

// VNode から属性を取得
fn get_attr[E](node: Node[E], name: String) -> Attr[E]?

// VNode の子要素数を取得
fn child_count[E](node: Node[E]) -> Int

// VNode のテキストコンテンツを取得
fn get_text_content[E](node: Node[E]) -> String
```

### 2. アサーションヘルパー

```moonbit
// 要素が特定のタグを持つことを検証
fn assert_tag[E](node: Node[E], expected: String) -> Unit

// 静的属性の値を検証
fn assert_static_attr[E](node: Node[E], name: String, expected: String) -> Unit

// 動的属性の現在値を検証
fn assert_dynamic_attr[E](node: Node[E], name: String, expected: String) -> Unit

// イベントハンドラが存在することを検証
fn assert_has_handler[E](node: Node[E], event: String) -> Unit
```

### 3. コンポーネントテストパターン

```moonbit
// Signal 変更時の再レンダリングをテスト
test "component updates on signal change" {
  let count = @signal.signal(0)
  let node = my_counter_component(count)

  // 初期値を検証
  assert_text_contains(node, "Count: 0")

  // Signal を更新
  count.set(5)

  // 動的テキストが更新されることを検証
  let text_node = find_dynamic_text(node)
  assert_eq(text_node.unwrap()(), "Count: 5")
}
```

## Luna への提案

### 1. `@luna/testing` パッケージの追加

```moonbit
// パッケージ: mizchi/luna/testing

// VNode クエリ
pub fn query_selector[E](node: Node[E], selector: String) -> Node[E]?
pub fn query_selector_all[E](node: Node[E], selector: String) -> Array[Node[E]]

// アサーション
pub fn assert_node_matches[E](node: Node[E], expected: NodeMatcher) -> Unit

// テスト用レンダラー（HTML 文字列ではなく、検査可能な構造を返す）
pub fn render_to_test_tree[E](node: Node[E]) -> TestTree
```

### 2. `NodeMatcher` DSL

```moonbit
// 宣言的なマッチング
let matcher = element("div",
  class="container",
  children=[
    element("button", text="Click me"),
    element("span", dyn_text=fn() { "..." })
  ]
)

assert_node_matches(node, matcher)
```

### 3. Signal スナップショットテスト

```moonbit
// Signal 変更履歴を記録してテスト
test "signal history" {
  let sig = @signal.signal(0)
  let history = @testing.track_signal(sig)

  sig.set(1)
  sig.set(2)
  sig.set(3)

  assert_eq(history.values(), [0, 1, 2, 3])
}
```

## 実装状況

### 実装済み: `src/luna_testing/`

プロトタイプ実装が完了。42テスト通過。

- `query.mbt`: VNode クエリヘルパー（28関数）
- `assertions.mbt`: アサーションヘルパー（18関数）
- `signal.mbt`: Signal テストユーティリティ（12関数）

### Phase 2: Luna へフィードバック

- パターンが安定したら Luna に `@luna/testing` として提案
- ドキュメントとサンプルを整備

## 参考

- React Testing Library: DOM クエリパターン
- Vue Test Utils: コンポーネントマウント・スナップショット
- SolidJS Testing: Signal ベースのテスト
