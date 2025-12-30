// フォーム入力コンポーネント

///|
/// 数値入力フィールド
pub fn number_field(
  label : String,
  value : Double,
  on_change : (Double) -> Unit,
  theme : @model.Theme,
) -> @element.DomNode {
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    @element.input(
      type_="number",
      style=small_input_style(theme),
      value=@model.num_str(value),
      on=@element.events().change(fn(e) {
        let str_value = get_input_value_ff(e.as_any())
        if parse_double(str_value) is Some(v) {
          on_change(v)
        }
      }),
    ),
  ])
}

///|
/// 動的数値入力フィールド
pub fn number_field_dyn(
  label : String,
  get_value : () -> Double,
  on_change : (Double) -> Unit,
  theme : @model.Theme,
) -> @element.DomNode {
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    @element.input(
      type_="number",
      style=small_input_style(theme),
      dyn_value=fn() { @model.num_str(get_value()) },
      on=@element.events().change(fn(e) {
        let str_value = get_input_value_ff(e.as_any())
        if parse_double(str_value) is Some(v) {
          on_change(v)
        }
      }),
    ),
  ])
}

///|
/// テキスト入力フィールド
pub fn text_field(
  label : String,
  value : String,
  on_change : (String) -> Unit,
  theme : @model.Theme,
) -> @element.DomNode {
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    @element.input(
      type_="text",
      style=text_input_style(theme),
      value~,
      on=@element.events().change(fn(e) {
        let v = get_input_value_ff(e.as_any())
        on_change(v)
      }),
    ),
  ])
}

///|
/// 動的テキスト入力フィールド
pub fn text_field_dyn(
  label : String,
  get_value : () -> String,
  on_change : (String) -> Unit,
  theme : @model.Theme,
) -> @element.DomNode {
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    @element.input(
      type_="text",
      style=text_input_style(theme),
      dyn_value=get_value,
      on=@element.events().change(fn(e) {
        let v = get_input_value_ff(e.as_any())
        on_change(v)
      }),
    ),
  ])
}

///|
/// ID 入力フィールド（モノスペースフォント）
pub fn id_field(
  label : String,
  get_value : () -> String,
  on_change : (String) -> Unit,
  theme : @model.Theme,
) -> @element.DomNode {
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    @element.input(
      type_="text",
      style=id_input_style(theme),
      dyn_value=get_value,
      on=@element.events().change(fn(e) {
        let v = get_input_value_ff(e.as_any())
        on_change(v)
      }),
    ),
  ])
}

///|
/// 読み取り専用フィールド
pub fn readonly_field(
  label : String,
  value : String,
  theme : @model.Theme,
) -> @element.DomNode {
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    @element.span(style=readonly_field_style(theme), [@element.text(value)]),
  ])
}

///|
/// 動的読み取り専用フィールド
pub fn readonly_field_dyn(
  label : String,
  get_value : () -> String,
  theme : @model.Theme,
) -> @element.DomNode {
  @element.div(style=row_style(), [
    @element.span(style=label_style(theme), [@element.text(label)]),
    @element.span(style=readonly_field_style(theme), [
      @element.text_dyn(get_value),
    ]),
  ])
}

// ヘルパー関数

///|
fn get_input_value_ff(e : @js.Any) -> String {
  get_event_value_ffi(e)
}

///|
extern "js" fn get_event_value_ffi(e : @js.Any) -> String =
  #| (e) => e.target.value

///|
fn parse_double(s : String) -> Double? {
  Some(@strconv.parse_double(s)) catch {
    _ => None
  }
}
