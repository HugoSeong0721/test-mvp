// 연비 기록 웹 미리보기를 아이폰 13 크기 헤드리스 Chromium 으로 실제로 눌러 보고 화면을 찍는다.
// catdoku_app/qa/flutter-web-harness.js 방식(gstatic 차단 → canvaskit 로컬 응답).
//   1) 처음 켬: 차 이름 → 주유 두 번 입력 → 30.0 MPG 가 화면에 나오는지 → 탭 4개 → CSV 내보내기(다운로드 내용 확인)
//   2) ?demo=1: 예시 기록으로 모든 탭·입력 화면을 열어 본다
//
// 준비: (cd <srv> && python3 -m http.server 8765)  — <srv>/test-mvp → 리포의 docs 로 심볼릭 링크
// 실행: NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node fuellog_app/qa/web-check.js <스크린샷 폴더>
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs'), path = require('path');

const BASE = 'http://localhost:8765/test-mvp/fuel-log-app/index.html';
const CK = path.resolve(__dirname, '../flutter/build/web/canvaskit');
const OUT = path.resolve(process.argv[2] || 'qa-shots');
fs.mkdirSync(OUT, { recursive: true });

async function open(url) {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, hasTouch: true, isMobile: true, acceptDownloads: true });
  const p = await ctx.newPage();
  await p.route(/^https:\/\//, async route => {
    const u = route.request().url();
    const m = /flutter-canvaskit\/[0-9a-f]+\/(.*)$/.exec(u);
    if (m) {
      const f = path.join(CK, m[1]);
      if (fs.existsSync(f)) {
        return route.fulfill({ status: 200, body: fs.readFileSync(f), headers: { 'content-type': f.endsWith('.wasm') ? 'application/wasm' : 'text/javascript', 'access-control-allow-origin': '*' } });
      }
    }
    try {
      const r = await fetch(u);
      await route.fulfill({ status: r.status, body: Buffer.from(await r.arrayBuffer()), headers: { 'content-type': r.headers.get('content-type') || 'application/octet-stream', 'access-control-allow-origin': '*' } });
    } catch (e) { await route.abort(); }
  });
  const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  cur = p;
  await p.goto(url);
  await p.getByRole('button').first().waitFor({ timeout: 40000 });
  await p.waitForTimeout(1200);
  return { b, p, errs };
}

let cur = null; // 실패하면 그 순간 화면을 남긴다
const log = [];
const step = (s) => { log.push(s); console.log('•', s); };
const fail = [];
const check = (ok, what) => { step((ok ? 'OK   ' : 'FAIL ') + what); if (!ok) fail.push(what); };
async function shot(p, name) { await p.waitForTimeout(400); await p.screenshot({ path: path.join(OUT, name + '.png') }); step('screenshot ' + name); }
async function tap(p, name) { await p.getByRole('button', { name }).first().click(); step('tap ' + name); await p.waitForTimeout(700); }
async function tab(p, name) { await p.getByRole('tab', { name }).or(p.getByRole('button', { name })).first().click(); step('tab ' + name); await p.waitForTimeout(700); }
async function type(p, label, text) {
  const box = p.getByRole('textbox', { name: label }).first();
  await box.click();
  await p.waitForTimeout(250);
  await p.keyboard.type(text);
  step(`type ${label} = ${text}`);
  await p.waitForTimeout(250);
}
/// 화면 읽기 트리에 있는 모든 글자
async function texts(p) {
  return (await p.locator('flt-semantics').evaluateAll(es => es.map(e => ((e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')).trim()))).join(' | ');
}

(async () => {
  // ───── 1) 처음 켬 ─────
  let { b, p, errs } = await open(BASE);
  await shot(p, '01-welcome');
  await type(p, /e\.g\. 2019 Honda Civic|Your car/, 'Test Car');
  await tap(p, /Start logging/);
  check(/Test Car/.test(await texts(p)), 'vehicle name shown after start');
  await shot(p, '02-empty-log');

  await tap(p, /^Fill-up$/);
  await type(p, /Odometer/, '10000');
  await type(p, /Gallons/, '12');
  await type(p, /Price per gallon/, '3.25');
  await p.keyboard.press('Tab').catch(() => {});
  await shot(p, '03-first-fill');
  await tap(p, /Save fill-up/);
  await tap(p, /^Fill-up$/);
  await type(p, /Odometer/, '10300');
  await type(p, /Gallons/, '10');
  await type(p, /Total cost/, '35');
  await p.waitForTimeout(500);
  check(/This tank: 30\.0 MPG/.test(await texts(p)), 'live preview shows 30.0 MPG');
  await shot(p, '04-second-fill');
  await tap(p, /Save fill-up/);
  await p.waitForTimeout(600);
  const t1 = await texts(p);
  check(/30\.0/.test(t1) && /MPG average/.test(t1), 'log shows 30.0 MPG average');
  await shot(p, '05-log-two-fills');

  for (const name of [/^Charts/, /Reminders/, /^More/]) {
    await tab(p, name);
    await shot(p, '06-tab-' + String(name).replace(/[^a-z]/gi, ''));
  }
  // 내보내기 → 브라우저 다운로드
  const dl = p.waitForEvent('download', { timeout: 8000 }).catch(() => null);
  await tap(p, /Export CSV/);
  const d = await dl;
  if (d) {
    const file = path.join(OUT, await d.suggestedFilename());
    await d.saveAs(file);
    const csv = fs.readFileSync(file, 'utf8');
    check(/^Vehicle,Type,Date,Odometer \(mi\)/.test(csv) && /Test Car,Fuel,.*,10300,10,3\.5,35/.test(csv), 'exported CSV has both fill-ups: ' + path.basename(file));
  } else check(false, 'export started a download');
  const e1 = [...errs];
  await b.close();

  // ───── 2) 예시 기록 ─────
  ({ b, p, errs } = await open(BASE + '?demo=1'));
  const t2 = await texts(p);
  check(/2019 Honda Civic/.test(t2) && /MPG average/.test(t2), 'demo log loaded');
  await shot(p, '10-demo-log');
  await tab(p, /^Charts/);
  await shot(p, '11-demo-charts');
  await tap(p, /^All$/);
  await shot(p, '12-demo-charts-all');
  await tab(p, /Reminders/);
  check(/Overdue by|In \d/.test(await texts(p)), 'reminder status text shown');
  await shot(p, '13-demo-reminders');
  await tap(p, /Log it/);
  await shot(p, '14-demo-log-it');
  await tap(p, /Close/);
  await tab(p, /^More/);
  await tap(p, /Trip cost split/);
  await type(p, /Trip distance/, '300');
  await shot(p, '15-demo-trip');
  await tap(p, /Back/);
  await tab(p, /^Log/);
  await tap(p, /Vehicle:/);
  await shot(p, '16-demo-vehicle-picker');
  await tap(p, /2021 Ford F-150/);
  check(/2021 Ford F-150/.test(await texts(p)), 'switched to truck');
  await shot(p, '17-demo-truck');
  await tap(p, /^Service$/);
  await shot(p, '18-demo-service');
  const e2 = [...errs];
  await b.close();

  const all = [...e1, ...e2];
  step('console errors: ' + all.length);
  all.forEach(e => console.log('   ERR', e));
  step('checks failed: ' + fail.length);
  fs.writeFileSync(path.join(OUT, 'log.txt'), log.join('\n') + '\n' + all.map(e => 'ERR ' + e).join('\n'));
  process.exit(fail.length || all.length ? 1 : 0);
})().catch(async e => {
  console.error('FAILED', e);
  if (cur) {
    await cur.screenshot({ path: path.join(OUT, 'zz-failed.png') }).catch(() => {});
    console.error('SEMANTICS:', (await texts(cur).catch(() => '')).slice(0, 1500));
  }
  process.exit(1);
});
