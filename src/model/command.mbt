// Command - Undo/Redo のためのコマンドパターン実装
// 純粋なデータ構造のみ（apply/unapply は EditorState に依存するため src に残す）

///|
/// 操作コマンド（各操作の実行と取り消しを表現）
pub(all) enum Command {
  /// 要素を追加
  AddElement(Element)
  /// 要素を削除
  RemoveElement(Element)
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
} derive(Show, Eq)

///|
/// 履歴管理
pub(all) struct History {
  undo_stack : Array[Command]
  redo_stack : Array[Command]
}

///|
/// 履歴を作成
pub fn History::new() -> History {
  { undo_stack: [], redo_stack: [] }
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

// ============================================================
// コマンドの適用（純粋関数）
// ============================================================

///|
/// コマンドの適用結果
pub(all) struct CommandResult {
  elements : Array[Element]
  selected_ids : Array[String]
} derive(Show, Eq)

///|
/// コマンドを適用（純粋関数版）
/// 入力を変更せず、新しい結果を返す
pub fn apply_command_pure(
  command : Command,
  elements : Array[Element],
  selected_ids : Array[String],
) -> CommandResult {
  match command {
    AddElement(element) => {
      let new_els = elements.copy()
      new_els.push(element)
      { elements: new_els, selected_ids }
    }
    RemoveElement(element) => {
      let new_els = elements.filter(fn(el) {
        el.id != element.id && el.parent_id != Some(element.id)
      })
      let new_selected = selected_ids.filter(fn(id) { id != element.id })
      { elements: new_els, selected_ids: new_selected }
    }
    MoveElement(id, _, _, to_x, to_y) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          { ..el, x: to_x, y: to_y }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
    ResizeElement(id, _, new_shape) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          { ..el, shape: new_shape }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
    ReorderElement(id, _, to_idx) => {
      let new_els = reorder_element_in_array(elements, id, to_idx)
      { elements: new_els, selected_ids }
    }
    UpdateStyle(id, _, new_style) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          { ..el, style: new_style }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
    RenameElement(old_id, new_id) => {
      let new_els = elements.map(fn(el) {
        if el.id == old_id {
          { ..el, id: new_id }
        } else {
          el
        }
      })
      let new_selected = selected_ids.map(fn(id) {
        if id == old_id {
          new_id
        } else {
          id
        }
      })
      { elements: new_els, selected_ids: new_selected }
    }
    UpdateText(id, _, new_content) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          match el.shape {
            Text(_, font_size) => { ..el, shape: Text(new_content, font_size) }
            _ => el
          }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
  }
}

///|
/// コマンドを取り消し（純粋関数版）
pub fn unapply_command_pure(
  command : Command,
  elements : Array[Element],
  selected_ids : Array[String],
) -> CommandResult {
  match command {
    AddElement(element) => {
      let new_els = elements.filter(fn(el) { el.id != element.id })
      let new_selected = selected_ids.filter(fn(id) { id != element.id })
      { elements: new_els, selected_ids: new_selected }
    }
    RemoveElement(element) => {
      let new_els = elements.copy()
      new_els.push(element)
      { elements: new_els, selected_ids }
    }
    MoveElement(id, from_x, from_y, _, _) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          { ..el, x: from_x, y: from_y }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
    ResizeElement(id, old_shape, _) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          { ..el, shape: old_shape }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
    ReorderElement(id, from_idx, _) => {
      let new_els = reorder_element_in_array(elements, id, from_idx)
      { elements: new_els, selected_ids }
    }
    UpdateStyle(id, old_style, _) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          { ..el, style: old_style }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
    RenameElement(old_id, new_id) => {
      let new_els = elements.map(fn(el) {
        if el.id == new_id {
          { ..el, id: old_id }
        } else {
          el
        }
      })
      let new_selected = selected_ids.map(fn(id) {
        if id == new_id {
          old_id
        } else {
          id
        }
      })
      { elements: new_els, selected_ids: new_selected }
    }
    UpdateText(id, old_content, _) => {
      let new_els = elements.map(fn(el) {
        if el.id == id {
          match el.shape {
            Text(_, font_size) => { ..el, shape: Text(old_content, font_size) }
            _ => el
          }
        } else {
          el
        }
      })
      { elements: new_els, selected_ids }
    }
  }
}

///|
/// 配列内の要素を指定位置に移動（純粋関数）
fn reorder_element_in_array(
  elements : Array[Element],
  id : String,
  to_index : Int,
) -> Array[Element] {
  let mut from_idx = -1
  for i = 0; i < elements.length(); i = i + 1 {
    if elements[i].id == id {
      from_idx = i
      break
    }
  }
  if from_idx < 0 {
    return elements
  }
  let el = elements[from_idx]
  // 要素を除いた配列を作成
  let without_el : Array[Element] = []
  for i = 0; i < elements.length(); i = i + 1 {
    if i != from_idx {
      without_el.push(elements[i])
    }
  }
  // 正しい位置に挿入
  let insert_idx = if to_index > without_el.length() {
    without_el.length()
  } else if to_index < 0 {
    0
  } else {
    to_index
  }
  let result : Array[Element] = []
  for i = 0; i < without_el.length(); i = i + 1 {
    if i == insert_idx {
      result.push(el)
    }
    result.push(without_el[i])
  }
  if insert_idx >= without_el.length() {
    result.push(el)
  }
  result
}
