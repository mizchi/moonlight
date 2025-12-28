# Moonlight 仕様書

MoonBit + luna ライブラリで実装した軽量 SVG エディタ。

## 基本機能

### 図形

- **Rect**: 矩形。角丸 (rx, ry) 対応
- **Circle**: 円
- **Ellipse**: 楕円
- **Line**: 線分。接続機能あり
- **Polyline**: 折れ線
- **Path**: SVG パス
- **Text**: テキスト。フォントサイズ調整可能

### 操作

- **選択**: クリックで単一選択、矩形ドラッグで複数選択
- **移動**: ドラッグで移動、矢印キーで微調整
- **リサイズ**: 選択ハンドルをドラッグ、Shift+矢印キーで微調整
- **コピー&ペースト**: Ctrl+C / Ctrl+V
- **全選択**: Ctrl+A
- **削除**: Delete/Backspace キー

### グリッドスナップ

- 10px グリッドへの自動スナップ
- トグルで ON/OFF 切り替え

## 接続機能

### アンカーポイント

図形には以下のアンカーが定義されている:

| 図形タイプ | アンカー |
|-----------|---------|
| Rect, Text | Center, Top, Bottom, Left, Right, TopLeft, TopRight, BottomLeft, BottomRight |
| Circle, Ellipse | Center, Top, Bottom, Left, Right |
| Line | LineStart, LineEnd |

### Line の接続

- Line の端点 (始点/終点) を他の図形のアンカーに接続可能
- 接続された図形を移動すると、接続された Line も自動追従
- **Line 同士の接続**: Line の端点を別の Line の端点に接続可能

### トポロジー検出 (Line-to-Line)

Line 同士が接続されている場合、移動時に接続グラフをたどって影響範囲を計算する。

```
例: 三角形
A.end → B.start
B.end → C.start
C.end → A.start

A を移動すると、B と C の座標も更新される
```

**実装**: `compute_line_move_topology()` が BFS で接続グラフを走査し、更新が必要な Line の新座標を計算。

**既知の問題**: 一部のノードが移動できなくなるケースがある（未解決）。

## スタイル

### 属性

- `fill`: 塗りつぶし色
- `stroke`: 線の色
- `stroke_width`: 線の太さ
- `opacity`: 不透明度
- `stroke_dasharray`: 破線パターン
- `marker_start` / `marker_end`: 矢印の種類

### 矢印

- `NoArrow`: 矢印なし
- `Arrow`: 標準の矢印

### プリセットカラー

Black, Gray, Red, Orange, Yellow, Green, Blue, Purple の 8 色。ライトモード/ダークモードで異なる色値。

## テーマ

### ライトモード

- 背景: `#ffffff`
- ストローク: `#000000`
- テキスト: `#000000`

### ダークモード

- 背景: `#1a1a1a`
- ストローク: `#ffffff`
- テキスト: `#ffffff`

CSS 変数 (`--ml-stroke`, `--ml-fill`, `--ml-text`) でテーマ切り替えに対応。

## UI

### ツールバー

- 図形選択 (ショートカット: 1-6)
- グリッドスナップトグル

### コンテキストメニュー

右クリックで表示:
- 図形の追加
- 削除
- 前面/背面への移動
- カラー変更

### パネル

- 要素プロパティの編集
- スタイル設定

## 永続化

### IndexedDB

編集状態を IndexedDB に自動保存。ページリロード後も状態を復元。

## インポート/エクスポート

### SVG エクスポート

現在のシーンを SVG ファイルとしてダウンロード。

### SVG インポート

SVG ファイルを読み込んでシーンに追加。

## 座標系

### Viewport

- `scroll_x`, `scroll_y`: スクロール位置
- `zoom`: ズーム率 (1.0 = 100%)

### 座標変換

- **画面 → シーン**: `screen_to_scene()`
- **シーン → 画面**: `scene_to_screen()`

## データモデル

### Element

```moonbit
pub(all) struct Element {
  id : String
  x : Double
  y : Double
  shape : ShapeType
  style : Style
  transform : String?
  parent_id : String?         // グループ化用
  connections : LineConnections?  // Line の接続情報
}
```

### LineConnections

```moonbit
pub(all) struct LineConnections {
  start : Connection?  // 始点の接続
  end : Connection?    // 終点の接続
}

pub(all) struct Connection {
  element_id : String  // 接続先の要素 ID
  anchor : Anchor      // 接続点の位置
}
```

## 開発履歴（主要機能）

| コミット | 機能 |
|---------|------|
| `923d028` | Line 接続のトポロジー検出を実装 |
| `21a8a8f` | IndexedDB による編集状態の永続化 |
| `112f635` | SVG Export/Import 機能を追加 |
| `404a996` | 複数選択、コピー&ペースト、全選択機能を追加 |
| `b2d672a` | アンカークリックで Arrow 作成、接続ポイント表示改善 |
| `d4d7100` | UI 全体のダークモード対応 |
| `52d8050` | テキスト編集機能を修正 |
| `e7e1503` | Shift+矢印キーで選択要素をリサイズ |
| `53bf1ee` | 埋め込みモード・モーダルエディタを実装 |
