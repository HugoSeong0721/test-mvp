// Flutter 웹 빌드를 폰 크기 헤드리스 Chromium 으로 띄우는 헬퍼 (샌드박스용).
// 샌드박스 프록시는 www.gstatic.com 을 막는다 → Flutter 엔진(canvaskit)은 로컬 빌드 사본으로 응답하고,
// 나머지 https 요청(폰트 등)은 node fetch 로 대신 받아 넘긴다. 실행: NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node <script>
//
//   const { browser, page, errs } = await require('./flutter-web-harness.js').open({
//     url: 'http://localhost:8765/test-mvp/catdoku-app/index.html',   // python3 -m http.server 로 docs 를 띄운 주소
//     canvaskit: '<앱>/flutter/build/web/canvaskit',                    // flutter build web 결과의 canvaskit 폴더
//     viewport: { width: 390, height: 844 }, scale: 3,              // scale: 스크린샷 배율 (기본 2)
//     init: () => { localStorage['flutter.level'] = '31' },        // 선택: 상태 미리 깔기
//   })
//   await page.getByRole('button', { name: /Play/ }).click()   // 앱이 kIsWeb 에서 ensureSemantics() 를 켜 둬야 한다
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs'), path = require('path');

exports.open = async (opts = {}) => {
  const CK = path.resolve(opts.canvaskit || 'build/web/canvaskit');
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await b.newContext({ viewport: opts.viewport || { width: 390, height: 844 }, deviceScaleFactor: opts.scale || 2, hasTouch: true, isMobile: true });
  const p = await ctx.newPage();
  await p.route(/^https:\/\//, async route => {
    const url = route.request().url();
    const m = /flutter-canvaskit\/[0-9a-f]+\/(.*)$/.exec(url);
    if (m) {
      const f = path.join(CK, m[1]);
      if (fs.existsSync(f)) {
        return route.fulfill({ status: 200, body: fs.readFileSync(f), headers: { 'content-type': f.endsWith('.wasm') ? 'application/wasm' : 'text/javascript', 'access-control-allow-origin': '*' } });
      }
    }
    try {
      const r = await fetch(url);
      const body = Buffer.from(await r.arrayBuffer());
      await route.fulfill({ status: r.status, body, headers: { 'content-type': r.headers.get('content-type') || 'application/octet-stream', 'access-control-allow-origin': '*' } });
    } catch (e) { await route.abort(); }
  });
  const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  if (opts.init) await p.addInitScript(opts.init);   // 예: localStorage 에 진행 상태 미리 깔기
  await p.goto(opts.url);
  await p.getByRole('button').first().waitFor({ timeout: 30000 });
  await p.waitForTimeout(1200);
  return { browser: b, page: p, errs };
};
