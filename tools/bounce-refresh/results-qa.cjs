const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'artifacts/bounce-results-20260930',process.argv.includes('--before')?'before':'after');fs.mkdirSync(out,{recursive:true});
const folders={math:'C:/Projects/minikMath/app/src/main/assets/www',bounce:'C:/Projects/MinikPaddleAndLearn/app/src/main/assets/www',ios:path.join(root,'Resources/RetroPong')};
const server=http.createServer((req,res)=>{const parts=decodeURIComponent(new URL(req.url,'http://localhost').pathname).split('/').filter(Boolean),dir=folders[parts.shift()];if(!dir)return res.writeHead(404).end();const file=path.resolve(dir,parts.join('/'));if(!file.startsWith(path.resolve(dir)+path.sep))return res.writeHead(403).end();fs.readFile(file,(e,b)=>{if(e)return res.writeHead(404).end();res.writeHead(200,{'Content-Type':({'.html':'text/html; charset=utf-8','.js':'application/javascript','.css':'text/css','.webp':'image/webp','.png':'image/png','.mp3':'audio/mpeg'})[path.extname(file)]||'application/octet-stream'}).end(b);});});
(async()=>{const results=[];await new Promise(r=>server.listen(0,'127.0.0.1',r));const base=`http://127.0.0.1:${server.address().port}`;const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
try{for(const app of Object.keys(folders))for(const lang of ['en','he'])for(const [width,height] of [[640,320],[740,340],[960,432]]){
 const ctx=await browser.newContext({viewport:{width,height},locale:lang==='he'?'he-IL':'en-US',isMobile:true,hasTouch:true,deviceScaleFactor:2,userAgent:`MinikNative/${app==='ios'?'iOS':'Android'} MinikNativeInsets/1 MinikNativeImmersive/1`});
 await ctx.addInitScript(({app,lang})=>{if(app==='ios'){window.__minikRetroConfig={language:lang,canExit:false};window.webkit={messageHandlers:{retroPong:{postMessage(){}}}};}else window.MinikAdsNative={playing(){},prepare(){},settings(){},finish(_,token){window.MinikMonetization.complete(token);}};},{app,lang});
 const page=await ctx.newPage();page.setDefaultTimeout(5000);const errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  await page.goto(`${base}/${app}/${app==='math'?'pingpong/':''}index.html?lang=${lang}${app==='math'?'&from=math':''}`);await page.waitForFunction(()=>typeof pong!=='undefined'&&pong);await page.waitForLoadState('networkidle');
  assert.equal(await page.locator('html').getAttribute('lang'),lang);
  for(const outcome of ['lose','win']){
   const name=`${app}-${lang}-${width}x${height}-${outcome}`;
   await page.evaluate(outcome=>{pong.waitingForStart=false;pong.startCountdownUntil=0;pong.over=false;pong.pendingMatchEnd=true;pong.pointPauseUntil=performance.now()+1;pong.userScore=outcome==='win'?pongTargetScore:0;pong.aiScore=outcome==='lose'?pongTargetScore:0;document.body.classList.remove('pong-waiting');finishPongPointPause();},outcome);
   await page.waitForFunction(()=>pong.over&&!pong.resultsPending);await page.waitForTimeout(150);
   const measurements=await page.locator('.pong-header-message:visible,.pong-landscape-message:visible').evaluateAll(els=>els.map(el=>{const r=document.createRange();r.selectNodeContents(el);return {text:el.textContent,box:el.getBoundingClientRect().toJSON(),lines:Array.from(r.getClientRects(),x=>x.toJSON()),scrollHeight:el.scrollHeight,clientHeight:el.clientHeight};}));
   const outside=measurements.some(m=>m.lines.some(l=>l.left<m.box.left-1||l.right>m.box.right+1||l.top<m.box.top-1||l.bottom>m.box.bottom+1)||m.box.left<0||m.box.right>width);
   const passed=measurements.length===1&&!outside&&errors.length===0;
   await page.screenshot({path:path.join(out,name+'.png')});results.push({name,passed,measurements,errors});console.log(`${passed?'PASS':'FAIL'} ${name}`);
  }
 }finally{await ctx.close();}
}}finally{await browser.close();await new Promise(r=>server.close(r));fs.writeFileSync(path.join(out,'results.json'),JSON.stringify(results,null,2));}
console.log(JSON.stringify({passed:results.filter(r=>r.passed).length,failed:results.filter(r=>!r.passed).length}));if(results.some(r=>!r.passed))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;server.close();});
