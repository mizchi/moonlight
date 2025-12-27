# Luna 改善提案 Part 2

Moonlight SVG エディタの実装を通じて発見した追加の改善点をまとめる。
proposal-luna.md の続編として、より実践的な課題と提案を記載する。

## 1. イベントハンドリングの型安全性

### 問題

イベントオブジェクトの扱いが冗長で、型安全性が低い：

```moonbit
// 現状：型キャストが頻繁に必要
on=events().click(fn(e) {
  let value = get_event_target_value(e.as_any())  // as_any() が必要
})

// MouseEvent のプロパティアクセスも冗長
let mouse_event : @js_dom.MouseEvent = e.cast()
let client_x = mouse_event.clientX

// さらに target のプロパティアクセスは _get ベース
let target = e._get("target")
let dataset = target._get("dataset")
let data_id = dataset._get("id")
```

### 提案 A: 型付きイベントハンドラ

```moonbit
// MouseEvent 専用のハンドラ
on=events().mouse_click(fn(e : MouseEvent) {
  let x = e.client_x  // 直接アクセス
  let y = e.client_y
})

// Input イベント専用
on=events().text_input(fn(e : InputEvent) {
  let value = e.target_value  // 直接取得
})
```

### 提案 B: イベントユーティリティの充実

```moonbit
// @luna.event モジュール
pub fn target_value(e : @js.Any) -> String { ... }
pub fn target_dataset(e : @js.Any, key : String) -> String? { ... }
pub fn client_pos(e : @js.Any) -> (Double, Double) { ... }
pub fn prevent_default(e : @js.Any) -> Unit { ... }
pub fn stop_propagation(e : @js.Any) -> Unit { ... }

// 使用例
on=events().click(fn(e) {
  let value = @luna.event.target_value(e)
  let (x, y) = @luna.event.client_pos(e)
})
```

### 推奨

**提案 B** を優先。既存 API との互換性を保ちつつ、よく使うパターンを簡略化できる。

---

## 2. Signal の更新バッチング

### 問題

複数の Signal を更新する際、各更新で effect が発火する：

```moonbit
// 問題：各行で effect が発火する可能性
self.elements.update(fn(els) { ... })  // effect 発火
self.selected_ids.set([])               // effect 発火
self.resize_state.set(None)             // effect 発火

// さらに悪いパターン：ループ内での更新
for id in ids {
  self.update_element(id, ...)  // 各ループで effect 発火！
}
```

### 現状のワークアラウンド

Moonlight では1回の `elements.update` 内で複数要素を更新：

```moonbit
// 最適化後：1回の update で全て処理
self.elements.update(fn(els) {
  els.map(fn(e) {
    if e.id == line_id { ... }
    else if connected_ids.contains(e.id) { ... }
    else { e }
  })
})
```

### 提案 A: 自動バッチング

```moonbit
// Signal 更新を自動的にバッチ化
// 同一イベントループ内の更新をまとめて処理
@luna.configure(auto_batch=true)
```

### 提案 B: 明示的バッチ API の強化

```moonbit
///|
/// Batch signal updates with transaction semantics
/// All effects are deferred until transaction completes
pub fn transaction[T](f : () -> T) -> T {
  // バッチ開始
  // f() を実行（signal 更新は記録のみ）
  // バッチ終了時に一括で effect を実行
}

// 使用例
@luna.transaction(fn() {
  state.elements.update(...)
  state.selected_ids.set([])
  state.resize_state.set(None)
})
// ここで effect が1回だけ発火
```

### 提案 C: ドキュメント強化

既存の `@luna.batch` の挙動と使い方を明確化：

- どのタイミングで effect が発火するか
- ネストした batch の挙動
- batch 内でのエラーハンドリング

### 推奨

**提案 B + C**。transaction API で意図を明確にし、ドキュメントで使い方を説明する。

---

## 3. テキスト入力と IME 対応

### 問題

Luna の `input` / `textarea` では IME（日本語入力）対応が難しい：

```moonbit
// 問題：IME 確定前に onChange が発火してしまう
input(
  on=events().change(fn(e) {
    // 日本語入力中も呼ばれる場合がある
  }),
)
```

### 現状のワークアラウンド

FFI で直接 textarea を作成し、composition イベントを処理：

```moonbit
// ffi.mbt
pub extern "js" fn create_textarea_ffi(
  style : String,
  initial_value : String,
  on_commit : (String) -> Unit,
  on_escape : (String) -> Unit,
) -> @js.Any =
  #| (style, initialValue, onCommit, onEscape) => {
  #|   const textarea = document.createElement('textarea');
  #|   let isComposing = false;
  #|   textarea.addEventListener('compositionstart', () => { isComposing = true; });
  #|   textarea.addEventListener('compositionend', () => { isComposing = false; });
  #|   textarea.addEventListener('keydown', (e) => {
  #|     if (e.key === 'Enter' && !isComposing) {
  #|       e.preventDefault();
  #|       onCommit(textarea.value);
  #|     }
  #|   });
  #|   // ...
  #| }
```

### 提案

IME 対応のイベントハンドラを追加：

```moonbit
// compositionstart/compositionend を考慮した入力イベント
on=events().text_commit(fn(value : String) {
  // IME 確定後のみ呼ばれる
})

// または composition 状態を提供
on=events().input_with_composition(fn(e : InputEvent, is_composing : Bool) {
  if not(is_composing) {
    // IME 確定後の処理
  }
})
```

---

## 4. 条件分岐の表現力

### 問題

`if` 式は `else` が必須で、空の場合も明示が必要：

```moonbit
// 冗長：else 部分が空でも書く必要がある
div([
  if condition {
    some_content()
  } else {
    @element.fragment([])  // 空を明示
  },
])

// show を使う場合も、条件が複雑だと冗長
show(
  fn() { state.selected_ids.get().length() == 1 },
  fn() { render_details() },
)
```

### 提案 A: when ヘルパー

```moonbit
///|
/// Render content only when condition is true (no else branch needed)
pub fn when(cond : () -> Bool, content : () -> DomNode) -> DomNode {
  show(cond, content)  // 内部的には show と同じ
}

// 使用例
div([
  when(fn() { is_visible }, fn() { content() }),
])
```

### 提案 B: show の else サポート

```moonbit
// else を持つ show
show_else(
  fn() { condition },
  fn() { if_true_content() },
  fn() { if_false_content() },
)

// または show をオーバーロード
show(
  fn() { condition },
  then=fn() { ... },
  else=fn() { ... },  // オプション
)
```

### 提案 C: guard パターンのサポート

```moonbit
// Signal から値を取り出して条件分岐
show_some(
  fn() { state.selected_id.get() },  // Option[T]
  fn(id) { render_for_id(id) },      // T -> DomNode
)

// 使用例
show_some(
  fn() { state.context_menu.get() },
  fn(menu) { render_menu(menu) },
)
```

### 推奨

**提案 C** が最も有用。Option/Result の unwrap パターンが簡潔になる。

---

## 5. 動的スタイルの簡略化

### 問題

動的スタイルと静的スタイルの組み合わせが冗長：

```moonbit
// 現状：基本スタイル + 動的部分を毎回結合
button(
  style=base_style,
  dyn_style=fn() {
    if is_active {
      base_style + " background: #000; color: #fff;"  // 重複
    } else {
      base_style + " background: #fff; color: #000;"
    }
  },
)
```

### 提案 A: スタイルマージ

```moonbit
// 静的スタイルは style で、動的部分は dyn_style で
// 両方指定した場合は自動的にマージ
button(
  style="padding: 8px; border-radius: 4px;",  // 静的部分
  dyn_style=fn() {
    if is_active {
      "background: #000; color: #fff;"  // 動的部分のみ
    } else {
      "background: #fff; color: #000;"
    }
  },
)
// 結果: "padding: 8px; border-radius: 4px; background: ..."
```

### 提案 B: クラスベースの動的スタイル

```moonbit
// CSS クラスを動的に設定
button(
  class="btn btn-base",
  dyn_class=fn() {
    if is_active { "btn-active" } else { "btn-inactive" }
  },
)
```

### 推奨

**提案 A** を優先。インラインスタイルでの開発が多い場合に便利。

---

## 6. イベントリスナーの複数設定

### 問題

複数のイベントを設定する際、冗長になりがち：

```moonbit
// 現状：各イベントを個別に設定
div(
  on=events()
    .mousedown(fn(e) { ... })
    .mousemove(fn(e) { ... })
    .mouseup(fn(e) { ... }),
)

// または FFI で直接設定が必要な場合も
add_event_listener_ffi(el, "wheel", fn(e) { ... })
```

### 提案: より多くのイベントタイプをサポート

```moonbit
// 現状サポートされていないイベント
events()
  .wheel(fn(e) { ... })           // ホイールイベント
  .contextmenu(fn(e) { ... })     // 右クリック
  .dblclick(fn(e) { ... })        // ダブルクリック
  .keydown(fn(e) { ... })         // キーダウン
  .keyup(fn(e) { ... })           // キーアップ
  .focus(fn(e) { ... })           // フォーカス
  .blur(fn(e) { ... })            // ブラー

// 汎用イベント設定
events().on("wheel", fn(e) { ... })
```

---

## 7. Signal 依存関係の可視化

### 問題

複雑なアプリでは、どの Signal がどの effect をトリガーするか追跡が困難：

```moonbit
// どの signal の変更が effect を発火させるか不明確
let _ = @luna.effect(fn() {
  let a = sig_a.get()
  if some_condition {
    let b = sig_b.get()  // 条件によって依存関係が変わる
  }
  let c = sig_c.get()
  // ...
})
```

### 提案: デバッグモード

```moonbit
// 開発時のみ有効なデバッグ情報
@luna.debug_effect("redraw_svg", fn() {
  let _ = state.elements.get()
  let _ = state.selected_ids.get()
  redraw()
})
// コンソールに依存関係が出力される:
// [Luna Debug] Effect "redraw_svg" depends on: [elements, selected_ids]
// [Luna Debug] Effect "redraw_svg" triggered by: elements
```

---

## 8. ドキュメントの改善提案

### 必要なドキュメント

1. **パターンカタログ**
   - Signal を使った状態管理パターン
   - Effect の初回スキップパターン
   - 外部 DOM 統合パターン
   - リスト最適化パターン

2. **パフォーマンスガイド**
   - Signal 更新の最適化
   - Effect の依存関係最小化
   - For/Show の使い分け
   - 大量要素のレンダリング

3. **API リファレンス強化**
   - 各関数の具体的な使用例
   - 返り値の型と挙動の詳細
   - エラー時の挙動

4. **マイグレーションガイド**
   - React/Solid.js からの移行
   - 同等の機能の対応表

---

## 9. For/リストレンダリングの最適化

### 問題

要素リストの部分更新時、全体が再レンダリングされる：

```moonbit
// 1つの要素を更新しただけで、全リストが再レンダリング
state.elements.update(fn(els) {
  els.map(fn(e) {
    if e.id == target_id {
      { ..e, x: new_x }  // 1要素だけ変更
    } else {
      e
    }
  })
})
```

### 提案: キーベースの差分更新

```moonbit
// キーを指定して差分更新を最適化
for_keyed(
  fn() { state.elements.get() },
  key=fn(el) { el.id },  // 一意なキー
  fn(el) { render_element(el) },
)
```

---

## 10. 提案の優先度

| 優先度 | 提案 | 理由 |
|--------|------|------|
| 高 | 2B: transaction API | パフォーマンス最適化の基盤 |
| 高 | 6: イベントタイプ拡充 | wheel, contextmenu は必須レベル |
| 高 | 8.1: パターンカタログ | 学習コストを下げる |
| 中 | 1B: イベントユーティリティ | 冗長なコードを削減 |
| 中 | 4C: show_some | Option 処理の簡略化 |
| 中 | 5A: スタイルマージ | よく使うパターン |
| 中 | 9: for_keyed | 大規模リストのパフォーマンス |
| 低 | 3: IME 対応 | 日本語圏向け、FFI で対応可能 |
| 低 | 7: デバッグモード | 開発時のみ必要 |

---

## 参考: Moonlight での FFI ワークアラウンド一覧

proposal-luna.md と合わせて、FFI で対応している機能の一覧：

| 機能 | FFI 関数 | 提案される解決策 |
|------|----------|------------------|
| SVG 要素作成 | `create_svg_element_ffi` | create_element_ns |
| SVG 属性設定 | `set_svg_attr_ffi` | - |
| viewBox 更新 | `update_viewbox_ffi` | - |
| 背景色更新 | `update_svg_background_ffi` | - |
| CSS 変数更新 | `update_svg_css_vars_ffi` | - |
| dataset 取得 | `get_closest_data_id_ffi` | get_data_attr |
| textarea 作成 | `create_textarea_ffi` | IME 対応 input |
| キーリスナー | `add_keydown_listener` | events().keydown |
| ホイールリスナー | （main.mbt で直接処理） | events().wheel |
| ファイルダウンロード | `download_file` | - |
| multiline テキスト | `set_multiline_text_ffi` | - |

これらの FFI 関数のうち、Luna 本体に取り込むべきものは上記の優先度表に従って検討すべき。
