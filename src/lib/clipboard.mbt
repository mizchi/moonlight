// コピー / 貼り付け - スタンドアロンと埋め込みで同じものを使う
//
// SVG テキストのクリップボード（Ctrl+Shift+C/V）とは別で、こちらはエディタ内部
// に要素そのものを持つ。ページ内に複数のエディタがあれば、片方でコピーして
// もう片方に貼れる。

///|
/// エディタ内クリップボード（要素そのものを持つ）
let clipboard : Ref[Array[@model.Element]] = { val: [], }

///|
/// 選択中の要素（と子要素）をクリップボードに取る
pub fn copy_selection(state : @core.EditorState) -> Unit {
  let copied : Array[@model.Element] = []
  for id in state.selected_ids.get() {
    guard state.find_element(id) is Some(el) else { continue }
    copied.push(el)
    // 子要素（ラベルなど）も一緒に持っていく
    for child in state.get_children(id) {
      copied.push(child)
    }
  }
  clipboard.val = copied
}

///|
/// クリップボードの中身を右下に少しずらして貼る
///
/// 親子関係と線の接続は、貼った側の新しい ID に張り替える。貼り付けは一回の
/// 操作なので、Undo も一回で全部消えるように Batch でまとめる。
pub fn paste_clipboard(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  guard clipboard.val.length() > 0 else { return }
  let offset = 20.0
  // まず全要素の新しい ID を決めてから、参照を張り替える
  let id_map : Array[(String, String)] = []
  for el in clipboard.val {
    id_map.push((el.id, new_id()))
  }
  let find_new_id = fn(old_id : String) -> String {
    for mapping in id_map {
      let (o, n) = mapping
      if o == old_id {
        return n
      }
    }
    old_id
  }
  let remap_connection = fn(conn : @model.Connection?) -> @model.Connection? {
    match conn {
      Some(c) =>
        Some({ element_id: find_new_id(c.element_id), anchor: c.anchor, })
      None => None
    }
  }
  let added : Array[@model.Command] = []
  let new_ids : Array[String] = []
  for el in clipboard.val {
    let new_el_id = find_new_id(el.id)
    let new_parent_id = match el.parent_id {
      Some(pid) => Some(find_new_id(pid))
      None => None
    }
    let new_connections : @model.LineConnections? = match el.connections {
      Some(conns) =>
        Some({
          start: remap_connection(conns.start),
          end: remap_connection(conns.end),
        })
      None => None
    }
    let new_el = {
      ..el,
      id: new_el_id,
      x: el.x + offset,
      y: el.y + offset,
      parent_id: new_parent_id,
      connections: new_connections,
    }
    // Line は終点も一緒にずらさないと形が変わる
    let final_el = match new_el.shape {
      @model.Line(x2, y2) =>
        { ..new_el, shape: @model.Line(x2 + offset, y2 + offset), }
      _ => new_el
    }
    state.add_element_raw(final_el)
    added.push(@model.AddElement(final_el))
    // 子要素は親と一緒に動くので、選択には入れない
    if new_parent_id is None {
      new_ids.push(new_el_id)
    }
  }
  guard added.length() > 0 else { return }
  history.undo_stack.push(@model.Batch(added))
  history.redo_stack.clear()
  state.select_multiple(new_ids)
}
