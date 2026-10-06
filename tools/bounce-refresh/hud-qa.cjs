const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'artifacts/hud-refinement-20260930/qa');fs.mkdirSync(out,{recursive:true});
const folders={math:'C:/Projects/minikMath/app/src/main/assets/www',bounce:'C:/Projects/MinikPaddleAndLearn/app/src/main/assets/www',ios:path.join(root,'Resources/RetroPong')};
const server=http.createServer((req,res)=>{const parts=decodeURIComponent(new URL(req.url,'http://localhost').pathname).split('/').filter(Boolean),dir=folders[parts.shift()];if(!dir)return res.writeHead(404).end();const file=path.resolve(dir,parts.join('/'));if(!file.startsWith(path.resolve(dir)+path.sep))return res.writeHead(403).end();fs.readFile(file,(e,b)=>{if(e)return res.writeHead(404).end();res.writeHead(200,{'Content-Type':({'.html':'text/html; charset=utf-8','.js':'application/javascript','.css':'text/css','.webp':'image/webp','.png':'image/png','.mp3':'audio/mpeg'})[path.extname(file)]||'application/octet-stream'}).end(b);});});
async function measurements(page){return page.evaluate(()=>{
 const rect=el=>el.getBoundingClientRect().toJSON(),q=s=>document.querySelector(s);
 const total=q('.pong-mini-total'),back=q('.pong-infield-back .back-btn');
 return {total:rect(total),label:rect(total.querySelector('small')),value:rect(total.querySelector('b')),score:rect(q('.pong-mini-score')),help:rect(q('.pong-infield-help')),back:rect(back),arrow:rect(back.querySelector('img')),players:[...q('.pong-mini-score').querySelectorAll('span:not(:nth-child(2))')].map(el=>({label:rect(el.querySelector('small')),value:rect(el.querySelector('b'))})),errors:window.__errors||[]};
});}
(async()=>{const results=[];await new Promise(r=>server.listen(0,'127.0.0.1',r));const base=`http://127.0.0.1:${server.address().port}`;const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
try{
 for(const app of (process.argv.includes('--math-captures')?['math']:Object.keys(folders)))for(const lang of ['en','he'])for(const [width,height]of (process.argv.includes('--math-captures')?[[960,432]]:[[640,320],[740,340],[960,432]])){
  const name=`${app}-${lang}-${width}x${height}`,ctx=await browser.newContext({viewport:{width,height},locale:lang==='he'?'he-IL':'en-US',isMobile:true,hasTouch:true,deviceScaleFactor:2,userAgent:`MinikNative/${app==='ios'?'iOS':'Android'} MinikNativeInsets/1 MinikNativeImmersive/1`});
  await ctx.addInitScript(({app,lang})=>{window.__errors=[];window.addEventListener('error',e=>__errors.push(e.message));let seed=3180926;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};if(app==='ios'){window.__minikRetroConfig={language:lang,canExit:false};window.webkit={messageHandlers:{retroPong:{postMessage(){}}}};}else window.MinikAdsNative={playing(){},prepare(){},settings(){},finish(_,token){window.MinikMonetization.complete(token);}};},{app,lang});
  const page=await ctx.newPage();page.setDefaultTimeout(6000);
  try{
   await page.goto(`${base}/${app}/${app==='math'?'pingpong/':''}index.html?lang=${lang}${app==='math'?'&from=math':''}`);await page.waitForFunction(()=>typeof pong!=='undefined'&&pong);await page.waitForLoadState('networkidle');
   assert.equal(await page.locator('html').getAttribute('lang'),lang);
   await page.evaluate(()=>{setPongTargetScore(11);setBalloonMadness(true);startPongLandscape();});await page.waitForTimeout(80);
   // Complete the real countdown through the engine; drive the paddle as an
   // automated player, never drawing replacement HUD or gameplay elements.
   await page.evaluate(()=>{cancelAnimationFrame(pongRAF);window.__simNow=performance.now();window.__advance=(seconds,scene=false)=>{for(let i=0;i<seconds*60;i++){__simNow+=1000/60;if(pong.pcVertical)pong.userY=Math.max(0,Math.min(pong.c.width-pong.paddleHeight,pong.ball.x-pong.paddleHeight/2));loopPong(__simNow);cancelAnimationFrame(pongRAF);if(scene===true&&PongExtras.snapshot().train?.progress>=.50)break;if(scene==='madness'){const visible=pong.madnessObjects.filter(o=>o.x-o.w/2>12&&o.x+o.w/2<pong.c.width-12&&o.y-o.h/2>30&&o.y+o.h/2<pong.c.height-30);if(visible.length>=4&&visible.some(o=>['beach','cotton','car'].includes(o.type)))break;}}};__advance(3.4);});
   const m=await measurements(page);assert.deepEqual(m.errors,[]);
   assert.ok(m.label.right<=m.value.left,'Total label must be physically left of value');
   for(const p of m.players)assert.ok(lang==='en'?p.label.right<=p.value.left:p.value.right<=p.label.left,'Player label/value ordering');
   assert.ok(lang==='en'?m.total.right<m.help.left&&m.help.right<m.score.left:m.total.right<m.help.left&&m.help.right<m.score.left,'Total — gear — match score physical order');
   assert.ok(Math.abs(m.arrow.y+m.arrow.height/2-(m.back.y+m.back.height/2))<.6,'Arrow/frame vertical centres');
   assert.ok(Math.abs(m.arrow.x+m.arrow.width/2-(m.back.x+m.back.width/2))<.6,'Arrow/frame horizontal centres');
   assert.ok(m.arrow.left>=m.back.left&&m.arrow.right<=m.back.right&&m.arrow.top>=m.back.top&&m.arrow.bottom<=m.back.bottom,'Arrow fits its frame');
   await page.screenshot({path:path.join(out,name+'.png')});results.push({name,passed:true,measurements:m});console.log('PASS '+name);
   if(app==='math'&&width===960){
    await page.evaluate(()=>__advance(40,true));await page.waitForFunction(()=>[...document.querySelectorAll('.question-train img')].every(i=>i.complete));
    await page.screenshot({path:path.join(out,`math-${lang}-05-train.png`)});
    fs.writeFileSync(path.join(out,`math-${lang}-05-train-state.json`),JSON.stringify(await page.evaluate(()=>({extras:PongExtras.snapshot(),score:{you:pong.userScore,minik:pong.aiScore}})),null,2));
    await page.evaluate(()=>{PongExtras.setTrainMode('off');setPongDifficulty('hard');resetPong();});await page.waitForTimeout(80);
    await page.evaluate(()=>{cancelAnimationFrame(pongRAF);__simNow=performance.now();__advance(70,'madness');});await page.waitForTimeout(80);
    assert.equal(await page.evaluate(()=>pong.over),false,'Balloon capture must show a live round');
    await page.screenshot({path:path.join(out,`math-${lang}-06-balloon-madness.png`)});
    fs.writeFileSync(path.join(out,`math-${lang}-06-balloon-madness-state.json`),JSON.stringify(await page.evaluate(()=>({extras:PongExtras.snapshot(),objects:pong.madnessObjects.map(o=>({type:o.type,x:o.x,y:o.y})),score:{you:pong.userScore,minik:pong.aiScore}})),null,2));
   }
  }catch(e){results.push({name,passed:false,error:e.message});await page.screenshot({path:path.join(out,name+'-FAIL.png')}).catch(()=>{});console.log('FAIL '+name+' '+e.message);}finally{await ctx.close();}
 }
}finally{await browser.close();await new Promise(r=>server.close(r));fs.writeFileSync(path.join(out,'results.json'),JSON.stringify(results,null,2));}
console.log(JSON.stringify({passed:results.filter(r=>r.passed).length,failed:results.filter(r=>!r.passed).length}));if(results.some(r=>!r.passed))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;server.close();});
