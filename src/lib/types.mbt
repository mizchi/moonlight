// 共通ライブラリ - 型定義

///|
/// undefined かどうかチェック
extern "js" fn is_undefined_ffi(value : @js.Any) -> Bool =
  #| (value) => value === undefined

///|
/// エディタオプション（外部から渡される設定）
pub(all) struct EditorOptions {
  width : Int? // キャンバス幅（デフォルト: コンテナに合わせる）
  height : Int? // キャンバス高さ（デフォルト: アスペクト比維持）
  gridsnap : Bool // グリッドスナップ（デフォルト: false）
  theme : String? // テーマ ("light" | "dark"、デフォルト: "light")
  zoom : Double? // 初期ズーム（デフォルト: 1.0）
  is_readonly : Bool // 読み取り専用（デフォルト: false）
  toolbar_visible : Bool // ツールバー表示（デフォルト: true）
  initial_svg : String? // 初期SVG（デフォルト: None）
}

///|
/// デフォルトオプション
pub fn EditorOptions::default() -> EditorOptions {
  {
    width: None,
    height: None,
    gridsnap: false,
    theme: Some("light"),
    zoom: Some(1.0),
    is_readonly: false,
    toolbar_visible: true,
    initial_svg: None,
  }
}

///|
/// JavaScript オブジェクトから EditorOptions を解析
pub fn EditorOptions::from_js(obj : @js.Any) -> EditorOptions {
  let default_opts = EditorOptions::default()
  let width : Int? = if is_undefined_ffi(obj._get("width")) {
    None
  } else {
    Some(obj._get("width").cast())
  }
  let height : Int? = if is_undefined_ffi(obj._get("height")) {
    None
  } else {
    Some(obj._get("height").cast())
  }
  let gridsnap : Bool = if is_undefined_ffi(obj._get("gridsnap")) {
    default_opts.gridsnap
  } else {
    obj._get("gridsnap").cast()
  }
  let theme : String? = if is_undefined_ffi(obj._get("theme")) {
    default_opts.theme
  } else {
    Some(obj._get("theme").cast())
  }
  let zoom : Double? = if is_undefined_ffi(obj._get("zoom")) {
    default_opts.zoom
  } else {
    Some(obj._get("zoom").cast())
  }
  let is_readonly : Bool = if is_undefined_ffi(obj._get("readonly")) {
    default_opts.is_readonly
  } else {
    obj._get("readonly").cast()
  }
  let toolbar_visible : Bool = if is_undefined_ffi(obj._get("toolbarVisible")) {
    default_opts.toolbar_visible
  } else {
    obj._get("toolbarVisible").cast()
  }
  let initial_svg : String? = if is_undefined_ffi(obj._get("initialSvg")) {
    None
  } else {
    Some(obj._get("initialSvg").cast())
  }
  {
    width,
    height,
    gridsnap,
    theme,
    zoom,
    is_readonly,
    toolbar_visible,
    initial_svg,
  }
}

///|
/// テーマ文字列を ThemeMode に変換
pub fn parse_theme(theme : String?) -> @model.ThemeMode {
  match theme {
    Some("dark") => @model.Dark
    _ => @model.Light
  }
}

///|
/// プレビューオプション
pub(all) struct PreviewOptions {
  width : Int? // 幅
  height : Int? // 高さ
  click_to_edit : Bool // クリックでモーダルを開く
  modal_fullscreen : Bool // モーダルをフルスクリーンにする
}

///|
/// アンカータイプを文字列から変換
pub fn parse_anchor_type(s : String) -> @core.AnchorType? {
  match s {
    "top" => Some(@core.Top)
    "bottom" => Some(@core.Bottom)
    "left" => Some(@core.Left)
    "right" => Some(@core.Right)
    "center" => Some(@core.Center)
    "line-start" => Some(@core.LineStart)
    "line-end" => Some(@core.LineEnd)
    _ => None
  }
}

///|
/// アンカータイプを文字列に変換
pub fn anchor_type_to_string(anchor : @core.AnchorType) -> String {
  match anchor {
    @core.Top => "top"
    @core.Bottom => "bottom"
    @core.Left => "left"
    @core.Right => "right"
    @core.Center => "center"
    @core.LineStart => "line-start"
    @core.LineEnd => "line-end"
  }
}

///|
/// デフォルトプレビューオプション
pub fn PreviewOptions::default() -> PreviewOptions {
  { width: None, height: None, click_to_edit: true, modal_fullscreen: false }
}
