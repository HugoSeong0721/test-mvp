// 웹 미리보기를 폰 크기 헤드리스 Chromium 으로 열어 **진짜 터치 이벤트**(마우스 아님)로 줄을 그어 본다.
// 마우스로만 확인하면 터치 조작이 안 되는 걸 놓친다 (CLAUDE.md — 불길 탈출 7m 사고).
//
// 실행 (리포 루트에서):
//   mkdir -p /tmp/pp-serve && ln -sfn "$PWD/docs" /tmp/pp-serve/test-mvp && (cd /tmp/pp-serve && python3 -m http.server 8765 &)
//   NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node path_puzzle_app/qa/web-touch-check.js [출력 폴더]
// 앱이 kIsWeb 에서 window.__pathPuzzle 에 판 상태(정답 줄 포함)를 남긴다 (lib/core/qa_hook_web.dart).
const path = require('path');
const fs = require('fs');
const harness = require('../../catdoku_app/qa/flutter-web-harness.js');

const OUT = process.argv[2] || 'build/web-qa';
const URL = process.env.URL || 'http://127.0.0.1:8765/test-mvp/path-puzzle-app/index.html';
const VIEWPORTS = [
  { name: 'iPhone13', width: 390, height: 844 },
  { name: 'iPhoneSE', width: 375, height: 667 },
];

const log = [];
const ok = (cond, what) => {
  log.push(`${cond ? 'PASS' : 'FAIL'}  ${what}`);
  fs.appendFileSync(process.env.QA_LOG || '/dev/stderr', log[log.length - 1] + '\n');
  if (!cond) process.exitCode = 1;
};

async function run(vp) {
  fs.mkdirSync(OUT, { recursive: true });
  const { browser, page, errs } = await harness.open({
    url: URL,
    canvaskit: path.join(__dirname, '../flutter/build/web/canvaskit'),
    viewport: { width: vp.width, height: vp.height },
  });
  const cdp = await page.context().newCDPSession(page);
  const shot = (n) => page.screenshot({ path: `${OUT}/${vp.name}-${n}.png` });
  const state = async () => JSON.parse((await page.evaluate(() => window.__pathPuzzle)) || 'null');
  const board = async () => {
    const r = await page.evaluate(() => {
      // 부모 요소의 textContent 에도 자식 글자가 들어 있다 → 글자가 맞는 것 중 가장 작은 상자가 판
      let best = null;
      for (const e of document.querySelectorAll('flt-semantics')) {
        const t = (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '');
        if (!t.includes('Puzzle board')) continue;
        const b = e.getBoundingClientRect();
        if (b.width > 100 && (!best || b.width * b.height < best.w * best.h)) {
          best = { x: b.x, y: b.y, w: b.width, h: b.height };
        }
      }
      return best;
    });
    return r;
  };
  const center = (b, n, cell) => ({
    x: b.x + ((cell % n) + 0.5) * (b.w / n),
    y: b.y + (Math.floor(cell / n) + 0.5) * (b.w / n),
  });
  // 칸 가운데를 차례로 지나는 터치 끌기 (칸 사이마다 4번씩 움직임 이벤트)
  const touchDraw = async (cells) => {
    const st = await state();
    const b = await board();
    const pts = cells.map((c) => center(b, st.n, c));
    const ev = (type, p) => cdp.send('Input.dispatchTouchEvent', {
      type, touchPoints: p ? [{ x: p.x, y: p.y, id: 1, radiusX: 8, radiusY: 8, force: 1 }] : [],
    });
    await ev('touchStart', pts[0]);
    await page.waitForTimeout(30);
    for (let i = 1; i < pts.length; i++) {
      for (let k = 1; k <= 4; k++) {
        await ev('touchMove', {
          x: pts[i - 1].x + ((pts[i].x - pts[i - 1].x) * k) / 4,
          y: pts[i - 1].y + ((pts[i].y - pts[i - 1].y) * k) / 4,
        });
        await page.waitForTimeout(8);
      }
    }
    await ev('touchEnd');
    await page.waitForTimeout(250);
  };
  // Flutter 웹 접근성 트리: 글자는 textContent 나 aria-label 중 한쪽에 들어간다 (버튼이면 aria-label)
  const hasText = (re) => page.evaluate((src) => {
    const r = new RegExp(src);
    return [...document.querySelectorAll('flt-semantics, [aria-label]')].some(
      (e) => r.test(e.getAttribute('aria-label') || '') || r.test(e.textContent || ''));
  }, re.source);
  const tapButton = async (name) => {
    fs.appendFileSync(process.env.QA_LOG || '/dev/stderr', '  tap ' + String(name) + '\n');
    const btn = page.getByRole('button', { name }).first();
    const b = await btn.boundingBox();
    await page.touchscreen.tap(b.x + b.width / 2, b.y + b.height / 2);
    await page.waitForTimeout(900);
  };

  await shot('01-howto');
  await tapButton(/Got it/);
  await shot('02-home');
  await tapButton(/^Play$/);
  let st = await state();
  ok(st && st.n === 6 && st.path.length === 1, `${vp.name}: daily 6x6 opens with the line on 1`);
  const ans = st.answer;
  await touchDraw(ans.slice(0, 8));
  st = await state();
  ok(st.path.length === 8, `${vp.name}: touch-drag 7 squares → line has 8 (got ${st.path.length})`);
  await touchDraw([ans[7], ans[6], ans[5]]);
  st = await state();
  ok(st.path.length === 6, `${vp.name}: slide back 2 → line has 6 (got ${st.path.length})`);
  await shot('03-drawing');
  // 세로로 길게 끌어도 페이지가 스크롤되지 않는다 (판 위 끌기가 화면을 움직이면 안 된다)
  const scrollBefore = await page.evaluate(() => window.scrollY);
  await touchDraw([ans[5], ans[4], ans[3], ans[4], ans[5]]);
  ok((await page.evaluate(() => window.scrollY)) === scrollBefore, `${vp.name}: dragging on the board does not scroll the page`);
  await tapButton(/Hint/);
  await page.waitForTimeout(300);
  await shot('04-hint-dialog');
  await tapButton(/Watch video/);
  await page.waitForTimeout(800);
  st = await state();
  ok(st.path.length > 6 && st.path.every((c, i) => c === ans[i]), `${vp.name}: hint extends the line on the answer (len ${st.path.length})`);
  await shot('05-after-hint');
  await page.waitForTimeout(2500);
  await touchDraw(ans.slice(st.path.length - 1));
  await page.waitForTimeout(1500);
  st = await state();
  ok(st.status === 'won', `${vp.name}: drawing to the end solves the daily puzzle`);
  ok(await hasText(/Solved!/), `${vp.name}: "Solved!" panel shows`);
  await shot('06-solved');
  await tapButton(/Play Levels/);
  await page.waitForTimeout(500);
  st = await state();
  ok(st.level === 1 && st.n === 5, `${vp.name}: Play Levels opens Level 1 (5x5)`);
  await touchDraw(st.answer);
  await page.waitForTimeout(1500);
  st = await state();
  ok(st.status === 'won', `${vp.name}: Level 1 solved by touch`);
  await shot('07-level-cleared');
  await tapButton(/Next Level/);
  st = await state();
  ok(st.level === 2, `${vp.name}: Next Level → Level 2`);
  await tapButton(/Back/);
  ok(await hasText(/Level 2/), `${vp.name}: Back → home shows Level 2`);
  await shot('08-home-after');
  ok(errs.length === 0, `${vp.name}: console errors 0 (${errs.join(' | ')})`);
  await browser.close();
}

(async () => {
  for (const vp of VIEWPORTS) {
    try {
      await run(vp);
    } catch (e) {
      ok(false, `${vp.name}: crashed — ${e.message}`);
    }
  }
  console.log('---\n' + log.join('\n'));
})();
