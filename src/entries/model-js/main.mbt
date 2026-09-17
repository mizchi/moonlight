// セマンティックモデルを JS へ橋渡しするエントリ
//
// 視覚テストは、同じシナリオテキストから
//   - エディタに流し込む初期 SVG
//   - 操作後にこうなっているはず、というモデルの予測
//   - 絵を見て確かめるべき主張（vlmkit に渡す）
// をすべてここから受け取る。テスト側でモデルを書き直さずに済む。

///|
/// シナリオを実行し、結果を JSON 文字列で返す。
///
/// 返る形:
/// {
///   "ok": true,
///   "initialSvg": "...",   // 入力を流す前の Moonlight SVG
///   "svg": "...",          // 流したあとの Moonlight SVG
///   "description": "...",  // モデルによるシーンの説明
///   "claims": ["..."],     // 絵を見て確かめるべき主張
///   "violations": ["..."], // 破れているジョイント（空であるべき）
///   "elements": [{ "id": ..., "x": ..., "y": ..., "shape": ..., "bbox": {...} }],
///   "joints": [{ "line": ..., "endpoint": ..., "target": ..., "anchor": ... }]
/// }
/// 解析に失敗した場合は { "ok": false, "error": "line N: ..." }。
pub fn runScenario(source : String, width : Int, height : Int) -> String {
  match @interaction.parse_scenario(source) {
    Err(e) => error_json(e.describe())
    Ok(scenario) =>
      scene_json(scenario.run(), width, height, Some(scenario.scene))
  }
}

///|
/// 既存の Moonlight SVG を読み込み、その上でシナリオを走らせる。
///
/// headless から「今ある図に足す・動かす」をするための入口。読めなければ
/// `{"ok":false,...}` を返す。
pub fn applyToSvg(
  svg : String,
  source : String,
  width : Int,
  height : Int,
) -> String {
  match scene_of_svg(svg) {
    None => error_json("could not read the SVG")
    Some(base) =>
      match @interaction.parse_scenario_onto(base, source) {
        Err(e) => error_json(e.describe())
        Ok(scenario) => scene_json(scenario.run(), width, height, Some(base))
      }
  }
}

///|
/// 既存の Moonlight SVG を読み込んで、そのシーンを説明する。
///
/// AI が「今どこに何があるか」を掴むための入口。
pub fn describeSvg(svg : String, width : Int, height : Int) -> String {
  match scene_of_svg(svg) {
    None => error_json("could not read the SVG")
    Some(scene) => scene_json(scene, width, height, None)
  }
}

///|
/// SVG 文字列を読み込んでシーンにする
fn scene_of_svg(svg : String) -> @interaction.Scene? {
  let counter : Ref[Int] = { val: 0, }
  let new_id = fn() -> String {
    counter.val = counter.val + 1
    "el-\{counter.val}"
  }
  let elements = @import.import_svg_elements(svg, new_id)
  if elements.length() == 0 && svg.trim(chars=" \n\t\r") != "" {
    // 図形がひとつも取れなかったのは、読めなかったのと区別が付かない。
    // 空の SVG を渡したいときは空文字列で。
    None
  } else {
    Some(@interaction.Scene::of(elements))
  }
}

///|
/// エラーを JSON にする
fn error_json(message : String) -> String {
  "{\"ok\":false,\"error\":\{json_string(message)}}"
}

///|
/// シーンひとつ分の JSON。`before` があれば初期 SVG も添える。
fn scene_json(
  scene : @interaction.Scene,
  width : Int,
  height : Int,
  before : @interaction.Scene?,
) -> String {
  let sb = StringBuilder()
  sb.write_string("{\"ok\":true")
  if before is Some(b) {
    sb.write_string(
      ",\"initialSvg\":\{json_string(scene_svg(b, width, height))}",
    )
  }
  sb.write_string(",\"svg\":\{json_string(scene_svg(scene, width, height))}")
  sb.write_string(",\"description\":\{json_string(scene.describe())}")
  sb.write_string(",\"claims\":\{json_strings(scene.visual_claims())}")
  sb.write_string(
    ",\"violations\":\{json_strings(scene.joint_violations().map(fn(v) { v.describe() }))}",
  )
  sb.write_string(",\"elements\":\{elements_json(scene)}")
  sb.write_string(",\"joints\":\{joints_json(scene)}")
  sb.write_string(",\"selection\":\{json_strings(scene.selection)}")
  sb.write_string("}")
  sb.to_string()
}

///|
/// シナリオのシーン部分だけを Moonlight SVG にする（入力は流さない）
pub fn sceneToSvg(source : String, width : Int, height : Int) -> String {
  match @interaction.parse_scenario(source) {
    Err(_) => ""
    Ok(scenario) => scene_svg(scenario.scene, width, height)
  }
}

///|
fn scene_svg(scene : @interaction.Scene, width : Int, height : Int) -> String {
  @render.elements_to_moonlight_svg(scene.elements, width, height, "#ffffff")
}

///|
fn elements_json(scene : @interaction.Scene) -> String {
  let parts = scene.elements.map(fn(el) {
    let bbox = el.bounding_box()
    let sb = StringBuilder()
    sb.write_string("{\"id\":\{json_string(el.id)}")
    sb.write_string(",\"shape\":\{json_string(@model.shape_name(el.shape))}")
    sb.write_string(",\"x\":\{num(el.x)},\"y\":\{num(el.y)}")
    sb.write_string(
      ",\"bbox\":{\"x\":\{num(bbox.x)},\"y\":\{num(bbox.y)},\"width\":\{num(bbox.width)},\"height\":\{num(bbox.height)}}",
    )
    match el.shape {
      @model.Line(x2, y2) =>
        sb.write_string(",\"x2\":\{num(x2)},\"y2\":\{num(y2)}")
      _ => ()
    }
    sb.write_string("}")
    sb.to_string()
  })
  "[\{parts.join(",")}]"
}

///|
fn joints_json(scene : @interaction.Scene) -> String {
  let parts = scene
    .joints()
    .map(fn(j) {
      let endpoint = match j.endpoint {
        @interaction.Start => "start"
        @interaction.End => "end"
      }
      let point = scene
        .endpoint_point(j.line_id, j.endpoint)
        .unwrap_or({ x: 0.0, y: 0.0, })
      "{\"line\":\{json_string(j.line_id)},\"endpoint\":\{json_string(endpoint)},\"target\":\{json_string(j.target_id)},\"anchor\":\{json_string(@model.anchor_to_string(j.anchor))},\"x\":\{num(point.x)},\"y\":\{num(point.y)}}"
    })
  "[\{parts.join(",")}]"
}

///|
/// 数値を JSON に書ける形にする
fn num(value : Double) -> String {
  @model.num_str(value)
}

///|
/// 文字列を JSON リテラルにする
fn json_string(s : String) -> String {
  let sb = StringBuilder()
  sb.write_string("\"")
  for ch in s {
    match ch {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      c =>
        if c.to_int() < 0x20 {
          // 制御文字は \u00XX に逃がす
          let code = c.to_int()
          let hex = [
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd',
            'e', 'f',
          ]
          sb.write_string("\\u00")
          sb.write_char(hex[code / 16])
          sb.write_char(hex[code % 16])
        } else {
          sb.write_char(c)
        }
    }
  }
  sb.write_string("\"")
  sb.to_string()
}

///|
/// 文字列配列を JSON 配列にする
fn json_strings(values : Array[String]) -> String {
  "[\{values.map(fn(v) { json_string(v) }).join(",")}]"
}

///|
fn main {
  // エクスポートは moon.pkg の link 設定で行われる
}
