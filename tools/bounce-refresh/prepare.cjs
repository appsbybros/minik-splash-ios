const fs=require('node:fs'),path=require('node:path');
const sharp=require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),android='C:/Projects/MinikPaddleAndLearn',stage=path.join(root,'artifacts/bounce-refresh-20260930/android');
const generated='C:/Users/User/.codex/generated_images/01a0d467-5215-7892-a9ea-21fa1c336020/exec-c353f7c7-cc90-452d-ae41-162d1a10205c.png';
const dest=p=>{const d=path.join(stage,p);fs.mkdirSync(path.dirname(d),{recursive:true});return d;};
const write=(p,s)=>fs.writeFileSync(dest(p),s);
const copy=(from,to)=>fs.copyFileSync(from,dest(to));
const readBase=p=>{const backup=path.join(android,'artifacts/bounce-refresh-20260930/before',p);return fs.readFileSync(fs.existsSync(backup)?backup:path.join(android,p),'utf8');};
const edit=(p,changes)=>{let s=readBase(p);for(const [a,b]of changes){if(!s.includes(a))throw Error('Missing edit: '+a);s=s.replaceAll(a,b);}write(p,s);};
(async()=>{
 const master=await sharp(generated).resize(1024,1024).flatten({background:'#25104f'}).removeAlpha().png().toBuffer();
 write('branding/2026-09-30/app-icon-1024.png',master);copy(generated,'branding/2026-09-30/generated-paddle-ball.png');
 await sharp(master).resize(512).webp({lossless:true}).toFile(dest('app/src/main/res/drawable-nodpi/app_icon.webp'));
 await sharp(master).resize(256).webp({lossless:true}).toFile(dest('app/src/main/assets/www/assets/bounce-mark.webp'));
 const foreground=await sharp(generated).resize(780,780).png().toBuffer();
 const adaptive=await sharp({create:{width:1080,height:1080,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:foreground,left:150,top:150}]).webp({lossless:true}).toBuffer();
 write('app/src/main/res/drawable-nodpi/bounce_launcher.webp',adaptive);
 edit('app/src/main/res/values/colors.xml',[['#170565','#25104F']]);
 edit('app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',[['</adaptive-icon>','    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n</adaptive-icon>']]);
 write('app/src/main/res/drawable/ic_launcher_monochrome.xml',`<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#FFFFFFFF" android:pathData="M63,29 A14,14 0,1 1,63,57 A14,14 0,1 1,63,29 M30,62 L77,62 A6,6 0,0 1,83,68 A6,6 0,0 1,77,74 L30,74 A6,6 0,0 1,24,68 A6,6 0,0 1,30,62 Z" />
</vector>
`);
 const web='app/src/main/assets/www/';
 edit(web+'app.js',[
  ['pongTitle:"פינג פונג עם מיניק"','pongTitle:"מיניק מקפיצים ולומדים"'],
  ['<span class="pong-badge">🏓','<span class="pong-badge">'],
  ['? "assets/bounce-logo.webp"','? "assets/bounce-mark.webp"'],
  ['<img src="assets/bounce-logo.webp" alt="Minik Bounce & Learn">','<img src="assets/bounce-mark.webp" alt="Minik Bounce & Learn">']
 ]);
 edit(web+'index.html',[
  ['id="brandLogo" src="assets/bounce-logo.webp"','id="brandLogo" src="assets/bounce-mark.webp"'],
  ['aria-label="Minik Math home"','aria-label="Minik Bounce &amp; Learn home"'],
  ['Minik Math - Learn Math with Fun and Games','Minik Bounce &amp; Learn'],
  ['Practice multiplication and division with fun Minik games.','Bounce, answer the question train, and enjoy Balloon Madness.']
 ]);
 edit(web+'pong-extras.js',[['src="assets/bounce-logo.webp"','src="assets/bounce-mark.webp"']]);
 const css=readBase(web+'pong-layout.css');
 write(web+'pong-layout.css',css+'\n/* Compact brand marks differ from the unchanged large train/balloon illustration. */\n.pong-setup-logo,.pong-guide-heading > img,#brandLogo{border-radius:22%;}\n');
 edit('tools/check-retro-refinement.cjs',[["extrasSource.replaceAll('assets/bounce-logo.webp','assets/minik-ping-pong-logo.webp')","extrasSource.replaceAll('assets/bounce-mark.webp','assets/minik-ping-pong-logo.webp')"]]);
 const oldStore=path.join(android,'play-store/2026-09-29');
 for(const folder of ['upload','copy'])fs.cpSync(path.join(oldStore,folder),dest('play-store/current/'+folder),{recursive:true,force:false});
 await sharp(master).resize(512).png().toFile(dest('play-store/current/upload/common/app-icon-512.png'));
 copy(path.join(oldStore,'source/generated-feature-background.png'),'play-store/current/source/feature-background.png');
 copy(path.join(root,'website/minik-apps/public/assets/fonts/Heebo-Variable.ttf'),'play-store/current/source/Heebo-Variable.ttf');
 copy(path.join(root,'website/minik-apps/public/assets/fonts/OFL-Heebo.txt'),'play-store/current/source/OFL-Heebo.txt');
 write('branding/2026-09-30/PROMPT.txt','Built-in image_gen, logo-brand, 2026-09-30.\nSimple square mobile launcher icon: exactly one large white ball above a thick golden-yellow horizontal arcade paddle on a plain dark-purple background. No train, balloons, mascot, text, net, table or racket. Large high-contrast shapes, generous adaptive-icon margins.\nGenerated output preserved beside this file. Exported RGB iOS/Play icon, transparent adaptive Android foreground, and compact WebP in-app mark. Large in-app illustration is unchanged.\n');
 // Actual launcher viewport/masks, not the entire 108dp adaptive layer.
 const visible=await sharp(adaptive).extract({left:180,top:180,width:720,height:720}).flatten({background:'#25104f'}).png().toBuffer();
 const pieces=[];for(const [row,kind]of ['circle','rounded'].entries())for(const [col,size]of [32,48,72,192].entries()){
  const shape=kind==='circle'?`<circle cx="${size/2}" cy="${size/2}" r="${size/2}" fill="white"/>`:`<rect width="${size}" height="${size}" rx="${size*.22}" fill="white"/>`;
  const input=await sharp(visible).resize(size).ensureAlpha().composite([{input:Buffer.from(`<svg width="${size}" height="${size}">${shape}</svg>`),blend:'dest-in'}]).png().toBuffer();pieces.push({input,left:30+col*220,top:30+row*230});
 }
 await sharp({create:{width:930,height:460,channels:3,background:'#e6e5ed'}}).composite(pieces).png().toFile(dest('branding/2026-09-30/launcher-mask-preview.png'));
 console.log('Prepared reviewable Android changes at '+stage);
})();
