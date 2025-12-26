# Moonlight SVG Editor - 仕様書

MoonBit + Luna で実装する軽量 SVG エディタの仕様。

## 概要

- **目標**: Excalidraw 風の軽量 SVG エディタ
- **技術スタック**: MoonBit, Luna (Signal-based UI), SVG
- **ユースケース**: WYSIWYG エディタへの組み込み

## キャンバス

| 項目 | 仕様 |
|------|------|
| サイズ | 400 x 300 px（固定） |
| 背景 | #fafafa |
| 枠線 | 1px solid #ccc |

## 図形タイプ

| タイプ | パラメータ | 説明 | 状態 |
|--------|------------|------|------|
| `Rect` | width, height, rx?, ry? | 矩形（角丸オプション） | ✅ |
| `Circle` | radius | 円 | ✅ |
| `Ellipse` | rx, ry | 楕円 | ✅ |
| `Line` | x2, y2 | 線分 | ✅ |
| `Text` | content, fontSize? | テキスト | ✅ |
| `Polyline` | points | 折れ線 | skip |
| `Path` | d | SVG パス | skip |

## スタイル属性

| 属性 | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `fill` | String? | None | 塗りつぶし色 |
| `stroke` | String? | "#000000" | 線の色 |
| `stroke_width` | Double? | 1.0 | 線の太さ |
| `opacity` | Double? | None | 不透明度 (0.0-1.0) |

## インタラクション

### 選択

| 操作 | 動作 |
|------|------|
| 図形を左クリック | その図形を選択 |
| 空白を左クリック | 選択解除 |
| 選択状態の表示 | 青いストローク (#0066ff) + 線幅 +1 |

### ドラッグ移動

| 操作 | 動作 |
|------|------|
| 図形を左クリック＆ドラッグ | 図形を移動 |
| マウスアップ | ドラッグ終了 |

### コンテキストメニュー

| 操作 | 動作 |
|------|------|
| 図形を右クリック | メニュー表示 |
| 空白を右クリック | "No element selected" 表示 |
| Bring to Front | 図形を最前面に移動 |
| Send to Back | 図形を最背面に移動 |
| Delete | 対象図形を削除 |
| 左クリック | メニューを閉じる |

## ツールバー

| ボタン | 動作 |
|--------|------|
| Add Rectangle | 紫の矩形を追加 |
| Add Circle | 赤い円を追加 |
| Add Ellipse | ティール色の楕円を追加 |
| Add Line | 紫の線分を追加 |
| Add Text | "Hello" テキストを追加 |
| Undo | 操作を取り消し |
| Redo | 操作をやり直し |
| Export SVG | SVG ファイルをダウンロード |
| -/+/Reset | ズーム操作 |
| Grid Snap | グリッドスナップの切り替え |

## キーボードショートカット

| キー | 動作 |
|------|------|
| Delete / Backspace | 選択中の図形を削除 |
| Escape | 選択解除 |
| Ctrl+D / Cmd+D | 図形を複製 |
| Ctrl+Z / Cmd+Z | Undo |
| Ctrl+Y / Cmd+Y | Redo |
| マウスホイール | ズーム |
| Space + ドラッグ | パン（キャンバス移動） |

## 状態管理

Signal ベースのリアクティブ状態管理:

```
EditorState
├── elements: Signal[Array[Element]]   # 要素リスト
├── selected_id: Signal[String?]       # 選択中の要素 ID
├── drag_state: Signal[DragState?]     # ドラッグ状態
├── resize_state: Signal[ResizeState?] # リサイズ状態
├── context_menu: Signal[ContextMenu?] # コンテキストメニュー
├── viewport: Signal[Viewport]         # ビューポート (ズーム/パン)
├── grid_enabled: Signal[Bool]         # グリッドスナップ有効
├── grid_size: Signal[Int]             # グリッドサイズ (20px)
├── is_panning: Signal[Bool]           # パン中かどうか
└── pan_start: Signal[(Double,Double)?] # パン開始位置
```

## データモデル

### Element

```moonbit
pub struct Element {
  id : String        // 一意な識別子
  x : Double         // 基準 X 座標
  y : Double         // 基準 Y 座標
  shape : ShapeType  // 図形タイプ
  style : Style      // スタイル属性
  transform : String? // SVG transform
}
```

### Viewport

```moonbit
pub struct Viewport {
  scroll_x : Double  // スクロール X
  scroll_y : Double  // スクロール Y
  zoom : Double      // ズーム倍率 (1.0 = 100%, 範囲: 25% - 400%)
}
```

## テスト

E2E テスト (Playwright): 38 件

| カテゴリ | テスト数 |
|----------|----------|
| 基本表示 | 6 |
| 選択 | 1 |
| 図形追加 | 5 |
| ドラッグ | 1 |
| コンテキストメニュー | 6 |
| Undo/Redo | 5 |
| リサイズ | 3 |
| キーボード | 4 |
| ズーム | 4 |
| グリッド | 1 |
| デバッグ | 2 |

---

## Undo/Redo 設計

### コマンドパターン

各操作を `Command` として表現し、履歴スタックで管理する。

```moonbit
pub enum Command {
  AddElement(Element)           // 要素追加
  RemoveElement(Element)        // 要素削除
  MoveElement(String, Point, Point)  // 移動 (id, from, to)
  ResizeElement(String, ShapeType, ShapeType)  // リサイズ (id, old, new)
  // 将来: ChangeStyle, Rotate, Group, etc.
}
```

### 履歴管理

```moonbit
pub struct History {
  undo_stack : Array[Command]  // 取り消し可能な操作
  redo_stack : Array[Command]  // やり直し可能な操作
}
```

### 操作フロー

```
[操作実行]
  ↓
execute(command)
  ↓
undo_stack.push(command)
redo_stack.clear()

[Undo]
  ↓
command = undo_stack.pop()
command.undo()
redo_stack.push(command)

[Redo]
  ↓
command = redo_stack.pop()
command.execute()
undo_stack.push(command)
```

---

## リサイズ設計

### リサイズハンドル

選択中の図形の四隅にハンドルを表示。

```
┌─[nw]───────[ne]─┐
│                 │
│     Element     │
│                 │
└─[sw]───────[se]─┘
```

### ハンドル仕様

| 項目 | 仕様 |
|------|------|
| サイズ | 8 x 8 px |
| 色 | #0066ff |
| カーソル | nwse-resize, nesw-resize |

### ドラッグ処理

| ハンドル | X 方向 | Y 方向 |
|----------|--------|--------|
| NW | x を変更, width を逆方向に変更 | y を変更, height を逆方向に変更 |
| NE | width を変更 | y を変更, height を逆方向に変更 |
| SW | x を変更, width を逆方向に変更 | height を変更 |
| SE | width を変更 | height を変更 |

---

## TODO

### Phase 1: 基本機能

- [x] キャンバス表示
- [x] 矩形・円の表示
- [x] 図形の選択
- [x] ドラッグ移動
- [x] 図形の追加（ボタン）
- [x] 右クリックメニュー
- [x] 図形の削除

### Phase 2: 編集機能

- [x] キーボードショートカット (Delete, Escape, Ctrl+Z/Y)
- [x] 複製 (Ctrl+D)
- [x] Undo/Redo
- [x] 図形のリサイズ
- [ ] skip: 図形の回転 (Excalidrawのような簡単な図形編集するだけなら不要)
- [x] 要素の詳細のサイドバーを表示

### Phase 3: 拡張図形

- [x] 楕円
- [x] 線分
- [ ] skip: 折れ線 => インタラクションが複雑
- [ ] skip: パス => path d は複雑だしUIとして設計が難しい
- [x] テキスト

### Phase 4: 高度な機能

- [ ] 複数選択
- [ ] グループ化
- [x] レイヤー順序変更 (Bring to Front / Send to Back)
- [x] ズーム/パン (ホイール、ボタン)
- [x] グリッドスナップ
- [x] SVG エクスポート
