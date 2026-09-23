# AI 作図の評価（ヘッドレス × vlmkit）

AI に Moonlight をヘッドレスで使わせて図を描かせ、**頼んだとおりに描けたか**と、
**Moonlight として意図どおりに扱える図になっているか**を測る。

```sh
pnpm moon:build:compat                 # headless が読む JS を作る
pnpm eval:ai-draw                      # claude CLI に 8 課題を描かせて採点
AI_DRAW_DRIVER=oracle pnpm eval:ai-draw  # 正解のシナリオで採点（AI を呼ばない）
```

結果は `eval/ai-draw/runs/<run>/` に残る（git には入らない）。これまでの結果と、そこから
見つかって直したものは [RESULTS.md](RESULTS.md)。`report.md` に課題ごとの
絵・落ちた検査・判定役の理由がまとまり、`playwright-report/` に Playwright の HTML
レポートが出る。

## しくみ

```
課題（tasks.ts）── 依頼文 ──▶ 描き手（drawer.ts）
                              claude -p（ヘッドレス）。道具は `moonlight` CLI と
                              Read / Write / Edit だけ。作業はリポジトリの外の一時
                              ディレクトリで、案内は docs/headless.md の写し
                                   │ drawing.svg
                                   ▼
             ┌──────── ブラウザで描いて「見えている事実」を読む（facts.ts）
             │           要素ごとの位置・大きさ・文字・線の端の結合・矢じり
             ▼
  構造・読みやすさ（judge.ts） ふるまい（behaviour.ts）     vlmkit
  ラベルで図形を名指しし、       Moonlight のモデルに操作を   nlAssert … 絵を見て主張を判定
  つながり・並び・はみ出し・     流す: 図形を掴んで動かすと   check integrity --elements
  重なりを決定的に確かめる       線とラベルが付いてくるか、   … 文字の重なり、ラベルの
                               読み直して同じ絵か、モデル     はみ出し、微妙なずれ
                               と絵が同じ位置を指すか         （決定的、ブラウザ不要）
```

判定は AI が付けた ID を使わず、「"Parse" と書かれた図形」のようにラベルの文字で
図形を名指しする。人が図を見て確かめるのと同じ手順にするため。

### 物差し

| 区分 | 何を見るか | 例 |
|---|---|---|
| 構造 | 頼んだ図形・つながり・配置があるか | `node:Parse` `edge:Parse→Check` `relation:row(…)` `exact` `unchanged:A` `moved:B` |
| 読みやすさ | ラベルが図形に収まり、文字が隠れず、キャンバスに収まるか | `labels-inside` `text-clear` `shapes-apart` `in-canvas` |
| ふるまい | エディタで触っても意図どおりか | `joined:*`（線が図形に結合しているか） `follows-move:*` `label-follows:*` `round-trip` `model-matches-picture` `model-consistent` |
| 見た目（vlmkit） | 絵が主張どおりか | 課題ごとの `claims` と、文字が読めるかの共通の主張 |
| integrity（vlmkit） | 決定的な描画の欠陥 | `text-collision` `container-protrusion` `near-misalignment` |

「意図どおり」はこれを全部満たしたとき。

**ふるまい**が Moonlight 固有の見どころ。線を図形の縁まで引いただけでも絵としては
正しく見えるが、エディタで図形を動かすと外れる。文字を図形の上に置いただけのラベル
は、図形を動かすと取り残される。`behaviour.ts` は人がエディタで触るのと同じ経路
（press → move → release）で一番つながりの多い図形を動かし、付いてくるべきものが
付いてくるかを見る。

## 判定の検算

`judge.selfcheck.eval.ts` は AI を呼ばずに走る。エディタが書き出すのと同じ形の理想の
SVG を手で書き、理想の図は全部の検査を通ること、わざと一か所だけ壊した図（結合して
いない線、結び付いていないラベル、逆向きの矢印、はみ出したラベル、余計な図形、
ラベルを横切る線、動かしすぎ・動かし足りない編集）はその検査だけが落ちることを
確かめる。ここが緑でなければ AI の点数は信用できない。

`AI_DRAW_DRIVER=oracle` は課題ごとの正解シナリオ（`tasks.ts` の `oracle`）を AI と同じ
CLI に通す。「今のシナリオ文法でできる最善」の点数になるので、AI の点数と見比べると、
落ちた原因が AI にあるのか Moonlight にあるのかが分かる。

## 設定

| 環境変数 | 既定 | 意味 |
|---|---|---|
| `AI_DRAW_DRIVER` | claude があれば `claude`、無ければ `oracle` | 描き手 |
| `AI_DRAW_MODEL` | CLI の既定 | 描き手のモデル（`claude --model` に渡す） |
| `AI_DRAW_EFFORT` | CLI の既定 | 描き手の推論の深さ（`CLAUDE_EFFORT` として渡す） |
| `AI_DRAW_TASKS` | 全部 | `pipeline,hub` のように絞る |
| `AI_DRAW_WORKERS` | 4 | 同時に描かせる数 |
| `AI_DRAW_VLM` | 判定役があれば on | `0` で nlAssert を飛ばす（速い） |
| `AI_DRAW_RUN` | 日時 | 結果を置くディレクトリ名 |
| `AI_DRAW_TIMEOUT_MS` / `AI_DRAW_BUDGET_USD` | 600000 / 2 | 一課題あたりの上限 |
| `VLMKIT_REVIEWER` / `VLMKIT_MODEL` | | 判定役（`e2e/vlm-reviewer.ts`） |

描き手の `claude` には、この評価を走らせているセッションの環境変数（セッション ID
やメッセージの口など）を渡さない。評価が走っている場所に左右されないようにするため。

## 課題を足す

`tasks.ts` に一つ足す。依頼文（`prompt`）は人がふつうに頼む言い方で書き、シナリオの
書き方（`join` など）には触れない。道具をどう使うかも評価の対象だから。仕様
（`nodes` / `edges` / `relations`）はラベルで書き、`oracle` に正解のシナリオを添える。
`AI_DRAW_DRIVER=oracle AI_DRAW_TASKS=<id>` で、正解が構造・読みやすさを満たすことを
先に確かめる。
