const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sharp=require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'artifacts/hud-refinement-20260930/stage');
const projects={math:['C:/Projects/minikMath','app/src/main/assets/www/pingpong'],bounce:['C:/Projects/MinikPaddleAndLearn','app/src/main/assets/www']};
const css=fs.readFileSync(path.join(__dirname,'hud-layout.css'),'utf8');
const put=(app,rel,data)=>{const p=path.join(stage,app,rel);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,data);};
(async()=>{
 for(const [app,[dir,web]]of Object.entries(projects)){
  const current=fs.readFileSync(path.join(dir,web,'pong-layout.css'),'utf8');if(current.includes('/* Native HUD reading order:'))throw Error('Already applied '+app);
  put(app,web+'/pong-layout.css',current.trimEnd()+'\n'+css);
  // Export the same arrow pixels on a balanced canvas; no new artwork or pose.
  const original=fs.readFileSync(path.join(dir,web,'assets/arrow_back.webp'));
  const {data,info}=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let minX=info.width,minY=info.height,maxX=0,maxY=0;
  for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>=8){minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
  const b=await sharp(original).extract({left:minX,top:minY,width:maxX-minX+1,height:maxY-minY+1}).webp({lossless:true}).toBuffer();
  put(app,web+'/assets/arrow_back.webp',b);
  console.log(JSON.stringify({app,arrowBefore:[info.width,info.height],visibleBounds:[minX,minY,maxX,maxY]}));
 }
 const mathStore=projects.math[0]+'/play-store/2026-09-29';const hashes={};
 function walk(d){for(const item of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,item.name);if(item.isDirectory())walk(p);else if(/\.png$/i.test(p))hashes[path.relative(mathStore,p).replaceAll('\\','/')]=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');}}
 walk(mathStore+'/upload');fs.writeFileSync(path.join(stage,'../store-before-hashes.json'),JSON.stringify(hashes,null,2));
})();
