# Luna SVG 名前空間での for_each 問題

## 問題

Luna の `for_each` を SVG 要素内で使用すると、DOM 階層エラーが発生する。

### エラーメッセージ

```
HierarchyRequestError: Failed to execute 'moveBefore' on 'Element':
State-preserving atomic move cannot be performed on nodes participating in an invalid hierarchy.

NotFoundError: Failed to execute 'removeChild' on 'Node':
The node to be removed is not a child of this node.
```

### 再現コード

```moonbit
fn render_svg_canvas() -> @element.DomNode {
  let svg_attrs = [
    ("width", @element.Static("400")),
    ("height", @element.Static("300")),
  ]

  let children : Array[@element.DomNode] = []

  // これが問題を引き起こす
  children.push(@element.for_each(
    fn() { elements_signal.get() },
    fn(el, _idx) {
      // SVG 子要素を返す
      create_svg_node("rect", [...], [], [])
    },
  ))

  @element.create_element_ns(@element.svg_ns, "svg", svg_attrs, children)
}
```

## 原因の推測

1. **名前空間の不一致**: Luna の reconciliation が HTML DOM を前提としており、SVG 名前空間内での `moveBefore` / `removeChild` が正しく動作しない

2. **親子関係の追跡**: `for_each` 内で生成された SVG 要素が、正しい親要素に関連付けられていない可能性

3. **DOM 操作 API の違い**: SVG 要素では一部の DOM 操作 API の動作が HTML と異なる場合がある

## 現在のワークアラウンド

SVG 内部の要素は Effect ベースで手動管理し、`for_each` を使わない：

```moonbit
fn render_svg_canvas_node(state : EditorState, ...) -> @element.DomNode {
  let svg_ref : Ref[@js.Any?] = { val: None }

  let svg_attrs = [
    ("width", @element.Static("400")),
    ("height", @element.Static("300")),
    // Dynamic 属性は正常に動作する
    ("viewBox", @element.Dynamic(fn() { ... })),
    ("style", @element.Dynamic(fn() { ... })),
    // __ref で SVG 要素への参照を取得
    ("__ref", @element.Handler(fn(el) {
      svg_ref.val = Some(el)
      redraw_svg_inner(...)
    })),
  ]

  // Effect で Signal 変更を監視し、手動で再描画
  let _ = @luna.effect(fn() {
    let elements = state.elements.get()
    // ... 他の Signal も取得

    if svg_ref.val is Some(svg) {
      clear_children_ffi(svg)
      // 手動で子要素を追加
      for el in elements {
        append_child_ffi(svg, render_element(el, ...))
      }
    }
  })

  // 子要素なしで SVG を作成（Effect で動的に追加）
  @element.create_element_ns(@element.svg_ns, "svg", svg_attrs, [])
}
```

## 期待される修正

Luna 側で以下のいずれかの対応が必要：

### 案1: SVG 名前空間対応の reconciliation

`for_each` の reconciliation ロジックで、親要素が SVG 名前空間の場合に適切な DOM 操作を行う。

### 案2: 名前空間を考慮した moveBefore

`moveBefore` が SVG 要素で失敗する場合のフォールバック処理を追加：

```javascript
function moveBefore(parent, node, referenceNode) {
  try {
    parent.moveBefore(node, referenceNode);
  } catch (e) {
    if (e instanceof DOMException) {
      // フォールバック: insertBefore を使用
      parent.insertBefore(node, referenceNode);
    } else {
      throw e;
    }
  }
}
```

### 案3: SVG 専用の for_each

SVG 名前空間内で使用する専用の `for_each_svg` を提供し、内部で適切な DOM 操作を行う。

## テストケース

修正後、以下のケースで動作確認が必要：

1. SVG 内で `for_each` を使った要素リストの描画
2. 要素の追加・削除時の差分更新
3. 要素の順序変更（ドラッグ&ドロップなど）
4. ネストした SVG グループ（`<g>`）内での `for_each`

## 追加の問題: show/for_each 内部コンテンツの再描画

Luna v0.2.2 で `for_each` の階層エラーは修正されたが、別の問題が発見された。

### 問題

`show` や `for_each` 内で生成された要素は、Signal の値変更時に再描画されない。

### 再現コード

```moonbit
// 選択中の要素のリサイズハンドルを描画
children.push(show(
  fn() { state.selected_ids.get().length() > 0 },
  fn() {
    // elements.get() を呼んでも依存関係として機能しない
    let _ = state.elements.get()
    let selected_ids = state.selected_ids.get()
    let nodes : Array[@element.DomNode] = []
    for id in selected_ids {
      match state.find_element(id) {
        Some(el) => {
          // el の位置は変更されているが、
          // 生成されるハンドルは古い位置のまま
          for handle in render_resize_handles_nodes(el) {
            nodes.push(handle)
          }
        }
        None => ()
      }
    }
    @element.fragment(nodes)
  },
))
```

### 症状

1. 要素をドラッグして移動
2. リサイズハンドル/アンカーポイントが元の位置に残る
3. 要素の位置は更新されているが、`show` 内の子要素は再描画されない

### 原因

- `show` は条件関数の結果（true/false）の変化のみを検知
- 条件が true → true のままでも Signal 値が変化した場合、内部コンテンツは再描画されない
- `for_each` も同様に、配列の要素追加/削除は検知するが、要素の内部データ変更は検知しない

### ワークアラウンド

Effect ベースの手動 DOM 操作に戻す:

```moonbit
let _ = @luna.effect(fn() {
  // 必要な Signal を全て取得（依存関係として登録）
  let elements = state.elements.get()
  let selected_ids = state.selected_ids.get()
  // ...

  if svg_ref.val is Some(svg) {
    // 手動で DOM をクリア & 再構築
    clear_children_ffi(svg)
    for el in elements {
      append_child_ffi(svg, render_element(el, ...))
    }
    // ハンドルも手動で追加
    for id in selected_ids {
      // ...
    }
  }
})
```

### 期待される修正

1. **深い依存関係の追跡**: `show`/`for_each` 内で参照された Signal の変更時にも内部コンテンツを再描画する

2. **強制再描画フラグ**: Signal 変更時に内部コンテンツを強制的に再描画するオプション

3. **memo との統合**: `show` 内のコンテンツ生成関数を memo 化し、依存 Signal の変更で自動再計算

## 関連

- `docs/luna_svg_fix.md` - `create_element_ns` の追加提案（実装済み）
- Luna 0.2.1 で `create_element_ns` は対応済み
- Luna 0.2.2 で `for_each` の階層エラーは修正済み
