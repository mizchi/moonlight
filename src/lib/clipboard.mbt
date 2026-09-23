// コピー / 貼り付け - スタンドアロンと埋め込みで同じものを使う
//
// SVG テキストのクリップボード（Ctrl+Shift+C/V）とは別で、こちらはエディタ内部
// に要素そのものを持つ。ページ内に複数のエディタがあれば、片方でコピーして
// もう片方に貼れる。

///|
/// エディタ内クリップボード（要素そのものを持つ）
let clipboard : Ref[Array[@model.Element]] = { val: [], }

///|
/// 選択中の要素と、その子要素（ラベルなど）を集める
fn collect_selection(state : @core.EditorState) -> Array[@model.Element] {
  let out : Array[@model.Element] = []
  let push = fn(el : @model.Element) {
    if !out.iter().any(fn(e) { e.id == el.id }) {
      out.push(el)
    }
  }
  for id in state.selected_ids.get() {
    guard state.find_element(id) is Some(el) else { continue }
    push(el)
    // 子要素（ラベルなど）も一緒に持っていく
    for child in state.get_children(id) {
      push(child)
    }
  }
  out
}

///|
/// 選択中の要素（と子要素）をクリップボードに取る
pub fn copy_selection(state : @core.EditorState) -> Unit {
  clipboard.val = collect_selection(state)
}

///|
/// クリップボードの中身を右下に少しずらして貼る
pub fn paste_clipboard(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> Unit {
  add_copies(state, history, new_id, clipboard.val)
}

///|
/// 要素の組の写しを、新しい ID で右下に少しずらして置く（貼り付け・複製）
///
/// 親子関係と線の接続は、一緒に写した要素どうしなら新しい ID に張り替える。
/// 写さなかった要素への接続は外す。元の要素を指したままだと、ずらして置いた
/// 線は結合先から浮いたうえ、元の要素を動かすとそこへ飛んでいってしまう。
/// 一回の操作なので、Undo も一回で全部消えるように Batch でまとめる。
pub fn add_copies(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
  source : Array[@model.Element],
) -> Unit {
  guard source.length() > 0 else { return }
  let offset = 20.0
  // まず全要素の新しい ID を決めてから、参照を張り替える
  let id_map : Array[(String, String)] = []
  for el in source {
    id_map.push((el.id, new_id()))
  }
  let copied_id = fn(old_id : String) -> String? {
    for mapping in id_map {
      let (o, n) = mapping
      if o == old_id {
        return Some(n)
      }
    }
    None
  }
  let remap_connection = fn(conn : @model.Connection?) -> @model.Connection? {
    guard conn is Some(c) else { return None }
    match copied_id(c.element_id) {
      Some(n) => Some({ element_id: n, anchor: c.anchor, })
      // 写していない要素への接続は外す
      None => None
    }
  }
  let added : Array[@model.Command] = []
  let new_ids : Array[String] = []
  for el in source {
    let new_el_id = copied_id(el.id).unwrap_or(el.id)
    // 親を一緒に写していなければ、元の親のラベルとして残す（従来どおり）
    let new_parent_id = match el.parent_id {
      Some(pid) => Some(copied_id(pid).unwrap_or(pid))
      None => None
    }
    let new_connections : @model.LineConnections? = match el.connections {
      Some(conns) => {
        let start = remap_connection(conns.start)
        let end = remap_connection(conns.end)
        if start is None && end is None {
          None
        } else {
          Some({ start, end, })
        }
      }
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
