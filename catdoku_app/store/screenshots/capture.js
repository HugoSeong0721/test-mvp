// App Store 스크린샷 원본 찍기: 웹 미리보기(docs/catdoku-app)를 iPhone 13 크기(1170×2532)로 띄워 화면별로 캡처.
// 실행: (docs 를 http://localhost:8770/test-mvp/ 로 띄운 뒤) NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node capture.js
const H = require('../../qa/flutter-web-harness.js');
const CK = __dirname + '/../../flutter/build/web/canvaskit';
const URL = 'http://localhost:8770/test-mvp/catdoku-app/index.html';
const out = n => __dirname + '/raw/' + n;
async function open(init) {
  return H.open({ url: URL, scale: 3, canvaskit: CK, init });
}
async function hints(p, k) {
  for (let i = 0; i < k; i++) {
    await p.getByRole('button', { name: /Hint/ }).click(); await p.waitForTimeout(500);
    await p.getByRole('button', { name: /Watch video/ }).click(); await p.waitForTimeout(900);
  }
}
(async () => {
  // 1) 오늘의 퍼즐 진행 중 (고양이 4마리)
  let { browser, page: p, errs } = await open(() => { localStorage['flutter.seenHowTo'] = 'true'; });
  await p.getByRole('button', { name: 'Play', exact: true }).click(); await p.waitForTimeout(1500);
  await hints(p, 4); await p.waitForTimeout(2600);
  await p.screenshot({ path: out('1-play.png') });
  await browser.close();
  // 3) 승리 패널 (단계 9, 6×6)
  ({ browser, page: p } = await open(() => { localStorage['flutter.seenHowTo'] = 'true'; localStorage['flutter.level'] = '9'; }));
  await p.getByRole('button', { name: 'Continue' }).click(); await p.waitForTimeout(1500);
  await hints(p, 6); await p.waitForTimeout(1500);
  await p.screenshot({ path: out('3-win.png') });
  await browser.close();
  // 4) 단계 목록
  ({ browser, page: p } = await open(() => { localStorage['flutter.seenHowTo'] = 'true'; localStorage['flutter.level'] = '18'; }));
  await p.getByRole('button', { name: /All levels/ }).click(); await p.waitForTimeout(1800);
  await p.screenshot({ path: out('4-levels.png') });
  await browser.close();
  // 5) 9×9 큰 판
  ({ browser, page: p } = await open(() => { localStorage['flutter.seenHowTo'] = 'true'; localStorage['flutter.level'] = '60'; localStorage['flutter.premium'] = 'true'; }));
  await p.getByRole('button', { name: 'Continue' }).click(); await p.waitForTimeout(1500);
  await hints(p, 3); await p.waitForTimeout(2600);
  await p.screenshot({ path: out('5-big.png') });
  await browser.close();
  // 6) 홈 (연속 기록)
  ({ browser, page: p } = await open(() => { localStorage['flutter.seenHowTo'] = 'true'; localStorage['flutter.level'] = '18'; localStorage['flutter.streak'] = '7'; localStorage['flutter.bestStreak'] = '7'; localStorage['flutter.dailyTotal'] = '12';
    const d = new Date(); const k = '' + d.getFullYear() + String(d.getMonth() + 1).padStart(2, '0') + String(d.getDate()).padStart(2, '0'); localStorage['flutter.streakDay'] = JSON.stringify(k); }));
  await p.waitForTimeout(1500);
  await p.screenshot({ path: out('6-home.png') });
  await browser.close();
  console.log('errors', JSON.stringify(errs));
})();
