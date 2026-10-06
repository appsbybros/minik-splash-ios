from pathlib import Path
import json, hashlib, zipfile, xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
android = Path('C:/Projects/MinikPaddleAndLearn')
stage = root / 'artifacts/bounce-refresh-20260930/android'
qa = json.loads((root/'artifacts/bounce-refresh-20260930/qa/results.json').read_text())
assert len(qa) == 14 and all(item['passed'] for item in qa)
tests = {}
for variant in ('Debug', 'Release'):
    suites = [ET.parse(p).getroot() for p in (android / f'app/build/test-results/test{variant}UnitTest').glob('TEST-*.xml')]
    assert suites
    tests[variant] = {key: sum(int(s.get(key, '0')) for s in suites) for key in ('tests', 'failures', 'errors')}
    assert tests[variant] == {'tests':63,'failures':0,'errors':0}
apk = android/'app/build/outputs/apk/debug/app-debug.apk'
with zipfile.ZipFile(apk) as z:
    for name in ['app.js','index.html','pong-extras.js','pong-layout.css','assets/bounce-mark.webp','assets/bounce-logo.webp']:
        assert z.read('assets/www/'+name) == (android/'app/src/main/assets/www'/name).read_bytes(), name

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='\n')

android_report = '''# Bounce branding refresh — 30 September 2026

## Requested changes

1. Replaced the busy launcher with one large ball and a golden horizontal arcade paddle on plain purple. Android has separate adaptive foreground/background plus a themed monochrome silhouette. The icon was checked in circular and rounded masks at 32/48/72/192 pixels. No text, mascot, train, table or racket is in the small mark.
2. Setup, app header and Help use `assets/bounce-mark.webp`. The larger `assets/bounce-logo.webp` train/balloon illustration is unchanged. Hebrew's old Pong heading and the table-tennis badge emoji were corrected.
3. The complete current Store package is now **play-store/current**. Open its **preview.html**. Both languages have the new icon/feature branding and current setup/help screens; Balloon Madness and train screenshots keep the earlier Pixel captures. Eleven upload images have exact PNG dimensions, no alpha, size checks and SHA-256 records in `asset-manifest.json`. No Modern table-tennis imagery is in this set. Older dated/superseded folders remain archives.
4. The iOS Bounce implementation at `C:/Projects/Minik-to-IOS/ios-main-merge` now shares this Android payload and branding, while retaining its native storage, pause/audio and parent-return bridge. Its separate app icon is no longer the Modern icon. Its launcher label is Minik Bounce; scheme/bundle identity remain unchanged. Court Back returns to setup; embedded setup Back returns to Math; standalone iOS has no meaningless root Exit button or Game closed dead end. Portrait setup now has a visible Start. Modern's separate application is untouched. No iOS ads were added.
5. No Pixel/ADB connection or physical-device interaction was used. Device validation is pending.
6. This Android project is the actual repository at `https://github.com/appsbybros/minik-bounce.git`. Work started from main `751deaa16d16490bb5d50fa47d91507909b3dfe8`, matching remote main. The user's existing versionCode 2/versionName 2.0 change is preserved and included with the latest source. Local signing/ad configuration and build outputs are excluded from Git. The Android commit is intended for a normal main push; the iOS work remains local for separate review/push.

## Android files

- `app/build.gradle.kts`: preserve the pre-existing version 2 update.
- `app/src/main/assets/www/{app.js,index.html,pong-extras.js,pong-layout.css}`: small mark, heading/metadata, presentation.
- `app/src/main/assets/www/assets/bounce-mark.webp`: new compact in-app brand.
- `app/src/main/res/drawable-nodpi/{app_icon.webp,bounce_launcher.webp}`: launcher/app mark.
- `app/src/main/res/drawable/ic_launcher_monochrome.xml`: themed icon.
- `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` and `app/src/main/res/values/colors.xml`: adaptive icon wiring/background.
- `tools/check-retro-refinement.cjs`: normalize the brand-only difference when comparing shared gameplay against Math.
- `branding/2026-09-30/`: source image, prompt, RGB 1024px master and mask preview.
- `play-store/README.md` and `play-store/current/`: obvious current upload set, bilingual copy, gallery, validated manifest and source artwork/captures.
- This report and `bounce-refresh-files.json`: full inventory.

## Verification

From this Android project, using the existing JBR 21 and Android SDK:

```powershell
./gradlew.bat :app:assembleDebug :app:assembleRelease :app:bundleRelease :app:test :app:lintDebug --console=plain
node tools/check-retro-refinement.cjs
node tools/monetization-web.test.cjs
```

- Gradle: BUILD SUCCESSFUL, 114 tasks. Debug APK, unsigned release APK and release AAB produced.
- JVM: 63 tests in debug and the same 63 in release; zero failures/errors.
- Android gameplay refinement: 10 checks passed. Web monetization/navigation: 24 tests passed.
- Android lint: zero errors, 12 warnings (recorded in `app/build/reports/lint-results-debug.txt`). No unrelated lint cleanup.
- From the paired iOS workspace: `node Tests/RetroPong/engine.test.cjs` (16 checks); `node Tests/RetroPong/host.test.cjs` (8 tests); `python scripts/audit-retro-pong.py` (194 checks, 74 payload entries).
- `node tools/bounce-refresh/qa.cjs`: 14 browser scenarios pass at 2x pixel density. English/Hebrew Android landscape (960×432 and 740×340), iOS same landscape plus 390×844 and 768×1024 portrait, and embedded iOS return-to-Math callbacks in both languages. Checks cover distinct marks/illustration, setup bounds, help, Start, Back, missing assets and JavaScript exceptions.
- APK's packaged brand, app scripts and large illustration verified byte-for-byte against current source.
- Eleven Play Store images and all six listing text limits validated by `tools/bounce-refresh/package.cjs`.

Outputs:

- Debug: `app/build/outputs/apk/debug/app-debug.apk`
- Unsigned release: `app/build/outputs/apk/release/app-release-unsigned.apk`
- Release bundle: `app/build/outputs/bundle/release/app-release.aab` (distribution signing remains the existing owner setup).
- Browser evidence: paired iOS `artifacts/bounce-refresh-20260930/qa/`.
- Build log: `artifacts/bounce-refresh-20260930/build.log`.

## Remaining device checks

Pixel 3 and Pixel 6: install as an update without clearing data; inspect normal/themed launcher icons and adaptive masks, separate setup mark/hero, English/Hebrew help, court Back→setup, setup/system Back→Android exit, background/resume and retained points/settings. Compare setup and gameplay on both small and normal landscape screens.

iOS: Windows cannot build/run Xcode or WKWebView. On macOS build the existing MinikRetroPingPong and MinikMath schemes, verify the new icon and display name, portrait/landscape/notch safe areas, court→setup Back, embedded return to Math, background/resume, local progress and audio. The local browser tests are not a native iOS build. No IPA produced here.
'''
write(stage/'docs/BOUNCE-REFRESH-2026-09-30.md', android_report)
files = sorted(p.relative_to(stage).as_posix() for p in stage.rglob('*') if p.is_file())
write(stage/'docs/bounce-refresh-files.json',json.dumps({'date':'2026-09-30','project':str(android),'files':sorted(set(files+['app/build.gradle.kts','docs/bounce-refresh-files.json'])),'unitTests':tests,'browserScenarios':14,'apkSHA256':hashlib.sha256(apk.read_bytes()).hexdigest()},indent=2)+'\n')
ios_report='''# Minik Bounce & Learn iOS refresh — 2026-09-30

This supersedes the branding and exit-flow parts of the September 28 Retro handoff. The current Android reference is `C:/Projects/MinikPaddleAndLearn`, not the old Modern/80s chooser project.

The standalone `MinikRetroPingPong` scheme now has its own paddle/ball icon and display name **Minik Bounce**. The app header and Help use the simple mark, while the large train/balloon illustration remains. There is no Modern menu or Modern table-tennis artwork in this standalone route. The separate Modern app and Math chooser are unchanged.

The same refreshed `Resources/RetroPong` payload is used when Math hosts Bounce. Existing native progress, language, pause/audio and offline navigation protections remain. No ads or Android monetization library was added to iOS.

Back on the court returns to setup. With an `onExit` host callback, setup Back cleans up once and returns to Math. Standalone setup is the root and hides the nonfunctional Exit button. It no longer shows the browser's Game closed panel. `canExit` is a native navigation capability, not a gameplay feature mode. A portrait CSS adapter makes the setup and Start visible when hosted in a portrait iPhone/iPad window.

## Files

- `Resources/RetroPong/{app.js,index.html,pong-extras.js,pong-layout.css}` and `assets/{bounce-logo.webp,bounce-mark.webp}`: latest Android payload/branding, retaining iOS language/mobile adapter and offline CSP.
- `Resources/RetroPong/ios-host.{js,css}`: host-aware Back and usable portrait setup.
- `Sources/RetroPong/{RetroPongView.swift,RetroPongStorage.swift}`: supply the parent-return capability without changing progress keys.
- `Resources/RetroPongIcon.xcassets/RetroPongAppIcon.appiconset/AppIcon.png`: distinct 1024px RGB icon with no alpha.
- `project.yml`: Bounce display name only; target and bundle ID unchanged.
- `Tests/RetroPong/host.test.cjs`: embedded/standalone exit regression coverage.
- `docs/retro-pong-android-provenance.json`: all 74 source paths and hashes, with only documented platform adapters.
- `tools/bounce-refresh/`: staging, export, browser QA, packaging and handoff scripts. Android writes are scoped to the separately authorized project. Artifacts are under `artifacts/bounce-refresh-20260930`.

## Verification

16 shared gameplay checks, 8 host tests, 194 source/asset checks and 14 bilingual browser scenarios passed. Browser tests include phone and tablet portrait/landscape, setup/Help/game/Back, and embedded return callbacks. Android debug/release/bundle builds also pass, with 63 unit tests per build variant and no lint errors.

**No native iOS build, IPA, simulator or device run was performed on Windows. No Pixel was used.** The existing Retro Pong Simulator Verification workflow can perform the macOS build after the owner pushes this iOS work. These iOS changes are left uncommitted and unpushed; only Android Git publication was requested. Pre-existing website artifacts and other untracked user files were preserved.

## Next checks

On macOS, build MinikRetroPingPong and MinikMath; inspect launcher icon, safe areas, rotation, court Back→setup and embedded setup Back→Math, Help, pause/resume and preserved points/settings. On Pixel 3/6, inspect the new Android launcher and small mark/large illustration distinction in both languages without clearing data.

Current Play Store gallery: `C:/Projects/MinikPaddleAndLearn/play-store/current/preview.html`. The refreshed package contains one icon, two feature graphics and eight phone screenshots. The new setup/help captures are local renders of real app UI; gameplay/train screenshots retain earlier Pixel captures. Nothing has been uploaded to Play Console.
'''
write(root/'docs/bounce-refresh-2026-09-30.md',ios_report)
# New documents and copied listing text use repository-safe LF line endings.
for directory in ('docs', 'branding', 'play-store'):
    for p in (stage/directory).rglob('*'):
        if p.is_file() and p.suffix in ('.md','.json','.txt','.html'):
            p.write_bytes(b'\n'.join(line.rstrip(b' \t') for line in p.read_bytes().replace(b'\r\n',b'\n').split(b'\n')))
with zipfile.ZipFile(stage/'play-store/current/minik-bounce-play-store-current.zip','w',zipfile.ZIP_DEFLATED) as z:
    folder=stage/'play-store/current'
    for p in sorted(folder.rglob('*')):
        if p.is_file() and p.suffix!='.zip':z.write(p,p.relative_to(folder))
print(json.dumps({'browser_scenarios':len(qa),'unit_tests':tests,'apk_source_matches':True,'android_files':len(files)}))
