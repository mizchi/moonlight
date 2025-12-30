// UI Components - サイドバー、コンテキストメニュー、テキスト入力

///|
/// サイドバー幅
let sidebar_width : Int = 220

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
/// サイドバーをレンダリング（後方互換性のため残す）
pub fn render_sidebar(
  state : @core.EditorState,
  history : @model.History,
  _canvas_height : Int,
) -> @element.DomNode {
  render_floating_panel(state, history)
}

///|
/// フローティングパネルをレンダリング
pub fn render_floating_panel(
  state : @core.EditorState,
  history : @model.History,
) -> @element.DomNode {
  div(
    dyn_style=fn() {
      let theme = state.get_theme()
      let is_mobile = state.is_mobile.get()
      let is_dark = state.theme_mode.get() == @model.Dark
      let shadow = if is_dark { "rgba(0,0,0,0.4)" } else { "rgba(0,0,0,0.15)" }
      if is_mobile {
        // モバイル: 画面下部にスライド表示
        "position: fixed; bottom: 0; left: 0; right: 0; max-height: 50vh; background: \{theme.ui_bg}; border-top: 1px solid \{theme.ui_border}; border-radius: 12px 12px 0 0; padding: 12px; box-sizing: border-box; overflow-y: auto; box-shadow: 0 -2px 12px \{shadow}; z-index: 100; color: \{theme.ui_text};"
      } else {
        // デスクトップ: 右端にフローティング表示
        "position: fixed; top: 56px; right: 12px; width: \{sidebar_width}px; max-height: calc(100vh - 80px); background: \{theme.ui_bg}; border: 1px solid \{theme.ui_border}; border-radius: 8px; padding: 12px; box-sizing: border-box; overflow-y: auto; box-shadow: 0 2px 12px \{shadow}; z-index: 100; color: \{theme.ui_text};"
      }
    },
    [render_panel_content(state, history)],
  )
}

///|
/// インラインパネルをレンダリング（モーダル内で使用、position: fixed なし）
pub fn render_inline_panel(
  state : @core.EditorState,
  history : @model.History,
) -> @element.DomNode {
  div(
    dyn_style=fn() {
      let theme = state.get_theme()
      "padding: 8px; background: \{theme.ui_bg}; color: \{theme.ui_text}; font-size: 12px;"
    },
    [render_panel_content(state, history)],
  )
}

///|
/// パネルの共通コンテンツ
fn render_panel_content(
  state : @core.EditorState,
  history : @model.History,
) -> @element.DomNode {
  @element.fragment([
    // パンくずリスト（階層表示）
    render_breadcrumb(state),
    // 選択中の要素の詳細を表示（単一選択の場合）
    show(fn() { state.selected_ids.get().length() == 1 }, fn() {
      render_element_details(state, history)
    }),
    // 複数選択の場合
    show(fn() { state.selected_ids.get().length() > 1 }, fn() {
      render_multi_selection_panel(state)
    }),
    // 選択なしの場合：Canvas設定と要素ツリーを表示
    show(fn() { state.selected_ids.get().length() == 0 }, fn() {
      render_canvas_root_compact(state)
    }),
  ])
}

///|
/// パンくずリストをレンダリング
fn render_breadcrumb(state : @core.EditorState) -> @element.DomNode {
  let theme = state.get_theme()
  let breadcrumb_style = "display: flex; align-items: center; gap: 4px; margin-bottom: 12px; border-bottom: 1px solid \{theme.ui_border}; padding-bottom: 8px; font-size: 12px;"
  let link_style = "color: \{theme.ui_accent}; cursor: pointer; background: none; border: none; padding: 0; font-size: 12px;"
  let current_style = "color: \{theme.ui_text}; font-weight: bold;"
  // 選択なしの場合はパンくずを非表示
  show(fn() { state.selected_ids.get().length() > 0 }, fn() {
    div(style=breadcrumb_style, [
      // Canvas リンク
      button(
        style=link_style,
        on=events().click(fn(_) { state.select(None) }),
        [text("Canvas")],
      ),
      @element.span(style="color: #999;", [text(" > ")]),
      // 選択中の要素名
      show(fn() { state.selected_ids.get().length() == 1 }, fn() {
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
      }),
      // 複数選択の場合
      show(fn() { state.selected_ids.get().length() > 1 }, fn() {
        @element.span(style=current_style, [
          text_dyn(fn() { "\{state.selected_ids.get().length()} selected" }),
        ])
      }),
    ])
  })
}

///|
/// 複数選択時のパネルをレンダリング
fn render_multi_selection_panel(state : @core.EditorState) -> @element.DomNode {
  let theme = state.get_theme()
  let item_style = "display: flex; align-items: center; gap: 4px; padding: 4px 8px; cursor: pointer; border-radius: 3px; font-size: 11px;"
  div(style="font-size: 12px;", [
    // ヘッダー
    div(
      style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px;",
      [
        @element.span(style="font-weight: 500; color: \{theme.ui_text};", [
          text_dyn(fn() {
            "\{state.selected_ids.get().length()} elements selected"
          }),
        ]),
        // 選択解除ボタン
        button(
          style="padding: 2px 6px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 10px; background: #fff;",
          on=events().click(fn(_) { state.select(None) }),
          [text("Clear")],
        ),
      ],
    ),
    // 選択中の要素リスト
    div(
      style="max-height: 200px; overflow-y: auto; border: 1px solid \{theme.ui_border}; border-radius: 4px; padding: 4px;",
      [
        @element.for_each(fn() { state.selected_ids.get() }, fn(id, _idx) {
          let el_opt = state.find_element(id)
          let shape_icon = match el_opt {
            Some(el) =>
              match el.shape {
                @model.Rect(_, _, _, _) => "▢"
                @model.Circle(_) => "○"
                @model.Ellipse(_, _) => "⬭"
                @model.Line(_, _) => "╱"
                @model.Polyline(_) => "⟋"
                @model.Path(_, _, _, _, _) => "✎"
                @model.Text(_, _) => "T"
              }
            None => "?"
          }
          let shape_name = match el_opt {
            Some(el) => @model.shape_name(el.shape)
            None => "Unknown"
          }
          div(
            style=item_style,
            on=events().click(fn(_) { state.select(Some(id)) }),
            [
              @element.span(style="font-size: 14px; width: 16px;", [
                text(shape_icon),
              ]),
              @element.span(style="color: #666;", [text(shape_name)]),
              @element.span(style="color: #999; font-family: monospace;", [
                text("#" + id),
              ]),
              // 選択から除外ボタン
              button(
                style="margin-left: auto; padding: 1px 4px; border: 1px solid #ccc; border-radius: 2px; cursor: pointer; font-size: 9px; background: #fff; color: #666;",
                on=events().click(fn(e) {
                  let _ = e.as_any()._call("stopPropagation", [])
                  state.remove_from_selection(id)
                }),
                [text("×")],
              ),
            ],
          )
        }),
      ],
    ),
    // ヒントテキスト
    div(
      style="margin-top: 8px; font-size: 10px; color: \{theme.ui_text_muted};",
      [text("Tip: Shift+click to add/remove, Ctrl+C/V to copy/paste")],
    ),
  ])
}

///|
/// アコーディオンヘッダーのスタイル
let accordion_header_style : String = "display: flex; align-items: center; justify-content: space-between; padding: 8px; background: #f0f0f0; border-radius: 4px; cursor: pointer; font-size: 12px; font-weight: bold; color: #333; margin-bottom: 4px; user-select: none;"

///|
/// Canvas ルート表示（コンパクト版 - アコーディオンは閉じた状態で開始）
fn render_canvas_root_compact(state : @core.EditorState) -> @element.DomNode {
  let settings_open = @luna.signal(false) // 閉じた状態で開始
  let elements_open = @luna.signal(true) // Elements は開いた状態
  div(style="display: flex; flex-direction: column; gap: 4px;", [
    // Canvas Settings アコーディオン（閉じた状態）
    div(style="", [
      div(
        style=accordion_header_style,
        on=events().click(fn(_) { settings_open.update(fn(v) { not(v) }) }),
        [
          text("Canvas Settings"),
          text_dyn(fn() { if settings_open.get() { "▼" } else { "▶" } }),
        ],
      ),
      show(fn() { settings_open.get() }, fn() { render_canvas_settings(state) }),
    ]),
    // Elements アコーディオン
    div(style="", [
      div(
        style=accordion_header_style,
        on=events().click(fn(_) { elements_open.update(fn(v) { not(v) }) }),
        [
          text_dyn(fn() {
            let count = state.elements
              .get()
              .filter(fn(el) { el.parent_id is None })
              .length()
            "Elements (\{count})"
          }),
          text_dyn(fn() { if elements_open.get() { "▼" } else { "▶" } }),
        ],
      ),
      show(fn() { elements_open.get() }, fn() { render_element_tree(state) }),
    ]),
  ])
}

///|
/// Canvas 設定パネル
fn render_canvas_settings(state : @core.EditorState) -> @element.DomNode {
  let row_style = "display: flex; align-items: center; justify-content: space-between; padding: 4px 8px; font-size: 11px;"
  let label_style = "color: #666;"
  let text_input_style = "width: 70px; padding: 2px 4px; border: 1px solid #ccc; border-radius: 3px; font-size: 10px;"
  let small_input_style = "width: 60px; padding: 2px 4px; border: 1px solid #ccc; border-radius: 3px; font-size: 10px;"
  let theme_btn_style = "flex: 1; padding: 6px 8px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 11px; transition: all 0.2s;"
  div(
    style="padding: 8px; background: #fff; border: 1px solid #eee; border-radius: 4px;",
    [
      // Document Size
      div(style="margin-bottom: 12px;", [
        @element.span(
          style=label_style + " display: block; margin-bottom: 6px;",
          [text("Document Size")],
        ),
        div(style="display: flex; gap: 8px; align-items: center;", [
          @element.span(style="font-size: 10px; color: #999;", [text("W:")]),
          input(
            type_="number",
            style=small_input_style,
            dyn_value=fn() { state.doc_width.get().to_int().to_string() },
            on=events().change(fn(e) {
              let value = get_event_target_value(e.as_any())
              if parse_double(value) is Some(w) {
                if w > 0.0 {
                  state.doc_width.set(w)
                }
              }
            }),
          ),
          @element.span(style="font-size: 10px; color: #999;", [text("H:")]),
          input(
            type_="number",
            style=small_input_style,
            dyn_value=fn() { state.doc_height.get().to_int().to_string() },
            on=events().change(fn(e) {
              let value = get_event_target_value(e.as_any())
              if parse_double(value) is Some(h) {
                if h > 0.0 {
                  state.doc_height.set(h)
                }
              }
            }),
          ),
        ]),
        // Fit to Canvas ボタン
        button(
          style="margin-top: 6px; width: 100%; padding: 4px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 10px; background: #f8f8f8;",
          on=events().click(fn(_) { state.fit_to_canvas() }),
          [text("Fit to Canvas")],
        ),
      ]),
      // テーマ切り替え
      div(
        style="margin-bottom: 12px; border-top: 1px solid #eee; padding-top: 8px;",
        [
          @element.span(
            style=label_style + " display: block; margin-bottom: 6px;",
            [text("Theme")],
          ),
          div(style="display: flex; gap: 4px;", [
            button(
              dyn_style=fn() {
                let is_active = state.theme_mode.get() == @model.Light
                if is_active {
                  theme_btn_style +
                  " background: #000; color: #fff; border-color: #000;"
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
                  theme_btn_style +
                  " background: #000; color: #fff; border-color: #000;"
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
        ],
      ),
      // プリセットカラー
      div(
        style="margin-bottom: 12px; border-top: 1px solid #eee; padding-top: 8px;",
        [
          @element.span(
            style=label_style + " display: block; margin-bottom: 6px;",
            [text("Preset Colors")],
          ),
          render_preset_colors(state),
        ],
      ),
      // 埋め込み背景色
      div(style=row_style + " border-top: 1px solid #eee; padding-top: 8px;", [
        @element.span(style=label_style, [text("Embed BG")]),
        input(
          type_="text",
          style=text_input_style,
          placeholder="transparent",
          dyn_value=fn() {
            let bg = state.embed_bg.get()
            if bg == "transparent" {
              ""
            } else {
              bg
            }
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
fn render_preset_colors(state : @core.EditorState) -> @element.DomNode {
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
          @element.span(style="font-size: 9px; color: #999;", [
            text(preset_name),
          ]),
        ],
      ),
    )
  }
  div(style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px;", [
    @element.fragment(children),
  ])
}

///|
/// 共通スタイルエディタコンポーネント（コンテキストメニュー・詳細パネル両方で使用）
/// close_menu: メニューを閉じるコールバック（コンテキストメニュー用、詳細パネルでは空の関数を渡す）
pub fn render_style_editor(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
  close_menu : () -> Unit,
) -> @element.DomNode {
  let theme = state.get_theme()
  let section_style = "margin-bottom: 8px;"
  let label_style = "font-size: 11px; color: \{theme.ui_text_muted}; min-width: 40px;"
  @element.fragment([
    // Stroke セクション
    div(style=section_style, [
      div(
        style="display: flex; align-items: center; gap: 8px;",
        [
          @element.span(style=label_style, [text("Stroke")]),
          render_color_editor(state, history, element_id, false, close_menu),
        ],
      ),
    ]),
    // Fill セクション
    div(style=section_style, [
      div(
        style="display: flex; align-items: center; gap: 8px;",
        [
          @element.span(style=label_style, [text("Fill")]),
          render_color_editor(state, history, element_id, true, close_menu),
        ],
      ),
    ]),
    // Text 専用オプション（フォント選択）
    show(
      fn() {
        match state.find_element(element_id) {
          Some(el) => el.shape is @model.Text(_, _)
          None => false
        }
      },
      fn() { render_text_style_editor(state, history, element_id, close_menu) },
    ),
    // Line 専用オプション（破線、矢印）
    show(
      fn() {
        match state.find_element(element_id) {
          Some(el) => el.shape is @model.Line(_, _)
          None => false
        }
      },
      fn() { render_line_style_editor(state, history, element_id, close_menu) },
    ),
  ])
}

///|
/// 色エディタ（現在の色ボタン + カラーピッカー + 透明ボタン）
fn render_color_editor(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
  is_fill : Bool,
  _close_menu : () -> Unit,
) -> @element.DomNode {
  div(
    style="display: flex; align-items: center; gap: 4px;",
    [
      // 現在の色を表示するボタン
      @element.create_element(
        "button",
        [
          (
            "style",
            @element.Dynamic(fn() {
              let color = match state.find_element(element_id) {
                Some(el) =>
                  if is_fill {
                    el.style.fill.unwrap_or("transparent")
                  } else {
                    el.style.stroke.unwrap_or("#000000")
                  }
                None => if is_fill { "transparent" } else { "#000000" }
              }
              let bg = if color == "transparent" {
                "linear-gradient(45deg, #ccc 25%, transparent 25%), linear-gradient(-45deg, #ccc 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #ccc 75%), linear-gradient(-45deg, transparent 75%, #ccc 75%); background-size: 6px 6px; background-position: 0 0, 0 3px, 3px -3px, -3px 0px"
              } else {
                color
              }
              "width: 28px; height: 22px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; background: \{bg};"
            }),
          ),
        ],
        [],
      ),
      // ネイティブカラーピッカー
      input(
        type_="color",
        style="width: 22px; height: 22px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer;",
        dyn_value=fn() {
          match state.find_element(element_id) {
            Some(el) => {
              let color = if is_fill {
                el.style.fill.unwrap_or("transparent")
              } else {
                el.style.stroke.unwrap_or("#000000")
              }
              to_hex_color(
                color,
                if is_fill { "#ffffff" } else { "#000000" },
              )
            }
            None => if is_fill { "#ffffff" } else { "#000000" }
          }
        },
        on=events().input(fn(e) {
          if state.find_element(element_id) is Some(el) {
            let value = get_event_target_value(e.as_any())
            let old_style = el.style
            let new_style = if is_fill {
              { ..old_style, fill: Some(value) }
            } else {
              { ..old_style, stroke: Some(value) }
            }
            @core.execute_command(
              history,
              state,
              @model.UpdateStyle(element_id, old_style, new_style),
            )
          }
        }),
      ),
      // Fill の場合は透明ボタンを追加
      if is_fill {
        @element.create_element(
          "button",
          [
            (
              "style",
              @element.Static(
                "width: 22px; height: 22px; padding: 0; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 12px; background: white;",
              ),
            ),
            ("title", @element.Static("Transparent")),
            (
              "click",
              @element.Handler(fn(_) {
                if state.find_element(element_id) is Some(el) {
                  let old_style = el.style
                  let new_style = { ..old_style, fill: None }
                  @core.execute_command(
                    history,
                    state,
                    @model.UpdateStyle(element_id, old_style, new_style),
                  )
                }
              }),
            ),
          ],
          [@element.text("∅")],
        )
      } else {
        @element.fragment([])
      },
    ],
  )
}

///|
/// Text 用スタイルエディタ（フォント選択）
fn render_text_style_editor(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
  _close_menu : () -> Unit,
) -> @element.DomNode {
  let theme = state.get_theme()
  div(
    style="margin-top: 6px; padding-top: 6px; border-top: 1px solid \{theme.ui_border}; display: flex; align-items: center; gap: 6px;",
    [
      @element.span(style="font-size: 11px; color: \{theme.ui_text_muted};", [
        text("Font"),
      ]),
      div(
        style="display: flex; gap: 2px;",
        [render_font_buttons_shared(state, history, element_id)],
      ),
    ],
  )
}

///|
/// 共通フォントボタン群
fn render_font_buttons_shared(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
) -> @element.DomNode {
  let buttons : Array[@element.DomNode] = []
  for preset in font_family_presets {
    let (label, font_value) = preset
    buttons.push(
      button(
        style=toggle_button_style,
        dyn_style=fn() {
          let is_selected = match state.find_element(element_id) {
            Some(el) => el.style.font_family == font_value
            None => false
          }
          if is_selected {
            toggle_button_style + " background: #e3f2fd; border-color: #2196f3;"
          } else {
            toggle_button_style + " background: white;"
          }
        },
        on=events().click(fn(_) {
          if state.find_element(element_id) is Some(el) {
            let old_style = el.style
            let new_style = { ..old_style, font_family: font_value }
            @core.execute_command(
              history,
              state,
              @model.UpdateStyle(element_id, old_style, new_style),
            )
          }
        }),
        [text(label)],
      ),
    )
  }
  @element.fragment(buttons)
}

///|
/// Line 用スタイルエディタ（破線、矢印）
fn render_line_style_editor(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
  _close_menu : () -> Unit,
) -> @element.DomNode {
  let theme = state.get_theme()
  div(
    style="margin-top: 6px; padding-top: 6px; border-top: 1px solid \{theme.ui_border}; display: flex; align-items: center; gap: 6px; flex-wrap: wrap;",
    [
      // 破線パターン選択
      div(
        style="display: flex; gap: 2px;",
        [render_dasharray_buttons_shared(state, history, element_id)],
      ),
      // セパレータ
      @element.span(style="color: #ccc;", [text("|")]),
      // Arrow トグルボタン
      div(style="display: flex; gap: 4px; align-items: center;", [
        // Start Arrow
        button(
          style=toggle_button_style,
          dyn_style=fn() {
            let is_selected = match state.find_element(element_id) {
              Some(el) => el.style.marker_start is Some(@model.Arrow)
              None => false
            }
            if is_selected {
              toggle_button_style + " background: #e3f2fd; border-color: #2196f3;"
            } else {
              toggle_button_style + " background: white;"
            }
          },
          on=events().click(fn(_) {
            if state.find_element(element_id) is Some(el) {
              let old_style = el.style
              let new_marker = if old_style.marker_start is Some(@model.Arrow) {
                None
              } else {
                Some(@model.Arrow)
              }
              let new_style = { ..old_style, marker_start: new_marker }
              @core.execute_command(
                history,
                state,
                @model.UpdateStyle(element_id, old_style, new_style),
              )
            }
          }),
          [text("<")],
        ),
        // End Arrow
        button(
          style=toggle_button_style,
          dyn_style=fn() {
            let is_selected = match state.find_element(element_id) {
              Some(el) => el.style.marker_end is Some(@model.Arrow)
              None => false
            }
            if is_selected {
              toggle_button_style + " background: #e3f2fd; border-color: #2196f3;"
            } else {
              toggle_button_style + " background: white;"
            }
          },
          on=events().click(fn(_) {
            if state.find_element(element_id) is Some(el) {
              let old_style = el.style
              let new_marker = if old_style.marker_end is Some(@model.Arrow) {
                None
              } else {
                Some(@model.Arrow)
              }
              let new_style = { ..old_style, marker_end: new_marker }
              @core.execute_command(
                history,
                state,
                @model.UpdateStyle(element_id, old_style, new_style),
              )
            }
          }),
          [text(">")],
        ),
      ]),
    ],
  )
}

///|
/// 共通破線パターンボタン群
fn render_dasharray_buttons_shared(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
) -> @element.DomNode {
  let children : Array[@element.DomNode] = []
  for preset in dasharray_presets {
    let (label, pattern) = preset
    let btn = button(
      style=toggle_button_style,
      dyn_style=fn() {
        match state.find_element(element_id) {
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
      },
      on=events().click(fn(_) {
        if state.find_element(element_id) is Some(el) {
          let old_style = el.style
          let new_style = { ..old_style, stroke_dasharray: pattern }
          @core.execute_command(
            history,
            state,
            @model.UpdateStyle(element_id, old_style, new_style),
          )
        }
      }),
      [text(label)],
    )
    children.push(btn)
  }
  @element.fragment(children)
}

///|
/// Layer 操作コンポーネント
pub fn render_layer_operations(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
  close_menu : () -> Unit,
) -> @element.DomNode {
  let theme = state.get_theme()
  let btn_style = menu_button_style + " color: \{theme.ui_text};"
  let section_style = "padding: 4px 0;"
  @element.fragment([
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          if state.bring_to_front(element_id) is Some((from_idx, to_idx)) {
            let cmd = @model.ReorderElement(element_id, from_idx, to_idx)
            history.undo_stack.push(cmd)
            history.redo_stack.clear()
          }
          close_menu()
        }),
        [text("Bring to Front")],
      ),
    ]),
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          if state.bring_forward(element_id) is Some((from_idx, to_idx)) {
            let cmd = @model.ReorderElement(element_id, from_idx, to_idx)
            history.undo_stack.push(cmd)
            history.redo_stack.clear()
          }
          close_menu()
        }),
        [text("Bring Forward")],
      ),
    ]),
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          if state.send_backward(element_id) is Some((from_idx, to_idx)) {
            let cmd = @model.ReorderElement(element_id, from_idx, to_idx)
            history.undo_stack.push(cmd)
            history.redo_stack.clear()
          }
          close_menu()
        }),
        [text("Send Backward")],
      ),
    ]),
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          if state.send_to_back(element_id) is Some((from_idx, to_idx)) {
            let cmd = @model.ReorderElement(element_id, from_idx, to_idx)
            history.undo_stack.push(cmd)
            history.redo_stack.clear()
          }
          close_menu()
        }),
        [text("Send to Back")],
      ),
    ]),
  ])
}

///|
/// 削除ボタンコンポーネント
pub fn render_delete_button(
  state : @core.EditorState,
  history : @model.History,
  element_id : String,
  close_menu : () -> Unit,
) -> @element.DomNode {
  let btn_style = menu_button_style + " color: #e53e3e;"
  button(
    style=btn_style,
    on=events().click(fn(_) {
      if state.find_element(element_id) is Some(el) {
        @core.execute_command(history, state, @model.RemoveElement(el))
      }
      close_menu()
    }),
    [text("Delete")],
  )
}

///|
/// 要素ツリーをレンダリング
fn render_element_tree(state : @core.EditorState) -> @element.DomNode {
  let tree_style = "max-height: 300px; overflow-y: auto; padding: 4px;"
  let item_style = "display: flex; align-items: center; gap: 4px; padding: 4px 8px; cursor: pointer; border-radius: 3px; font-size: 11px;"
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
      @model.Path(_, _, _, _, _) => "✎"
      @model.Text(_, _) => "T"
    }
    let el_id = el.id
    let shape_name = @model.shape_name(el.shape)
    children.push(
      div(
        style=item_style,
        on=events().click(fn(_) { state.select(Some(el_id)) }),
        [
          @element.span(style="font-size: 14px; width: 16px;", [
            text(shape_icon),
          ]),
          @element.span(style="color: #666;", [text(shape_name)]),
          @element.span(style="color: #999; font-family: monospace;", [
            text("#" + el_id),
          ]),
        ],
      ),
    )
  }
  if children.length() == 0 {
    div(
      style="padding: 8px; color: #999; font-size: 11px; text-align: center;",
      [text("No elements")],
    )
  } else {
    div(style=tree_style, [@element.fragment(children)])
  }
}

///|
/// 小さい入力フィールドのスタイル（コンパクト版）
let small_input_style : String = "width: 48px; padding: 2px 4px; border: 1px solid #ddd; border-radius: 3px; font-family: monospace; font-size: 11px; box-sizing: border-box;"

///|
/// 読み取り専用フィールドのスタイル
let readonly_field_style : String = "font-family: monospace; font-size: 11px; padding: 2px 4px; background: #f5f5f5; border-radius: 3px; min-width: 36px; text-align: center;"

///|
/// ID入力フィールドのスタイル
let id_input_style : String = "flex: 1; padding: 2px 6px; border: 1px solid #ddd; border-radius: 3px; font-family: monospace; font-size: 11px; box-sizing: border-box;"

///|
/// ラベルのスタイル
let label_style : String = "font-size: 11px; color: #888; min-width: 12px;"

///|
/// 行のスタイル
let row_style : String = "display: flex; align-items: center; gap: 6px; margin-bottom: 6px;"

///|
/// 要素の詳細を表示・編集（コンパクト版）
fn render_element_details(
  state : @core.EditorState,
  history : @model.History,
) -> @element.DomNode {
  let id_error = @luna.signal(false)
  div(style="font-size: 12px;", [
    // Shape type + ID (一行)
    div(style=row_style, [
      @element.span(style="font-size: 12px; color: #333; font-weight: 500;", [
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
      @element.span(style="font-size: 11px; color: #999;", [text("#")]),
      input(
        type_="text",
        style=id_input_style,
        dyn_style=fn() {
          if id_error.get() {
            id_input_style + " border-color: #e53e3e; background: #fff5f5;"
          } else {
            id_input_style
          }
        },
        dyn_value=fn() { state.get_selected_id().unwrap_or("") },
        on=events().change(fn(e) {
          if state.get_selected_id() is Some(old_id) {
            let new_id = get_event_target_value(e.as_any())
            if new_id != "" && new_id != old_id {
              if state.has_element_with_id(new_id) {
                id_error.set(true)
              } else {
                @core.execute_command(
                  history,
                  state,
                  @model.RenameElement(old_id, new_id),
                )
                id_error.set(false)
              }
            }
          }
        }),
      ),
    ]),
    // Position & Size (2行をコンパクトに)
    div(
      style="display: grid; grid-template-columns: 1fr 1fr; gap: 4px; margin-bottom: 8px; padding: 6px; background: #f8f8f8; border-radius: 4px;",
      [
        // x
        div(style="display: flex; align-items: center; gap: 4px;", [
          @element.span(style=label_style, [text("x")]),
          input(
            type_="number",
            style=small_input_style + " flex: 1;",
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
            on=events().input(fn(e) {
              if state.get_selected_id() is Some(id) {
                if state.find_element(id) is Some(el) {
                  let value = get_event_target_value(e.as_any())
                  if parse_double(value) is Some(new_x) {
                    @core.execute_command(
                      history,
                      state,
                      @model.MoveElement(id, el.x, el.y, new_x, el.y),
                    )
                  }
                }
              }
            }),
          ),
        ]),
        // y
        div(style="display: flex; align-items: center; gap: 4px;", [
          @element.span(style=label_style, [text("y")]),
          input(
            type_="number",
            style=small_input_style + " flex: 1;",
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
            on=events().input(fn(e) {
              if state.get_selected_id() is Some(id) {
                if state.find_element(id) is Some(el) {
                  let value = get_event_target_value(e.as_any())
                  if parse_double(value) is Some(new_y) {
                    @core.execute_command(
                      history,
                      state,
                      @model.MoveElement(id, el.x, el.y, el.x, new_y),
                    )
                  }
                }
              }
            }),
          ),
        ]),
        // w (readonly)
        div(style="display: flex; align-items: center; gap: 4px;", [
          @element.span(style=label_style, [text("w")]),
          @element.span(style=readonly_field_style + " flex: 1;", [
            text_dyn(fn() {
              match state.get_selected_id() {
                Some(id) =>
                  match state.find_element(id) {
                    Some(el) => el.bounding_box().width.to_int().to_string()
                    None => "-"
                  }
                None => "-"
              }
            }),
          ]),
        ]),
        // h (readonly)
        div(style="display: flex; align-items: center; gap: 4px;", [
          @element.span(style=label_style, [text("h")]),
          @element.span(style=readonly_field_style + " flex: 1;", [
            text_dyn(fn() {
              match state.get_selected_id() {
                Some(id) =>
                  match state.find_element(id) {
                    Some(el) => el.bounding_box().height.to_int().to_string()
                    None => "-"
                  }
                None => "-"
              }
            }),
          ]),
        ]),
      ],
    ),
    // Style section - 共通コンポーネント使用（Stroke, Fill, Text font, Line style）
    show(fn() { state.get_selected_id() is Some(_) }, fn() {
      let id = state.get_selected_id().unwrap()
      let noop = fn() {  }
      @element.fragment([
        render_style_editor(state, history, id, noop),
        // stroke-width（詳細パネル専用）
        div(style="display: flex; align-items: center; gap: 8px; margin-top: 8px;", [
          @element.span(style="font-size: 11px; color: #666; min-width: 40px;", [
            text("Width"),
          ]),
          input(
            type_="number",
            style="width: 50px; padding: 2px 4px; border: 1px solid #ddd; border-radius: 3px; font-size: 10px;",
            attrs=[
              ("min", @element.AttrString("0")),
              ("step", @element.AttrString("0.5")),
            ],
            dyn_value=fn() {
              match state.find_element(id) {
                Some(el) => el.style.stroke_width.unwrap_or(1.0).to_string()
                None => "1"
              }
            },
            on=events().change(fn(e) {
              if state.find_element(id) is Some(el) {
                let value = get_event_target_value(e.as_any())
                if parse_double(value) is Some(w) {
                  let old_style = el.style
                  let new_style = { ..old_style, stroke_width: Some(w) }
                  @core.execute_command(
                    history,
                    state,
                    @model.UpdateStyle(id, old_style, new_style),
                  )
                }
              }
            }),
          ),
          @element.span(style="font-size: 10px; color: #999;", [text("px")]),
        ]),
      ])
    }),
  ])
}

///|
/// トグルボタンのスタイル
let toggle_button_style : String = "padding: 2px 6px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; font-size: 10px;"

///|
/// フォントファミリーのプリセット
let font_family_presets : Array[(String, String?)] = [
  ("Sans", None), // システムデフォルト
  ("Serif", Some("serif")),
  ("Mono", Some("monospace")),
]

///|
/// 破線パターンのプリセット（短いラベル）
let dasharray_presets : Array[(String, String?)] = [
  ("―", None),
  ("--", Some("8,4")),
  ("··", Some("2,4")),
  ("-·", Some("8,4,2,4")),
]

///|
/// テキスト入力オーバーレイをレンダリング
pub fn render_text_input(
  state : @core.EditorState,
  commit : (String) -> Unit,
  cancel : () -> Unit,
) -> @element.DomNode {
  guard state.text_edit.get() is Some(edit_state)
  let vp = state.viewport.get()
  // 親要素がある場合は親の中央座標を使用
  let (text_x, text_y, max_width) : (Double, Double, Double) = match
    state.find_element(edit_state.parent_id) {
    Some(parent) => {
      let bbox = parent.bounding_box()
      let center_x = bbox.x + bbox.width / 2.0
      let center_y = bbox.y + bbox.height / 2.0
      (center_x, center_y, bbox.width * vp.zoom - 16.0)
    }
    None => (edit_state.x, edit_state.y, 200.0)
  }
  // シーン座標をスクリーン座標に変換
  let screen_pos = vp.scene_to_screen(text_x, text_y)
  // テキストエリア（背景色でSVGテキストを覆う）
  let min_width = if max_width < 40.0 { 40.0 } else { max_width }
  let style = "position: absolute; left: \{screen_pos.x}px; top: \{screen_pos.y}px; transform: translate(-50%, -50%); min-width: \{min_width}px; height: 24px; padding: 2px 4px; border: none; background: #ffffff; color: #000000; font-family: sans-serif; font-size: 16px; line-height: 1.2; text-align: center; outline: none; box-sizing: border-box; resize: none; overflow: hidden; caret-color: currentColor; white-space: nowrap; border-radius: 2px;"
  // リアルタイム更新用のコールバック
  let editing_id = edit_state.editing_id
  let initial_text = edit_state.initial_text
  let on_input = fn(value : String) {
    match editing_id {
      Some(id) => state.update_text_raw(id, value)
      None => ()
    }
  }
  let on_escape = fn(_value : String) {
    // キャンセル時は元のテキストに戻す
    match editing_id {
      Some(id) => state.update_text_raw(id, initial_text)
      None => ()
    }
    cancel()
  }
  // FFIでtextareaを作成
  let textarea = create_textarea_ffi(
    style,
    initial_text,
    fn(value) { commit(value) },
    on_escape,
    on_input,
  )
  let node : @js_dom.Node = textarea.cast()
  @element.dom_node(node)
}

///|
/// コンテキストメニューをレンダリング
pub fn render_context_menu(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
) -> @element.DomNode {
  guard state.context_menu.get() is Some(menu)
  let theme = state.get_theme()
  let is_dark = state.theme_mode.get() == @model.Dark
  let shadow = if is_dark { "rgba(0,0,0,0.4)" } else { "rgba(0,0,0,0.1)" }
  let style = "position: fixed; left: \{menu.x}px; top: \{menu.y}px; background: \{theme.ui_bg}; border: 1px solid \{theme.ui_border}; border-radius: 4px; box-shadow: 2px 2px 10px \{shadow}; min-width: 140px; z-index: 1000; color: \{theme.ui_text};"
  let section_style = "padding: 4px 12px; border-bottom: 1px solid \{theme.ui_border};"
  let header_style = "padding: 4px 12px; border-bottom: 1px solid \{theme.ui_border}; color: \{theme.ui_text_muted}; font-size: 11px;"
  let close_menu = fn() { state.hide_context_menu() }
  div(style~, [
    // 要素上でクリックした場合のみメニューを表示
    if menu.target_id is Some(id) {
      @element.fragment([
        // Style section - 共通コンポーネント使用
        div(style=section_style, [
          render_style_editor(state, history, id, close_menu),
        ]),
        // Layer section header
        div(style=header_style, [text("Layer")]),
        // Layer operations - 共通コンポーネント使用
        render_layer_operations(state, history, id, close_menu),
        // Delete - 共通コンポーネント使用
        div(style="padding: 4px 12px;", [
          render_delete_button(state, history, id, close_menu),
        ]),
      ])
    } else {
      // 空白部分を右クリックした場合 - 挿入メニュー
      render_insert_menu(state, history, new_id, menu.scene_x, menu.scene_y)
    },
  ])
}

///|
/// 挿入メニューをレンダリング
fn render_insert_menu(
  state : @core.EditorState,
  history : @model.History,
  new_id : () -> String,
  insert_x : Double,
  insert_y : Double,
) -> @element.DomNode {
  let theme = state.get_theme()
  let section_style = "padding: 4px 12px; border-bottom: 1px solid \{theme.ui_border};"
  let header_style = "padding: 4px 12px; border-bottom: 1px solid \{theme.ui_border}; color: \{theme.ui_text_muted}; font-size: 12px;"
  let btn_style = menu_button_style + " color: \{theme.ui_text};"
  @element.fragment([
    div(style=header_style, [text("Insert")]),
    // Rectangle
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Rect(80.0, 60.0, None, None),
          ).with_style(state.get_default_style())
          @core.execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Rectangle")],
      ),
    ]),
    // Circle
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Circle(40.0),
          ).with_style(state.get_default_style())
          @core.execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Circle")],
      ),
    ]),
    // Ellipse
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Ellipse(60.0, 35.0),
          ).with_style(state.get_default_style())
          @core.execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Ellipse")],
      ),
    ]),
    // Line
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Line(insert_x + 100.0, insert_y + 50.0),
          ).with_style(state.get_line_style())
          @core.execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Line")],
      ),
    ]),
    // Arrow
    div(style=section_style, [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Line(insert_x + 100.0, insert_y + 50.0),
          ).with_style(state.get_arrow_style())
          @core.execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Arrow")],
      ),
    ]),
    // Text
    div(style="padding: 4px 12px;", [
      button(
        style=btn_style,
        on=events().click(fn(_) {
          let el = @model.Element::new(
            new_id(),
            insert_x,
            insert_y,
            @model.Text("Text", Some(24.0)),
          ).with_style(state.get_text_style())
          @core.execute_command(history, state, @model.AddElement(el))
          state.hide_context_menu()
        }),
        [text("Text")],
      ),
    ]),
  ])
}
