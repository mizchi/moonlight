// UI Components - サイドバー、コンテキストメニュー、テキスト入力

///|
/// サイドバー幅
let sidebar_width : Int = 220

///|
/// カラープリセット（背景用）- 8色に圧縮
let fill_presets : Array[String] = [
  "transparent", "#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff",
]

///|
/// カラープリセット（線用）- 8色に圧縮
let stroke_presets : Array[String] = [
  "#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff",
]

///|
/// カラースウォッチのスタイル
let swatch_style : String = "width: 20px; height: 20px; border: 1px solid #999; border-radius: 2px; cursor: pointer; padding: 0;"

///|
/// メニューボタンのスタイル
let menu_button_style : String = "width: 100%; text-align: left; background: none; border: none; cursor: pointer; padding: 4px 8px;"

///|
/// カラースウォッチを描画
fn render_color_swatches(
  state : EditorState,
  colors : Array[String],
  is_fill : Bool,
) -> @element.DomNode {
  let children : Array[@element.DomNode] = []
  for color in colors {
    // transparent の場合は斜線パターンで表示
    let bg_style = if color == "transparent" {
      "background: linear-gradient(45deg, #ccc 25%, transparent 25%), linear-gradient(-45deg, #ccc 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #ccc 75%), linear-gradient(-45deg, transparent 75%, #ccc 75%); background-size: 8px 8px; background-position: 0 0, 0 4px, 4px -4px, -4px 0px;"
    } else {
      "background: \{color};"
    }
    let swatch = button(
      style=swatch_style + " " + bg_style,
      on=events().click(fn(_) {
        if state.get_selected_id() is Some(id) {
          let value = if color == "transparent" { "transparent" } else { color }
          if is_fill {
            state.update_element(id, fn(el) {
              { ..el, style: { ..el.style, fill: Some(value) } }
            })
          } else {
            state.update_element(id, fn(el) {
              { ..el, style: { ..el.style, stroke: Some(value) } }
            })
          }
        }
      }),
      [],
    )
    children.push(swatch)
  }
  @element.fragment(children)
}

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
/// 小さい入力フィールドのスタイル（コンパクト版）
let small_input_style : String = "width: 50px; padding: 2px 4px; border: 1px solid #ccc; border-radius: 3px; font-family: monospace; font-size: 11px; box-sizing: border-box;"

///|
/// 読み取り専用フィールドのスタイル
let readonly_field_style : String = "font-family: monospace; font-size: 11px; padding: 2px 4px; background: #f0f0f0; border-radius: 3px; min-width: 30px;"

///|
/// ID入力フィールドのスタイル
let id_input_style : String = "width: 80px; padding: 2px 4px; border: 1px solid #ccc; border-radius: 3px; font-family: monospace; font-size: 11px; box-sizing: border-box;"

///|
/// ラベルのスタイル
let label_style : String = "font-size: 10px; color: #666; min-width: 14px;"

///|
/// 行のスタイル
let row_style : String = "display: flex; align-items: center; gap: 4px; margin-bottom: 4px;"

///|
/// 要素の詳細を表示・編集（コンパクト版）
fn render_element_details(state : EditorState) -> @element.DomNode {
  // ID編集用のローカル状態（衝突エラー表示用）
  let id_error = @luna.signal(false)
  div([
    // ID: rect #id 形式、id部分は編集可能
    div(style=row_style, [
      @element.span(style="font-size: 11px; color: #333;", [
        text_dyn(fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => @model.shape_name(el.shape)
                None => "-"
              }
            None => "-"
          }
        }),
      ]),
      @element.span(style="font-size: 11px; color: #666;", [text("#")]),
      input(
        type_="text",
        style=id_input_style,
        dyn_style=fn() {
          if id_error.get() {
            id_input_style + " border-color: #c53030; background: #fff5f5;"
          } else {
            id_input_style
          }
        },
        dyn_value=fn() { state.get_selected_id().unwrap_or("") },
        on=events().change(fn(e) {
          if state.get_selected_id() is Some(old_id) {
            let new_id = get_event_target_value(e.as_any())
            if new_id != "" {
              let success = state.rename_element_id(old_id, new_id)
              id_error.set(not(success))
            }
          }
        }),
      ),
    ]),
    // x: [] y: [] を一行に
    div(style=row_style, [
      @element.span(style=label_style, [text("x:")]),
      input(
        type_="number",
        style=small_input_style,
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
      @element.span(style=label_style, [text("y:")]),
      input(
        type_="number",
        style=small_input_style,
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
    // w: [] h: [] を一行に
    div(style=row_style, [
      @element.span(style=label_style, [text("w:")]),
      @element.span(style=readonly_field_style, [
        text_dyn(fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => {
                  let bbox = el.bounding_box()
                  bbox.width.to_int().to_string()
                }
                None => "-"
              }
            None => "-"
          }
        }),
      ]),
      @element.span(style=label_style, [text("h:")]),
      @element.span(style=readonly_field_style, [
        text_dyn(fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => {
                  let bbox = el.bounding_box()
                  bbox.height.to_int().to_string()
                }
                None => "-"
              }
            None => "-"
          }
        }),
      ]),
    ]),
    // Stroke: カラーピッカー + カラーコード（背景色付き）
    div(style=row_style + " margin-top: 6px;", [
      @element.span(style=label_style + " min-width: 38px;", [text("Stroke")]),
      input(
        type_="color",
        style="width: 24px; height: 20px; padding: 0; border: 1px solid #ccc; border-radius: 2px; cursor: pointer;",
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
      @element.span(
        style="font-family: monospace; font-size: 10px; padding: 2px 4px; border-radius: 2px; color: #fff;",
        dyn_style=fn() {
          let color = match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.style.stroke.unwrap_or("#000000")
                None => "#000000"
              }
            None => "#000000"
          }
          "font-family: monospace; font-size: 10px; padding: 2px 4px; border-radius: 2px; color: #fff; background: \{color};"
        },
        [
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
        ],
      ),
    ]),
    // Stroke プリセット（1行）
    div(style="display: flex; gap: 2px; margin-bottom: 4px;", [
      render_color_swatches(state, stroke_presets, false),
    ]),
    // stroke-width を一行に
    div(style=row_style, [
      @element.span(style=label_style + " min-width: 64px;", [text("stroke-width:")]),
      input(
        type_="number",
        style=small_input_style,
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
    // Fill: カラーピッカー + カラーコード（背景色付き）
    div(style=row_style + " margin-top: 6px;", [
      @element.span(style=label_style + " min-width: 38px;", [text("Fill")]),
      input(
        type_="color",
        style="width: 24px; height: 20px; padding: 0; border: 1px solid #ccc; border-radius: 2px; cursor: pointer;",
        dyn_value=fn() {
          match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => {
                  let fill = el.style.fill.unwrap_or("transparent")
                  if fill == "transparent" { "#ffffff" } else { fill }
                }
                None => "#ffffff"
              }
            None => "#ffffff"
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
      @element.span(
        style="font-family: monospace; font-size: 10px; padding: 2px 4px; border-radius: 2px;",
        dyn_style=fn() {
          let fill = match state.get_selected_id() {
            Some(id) =>
              match state.find_element(id) {
                Some(el) => el.style.fill.unwrap_or("transparent")
                None => "transparent"
              }
            None => "transparent"
          }
          if fill == "transparent" {
            "font-family: monospace; font-size: 10px; padding: 2px 4px; border-radius: 2px; background: linear-gradient(45deg, #ccc 25%, transparent 25%), linear-gradient(-45deg, #ccc 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #ccc 75%), linear-gradient(-45deg, transparent 75%, #ccc 75%); background-size: 6px 6px; background-position: 0 0, 0 3px, 3px -3px, -3px 0px;"
          } else {
            let text_color = if fill == "#ffffff" || fill == "#ffff00" || fill == "#00ff00" {
              "#000"
            } else {
              "#fff"
            }
            "font-family: monospace; font-size: 10px; padding: 2px 4px; border-radius: 2px; background: \{fill}; color: \{text_color};"
          }
        },
        [
          text_dyn(fn() {
            match state.get_selected_id() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.fill.unwrap_or("transparent")
                  None => "-"
                }
              None => "-"
            }
          }),
        ],
      ),
    ]),
    // Fill プリセット（1行）
    div(style="display: flex; gap: 2px; margin-bottom: 4px;", [
      render_color_swatches(state, fill_presets, true),
    ]),
    // Line 専用オプション（破線、矢印）
    show(
      fn() {
        match state.get_selected_id() {
          Some(id) =>
            match state.find_element(id) {
              Some(el) => el.shape is @model.Line(_, _)
              None => false
            }
          None => false
        }
      },
      fn() { render_line_options(state) },
    ),
  ])
}

///|
/// トグルボタンのスタイル
let toggle_button_style : String = "padding: 2px 6px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 10px;"

///|
/// 破線パターンのプリセット（短いラベル）
let dasharray_presets : Array[(String, String?)] = [
  ("―", None),
  ("--", Some("8,4")),
  ("··", Some("2,4")),
  ("-·", Some("8,4,2,4")),
]

///|
/// Line 専用オプション（破線、矢印）- コンパクト版
fn render_line_options(state : EditorState) -> @element.DomNode {
  // Style と Arrows を一行に
  div(style="margin-top: 6px; padding-top: 6px; border-top: 1px solid #eee; display: flex; align-items: center; gap: 6px; flex-wrap: wrap;", [
    // 破線パターン選択
    div(style="display: flex; gap: 2px;", [
      render_dasharray_buttons(state),
    ]),
    // セパレータ
    @element.span(style="color: #ccc;", [text("|")]),
    // Arrow チェックボックス
    div(style="display: flex; gap: 6px; align-items: center;", [
      // Start Arrow
      @element.label(style="display: flex; align-items: center; gap: 2px; font-size: 11px; cursor: pointer;", [
        input(
          type_="checkbox",
          style="cursor: pointer; margin: 0;",
          dyn_checked=fn() {
            match state.get_selected_id() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.marker_start is Some(@model.Arrow)
                  None => false
                }
              None => false
            }
          },
          on=events().change(fn(_) {
            if state.get_selected_id() is Some(id) {
              state.update_element(id, fn(el) {
                let new_marker = if el.style.marker_start is Some(@model.Arrow) {
                  None
                } else {
                  Some(@model.Arrow)
                }
                { ..el, style: { ..el.style, marker_start: new_marker } }
              })
            }
          }),
        ),
        text("<"),
      ]),
      // End Arrow
      @element.label(style="display: flex; align-items: center; gap: 2px; font-size: 11px; cursor: pointer;", [
        input(
          type_="checkbox",
          style="cursor: pointer; margin: 0;",
          dyn_checked=fn() {
            match state.get_selected_id() {
              Some(id) =>
                match state.find_element(id) {
                  Some(el) => el.style.marker_end is Some(@model.Arrow)
                  None => false
                }
              None => false
            }
          },
          on=events().change(fn(_) {
            if state.get_selected_id() is Some(id) {
              state.update_element(id, fn(el) {
                let new_marker = if el.style.marker_end is Some(@model.Arrow) {
                  None
                } else {
                  Some(@model.Arrow)
                }
                { ..el, style: { ..el.style, marker_end: new_marker } }
              })
            }
          }),
        ),
        text(">"),
      ]),
    ]),
  ])
}

///|
/// 破線パターンボタン群
fn render_dasharray_buttons(state : EditorState) -> @element.DomNode {
  let children : Array[@element.DomNode] = []
  for preset in dasharray_presets {
    let (label, pattern) = preset
    let btn = button(
      style=toggle_button_style,
      dyn_style=fn() {
        match state.get_selected_id() {
          Some(id) =>
            match state.find_element(id) {
              Some(el) => {
                let current = el.style.stroke_dasharray
                let is_active = match (current, pattern) {
                  (None, None) => true
                  (Some(a), Some(b)) => a == b
                  _ => false
                }
                if is_active {
                  toggle_button_style + " background: #e0e0ff; border-color: #6666ff;"
                } else {
                  toggle_button_style + " background: #fff;"
                }
              }
              None => toggle_button_style + " background: #fff;"
            }
          None => toggle_button_style + " background: #fff;"
        }
      },
      on=events().click(fn(_) {
        if state.get_selected_id() is Some(id) {
          state.update_element(id, fn(el) {
            { ..el, style: { ..el.style, stroke_dasharray: pattern } }
          })
        }
      }),
      [text(label)],
    )
    children.push(btn)
  }
  @element.fragment(children)
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
  // シンプルなインライン入力（コンテンツ幅に合わせる）
  let style =
    "position: absolute; left: \{screen_pos.x}px; top: \{screen_pos.y}px; transform: translate(-50%, -50%); min-width: 20px; padding: 2px 4px; border: none; border-bottom: 1px solid #333; background: transparent; font-size: 14px; text-align: center; outline: none;"
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
            fill: Some("transparent"),
            stroke: Some("#000000"),
            stroke_width: Some(2.0),
            opacity: None,
            stroke_dasharray: None,
            marker_start: None,
            marker_end: None,
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
            fill: Some("transparent"),
            stroke: Some("#000000"),
            stroke_width: Some(2.0),
            opacity: None,
            stroke_dasharray: None,
            marker_start: None,
            marker_end: None,
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
            fill: Some("transparent"),
            stroke: Some("#000000"),
            stroke_width: Some(2.0),
            opacity: None,
            stroke_dasharray: None,
            marker_start: None,
            marker_end: None,
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
            stroke: Some("#000000"),
            stroke_width: Some(2.0),
            opacity: None,
            stroke_dasharray: None,
            marker_start: None,
            marker_end: Some(@model.Arrow),
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
            fill: Some("#000000"),
            stroke: None,
            stroke_width: None,
            opacity: None,
            stroke_dasharray: None,
            marker_start: None,
            marker_end: None,
          })
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Text")],
      ),
    ]),
  ])
}
