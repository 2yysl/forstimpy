// Run the BotBrowserChecks.tscn release export in an actual browser.
const { chromium } = require('playwright-core');
const assert = require('node:assert/strict');
(async () => {
 const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless:true, args:['--no-sandbox','--enable-webgl','--enable-unsafe-swiftshader']});
 const page = await browser.newPage({viewport:{width:1280,height:720}});
 const errors=[];
 page.on('pageerror', e=>errors.push(e.message));
 page.on('console', m=>{if(m.type()==='error')errors.push(m.text());});
 try {
  await page.goto(process.argv[2]);
  await page.waitForFunction(()=>window.yyslChessVerification !== undefined, null, {timeout:120000});
  const result = await page.evaluate(()=>window.yyslChessVerification);
  console.log(JSON.stringify(result,null,2));
  assert.equal(result.failures,0,'Browser bot checks must pass');
  assert.deepEqual(errors,[],'No browser errors');
  console.log('BROWSER BOT:',result.checks+'/'+result.checks,'checks passed');
 } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1);});
