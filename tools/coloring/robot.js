// Test robot: on an iPhone 13-sized touch viewport, for every picture in the
// preview, pick each palette color and TAP every region at its label point.
// Reports regions that could not be filled, completion reached, console errors,
// and saves a screenshot per picture (start + finished).
// usage: node robot.js <playwright-module> <preview.html> <shot_dir>
const [, , pw, file, shots] = process.argv;
const { chromium, devices } = require(pw);
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await b.newContext({ ...devices['iPhone 13'], deviceScaleFactor: 2 });
  const p = await ctx.newPage(); const errs = [];
  p.on('console', m => m.type() === 'error' && errs.push(m.text())); p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + file);
  const n = await p.evaluate(() => PICS.length); const report = [];
  for (let i = 0; i < n; i++) {
    await p.evaluate(i => load(i), i);
    await p.screenshot({ path: `${shots}/robot-${i}-start.png` });
    const regs = await p.evaluate(() => PICS[cur].data.regions.map(r => [r.c, r.x, r.y]));
    const box = await p.locator('#fills').boundingBox();
    const k = box.width / 1024; let taps = 0, misses = [];
    const colors = [...new Set(regs.map(r => r[0]))].sort((a, b) => a - b);
    for (const c of colors) {
      await p.locator(`.sw[data-c="${c}"]`).tap();
      for (let j = 0; j < regs.length; j++) {
        if (regs[j][0] !== c) continue;
        await p.touchscreen.tap(box.x + regs[j][1] * k, box.y + regs[j][2] * k); taps++;
        if (!(await p.evaluate(j => filled.has(j), j))) misses.push(j);
      }
    }
    const done = await p.locator('#done').isVisible();
    await p.screenshot({ path: `${shots}/robot-${i}-done.png` });
    const t = await p.evaluate(() => PICS[cur].meta.title);
    report.push({ pic: i, title: t, regions: regs.length, taps, misses: misses.length, missIdx: misses.slice(0, 10), done });
  }
  // navigation buttons
  await p.locator('#next').tap(); const afterNext = await p.evaluate(() => cur);
  await p.locator('#prev').tap(); const afterPrev = await p.evaluate(() => cur);
  console.log(JSON.stringify({ report, nav: { afterNext, afterPrev }, consoleErrors: errs }, null, 1));
  await b.close();
})();
