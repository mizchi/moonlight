# TODO

- [x] イベントハンドラのモバイル対応 (Pointer Events + ピンチズーム)
- [x] 文字のフォント選択
- [ ] 形状をAIに読ませてメタ情報を注入できるようにする
  - title, desc 対応
- [x] stroke width のデフォルトを1に
- [x] 線と矢印の分離
- [ ] すでに矢印が結ばれてアンカーの位置にあるテキストがある時、新しいテキストを作らない
- [x] 手書きモード・ベジェ近似
- [ ] ボックス側から矢印側へジョイントする
- [x] ダークモード対応
- [x] キャンバスサイズの指定と境界表示
- [x] ヘッダの修正
- [x] Luna mbt への反映
- [x] 図形コンポーネントへの切り出し, UIを用意する。
- [ ] WebComponents
- [x] SVG Export (Moonlight形式 - data-* 属性でメタデータ埋め込み)
  - Ctrl+S: SVGファイルダウンロード
  - Ctrl+Shift+C: SVGテキストをクリップボードにコピー
  - ツールバーボタン: Export, Copy
- [x] SVG Import (Moonlight形式 + プレーンSVG基本図形対応)
  - Ctrl+Shift+V: クリップボードからインポート
  - ツールバーボタン: Import (ファイル選択ダイアログ)
- [x] IndexedDB による状態保存
  - 起動時に自動読み込み、編集時に自動保存
- [ ] export page を作る
- [x] shift おしながらクリックで複数選択して、移動できる。ツールチップ側には選択中の要素をリストで表示する
- [x] Ctrl-C で選択要素をコピーして、　Ctrl-V で右下にややずらした位置に複製
- [x] Ctrl-A で全要素を選択する
- [x] ヘルプシステム
  - SSOT キーバインド定義 (`src/model/keybindings.mbt`)
  - ヘルプページ (`docs/help.html`)
  - ヘルプボタン UI (右下 ? ボタン、? キーでも開く)
  - `showHelpButton` オプションで非表示可能
- [x] Examples ドキュメント整備
  - HTMLファイルを `examples/` に移動
  - `examples/README.md` 追加

## Icebox

- [ ] Round やCSSによるパラメータを折りたたみで対応する

## Model 層の機能

### Keybindings モジュール (`src/model/keybindings.mbt`) ✓ 統合済み

キーバインドのSSOT（Single Source of Truth）定義。実装とドキュメント双方で参照。

#### 機能一覧

| 関数 | 説明 |
|-----|------|
| `get_keybindings()` | 全キーバインド定義を取得 |
| `get_keybindings_by_category(category)` | カテゴリでフィルタ |
| `find_keybinding_by_action(action)` | アクション名で検索 |
| `match_keybinding(key, ctrl, shift, meta)` | キーイベントに一致するバインドを検索 |
| `keybinding_to_string(kb)` | 表示用文字列に変換 |

#### カテゴリ

- `Tool`: 図形作成 (1-6キー)
- `Edit`: 編集操作 (Delete, Escape, ?)
- `Navigation`: 移動 (矢印キー)
- `Mode`: モード切替 (P, V)

### Validation モジュール (`src/model/validation.mbt`) ✓ 統合済み

要素の操作可能性を検証し、UI層での操作制御に使用。

#### 機能一覧

| 関数 | 説明 |
|-----|------|
| `validate_elements(elements)` | 全要素を検証し ValidationResult を返す |
| `get_element_capability(result, id)` | 要素の操作権限を取得 |
| `is_element_operable(result, id)` | 要素が操作可能か判定 |
| `get_element_issues(result, id)` | 要素の問題リストを取得 |
| `can_add_element(new_el, existing)` | 追加可能か事前チェック |
| `can_delete_element(id, elements)` | 削除可能か事前チェック |
| `suggest_repairs(issues)` | 修復アクションを提案 |

#### 検証項目

- **ID**: 空ID (Error), 重複ID (Error)
- **座標**: NaN/Infinity座標 (Error)
- **親子関係**: 存在しない親 (Warning), 循環参照 (Error)
- **接続**: 孤立した接続 (Warning), 自己接続 (Warning)
- **形状**: 負の寸法 (Error), 同一点Line (Warning), 空テキスト (Info)
- **プレーンSVG**: Moonlight形式でない要素 (移動と削除のみ可)

#### 操作権限 (ElementCapability)

```
can_move      : Bool  // エラーでも true（常に移動可能）
can_resize    : Bool
can_edit      : Bool
can_delete    : Bool  // エラー要素でも true（問題要素を除去可能）
can_connect   : Bool  // Line のみ
can_add_child : Bool
```

#### UI への統合状況

- [x] SVG Import 後に validate してプレーンSVG要素を登録
- [x] 要素選択時に capability に応じてリサイズハンドル表示制御
- [x] コンテキストメニューで capability に応じたスタイル編集制御
- [ ] 削除時に接続/子要素の警告ダイアログ表示
- [ ] 問題のある要素をハイライト表示

### Topology モジュール (`src/model/topology.mbt`)

要素間の接続グラフを構築し、パス探索や接続距離計算を行う。

#### 機能一覧

| 関数 | 説明 |
|-----|------|
| `build_connection_graph(elements)` | 接続グラフを構築 |
| `graph.get_neighbors(id)` | 隣接要素を取得 |
| `graph.are_directly_connected(id1, id2)` | 直接接続判定 |
| `graph.get_connected_component(id)` | 連結成分を取得 |
| `graph.connection_distance(from, to)` | 接続距離（ホップ数） |
| `graph.find_shortest_path(from, to, elements)` | 最短パス探索 |
| `graph.has_cycle()` | サイクル検出 |
| `recalculate_on_partial_move(targets, elements)` | 部分移動時の再計算 |

#### UI への組み込み案

- [ ] 要素選択時に接続されている要素をハイライト
- [ ] グループ選択: 連結成分を一括選択
- [ ] レイアウト自動整列（接続グラフに基づく）
- [ ] 接続パスのビジュアライズ
