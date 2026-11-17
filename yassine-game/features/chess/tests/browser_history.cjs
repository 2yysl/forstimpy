// Real UI input. Only the separate fixture prepares initial completed games.
const { chromium } = require('playwright-core');
const { PNG } = require('pngjs');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const output = process.argv[3];
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--enable-webgl', '--enable-unsafe-swiftshader'] });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, permissions: ['clipboard-read', 'clipboard-write'] });
  const page = await context.newPage();
  const errors = [], lines = [];
  page.on('console', message => { lines.push(message.text()); if (message.type() === 'error') errors.push(message.text()); });
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(() => {
    window.__reviewLinks = [];
    // Observe the requested browser action without contacting external services.
    window.open = url => { window.__reviewLinks.push(String(url)); return null; };
  });
  let checks = 0;
  const check = (value, label) => { assert.ok(value, label); checks++; console.log('PASS:', label); };
  const wait = ms => page.waitForTimeout(ms);
  const click = async (x, y, delay = 120) => { await page.mouse.click(x, y); await wait(delay); };
  const shot = async name => PNG.sync.read(await page.screenshot({ path: path.join(output, name + '.png') }));
  const pixel = (image, x, y) => [...image.data.subarray((Math.floor(y) * image.width + Math.floor(x)) * 4, (Math.floor(y) * image.width + Math.floor(x)) * 4 + 3)].join();
  const signature = image => Array.from({ length: 64 }, (_, n) => {
    const row = Math.floor(n / 8), col = n % 8;
    return pixel(image, 422 + (col + 0.5) * 54.5, 252 + (row + 0.5) * 54.5) !== pixel(image, 426 + col * 54.5, 256 + row * 54.5);
  }).join();
  const clipboard = () => page.evaluate(() => navigator.clipboard.readText());
  try {
    await page.goto(process.argv[2]);
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await wait(3000);
    const live = await shot('01-live-with-history');
    const liveKey = signature(live);
    check(pixel(live, 890, 390) !== '255,250,240', 'The seated chess layout displays a session match-history panel');
    for (let i = 0; i < 12; i++) await click(946, 636, 30);
    const start = await shot('02-replay-start');
    check(signature(start) !== liveKey && pixel(start, 667, 606) === '255,242,204', 'Previous arrows navigate the whole game back to its starting board');
    for (let i = 0; i < 10; i++) await click(1150, 636, 30);
    check(signature(await shot('03-next-to-live')) === liveKey, 'Next arrows return to the identical live board');
    await click(1020, 425);
    const draw = await shot('04-archived-stalemate');
    check(signature(draw) !== liveKey, 'Selecting a history entry opens its archived position');
    await click(1210, 636);
    check(signature(await shot('05-live-preserved')) === liveKey, 'Returning from an archived game restores the unfinished live match');
    await click(1020, 444);
    await click(1160, 674, 500);
    const exportView = await shot('06-external-review-pgn');
    check(pixel(exportView, 240, 650) === '255,250,240' && pixel(exportView, 240, 690) !== '255,250,240', 'The desktop PGN modal fits on screen with its copy/open/back controls');
    const matePGN = await clipboard();
    check(matePGN.includes('1. f3 e5 2. g4 Qh4# 0-1'), 'Review copies the full exact archived game, including checkmate and result');
    check(!matePGN.includes('O-O'), 'Archived export does not accidentally copy the unfinished live game');
    check((await page.evaluate(() => window.__reviewLinks)).includes('https://www.chess.com/analysis'), 'Review opens the official Chess.com analysis page');
    await page.keyboard.press('Escape');
    await wait(120);
    await click(1210, 636);
    check(signature(PNG.sync.read(await page.screenshot())) === liveKey, 'Closing external review leaves the live match intact');
    await click(1160, 674); // Resign the current live game through its real button.
    await shot('07-finished-new-game');
    await click(1000, 674);
    const fists = await shot('08-new-game-fists');
    check(pixel(fists, 527, 486) !== '255,250,240' && pixel(fists, 753, 486) !== '255,250,240', 'New game after a result starts a fresh fist selection');
    await page.keyboard.press('s'); // Developer fixture prepares a stalemate.
    await wait(150);
    await click(128, 665);
    await shot('09-table-new-game');
    await click(640, 670);
    const afterTable = await shot('10-table-restart-fists');
    check(pixel(afterTable, 527, 486) !== '255,250,240', 'New game is also available after returning to the table from stalemate');
    await page.setViewportSize({ width: 390, height: 844 });
    await wait(400);
    await click(275, 804);
    await shot('11-portrait-history-list');
    await click(170, 264);
    await shot('12-portrait-archived-board');
    await click(195, 748, 400);
    const portraitPGN = await clipboard();
    check(portraitPGN.includes('[FEN "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"]') && portraitPGN.includes('1/2-1/2'), 'Portrait history opens and exports the selected stalemate exactly');
    await shot('13-portrait-export');
    await click(245, 690, 200);
    check((await page.evaluate(() => window.__reviewLinks)).includes('https://lichess.org/paste'), 'The optional Lichess action opens its official PGN import page');
    await page.keyboard.press('Escape');
    await wait(100);
    await click(335, 710);
    await shot('14-portrait-live-fists');
    check(errors.length === 0, 'History, replay and review have no browser script errors');
    console.log(`HISTORY BROWSER: ${checks}/${checks} checks passed`);
    console.log('REVIEW LINKS:', JSON.stringify(await page.evaluate(() => window.__reviewLinks)));
  } finally {
    fs.writeFileSync(path.join(output, 'console.log'), lines.join('\n') + '\n' + errors.join('\n'));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
