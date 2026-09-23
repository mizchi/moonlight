# セマンティックインタラクションモデルと視覚モデルテスト

図形とジョイントの組み合わせは掛け算で増える。矩形・円・楕円 × 外周アンカー ×
「どちらを動かしたか」だけで数十通りあり、これをブラウザ越しにしか確かめられない
と、壊れたときにどこが壊れたのか分からない。

そこで操作の意味だけを表す層を `mizchi/moonlight/interaction` に置き、エディタ本体は
その結果を Signal に載せ替えるだけにした。同じモデルがユニットテストと視覚テストの
両方を駆動するので、「状態は正しいが絵が違う」と「絵は合っているが状態が違う」の
どちらのずれも見つけられる。

## 層の分かれ方

| 層 | 置き場所 | 依存 |
|---|---|---|
| 純粋な計算（座標・接続の伝播） | `src/model` | なし |
| 操作の意味（ジェスチャの状態遷移） | `src/interaction` | `model` のみ |
| Signal と DOM | `src/core`, `src/ui.mbt`, `src/render.mbt` | luna, js |

`src/interaction` は Signal も DOM も知らないので、`js` / `wasm` / `wasm-gc` の
どれでもビルドでき、ブラウザなしでテストできる。

## モデルの形

```
Scene   = 要素 + 選択 + グリッド（ただの値）
Target  = ポインタが掴んだもの（Canvas / Body(id) / Handle(id, handle)）
Input   = Press(target, point) | MoveTo(point) | Release | Cancel
Gesture = Idle | Moving | Resizing | BoxSelecting
Session = Scene + Gesture（+ スナップ中の接続先、取り消し用のスナップショット）
```

ジェスチャは `Press → MoveTo* → Release | Cancel` の一本道で、どのジェスチャに
入るかは Press が掴んだ `Target` だけで決まる。`Session::step` は純粋関数なので、
入力列を与えれば結果は常に同じになる。

```moonbit
let after = Scene::of([rect("r1", 100.0, 100.0, 80.0, 60.0)]).play([
  Press(Body("r1"), { x: 140.0, y: 130.0 }),
  MoveTo({ x: 200.0, y: 180.0 }),
  Release,
])
```

## ジョイントと、その不変条件

「線 L の始点／終点が図形 E のアンカー A に結合している」という関係を `Joint` として
取り出せるようにした。データ上は `Element.connections` に入っているが、そこに書かれた
結合が実際の座標と一致している保証はない。一致しているかどうかを検査するのが
`Scene::joint_violations` で、これがこの層の中心的な約束になる。

```moonbit
// ドラッグやリサイズのあと、これは常に空でなければならない
assert_true(scene.joints_are_consistent())
```

破れ方は三つに分かれる。

- `Detached` — 端点が結合先アンカーから離れている（伝播の漏れ）
- `MissingTarget` — 結合先の要素がもういない
- `NotALine` — 線でない要素に接続情報が付いている

図形の種類 × その図形が実際に差し出すアンカーを総当たりし、図形を動かした場合と
リサイズした場合の両方でこの不変条件を確かめている
（`src/interaction/joints_test.mbt`）。

## シナリオ DSL

シーンと操作を一つのテキストで書く。同じテキストからユニットテストの期待値も、
ブラウザに流し込む初期 SVG も作れるので、テスト側でモデルを書き写さずに済む。

```
rect r1 80 80 100 70
circle c1 420 200 50
line l1 180 115 370 200
join l1 start r1 right
join l1 end c1 left
grid 20
press body r1 130 115
move 210 245
release
```

| 命令 | 意味 |
|---|---|
| `rect / circle / ellipse / line / text` | 図形を置く（`text` の座標は文字の中心） |
| `arrow <id> <x1> <y1> <x2> <y2>` | 終点に矢じりの付いた線 |
| `label <shape> <content...>` | 図形の中央に置き、図形に結び付けた文字（ID は `<shape>-label`） |
| `join <line> start\|end <target> <anchor>` | ジョイントを張る |
| `grid <size>` | グリッドスナップ（0 で無効） |
| `select <id>...` | 選択状態 |
| `press canvas\|body\|handle ...` | ポインタを押す |
| `move <x> <y>` / `release` / `cancel` | 動かす・離す・取り消す |

`#` で始まる行と空行は無視される。解析に失敗すると行番号付きで返る。

## 視覚モデルテスト

`e2e/visual-model.test.ts` が、一つのシナリオから三つを引き出して突き合わせる。

1. **モデルの予測** — `runScenario` が返すシーン・ジョイント・主張
2. **本物の操作の結果** — 実際のマウス操作を通したあとのエディタの状態
3. **描かれた絵** — スクリーンショットを vlmkit の自然言語アサーションにかける

1 と 2 が食い違えばモデルか実装のどちらかが嘘をついている。2 と 3 が食い違えば
状態は正しいのに絵になっていない。

```bash
just visual-model        # 1 と 2 の突き合わせ（鍵不要）
just vlm-integrity       # vlmkit の参照なし検査（鍵不要、要 `just dev`）
just vlm-snapshot        # vlmkit の視覚スナップショット（要 `just dev`）
```

3 の自然言語アサーションだけは、絵を見て文を判定する役が要る。判定役は
`e2e/vlm-reviewer.ts` にあり、上から順に使えるものを選ぶ。

| 判定役 | 要るもの |
|---|---|
| `anthropic` / `openrouter` / `gemini` | `ANTHROPIC_API_KEY` / `OPENROUTER_API_KEY` / `GEMINI_API_KEY` |
| `claude-cli` | `PATH` 上のサインイン済み `claude` CLI（鍵は不要） |

`VLMKIT_REVIEWER` で名指しでき、判定に使うモデルは `VLMKIT_MODEL` で選べる。
どれも無ければ理由付きで skip する。

### 判定役そのものを疑う

主張が全部通ったことは、それだけでは何も言っていない。何を見せても pass と
答えるレビュアーでも同じ緑になるからだ。そこで同じファイルに一つだけ、絵が
明らかに否定する主張（「三角形がちょうど 7 つあり、矩形は一つも無い」）を
投げて、落ちることを要求するテストを置いている。これが落ちて初めて、他の
主張が通ったことに意味が出る。

## エディタ側の窓口

Signal 上の状態はいつでも純粋なシーンに写せる。

```moonbit
let scene = state.to_interaction_scene()
```

`EditorState::resize_move` と `EditorState::end_resize` はこのシーンを
`@interaction` に渡し、返ってきた結果を Signal に載せ替えるだけになっている。
図形 × ハンドルごとの幾何計算とジョイントの張り替えは `src/interaction` にしかない。
