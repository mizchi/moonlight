// カラーピッカーコンポーネント

///|
/// カラースウォッチ（単一の色ボタン）
pub fn color_swatch(
  color : String,
  size : Int,
  is_selected : Bool,
  on_click : () -> Unit,
) -> @element.DomNode {
  let border = if is_selected { "2px solid #0066ff" } else { "1px solid #ccc" }
  let bg = if color == "transparent" {
    "linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%), linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%); background-size: 8px 8px; background-position: 0 0, 4px 4px"
  } else {
    color
  }
  let size_str = size.to_string()
  @element.button(
    style="width: \{size_str}px; height: \{size_str}px; border: \{border}; border-radius: 3px; cursor: pointer; padding: 0; background: \{bg};",
    on=@element.events().click(fn(_) { on_click() }),
    [],
  )
}

///|
/// カラースウォッチグリッド
pub fn color_swatch_grid(
  colors : Array[String],
  current_color : String,
  swatch_size : Int,
  columns : Int,
  on_select : (String) -> Unit,
) -> @element.DomNode {
  @element.div(
    style=grid_style(columns, 4),
    colors.map(fn(color) {
      color_swatch(color, swatch_size, color == current_color, fn() {
        on_select(color)
      })
    }),
  )
}

///|
/// カラーピッカードロップダウン
pub fn color_picker_dropdown(
  current_color : String,
  colors : Array[String],
  on_change : (String) -> Unit,
  theme : @model.Theme,
) -> @element.DomNode {
  let dropdown_open = @luna.signal(false)
  @element.div(
    style="position: relative; display: flex; align-items: center; gap: 4px;",
    [
      // カラーインジケーター
      @element.button(
        dyn_style=fn() {
          let bg = if current_color == "transparent" {
            "linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%), linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%); background-size: 8px 8px; background-position: 0 0, 4px 4px"
          } else {
            current_color
          }
          "width: 20px; height: 22px; padding: 0; border: 1px solid \{theme.ui_border}; border-radius: 3px; cursor: pointer; background: \{bg};"
        },
        on=@element.events().click(fn(_) {
          dropdown_open.update(fn(v) { not(v) })
        }),
        [],
      ),
      // ドロップダウンパネル
      @element.show(fn() { dropdown_open.get() }, fn() {
        @element.div(
          style=dropdown_panel_style(theme),
          colors.map(fn(color) {
            color_swatch(color, 24, color == current_color, fn() {
              on_change(color)
              dropdown_open.set(false)
            })
          }),
        )
      }),
    ],
  )
}

///|
/// カラー入力付きピッカー
pub fn color_picker_with_input(
  label : String,
  current_color : String,
  colors : Array[String],
  on_change : (String) -> Unit,
  theme : @model.Theme,
) -> @element.DomNode {
  let dropdown_open = @luna.signal(false)
  let hex_color = to_hex_color(current_color, "#000000")
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    // カラーインジケーター
    @element.button(
      dyn_style=fn() {
        let bg = if current_color == "transparent" {
          "linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%), linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%); background-size: 8px 8px; background-position: 0 0, 4px 4px"
        } else {
          current_color
        }
        "width: 20px; height: 22px; padding: 0; border: 1px solid \{theme.ui_border}; border-radius: 3px; cursor: pointer; background: \{bg};"
      },
      on=@element.events().click(fn(_) {
        dropdown_open.update(fn(v) { not(v) })
      }),
      [],
    ),
    // テキスト入力
    @element.input(
      type_="color",
      style="width: 0; height: 0; padding: 0; border: none; visibility: hidden;",
      value=hex_color,
      on=@element.events().input(fn(e) {
        let value = get_input_value_cp(e.as_any())
        on_change(value)
      }),
    ),
    // ドロップダウン
    @element.show(fn() { dropdown_open.get() }, fn() {
      @element.div(
        style=dropdown_panel_style(theme),
        colors.map(fn(color) {
          color_swatch(color, 24, color == current_color, fn() {
            on_change(color)
            dropdown_open.set(false)
          })
        }),
      )
    }),
  ])
}

// ヘルパー関数

///|
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
fn get_input_value_cp(e : @js.Any) -> String {
  get_event_target_value_ffi(e)
}

///|
extern "js" fn get_event_target_value_ffi(e : @js.Any) -> String =
  #| (e) => e.target.value
