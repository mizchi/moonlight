# Headless モード

ブラウザなしで図を組み立て、読み、書き出すための入口。エディタ本体は DOM が要るが、
図そのもの——シーンのモデル、図形と線の結合、SVG の書き出し——は要らない。

AI に図を描かせるときの土台でもある。AI は下のシナリオ文法でテキストを書き、
`describe` で「いま何がどこにあるか」を読み、必要なら書き足す。

## 使う

### Node から

```js
import { createScene, loadSvg, toPng } from '@mizchi/moonlight/headless';

const scene = createScene({ width: 640, height: 420 });
scene.apply(`
  rect box 80 80 120 80
  label box Start
  circle dot 400 200 40
  arrow link 200 120 360 200
  join link start box right
  join link end dot left
`);

scene.toSvg();        // Moonlight SVG の文字列
scene.describe();     // 何がどこにあるか（下記）
scene.elements();     // [{ id, shape, x, y, bbox }]
scene.joints();       // [{ line, endpoint, target, anchor, x, y }]
scene.violations();   // 破れている結合。空なら健全
```

既存の SVG を読み直して続きを書く場合:

```js
const scene = await loadSvg(await readFile('drawing.svg', 'utf8'));
const [box, dot] = scene.elements().map((el) => el.id); // 取り込み時に el-1, el-2 … が振られる
scene.apply(`line link 0 0 0 0\njoin link start ${box} right\njoin link end ${dot} left`);
```

`loadSvg` と `describeSvg` は DOMParser を要るので非同期。Node では
[happy-dom](https://www.npmjs.com/package/happy-dom) を借りる（`optionalDependencies`）。
入っていなければその旨を投げる。読み込んだあとの操作は同期。

### CLI から

```
moonlight render [scenario] [-o out.svg] [--width N] [--height N]
moonlight apply <drawing.svg> [scenario] [-o out.svg]
moonlight describe <drawing.svg | scenario> [--json]
moonlight png <drawing.svg> -o out.png [--scale N]
```

シナリオを `-` または省略で渡すと標準入力から読む。

```sh
echo 'rect a 10 10 80 60' | moonlight render -o out.svg
moonlight describe out.svg
echo 'circle b 200 100 40' | moonlight apply out.svg
moonlight png out.svg -o out.png          # playwright が要る
```

## シナリオ文法

1 行 1 コマンド。空行と `#` で始まる行は無視。引数は空白区切り。

### 図形を置く

| 書き方 | 意味 |
|---|---|
| `rect <id> <x> <y> <width> <height>` | 矩形。`x y` は左上 |
| `circle <id> <cx> <cy> <r>` | 円。`cx cy` は中心 |
| `ellipse <id> <cx> <cy> <rx> <ry>` | 楕円 |
| `line <id> <x1> <y1> <x2> <y2>` | 線分 |
| `arrow <id> <x1> <y1> <x2> <y2>` | 矢印。`(x2, y2)` の側に矢じりが付く。`join` は線と同じ |
| `text <id> <x> <y> <content...>` | テキスト。`x y` は文字の**中心**。`content` は行末まで |

`<id>` は自分で決める名前で、あとから `join` や `press` で指すのに使う。書き出した
SVG では `data-id` になる。数を書くところに数でないものを書くとエラーになる。

### 図形にラベルを付ける

```
label <shape-id> <content...>
```

図形の中央に文字を置き、その図形に結び付ける。エディタで図形をダブルクリックして
書く文字と同じもので、図形を動かすと付いてくる。文字の色は図形の線の色になる。
ID は `<shape-id>-label`。

図形の上に `text` を置いただけでは結び付かないので、図形を動かすと文字が取り残される。
箱や丸の名前は `label` で書く。

### 線を図形につなぐ

```
join <line-id> start|end <shape-id> <anchor>
```

`<anchor>` は `left` `right` `top` `bottom` `center`。つないだ端点は、図形を動かしても
そのアンカーに追従する。`violations()` が空でなければ、繋がっているはずの場所から
外れている。

### 操作を流す（人が触ったときと同じ経路）

| 書き方 | 意味 |
|---|---|
| `press canvas <x> <y>` | 何もない場所を押す |
| `press body <id> <x> <y>` | 図形の本体を押す |
| `press handle <id> <handle> <x> <y>` | ハンドルを押す。`<handle>` は `nw` `ne` `sw` `se` `line-start` `line-end` |
| `move <x> <y>` | 押したまま動かす |
| `release` | 離す |
| `select <id...>` | 選択状態にする |
| `grid <size>` | グリッド吸着。`0` で切る |

```
rect box 80 80 100 70
press body box 130 115
move 210 245
release
```

## 読み取り

`describe()` は、AI がそのまま読める形で返す:

```
Shapes:
- rectangle box at (80, 80) size 120x80
- label box-label "Start" on box at (124, 110.4) size 32x19.2
- circle dot centred at (400, 200) radius 40
- arrow link from (200, 120) to (360, 200)
Connections:
- the start of line link is attached to the right anchor of rect box
- the end of line link is attached to the left anchor of circle dot
```

`inspect()` はこれに加えて `elements` / `joints` / `violations` / `claims` / `svg` を
まとめて返す。`claims` は「絵を見れば確かめられる主張」の一覧で、レンダリング結果を
検証したいときに使う（このリポジトリの視覚テストが実際に使っている）。

## 気に留めること

- **ID は取り込みで振り直される。** シナリオで付けた `box` は、書き出した SVG を
  読み直すと `el-1` になる。読み直したあとは `elements()` が返す ID を使う。
- **`apply` は積み上げる。** 同じシーンに続けて書き足していく。文法エラーのときは
  投げ、シーンは元のまま。行番号は「そのとき渡したテキストの何行目か」で返る。
- **PNG はブラウザに任せている。** `toPng` は playwright を使う。入れていなければ
  その旨を投げる。SVG 自体は単体で正しく描けるので、他のラスタライザでも構わない。
- **座標系はキャンバス座標。** 既定は 640x420。`createScene({ width, height })` で変えられる。
