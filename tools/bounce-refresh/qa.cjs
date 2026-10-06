const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const sharp=require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'artifacts/bounce-refresh-20260930/android'),out=path.join(root,'artifacts/bounce-refresh-20260930/qa');fs.mkdirSync(out,{recursive:true});
const folders={android:'C:/Projects/MinikPaddleAndLearn/app/src/main/assets/www',ios:path.join(root,'Resources/RetroPong'),store:path.join(stage,'play-store/current')};
const results=[];
const server=http.createServer((req,res)=>{const parts=decodeURIComponent(new URL(req.url,'http://localhost').pathname).split('/').filter(Boolean),dir=folders[parts.shift()];if(!dir){res.writeHead(404).end();return;}const file=path.resolve(dir,parts.join('/')||'index.html');if(!file.startsWith(path.resolve(dir)+path.sep)){res.writeHead(403).end();return;}fs.readFile(file,(e,b)=>{if(e){res.writeHead(404).end();return;}res.writeHead(200,{'Content-Type':({'.html':'text/html; charset=utf-8','.js':'application/javascript','.css':'text/css','.webp':'image/webp','.png':'image/png','.mp3':'audio/mpeg','.ttf':'font/ttf'})[path.extname(file)]||'application/octet-stream'}).end(b);});});
async function writePng(bytes,file){fs.mkdirSync(path.dirname(file),{recursive:true});await sharp(bytes).flatten({background:'#1b0d38'}).removeAlpha().png().toFile(file);}
async function run(){await new Promise(r=>server.listen(0,'127.0.0.1',r));const base=`http://127.0.0.1:${server.address().port}`;const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
try{
 // Android's native activity is landscape-only; iOS also supports portrait hosting.
 for(const platform of ['android','ios'])for(const lang of ['en','he'])for(const [width,height] of (platform==='android'?[[960,432],[740,340]]:[[960,432],[740,340],[390,844],[768,1024]])){
  const name=`${platform}-${lang}-${width}x${height}`,errors=[],failed=[];
  const ctx=await browser.newContext({viewport:{width,height},locale:lang==='he'?'he-IL':'en-US',isMobile:true,hasTouch:true,deviceScaleFactor:2,userAgent:`Mozilla/5.0 (${platform==='ios'?'iPhone':'Linux; Android 14'}) AppleWebKit/537.36 Chrome/140 Mobile Safari/537.36 MinikNative/${platform==='ios'?'iOS':'Android'} MinikNativeInsets/1 MinikNativeImmersive/1`});
  await ctx.addInitScript(({platform,lang})=>{
   window.__hostMessages=[];
   if(platform==='ios'){window.__minikRetroConfig={language:lang,paused:false,canExit:false};window.webkit={messageHandlers:{retroPong:{postMessage:m=>window.__hostMessages.push(m)}}};}
   else window.MinikAdsNative={playing(){},prepare(){},settings(){},finish(_,token){window.MinikMonetization.complete(token);}};
  },{platform,lang});
  const page=await ctx.newPage();page.setDefaultTimeout(6000);page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)failed.push(r.url());});
  try{
   await page.goto(`${base}/${platform}/index.html?lang=${lang}`);await page.waitForFunction(()=>window.PongExtras&&document.querySelector('.pong-setup-logo')?.complete);await page.waitForLoadState('networkidle');
   assert.deepEqual(errors,[]);assert.deepEqual(failed,[]);
   assert.match(await page.locator('.pong-setup-logo').getAttribute('src'),/bounce-mark/);assert.match(await page.locator('.pong-landscape-art').getAttribute('src'),/bounce-logo/);
   assert.equal(await page.locator('html').getAttribute('lang'),lang);
   assert.ok(!(await page.locator('#app').innerText()).includes('MODERN'));
   const rects=await page.locator('.pong-setup-header,.pong-setup-body,.pong-setup-actions').evaluateAll(els=>els.map(el=>({cls:el.className,...el.getBoundingClientRect().toJSON()})));
   assert.ok(rects.every(r=>r.width>0&&r.height>0&&r.x>=-1&&r.right<=width+1&&r.y>=-1&&r.bottom<=height+1),JSON.stringify(rects));
   if(platform==='ios')assert.equal(await page.locator('.pong-setup-nav .pong-exit-btn').isVisible(),false);
   const setup=await page.screenshot();await writePng(setup,path.join(out,name+'-setup.png'));
   if(platform==='android'&&width===960)await writePng(setup,path.join(stage,`play-store/current/source/setup-${lang}.png`));
   await page.evaluate(()=>PongExtras.openSettings(false));await page.waitForSelector('#pongGuideOverlay');
   assert.match(await page.locator('.pong-guide-heading img').first().getAttribute('src'),/bounce-mark/);
   const help=await page.screenshot();await writePng(help,path.join(out,name+'-help.png'));
   if(platform==='android'&&width===960)await writePng(help,path.join(stage,`play-store/current/source/help-${lang}.png`));
   await page.locator('.pong-guide-close').click();await page.waitForSelector('#pongGuideOverlay',{state:'detached'});
   await page.locator('.pong-landscape-start').click();await page.waitForTimeout(3300);
   assert.equal(await page.evaluate(()=>pong.waitingForStart),false);
   await writePng(await page.screenshot(),path.join(out,name+'-play.png'));
   await page.locator('.back-btn:visible').first().click();await page.waitForFunction(()=>pong?.waitingForStart);
   assert.equal(await page.locator('.pong-landscape-start').isVisible(),true);
   if(platform==='ios'){await page.evaluate(()=>exitPong());assert.equal(await page.evaluate(()=>view),'pong');assert.equal(await page.locator('.pong-landscape-start').isVisible(),true);assert.equal(await page.evaluate(()=>__hostMessages.some(m=>m.type==='exit')),false);}
   assert.deepEqual(errors,[]);results.push({name,passed:true});console.log('PASS '+name);
  }catch(e){await page.screenshot({path:path.join(out,name+'-FAIL.png')}).catch(()=>{});results.push({name,passed:false,error:e.message,errors,failed});console.log('FAIL '+name+' '+e.message);}finally{await ctx.close();}
 }
 // A host-supplied return target is kept, even though standalone has no root Exit.
 for(const lang of ['en','he']){const ctx=await browser.newContext({viewport:{width:844,height:390},isMobile:true,hasTouch:true,userAgent:'MinikNative/iOS MinikNativeInsets/1'});await ctx.addInitScript(lang=>{window.__hostMessages=[];window.__minikRetroConfig={language:lang,canExit:true};window.webkit={messageHandlers:{retroPong:{postMessage:m=>__hostMessages.push(m)}}};},lang);const page=await ctx.newPage();await page.goto(base+'/ios/index.html');await page.locator('.pong-setup-nav .pong-exit-btn').click();assert.equal(await page.evaluate(()=>__hostMessages.filter(m=>m.type==='exit').length),1);assert.equal(await page.locator('.pong-exit-panel').count(),0);results.push({name:`embedded-${lang}-return-to-Math`,passed:true});await ctx.close();}
 // Store artwork: separate marketing frame around unchanged current app captures.
 const htmlDir=path.join(stage,'play-store/current/source');
 for(const lang of ['en','he']){
  const locale=lang==='he'?'he-IL':'en-US',he=lang==='he';
  const font=`@font-face{font-family:Heebo;src:url('./Heebo-Variable.ttf')}*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden}body{font-family:Heebo,Arial,sans-serif;color:white;background:#170c38}`;
  const feature=`<!doctype html><meta charset="utf-8"><style>${font}.bg{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}.shade{position:absolute;inset:0;background:linear-gradient(90deg,#160637e8,transparent 58%)}.brand{position:absolute;top:36px;left:44px;display:flex;align-items:center;gap:16px}.brand img{width:68px;height:68px;border-radius:17px}.brand b{font-size:25px;letter-spacing:3px;color:#86f5ff}.copy{position:absolute;top:128px;left:44px;width:375px}h1{font-size:${he?58:60}px;line-height:1.06;margin:0 0 30px;font-weight:900;letter-spacing:-1px}p{font-size:21px;margin:0;color:#eee4ff}</style><img class="bg" src="feature-background.png"><div class="shade"></div><div class="brand"><img src="../upload/common/app-icon-512.png"><b>MINIK</b></div><div class="copy" dir="${he?'rtl':'ltr'}"><h1>${he?'מקפצים<br>ולומדים':'BOUNCE<br>&amp; LEARN'}</h1><p>${he?'קופצים. חושבים. מחייכים.':'Bounce. Think. Smile.'}</p></div>`;
  fs.writeFileSync(path.join(htmlDir,`feature-${lang}.html`),feature);
  const page=await browser.newPage({viewport:{width:1024,height:500}});await page.goto(`${base}/store/source/feature-${lang}.html`);await page.evaluate(()=>document.fonts.ready);await writePng(await page.screenshot(),path.join(stage,`play-store/current/upload/${locale}/feature-graphic-1024x500.png`));await page.close();
  for(const [number,kind,title,sub]of [[3,'help',he?'הצבע שלכם. ההתקדמות שלכם.':'Your colors. Your progress.',he?'מחבט, חיצים ואתגר שגדלים איתכם.':'Paddles, arrows and a challenge that grows.'],[4,'setup',he?'מוכנים לקפיצה הבאה?':'Ready for the next bounce?',he?'בוחרים רמה, מתחילים לשחק.':'Pick your challenge. Press Start.']]){
   const html=`<!doctype html><meta charset="utf-8"><style>${font}body{background:radial-gradient(at top right,#4d217d,#110827 74%)}.mark{position:absolute;top:58px;left:70px;width:94px;height:94px;border-radius:23px}.copy{position:absolute;top:58px;left:206px;right:70px;text-align:${he?'right':'left'}}h1{font-size:68px;line-height:1.15;margin:0 0 16px}p{font-size:32px;color:#d7d0ef;margin:0}.capture{position:absolute;top:252px;left:70px;width:1780px;height:756px;display:flex;align-items:center;justify-content:center;border:2px solid #8068a0;border-radius:28px;background:#170d32;overflow:hidden}.capture img{width:100%;height:100%;object-fit:contain}</style><img class="mark" src="../upload/common/app-icon-512.png"><div class="copy" dir="${he?'rtl':'ltr'}"><h1>${title}</h1><p>${sub}</p></div><div class="capture"><img src="${kind}-${lang}.png"></div>`;
   fs.writeFileSync(path.join(htmlDir,`${kind}-frame-${lang}.html`),html);
   const page=await browser.newPage({viewport:{width:1920,height:1080}});await page.goto(`${base}/store/source/${kind}-frame-${lang}.html`);await page.evaluate(()=>document.fonts.ready);await writePng(await page.screenshot(),path.join(stage,`play-store/current/upload/${locale}/phone/0${number}-${kind==='help'?'colors':'setup'}-1920x1080.png`));await page.close();
  }
 }
}finally{await browser.close();await new Promise(r=>server.close(r));fs.writeFileSync(path.join(out,'results.json'),JSON.stringify(results,null,2));}
console.log(JSON.stringify({passed:results.filter(x=>x.passed).length,failed:results.filter(x=>!x.passed).length}));if(results.some(x=>!x.passed))process.exitCode=1;
}run().catch(e=>{console.error(e);process.exitCode=1;server.close();});
