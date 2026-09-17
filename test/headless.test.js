import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createScene, loadSvg, describeSvg, toPng } from '../js/headless.js';

const BRIDGE = `
rect box 80 80 120 80
circle dot 400 200 40
line link 200 120 360 200
join link start box right
join link end dot left
`;

test('a scenario becomes a drawing', () => {
  const scene = createScene().apply(BRIDGE);
  const svg = scene.toSvg();

  assert.match(svg, /data-moonlight/);
  assert.match(svg, /<rect [^>]*data-id="box"/);
  assert.match(svg, /<circle [^>]*data-id="dot"/);
  assert.match(svg, /<line [^>]*data-id="link"/);
});

test('the ids written in the scenario are the ids in the drawing', () => {
  const scene = createScene().apply(BRIDGE);
  assert.deepEqual(
    scene.elements().map((el) => el.id),
    ['box', 'dot', 'link'],
  );
});

test('a joint is recorded, and holds', () => {
  const scene = createScene().apply(BRIDGE);
  const joints = scene.joints();

  assert.equal(joints.length, 2);
  assert.deepEqual(
    joints.map((j) => `${j.line}.${j.endpoint} -> ${j.target}.${j.anchor}`),
    ['link.start -> box.right', 'link.end -> dot.left'],
  );
  assert.deepEqual(scene.violations(), [], 'a fresh scene should be consistent');
});

test('the description names every shape and every connection', () => {
  const description = createScene().apply(BRIDGE).describe();
  for (const needle of ['rectangle box', 'circle dot', 'line link', 'attached to']) {
    assert.ok(description.includes(needle), `description should mention ${needle}`);
  }
});

test('a bad line is reported, and the scene is left alone', () => {
  const scene = createScene().apply('rect box 10 10 50 50');
  const before = scene.toSvg();

  assert.throws(() => scene.apply('rect'), /line 1/);
  assert.equal(scene.toSvg(), before, 'a rejected scenario must not change the drawing');
});

test('a drawing can be read back and carried on', async () => {
  const first = createScene().apply('rect box 80 80 120 80\ncircle dot 400 200 40');

  const scene = await loadSvg(first.toSvg());
  assert.deepEqual(
    scene.elements().map((el) => el.shape),
    ['rect', 'circle'],
    'both shapes should survive the round-trip',
  );

  // 取り込み後の ID で繋ぐ
  const [box, dot] = scene.elements().map((el) => el.id);
  scene.apply(`line link 200 120 360 200\njoin link start ${box} right\njoin link end ${dot} left`);

  assert.equal(scene.elements().length, 3);
  assert.deepEqual(scene.violations(), []);
});

test('reading something that is not a drawing says so', async () => {
  await assert.rejects(() => describeSvg('this is not an svg at all <<<'), /could not read/);
});

test('a drawing describes itself the same way after a round-trip', async () => {
  const scene = createScene().apply(BRIDGE);
  const reloaded = await describeSvg(scene.toSvg());

  // ID は取り込みで振り直されるので、形と繋がりの本数で比べる
  assert.equal(reloaded.elements.length, scene.elements().length);
  assert.equal(reloaded.joints.length, scene.joints().length);
  assert.deepEqual(reloaded.violations, []);
});

test('a drawing can be rasterised', { timeout: 120_000 }, async () => {
  const svg = createScene({ width: 200, height: 120 })
    .apply('rect box 20 20 160 80')
    .toSvg();

  const png = await toPng(svg);
  assert.ok(png.length > 100, 'the PNG should have some content');
  // PNG のシグネチャ
  assert.deepEqual([...png.slice(0, 4)], [0x89, 0x50, 0x4e, 0x47]);
});

test('the line number in an error points into the text you just wrote', () => {
  const scene = createScene().apply('rect a 10 10 50 50\ncircle b 200 200 30');

  // 積み上げたシナリオ全体ではなく、いま渡した 2 行目であること
  assert.throws(() => scene.apply('circle ok 300 300 20\nrect'), /line 2/);
});
