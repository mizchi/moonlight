// Command - Undo/Redo のためのコマンドパターン実装
// 純粋なデータ構造のみ（apply/unapply は EditorState に依存するため src に残す）

///|
/// 操作コマンド（各操作の実行と取り消しを表現）
pub(all) enum Command {
  /// 要素を追加
  AddElement(Element)
  /// 要素を削除 (element, 削除時の位置)
  /// SVG では文書順がそのまま描画順なので、位置を覚えておかないと Undo で
  /// 戻したときに重なり順が変わってしまう。
  RemoveElement(Element, Int)
  /// 要素を移動 (id, from_x, from_y, to_x, to_y)
  MoveElement(String, Double, Double, Double, Double)
  /// 要素をリサイズ (id, old_shape, new_shape)
  ResizeElement(String, ShapeType, ShapeType)
  /// 要素の順序を変更 (id, from_index, to_index)
  ReorderElement(String, Int, Int)
  /// スタイルを更新 (id, old_style, new_style)
  UpdateStyle(String, Style, Style)
  /// 要素のIDを変更 (old_id, new_id)
  RenameElement(String, String)
  /// テキスト内容を更新 (id, old_content, new_content)
  UpdateText(String, String, String)
  /// 複数の操作をひとまとめにする
  /// 一回の操作で複数の要素が変わるとき（ラベル付き図形の削除、複数選択の複製）
  /// に使う。これが無いと Undo 一回で半分だけ戻る。
  Batch(Array[Command])
  /// 要素一式を差し替える (操作前, 操作後)
  /// ドラッグやキーボードでの移動は、線の片方の端点だけ・連れて動く図形・
  /// 張り替わった接続と、一度に何か所も変わる。個々の変更を相対的なコマンドで
  /// 積むと、再生したときに連れて動く処理が二重にかかったり、接続の張り替えが
  /// 戻らなかったりする。前後の状態そのものを積めば Undo / Redo は必ず元に戻る。
  ReplaceElements(Array[Element], Array[Element])
} derive(Debug, Eq)

///|
/// 履歴管理
pub(all) struct History {
  undo_stack : Array[Command]
  redo_stack : Array[Command]
}

///|
/// 履歴を作成
pub fn History::new() -> History {
  { undo_stack: [], redo_stack: [], }
}

///|
/// Undo 可能かどうか
pub fn History::can_undo(self : History) -> Bool {
  self.undo_stack.length() > 0
}

///|
/// Redo 可能かどうか
pub fn History::can_redo(self : History) -> Bool {
  self.redo_stack.length() > 0
}
