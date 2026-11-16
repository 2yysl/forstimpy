// Uses real canvas input. Run against build_web.py's locally served export.
// Dependencies outside the game: playwright-core and pngjs.
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
  const consoleLines = [], errors = [];
  page.on('console', message => {
    consoleLines.push(`${message.type()}: ${message.text()}`);
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('pageerror', error => errors.push(error.message));
  let checks = 0, humanColour = 1;
  const check = (condition, description) => {
    assert.ok(condition, description);
    checks++;
    console.log('PASS:', description);
  };
  const shot = async name => PNG.sync.read(await page.screenshot({ path: path.join(output, `${name}.png`) }));
  const click = async (x, y, delay = 180) => { await page.mouse.click(x, y); await page.waitForTimeout(delay); };
  const pixel = (image, x, y) => {
    const offset = (Math.floor(y) * image.width + Math.floor(x)) * 4;
    return [...image.data.subarray(offset, offset + 3)].join();
  };
  const board = { x: 422, y: 252, size: 436 };
  const visual = (row, column) => humanColour === 1 ? [row, column] : [7 - row, 7 - column];
  const screenCenter = (row, column) => [board.x + (column + 0.5) * board.size / 8, board.y + (row + 0.5) * board.size / 8];
  const center = (row, column) => screenCenter(...visual(row, column));
  const clickSquare = async (row, column, delay = 180) => click(...center(row, column), delay);
  const occupied = (image, row, column) => {
    const [r, c] = visual(row, column);
    return pixel(image, ...center(row, column)) !== pixel(image, board.x + c * board.size / 8 + 4, board.y + r * board.size / 8 + 4);
  };
  const signature = image => Array.from({ length: 64 }, (_, n) => occupied(image, Math.floor(n / 8), n % 8)).join();
  const handPoint = hand => {
    const extent = Math.min((board.size - 16) / 2, 220, board.size - 38);
    return [board.x + hand * (extent + 16) + extent / 2, board.y + (board.size - extent - 38) / 2 + extent * 0.666];
  };
  const choose = async (hand, name) => {
    const before = await shot(`${name}-closed`);
    const point = handPoint(hand);
    await click(...point, 100);
    const reveal = await shot(`${name}-reveal`);
    const colour = pixel(reveal, ...point);
    check(colour === '255,242,204' || colour === '36,51,51', 'Chosen fist reveals a white or black queen');
    humanColour = colour === '255,242,204' ? 1 : -1;
    console.log(`BROWSER assigned ${humanColour === 1 ? 'White' : 'Black'} via ${hand === 0 ? 'left' : 'right'} fist`);
    check(pixel(before, ...handPoint(1 - hand)) === pixel(reveal, ...handPoint(1 - hand)), 'Unchosen fist stays closed');
    await click(...handPoint(1 - hand), 100);
    const locked = PNG.sync.read(await page.screenshot());
    check(pixel(locked, ...point) === colour, 'Clicking the other fist cannot change the revealed colour');
    await page.waitForTimeout(1550);
    const started = await shot(`${name}-board`);
    const nearKing = screenCenter(7, humanColour === 1 ? 4 : 3);
    check(pixel(started, ...nearKing) === colour, 'Board automatically orients to the revealed colour');
    return started;
  };
  const humanMove = async (delay = 1200) => {
    const from = humanColour === 1 ? [6, 4] : [1, 2];
    const to = humanColour === 1 ? [4, 4] : [2, 2];
    await clickSquare(...from);
    await clickSquare(...to, delay);
    return { from, to };
  };
  try {
    await page.goto(process.argv[2] || 'http://127.0.0.1:8765/');
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await page.waitForTimeout(1000);
    await shot('01-title');
    await click(640, 590, 2300);
    const invitation = await shot('02-invitation');
    check(pixel(invitation, 645, 670) === '187,128,94', 'Invitation retains the two affirmative choices');
    await click(430, 670, 400);
    const closed = await shot('03-fists');
    check(pixel(closed, 527, 486) !== '255,250,240' && pixel(closed, 753, 486) !== '255,250,240', 'Sure enters two closed fist placeholders');
    // Removed top-strip controls cannot bypass the colour choice.
    await click(116, 110);
    await click(254, 76);
    check(pixel(PNG.sync.read(await page.screenshot()), 527, 486) === pixel(closed, 527, 486), 'Former colour/restart locations cannot bypass the fists');
    let initial = await choose(0, '04-left');
    check(humanColour === 1 ? occupied(initial, 6, 4) && !occupied(initial, 4, 4) : occupied(initial, 4, 4) && !occupied(initial, 6, 4), 'White moves first, including the character when player draws Black');
    const from = humanColour === 1 ? [6, 4] : [1, 2];
    const to = humanColour === 1 ? [4, 4] : [2, 2];
    const illegalTo = humanColour === 1 ? [3, 4] : [4, 2];
    await clickSquare(...from);
    check(occupied(await shot('05-selected'), ...to), 'Assigned player can select a pawn and see a legal destination');
    await clickSquare(...illegalTo);
    check(occupied(await shot('06-illegal'), ...from), 'Illegal pawn move is rejected');
    await humanMove();
    let current = await shot('07-first-reply');
    check(!occupied(current, ...from) && occupied(current, ...to), 'Player can make a legal move in the assigned colour');
    const botFrom = humanColour === 1 ? [1, 2] : [6, 3];
    const botTo = humanColour === 1 ? [2, 2] : [4, 3];
    check(!occupied(current, ...botFrom) && occupied(current, ...botTo), 'Character follows the appropriate opening as the opposite colour');
    const liveSignature = signature(current);
    await click(968, 674);
    current = await shot('08-undo-preview');
    check(occupied(current, ...botFrom) && !occupied(current, ...botTo), 'Undo still previews the previous character move');
    await clickSquare(humanColour === 1 ? 6 : 1, 5);
    await clickSquare(humanColour === 1 ? 4 : 3, 5);
    await click(968, 674);
    check(signature(await shot('09-live')) === liveSignature, 'Preview input cannot change the match');
    await click(1075, 674);
    current = await shot('10-rps');
    check(pixel(current, 10, 400) !== '255,250,240' && pixel(current, 425, 600) !== '255,250,240', 'Takeback opens a compact modal RPS challenge');
    await clickSquare(humanColour === 1 ? 6 : 1, 5);
    await clickSquare(humanColour === 1 ? 4 : 3, 5);
    await click(495, 327);
    await shot('11-rps-result');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(200);
    current = await shot('12-after-rps');
    check(occupied(current, humanColour === 1 ? 6 : 1, 5) && !occupied(current, humanColour === 1 ? 4 : 3, 5), 'RPS blocks underlying chess input');
    check(occupied(current, ...from) !== occupied(current, ...to), 'RPS returns a restored or unchanged valid turn');
    await click(1190, 674);
    const resigned = signature(await shot('13-resigned'));
    await humanMove(300);
    check(signature(PNG.sync.read(await page.screenshot())) === resigned, 'Resign blocks further moves');
    // Back now resumes the same session, including a resigned game.
    await click(128, 665, 300);
    await click(430, 670, 300);
    check(signature(await shot('14-resumed-resignation')) === resigned, 'Back and return retain the resigned board and assigned colour');
    await humanMove(200);
    check(signature(PNG.sync.read(await page.screenshot())) === resigned, 'A resumed resigned match still rejects moves');
    // Reload the entire app for an independent fresh-session fixture.
    await page.reload();
    await page.waitForSelector('#status', { state: 'detached', timeout: 30000 });
    await page.waitForTimeout(1000);
    await click(640, 590, 2300);
    await click(430, 670, 300);
    await choose(1, '15-right-fresh-session');
    await humanMove(20);
    await click(128, 665, 100);
    await page.waitForTimeout(600);
    await click(430, 670, 1200);
    const fresh = await shot('16-resumed-pending-reply');
    const retainedFrom = humanColour === 1 ? [6, 4] : [1, 2];
    const retainedTo = humanColour === 1 ? [4, 4] : [2, 2];
    check(!occupied(fresh, ...retainedFrom) && occupied(fresh, ...retainedTo), 'Leaving pending AI work retains the player move and resumes the reply');
    const resumedSignature = signature(fresh);
    await click(128, 665, 200);
    await click(860, 670, 2500);
    initial = await shot('17-joke-resumes');
    check(signature(initial) === resumedSignature, 'The joke invitation also resumes the saved match without another fist choice');
    const deviationFrom = humanColour === 1 ? [6, 7] : [1, 0];
    const deviationTo = humanColour === 1 ? [4, 7] : [2, 0];
    await clickSquare(...deviationFrom);
    const started = Date.now();
    await clickSquare(...deviationTo, 1000);
    let replied = false;
    while (Date.now() - started < 12000) {
      current = PNG.sync.read(await page.screenshot());
      for (let n = 0; n < 64; n++) {
        const square = [Math.floor(n / 8), n % 8];
        if ([deviationFrom.join(), deviationTo.join()].includes(square.join())) continue;
        if (occupied(current, ...square) !== occupied(initial, ...square)) replied = true;
      }
      if (replied) break;
      await page.waitForTimeout(400);
    }
    console.log('BROWSER FALLBACK completion observed after', Date.now() - started, 'ms');
    check(replied, 'Character continues after an unsupported opening in the assigned colour');
    await shot('18-fallback');
    const beforePortrait = signature(current);
    await click(128, 665, 200);
    await click(430, 670, 300);
    await page.setViewportSize({ width: 390, height: 844 });
    Object.assign(board, { x: 49, y: 326, size: 292 });
    await page.waitForTimeout(500);
    current = await shot('19-portrait-resumed');
    check(signature(current) === beforePortrait, 'Portrait resizing and re-entry preserve the same saved board');
    check(pixel(current, 335, 332) === '112,147,145', 'Portrait board fits between both captured-piece areas');
    check(pixel(current, 26, 268) !== '255,250,240' && pixel(current, 26, 644) !== '255,250,240', 'Portrait has capture areas at the character and player edges');
    check(pixel(current, 18, 730) !== '255,250,240', 'Portrait inventory remains visible');
    await click(195, 748, 300);
    current = await shot('20-portrait-rps');
    check(pixel(current, 10, 400) !== '255,250,240' && pixel(current, 20, 650) !== '255,250,240', 'Portrait RPS still opens and fits the screen');
    check(errors.length === 0, 'No browser console errors or script exceptions');
    console.log(`BROWSER: ${checks}/${checks} checks passed; Chromium ${await browser.version()}`);
  } finally {
    fs.writeFileSync(path.join(output, 'console.log'), consoleLines.join('\n') + '\n' + errors.join('\n'));
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
