// プレビューモード - エントリポイント
// SVG をプレビュー表示し、クリックでモーダルを開く

///|
using @element {div, text, button, events, show}

///|
/// JavaScript グローバルに createPreview を登録
extern "js" fn register_create_preview(
  create_fn : (@js.Any, @js.Any, @js.Any) -> @js.Any,
) =
  #| (createFn) => {
  #|   globalThis.MoonlightPreview = {
  #|     create: createFn
  #|   };
  #| }

///|
/// ID カウンター
let id_counter : Ref[Int] = { val: 0 }

///|
/// 新しい ID を生成
fn new_id() -> String {
  id_counter.val = id_counter.val + 1
  "el-\{id_counter.val}"
}

///|
/// SVG コンテンツを保持する Signal
struct PreviewState {
  svg_content : @luna.Signal[String]
  modal_open : @luna.Signal[Bool]
  width : Int
  height : Int
}

///|
/// プレビューを作成（JavaScript から呼び出される）
fn create_preview_internal(
  container : @js.Any,
  svg_content : @js.Any,
  options_js : @js.Any,
) -> @js.Any {
  let options = @lib.EditorOptions::from_js(options_js)
  let width = options.width.unwrap_or(400)
  let height = options.height.unwrap_or(300)
  let svg_str : String = svg_content.cast()
  // 状態を作成
  let state : PreviewState = {
    svg_content: @luna.signal(svg_str),
    modal_open: @luna.signal(false),
    width,
    height,
  }
  // プレビュー部分（クリック可能）
  let preview_node = div(
    style="width: \{width}px; height: \{height}px; cursor: pointer; border: 1px solid #ddd; border-radius: 4px; overflow: hidden; position: relative;",
    on=events().click(fn(_e) { state.modal_open.set(true) }),
    [
      div(
        style="width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; background: #fafafa;",
        [text("SVG Preview (click to edit)")],
      ),
      // ホバー時のオーバーレイ
      div(
        style="position: absolute; inset: 0; background: rgba(0,0,0,0.3); opacity: 0; transition: opacity 0.2s; display: flex; align-items: center; justify-content: center; pointer-events: none; color: white; font-weight: bold;",
        class="preview-overlay",
        [text("Click to Edit")],
      ),
    ],
  )
  // モーダル部分
  let modal_node = show(
    fn() { state.modal_open.get() },
    fn() {
      div(
        style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 1000;",
        on=events().click(fn(_e) { state.modal_open.set(false) }),
        [
          div(
            style="background: white; border-radius: 8px; padding: 20px; max-width: 90vw; max-height: 90vh; overflow: auto;",
            on=events().click(fn(e) {
              // モーダル内のクリックは伝播を止める
              stop_propagation(e)
            }),
            [
              div(
                style="display: flex; justify-content: space-between; margin-bottom: 10px;",
                [
                  text("Editor"),
                  button(
                    style="background: #dc3545; color: white; border: none; padding: 4px 12px; border-radius: 4px; cursor: pointer;",
                    on=events().click(fn(_e) { state.modal_open.set(false) }),
                    [text("Close")],
                  ),
                ],
              ),
              // エディタ領域（SVG を表示）
              div(
                style="width: \{width}px; height: \{height}px; border: 1px solid #ccc; display: flex; align-items: center; justify-content: center; background: #f5f5f5;",
                [text("Editor Mode")],
              ),
            ],
          ),
        ],
      )
    },
  )
  // ルートノード
  let root_node = div([preview_node, modal_node])
  // DOM にレンダリング
  let container_el : @js_dom.Element = container.cast()
  @element.render(container_el |> @element.DomElement::from_dom, root_node)
  // ハンドルを返す
  @lib.create_preview_handle(
    fn() { state.modal_open.set(true) },
    fn() { state.modal_open.set(false) },
    fn() -> Bool { state.modal_open.get() },
    fn() -> String { state.svg_content.get() },
    fn(svg : String) { state.svg_content.set(svg) },
  )
}

///|
/// イベント伝播を停止
extern "js" fn stop_propagation(e : @js_dom.MouseEvent) =
  #| (e) => e.stopPropagation()

///|
/// メイン関数
fn main {
  register_create_preview(create_preview_internal)
}
