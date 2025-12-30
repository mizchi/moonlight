// アコーディオン（折りたたみセクション）コンポーネント

///|
/// アコーディオンセクション
pub fn accordion_section(
  title : String,
  initial_open : Bool,
  theme : @model.Theme,
  content : () -> @element.DomNode,
) -> @element.DomNode {
  let is_open = @luna.signal(initial_open)
  @element.div(style="margin-bottom: 8px;", [
    // ヘッダー
    @element.div(
      style=accordion_header_style(theme),
      on=@element.events().click(fn(_) { is_open.update(fn(v) { not(v) }) }),
      [
        @element.text(title),
        @element.text_dyn(fn() { if is_open.get() { "▼" } else { "▶" } }),
      ],
    ),
    // コンテンツ
    @element.show(fn() { is_open.get() }, content),
  ])
}

///|
/// 折りたたみセクション（Signal を外部から渡す版）
pub fn collapsible_section(
  title : String,
  is_open : @luna.Signal[Bool],
  theme : @model.Theme,
  content : () -> @element.DomNode,
) -> @element.DomNode {
  @element.div(style="margin-bottom: 8px;", [
    @element.div(
      style=accordion_header_style(theme),
      on=@element.events().click(fn(_) { is_open.update(fn(v) { not(v) }) }),
      [
        @element.text(title),
        @element.text_dyn(fn() { if is_open.get() { "▼" } else { "▶" } }),
      ],
    ),
    @element.show(fn() { is_open.get() }, content),
  ])
}

///|
/// セクション区切り
pub fn section_divider(theme : @model.Theme) -> @element.DomNode {
  @element.div(style=section_divider_style(theme), [])
}

///|
/// パネルセクション（枠付き）
pub fn panel_section(
  theme : @model.Theme,
  children : Array[@element.DomNode],
) -> @element.DomNode {
  @element.div(style=panel_section_style(theme), children)
}
