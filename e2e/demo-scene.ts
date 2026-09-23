/**
 * 起動時のデモ（src/sample_shapes.mbt）の中身。
 *
 * 「最初に何が出ているか」を前提にするテストは、数や色をここから取る。デモを
 * 描き替えたらここだけ直せばよい（数をテストごとに書き込んでいた頃は、デモを
 * 変えるたびに何十ものテストが一度に落ちた）。
 */
export const DEMO = {
  /** 矩形の図形: Plain SVG（角丸）と Embed anywhere */
  rects: 2,
  /** 楕円の図形: Draw */
  ellipses: 1,
  circles: 0,
  /** 図形の中のラベル 3 つ、Round trip、操作のヒント 2 行 */
  texts: 6,
  /** 図形どうしをつなぐ矢印（両端ともアンカーに結合） */
  lines: 3,
  /** 手描きの ↻ */
  paths: 1,
  /** 図形の中のラベルと、その文字色（= 親図形の線の色） */
  labels: {
    draw: { text: 'Draw', fill: '#6d28d9' },
    svg: { text: 'Plain SVG', fill: '#b45309' },
    embed: { text: 'Embed anywhere', fill: '#047857' },
  },
} as const;
