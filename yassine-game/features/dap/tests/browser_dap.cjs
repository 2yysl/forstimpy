// Actual mouse input and Web Audio observations; no hooks in the game build.
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
  await page.addInitScript(() => {
    window.__dapAudio = { starts: [], active: 0, maxActive: 0, contexts: [] };
    const start = AudioBufferSourceNode.prototype.start;
    const stop = AudioBufferSourceNode.prototype.stop;
    const finish = source => {
      if (source.__dapTracked) { source.__dapTracked = false; window.__dapAudio.active--; }
    };
    AudioBufferSourceNode.prototype.start = function (...args) {
      const buffer = this.buffer;
      if (buffer && [0.546, 0.418, 1.858].some(duration => Math.abs(buffer.duration - duration) < 0.02)) {
        const audio = window.__dapAudio;
        let peak = 0, energy = 0;
        const samples = buffer.getChannelData(0);
        for (let i = 0; i < samples.length; i += 32) { peak = Math.max(peak, Math.abs(samples[i])); energy += samples[i] * samples[i]; }
        audio.starts.push({ duration: buffer.duration, peak, energy });
        audio.contexts.push(this.context);
        this.__dapTracked = true;
        audio.active++;
        audio.maxActive = Math.max(audio.maxActive, audio.active);
        this.addEventListener('ended', () => finish(this), { once: true });
      }
      return start.apply(this, args);
    };
    AudioBufferSourceNode.prototype.stop = function (...args) {
      finish(this);
      return stop.apply(this, args);
    };
  });
  let checks = 0;
  const check = (value, message) => { assert.ok(value, message); checks++; console.log('PASS:', message); };
  const wait = ms => page.waitForTimeout(ms);
  const click = async (x, y, delay = 100) => { await page.mouse.click(x, y); if (delay) await wait(delay); };
  const audio = () => page.evaluate(() => ({ starts: window.__dapAudio.starts, active: window.__dapAudio.active, maxActive: window.__dapAudio.maxActive, running: window.__dapAudio.contexts.every(context => context.state === 'running') }));
  const shot = async name => PNG.sync.read(await page.screenshot({ path: path.join(output, name + '.png') }));
  const reactionDiff = (a, b) => {
    let changed = 0;
    for (let y = 270; y < 370; y++) for (let x = 950; x < 1230; x++) {
      const offset = (y * a.width + x) * 4;
      if (a.data[offset] !== b.data[offset] || a.data[offset + 1] !== b.data[offset + 1] || a.data[offset + 2] !== b.data[offset + 2]) changed++;
    }
    return changed;
  };
  try {
    await page.goto(process.argv[2]);
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await wait(1000);
    await click(640, 590, 2300);
    const initial = await shot('01-table');
    check((await audio()).starts.length === 0, 'The table starts without automatic dap audio');
    await click(935, 380);
    let sound = await audio();
    check(sound.starts.length === 1 && sound.running && sound.starts[0].peak > 0.0001, 'Selecting the hand plays a nonzero dap sample in a running audio context');
    check(reactionDiff(initial, await shot('02-first-dap')) > 100, 'The character displays a dap reaction');
    // These are real mouse press/release pairs, not calls into game internals.
    for (let i = 0; i < 200; i++) await click(935, 380, 0);
    await wait(100);
    sound = await audio();
    // Inputs sharing an engine frame deliberately start just the latest sound.
    check(sound.starts.length > 10 && sound.starts.length <= 201, 'Rapid clicks continuously retrigger sound without a cooldown');
    check(sound.maxActive === 1, 'Rapid clicking never stacks more than one dap voice');
    const clips = new Set(sound.starts.map(entry => `${entry.duration.toFixed(3)}:${entry.energy.toFixed(3)}`));
    check(clips.size === 4, 'Random play reaches all four distinct existing WAV samples');
    check(sound.starts.every(entry => entry.peak > 0.0001), 'Every observed dap clip contains nonzero audio');
    await shot('03-spam-reaction');
    await wait(1100);
    const before = sound.starts.length;
    await click(935, 380);
    await wait(1000);
    check((await audio()).starts.length === before + 1 && reactionDiff(initial, await shot('04-renewed-feedback')) > 100, 'A new click renews feedback instead of an old timeout clearing it');
    await wait(1200);
    check((await audio()).active === 0 && reactionDiff(initial, await shot('05-idle-again')) === 0, 'Sound and comment finish after the latest dap');
    await click(935, 380, 0);
    await page.mouse.move(270, 425);
    await wait(50);
    await click(270, 365);
    sound = await audio();
    check(sound.active === 0, 'Opening the full note cancels the current dap');
    const whileReading = sound.starts.length;
    await click(935, 380);
    check((await audio()).starts.length === whileReading, 'The note reader blocks dap input underneath');
    await page.keyboard.press('Escape');
    await wait(150);
    await click(935, 380);
    check((await audio()).starts.length === whileReading + 1, 'Dap works immediately after closing the note');
    await click(430, 670);
    check((await audio()).active === 0, 'Entering chess cancels dap playback');
    const duringChess = (await audio()).starts.length;
    await click(935, 380);
    check((await audio()).starts.length === duringChess, 'The hidden table hand cannot trigger during fist selection');
    await page.keyboard.press('Escape');
    await wait(150);
    await page.setViewportSize({ width: 390, height: 844 });
    await wait(400);
    const scale = 390 / 1280, top = (844 - 720 * scale) / 2;
    for (let i = 0; i < 20; i++) await click(935 * scale, top + 380 * scale, 20);
    await wait(100);
    sound = await audio();
    check(sound.starts.length > duringChess && sound.maxActive === 1, 'The scaled portrait hand supports repeated daps with bounded audio');
    await shot('06-portrait-dap');
    check(errors.length === 0, 'No browser console errors or script exceptions');
    console.log('DAP BROWSER:', checks + '/' + checks, 'checks passed');
    console.log('DAP WEB AUDIO:', JSON.stringify({ starts: sound.starts.length, maxActive: sound.maxActive, distinctClips: [...clips] }));
  } finally {
    fs.writeFileSync(path.join(output, 'console.log'), consoleLines.join('\n') + '\n' + errors.join('\n'));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
