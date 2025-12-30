// キーバインド定義 - SSOT (Single Source of Truth)
// このファイルはドキュメント生成と実装の両方で参照される

///|
/// キーバインド定義
pub(all) struct KeyBinding {
  key : String // "1", "Delete", "ArrowUp" など
  ctrl : Bool // Ctrl キー必須
  shift : Bool // Shift キー必須
  meta : Bool // Cmd/Meta キー必須（macOS）
  action : String // 内部アクション識別子
  label : String // 表示用ラベル（英語）
  category : String // "Tool", "Edit", "Navigation" など
}

///|
/// キーバインドカテゴリ
pub let category_tool : String = "Tool"

///|
pub let category_edit : String = "Edit"

///|
pub let category_navigation : String = "Navigation"

///|
pub let category_mode : String = "Mode"

///|
/// 全キーバインド定義を取得
pub fn get_keybindings() -> Array[KeyBinding] {
  [
    // Tool: 図形作成
    {
      key: "1",
      ctrl: false,
      shift: false,
      meta: false,
      action: "create_rect",
      label: "Rectangle",
      category: category_tool,
    },
    {
      key: "2",
      ctrl: false,
      shift: false,
      meta: false,
      action: "create_circle",
      label: "Circle",
      category: category_tool,
    },
    {
      key: "3",
      ctrl: false,
      shift: false,
      meta: false,
      action: "create_ellipse",
      label: "Ellipse",
      category: category_tool,
    },
    {
      key: "4",
      ctrl: false,
      shift: false,
      meta: false,
      action: "create_line",
      label: "Line",
      category: category_tool,
    },
    {
      key: "5",
      ctrl: false,
      shift: false,
      meta: false,
      action: "create_arrow",
      label: "Arrow",
      category: category_tool,
    },
    {
      key: "6",
      ctrl: false,
      shift: false,
      meta: false,
      action: "create_text",
      label: "Text",
      category: category_tool,
    },
    // Edit: 編集操作
    {
      key: "Delete",
      ctrl: false,
      shift: false,
      meta: false,
      action: "delete",
      label: "Delete",
      category: category_edit,
    },
    {
      key: "Backspace",
      ctrl: false,
      shift: false,
      meta: false,
      action: "delete",
      label: "Delete",
      category: category_edit,
    },
    {
      key: "Escape",
      ctrl: false,
      shift: false,
      meta: false,
      action: "escape",
      label: "Cancel / Deselect",
      category: category_edit,
    },
    // Navigation: 移動操作
    {
      key: "ArrowUp",
      ctrl: false,
      shift: false,
      meta: false,
      action: "move_up",
      label: "Move Up",
      category: category_navigation,
    },
    {
      key: "ArrowDown",
      ctrl: false,
      shift: false,
      meta: false,
      action: "move_down",
      label: "Move Down",
      category: category_navigation,
    },
    {
      key: "ArrowLeft",
      ctrl: false,
      shift: false,
      meta: false,
      action: "move_left",
      label: "Move Left",
      category: category_navigation,
    },
    {
      key: "ArrowRight",
      ctrl: false,
      shift: false,
      meta: false,
      action: "move_right",
      label: "Move Right",
      category: category_navigation,
    },
    // Mode: モード切替
    {
      key: "p",
      ctrl: false,
      shift: false,
      meta: false,
      action: "toggle_draw_mode",
      label: "Toggle Draw Mode",
      category: category_mode,
    },
    {
      key: "P",
      ctrl: false,
      shift: false,
      meta: false,
      action: "toggle_draw_mode",
      label: "Toggle Draw Mode",
      category: category_mode,
    },
    {
      key: "v",
      ctrl: false,
      shift: false,
      meta: false,
      action: "select_mode",
      label: "Select Mode",
      category: category_mode,
    },
    {
      key: "V",
      ctrl: false,
      shift: false,
      meta: false,
      action: "select_mode",
      label: "Select Mode",
      category: category_mode,
    },
    // Help
    {
      key: "?",
      ctrl: false,
      shift: false,
      meta: false,
      action: "show_help",
      label: "Show Help",
      category: category_edit,
    },
  ]
}

///|
/// カテゴリでフィルタしたキーバインドを取得
pub fn get_keybindings_by_category(category : String) -> Array[KeyBinding] {
  get_keybindings().filter(fn(kb) { kb.category == category })
}

///|
/// アクションに対応するキーバインドを検索
pub fn find_keybinding_by_action(action : String) -> KeyBinding? {
  for kb in get_keybindings() {
    if kb.action == action {
      return Some(kb)
    }
  }
  None
}

///|
/// キーイベントに一致するキーバインドを検索
pub fn match_keybinding(
  key : String,
  ctrl : Bool,
  shift : Bool,
  meta : Bool,
) -> KeyBinding? {
  let is_cmd = ctrl || meta
  for kb in get_keybindings() {
    // Ctrl/Meta はどちらかが true なら一致
    let kb_cmd = kb.ctrl || kb.meta
    if kb.key == key && kb_cmd == is_cmd && kb.shift == shift {
      return Some(kb)
    }
  }
  None
}

///|
/// キーバインドを表示用文字列に変換
pub fn keybinding_to_string(kb : KeyBinding) -> String {
  let mut s = ""
  if kb.ctrl || kb.meta {
    s = s + "Ctrl+"
  }
  if kb.shift {
    s = s + "Shift+"
  }
  s = s + kb.key
  s
}
