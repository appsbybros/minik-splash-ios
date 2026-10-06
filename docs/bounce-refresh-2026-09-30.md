# Minik Bounce & Learn iOS refresh — 2026-09-30

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
