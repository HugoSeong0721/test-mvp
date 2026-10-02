// Glance dB 웹 미리보기를 아이폰 13 크기 헤드리스 Chromium 으로 실제로 눌러 보고 화면을 찍는다.
// 크롬의 가짜 마이크(--use-fake-device-for-media-stream: 삐 소리)로 진짜 측정 경로(getUserMedia → PCM → 계산)를 탄다.
// catdoku_app/qa/flutter-web-harness.js 와 같은 방식(gstatic 차단 → canvaskit 로컬 응답) + 마이크 플래그·권한 거부 상황 추가.
//
// 준비: (cd <srv> && python3 -m http.server 8765)  — <srv>/test-mvp → 리포의 docs 로 심볼릭 링크
// 실행: NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node decibel_app/qa/web-check.js <스크린샷 폴더>
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs'), path = require('path');

const URL = 'http://localhost:8765/test-mvp/decibel-app/index.html';
const CK = path.resolve(__dirname, '../flutter/build/web/canvaskit');
const OUT = path.resolve(process.argv[2] || 'qa-shots');
fs.mkdirSync(OUT, { recursive: true });

async function open({ deny = false } = {}) {
  const args = ['--no-sandbox', '--use-fake-device-for-media-stream'];
  args.push(deny ? '--deny-permission-prompts' : '--use-fake-ui-for-media-stream');
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args });
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
  if (!deny) await ctx.grantPermissions(['microphone'], { origin: 'http://localhost:8765' });
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
      await route.fulfill({ status: r.status, body: Buffer.from(await r.arrayBuffer()), headers: { 'content-type': r.headers.get('content-type') || 'application/octet-stream', 'access-control-allow-origin': '*' } });
    } catch (e) { await route.abort(); }
  });
  const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  await p.goto(URL);
  await p.getByRole('button').first().waitFor({ timeout: 30000 });
  await p.waitForTimeout(1200);
  return { b, p, errs };
}

const log = [];
const step = (s) => { log.push(s); console.log('•', s); };
async function shot(p, name) { await p.screenshot({ path: path.join(OUT, name + '.png') }); step('screenshot ' + name); }
async function tap(p, name) { await p.getByRole('button', { name }).first().click(); step('tap ' + name); await p.waitForTimeout(700); }
async function back(p) { await p.getByRole('button', { name: 'Back' }).click(); step('tap Back'); await p.waitForTimeout(700); }
async function reading(p) {
  // Flutter 웹 접근성 트리: 버튼이 아닌 글자는 aria-label 이 아니라 글자 내용으로 들어간다
  const texts = await p.locator('flt-semantics').evaluateAll(es => es.map(e => (e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')));
  const hit = texts.map(t => /(\d+|<20) dB[ACZ]/.exec(t)).find(Boolean);
  return hit ? hit[0] : texts.some(t => /No reading/.test(t)) ? 'No reading yet' : '(gauge label not found)';
}

(async () => {
  // 1) 처음 실행 → 안내 → Continue → 가짜 마이크로 측정
  let { b, p, errs } = await open();
  await shot(p, '01-intro');
  await tap(p, /Continue/);
  await p.waitForTimeout(4000);
  step('gauge after 4 s: ' + await reading(p));
  await shot(p, '02-measuring');
  await tap(p, /Sound level guide/);
  await shot(p, '03-guide');
  await back(p);
  await p.waitForTimeout(3000);
  await tap(p, /^Report$/);
  await p.waitForTimeout(800);
  await shot(p, '04-report');
  await back(p);
  await tap(p, /^Pause$/);
  step('gauge after pause: ' + await reading(p));
  await shot(p, '05-paused');
  await tap(p, /History/);
  await shot(p, '06-history');
  await back(p);
  await tap(p, /Settings/);
  await shot(p, '07-settings');
  await back(p);
  await tap(p, /^Resume$/);
  await p.waitForTimeout(2000);
  step('gauge after resume: ' + await reading(p));
  await tap(p, /^Reset$/);
  step('gauge after reset: ' + await reading(p));
  const e1 = [...errs];
  await b.close();

  // 2) 마이크 거부
  ({ b, p, errs } = await open({ deny: true }));
  await tap(p, /Continue/);
  await p.waitForTimeout(1500);
  await shot(p, '08-mic-blocked');
  await tap(p, /Try again/);
  await p.waitForTimeout(800);
  const e2 = [...errs];
  await b.close();

  const all = [...e1, ...e2];
  step('console errors: ' + all.length);
  all.forEach(e => console.log('   ERR', e));
  fs.writeFileSync(path.join(OUT, 'log.txt'), log.join('\n') + '\n' + all.map(e => 'ERR ' + e).join('\n'));
})().catch(e => { console.error('FAILED', e); process.exit(1); });
