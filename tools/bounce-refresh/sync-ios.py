from pathlib import Path
import shutil,json,hashlib
root=Path(__file__).resolve().parents[2]
source=Path('C:/Projects/MinikPaddleAndLearn/app/src/main/assets/www')
output=root/'Resources/RetroPong'
records=[]
def sha(data):return hashlib.sha256(data).hexdigest()
for file in sorted(source.rglob('*')):
    if not file.is_file() or file.suffix.lower() not in ('.html','.js','.css','.webp','.png','.mp3','.svg'):continue
    rel=file.relative_to(source)
    if rel.as_posix()=='minik-monetization.js':continue # Keep the existing iOS no-ads contract.
    data=file.read_bytes()
    if file.suffix in ('.html','.js','.css','.svg'):
        text=data.decode('utf-8-sig').replace('\r\n','\n')
        if rel.as_posix() in ('app.js','pong-extras.js'):
            text=text.replace(r'MinikNative\/Android',r'MinikNative\/(?:Android|iOS)')
        if rel.as_posix()=='app.js':
            text=text.replace('const requestedPongLang = new URLSearchParams', 'const requestedPongLang = window.MinikRetroHost?.language || new URLSearchParams')
            text=text.replace('function isPongMobileDevice(){','function isPongMobileDevice(){\n  if(/MinikNative\\/iOS/.test(navigator.userAgent)) return true;')
        if rel.as_posix()=='index.html':
            csp="default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' data: blob:; connect-src 'none'; font-src 'self'; frame-src 'none'; base-uri 'none'; form-action 'none'"
            text=text.replace('<meta charset="utf-8" />','<meta charset="utf-8" />\n  <meta http-equiv="Content-Security-Policy" content="'+csp+'" />')
            text=text.replace('</head>','  <link rel="stylesheet" href="ios-host.css" />\n</head>')
            text=text.replace('  <script src="minik-audio-bank.js','  <script src="ios-host.js"></script>\n  <script src="minik-audio-bank.js')
            text=text.replace('  <script src="minik-monetization.js?v=monetization-1"></script>\n','')
        data=text.encode('utf-8')
    dest=output/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
    records.append({'source':str(file),'sourceSHA256':sha(file.read_bytes()),'output':dest.relative_to(root).as_posix(),'outputSHA256':sha(data),'outputHashMode':'lf-text' if file.suffix in ('.html','.js','.css','.svg') else 'bytes'})
(root/'docs/retro-pong-android-provenance.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
shutil.copy2(Path('C:/Projects/MinikPaddleAndLearn/branding/2026-09-30/app-icon-1024.png'),root/'Resources/RetroPongIcon.xcassets/RetroPongAppIcon.appiconset/AppIcon.png')
print('Synced '+str(len(records))+' Android Bounce files with the iOS host boundary preserved.')
