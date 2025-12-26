# Moonlight SVG Editor - 仕様書

MoonBit + Luna で実装する軽量 SVG エディタの仕様。

## 概要

- **目標**: Excalidraw 風の軽量 SVG エディタ
- **技術スタック**: MoonBit, Luna (Signal-based UI), SVG
- **ユースケース**: WYSIWYG エディタへの組み込み

## キャンバス

| 項目 | 仕様 |
|------|------|
| サイズ | 800 x 600 px（固定） |
| 背景 | #fafafa |
| 枠線 | 1px solid #ccc |

## 図形タイプ

### 実装済み

| タイプ | パラメータ | 説明 |
|--------|------------|------|
| `Rect` | width, height, rx?, ry? | 矩形（角丸オプション） |
| `Circle` | radius | 円 |

### 未実装（データモデルのみ）

| タイプ | パラメータ | 説明 |
|--------|------------|------|
| `Ellipse` | rx, ry | 楕円 |
| `Line` | x2, y2 | 線分 |
| `Polyline` | points | 折れ線 |
| `Path` | d | SVG パス |
| `Text` | content, fontSize? | テキスト |

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
| 図形を右クリック | メニュー表示（Delete アクション） |
| 空白を右クリック | メニュー表示（"No element selected"） |
| Delete クリック | 対象図形を削除 |
| 左クリック | メニューを閉じる |

## ボタン

| ボタン | 動作 |
|--------|------|
| Add Rectangle | 紫の矩形を追加（位置はオフセット） |
| Add Circle | 赤い円を追加（位置はオフセット） |

## 状態管理

Signal ベースのリアクティブ状態管理:

```
EditorState
├── elements: Signal[Array[Element]]   # 要素リスト
├── selected_id: Signal[String?]       # 選択中の要素 ID
├── drag_state: Signal[DragState?]     # ドラッグ状態
├── context_menu: Signal[ContextMenu?] # コンテキストメニュー
└── viewport: Signal[Viewport]         # ビューポート（未使用）
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

### Viewport（将来用）

```moonbit
pub struct Viewport {
  scroll_x : Double  // スクロール X
  scroll_y : Double  // スクロール Y
  zoom : Double      // ズーム倍率 (1.0 = 100%)
}
```

## テスト

E2E テスト (Playwright): 22 件

| カテゴリ | テスト数 |
|----------|----------|
| 基本表示 | 5 |
| 選択 | 1 |
| 図形追加 | 2 |
| ドラッグ | 1 |
| コンテキストメニュー | 4 |
| Undo/Redo | 5 |
| リサイズ | 3 |
| デバッグ | 1 |

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

- [ ] キーボードショートカット (Delete, Escape)
- [ ] 複製 (Ctrl+D)
- [x] Undo/Redo
- [x] 図形のリサイズ
- [ ] 図形の回転

### Phase 3: 拡張図形

- [ ] 楕円
- [ ] 線分
- [ ] 折れ線
- [ ] パス
- [ ] テキスト

### Phase 4: 高度な機能

- [ ] 複数選択
- [ ] グループ化
- [ ] レイヤー順序変更
- [ ] ズーム/パン
- [ ] グリッドスナップ
- [ ] SVG エクスポート
