const { chromium } = require('playwright-core');
const { PNG } = require('pngjs');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const output = process.argv[3];
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--enable-webgl', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('pageerror', error => errors.push(error.message));
  let checks = 0;
  const check = (value, label) => { assert.ok(value, label); checks++; console.log('PASS:', label); };
  const shot = async name => PNG.sync.read(await page.screenshot({ path: path.join(output, name + '.png') }));
  const pixel = (image, x, y) => [...image.data.subarray((Math.floor(y) * image.width + Math.floor(x)) * 4, (Math.floor(y) * image.width + Math.floor(x)) * 4 + 3)].join();
  const WHITE = '255,242,204', BLACK = '36,51,51';
  try {
    await page.goto(process.argv[2]);
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await page.waitForTimeout(800);
    let image = await shot('01-white-captures');
    check(pixel(image, 228, 612) === BLACK, 'White player collects the Black pawn at their near edge');
    check(pixel(image, 228, 316) === WHITE, 'The Black character collects the White pawn at the far edge');
    await page.keyboard.press('b');
    await page.waitForTimeout(100);
    image = await shot('02-black-captures');
    check(pixel(image, 228, 612) === WHITE && pixel(image, 228, 316) === BLACK, 'Both collections move with the player colour and board orientation');
    await page.keyboard.press('f');
    await page.waitForTimeout(100);
    await shot('03-desktop-full-trays');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(300);
    image = await shot('04-portrait-full-trays');
    check(pixel(image, 43, 634) === WHITE && pixel(image, 43, 298) === BLACK, 'Portrait trays keep the correct captured-piece colours at each edge');
    check(pixel(image, 347, 634) === WHITE && pixel(image, 347, 298) === BLACK, 'All fifteen captures fit into each portrait tray');
    check(pixel(image, 315, 332) === '112,147,145', 'The board remains separate from the portrait capture areas');
    await page.setViewportSize({ width: 452, height: 552 });
    await page.waitForTimeout(300);
    image = await shot('05-compact-full-trays');
    check(pixel(image, 26, 180) !== '255,250,240' && pixel(image, 26, 336) !== '255,250,240', 'Compact windows retain two separate capture trays');
    check(errors.length === 0, 'Capture visuals generate no browser errors');
    console.log(`CAPTURE BROWSER: ${checks}/${checks} checks passed`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
