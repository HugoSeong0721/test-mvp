// 웹 미리보기(docs/solunar-app) 실제 클릭 점검 + 화면별 스크린샷 (iPhone 13 = 1170×2532).
// 실행: (docs 를 /test-mvp/ 로 띄운 뒤) NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node solunar_app/qa/web-check.js
const H = require('./web-harness.js');
const path = require('path');
const APP_URL = process.env.APP_URL || 'http://localhost:8765/test-mvp/solunar-app/index.html';
const SHOTS = path.join(__dirname, 'shots');
const NOW = Date.UTC(2026, 9, 2, 17, 0); // Fri Oct 2 2026, 12:00 PM CDT
const AUSTIN = { latitude: 30.2672, longitude: -97.7431 };
const log = [];
let fails = 0;
const ok = (cond, what) => { log.push(`${cond ? 'PASS' : 'FAIL'}  ${what}`); if (!cond) fails++; };

async function shot(page, name) { await page.waitForTimeout(500); await page.screenshot({ path: path.join(SHOTS, name) }); log.push(`      📸 ${name}`); }
const btn = (page, name) => page.getByRole('button', { name });
// Flutter web merges a card's texts into one aria-label → search labels and text of every semantics node.
async function has(page, re, t = 6000) {
  const src = re instanceof RegExp ? re.source : re.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  try {
    await page.waitForFunction(s => {
      const r = new RegExp(s);
      return [...document.querySelectorAll('flt-semantics, h1, h2, h3, span')].some(n => r.test(n.getAttribute('aria-label') || '') || r.test([...n.childNodes].filter(c => c.nodeType === 3).map(c => c.textContent).join('')));
    }, src, { timeout: t });
    return true;
  } catch { return false; }
}
async function scrollDown(page, px) { await page.mouse.move(195, 600); await page.mouse.wheel(0, px); await page.waitForTimeout(400); }

(async () => {
  // 1) 첫 실행 → 내 위치(오스틴) → 메인 화면 전체
  let { browser, page, errs, net } = await H.open({ url: APP_URL, geolocation: AUSTIN, clock: NOW });
  ok(await has(page, 'Best fishing & hunting times'), 'Welcome screen shows');
  await shot(page, '01-welcome.png');
  await btn(page, /Use My Location/).click();
  ok(await has(page, /in Austin, TX\. Times in CDT/, 10000), 'Use My Location → "in Austin, TX", times in CDT (phone time zone)');
  ok(await has(page, /Today · Fri, Oct 2/), 'today title');
  ok(await has(page, /day for fishing & hunting/), 'score headline');
  ok(await has(page, /NEXT: MINOR PERIOD|PERIOD NOW|NEXT: MAJOR PERIOD/), 'now/next card');
  ok(await has(page, /Moon overhead \d/), 'Major period with moon overhead time');
  await shot(page, '02-home.png');
  await scrollDown(page, 700);
  ok(await has(page, /Shooting light ends in/), 'hunting countdown at noon');
  ok(await has(page, /30 min before sunrise to 30 min after sunset/), 'legal light rule text');
  await shot(page, '03-home-hunting.png');
  await scrollDown(page, 3000);
  ok(await has(page, /Next full moon/), 'sun & moon card');
  ok(await has(page, /30-Day Calendar/), 'calendar button');
  await shot(page, '04-home-bottom.png');
  // 점수 설명
  await scrollDown(page, -3000);
  await btn(page, /How is this scored/).click();
  ok(await has(page, 'How the score works'), 'score sheet opens');
  ok(await has(page, /\/ 60/) && await has(page, /\/ 25/) && await has(page, /\/ 15/), 'three score parts shown');
  await shot(page, '05-score-sheet.png');
  await btn(page, 'Done').click();
  // 주간 띠
  await btn(page, /^Saturday Oct 3/).click();
  ok(await has(page, /Tomorrow · Sat, Oct 3/), 'week strip → Saturday');
  await shot(page, '06-saturday.png');
  await btn(page, /^Friday Oct 2/).click();
  ok(await has(page, /Today · Fri, Oct 2/), 'week strip → back to today');
  // 30일 달력 (영상 보고 열기 — 웹은 가짜 광고)
  await scrollDown(page, 3000);
  await btn(page, /30-Day Calendar/).click();
  ok(await has(page, /Watch a short video/), 'unlock dialog');
  await shot(page, '07-unlock.png');
  await btn(page, /Watch Video/).click();
  ok(await has(page, 'BEST DAYS AHEAD', 8000), 'calendar opens after video');
  await shot(page, '08-calendar.png');
  await page.getByRole('button', { name: /^Sat, Oct 10/ }).first().click();
  ok(await has(page, /Sat, Oct 10/), 'calendar day → main screen shows that day');
  ok(await has(page, /New Moon/), 'Oct 10 is a new moon');
  // 설정
  await btn(page, 'Settings').click();
  ok(await has(page, 'LEGAL SHOOTING LIGHT'), 'settings opens');
  await btn(page, 'Ends after sunset: 5 minutes less').click();
  ok(await has(page, '25 min'), 'after-sunset −5 → 25 min');
  await page.getByRole('checkbox', { name: /30 min \/ sunset/ }).click();
  ok(await has(page, '0 min'), 'preset 30 / sunset');
  await shot(page, '09-settings.png');
  await btn(page, 'Back').click();
  await scrollDown(page, -3000);
  await btn(page, /^Friday Oct 2/).click();
  await scrollDown(page, 700);
  ok(await has(page, /30 min before sunrise to 0 min after sunset/), 'new offsets on the hunting card');
  // 장소 검색
  await scrollDown(page, -3000);
  await btn(page, /Change place/).click();
  ok(await has(page, 'Use My Location'), 'places screen');
  await page.getByRole('textbox').click();
  await page.keyboard.type('bozeman', { delay: 30 });
  ok(await page.getByRole('button', { name: /Bozeman, MT/ }).first().waitFor({ timeout: 6000 }).then(() => true, () => false), 'search "bozeman" finds Bozeman, MT');
  await shot(page, '10-search.png');
  await page.getByRole('button', { name: /Bozeman, MT/ }).first().click();
  ok(await has(page, /Bozeman, MT\. Times in MDT/), 'Bozeman times in MDT (place zone, not the phone\'s CDT)');
  await btn(page, 'Save place').click();
  ok(await btn(page, 'Remove from saved').first().waitFor({ timeout: 5000 }).then(() => true, () => false), 'saved (star on)');
  await btn(page, /Change place/).click();
  ok(await has(page, 'SAVED PLACES'), 'places shows saved section');
  await shot(page, '11-places-saved.png');
  await btn(page, 'Back').click();
  const external = net.filter(u => !/fonts\.gstatic\.com|flutter-canvaskit|fonts\.googleapis/.test(u));
  ok(external.length === 0, `no network calls besides fonts/engine (${external.length})`);
  await browser.close();
  log.push(`      console errors: ${errs.length}${errs.length ? ' → ' + errs.slice(0, 3).join(' | ') : ''}`);
  ok(errs.length === 0, 'no console errors (session 1)');

  // 2) 위치 거부 → 안내 → 검색으로 시작
  ({ browser, page, errs } = await H.open({ url: APP_URL, clock: NOW }));
  await btn(page, /Use My Location/).click();
  ok(await has(page, /search|Settings/i, 30000), 'location not given → message (no endless spinner)');
  await shot(page, '12-location-denied.png');
  await btn(page, /Search a Town/).click();
  await page.getByRole('textbox').click();
  await page.keyboard.type('duluth mn', { delay: 30 });
  await page.getByRole('button', { name: /Duluth, MN/ }).first().click();
  ok(await has(page, /Duluth, MN/), 'search start → Duluth');
  await browser.close();
  ok(errs.length === 0, 'no console errors (denied)');

  // 3) 광고 실패: 영상 없음(?ads=none) → 그래도 열림 / 중간에 닫음(?ads=early) → 잠김
  ({ browser, page, errs } = await H.open({ url: APP_URL + '?ads=early', geolocation: AUSTIN, clock: NOW }));
  await btn(page, /Use My Location/).click();
  await has(page, /in Austin, TX/, 10000);
  await scrollDown(page, 3000);
  await btn(page, /30-Day Calendar/).click();
  await btn(page, /Watch Video/).click();
  ok(await has(page, /closed early/, 6000), '?ads=early → stays locked with a message');
  await browser.close();
  ({ browser, page, errs } = await H.open({ url: APP_URL + '?ads=none', geolocation: AUSTIN, clock: NOW }));
  await btn(page, /Use My Location/).click();
  await has(page, /in Austin, TX/, 10000);
  await scrollDown(page, 3000);
  await btn(page, /30-Day Calendar/).click();
  await btn(page, /Watch Video/).click();
  ok(await has(page, 'Loading video…', 3000), '?ads=none → Loading video…');
  ok(await has(page, 'BEST DAYS AHEAD', 15000), '?ads=none → opens anyway after the wait');
  await browser.close();

  // 4) 작은 화면 (iPhone SE) + 큰 화면 (15 Pro Max)
  for (const [name, vp, scale] of [['13-iphone-se.png', { width: 375, height: 667 }, 2], ['14-pro-max.png', { width: 430, height: 932 }, 3]]) {
    ({ browser, page, errs } = await H.open({ url: APP_URL, viewport: vp, scale, geolocation: AUSTIN, clock: NOW }));
    await btn(page, /Use My Location/).click();
    ok(await has(page, /in Austin, TX/, 10000), `${name}: home`);
    await shot(page, name);
    await browser.close();
    ok(errs.length === 0, `no console errors (${name})`);
  }

  console.log(log.join('\n'));
  console.log(`\n${fails ? '❌' : '✅'} ${log.filter(l => l.startsWith('PASS')).length} passed, ${fails} failed`);
  process.exit(fails ? 1 : 0);
})().catch(e => { console.log(log.join('\n')); console.error(e); process.exit(2); });
