
'use strict';
const fs=require('node:fs'), path=require('node:path'), vm=require('node:vm'), assert=require('node:assert/strict'), crypto=require('node:crypto');
const root=path.resolve(process.argv[2] || path.join(__dirname,'../..'));
const web=path.join(root,'Resources/RetroPong');
const appSource=fs.readFileSync(path.join(web,'app.js'),'utf8');
const extrasSource=fs.readFileSync(path.join(web,'pong-extras.js'),'utf8');
let passed=0;
function test(name,fn){try{fn();passed++;console.log('PASS '+name);}catch(e){console.error('FAIL '+name);throw e;}}
class Element {
  constructor(tag='div'){this.tagName=tag;this.children=[];this.dataset={};this.style={setProperty(){}};this.events={};this.attributes={};this.className='';this.isConnected=true;this.textContent='';this.width=1000;this.height=400;
    this.classList={add:(...xs)=>{this.className=[...new Set([...this.className.split(' '),...xs])].join(' ');},remove:(...xs)=>{this.className=this.className.split(' ').filter(x=>!xs.includes(x)).join(' ');},contains:x=>this.className.split(' ').includes(x),toggle:(x,on)=>{if(on===undefined)on=!this.classList.contains(x);this.classList[on?'add':'remove'](x);return on;}};
  }
  set innerHTML(s){this.html=s;this.children=[];for(const cls of ['train-sprite','train-label','train-smoke'])if(s.includes('class="'+cls+'"')){const e=new Element(cls==='train-label'?'span':'img');e.className=cls;if(cls==='train-label')e.textContent=(s.match(/class="train-label"[^>]*>([^<]*)</)||[])[1]||'';this.appendChild(e);}}
  get innerHTML(){return this.html||'';}
  appendChild(e){this.children.push(e);return e;}
  replaceChildren(...e){this.children=e;}
  remove(){this.isConnected=false;}
  setAttribute(k,v){this.attributes[k]=v;}
  getAttribute(k){return this.attributes[k];}
  addEventListener(k,f){(this.events[k]??=[]).push(f);}
  fire(k,e={}){for(const f of this.events[k]||[])f({button:0,detail:1,preventDefault(){},stopPropagation(){},...e});}
  querySelectorAll(sel){let matches=[];for(const c of this.children){if(sel.startsWith('.')?c.classList.contains(sel.slice(1)):c.tagName===sel)matches.push(c);matches.push(...c.querySelectorAll(sel));}return matches;}
  querySelector(s){return this.querySelectorAll(s)[0]||null;}
  setPointerCapture(){}
  focus(){}
  getBoundingClientRect(){return {left:0,top:0,width:this.width,height:this.height};}
}
function makeStorage(seed={}){const m=new Map(Object.entries(seed));return {getItem:k=>m.get(k)??null,setItem:(k,v)=>m.set(k,String(v)),removeItem:k=>m.delete(k),map:m};}
const key='minik.pong.progress.v1';
const oldState=(patch={})=>({version:1,points:300,operation:'multiply',levels:{addition:4,subtraction:3,multiply:5,divide:2},controlDesktop:'keyboard',controlTouch:'arrows',trainMode:'ball',...patch});
function harness({storage=makeStorage(),language='en-US',search='?from=math&madness=off',width=1000,height=400,seed=19}={}){
  const nodes=new Map(['app','langBtn','homeBtn','feedbackLayer','brandLogo','screenTitle','mainSiteLink','footerRights','pongTrainLayer','pongLandscapeCountdown'].map(k=>[k,new Element()]));
  const audio=[],events={},winEvents={};let now=1000,stops=0,replaced=null;
  const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  const math=Object.create(Math);math.random=random;
  const drawing=new Proxy({}, {get:(o,k)=>o[k]??(()=>{}),set:(o,k,v)=>{o[k]=v;return true;}});
  const document={hidden:false,documentElement:new Element(),body:new Element(),getElementById:k=>nodes.get(k)||null,querySelector:()=>null,querySelectorAll:()=>[],createElement:t=>new Element(t),addEventListener:(k,f)=>(events[k]??=[]).push(f)};
  const sandbox={console,Math:math,URLSearchParams,navigator:{userAgent:'iPhone MinikNative/iOS MinikNativeInsets/1',language,languages:[language],maxTouchPoints:5},document,
    localStorage:storage,sessionStorage:makeStorage(),performance:{now:()=>now},Image:class {constructor(){this.complete=true;this.naturalWidth=100;this.naturalHeight=100;}},
    setTimeout:()=>1,clearTimeout(){},requestAnimationFrame:()=>1,cancelAnimationFrame(){},screen:{orientation:{addEventListener(){}}},
    innerWidth:width,innerHeight:height,matchMedia:q=>({matches:q.includes('pointer')||q.includes('hover')||q.includes('orientation')&&width>height||q.includes('max-width')&&width<=760}),
    addEventListener:(k,f)=>(winEvents[k]??=[]).push(f),scrollTo(){},location:{search,replace:s=>{replaced=s;}},MinikAudio:{play:(name,channel)=>{audio.push({name,channel});return true;},stopAll:()=>{stops++;}},
  };
  sandbox.window=sandbox;
  const c=vm.createContext(sandbox);
  const instrumented=extrasSource.replace('  window.PongExtras=Object.freeze({','  window.__extraTest={createTrain,answerTrain,positionTrain,paddleSpeedFactor,guideCopy,COPY,attach:()=>{mountedGame=pong;}, train:()=>train};\n  window.PongExtras=Object.freeze({');
  vm.runInContext(instrumented,c);
  const appWithoutBoot=appSource.replace(/\nsetLang\(lang\);\s*go\("pong"\);\s*$/,'\n');
  assert.notEqual(appWithoutBoot,appSource,'Remove only automatic rendering for headless engine tests');
  vm.runInContext(appWithoutBoot,c);
  const run=s=>vm.runInContext(s,c);
  sandbox.__canvas=new Element('canvas');sandbox.__canvas.width=width;sandbox.__canvas.height=height;sandbox.__drawing=drawing;
  run(`view="pong";
    pong={c:__canvas,ctx:__drawing,pcVertical:true,paddleHeight:160,userY:420,aiY:420,aiTargetY:500,aiReactionCounter:0,aiSlowRally:false,aiForcedMiss:false,aiMissDirection:1,
    ball:{x:500,y:250,vx:2,vy:-6,r:8},palette:{user:"#69d8a8",ai:"#f58cc8"},userScore:0,aiScore:0,over:false,waitingForStart:false,startCountdownUntil:0,pointPauseUntil:0,
    lastFrameAt:1000,simulationNow:1000,rallyStartedAt:1000,flatHitCount:0,rallyHitCount:0,ballChaosUntil:0,repeatedContactCount:0,lastContactBySide:{user:null,ai:null},madnessObjects:[],lastPaddleContact:null};
    __extraTest.attach();
    flashPongScore=()=>{};syncPongHeaderState=()=>{};updatePongScore=()=>{};
  `);
  return {c,run,nodes,storage,audio,events,winEvents,get stops(){return stops;},get replaced(){return replaced;},now:v=>{now=v;},extra:sandbox.PongExtras,internals:sandbox.__extraTest,document};
}


test('Syntax and native iOS capability gates',()=>{
 for(const n of ['app.js','pong-extras.js','minik-audio.js','minik-audio-bank.js'])new vm.Script(fs.readFileSync(path.join(web,n),'utf8'),{filename:n});
 assert(extrasSource.includes('(?:Android|iOS)'));
});
test('All match settings persist; legacy swipe preference cannot remove arrows',()=>{
 const storage=makeStorage({[key]:JSON.stringify(oldState({controlTouch:'swipe'}))}),h=harness({storage});
 assert.equal(h.extra.snapshot().control,'arrows');assert(h.extra.canUsePointer('touch'));
 h.extra.setControl('swipe');assert.equal(h.extra.snapshot().control,'arrows');
 h.run('setPongDifficulty("hard");setPongTargetScore(11);setBalloonMadness(true);');
 let r=harness({storage});assert.equal(r.run('pongDifficulty'),'hard');assert.equal(r.run('pongTargetScore'),11);assert.equal(r.run('pongBalloonMadness'),true);
 r.run('setBalloonMadness(false)');r=harness({storage,search:'?madness=on'});assert.equal(r.run('pongBalloonMadness'),false);
 assert.equal(r.extra.snapshot().state.points,300);assert.equal(r.extra.snapshot().state.levels.multiply,5);
});
test('Highest rank always sets both arrow design and player paddle color/width',()=>{
 const thresholds=[0,100,200,300,500,700,900,1200],colors=['#ffd84d','#ef5350','#69d8a8','#4da3ff','#ef5350','#69d8a8','#4da3ff','#d7dee8'];
 for(let rank=0;rank<8;rank++){
  const h=harness({storage:makeStorage({[key]:JSON.stringify(oldState({points:thresholds[rank]}))})});
  for(let i=0;i<12;i++){assert.equal(h.extra.prepareRound(),rank);assert.equal(h.extra.paddleRank(),rank);assert.equal(h.extra.paddleColor(),colors[rank]);}
  h.extra.tick(1016,.016);assert.equal(h.run('pong.palette.user'),colors[rank]);assert.equal(h.extra.paddleLengthFactor(),2.5-2*rank/7);
  h.run('pong.waitingForStart=true;window.__draws=[];drawPongPaddle=(ctx,x,y,w,h)=>__draws.push({w,h});loopPong(1032)');
  const p=h.run('__draws');assert.equal(p[0].w,p[1].w);assert.equal(p[0].h,p[1].h);
 }
 const h=harness({storage:makeStorage({[key]:JSON.stringify(oldState({points:99}))})});h.extra.awardPoint();
 assert.equal(h.extra.paddleRank(),1);assert.equal(h.run('pong.palette.user'),'#ef5350');
 assert(!extrasSource.includes('Math.random()*pool.length'));
});
test('Train collision only with Balloon Madness; tap works either way',()=>{
 for(const madness of [false,true]){
  const h=harness({width:1000,height:1000});h.run('pongBalloonMadness='+madness);h.internals.createTrain();h.internals.positionTrain(.5);
  const tr=h.internals.train(),rect=tr.hitRects[2],before=h.extra.snapshot().state.points;
  const prior={x:rect.x+rect.w/2,y:rect.y+rect.h+24},ball={x:prior.x,y:rect.y+rect.h-4,vx:2,vy:-28,r:5};
  h.c.__ball=ball;h.run('pong.ball=__ball');
  assert.equal(h.extra.collideTrain(prior,1000),madness);assert.equal(h.audio.length,madness?1:0);assert(!tr.answered);assert.equal(h.extra.snapshot().state.points,before);
  if(madness){assert(ball.vy>0);for(let i=0;i<20;i++)assert.equal(h.extra.collideTrain({x:rect.x+10,y:rect.y+10},1010+i),false);assert.equal(h.audio.length,1);}
  else assert.equal(ball.vy,-28);
  h.internals.answerTrain(tr.id,tr.question.choices.indexOf(tr.question.answer),'tap');
  assert(tr.answered);assert.equal(h.extra.snapshot().state.points,before+3);assert.equal(h.audio.at(-1).name,'success_in_a_raw_sound');
 }
});
test('Replay goes straight to the countdown; Start label is localized',()=>{
 const h=harness();h.run('window.__rendered=0;renderPong=()=>__rendered++;resetPong();');
 assert.equal(h.run('__rendered'),1);assert(h.run('pongMobileStartRequested'));assert(h.run('pongLandscapeCountdownRequested'));
 assert.equal(h.run('copy.en.restart'),'Start');assert.equal(h.run('copy.he.restart'),'התחלה');
 assert(!/onclick="openPongLandscapeSetup\(\)"/.test(appSource));
});
test('Countdown emits game_start exactly once and pause defers it',()=>{
 const h=harness();h.run('pong.startCountdownUntil=4000;pong.ball.vx=0;pong.ball.vy=0;');
 h.extra.nativePause(true);h.run('pong.simulationNow=4000;loopPong(1000)');assert.equal(h.audio.length,0);
 h.extra.nativePause(false);h.run('pong.simulationNow=4000;pong.lastFrameAt=1000;loopPong(1000);loopPong(1000);');
 assert.equal(h.audio.filter(x=>x.name==='game_start').length,1);assert.equal(h.run('pong.startCountdownUntil'),0);
});
test('Native app help explains paddle rank and has no computer-only instruction',()=>{
 const h=harness();
 for(const language of ['en','he']){
  h.run('lang="'+language+'"');const copy=h.internals.COPY[language],guide=h.internals.guideCopy();
  assert.equal(copy.close,language==='en'?'Back':'חזרה');assert(!/computer|keyboard|מחשב|מקלדת/i.test(guide.control));
  assert(!/random|אקראי/i.test(copy.arrowRandom));
  assert(copy.skins.includes(language==='en'?'paddle':'מחבט'));
 }
 assert(extrasSource.includes('const action=tr("close")'));assert(extrasSource.includes('()=>closeSettings(false)'));
});
test('New start audio is present, identical to its embedded audio bank',()=>{
 const s={window:{}};vm.runInNewContext(fs.readFileSync(path.join(web,'minik-audio-bank.js'),'utf8'),s);
 const b=fs.readFileSync(path.join(web,'assets/audio/game_start.mp3'));assert.deepEqual(Buffer.from(s.window.MinikAudioBank.game_start,'base64'),b);


});
test('Native app menu entry skips automatic Help and countdown belongs to court',()=>{
 assert(extrasSource.includes('if(!androidApp()&&!introSeen)'));
 assert(appSource.includes('</canvas><div id="pongLandscapeCountdown"'));
 const css=fs.readFileSync(path.join(web,'pong-layout.css'),'utf8');
 assert(!css.includes('position:fixed !important;inset:0 !important;display:grid !important;place-items:center;'));
});
test('Native app train crosses both arrow gutters and keeps court-relative hit boxes',()=>{
 const h=harness({width:1000,height:400});h.internals.createTrain();const t=h.internals.train();
 const layer=new Element();layer.classList.add('pong-train-fullwidth');
 layer.getBoundingClientRect=()=>({left:0,top:0,width:1200,height:500});
 h.c.__canvas.getBoundingClientRect=()=>({left:100,top:64,width:1000,height:400});
 t.el.parentElement=layer;
 for(const direction of [-1,1]){
  t.direction=direction;h.internals.positionTrain(0);
  assert.equal(t.surface.start,-100);assert.equal(t.surface.end,1100);
  assert.equal(t.along,direction>0?-100-t.length:1100);
  assert(Math.abs((1200+t.length)/t.duration-(1000+t.length)/8)<1e-9,'Pixel speed retained');
  h.internals.positionTrain(.5);
  assert.equal(t.hitRects.length,5);assert(t.el.style.transform.startsWith('translate3d('));
  const x=Number(t.el.style.transform.match(/translate3d\(([-.0-9]+)px/)[1]);
  assert.equal(x,100+t.along,'DOM translated from court to full surface');
  h.internals.positionTrain(1);assert.equal(t.along,direction>0?1100:-100-t.length);
 }
 // Resizing remeasures the surface, including a canvas drawn at a different scale.
 h.c.__canvas.width=800;h.c.__canvas.getBoundingClientRect=()=>({left:80,top:50,width:1000,height:400});
 h.internals.positionTrain(.5);assert.equal(t.surface.sx,1.25);assert.equal(t.surface.start,-64);assert.equal(t.surface.end,896);
});


test('Native pause freezes train/rally clocks and adjusts countdown deadlines on resume',()=>{
 const h=harness(); h.internals.createTrain(); h.extra.tick(1016,.016);
 h.run('pong.startCountdownUntil=4000;pong.pointPauseUntil=5000;');
 h.now(1100);h.extra.nativePause(true);const before=h.extra.snapshot();
 h.extra.tick(2000,10);assert.equal(h.extra.snapshot().activeTime,before.activeTime);
 assert.equal(h.extra.snapshot().train.progress,before.train.progress);assert(!h.extra.canUsePointer('touch'));
 h.now(4100);h.extra.nativePause(false);
 assert.equal(h.run('pong.startCountdownUntil'),7000);assert.equal(h.run('pong.pointPauseUntil'),8000);
 assert.equal(h.run('pong.lastFrameAt'),4100);assert(h.extra.canUsePointer('touch'));
});
test('Train horn fires once per visit; world freezes and recovers gradually after one accepted tap',()=>{
 const h=harness();h.internals.createTrain();const t=h.internals.train();
 for(let i=0;i<1500&&h.extra.timeScale()>0;i++)h.extra.tick(1000+i*16,1/60);
 assert.equal(h.extra.timeScale(),0);assert(t.progress>=.28);assert(t.progress<1);
 assert.equal(h.audio.filter(x=>x.name==='train_horn').length,1);
 const p=t.progress;for(let i=0;i<60;i++)h.extra.tick(25000+i*16,1/60);
 assert(t.progress>p,'Train continues in slow motion while world is frozen');
 const points=h.extra.snapshot().state.points,level=h.extra.snapshot().state.levels.addition;
 const correct=t.question.choices.indexOf(t.question.answer);h.internals.answerTrain(t.id,correct,'tap');
 for(let i=0;i<10;i++)h.internals.answerTrain(t.id,correct,'tap');
 assert.equal(h.extra.snapshot().state.points,points+3);assert.equal(h.extra.snapshot().state.levels.addition,level+1);
 assert.equal(h.audio.filter(x=>x.name==='success_in_a_raw_sound').length,1);
 h.extra.tick(27000,.1);assert(h.extra.timeScale()>0&&h.extra.timeScale()<.02);
 for(let i=0;i<200;i++)h.extra.tick(27100+i*16,1/60);
 assert.equal(h.extra.timeScale(),1);
});
test('Wrong train tap reduces arithmetic level once and never changes match score',()=>{
 const h=harness({storage:makeStorage({[key]:JSON.stringify(oldState())})});h.internals.createTrain();const t=h.internals.train();
 const wrong=t.question.choices.findIndex(x=>x!==t.question.answer);
 h.internals.answerTrain(t.id,wrong,'ball');assert(!t.answered);
 h.internals.answerTrain(t.id,wrong,'tap');h.internals.answerTrain(t.id,wrong,'tap');
 assert.equal(h.extra.snapshot().state.levels.multiply,4);assert.equal(h.extra.snapshot().state.points,300);
 assert.equal(h.audio.filter(x=>x.name==='failure_answer_sound').length,1);
 assert.equal(h.run('pong.userScore+pong.aiScore'),0);
});
test('All arithmetic operations produce four distinct choices and one exact answer across levels',()=>{
 const h=harness();
 for(const op of ['addition','subtraction','multiply','divide'])for(let level=1;level<=12;level++)for(let i=0;i<60;i++){
  const q=h.extra.makeQuestion(op,level);
  assert.equal(q.choices.length,4);assert.equal(new Set(q.choices).size,4);assert(q.choices.includes(q.answer));
  const expected=op==='addition'?q.a+q.b:op==='subtraction'?q.a-q.b:op==='multiply'?q.a*q.b:q.a/q.b;
  assert.equal(q.answer,expected);assert(Number.isInteger(q.answer));assert(q.answer>=0);
 }
});
test('Opponent tuning and actual movement are ordered Beginner, Medium, Hard',()=>{
 const move=[],miss=[],reaction=[];
 for(const level of ['beginner','medium','hard']){
  const h=harness();h.extra.setTrainMode('off');h.run(`setPongDifficulty('${level}');pong.aiY=20;pong.aiForcedMiss=false;pong.aiSlowRally=false;pong.ball={x:850,y:150,vx:0,vy:0,r:8};loopPong(1016.667);`);
  move.push(h.run('pong.aiY-20'));miss.push(h.run(`pongDifficultySettings.${level}.missChance`));reaction.push(h.run(`pongDifficultySettings.${level}.reactionFrames`));
 }
 assert(move[0]<move[1]&&move[1]<move[2]);assert(miss[0]>miss[1]&&miss[1]>miss[2]);assert(reaction[0]>reaction[1]&&reaction[1]>reaction[2]);
});
test('Player and Minik contact/point sounds retain distinct semantic mappings',()=>{
 const h=harness();
 h.run('recordPongPaddleContact("user",1000);recordPongPaddleContact("ai",2000);awardPongPoint("user",1,3000);pong.pointPauseUntil=0;awardPongPoint("ai",-1,4000);');
 assert.deepEqual(h.audio.map(x=>x.name),['minik_kick','minik_kick2','success_sound','failure_sound']);
});

console.log(`${passed} refinement checks passed for ${web}`);
