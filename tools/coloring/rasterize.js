// Render SVG files to 1024px PNGs with headless Chromium (for convert.py).
// usage: node rasterize.js <playwright-module> out_dir file1.svg file2.svg ...
const [, , pw, outDir, ...files] = process.argv;
const { chromium } = require(pw);
const fs = require('fs'), path = require('path');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  for (const f of files) {
    const svg = fs.readFileSync(f).toString('base64');
    await p.setContent(`<body style="margin:0;background:#fff"><img id=i style="width:1024px;height:1024px;object-fit:contain" src="data:image/svg+xml;base64,${svg}"></body>`);
    await p.waitForFunction(() => document.getElementById('i').complete);
    await p.screenshot({ path: path.join(outDir, path.basename(f, '.svg') + '.png') });
  }
  await b.close();
})();
