// 共通スタイル定数
// テーマに基づくスタイル生成関数を提供
// 注: このファイルは全てのコンポーネントから使用される

///|
/// ボタンスタイル
pub fn menu_button_style(theme : @model.Theme) -> String {
  "width: 100%; text-align: left; background: none; border: none; cursor: pointer; padding: 4px 8px; color: \{theme.ui_text};"
}

///|
/// 小さいボタンスタイル
pub fn small_button_style(theme : @model.Theme) -> String {
  "padding: 2px 6px; border: 1px solid \{theme.ui_border}; border-radius: 3px; cursor: pointer; font-size: 10px; background: \{theme.ui_bg}; color: \{theme.ui_text};"
}

///|
/// 行レイアウトスタイル
pub fn row_style() -> String {
  "display: flex; align-items: center; gap: 6px; margin-bottom: 6px;"
}

///|
/// ラベルスタイル
pub fn label_style(theme : @model.Theme) -> String {
  "font-size: 11px; color: \{theme.ui_text_muted}; min-width: 12px;"
}

///|
/// 小さい入力フィールドスタイル
pub fn small_input_style(theme : @model.Theme) -> String {
  "width: 48px; padding: 2px 4px; border: 1px solid \{theme.ui_border}; border-radius: 3px; font-family: monospace; font-size: 11px; box-sizing: border-box; background: \{theme.ui_bg}; color: \{theme.ui_text};"
}

///|
/// テキスト入力スタイル
pub fn text_input_style(theme : @model.Theme) -> String {
  "width: 70px; padding: 2px 4px; border: 1px solid \{theme.ui_border}; border-radius: 3px; font-size: 10px; background: \{theme.ui_bg}; color: \{theme.ui_text};"
}

///|
/// ID入力スタイル
pub fn id_input_style(theme : @model.Theme) -> String {
  "flex: 1; padding: 2px 6px; border: 1px solid \{theme.ui_border}; border-radius: 3px; font-family: monospace; font-size: 11px; box-sizing: border-box; background: \{theme.ui_bg}; color: \{theme.ui_text};"
}

///|
/// 読み取り専用フィールドスタイル
pub fn readonly_field_style(theme : @model.Theme) -> String {
  "font-family: monospace; font-size: 11px; padding: 2px 4px; background: \{theme.ui_bg_muted}; border-radius: 3px; min-width: 36px; text-align: center; color: \{theme.ui_text};"
}

///|
/// アコーディオンヘッダースタイル
pub fn accordion_header_style(theme : @model.Theme) -> String {
  "display: flex; align-items: center; justify-content: space-between; padding: 8px; background: \{theme.ui_bg_muted}; border-radius: 4px; cursor: pointer; font-size: 12px; font-weight: bold; color: \{theme.ui_text}; margin-bottom: 4px; user-select: none;"
}

///|
/// セクション区切りスタイル
pub fn section_divider_style(theme : @model.Theme) -> String {
  "margin-bottom: 12px; border-top: 1px solid \{theme.ui_border}; padding-top: 8px;"
}

///|
/// パネルセクションスタイル
pub fn panel_section_style(theme : @model.Theme) -> String {
  "padding: 8px; background: \{theme.ui_bg}; border: 1px solid \{theme.ui_border}; border-radius: 4px;"
}

///|
/// ドロップダウンパネルスタイル
pub fn dropdown_panel_style(theme : @model.Theme) -> String {
  "position: absolute; top: 100%; left: 0; margin-top: 4px; padding: 6px; background: \{theme.ui_bg}; border: 1px solid \{theme.ui_border}; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 100; display: grid; grid-template-columns: repeat(4, 1fr); gap: 4px;"
}

///|
/// カラースウォッチスタイル
pub fn color_swatch_style(color : String, size : Int) -> String {
  let size_str = size.to_string()
  let bg = if color == "transparent" {
    "linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%), linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%); background-size: 8px 8px; background-position: 0 0, 4px 4px"
  } else {
    color
  }
  "width: \{size_str}px; height: \{size_str}px; border: 1px solid #ccc; border-radius: 3px; cursor: pointer; padding: 0; background: \{bg};"
}

///|
/// ツリーアイテムスタイル
pub fn tree_item_style(theme : @model.Theme, is_selected : Bool) -> String {
  let bg = if is_selected { theme.ui_accent } else { "transparent" }
  let text_color = if is_selected { "#fff" } else { theme.ui_text }
  "display: flex; align-items: center; gap: 4px; padding: 4px 8px; cursor: pointer; border-radius: 3px; font-size: 11px; background: \{bg}; color: \{text_color};"
}

///|
/// グリッドレイアウトスタイル
pub fn grid_style(columns : Int, gap : Int) -> String {
  "display: grid; grid-template-columns: repeat(\{columns}, 1fr); gap: \{gap}px;"
}

///|
/// フレックス行スタイル
pub fn flex_row_style(gap : Int) -> String {
  "display: flex; align-items: center; gap: \{gap}px;"
}

///|
/// フレックス列スタイル
pub fn flex_column_style(gap : Int) -> String {
  "display: flex; flex-direction: column; gap: \{gap}px;"
}
