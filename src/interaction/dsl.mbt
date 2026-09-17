// シナリオ記述 DSL
//
// 「どんな図とジョイントがあり、そこに何をしたか」を一つのテキストで表す。
// 同じテキストからユニットテストの期待値も、ブラウザに流し込む初期 SVG も作れるので、
// セマンティックモデルと実際の描画がずれていないかを突き合わせられる。
//
// 例:
//   rect r1 100 100 80 60
//   circle c1 300 200 40
//   line l1 180 130 260 200
//   join l1 end c1 left
//   grid 20
//   press body r1 140 130
//   move 200 180
//   release
//
// 行頭の # と空行は無視する。

///|
/// 解析済みシナリオ
pub(all) struct Scenario {
  /// 入力を流す前のシーン
  scene : Scene
  /// 流す入力
  inputs : Array[Input]
} derive(Debug, Eq)

///|
/// シナリオの解析エラー（行番号付き）
pub(all) struct ScenarioError {
  line : Int
  message : String
} derive(Debug, Eq)

///|
/// エラーを一行で説明する
pub fn ScenarioError::describe(self : ScenarioError) -> String {
  "line \{self.line}: \{self.message}"
}

///|
/// シナリオテキストを解析する
pub fn parse_scenario(source : String) -> Result[Scenario, ScenarioError] {
  parse_scenario_onto(Scene::empty(), source)
}

///|
/// すでにあるシーンの上にシナリオを解析する。
///
/// headless で既存の SVG を読み込み、その続きを書き足すときに使う。空のシーンを
/// 渡せば `parse_scenario` と同じ。
pub fn parse_scenario_onto(
  base : Scene,
  source : String,
) -> Result[Scenario, ScenarioError] {
  let mut scene = base
  let inputs : Array[Input] = []
  let mut line_no = 0
  for raw in source.split("\n") {
    line_no = line_no + 1
    let words = split_words(raw.to_owned())
    if words.length() == 0 || words[0].has_prefix("#") {
      continue
    }
    let fail = fn(message : String) -> Result[Scenario, ScenarioError] {
      Err({ line: line_no, message, })
    }
    let head = words[0]
    let args = words[1:].to_owned()
    match head {
      "rect" => {
        guard args.length() >= 5 else {
          return fail("rect needs: id x y width height")
        }
        scene = scene.add(
          rect(args[0], num(args[1]), num(args[2]), num(args[3]), num(args[4])),
        )
      }
      "circle" => {
        guard args.length() >= 4 else {
          return fail("circle needs: id cx cy r")
        }
        scene = scene.add(
          circle(args[0], num(args[1]), num(args[2]), num(args[3])),
        )
      }
      "ellipse" => {
        guard args.length() >= 5 else {
          return fail("ellipse needs: id cx cy rx ry")
        }
        scene = scene.add(
          ellipse(
            args[0],
            num(args[1]),
            num(args[2]),
            num(args[3]),
            num(args[4]),
          ),
        )
      }
      "line" => {
        guard args.length() >= 5 else {
          return fail("line needs: id x1 y1 x2 y2")
        }
        scene = scene.add(
          line(args[0], num(args[1]), num(args[2]), num(args[3]), num(args[4])),
        )
      }
      "text" => {
        guard args.length() >= 4 else {
          return fail("text needs: id x y content")
        }
        let content = args[3:].to_owned().join(" ")
        scene = scene.add(text(args[0], num(args[1]), num(args[2]), content))
      }
      "join" => {
        guard args.length() >= 4 else {
          return fail("join needs: line-id start|end target-id anchor")
        }
        guard parse_endpoint(args[1]) is Some(endpoint) else {
          return fail("unknown endpoint '\{args[1]}', expected start or end")
        }
        guard @model.parse_anchor(args[3]) is Some(anchor) else {
          return fail("unknown anchor '\{args[3]}'")
        }
        guard scene.find(args[0]) is Some(_) else {
          return fail("no such line '\{args[0]}'")
        }
        guard scene.find(args[2]) is Some(_) else {
          return fail("no such element '\{args[2]}'")
        }
        scene = scene.connect(args[0], endpoint, args[2], anchor)
      }
      "grid" => {
        guard args.length() >= 1 else {
          return fail("grid needs: size (0 = off)")
        }
        let size = num(args[0])
        scene = scene.with_grid(
          if size > 0.0 {
            Grid::of(size)
          } else {
            Grid::off()
          },
        )
      }
      "select" => scene = scene.with_selection(args)
      "press" => {
        guard args.length() >= 1 else {
          return fail("press needs: canvas|body|handle ...")
        }
        match args[0] {
          "canvas" => {
            guard args.length() >= 3 else {
              return fail("press canvas needs: x y")
            }
            inputs.push(Press(Canvas, { x: num(args[1]), y: num(args[2]), }))
          }
          "body" => {
            guard args.length() >= 4 else {
              return fail("press body needs: id x y")
            }
            inputs.push(
              Press(Body(args[1]), { x: num(args[2]), y: num(args[3]), }),
            )
          }
          "handle" => {
            guard args.length() >= 5 else {
              return fail("press handle needs: id handle x y")
            }
            inputs.push(
              Press(Handle(args[1], @model.parse_handle_position(args[2])), {
                x: num(args[3]),
                y: num(args[4]),
              }),
            )
          }
          other => return fail("unknown press target '\{other}'")
        }
      }
      "move" => {
        guard args.length() >= 2 else { return fail("move needs: x y") }
        inputs.push(MoveTo({ x: num(args[0]), y: num(args[1]), }))
      }
      "release" => inputs.push(Release)
      "cancel" => inputs.push(Cancel)
      other => return fail("unknown command '\{other}'")
    }
  }
  Ok({ scene, inputs, })
}

///|
/// シナリオを実行して結果のシーンを得る
pub fn Scenario::run(self : Scenario) -> Scene {
  self.scene.play(self.inputs)
}

///|
/// テキストを解析して実行する（解析に失敗したらエラーを返す）
pub fn play_scenario(source : String) -> Result[Scene, ScenarioError] {
  match parse_scenario(source) {
    Ok(scenario) => Ok(scenario.run())
    Err(e) => Err(e)
  }
}

// =============================================================================
// 補助
// =============================================================================

///|
/// 要素を足したシーン
pub fn Scene::add(self : Scene, el : @model.Element) -> Scene {
  let elements = self.elements.copy()
  elements.push(el)
  { ..self, elements, }
}

///|
/// 空白区切りに分解する（連続する空白はまとめる）
fn split_words(source : String) -> Array[String] {
  source
  .split(" ")
  .map(fn(sv) { sv.trim(chars=" \t\r").to_owned() })
  .filter(fn(w) { w != "" })
  .collect()
}

///|
/// 数値として読む（読めなければ 0）
fn num(s : String) -> Double {
  let parsed = Some(@string.parse_double(s)) catch { _ => None }
  parsed.unwrap_or(0.0)
}

///|
/// start / end を Endpoint に読む
fn parse_endpoint(s : String) -> Endpoint? {
  match s {
    "start" => Some(Start)
    "end" => Some(End)
    _ => None
  }
}
