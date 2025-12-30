# Free Draw - ベジェ曲線近似プロトタイプ

フリーハンド描画をベジェ曲線に近似し、編集可能にするプロトタイプ実装。
Moonlight エディタへの組み込みを想定。

## 目的

- ペンツールでの描画をスムーズなベジェ曲線に変換
- 描画後にアンカーポイント・コントロールポイントを編集可能に
- データサイズの圧縮（生の座標列 → ベジェセグメント）

## アルゴリズム

### パイプライン

```
Raw Points → Resample → RDP Simplify → Bezier Fit → SVG Path
```

1. **Resample**: pointermove の取得頻度のバラつきを均一化
2. **RDP (Ramer-Douglas-Peucker)**: 点列を簡略化
3. **Bezier Fit (Schneider Algorithm)**: 3次ベジェ曲線にフィット
4. **SVG Path**: `M ... C ...` 形式に変換

### パラメータ

| パラメータ | デフォルト | 説明 |
|-----------|-----------|------|
| `min_resample_dist` | 4.0 | リサンプリング最小距離 |
| `epsilon` | 2.0 | RDP 簡略化の許容誤差 |
| `max_error` | 8.0 | ベジェフィットの最大誤差 |

## データ構造

### BezierSegment

```moonbit
pub(all) struct BezierSegment {
  p0 : Point  // 始点（アンカー）
  c1 : Point  // 制御点1
  c2 : Point  // 制御点2
  p3 : Point  // 終点（アンカー）
}
```

### PathData（デモ用）

```moonbit
priv struct PathData {
  segments : Array[@bezier.BezierSegment]
}
```

## インタラクション

### 描画

- `pointerdown`: 描画開始
- `pointermove`: 座標を収集
- `pointerup`: ベジェ近似を実行、確定

### 編集

| 操作 | 対象 | 動作 |
|------|------|------|
| ホバー | パス | コントロールポイントを表示 |
| ドラッグ | アンカーポイント (P0/P3) | 位置を移動、隣接セグメントも同期 |
| ドラッグ | コントロールポイント (C1/C2) | ハンドルを移動 |
| ドラッグ | パス本体 | パス全体を移動 |

### Hit Area

- 透明な太いストローク（20px）で当たり判定を拡大
- `pointer-events: stroke` で線上のみ反応

## API（bezier_fit モジュール）

### 主要関数

```moonbit
// 統合関数: 点列 → SVG path
fn approximate(raw_points: Array[Point], options: Options) -> String

// 個別ステップ
fn resample(points: Array[Point], min_dist: Double) -> Array[Point]
fn rdp_simplify(points: Array[Point], epsilon: Double) -> Array[Point]
fn fit_bezier(points: Array[Point], max_error: Double) -> Array[BezierSegment]
fn to_svg_path(segments: Array[BezierSegment]) -> String

// ユーティリティ
fn bezier_point(seg: BezierSegment, t: Double) -> Point
fn is_closed_path(points: Array[Point], threshold: Double) -> Bool
```

## エディタ統合時の検討事項

### 必要な拡張

- [ ] 閉じたパスの処理（始点と終点を結合）
- [ ] Undo/Redo 対応
- [ ] 複数パスの選択・グループ化
- [ ] スタイル（stroke, fill, width）の適用

### データモデル

```moonbit
// エディタ統合時の Element 定義案
pub struct PathElement {
  id : String
  segments : Array[BezierSegment]
  style : PathStyle
  closed : Bool
}
```

### パフォーマンス

- 描画中はリアルタイムでプレビュー表示（未圧縮）
- 確定時のみベジェ近似を実行
- 編集時は差分のみ再計算

## ファイル構成

```
src/
├── bezier_fit/
│   ├── bezier_fit.mbt      # アルゴリズム実装
│   ├── bezier_fit_test.mbt # テスト
│   └── moon.pkg.json       # 依存なし、独立モジュール
└── free-draw/
    ├── entry.mbt           # デモアプリケーション
    ├── moon.pkg.json
    └── spec.md             # この文書

free-draw.html              # デモ HTML
free-draw.ts                # Vite エントリ
```

## 今後の機能追加

### 編集機能

- [ ] **アンカーポイントの削除**: 不要なアンカーを削除し、隣接セグメントを再計算
- [ ] **中間アンカーの追加**: パス上の任意の位置にアンカーポイントを挿入
- [ ] **形状の再計算**: 選択範囲を点列に戻してベジェ近似をやり直す
- [ ] **許容度の再計算**: epsilon/max_error を変更して再フィット

### パス操作

- [ ] **マージ**: 異なるパスのアンカーポイント同士を接続して1つのパスに結合
- [ ] **切り離し**: アンカーポイントでパスを分割、2つの独立したパスに

### 実装メモ

```
削除: segments[i] を削除 → segments[i-1].p3 と segments[i+1].p0 を再接続
追加: bezier_point(seg, t) で分割点を計算 → de Casteljau で2セグメントに分割
マージ: path_a.segments[-1].p3 == path_b.segments[0].p0 なら結合
切り離し: アンカーで split → 2つの PathData に分離
```

## 参考

- [Schneider Algorithm](https://pomax.github.io/bezierinfo/#curvefitting) - ベジェフィットの元論文
- [Ramer-Douglas-Peucker](https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm) - 点列簡略化
- [de Casteljau's Algorithm](https://pomax.github.io/bezierinfo/#decasteljau) - ベジェ曲線の分割
