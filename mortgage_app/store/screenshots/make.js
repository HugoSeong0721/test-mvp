// raw/(1170×2532, 테스트 로봇이 찍음) → App Store 6.7형(1290×2796) 홍보 이미지: 위에 큰 제목, 아래에 앱 화면.
// 실행: (mortgage_app/flutter 에서) flutter test test/store_shots_test.dart → node ../store/screenshots/make.js
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs');
const SHOTS = [
  ['1-payment.png', '01-payment.png', 'Your real monthly payment', 'Taxes, insurance, HOA & PMI included'],
  ['4-extra.png', '02-pay-extra.png', 'Pay off years sooner', 'See what an extra $200 a month saves'],
  ['3-breakdown.png', '03-breakdown.png', 'Where every dollar goes', 'Total interest, PMI & payoff date'],
  ['5-schedule.png', '04-schedule.png', 'Full amortization schedule', 'Every payment, by year or month'],
  ['6-auto.png', '05-auto-personal.png', 'Car & personal loans too', 'Trade-in and sales tax built in'],
];
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const p = await b.newPage({ viewport: { width: 1290, height: 2796 } });
  for (const [src, dst, title, sub] of SHOTS) {
    const img = fs.readFileSync(__dirname + '/raw/' + src).toString('base64');
    await p.setContent(`<html><body style="margin:0;width:1290px;height:2796px;background:linear-gradient(#0E8A6E,#075A48);font-family:Roboto,Arial,sans-serif;overflow:hidden">
      <div style="text-align:center;padding-top:120px;color:#fff;font-size:92px;font-weight:900;letter-spacing:-1px">${title}</div>
      <div style="text-align:center;margin-top:24px;color:#CFF3E6;font-size:52px;font-weight:600">${sub}</div>
      <div style="position:absolute;left:105px;top:520px;width:1080px;height:2337px;border-radius:72px;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.4);border:14px solid #0B2A22">
        <img src="data:image/png;base64,${img}" style="width:100%;display:block"></div></body></html>`);
    await p.waitForTimeout(300);
    await p.screenshot({ path: __dirname + '/' + dst });
    console.log('made', dst);
  }
  await b.close();
})();
