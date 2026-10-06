// Regression: the live minikPingPong rules are copied unchanged into the merged candidate. These cases are
// copied verbatim from the original Minik Ping Pong suite and must keep passing against it.
const {before, after, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
let env;
const mergedPath = path.resolve(__dirname, '../rules/merged.json');
const projectId = 'demo-minik-pingpong';   // its own emulator namespace: the suites run in parallel
before(async () => {
  const [host,port]=(process.env.FIREBASE_DATABASE_EMULATOR_HOST||'').split(':');
  assert.ok(host==='127.0.0.1'&&Number(port)>0,'Local emulator required (emulators:exec sets it); never use production');
  env = await initializeTestEnvironment({projectId, database:{host,port:Number(port),rules:fs.readFileSync(mergedPath,'utf8')}});
});
after(async () => {if(env) await env.cleanup()});
beforeEach(async () => {await env.clearDatabase()});
const db = uid => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).database();
test('full rules deny unauthenticated root access', async () => {
  await assertFails(db().ref().once('value'));
  await assertFails(db().ref('minikPingPong/profiles/host').set({id:'host', name:'Host', avatar:0}));
});
const clone = o => structuredClone(o);
const identity = id => ({id,name:id,avatar:0});
const bot = {speed:9,reaction:9,accuracy:9,power:9,agility:9,characterId:'kyra',forehandSkill:9,backhandSkill:9,serveSkill:9};
function room(kind='friendlyRooms', ids=['alice','bob'], code='ABCDEF', capacity=ids.length) {
  return {code,kind:kind==='friendlyRooms'?'FRIENDLY':'TOURNAMENT',host:ids[0],capacity,legs:1,winPoints:3,lossPoints:0,difficulty:0,target:7,
    participants:Object.fromEntries(ids.map(id=>[id,{identity:identity(id),...(id.startsWith('bot_')?{bot}: {})}])),
    roster:ids.slice().sort(),rosterSize:ids.length,state:'WAITING',createdAt:Date.now(),lastActivityAt:Date.now()};
}
function schedule(r) {
  r=clone(r); r.state='ACTIVE';r.matches={};const ids=Object.keys(r.participants).sort();
  for(let leg=0;leg<r.legs;leg++)for(let i=0;i<ids.length;i++)for(let j=i+1;j<ids.length;j++) {
    const id=`${r.code}_${leg}_${i}_${j}`, a=ids[leg?j:i],b=ids[leg?i:j];
    const humans=[a,b].filter(id=>!r.participants[id].bot).sort();
    r.matches[id]={id,a,b,seed:123,phase:humans.length?'WAITING':'FINISHED',authorityUid:humans[0]||r.host,starts:0,scoreA:humans.length?0:7,scoreB:0,winner:humans.length?'':a};
  } return r;
}
async function seed(kind,r) {await env.withSecurityRulesDisabled(c=>c.database().ref(`minikPingPong/${kind}/${r.code}`).set(r));return `minikPingPong/${kind}/${r.code}`}
async function reserve(uid,kind,code,slot=0){return assertSucceeds(db(uid).ref(`minikPingPong/openSlots/${uid}/${kind}/${slot}`).set(code));}
async function read(p) {return (await db('alice').ref(p).once('value')).val()}
async function change(uid,p,fn) {
  const current=await read(p); const next=fn(clone(current))||current;
  return db(uid).ref(p).set(next);
}
function joined(r,id) {r.participants[id]={identity:identity(id)};r.roster=Object.keys(r.participants).sort();r.rosterSize=r.roster.length;return r}
function ready(r,uid) {const m=Object.values(r.matches)[0];m.phase='READY';m.ready={...m.ready,[uid]:true};return r}
function playing(r) {const m=Object.values(r.matches)[0];m.phase='PLAYING';m.starts=1;delete m.ready;return r}
function finish(r) {const m=Object.values(r.matches)[0];m.phase='FINISHED';m.scoreA=7;m.scoreB=3;m.winner=m.a;r.state='FINISHED';return r}
test('collection scans and unknown namespaces denied even to authenticated users',async()=>{
  for(const p of [undefined,'minikPingPong','minikPingPong/profiles','minikPingPong/friendlyRooms','minikPingPong/tournaments','minikPingPong/live','minikPingPong/leaderboard'])await assertFails(db('alice').ref(p).once('value'));
  await assertFails(db('alice').ref('minikPingPong/leaderboard/alice').set({score:99}));
});
test('own profile accepted; impersonation and invalid name/avatar rejected',async()=>{
  await assertSucceeds(db('alice').ref('minikPingPong/nicknames/GreenFrog').set('alice'));
  await assertSucceeds(db('alice').ref('minikPingPong/profiles/alice').set({...identity('alice'),name:'GreenFrog',updatedAt:12345}));
  await assertFails(db('bob').ref('minikPingPong/profiles/alice').set(identity('alice')));
  for(const bad of [{name:''},{name:'x'.repeat(19)},{id:'bob'},{avatar:6},{avatar:1.5}])await assertFails(db('alice').ref('minikPingPong/profiles/alice').set({...identity('alice'),...bad}));
});
for(const kind of ['friendlyRooms','tournaments']) {
  test(`${kind}: create/read/join works; full, unauthenticated and fake host rejected`,async()=>{
    const r=room(kind,['alice'],'ABCDEF',2),p=`minikPingPong/${kind}/ABCDEF`;
    await assertFails(db('bob').ref(p).set(r));await assertFails(db().ref(p).set(r));
    await reserve('alice',kind,r.code);await reserve('bob',kind,r.code);
    await assertSucceeds(db('alice').ref(p).set(r));
    await assertSucceeds(db('bob').ref(p).once('value')); // Knowing a code is the MVP read capability.
    await assertSucceeds(change('bob',p,r=>joined(r,'bob')));
    await assertFails(change('eve',p,r=>joined(r,'eve')));
    await assertFails(db().ref(p).once('value'));
  });
  test(`${kind}: outsiders cannot overwrite/delete rooms, members cannot alter settings/host`,async()=>{
    const p=await seed(kind,room(kind));
    await assertFails(change('eve',p,r=>{r.target=11;return r}));
    await assertFails(db('eve').ref(p).remove());
    for(const [k,v] of [['host','bob'],['target',11],['difficulty',3],['createdAt',999]])await assertFails(change('bob',p,r=>{r[k]=v;return r}));
  });
  test(`${kind}: own identity edit allowed before start; other identity and roster deletion blocked`,async()=>{
    const p=await seed(kind,room(kind));
    await assertSucceeds(change('bob',p,r=>{r.participants.bob.identity.name='Bobby';return r}));
    await assertFails(change('bob',p,r=>{r.participants.alice.identity.name='Stolen';return r}));
    await assertFails(change('bob',p,r=>{delete r.participants.alice;r.roster=['bob'];r.rosterSize=1;return r}));
    await assertFails(db('bob').ref(`${p}/participants/alice`).remove());
  });
  test(`${kind}: host creates schedule, ready persists, both present start once, authority saves immutable result`,async()=>{
    let r=room(kind);const p=await seed(kind,r),m=`${r.code}_0_0_1`;
    await assertFails(db('bob').ref(p).set(schedule(r)));
    await assertSucceeds(db('alice').ref(p).set(schedule(r)));
    await assertSucceeds(change('alice',p,r=>ready(r,'alice')));
    await assertFails(change('alice',p,r=>ready(r,'bob')));
    await assertSucceeds(change('bob',p,r=>ready(r,'bob')));
    await assertFails(change('alice',p,playing));
    for(const uid of ['alice','bob'])await assertSucceeds(db(uid).ref(`${p}/connections/${uid}/0`).set(true));
    await assertSucceeds(db('alice').ref(`${p}/connections/alice/0`).remove());
    assert.equal((await read(p)).matches[m].ready.alice,true);
    await assertSucceeds(db('alice').ref(`${p}/connections/alice/0`).set(true));
    await assertSucceeds(change('bob',p,playing));
    await assertFails(change('alice',p,r=>{r.matches[m].starts++;return r}));
    await assertFails(change('bob',p,finish));
    await assertSucceeds(change('alice',p,finish));
    await assertSucceeds(db('alice').ref(p).set(await read(p)));
    await assertFails(change('alice',p,r=>{r.matches[m].scoreB=4;return r}));
    await assertFails(db('alice').ref(`${p}/matches/${m}`).remove());
  });
  test(`${kind}: presence belongs to members themselves, including deletion via room transaction`,async()=>{
    const p=await seed(kind,room(kind));
    await assertFails(db('eve').ref(`${p}/connections/eve/0`).set(true));
    await assertFails(db('bob').ref(`${p}/connections/alice/0`).set(true));
    await assertSucceeds(db('alice').ref(`${p}/connections/alice/0`).set(true));
    await assertFails(db('bob').ref(`${p}/connections/alice/0`).remove());
    await assertFails(change('bob',p,r=>{delete r.connections;return r}));
    await assertSucceeds(db('alice').ref(`${p}/connections/alice/0`).remove());
  });
  test(`${kind}: bot skills validated, host add/remove supported, non-host cannot become bot`,async()=>{
    const r=room(kind,['alice'],'ABCDEF',2),p=await seed(kind,r);
    const withBot=clone(r);withBot.participants.bot_kyra={identity:identity('bot_kyra'),bot};withBot.roster=['alice','bot_kyra'];withBot.rosterSize=2;
    await assertSucceeds(db('alice').ref(p).set(withBot));
    await assertFails(change('alice',p,r=>{r.participants.bot_kyra.bot.forehandSkill=11;return r}));
    await reserve('alice',kind,r.code);await reserve('bob',kind,r.code);
    await assertSucceeds(db('alice').ref(p).set(r));
    await assertSucceeds(change('bob',p,r=>joined(r,'bob')));
    await assertFails(change('bob',p,r=>{r.participants.bob.bot=bot;return r}));
  });
}
test('checkpoint authority/revision and live action ownership/ring order',async()=>{
  const r=playing(schedule(room()));await seed('friendlyRooms',r);const m='ABCDEF_0_0_1',p=`minikPingPong/live/${m}`;
  const checkpoint={protocol:1,kind:'friendlyRooms',code:'ABCDEF',engine:{score:0},revision:1,authority:'alice',serverAt:Date.now()};
  await assertSucceeds(db('alice').ref(`${p}/checkpoint`).once('value'));
  await assertFails(db('bob').ref(`${p}/checkpoint`).set({...checkpoint,authority:'bob'}));
  await assertSucceeds(db('alice').ref(`${p}/checkpoint`).set(checkpoint));
  await assertFails(db('alice').ref(`${p}/checkpoint`).set(checkpoint));
  await assertSucceeds(db('alice').ref(`${p}/checkpoint`).set({...checkpoint,revision:2}));
  const action={protocol:1,kind:'friendlyRooms',code:'ABCDEF',sender:'bob',sequence:1,serverAt:Date.now(),clientAt:Date.now(),flight:{x:.5},rallies:0,hit:0};
  await assertSucceeds(db('bob').ref(`${p}/actions/bob/1`).set(action));
  await assertFails(db('bob').ref(`${p}/actions/bob/1`).set(action));
  await assertFails(db('alice').ref(`${p}/actions/bob/1`).set({...action,sequence:17}));
  await assertFails(db('eve').ref(`${p}/actions/eve/1`).set({...action,sender:'eve'}));
  await assertFails(db('bob').ref(`${p}/actions/bob/16`).set({...action,sequence:16}));
  await assertSucceeds(db('bob').ref(`${p}/actions/bob/1`).set({...action,sequence:17}));
  await assertSucceeds(db('alice').ref('minikPingPong/friendlyRooms/ABCDEF').set(finish(r)));
  await assertFails(db('bob').ref(`${p}/actions/bob/2`).set({...action,sequence:18}));
});
test('unchanged TripleShot own-user and leaderboard rules still work; cross-user writes denied',async()=>{
  const profile={uid:'alice',displayName:'Alice',createdAt:123,updatedAt:124};
  await assertSucceeds(db('alice').ref('tripleShot/users/alice/profile').set(profile));
  await assertFails(db('bob').ref('tripleShot/users/alice/profile').set(profile));
  await assertFails(db('bob').ref('tripleShot/users/alice').once('value'));
  await assertSucceeds(db('alice').ref('tripleShot/leaderboard/alice').set({uid:'alice',name:'Alice',bestScore:5}));
  await assertSucceeds(db('bob').ref('tripleShot/leaderboard').once('value'));
  await assertFails(db().ref('tripleShot/leaderboard').once('value'));
});
test('host cannot skip Ready; non-authority cannot change scores while playing',async()=>{
  const r=schedule(room()),p=await seed('friendlyRooms',r);
  for(const uid of ['alice','bob'])await assertSucceeds(db(uid).ref(`${p}/connections/${uid}/0`).set(true));
  await assertFails(change('alice',p,playing));
  await seed('friendlyRooms',playing(r));
  await assertFails(change('bob',p,r=>{r.matches.ABCDEF_0_0_1.scoreB=7;return r}));
  await assertFails(change('alice',p,r=>{r.matches.ABCDEF_0_0_1.phase='READY';return r}));
});
test('invalid final scores rejected; hard deuce result accepted',async()=>{
  const r=playing(schedule(room()));r.difficulty=2;const p=await seed('friendlyRooms',r);
  for(const scores of [[0,0],[6,3],[7,6],[9,6]]) {
    const next=finish(r);next.matches.ABCDEF_0_0_1.scoreA=scores[0];next.matches.ABCDEF_0_0_1.scoreB=scores[1];
    await assertFails(db('alice').ref(p).set(next));
  }
  const next=finish(r);next.matches.ABCDEF_0_0_1.scoreA=9;next.matches.ABCDEF_0_0_1.scoreB=7;
  await assertSucceeds(db('alice').ref(p).set(next));
});
function leaveTournament(r,uid){
  r=clone(r);const peer=Object.keys(r.participants).sort().find(p=>p!==uid&&!r.participants[p].bot&&!r.departed?.[p]&&Object.keys(r.connections?.[p]||{}).length);
  if(r.host===uid)r.host=peer;
  if(r.state==='WAITING'){delete r.participants[uid];r.roster=Object.keys(r.participants).sort();r.rosterSize=r.roster.length;}
  else {
    r.departed={...r.departed,[uid]:true};
    for(const m of Object.values(r.matches)){
      if((m.a===uid||m.b===uid)&&!['FINISHED','CANCELLED'].includes(m.phase)){m.phase='CANCELLED';delete m.ready;}
      if(r.participants[m.a].bot&&r.participants[m.b].bot)m.authorityUid=r.host;
    }
    r.state=Object.values(r.matches).every(m=>['FINISHED','CANCELLED'].includes(m.phase))?'FINISHED':'ACTIVE';
  }
  delete r.connections[uid];return r;
}
test('tournament deletion allowed to sole connected human even non-host and during play',async()=>{
  for(const phase of ['WAITING','PLAYING','FINISHED']){
    let r=room('tournaments',['alice','bob','bot_kyra']);
    if(phase!=='WAITING'){r=schedule(r);r.matches.ABCDEF_0_0_1.phase=phase;r.matches.ABCDEF_0_0_1.starts=1;}
    r.connections={bob:{0:true}};const p=await seed('tournaments',r);
    await assertFails(db('eve').ref(p).remove());
    await assertFails(db('alice').ref(p).remove()); // A different connected human exists.
    await assertSucceeds(db('bob').ref(p).remove());
  }
});
test('departure cannot evict a peer, steal host, alter results or cancel unrelated matches',async()=>{
  let r=schedule(room('tournaments',['alice','bob','carol']));r.connections={alice:{0:true},bob:{0:true},carol:{0:true}};
  const p=await seed('tournaments',r);
  await assertFails(db('bob').ref(p).set(leaveTournament(r,'alice')));
  const stolen=clone(r);stolen.host='bob';await assertFails(db('bob').ref(p).set(stolen));
  const bad=leaveTournament(r,'alice');bad.matches.ABCDEF_0_1_2.phase='CANCELLED';await assertFails(db('alice').ref(p).set(bad));
  const badScore=leaveTournament(r,'alice');badScore.matches.ABCDEF_0_0_1.scoreA=7;await assertFails(db('alice').ref(p).set(badScore));
  const noPeer=clone(r);noPeer.connections={alice:{0:true}};await seed('tournaments',noPeer);
  const disconnected=leaveTournament(r,'alice');await assertFails(db('alice').ref(p).set(disconnected));
});
test('monetization codes and purchase records remain server-only for both apps',async()=>{
  for(const root of ['minikPingPong/monetization','minikMath/monetization']){
    await env.withSecurityRulesDisabled(c=>c.database().ref(root+'/codes/private').set({enabled:true,maxUses:1}));
    for(const uid of [null,'alice','bob']){
      for(const child of ['codes/private','purchases/fake','rate/fake']){
        await assertFails(db(uid).ref(root+'/'+child).once('value'));
        await assertFails(db(uid).ref(root+'/'+child).set({enabled:true,verifiedAt:Date.now()}));
      }
      await assertFails(db(uid).ref(root).once('value'));
      await assertFails(db(uid).ref(root).set({codes:{free:{enabled:true}}}));
    }
  }
});
// Knockout: server validates stored draws, winners/byes and the same result authority.
function knockoutRoom(ids=['alice','bob'],capacity=ids.length) {
  return {...room('tournaments',ids,'KNCDEF',capacity),format:'KNOCKOUT'};
}
function knockoutDraw(r,ids,round=0) {
  r=clone(r);r.state='ACTIVE';r.rounds??={};r.matches??={};
  r.rounds[round]={count:ids.length,players:ids};
  for(let i=0;i<Math.floor(ids.length/2);i++) {
    const a=ids[i*2],b=ids[i*2+1],id=r.code+'_K'+round+'_'+i;
    const humans=[a,b].filter(x=>!r.participants[x].bot).sort();
    r.matches[id]={id,a,b,seed:123,phase:humans.length?'WAITING':'FINISHED',authorityUid:humans[0]||r.host,
      starts:0,scoreA:humans.length?0:7,scoreB:0,winner:humans.length?'':a};
  }
  return r;
}
function knockoutSettle(r) {
  r=clone(r);
  while(true) {
    const round=Math.max(...Object.keys(r.rounds).map(Number)),players=r.rounds[round].players;
    const matches=Array.from({length:Math.floor(players.length/2)},(_,i)=>r.matches[r.code+'_K'+round+'_'+i]);
    if(matches.some(m=>!['FINISHED','CANCELLED'].includes(m.phase)))return r;
    const ids=[...matches.map(m=>m.winner),...(players.length%2?[players.at(-1)]:[])]
      .filter(id=>id&&!r.departed?.[id]);
    if(ids.length<=1){r.state='FINISHED';return r;}
    r=knockoutDraw(r,ids.reverse(),round+1);
  }
}
function knockoutFinish(r,id,winner) {
  r=clone(r);const m=r.matches[id];m.phase='FINISHED';m.scoreA=winner===m.a?7:1;m.scoreB=winner===m.b?7:1;m.winner=winner;
  return knockoutSettle(r);
}
test('knockout: complete odd and even tournaments, advance exact winners plus bye, and keep results immutable',async()=>{
  for(const count of [2,3,5,8,9]){
    const ids=['alice','bob','charlie','dana','erin','frank','grace','hank','ivy'].slice(0,count);
    let r=knockoutRoom(ids);const p=await seed('tournaments',r);
    r=knockoutDraw(r,ids);await assertSucceeds(db('alice').ref(p).set(r));
    let completed=0;
    while(r.state!=='FINISHED'){
      const m=Object.values(r.matches).find(m=>m.phase==='WAITING');
      assert.ok(m);m.phase='PLAYING';m.starts=1;
      await seed('tournaments',r);
      const next=knockoutFinish(r,m.id,m.a);
      const nonAuthority=ids.find(id=>id!==m.authorityUid);
      await assertFails(db(nonAuthority).ref(p).set(next));
      await assertSucceeds(db(m.authorityUid).ref(p).set(next));
      await assertSucceeds(db(m.authorityUid).ref(p).set(next)); // retry is idempotent
      r=next;completed++;
    }
    assert.equal(completed,count-1);
    await assertFails(change('alice',p,r=>{r.state='ACTIVE';return r}));
    const id=Object.keys(r.matches)[0];
    await assertFails(change('alice',p,r=>{r.matches[id].scoreA=8;return r}));
    await assertFails(change('alice',p,r=>{delete r.rounds[0];return r}));
  }
});
test('knockout: quitting awards an honest walkover and transfers host; invented walkovers rejected',async()=>{
  let r=knockoutDraw(knockoutRoom(['alice','bob','charlie']),['alice','bob','charlie']);
  r.connections={alice:{0:true},bob:{0:true},charlie:{0:true}};
  const p=await seed('tournaments',r);
  const next=clone(r);next.departed={alice:true};next.host='bob';delete next.connections.alice;
  Object.assign(next.matches.KNCDEF_K0_0,{phase:'CANCELLED',winner:'bob'});
  const good=knockoutSettle(next);
  const bad=clone(good);delete bad.departed;
  await assertFails(db('alice').ref(p).set(bad));
  await assertSucceeds(db('alice').ref(p).set(good));
  assert.deepEqual(new Set((await read(p)).rounds[1].players),new Set(['bob','charlie']));
});
