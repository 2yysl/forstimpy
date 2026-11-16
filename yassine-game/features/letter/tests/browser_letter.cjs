// Real-input letter checks. Dependencies: playwright-core and pngjs, outside the game.
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
  const errors = [], consoleLines = [];
  page.on('console', message => { consoleLines.push(`${message.type()}: ${message.text()}`); if (message.type() === 'error') errors.push(message.text()); });
  page.on('pageerror', error => errors.push(error.message));
  // Observe the actual Web Audio sample, without adding test hooks to the game.
  await page.addInitScript(() => {
    window.__letterAudioStarts = [];
    const start = AudioBufferSourceNode.prototype.start;
    AudioBufferSourceNode.prototype.start = function (...args) {
      const buffer = this.buffer;
      if (buffer && Math.abs(buffer.duration - 1.434) < 0.02) {
        let peak = 0;
        const samples = buffer.getChannelData(0);
        for (let i = 0; i < samples.length; i += 32) peak = Math.max(peak, Math.abs(samples[i]));
        window.__letterAudioContext = this.context;
        window.__letterAudioStarts.push({ duration: buffer.duration, peak });
      }
      return start.apply(this, args);
    };
  });
  let checks = 0;
  const check = (value, message) => { assert.ok(value, message); checks++; console.log('PASS:', message); };
  const wait = ms => page.waitForTimeout(ms);
  const move = async (x, y, delay = 120) => { await page.mouse.move(x, y); await wait(delay); };
  const click = async (x, y, delay = 150) => { await page.mouse.click(x, y); await wait(delay); };
  const shot = async name => PNG.sync.read(await page.screenshot({ path: path.join(output, name + '.png') }));
  const pixel = (image, x, y) => [...image.data.subarray((Math.floor(y) * image.width + Math.floor(x)) * 4, (Math.floor(y) * image.width + Math.floor(x)) * 4 + 3)].join();
  const audioCount = () => page.evaluate(() => window.__letterAudioStarts.length);
  const PAPER = '255,250,240';
  try {
    await page.goto(process.argv[2]);
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await wait(1000);
    await click(640, 590, 2300);
    await click(56, 306); // Select the third table location before reading.
    await move(160, 360);
    const initial = await shot('01-table-closed');
    check(pixel(initial, 250, 360) !== PAPER && await audioCount() === 0, 'Table starts with a closed, silent letter');
    await move(270, 365);
    await click(270, 365);
    check(await audioCount() === 0 && pixel(await shot('02-hidden-note'), 250, 360) !== PAPER, 'Invisible note area cannot open the letter or reader');
    await move(270, 425);
    let current = await shot('03-hover-open');
    check(pixel(current, 250, 360) === PAPER, 'Hover opens the envelope and exposes paper');
    check(await audioCount() === 1, 'First hover starts exactly one paper sample');
    const audio = await page.evaluate(() => ({ state: window.__letterAudioContext?.state, starts: window.__letterAudioStarts }));
    check(audio.state === 'running' && audio.starts[0].peak > 0.0001, 'Existing WAV reaches a running Web Audio context with nonzero samples');
    await wait(350);
    check(await audioCount() === 1, 'Holding the cursor does not loop the sound');
    await move(270, 365);
    check(pixel(await shot('04-note-hover'), 250, 360) === PAPER && await audioCount() === 1, 'Moving from envelope onto note keeps it open without retriggering');
    await move(250, 425);
    check(await audioCount() === 1, 'Moving back onto the envelope remains one continuous hover');
    await move(160, 360);
    check(pixel(await shot('05-mouse-out'), 250, 360) !== PAPER && await audioCount() === 1, 'Leaving closes the envelope without starting another clip');
    for (let i = 0; i < 3; i++) { await move(270, 425, 60); await move(160, 360, 60); }
    check(await audioCount() === 4, 'Every fresh rapid hover starts the paper sample once');
    await move(270, 425);
    await move(270, 365);
    const beforeRead = await audioCount();
    await click(270, 365);
    current = await shot('06-full-note');
    check(pixel(current, 10, 400) !== pixel(initial, 10, 400) && pixel(current, 240, 40) === PAPER, 'Selecting the protruding note opens a full-screen modal reader');
    check(await audioCount() === beforeRead, 'Reading does not add another paper sound');
    await click(56, 196); // Underlying location button, outside the paper.
    await click(935, 380); // Underlying dap button, behind the paper.
    await click(600, 500); // Underlying chess hotspot.
    check(pixel(await shot('07-blocked-input'), 240, 40) === PAPER, 'Reader blocks table controls and chess underneath');
    await move(650, 350);
    await page.mouse.wheel(0, 5000);
    await wait(200);
    const end = await shot('08-note-end');
    check(pixel(end, 250, 100) !== pixel(current, 250, 100) || !end.data.equals(current.data), 'Full note can scroll to its ending');
    await click(640, 658);
    current = await shot('09-back');
    check(pixel(current, 10, 400) === pixel(initial, 10, 400), 'Back returns to the same unshaded table');
    check(pixel(current, 1030, 160) === pixel(initial, 1030, 160), 'Previously selected table location is preserved');
    check(await audioCount() === beforeRead, 'Back adds no phantom hover sound');
    await move(270, 425);
    await click(270, 365);
    const beforeEscape = await audioCount();
    await page.keyboard.press('Escape');
    await wait(180);
    current = await shot('10-escape-under-pointer');
    check(pixel(current, 250, 360) === PAPER && pixel(current, 10, 400) === pixel(initial, 10, 400), 'Escape returns to an open letter when cursor is still over its note');
    check(await audioCount() === beforeEscape, 'Returning beneath the cursor does not replay paper audio');
    await move(160, 360);
    await move(270, 425);
    check(await audioCount() === beforeEscape + 1, 'Another real hover after returning plays again');
    await move(160, 360);
    await page.setViewportSize({ width: 390, height: 844 });
    await wait(500);
    const scale = 390 / 1280, top = (844 - 720 * scale) / 2;
    const tablePoint = (x, y) => [x * scale, top + y * scale];
    await move(...tablePoint(270, 425));
    const portraitCount = await audioCount();
    await shot('11-portrait-open');
    await click(...tablePoint(270, 365));
    current = await shot('12-portrait-note');
    check(current.width === 390 && pixel(current, 20, 100) === PAPER, 'Portrait note reader fills the physical viewport with readable paper');
    await move(190, 350);
    await page.mouse.wheel(0, 5000);
    await wait(200);
    await shot('13-portrait-note-end');
    await click(195, 734);
    await shot('14-portrait-back');
    check(await audioCount() === portraitCount, 'Portrait Back closes the reader without replaying audio');
    await page.setViewportSize({ width: 1280, height: 720 });
    await wait(400);
    await click(430, 670, 300);
    current = await shot('15-chess-fists');
    check(pixel(current, 527, 486) !== PAPER && pixel(current, 753, 486) !== PAPER, 'Chess still enters both closed fists after letter reading');
    check(errors.length === 0, 'No browser console errors or script exceptions');
    console.log('LETTER BROWSER:', checks + '/' + checks, 'checks passed');
    console.log('WEB AUDIO:', JSON.stringify(await page.evaluate(() => window.__letterAudioStarts)));
  } finally {
    fs.writeFileSync(path.join(output, 'console.log'), consoleLines.join('\n') + '\n' + errors.join('\n'));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
