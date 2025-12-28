// UI コンポーネント - ボタン

///|
using @element {div, text}

///|
/// ツールバーボタン用のユニーク ID カウンター
let toolbar_btn_id_counter : Ref[Int] = { val: 0 }

///|
/// SVG アイコンを作成するヘルパー
pub fn svg_icon(path_d : String, size : Int) -> @element.DomNode {
  let size_str = size.to_string()
  @element.create_element_ns(
    @element.svg_ns,
    "svg",
    [
      ("width", @element.Static(size_str)),
      ("height", @element.Static(size_str)),
      ("viewBox", @element.Static("0 0 24 24")),
      ("fill", @element.Static("none")),
      ("stroke", @element.Static("currentColor")),
      ("stroke-width", @element.Static("2")),
      ("stroke-linecap", @element.Static("round")),
      ("stroke-linejoin", @element.Static("round")),
      ("style", @element.Static("display: block;")),
    ],
    [
      @element.create_element_ns(
        @element.svg_ns,
        "path",
        [("d", @element.Static(path_d))],
        [],
      ),
    ],
  )
}

///|
/// Popover を表示してボタン位置に配置
extern "js" fn show_popover_at_button(popover_id : String, e : @js.Any) =
  #| (popoverId, e) => {
  #|   const popover = document.getElementById(popoverId);
  #|   if (!popover) return;
  #|   const btn = e.currentTarget;
  #|   const rect = btn.getBoundingClientRect();
  #|   popover.showPopover();
  #|   popover.style.left = (rect.left + rect.width / 2) + 'px';
  #|   popover.style.top = (rect.bottom + 6) + 'px';
  #|   popover.style.transform = 'translateX(-50%)';
  #| }

///|
/// Popover を非表示
extern "js" fn hide_popover(popover_id : String) =
  #| (popoverId) => {
  #|   const popover = document.getElementById(popoverId);
  #|   if (popover) popover.hidePopover();
  #| }

///|
/// ツールバーボタン（アイコン + キーバインド + Popover ツールチップ）
pub fn toolbar_button(
  icon : @element.DomNode,
  shortcut : String?,
  tooltip : String,
  on_click : () -> Unit,
  theme? : @model.Theme = @model.Theme::light(),
) -> @element.DomNode {
  toolbar_btn_id_counter.val = toolbar_btn_id_counter.val + 1
  let popover_id = "tooltip-\{toolbar_btn_id_counter.val}"
  let btn_style = "display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; padding: 4px 6px; cursor: pointer; border: 1px solid \{theme.ui_border}; border-radius: 4px; background: \{theme.ui_bg}; min-width: 36px; height: 40px; position: relative; color: \{theme.ui_text};"
  let shortcut_style = "color: \{theme.ui_text_muted}; font-size: 9px; font-family: system-ui, sans-serif; line-height: 1;"
  let popover_style = "position: fixed; margin: 0; padding: 4px 8px; background: #333; color: #fff; font-size: 11px; border-radius: 4px; white-space: nowrap; border: none;"
  div(style="position: relative; display: inline-block;", [
    @element.create_element(
      "button",
      [
        ("style", @element.Static(btn_style)),
        ("aria-label", @element.Static(tooltip)),
        ("click", @element.Handler(fn(_) { on_click() })),
        (
          "mouseenter",
          @element.Handler(fn(e) { show_popover_at_button(popover_id, e) }),
        ),
        ("mouseleave", @element.Handler(fn(_) { hide_popover(popover_id) })),
      ],
      match shortcut {
        Some(key) => [icon, @element.span(style=shortcut_style, [text(key)])]
        None => [icon]
      },
    ),
    // Popover ツールチップ
    div(
      style=popover_style,
      attrs=[
        ("id", @element.AttrString(popover_id)),
        ("popover", @element.AttrString("manual")),
      ],
      [text(tooltip)],
    ),
  ])
}

///|
/// セパレータ（ツールバー用）
pub fn toolbar_separator(theme : @model.Theme) -> @element.DomNode {
  @element.span(
    style="width: 1px; height: 24px; background: \{theme.ui_border}; margin: 0 2px;",
    [],
  )
}
