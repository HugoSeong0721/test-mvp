// Solunar 웹 미리보기를 폰 크기 헤드리스 Chromium 으로 띄우는 헬퍼 (샌드박스용).
// 샌드박스는 www.gstatic.com(Flutter 엔진)을 막는다 → 엔진은 로컬 빌드 사본으로 응답 (Catdoku·물때 하네스 방식).
// 앱은 네트워크가 필요 없다(전부 기기에서 계산) — 글꼴(fonts.gstatic.com)만 node fetch 로 대신 받는다.
// 실행: NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node <script>
//
//   const { browser, page, errs } = await require('./web-harness.js').open({
//     url: 'http://localhost:8765/test-mvp/solunar-app/index.html',
//     viewport: { width: 390, height: 844 },
//     geolocation: { latitude: 30.2672, longitude: -97.7431 },   // 없으면 위치 거부
//     timezoneId: 'America/Chicago',                              // 폰 시간대
//     clock: Date.UTC(2026, 9, 2, 17),                            // 고정 "지금"
//   })
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs'), path = require('path');

const ROOT = path.resolve(__dirname, '..', 'flutter');

exports.open = async (opts = {}) => {
  const CK = path.join(ROOT, 'build', 'web', 'canvaskit');
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await b.newContext({
    viewport: opts.viewport || { width: 390, height: 844 }, deviceScaleFactor: opts.scale || 3, hasTouch: true, isMobile: true,
    timezoneId: opts.timezoneId || 'America/Chicago',
    ...(opts.geolocation ? { geolocation: opts.geolocation, permissions: ['geolocation'] } : {}),
  });
  if (opts.clock) await ctx.addInitScript(`(() => { const T = ${+opts.clock}; const D = Date; const off = T - D.now();
    globalThis.Date = class extends D { constructor(...a) { super(...(a.length ? a : [D.now() + off])); } static now() { return D.now() + off; } }; })()`);
  const p = await ctx.newPage();
  const net = [];
  await p.route(/^https:\/\//, async route => {
    const url = route.request().url();
    net.push(url);
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
  await p.goto(opts.url);
  await p.getByRole('button').first().waitFor({ timeout: 40000 });
  await p.waitForTimeout(1500);
  return { browser: b, ctx, page: p, errs, net };
};
