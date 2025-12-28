import puppeteer from 'puppeteer';

const browser = await puppeteer.launch({ headless: true });
const page = await browser.newPage();

// コンソールログをキャプチャ
page.on('console', msg => {
  const type = msg.type();
  const text = msg.text();
  console.log(`[${type}] ${text}`);
});

// エラーをキャプチャ
page.on('pageerror', err => {
  console.log('[PAGE ERROR]', err.message);
  console.log(err.stack);
});

try {
  console.log('Loading embed.html...');
  await page.goto('http://localhost:5175/embed.html', { waitUntil: 'networkidle0' });

  // 少し待つ
  await new Promise(r => setTimeout(r, 1000));

  // SVG が存在するか確認
  const svgInfo = await page.evaluate(() => {
    const svg = document.querySelector('#editor svg');
    if (!svg) return { exists: false };
    const elements = Array.from(svg.querySelectorAll('[data-id]'));
    return {
      exists: true,
      viewBox: svg.getAttribute('viewBox'),
      width: svg.getAttribute('width'),
      height: svg.getAttribute('height'),
      childCount: svg.children.length,
      elements: elements.map(el => ({
        id: el.dataset.id,
        tagName: el.tagName,
        cx: el.getAttribute('cx'),
        cy: el.getAttribute('cy'),
        x: el.getAttribute('x'),
        y: el.getAttribute('y'),
      }))
    };
  });
  console.log('SVG info:', JSON.stringify(svgInfo, null, 2));

  // Circle 要素の位置を取得
  const circlePos = await page.evaluate(() => {
    const svg = document.querySelector('#editor svg');
    const circle = svg.querySelector('circle[data-id]');
    if (!circle) return null;
    const svgRect = svg.getBoundingClientRect();
    return {
      svgRect: { x: svgRect.x, y: svgRect.y, width: svgRect.width, height: svgRect.height },
      cx: parseFloat(circle.getAttribute('cx')),
      cy: parseFloat(circle.getAttribute('cy')),
    };
  });
  console.log('Circle position:', circlePos);

  if (circlePos) {
    // SVG 内の座標をスクリーン座標に変換
    const screenX = circlePos.svgRect.x + (circlePos.cx / 600) * circlePos.svgRect.width;
    const screenY = circlePos.svgRect.y + (circlePos.cy / 400) * circlePos.svgRect.height;
    console.log(`Clicking at screen coords: (${screenX}, ${screenY})`);

    // ドラッグシミュレーション
    await page.mouse.move(screenX, screenY);
    await page.mouse.down();
    console.log('Mouse down...');

    // 少し移動
    await page.mouse.move(screenX + 50, screenY + 30, { steps: 5 });
    console.log('Mouse moved...');

    await new Promise(r => setTimeout(r, 500));

    // エラーがないか確認
    const afterDrag = await page.evaluate(() => {
      const svg = document.querySelector('#editor svg');
      const circle = svg.querySelector('circle[data-id]');
      if (!circle) return null;
      return {
        cx: circle.getAttribute('cx'),
        cy: circle.getAttribute('cy'),
      };
    });
    console.log('Circle after drag:', afterDrag);

    await page.mouse.up();
  }

} catch (err) {
  console.error('Error:', err);
} finally {
  await browser.close();
}
