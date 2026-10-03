// raw/(1170×2532) → App Store 6.7형(1290×2796) 홍보 이미지: 위에 큰 제목, 아래에 앱 화면.
// 실행: node make.js
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs');
const SHOTS = [
  ['1-play.png', '01-play.png', 'One cat in every color', 'Row, column & color — cats can’t touch'],
  ['5-big.png', '02-levels-grow.png', '500 levels', 'From quick 5×5 to brain-bending 9×9'],
  ['6-home.png', '03-daily.png', 'A new puzzle every day', 'Keep your streak going 🔥'],
  ['3-win.png', '04-solved.png', 'Purr-fect!', 'Relaxing logic puzzles with cats'],
  ['4-levels.png', '05-all-levels.png', 'Replay any level', 'See how many you’ve solved'],
];
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
  const p = await b.newPage({ viewport: { width: 1290, height: 2796 } });
  for (const [src, dst, title, sub] of SHOTS) {
    const img = fs.readFileSync(__dirname + '/raw/' + src).toString('base64');
    await p.setContent(`<html><body style="margin:0;width:1290px;height:2796px;background:#4A3B28;font-family:Roboto,Arial,sans-serif;overflow:hidden">
      <div style="text-align:center;padding-top:120px;color:#FFD98A;font-size:96px;font-weight:900;letter-spacing:-1px">${title}</div>
      <div style="text-align:center;margin-top:24px;color:#F6EFE4;font-size:52px;font-weight:600">${sub}</div>
      <div style="position:absolute;left:105px;top:520px;width:1080px;height:2337px;border-radius:72px;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.45);border:14px solid #2a2117">
        <img src="data:image/png;base64,${img}" style="width:100%;display:block"></div></body></html>`);
    await p.waitForTimeout(300);
    await p.screenshot({ path: __dirname + '/' + dst });
    console.log('made', dst);
  }
  await b.close();
})();
