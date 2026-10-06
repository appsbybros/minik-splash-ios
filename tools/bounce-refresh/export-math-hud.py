"""Re-export only Math screenshots 05/06 in the existing package style."""
from pathlib import Path
import importlib.util, json, shutil, hashlib, sys
root=Path(__file__).resolve().parents[2]
work=root/'artifacts/hud-refinement-20260930'
source=Path('C:/Projects/minikMath/play-store/2026-09-29')
stage=work/'stage/math/play-store/2026-09-29'
exporter=work/'exporter';exporter.mkdir(parents=True,exist_ok=True)
for name in ('build.py','copy.json','storyboards.json'):
    shutil.copy2(source/'source/exporter'/name,exporter/name)
spec=importlib.util.spec_from_file_location('store_export',exporter/'build.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
module.OUT=work/'rendered'
output=module.OUT/'math';output.mkdir(parents=True,exist_ok=True)
(output/'source').mkdir(exist_ok=True)
story=json.loads((source/'source/storyboard.json').read_text(encoding='utf-8'))
manifest=json.loads((source/'asset-manifest.json').read_text(encoding='utf-8'))
provenance=json.loads((source/'source/provenance.json').read_text(encoding='utf-8'))
screens=[s for s in story['screens'] if s['slug'] in ('05-train','06-balloon-madness')]
assert len(screens)==2
def put(rel,data):
    p=stage/rel;p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(data,encoding='utf-8',newline='\n')
def js(rel,data):put(rel,json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
changed=[]
for locale,lang in [('en-US','en'),('he-IL','he')]:
    for st in screens:
        current=dict(st);current['source_he' if lang=='he' else 'source_en']=str(work/f'qa/math-{lang}-{st["slug"]}.png')
        made=module.screenshot('math',locale,current,output)
        rel=made.relative_to(output);dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(made,dest)
        entry=module.EXPORTS[-1];entry['status']='ready-local-app-render'
        assert (entry['width'],entry['height'],entry['mode'])==(1920,1080,'RGB')
        assert entry['bytes']<8*1024*1024
        manifest=[entry if old['file']==entry['file'] else old for old in manifest]
        raw=Path(current['source_he' if lang=='he' else 'source_en']);raw_rel=Path('source/local-captures/2026-09-30')/raw.name
        raw_dest=stage/raw_rel;raw_dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(raw,raw_dest)
        p=module.PROVENANCE[-1];p['source']=str(source/raw_rel)
        p['transform']='Current Android app payload rendered locally at 960x432 with 2x pixel density, then uniformly resized inside the existing marketing frame. App pixels are not retouched.'
        p['caveat']='30 September 2026 local Chromium capture with deterministic engine replay and an automated paddle. No phone/device used. Train and Balloon Madness are rendered by the actual game engine.'
        provenance=[p if old['output']==p['output'] else old for old in provenance]
        st['source_he' if lang=='he' else 'source_en']=str(source/raw_rel)
        changed.append(rel.as_posix())
    alts=json.loads((source/f'copy/{locale}/screenshot-alt-text.json').read_text(encoding='utf-8'))
    alts['06-balloon-madness']='Balloon Madness in Minik Math: colorful balloons, a cotton-candy ball and a cloud, with the corrected score and Total labels.' if lang=='en' else 'טירוף הבלונים במיניק חשבון עם בלונים צבעוניים, כדור צמר גפן מתוק וענן; הניקוד והניקוד המצטבר מוצגים בסדר המתוקן.'
    assert all(len(v)<=140 for v in alts.values())
    js(f'copy/{locale}/screenshot-alt-text.json',alts)
js('asset-manifest.json',manifest);js('source/provenance.json',provenance);js('source/storyboard.json',story)
full_story=json.loads((source/'source/exporter/storyboards.json').read_text(encoding='utf-8'))
for old in full_story['math']['screens']:
    match=next((s for s in screens if s['slug']==old['slug']),None)
    if match:old.update({k:match[k] for k in ('source_en','source_he')})
js('source/exporter/storyboards.json',full_story)
readme=(source/'README.md').read_text(encoding='utf-8')
readme=readme.replace('Screenshots were captured directly from this Android app on Pixel 3 and Pixel 6 on 29 September 2026.', 'Screenshots 01–04 retain the Pixel 3/6 captures from 29 September 2026. Only 05 (train) and 06 (Balloon Madness), in each language, were refreshed on 30 September from the current Android web payload rendered locally; no phone was used for this update.')
readme=readme.replace('- Both Pixel 3 and Pixel 6 were used for fresh app captures. Source screenshots and their hashes/provenance are retained under source/.','- Original Pixel captures remain under source/phone-captures. The four refreshed local captures are under source/local-captures/2026-09-30; provenance.json distinguishes them. No new archive/package folder was created, and all other upload images remain unchanged.')
put('README.md',readme)
session=(source/'source/capture-session.md').read_text(encoding='utf-8')
session+='\n## HUD update — 30 September 2026\n\nOnly upload/en-US/phone/{05-train,06-balloon-madness}-1920x1080.png and the corresponding he-IL files were replaced in place. These four current app captures were made in local Chromium, at 2x pixel density, without Pixel access. The same app engine produced the train and Balloon Madness scenes during deterministic automated play. The original marketing frame/captions were reused, with no pixel-level UI edits. Source files and updated hashes are recorded in provenance.json. All other upload images remain byte-for-byte unchanged.\n'
put('source/capture-session.md',session)
before=json.loads((work/'store-before-hashes.json').read_text())
assert set(changed)=={f'upload/{loc}/phone/{slug}-1920x1080.png' for loc in ('en-US','he-IL') for slug in ('05-train','06-balloon-madness')}
for rel,old_sha in before.items():
    if rel not in changed:assert sha(source/rel)==old_sha,rel
    else:assert sha(stage/rel)!=old_sha,rel
js('source/hud-update-2026-09-30.json',{'updatedUploads':changed,'unchangedUploads':[rel for rel in before if rel not in changed],'devicesUsed':False,'viewport':[960,432],'deviceScaleFactor':2,'source':'Current Android web payload, deterministic local Chromium replay','replaySeed':3180926})
print(json.dumps({'updated':changed,'unchanged_uploads':len(before)-len(changed)}))
