#!/usr/bin/env node
/**
 * moonlight — ブラウザなしで図を作る/読む CLI
 *
 * 図の組み立ては `docs/headless.md` のシナリオ文法で書く。AI に描かせるときは、
 * この CLI をそのまま道具として渡せる。
 *
 *   moonlight render scene.txt -o out.svg
 *   echo 'rect a 10 10 80 60' | moonlight render -o out.svg
 *   moonlight describe out.svg
 *   moonlight apply out.svg more.txt -o out.svg
 *   moonlight png out.svg -o out.png
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { createScene, loadSvg, describeSvg, toPng } from '../js/headless.js';

const USAGE = `moonlight — build and read SVG drawings without a browser

Usage:
  moonlight render [scenario] [-o out.svg] [--width N] [--height N]
  moonlight apply <drawing.svg> [scenario] [-o out.svg]
  moonlight describe <drawing.svg | scenario> [--json]
  moonlight png <drawing.svg> [-o out.png] [--scale N]

A scenario is the small text format the editor's model reads:

  rect    <id> <x> <y> <width> <height>       # x y: the top-left corner
  circle  <id> <cx> <cy> <r>
  ellipse <id> <cx> <cy> <rx> <ry>
  line    <id> <x1> <y1> <x2> <y2>
  arrow   <id> <x1> <y1> <x2> <y2>            # a line with an arrowhead at x2 y2
  text    <id> <x> <y> <content...>           # x y: the centre of the text
  label   <shape> <content...>                # text centred in a shape and bound to it:
                                              #   it moves with the shape (id: <shape>-label)
  join    <line> start|end <shape> <anchor>   # anchor: left right top bottom center
  select  <id...>
  press body <id> <x> <y>                     # drag a shape the way a person would:
  move <x> <y>                                #   joined lines and labels come along
  release

Pass "-" or nothing as the scenario to read it from stdin.
Every command writes to stdout unless -o is given.`;

function readInput(path) {
  if (!path || path === '-') return readFileSync(0, 'utf8');
  return readFileSync(path, 'utf8');
}

function looksLikeSvg(text) {
  return /^\s*<(\?xml|svg)\b/.test(text);
}

function fail(message) {
  process.stderr.write(`moonlight: ${message}\n`);
  process.exit(1);
}

function output(text, out) {
  if (out) {
    writeFileSync(out, text);
    process.stderr.write(`wrote ${out}\n`);
  } else {
    process.stdout.write(text.endsWith('\n') ? text : `${text}\n`);
  }
}

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    out: { type: 'string', short: 'o' },
    width: { type: 'string' },
    height: { type: 'string' },
    scale: { type: 'string' },
    json: { type: 'boolean' },
    help: { type: 'boolean', short: 'h' },
  },
});

const [command, ...rest] = positionals;

if (values.help || !command) {
  process.stdout.write(`${USAGE}\n`);
  process.exit(values.help ? 0 : 1);
}

const size = {};
if (values.width) size.width = Number(values.width);
if (values.height) size.height = Number(values.height);

try {
  switch (command) {
    case 'render': {
      const scene = createScene(size);
      scene.apply(readInput(rest[0]));
      output(scene.toSvg(), values.out);
      break;
    }

    case 'apply': {
      const [drawing, scenario] = rest;
      if (!drawing) fail('apply needs the drawing to edit');
      const scene = await loadSvg(readFileSync(drawing, 'utf8'), size);
      scene.apply(readInput(scenario));
      output(scene.toSvg(), values.out ?? drawing);
      break;
    }

    case 'describe': {
      const text = readInput(rest[0]);
      const state = looksLikeSvg(text)
        ? await describeSvg(text, size)
        : createScene(size).apply(text).inspect();
      if (values.json) {
        output(JSON.stringify(state, null, 2), values.out);
      } else {
        const lines = [state.description];
        if (state.violations.length > 0) {
          lines.push('', 'Broken connections:', ...state.violations.map((v) => `- ${v}`));
        }
        output(lines.join('\n'), values.out);
      }
      break;
    }

    case 'png': {
      const text = readInput(rest[0]);
      const svg = looksLikeSvg(text) ? text : createScene(size).apply(text).toSvg();
      const png = await toPng(svg, values.scale ? { scale: Number(values.scale) } : {});
      if (!values.out) fail('png needs -o to write to (a PNG is not text)');
      writeFileSync(values.out, png);
      process.stderr.write(`wrote ${values.out} (${png.length} bytes)\n`);
      break;
    }

    default:
      fail(`unknown command "${command}"\n\n${USAGE}`);
  }
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
