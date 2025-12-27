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
/// CSS 変数をヘックス色に変換（カラーピッカー用）
fn to_hex_color(color : String, default : String) -> String {
  if color.has_prefix("var(") {
    default
  } else if color == "transparent" || color == "" {
    default
  } else {
    color
  }
}

///|
/// カラースウォッチを描画
fn render_color_swatches(
  state : EditorState,
  history : @model.History,
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
          if state.find_element(id) is Some(el) {
            let value = if color == "transparent" { "transparent" } else { color }
            let old_style = el.style
            let new_style = if is_fill {
              { ..old_style, fill: Some(value) }
            } else {
              { ..old_style, stroke: Some(value) }
            }
            execute_command(history, state, @model.UpdateStyle(id, old_style, new_style))
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
pub fn render_sidebar(
  state : EditorState,
  history : @model.History,
  canvas_height : Int,
) -> @element.DomNode {
  let sidebar_style =
    "width: \{sidebar_width}px; min-height: \{canvas_height}px; border: 1px solid #ccc; border-radius: 4px; background: #fafafa; padding: 12px; box-sizing: border-box;"
  div(
    style=sidebar_style,
    [
      // パンくずリスト（階層表示）
      render_breadcrumb(state),
      // 選択中の要素の詳細を表示（単一選択の場合）
      show(
        fn() { state.selected_ids.get().length() == 1 },
        fn() { render_element_details(state, history) },
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
      // 選択なしの場合：Canvas設定と要素ツリーを表示
      show(
        fn() { state.selected_ids.get().length() == 0 },
        fn() { render_canvas_root(state) },
      ),
    ],
  )
}

///|
/// パンくずリストをレンダリング
fn render_breadcrumb(state : EditorState) -> @element.DomNode {
  let breadcrumb_style =
    "display: flex; align-items: center; gap: 4px; margin-bottom: 12px; border-bottom: 1px solid #ddd; padding-bottom: 8px; font-size: 12px;"
  let link_style =
    "color: #0066cc; cursor: pointer; background: none; border: none; padding: 0; font-size: 12px;"
  let current_style = "color: #333; font-weight: bold;"
  // 選択なしの場合はパンくずを非表示
  show(
    fn() { state.selected_ids.get().length() > 0 },
    fn() {
      div(
        style=breadcrumb_style,
        [
          // Canvas リンク
          button(
            style=link_style,
            on=events().click(fn(_) { state.select(None) }),
            [text("Canvas")],
          ),
          @element.span(style="color: #999;", [text(" > ")]),
          // 選択中の要素名
          show(
            fn() { state.selected_ids.get().length() == 1 },
            fn() {
              @element.span(style=current_style, [
                text_dyn(fn() {
                  match state.get_selected_id() {
                    Some(id) =>
                      match state.find_element(id) {
                        Some(el) => @model.shape_name(el.shape) + " #" + el.id
                        None => "Unknown"
                      }
                    None => "Unknown"
                  }
                }),
              ])
            },
          ),
          // 複数選択の場合
          show(
            fn() { state.selected_ids.get().length() > 1 },
            fn() {
              @element.span(style=current_style, [
                text_dyn(fn() { "\{state.selected_ids.get().length()} selected" }),
              ])
            },
          ),
        ],
      )
    },
  )
}

///|
/// アコーディオンヘッダーのスタイル
let accordion_header_style : String = "display: flex; align-items: center; justify-content: space-between; padding: 8px; background: #f0f0f0; border-radius: 4px; cursor: pointer; font-size: 12px; font-weight: bold; color: #333; margin-bottom: 4px; user-select: none;"

///|
/// Canvas ルート表示（設定 + 要素ツリー）
fn render_canvas_root(state : EditorState) -> @element.DomNode {
  let settings_open = @luna.signal(true)
  let elements_open = @luna.signal(true)
  div(
    style="display: flex; flex-direction: column; gap: 8px;",
    [
      // Canvas Settings アコーディオン
      div(style="", [
        div(
          style=accordion_header_style,
          on=events().click(fn(_) { settings_open.update(fn(v) { not(v) }) }),
          [
            text("Canvas Settings"),
            text_dyn(fn() { if settings_open.get() { "▼" } else { "▶" } }),
          ],
        ),
        show(
          fn() { settings_open.get() },
          fn() { render_canvas_settings(state) },
        ),
      ]),
      // Elements アコーディオン
      div(style="", [
        div(
          style=accordion_header_style,
          on=events().click(fn(_) { elements_open.update(fn(v) { not(v) }) }),
          [
            text_dyn(fn() {
              let count = state.elements.get().filter(fn(el) { el.parent_id is None }).length()
              "Elements (\{count})"
            }),
            text_dyn(fn() { if elements_open.get() { "▼" } else { "▶" } }),
          ],
        ),
        show(fn() { elements_open.get() }, fn() { render_element_tree(state) }),
      ]),
    ],
  )
}

///|
/// Canvas 設定パネル
fn render_canvas_settings(state : EditorState) -> @element.DomNode {
  let row_style =
    "display: flex; align-items: center; justify-content: space-between; padding: 4px 8px; font-size: 11px;"
  let label_style = "color: #666;"
  let text_input_style =
    "width: 70px; padding: 2px 4px; border: 1px solid #ccc; border-radius: 3px; font-size: 10px;"
  let theme_btn_style =
    "flex: 1; padding: 6px 8px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 11px; transition: all 0.2s;"
  div(
    style="padding: 8px; background: #fff; border: 1px solid #eee; border-radius: 4px;",
    [
      // テーマ切り替え
      div(style="margin-bottom: 12px;", [
        @element.span(style=label_style + " display: block; margin-bottom: 6px;", [
          text("Theme"),
        ]),
        div(style="display: flex; gap: 4px;", [
          button(
            dyn_style=fn() {
              let is_active = state.theme_mode.get() == @model.Light
              if is_active {
                theme_btn_style + " background: #000; color: #fff; border-color: #000;"
              } else {
                theme_btn_style + " background: #fff; color: #333;"
              }
            },
            on=events().click(fn(_) {
              state.theme_mode.set(@model.Light)
              let theme = @model.Theme::light()
              state.preview_bg.set(theme.background)
            }),
            [text("Light")],
          ),
          button(
            dyn_style=fn() {
              let is_active = state.theme_mode.get() == @model.Dark
              if is_active {
                theme_btn_style + " background: #000; color: #fff; border-color: #000;"
              } else {
                theme_btn_style + " background: #fff; color: #333;"
              }
            },
            on=events().click(fn(_) {
              state.theme_mode.set(@model.Dark)
              let theme = @model.Theme::dark()
              state.preview_bg.set(theme.background)
            }),
            [text("Dark")],
          ),
        ]),
      ]),
      // プリセットカラー
      div(style="margin-bottom: 12px; border-top: 1px solid #eee; padding-top: 8px;", [
        @element.span(style=label_style + " display: block; margin-bottom: 6px;", [
          text("Preset Colors"),
        ]),
        render_preset_colors(state),
      ]),
      // 埋め込み背景色
      div(style=row_style + " border-top: 1px solid #eee; padding-top: 8px;", [
        @element.span(style=label_style, [text("Embed BG")]),
        input(
          type_="text",
          style=text_input_style,
          placeholder="transparent",
          dyn_value=fn() {
            let bg = state.embed_bg.get()
            if bg == "transparent" { "" } else { bg }
          },
          on=events().input(fn(e) {
            let value = get_event_target_value(e.as_any())
            if value == "" {
              state.embed_bg.set("transparent")
            } else {
              state.embed_bg.set(value)
            }
          }),
        ),
      ]),
    ],
  )
}

///|
/// プリセットカラーを表示
fn render_preset_colors(state : EditorState) -> @element.DomNode {
  let colors = @model.preset_colors()
  let children : Array[@element.DomNode] = []
  for preset in colors {
    let preset_name = preset.name
    let light_color = preset.light
    let dark_color = preset.dark
    children.push(
      div(
        style="display: flex; flex-direction: column; align-items: center; gap: 2px;",
        [
          div(
            dyn_style=fn() {
              let color = match state.theme_mode.get() {
                @model.Light => light_color
                @model.Dark => dark_color
              }
              "width: 24px; height: 24px; border-radius: 4px; border: 2px solid #ccc; cursor: pointer; background: \{color};"
            },
            on=events().click(fn(_) {
              // 選択中の要素があれば色を適用
              let color = match state.theme_mode.get() {
                @model.Light => light_color
                @model.Dark => dark_color
              }
              if state.get_selected_id() is Some(id) {
                state.update_element(id, fn(el) {
                  { ..el, style: { ..el.style, stroke: Some(color) } }
                })
              }
            }),
            [],
          ),
          @element.span(style="font-size: 9px; color: #999;", [text(preset_name)]),
        ],
      ),
    )
  }
  div(
    style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px;",
    [@element.fragment(children)],
  )
}

///|
/// 要素ツリーをレンダリング
fn render_element_tree(state : EditorState) -> @element.DomNode {
  let tree_style = "max-height: 300px; overflow-y: auto; padding: 4px;"
  let item_style =
    "display: flex; align-items: center; gap: 4px; padding: 4px 8px; cursor: pointer; border-radius: 3px; font-size: 11px;"
  // 親要素のみを表示（子要素は除外）
  let elements = state.elements.get().filter(fn(el) { el.parent_id is None })
  let children : Array[@element.DomNode] = []
  for el in elements {
    let shape_icon = match el.shape {
      @model.Rect(_, _, _, _) => "▢"
      @model.Circle(_) => "○"
      @model.Ellipse(_, _) => "⬭"
      @model.Line(_, _) => "╱"
      @model.Polyline(_) => "⟋"
      @model.Path(_) => "✎"
      @model.Text(_, _) => "T"
    }
    let el_id = el.id
    let shape_name = @model.shape_name(el.shape)
    children.push(
      div(
        style=item_style,
        on=events().click(fn(_) { state.select(Some(el_id)) }),
        [
          @element.span(style="font-size: 14px; width: 16px;", [text(shape_icon)]),
          @element.span(style="color: #666;", [text(shape_name)]),
          @element.span(style="color: #999; font-family: monospace;", [
            text("#" + el_id),
          ]),
        ],
      ),
    )
  }
  if children.length() == 0 {
    div(style="padding: 8px; color: #999; font-size: 11px; text-align: center;", [
      text("No elements"),
    ])
  } else {
    div(style=tree_style, [@element.fragment(children)])
  }
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
fn render_element_details(
  state : EditorState,
  history : @model.History,
) -> @element.DomNode {
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
            if new_id != "" && new_id != old_id {
              // 衝突チェック
              if state.has_element_with_id(new_id) {
                id_error.set(true)
              } else {
                execute_command(history, state, @model.RenameElement(old_id, new_id))
                id_error.set(false)
              }
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
            if state.find_element(id) is Some(el) {
              let value = get_event_target_value(e.as_any())
              if parse_double(value) is Some(new_x) {
                execute_command(history, state, @model.MoveElement(id, el.x, el.y, new_x, el.y))
              }
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
            if state.find_element(id) is Some(el) {
              let value = get_event_target_value(e.as_any())
              if parse_double(value) is Some(new_y) {
                execute_command(history, state, @model.MoveElement(id, el.x, el.y, el.x, new_y))
              }
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
                Some(el) => to_hex_color(el.style.stroke.unwrap_or("#000000"), "#000000")
                None => "#000000"
              }
            None => "#000000"
          }
        },
        on=events().input(fn(e) {
          if state.get_selected_id() is Some(id) {
            if state.find_element(id) is Some(el) {
              let value = get_event_target_value(e.as_any())
              let old_style = el.style
              let new_style = { ..old_style, stroke: Some(value) }
              execute_command(history, state, @model.UpdateStyle(id, old_style, new_style))
            }
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
      render_color_swatches(state, history, stroke_presets, false),
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
            if state.find_element(id) is Some(el) {
              let value = get_event_target_value(e.as_any())
              if parse_double(value) is Some(w) {
                let old_style = el.style
                let new_style = { ..old_style, stroke_width: Some(w) }
                execute_command(history, state, @model.UpdateStyle(id, old_style, new_style))
              }
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
                Some(el) => to_hex_color(el.style.fill.unwrap_or("transparent"), "#ffffff")
                None => "#ffffff"
              }
            None => "#ffffff"
          }
        },
        on=events().input(fn(e) {
          if state.get_selected_id() is Some(id) {
            if state.find_element(id) is Some(el) {
              let value = get_event_target_value(e.as_any())
              let old_style = el.style
              let new_style = { ..old_style, fill: Some(value) }
              execute_command(history, state, @model.UpdateStyle(id, old_style, new_style))
            }
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
      render_color_swatches(state, history, fill_presets, true),
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
      fn() { render_line_options(state, history) },
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
fn render_line_options(
  state : EditorState,
  history : @model.History,
) -> @element.DomNode {
  // Style と Arrows を一行に
  div(style="margin-top: 6px; padding-top: 6px; border-top: 1px solid #eee; display: flex; align-items: center; gap: 6px; flex-wrap: wrap;", [
    // 破線パターン選択
    div(style="display: flex; gap: 2px;", [
      render_dasharray_buttons(state, history),
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
              if state.find_element(id) is Some(el) {
                let old_style = el.style
                let new_marker = if old_style.marker_start is Some(@model.Arrow) {
                  None
                } else {
                  Some(@model.Arrow)
                }
                let new_style = { ..old_style, marker_start: new_marker }
                execute_command(history, state, @model.UpdateStyle(id, old_style, new_style))
              }
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
              if state.find_element(id) is Some(el) {
                let old_style = el.style
                let new_marker = if old_style.marker_end is Some(@model.Arrow) {
                  None
                } else {
                  Some(@model.Arrow)
                }
                let new_style = { ..old_style, marker_end: new_marker }
                execute_command(history, state, @model.UpdateStyle(id, old_style, new_style))
              }
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
fn render_dasharray_buttons(
  state : EditorState,
  history : @model.History,
) -> @element.DomNode {
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
          if state.find_element(id) is Some(el) {
            let old_style = el.style
            let new_style = { ..old_style, stroke_dasharray: pattern }
            execute_command(history, state, @model.UpdateStyle(id, old_style, new_style))
          }
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
  cancel : () -> Unit,
) -> @element.DomNode {
  guard state.text_edit.get() is Some(edit_state)
  let vp = state.viewport.get()
  // 親要素がある場合は親の中央座標を使用
  let (text_x, text_y, max_width) : (Double, Double, Double) = match state.find_element(edit_state.parent_id) {
    Some(parent) => {
      let bbox = parent.bounding_box()
      let center_x = bbox.x + bbox.width / 2.0
      let center_y = bbox.y + bbox.height / 2.0
      (center_x, center_y, (bbox.width * vp.zoom) - 16.0)
    }
    None => (edit_state.x, edit_state.y, 200.0)
  }
  // シーン座標をスクリーン座標に変換
  let screen_pos = vp.scene_to_screen(text_x, text_y)
  let clamped_width = if max_width < 40.0 { 40.0 } else { max_width }
  // テキストエリア（複数行対応、親要素の幅に合わせる）
  // line-height: 1.2 は SVG tspan の lineHeight = fontSize * 1.2 と一致
  let style =
    "position: absolute; left: \{screen_pos.x}px; top: \{screen_pos.y}px; transform: translate(-50%, -50%); width: \{clamped_width}px; min-height: 19px; max-height: 100px; padding: 0; border: none; background: transparent; font-family: sans-serif; font-size: 16px; line-height: 1.2; text-align: center; outline: none; box-sizing: border-box; resize: none; overflow: hidden; caret-color: currentColor;"
  // FFIでtextareaを作成
  let textarea = create_textarea_ffi(
    style,
    edit_state.initial_text,
    fn(value) { commit(value) },
    fn(_) { cancel() },
  )
  let node : @js_dom.Node = textarea.cast()
  @element.dom_node(node)
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
          ).with_style(state.get_default_style())
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
          ).with_style(state.get_default_style())
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
          ).with_style(state.get_default_style())
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
          ).with_style(state.get_line_style())
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Line")],
      ),
    ]),
    // Arrow
    div(style="padding: 4px 12px; border-bottom: 1px solid #eee;", [
      button(
        style=menu_button_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Line(insert_x + 100.0, insert_y + 50.0),
          ).with_style(state.get_arrow_style())
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Arrow")],
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
          ).with_style(state.get_text_style())
          execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Text")],
      ),
    ]),
  ])
}
