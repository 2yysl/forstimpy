// npm install playwright pngjs (or set NODE_PATH to an existing installation).
// Start build_web.py's export on localhost, then:
// node browser_smoke.cjs http://127.0.0.1:8765 /tmp/chess-browser-evidence
const { chromium } = require('playwright-core');
const { PNG } = require('pngjs');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const output = process.argv[3] || '/tmp/forstimpy-chess-browser';
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--enable-webgl', '--enable-unsafe-swiftshader'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const consoleLines = [];
  const errors = [];
  page.on('console', message => {
    consoleLines.push(`${message.type()}: ${message.text()}`);
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('pageerror', error => errors.push(error.message));
  let checks = 0;
  const check = (condition, description) => {
    assert.ok(condition, description);
    checks++;
    console.log('PASS:', description);
  };
  const shot = async name => PNG.sync.read(await page.screenshot({ path: path.join(output, `${name}.png`) }));
  const click = async (x, y, delay = 180) => { await page.mouse.click(x, y); await page.waitForTimeout(delay); };
  const pixel = (image, x, y) => [...image.data.subarray((y * image.width + x) * 4, (y * image.width + x) * 4 + 3)];
  // Board square centers are away from borders and labels. A piece or marker
  // differs from that square's background color at its center.
  const occupied = (image, row, column) => {
    const x = 24 + column * 80, y = 32 + row * 80;
    return pixel(image, x + 40, y + 40).join() !== pixel(image, x + 4, y + 4).join();
  };
  try {
    await page.goto(process.argv[2] || 'http://127.0.0.1:8765/');
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await page.waitForTimeout(1200);
    await shot('01-title');
    await click(640, 590, 2300);
    const invitation = await shot('02-character');
    check(pixel(invitation, 645, 670).join() === '187,128,94', 'Invitation has no Not now button');
    await click(430, 670, 500);
    const initial = await shot('04-start');
    check(occupied(initial, 6, 4) && !occupied(initial, 4, 4), 'Sure opens starting position');
    await click(384, 552);
    const selected = await shot('05-selected');
    check(occupied(selected, 4, 4), 'Legal e4 destination highlights after selecting e2');
    await click(384, 312);
    const illegal = await shot('06-illegal');
    check(occupied(illegal, 6, 4) && !occupied(illegal, 3, 4), 'Illegal e2-e5 is rejected');
    await click(384, 552);
    await click(384, 392, 1200);
    let current = await shot('07-e4-c6');
    check(!occupied(current, 6, 4) && occupied(current, 4, 4), 'Human e4 executes');
    check(!occupied(current, 1, 2) && occupied(current, 2, 2), 'Release bot replies c6 from its opening book');
    await click(304, 552);
    await click(304, 392, 1200);
    current = await shot('08-d4-d5');
    check(!occupied(current, 1, 3) && occupied(current, 3, 3), 'Release bot follows with d5 in matching position');
    // Restart while a reply is queued, then ensure the position stays fresh.
    await click(970, 235, 300);
    await click(384, 552, 20);
    await click(384, 392, 20);
    await click(970, 235, 1200);
    current = await shot('09-restart-cancellation');
    check(occupied(current, 6, 4) && !occupied(current, 4, 4) && occupied(current, 1, 2), 'Restart cancels a pending reply');
    await click(1110, 188, 1200);
    current = await shot('10-human-black');
    check(pixel(current, 304, 632).join() === '36,51,51', 'Black king appears on the near rank in Black orientation');
    // White e4 appears on d5 visually from Black's perspective; d4 on e5.
    check((!occupied(current, 1, 3) && occupied(current, 3, 3)) || (!occupied(current, 1, 4) && occupied(current, 3, 4)), 'Bot White makes a legal opening with Black orientation');
    await click(464, 552);
    await click(464, 472, 1400);
    current = await shot('10b-black-c6');
    check(!occupied(current, 6, 5) && occupied(current, 5, 5), 'Human Black can move c7-c6 using the rotated board');
    await click(970, 327, 400);
    await shot('11-table-return');
    await click(640, 530, 300);
    await shot('12-reentry');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(300);
    // Start a fresh title flow to exercise both affirmative responses again.
    await page.reload();
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await page.waitForTimeout(700);
    await click(640, 590, 2300);
    await click(430, 670, 400);
    current = await shot('13-sure');
    check(occupied(current, 6, 4) && !occupied(current, 4, 4), 'Sure opens a playable board');
    await click(970, 327, 300);
    await click(860, 670, 2500);
    current = await shot('14-yes-but-red');
    check(occupied(current, 6, 4) && !occupied(current, 4, 4), 'Yes but red opens a playable board after dialogue');
    await click(970, 235, 200);
    await click(624, 552);
    await click(624, 392, 1600);
    current = await shot('15-fallback');
    let blackChanged = false;
    for (let row = 0; row < 4; row++) for (let column = 0; column < 8; column++) {
      if (occupied(current, row, column) !== occupied(initial, row, column)) blackChanged = true;
    }
    check(blackChanged, 'Bot continues moving after h4 book deviation');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(700);
    const narrow = await shot('16-portrait');
    check(narrow.width === 390 && narrow.height === 844, 'Portrait layout renders');
    check(pixel(narrow, 360, 40).join() === '112,147,145', 'Portrait board uses the available width instead of shrinking desktop controls');
    check(errors.length === 0, 'No browser console errors or script exceptions');
    console.log(`BROWSER: ${checks}/${checks} checks passed; Chromium ${await browser.version()}`);
  } finally {
    fs.writeFileSync(path.join(output, 'console.log'), consoleLines.join('\n') + '\n' + errors.join('\n'));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
