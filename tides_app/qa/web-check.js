// 웹 미리보기(docs/tides-app) 실제 클릭 점검 + 화면별 스크린샷 (iPhone 13 = 1170×2532).
// 실행: (docs 를 /test-mvp/ 로 띄운 뒤) NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node tides_app/qa/web-check.js
const H = require('./web-harness.js');
const path = require('path');
const APP_URL = process.env.APP_URL || 'http://localhost:8765/test-mvp/tides-app/index.html';
const SHOTS = path.join(__dirname, 'shots');
const NOW = Date.UTC(2026, 9, 2, 19, 0); // Fri Oct 2 2026, 12:00 PM PDT (inside the NOAA fixtures)
const log = [];
let fails = 0;
const ok = (cond, what) => { log.push(`${cond ? 'PASS' : 'FAIL'}  ${what}`); if (!cond) fails++; };

async function shot(page, name) { await page.waitForTimeout(500); await page.screenshot({ path: path.join(SHOTS, name) }); log.push(`      📸 ${name}`); }
const btn = (page, name) => page.getByRole('button', { name });
async function has(page, re, t = 6000) { try { await page.getByText(re).first().waitFor({ timeout: t }); return true; } catch { return false; } }

(async () => {
  // 1) 첫 실행 → 내 위치(샌프란시스코) → 물때 화면
  let { browser, page, errs, noaa } = await H.open({ url: APP_URL, geolocation: { latitude: 37.8063, longitude: -122.4659 }, clock: NOW });
  ok(await has(page, 'Tides near you'), 'Welcome screen shows');
  await shot(page, '01-welcome.png');
  await btn(page, /Use My Location/).click();
  ok(await has(page, /San Francisco \(Golden Gate\)/, 10000), 'Use My Location → nearest station San Francisco');
  ok(await has(page, /Rising|Falling/), 'Rising/Falling shown');
  ok(await has(page, /ft now/), 'height now in ft');
  ok(await has(page, /Today · Fri, Oct 2/), 'today chart title');
  ok(noaa.calls.some(u => u.includes('interval=hilo')) && noaa.calls.some(u => u.includes('interval=6')), 'NOAA hilo + 6-minute requested');
  ok(noaa.calls.every(u => u.includes('time_zone=gmt') && u.includes('datum=MLLW') && !/lat|lon/.test(new URL(u).search)), 'requests carry no location');
  await shot(page, '02-home.png');
  // 그래프 탭 → 시각 읽기
  const title = await page.getByText(/Today · Fri, Oct 2/).first().boundingBox();
  const chart = { x: title.x, y: title.y + title.height + 10, width: 340, height: 170 };
  await page.mouse.click(chart.x + chart.width * 0.7, chart.y + chart.height * 0.5);
  ok(await has(page, /PM · [−0-9.]+ ft/), 'chart tap shows time · height');
  await shot(page, '03-chart-readout.png');
  // 7일 표에서 토요일
  await page.getByRole('button', { name: /^Sat/ }).first().click();
  ok(await has(page, /Saturday · Oct 3/), 'tap Saturday row → chart shows Saturday');
  await shot(page, '04-saturday.png');
  // 설정: 미터
  await btn(page, 'Settings').click();
  ok(await has(page, /Not for navigation/), 'settings sheet with Not for navigation');
  await shot(page, '05-settings.png');
  await page.getByRole('button', { name: /^Meters/ }).first().click();
  await btn(page, 'Done').click();
  ok(await has(page, / m now/), 'meters applied');
  await btn(page, 'Settings').click();
  await page.getByRole('button', { name: /^Feet/ }).first().click();
  await btn(page, 'Done').click();
  ok(await has(page, /ft now/), 'back to feet');
  // 즐겨찾기
  await btn(page, 'Add to favorites').click();
  ok(await btn(page, 'Remove from favorites').first().waitFor({ timeout: 5000 }).then(() => true, () => false), 'favorite star on');
  // 관측소 검색
  await btn(page, 'Change station').click();
  ok(await has(page, 'FAVORITES'), 'stations: favorites section');
  ok(await has(page, 'NEARBY'), 'stations: nearby section');
  await page.getByRole('textbox').click();
  await page.keyboard.type('santa monica', { delay: 30 });
  ok(await page.getByRole('button', { name: /Santa Monica, Municipal Pier/ }).first().waitFor({ timeout: 6000 }).then(() => true, () => false), 'search "santa monica" finds the pier');
  await shot(page, '06-search.png');
  await page.getByRole('button', { name: /Santa Monica, Municipal Pier/ }).first().click();
  ok(await has(page, /Santa Monica, Municipal Pier/), 'picked Santa Monica → home');
  ok(await has(page, /PDT/), 'times in PDT');
  // 보조 관측소 (곡선 추정 표기)
  await btn(page, 'Change station').click();
  await page.getByRole('textbox').click();
  await page.keyboard.type('san nicolas', { delay: 30 });
  await page.getByRole('button', { name: /San Nicolas Island/ }).first().click();
  ok(await has(page, /San Nicolas Island/), 'subordinate station opens');
  await page.mouse.wheel(0, 800);
  ok(await has(page, /estimated/), 'subordinate: curve marked as estimated');
  await shot(page, '07-subordinate.png');
  await browser.close();
  log.push(`      console errors: ${errs.length}${errs.length ? ' → ' + errs.slice(0, 3).join(' | ') : ''}`);
  ok(errs.length === 0, 'no console errors (session 1)');

  // 2) 신호 없이 처음 켜면 "No data" + Try again (저장된 예보 + Offline 안내는 테스트 로봇이 확인)
  ({ browser, page, errs, noaa } = await H.open({ url: APP_URL, geolocation: { latitude: 21.3, longitude: -157.86 }, clock: NOW, noaaOffline: true }));
  await btn(page, /Use My Location/).click();
  ok(await has(page, 'No data', 10000), 'offline, nothing saved → No data (no fake curve)');
  ok(await has(page, /Couldn't reach NOAA/), 'readable reason');
  await shot(page, '08-no-data.png');
  noaa.offline = false;
  await btn(page, /Try again/).click();
  ok(await has(page, /Rising|Falling/, 10000), 'Try again online → data');
  ok(await has(page, 'Honolulu'), 'Honolulu nearest');
  await browser.close();
  log.push(`      console errors: ${errs.length}${errs.length ? ' → ' + errs.slice(0, 3).join(' | ') : ''}`);

  // 3) 위치 거부 → 안내 → 검색
  ({ browser, page, errs, noaa } = await H.open({ url: APP_URL, clock: NOW }));
  await btn(page, /Use My Location/).click();
  // headless Chromium leaves the permission prompt unanswered → the app's 12 s location time limit must end the wait
  ok(await has(page, /search for a station|Settings/, 30000), 'location not given → message (no endless spinner)');
  await shot(page, '09-location-denied.png');
  await btn(page, /Search Stations/).click();
  ok(await has(page, 'POPULAR'), 'search screen with popular stations');
  await btn(page, 'Back').click();
  ok(await has(page, 'Tides near you'), 'Back → welcome');
  await browser.close();
  log.push(`      console errors: ${errs.length}${errs.length ? ' → ' + errs.slice(0, 3).join(' | ') : ''}`);

  // 4) 작은 화면 (iPhone SE)
  ({ browser, page, errs, noaa } = await H.open({ url: APP_URL, viewport: { width: 375, height: 667 }, scale: 2, geolocation: { latitude: 40.7, longitude: -74.01 }, clock: NOW }));
  await btn(page, /Use My Location/).click();
  ok(await has(page, /New York \(The Battery\)/, 10000), 'iPhone SE: New York nearest');
  await shot(page, '10-iphone-se.png');
  await browser.close();
  ok(errs.length === 0, 'no console errors (SE)');

  console.log(log.join('\n'));
  console.log(`\n${fails ? '❌' : '✅'} ${log.filter(l => l.startsWith('PASS')).length} passed, ${fails} failed`);
  process.exit(fails ? 1 : 0);
})().catch(e => { console.log(log.join('\n')); console.error(e); process.exit(2); });
