// Tides 웹 미리보기를 폰 크기 헤드리스 Chromium 으로 띄우는 헬퍼 (샌드박스용).
// 샌드박스는 www.gstatic.com(Flutter 엔진)·api.tidesandcurrents.noaa.gov 를 막는다 →
//   엔진은 로컬 빌드 사본, NOAA 는 Actions 로 받아 둔 실제 응답(tides_app/flutter/test/fixtures)으로 응답한다.
//   (폰에서 열면 NOAA 에 직접 접속한다 — NOAA 는 CORS `*` 를 준다.)
// 실행: NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node <script>
//
//   const { browser, page, errs, noaa } = await require('./web-harness.js').open({
//     url: 'http://localhost:8765/test-mvp/tides-app/index.html',
//     viewport: { width: 390, height: 844 },
//     geolocation: { latitude: 37.8063, longitude: -122.4659 },   // 없으면 위치 거부
//     noaaOffline: false,
//   })
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs'), path = require('path');

const ROOT = path.resolve(__dirname, '..', 'flutter');
const FIX = path.join(ROOT, 'test', 'fixtures');
const SUB = new Set(['9410068']);

function noaaBody(url) {
  const q = new URL(url).searchParams;
  const id = q.get('station'), six = q.get('interval') === '6';
  if (six && SUB.has(id)) {
    return '{"error": {"message":"No Predictions data was found. Please make sure the Datum input is valid."}}';
  }
  // Captured stations answer with their own data; others get one consistent stand-in pair
  // (San Francisco, or San Nicolas Island for subordinate stations) — never mixed.
  const src = fs.existsSync(path.join(FIX, `${id}_hilo.json`)) ? id : (SUB.has(id) ? '9410068' : '9414290');
  return fs.readFileSync(path.join(FIX, `${src}_${six ? '6min' : 'hilo'}.json`), 'utf8');
}

exports.open = async (opts = {}) => {
  const CK = path.join(ROOT, 'build', 'web', 'canvaskit');
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await b.newContext({
    viewport: opts.viewport || { width: 390, height: 844 }, deviceScaleFactor: opts.scale || 3, hasTouch: true, isMobile: true,
    ...(opts.geolocation ? { geolocation: opts.geolocation, permissions: ['geolocation'] } : {}),
  });
  if (opts.clock) await ctx.addInitScript(`(() => { const T = ${+opts.clock}; const D = Date; const off = T - D.now();
    globalThis.Date = class extends D { constructor(...a) { super(...(a.length ? a : [D.now() + off])); } static now() { return D.now() + off; } }; })()`);
  const p = await ctx.newPage();
  const noaa = { calls: [], offline: !!opts.noaaOffline };
  await p.route(/^https:\/\//, async route => {
    const url = route.request().url();
    if (url.includes('api.tidesandcurrents.noaa.gov')) {
      noaa.calls.push(url);
      if (noaa.offline) return route.abort('internetdisconnected');
      return route.fulfill({ status: 200, body: noaaBody(url), headers: { 'content-type': 'application/json;charset=UTF-8', 'access-control-allow-origin': '*' } });
    }
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
  return { browser: b, ctx, page: p, errs, noaa };
};
