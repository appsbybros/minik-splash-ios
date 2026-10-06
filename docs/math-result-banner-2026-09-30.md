# Minik Math result caption — 2026-09-30

The reported image is `C:/Projects/minikMath/play-store/2026-09-29-superseded-174902/upload/en-US/phone/03-play-break-1920x1080.png`.

Reproduced in the current Math Android payload. In a 640 × 320 landscape viewport, the result badge shrank to about 50.6px wide while its height stayed 44px. The English loss message needed five lines, extending above and below the badge. The shorter victory text could overflow too.

Applied the already-present Bounce/iOS rule to the Math payload: the completed-match status slot reserves **at least 136px**. It now fits the whole loss message in two centered lines. No truncation or smaller text, and no gameplay/score changes.

Only Math app code changed:

`C:/Projects/minikMath/app/src/main/assets/www/pingpong/pong-layout.css` — three added lines.

Bounce and iOS already had the rule and needed no new code edits for this defect. Android Bounce remains pushed at `a53acd2c3e990a9f24840d15ffc93e9d14c7bc0d` in `appsbybros/minik-bounce`. Math's small fix is local; no Math Git publication was requested.

## Verification

- `node tools/bounce-refresh/results-qa.cjs --before`: 12 Math cases reproduced the overflow; 24 Bounce/iOS cases already passed.
- `node tools/bounce-refresh/results-qa.cjs`: all **36** scenarios pass. Win and loss in English/Hebrew, 640×320, 740×340 and 960×432, for Math, Bounce and iOS. Uses the actual match-completion rendering, checks every rendered text-line rectangle against the badge, and captures screenshots.
- Math: `./gradlew.bat :app:assembleDebug :app:testDebugUnitTest :app:lintDebug --console=plain` — BUILD SUCCESSFUL; **59** unit tests, zero failures/errors; lint zero errors and 19 warnings.
- Before/after screenshots and rectangle measurements: `artifacts/bounce-results-20260930/{before,after}/` in this iOS workspace.
- Math build log: `C:/Projects/minikMath/artifacts/result-banner-20260930/build.log`.

No Pixel or iOS device was used. Native iOS remains unbuilt on Windows. The archived Store image is preserved, not cosmetically patched; the current Math upload set is under `play-store/2026-09-29` and does not use that old play-break screenshot.
