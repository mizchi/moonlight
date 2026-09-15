// 操作セッションの状態遷移
//
// Press -> MoveTo* -> Release / Cancel という一本の流れだけを扱う。
// どのジェスチャに入るかは Press が掴んだ Target だけで決まる。

///|
/// 入力をひとつ適用した新しいセッションを返す（純粋関数）
pub fn Session::step(self : Session, input : Input) -> Session {
  match input {
    Press(target, point) => self.press(target, point)
    MoveTo(point) => self.move_to(point)
    Release => self.release()
    Cancel => self.cancel()
  }
}

///|
/// 入力列をまとめて適用する
pub fn Session::run(self : Session, inputs : Array[Input]) -> Session {
  let mut session = self
  for input in inputs {
    session = session.step(input)
  }
  session
}

///|
/// シーンに入力列を適用した結果のシーンを返す（テスト用の近道）
pub fn Scene::play(self : Scene, inputs : Array[Input]) -> Scene {
  Session::start(self).run(inputs).scene
}

// =============================================================================
// Press
// =============================================================================

///|
fn Session::press(
  self : Session,
  target : Target,
  point : @model.Point,
) -> Session {
  // 進行中のジェスチャがあれば先に確定させる
  let base = if self.is_active() { self.release() } else { self }
  let snapshot = base.scene.elements
  match target {
    Canvas =>
      {
        scene: { ..base.scene, selection: [], },
        gesture: BoxSelecting({
          start_x: point.x,
          start_y: point.y,
          current_x: point.x,
          current_y: point.y,
        }),
        pending: None,
        snapshot: Some(snapshot),
      }
    Body(id) => {
      guard base.scene.find(id) is Some(el) else { return base }
      {
        scene: { ..base.scene, selection: [id], },
        gesture: Moving({
          element_id: id,
          offset_x: point.x - el.x,
          offset_y: point.y - el.y,
        }),
        pending: None,
        snapshot: Some(snapshot),
      }
    }
    Handle(id, handle) => {
      guard base.scene.find(id) is Some(el) else { return base }
      {
        scene: { ..base.scene, selection: [id], },
        gesture: Resizing({
          element_id: id,
          handle,
          start_x: el.x,
          start_y: el.y,
          start_shape: el.shape,
          mouse_start: point,
        }),
        pending: None,
        snapshot: Some(snapshot),
      }
    }
  }
}

// =============================================================================
// MoveTo
// =============================================================================

///|
fn Session::move_to(self : Session, point : @model.Point) -> Session {
  match self.gesture {
    Idle => self
    Moving(g) => {
      let target : @model.Point = {
        x: self.scene.grid.snap(point.x - g.offset_x),
        y: self.scene.grid.snap(point.y - g.offset_y),
      }
      let elements = @model.move_element_with_relations(
        self.scene.elements,
        g.element_id,
        target.x,
        target.y,
      )
      { ..self, scene: { ..self.scene, elements, }, }
    }
    Resizing(g) => {
      guard resize(self.scene, g, point) is Some(outcome) else { return self }
      let moved = self.scene.elements.map(fn(e) {
        if e.id == g.element_id {
          outcome.element
        } else if e.parent_id is Some(pid) && pid == g.element_id {
          match outcome.child_center {
            Some(c) => { ..e, x: c.x, y: c.y, }
            None => e
          }
        } else {
          e
        }
      })
      // 対象から伸びている接続線を BFS で追随させる
      let elements = @model.propagate_line_connections_bfs(moved, [g.element_id])
      { ..self, scene: { ..self.scene, elements, }, pending: outcome.joint, }
    }
    BoxSelecting(box) =>
      {
        ..self,
        gesture: BoxSelecting({ ..box, current_x: point.x, current_y: point.y, }),
      }
  }
}

// =============================================================================
// Release
// =============================================================================

///|
fn Session::release(self : Session) -> Session {
  match self.gesture {
    Idle => self
    Moving(g) => {
      let elements = round_one(self.scene.elements, g.element_id)
      {
        scene: { ..self.scene, elements, },
        gesture: Idle,
        pending: None,
        snapshot: None,
      }
    }
    Resizing(g) => self.release_resize(g)
    BoxSelecting(box) => {
      let bbox = box.to_bbox()
      let selection = @model.find_elements_in_box(self.scene.elements, bbox).map(fn(
          e,
        ) {
          e.id
        },
      )
      {
        scene: { ..self.scene, selection, },
        gesture: Idle,
        pending: None,
        snapshot: None,
      }
    }
  }
}

///|
/// リサイズ確定。線の端点ドラッグではここでジョイントの張り替えが起きる。
fn Session::release_resize(self : Session, g : ResizeGesture) -> Session {
  let done = fn(scene : Scene) -> Session {
    { scene, gesture: Idle, pending: None, snapshot: None, }
  }
  guard self.scene.find(g.element_id) is Some(el) else {
    return done(self.scene)
  }
  let is_line = el.shape is @model.Line(_, _)
  let endpoint = endpoint_of_handle(g.handle)
  // 線の端点を離した場合のみジョイントを更新する
  let jointed = if is_line && endpoint is Some(ep) {
    match self.pending {
      Some(p) => self.scene.connect(g.element_id, ep, p.target_id, p.anchor)
      None => self.scene.disconnect(g.element_id, ep)
    }
  } else {
    self.scene
  }
  // 潰れた線は破棄する（誤操作で長さ 0 の線が残らないように）
  if jointed.find(g.element_id) is Some(current) {
    if line_length(current) is Some(len) && len < min_line_length {
      let elements = jointed.elements.filter(fn(e) { e.id != g.element_id })
      let selection = jointed.selection.filter(fn(id) { id != g.element_id })
      return done({ ..jointed, elements, selection, })
    }
  }
  let elements = round_one(jointed.elements, g.element_id)
  done({ ..jointed, elements, selection: [g.element_id], })
}

// =============================================================================
// Cancel
// =============================================================================

///|
/// 進行中のジェスチャを取り消し、開始時の状態に巻き戻す
fn Session::cancel(self : Session) -> Session {
  let elements = match self.snapshot {
    Some(snapshot) => snapshot
    None => self.scene.elements
  }
  {
    scene: { ..self.scene, elements, },
    gesture: Idle,
    pending: None,
    snapshot: None,
  }
}

// =============================================================================
// 補助
// =============================================================================

///|
/// 指定要素の座標だけ整数に丸める（SVG の可読性のため）
fn round_one(
  elements : Array[@model.Element],
  id : String,
) -> Array[@model.Element] {
  elements.map(fn(e) {
    if e.id == id {
      @model.round_element_coords(e)
    } else {
      e
    }
  })
}
