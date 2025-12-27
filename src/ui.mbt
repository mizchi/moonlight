// UI Components - サイドバー、コンテキストメニュー、テキスト入力

///|
/// サイドバー幅
let sidebar_width : Int = 220

///|
/// 入力フィールドのスタイル
let input_style : String = "width: 100%; padding: 4px; border: 1px solid #ccc; border-radius: 3px; font-family: monospace; font-size: 13px; box-sizing: border-box;"

///|
/// カラー入力のスタイル
let color_input_style : String = "width: 60px; height: 24px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer;"

///|
/// メニューボタンのスタイル
let menu_button_style : String = "width: 100%; text-align: left; background: none; border: none; cursor: pointer; padding: 4px 8px;"

///|
/// サイドバーをレンダリング
pub fn render_sidebar(state : EditorState, canvas_height : Int) -> @element.DomNode {
  let sidebar_style =
    "width: \{sidebar_width}px; min-height: \{canvas_height}px; border: 1px solid #ccc; border-radius: 4px; background: #fafafa; padding: 12px; box-sizing: border-box;"
  div(
    style=sidebar_style,
    [
      div(style="font-weight: bold; margin-bottom: 12px; border-bottom: 1px solid #ddd; padding-bottom: 8px;", [
        text("Element"),
      ]),
      // 選択中の要素の詳細を表示（単一選択の場合）
      show(
        fn() { state.selected_ids.get().length() == 1 },
        fn() { render_element_details(state) },
      ),
      // 複数選択の場合
      show(
        fn() { state.selected_ids.get().length() > 1 },
        fn() {
          div(style="color: #333; font-size: 14px;", [
            text_dyn(fn() { "\{state.selected_ids.get().length()} elements selected" }),
          ])
        },
      ),
      // 選択なしの場合
      show(
        fn() { state.selected_ids.get().length() == 0 },
        fn() {
          div(style="color: #888; font-size: 14px;", [
            text("Select an element to view details"),
          ])
        },
      ),
    ],
  )
}

///|
/// 要素の詳細を表示・編集
fn render_element_details(state : EditorState) -> @element.DomNode {
  div([
    // ID (読み取り専用)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("ID")]),
      div(style="font-family: monospace; font-size: 14px; color: #333;", [
        text_dyn(fn() { state.get_selected_id().unwrap_or("-") }),
      ]),
    ]),
    // Position X
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("X")]),
      input(
        type_="number",
        style=input_style,
        dyn_value=fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.x.to_int().to_string()
                None => "0"
              }
            None => "0"
          }
        },
        on=events().change(fn(e) {
          if state.get_selected_id() is Some(id) {
            let value = get_event_target_value(e.as_any())
            if parse_double(value) is Some(x) {
              state.update_element(id, fn(el) { { ..el, x } })
            }
          }
        }),
      ),
    ]),
    // Position Y
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Y")]),
      input(
        type_="number",
        style=input_style,
        dyn_value=fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.y.to_int().to_string()
                None => "0"
              }
            None => "0"
          }
        },
        on=events().change(fn(e) {
          if state.get_selected_id() is Some(id) {
            let value = get_event_target_value(e.as_any())
            if parse_double(value) is Some(y) {
              state.update_element(id, fn(el) { { ..el, y } })
            }
          }
        }),
      ),
    ]),
    // Shape (読み取り専用)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Shape")]),
      div(style="font-family: monospace; font-size: 14px;", [
        text_dyn(fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => @model.format_shape(el.shape)
                None => "-"
              }
            None => "-"
          }
        }),
      ]),
    ]),
    // Fill (カラーピッカー)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Fill")]),
      div(style="display: flex; gap: 8px; align-items: center;", [
        input(
          type_="color",
          style=color_input_style,
          dyn_value=fn() {
            match state.get_selected_id() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.fill.unwrap_or("#000000")
                  None => "#000000"
                }
              None => "#000000"
            }
          },
          on=events().input(fn(e) {
            if state.get_selected_id() is Some(id) {
              let value = get_event_target_value(e.as_any())
              state.update_element(id, fn(el) {
                { ..el, style: { ..el.style, fill: Some(value) } }
              })
            }
          }),
        ),
        @element.span(style="font-family: monospace; font-size: 12px;", [
          text_dyn(fn() {
            match state.get_selected_id() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.fill.unwrap_or("none")
                  None => "-"
                }
              None => "-"
            }
          }),
        ]),
      ]),
    ]),
    // Stroke (カラーピッカー)
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Stroke")]),
      div(style="display: flex; gap: 8px; align-items: center;", [
        input(
          type_="color",
          style=color_input_style,
          dyn_value=fn() {
            match state.get_selected_id() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.stroke.unwrap_or("#000000")
                  None => "#000000"
                }
              None => "#000000"
            }
          },
          on=events().input(fn(e) {
            if state.get_selected_id() is Some(id) {
              let value = get_event_target_value(e.as_any())
              state.update_element(id, fn(el) {
                { ..el, style: { ..el.style, stroke: Some(value) } }
              })
            }
          }),
        ),
        @element.span(style="font-family: monospace; font-size: 12px;", [
          text_dyn(fn() {
            match state.get_selected_id() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.stroke.unwrap_or("none")
                  None => "-"
                }
              None => "-"
            }
          }),
        ]),
      ]),
    ]),
    // Stroke Width
    div(style="margin-bottom: 10px;", [
      div(style="font-size: 12px; color: #666; margin-bottom: 4px;", [text("Stroke Width")]),
      input(
        type_="number",
        style=input_style,
        dyn_value=fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.style.stroke_width.unwrap_or(1.0).to_string()
                None => "1"
              }
            None => "1"
          }
        },
        on=events().change(fn(e) {
          if state.get_selected_id() is Some(id) {
            let value = get_event_target_value(e.as_any())
            if parse_double(value) is Some(w) {
              state.update_element(id, fn(el) {
                { ..el, style: { ..el.style, stroke_width: Some(w) } }
              })
            }
          }
        }),
      ),
    ]),
  ])
}

///|
/// テキスト入力オーバーレイをレンダリング
pub fn render_text_input(
  state : EditorState,
  commit : (String) -> Unit,
) -> @element.DomNode {
  guard state.text_edit.get() is Some(edit_state)
  // シーン座標をスクリーン座標に変換
  let vp = state.viewport.get()
  let screen_pos = vp.scene_to_screen(edit_state.x, edit_state.y)
  // 入力フィールドの幅と高さ
  let input_width = 150
  let input_height = 28
  // 中央に配置（入力フィールドの半分をオフセット）
  let left = screen_pos.x - input_width.to_double() / 2.0
  let top = screen_pos.y - input_height.to_double() / 2.0
  let style =
    "position: absolute; left: \{left}px; top: \{top}px; width: \{input_width}px; height: \{input_height}px; padding: 4px 8px; border: 2px solid #0066ff; border-radius: 4px; font-size: 14px; text-align: center; box-sizing: border-box; outline: none;"
  // 自動フォーカス（初期値付き）
  let _ = schedule_focus_with_value_ffi("input[type=text]", edit_state.initial_text)
  input(
    type_="text",
    style~,
    on=events()
      .keydown(fn(e) {
        let key : String = e.as_any()._get("key").cast()
        if key == "Enter" {
          let value = get_event_target_value(e.as_any())
          commit(value)
        } else if key == "Escape" {
          state.end_text_edit()
        }
      })
      .blur(fn(e) {
        let value = get_event_target_value(e.as_any())
        commit(value)
      }),
  )
}

///|
/// コンテキストメニューをレンダリング
pub fn render_context_menu(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  guard state.context_menu.get() is Some(menu)
  let style =
    "position: fixed; left: \{menu.x}px; top: \{menu.y}px; background: white; border: 1px solid #ccc; border-radius: 4px; box-shadow: 2px 2px 10px rgba(0,0,0,0.1); min-width: 140px; z-index: 1000;"
  div(
    style~,
    [
      // 要素上でクリックした場合のみメニューを表示
      if menu.target_id is Some(id) {
        @element.fragment([
          // Bring to Front
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                if state.bring_to_front(id) is Some((from_idx, to_idx)) {
                  let cmd = @model.ReorderElement(id, from_idx, to_idx)
                  history.undo_stack.push(cmd)
                  history.redo_stack.clear()
                }
                state.hide_context_menu()
              }),
              [text("Bring to Front")],
            ),
          ]),
          // Send to Back
          div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
            button(
              style=menu_button_style,
              on=events().click(fn(_) {
                if state.send_to_back(id) is Some((from_idx, to_idx)) {
                  let cmd = @model.ReorderElement(id, from_idx, to_idx)
                  history.undo_stack.push(cmd)
                  history.redo_stack.clear()
                }
                state.hide_context_menu()
              }),
              [text("Send to Back")],
            ),
          ]),
          // Delete
          div(style="padding: 4px 12px;", [
            button(
              style=menu_button_style + " color: #c53030;",
              on=events().click(fn(_) {
                if state.find_element(id) is Some(el) {
                  execute_command(history, state, @model.RemoveElement(el))
                }
                state.hide_context_menu()
              }),
              [text("Delete")],
            ),
          ]),
        ])
      } else {
        // 空白部分を右クリックした場合 - 挿入メニュー
        render_insert_menu(state, history, new_id, menu.scene_x, menu.scene_y)
      },
    ],
  )
}

///|
/// 挿入メニューをレンダリング
fn render_insert_menu(
  state : EditorState,
  history : @model.History,
  new_id : () -> String,
  insert_x : Double,
  insert_y : Double,
) -> @element.DomNode {
  @element.fragment([
    div(style="padding: 4px 12px; border-bottom: 1px solid #eee; color: #666; font-size: 12px;", [
      text("Insert"),
    ]),
    // Rectangle
    div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
      button(
        style=menu_button_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Rect(80.0, 60.0, None, None),
          ).with_style({
            fill: Some("#9f7aea"),
            stroke: Some("#6b46c1"),
            stroke_width: Some(2.0),
            opacity: None,
          })
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Rectangle")],
      ),
    ]),
    // Circle
    div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
      button(
        style=menu_button_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Circle(40.0),
          ).with_style({
            fill: Some("#f56565"),
            stroke: Some("#c53030"),
            stroke_width: Some(2.0),
            opacity: None,
          })
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Circle")],
      ),
    ]),
    // Ellipse
    div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
      button(
        style=menu_button_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Ellipse(60.0, 35.0),
          ).with_style({
            fill: Some("#38b2ac"),
            stroke: Some("#234e52"),
            stroke_width: Some(2.0),
            opacity: None,
          })
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Ellipse")],
      ),
    ]),
    // Line
    div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
      button(
        style=menu_button_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Line(insert_x + 100.0, insert_y + 50.0),
          ).with_style({
            fill: None,
            stroke: Some("#805ad5"),
            stroke_width: Some(3.0),
            opacity: None,
          })
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Line")],
      ),
    ]),
    // Text
    div(style="padding: 4px 12px;", [
      button(
        style=menu_button_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Text("Text", Some(24.0)),
          ).with_style({
            fill: Some("#2d3748"),
            stroke: None,
            stroke_width: None,
            opacity: None,
          })
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Text")],
      ),
    ]),
  ])
}
