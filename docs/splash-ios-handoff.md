# Minik Splash — iOS port handoff

Android source: `C:\Projects\MinikSplash` (read-only; Android versionCode 3, revision 2026-10-04,
46 JVM tests). iOS target: `MinikSplash` in `project.yml` (bundle `com.appsbybros.minik.splash`),
sources under `Splash/`, tests under `Tests/SplashTests/` (scheme `MinikSplash`, test target
`SplashTests`). Nothing here has been compiled yet: this Windows machine has no `swiftc`, and no
GitHub build was started. Nothing was committed or pushed.

## What was ported

| Area | Status |
| --- | --- |
| Simulation (`SplashEngine`): movement, explicit pickup, walk-to (Easy), aim, throw, jump, crouch, personal space, collision geometry, paint layers, cleaning, shield, wrong-answer pop, house players, FFA/teams scoring, results | Ported statement by statement, same constants and random-number order |
| Questions: generators, per-skill learning, unlock rules, 24 English + 12 world facts | Ported; facts generated from `Learning.kt`; Kotlin `Random` reproduced bit-exactly |
| Gestures: 220 ms single/double tap, slop, locked targets for two independent fingers, cancel | Ported (`Gestures.swift`); UIKit touches mapped to Android pointer ids |
| Arena renderer (`SplashView.kt`): projection, cached arena, court glass, team halves, balloons with private answers, actors with direction atlases, mirroring, reflections, painted variants, aiming arc and grip, shots, splashes, particles, HUD, advice, tutorial overlay, pause overlay | Ported to Core Graphics (`SplashArenaView.swift`) with the same geometry in points |
| "Learn with Minik" (11 steps: Easy/Standard walking and throwing, mistakes, jump, duck, free practice), settings saved from the tutorial | Ported |
| Menus: home, settings (dropdowns, subjects with tap and drag), parent zone (multiplication gate), progress, play with friends, lobby, results (FFA rows, team panels, cup lines) | Ported to SwiftUI |
| Pause (Continue / Return to menu), saved battle, three-round local cup surviving relaunch, lifecycle save | Ported |
| Texts: English, Hebrew, Spanish, Arabic, Hindi, Dutch; device-language rule; RTL | Ported: the full 820-row Android catalog in `apptext.json` with the same lookup and template logic |
| Sounds (hit, throw, wrong, finish, pickup at 0.35), menu music loop (0.20), question read-aloud | Ported (AVAudioPlayer / AVSpeechSynthesizer) |
| Haptics | Android has none, so none on iOS |
| Online rooms (RTDB protocol, leases, handover, commands, snapshots, checkpoints, results, cups) | Ported (`OnlineSession.swift` + `FirebaseSplashDatabase.swift`); active only when `GoogleService-Info.plist` is bundled |
| Ads, billing, code redemption, UMP | Not ported (by request); the "Ads & purchases" button is hidden |
| Android unit tests | 44 of 46 ported (the 2 `MonetizationTest` cases test left-out code), plus golden parity tests |
| Firebase rules and rules test | Reference copies in `Tests/SplashFirebase/` (byte-identical) |

## Android → iOS file map

| Android | iOS |
| --- | --- |
| `core/SplashEngine.kt` | `Splash/Core/SplashEngine.swift` (`Actor` is `SplashActor`) |
| `core/SplashConfig.kt` | `Splash/Core/SplashConfig.swift` (`Character` is `SplashCharacter`) |
| `core/PlayerSettings.kt` | `Splash/Core/PlayerSettings.swift` |
| `core/Learning.kt` | `Splash/Core/Learning.swift`, `Splash/Core/QuestionFacts.swift` (generated) |
| `core/Gestures.kt` | `Splash/Core/Gestures.swift` |
| `core/Facing.kt` | `Splash/Core/SplashConfig.swift` (`Facing`) |
| Kotlin `Random`, `String.hashCode`, `HashMap` order, stable sorts | `Splash/Core/KotlinCompat.swift` |
| `localization/AppText.kt` | `Splash/Localization/AppText.swift` + `apptext.json` |
| `SplashView.kt` | `Splash/Game/SplashArenaView.swift`, `Splash/Game/SplashPalette.swift` |
| `ArtStore.kt` | `Splash/Game/ArtStore.swift` (`SplashPose` holds the pure pose logic) |
| `MenuMusic.kt`; SoundPool and TTS in `SplashActivity.kt` | `Splash/Game/SplashAudio.swift` |
| `SplashActivity.kt` | `Splash/App/SplashController.swift`, `Splash/App/SplashViews.swift`, `Splash/SplashApp.swift` |
| `LocalBattleStore.kt`, SharedPreferences | `Splash/App/SplashStore.swift` |
| `WorldCodec.kt` (with the `Node` helpers) | `Splash/Net/WorldCodec.swift`, `Splash/Net/Node.swift` |
| `ReplicaEvents.kt`, `ReplicaTimeline.kt` | `Splash/Net/ReplicaEvents.swift`, `Splash/Net/ReplicaTimeline.swift` |
| `OnlineSession.kt` | `Splash/Net/OnlineSession.swift`, `Splash/Net/SplashDatabase.swift`, `Splash/Net/FirebaseSplashDatabase.swift` |
| `SplashAds.kt`, `monetization/*.java` | not ported |
| `assets/art/*.webp`, `res/drawable-nodpi/splash_icon.png` | `Splash/Assets.xcassets/Art/*.imageset` (lossless PNG, pixel-identical) |
| `assets/art/atlas.json`, `directions.json` | `Splash/Art/` (byte-identical) |
| `res/raw/*.mp3` (the six used files) | `Splash/Audio/` (byte-identical) |
| `test/.../SplashCoreTest.kt` | `Tests/SplashTests/SplashCoreTests.swift` |
| `test/.../LearningAcceptanceTest.kt` | `Tests/SplashTests/LearningAcceptanceTests.swift` |
| `test/.../RevisionTest.kt` | `Tests/SplashTests/RevisionTests.swift` |
| `test/.../NetworkStateTest.kt` | `Tests/SplashTests/NetworkStateTests.swift` |
| `test/.../ReplicaEventsTest.kt`, `ReplicaTimelineTest.kt` | `Tests/SplashTests/ReplicaTests.swift` |
| `test/.../LanguageTest.kt` | `Tests/SplashTests/LanguageTests.swift` |
| (golden vectors from the Android classes) | `Tests/SplashTests/AndroidGoldenData.swift`, `KotlinCompatTests.swift`, `EngineParityTests.swift` |
| `firebase/database.rules.json`, `firebase.json`, `rules-test.cjs`, `start-emulators.ps1` | `Tests/SplashFirebase/` (copies) |

## Decisions

- **Exact randomness.** `KotlinRandom` is a bit-exact XorWow (`kotlin.random.Random(seed)`),
  including `nextBits(0)` consuming a value and the rejection loop of `nextInt(from, until)`.
  Questions, option order, balloon colours and layouts and house-player choices therefore match
  Android for the same seed and question secret, so an iOS authority, an Android authority, a
  checkpoint restored on the other platform and saved battles all agree. Golden vectors, captured
  by running the actual Android classes (`app/build/tmp/kotlin-classes/debug` with kotlin-stdlib
  2.2.21) through a scratch Java harness, pin this in `AndroidGoldenData.swift`.
- **Java ordering.** Android iterates Firebase maps as `java.util.HashMap`; the lobby list and the
  host's team assignment follow that order. `JavaOrder.hashMapOrder` reproduces it (checked against
  real `HashMap` output). Cup standings use `String.hashCode() xor seed` exactly. Kotlin's stable
  `sortedBy` is reproduced with `stableSorted`.
- **Renderer.** Android draws immediate-mode Canvas. The closest exact port is a UIKit view drawing
  with Core Graphics (`draw(_:)` with `drawsAsynchronously`), driven by a `CADisplayLink` capped at
  60 Hz, with the static arena pre-rendered into a separate image layer (Android's cached
  `arenaBitmap`). SpriteKit was not used because it would have meant re-modelling every draw call
  and text layout. dp and sp become points one to one. The menus are SwiftUI.
- **Catalog.** The complete Android catalog (820 rows, shared by the Minik games) is stored
  verbatim and in order as JSON rather than Swift literals (type-checker safety). Lookup, `{n}`
  templates (longest key first, stable), padding preservation and the " · " prefix rule are
  identical. Hebrew always comes from the call site, as on Android.
- **Robustness instead of crashes.** Android `require`s that could only fail on corrupt saved or
  network data (roster size, enum names, question validity) return or ignore on iOS instead of
  terminating; normal behaviour is unchanged. Outgoing JSON and Firebase payloads are sanitised
  against NaN and infinity (which the engine never produces).
- **Firebase.** The protocol sits behind a small `SplashDatabase` protocol so the app compiles and
  runs fully offline. A `FirebaseApp` is configured only when `GoogleService-Info.plist` is in the
  bundle. Release builds then use that registration (named app `minik-splash-production`, database
  URL from the plist, paths `minikSplash/rooms/...`). Debug builds mirror Android debug: only the
  local emulator (`127.0.0.1` or `10.0.2.2`, Auth 9099, RTDB 9005, project and namespace
  `demo-minik-splash`), and still only when the plist exists. Without the plist, "Create room"
  shows Android's own message "Production online registration is not activated."
- **Audio session.** Sound effects use the `ambient` category. While the menu loop plays the app
  switches to `soloAmbient`, and it deactivates with `notifyOthersOnDeactivation` when the loop
  stops, mirroring Android's audio-focus gain and abandon around the menu music.

## iOS-only differences

- No system Back button: the in-game "‹" (pause), the page "Back" buttons and "Leave" cover every
  Android Back path; "main-menu Back exits" has no iOS equivalent.
- Lifecycle: scene phase `inactive`/`background` is Android `onPause`, `active` is `onResume` (same
  saving, music, sound and network handling).
- Toasts are a small overlay; dialogs are SwiftUI alerts (pause, and the parent gate with a number
  field).
- The timer digits are always Latin (`m:ss`); Android `String.format` could localise digits.
- The online page shows the development notice and emulator host field only in Debug builds
  (Android shows them in every build because its production online is disabled).
- Fonts are the system font at Android's sp sizes (Android uses Roboto) and do not follow
  Dynamic Type.
- Saved data uses UserDefaults keys named after the Android preference files (`minik_splash.*`,
  `splash_local_battle.battle`, `splash_online.room`) with the same JSON values.
- No `.lproj` / `InfoPlist.strings`: Android does not localise the app name ("Minik Splash").

## Not ported (and why)

- `SplashAds.kt`, `monetization/*` (AdMob, UMP, Play Billing, signed code receipts) and the
  "Ads & purchases" page: ads, purchases and code redemption stay off on iOS for now. The parent
  zone keeps Android's text "Learning and purchases, in one place." unchanged (consider rewording
  once iOS purchases exist). `MonetizationTest` (2 tests) therefore has no port.
- DEBUG-only QA hooks (`qa*` intent extras, `qa-state.json`, visual-capture preferences): Android
  test tooling, not product behaviour.
- `androidTest` device tests (real touch, typography and language captures): they drive the
  Android view hierarchy; their behavioural assertions are covered by the ported unit tests. iOS
  UI tests can be added once the app has run on a simulator.
- Unused Android files: the untinted `splash_0..5.webp` (intermediate exports ArtStore never
  loads), the legacy `sfx_throw.mp3`, and the launcher foreground (the iOS `AppIcon` was provided
  separately).
- The Firebase rules test was not run: it needs the Firebase emulator and CLI, which could not be
  guaranteed to stay fully offline here. Android's run (65 checks, local emulator only) is
  recorded in `BUILD_STATUS.md`. To run it locally: `Tests/SplashFirebase/start-emulators.ps1`,
  then `node Tests/SplashFirebase/rules-test.cjs` (both still point at the Android machine's
  dependency paths).

## Activating online play later

1. Register the iOS app `com.appsbybros.minik.splash` in the approved Firebase project and add its
   `GoogleService-Info.plist` to `Splash/` (the repository ignores such files by default; add an
   exception like the other apps if it should be committed).
2. Deploy the reviewed `minikSplash` rules (`Tests/SplashFirebase/database.rules.json`) through the
   owner's workflow. No rules were deployed by this port.
3. Release builds then create and join rooms; Debug builds keep using the local emulator.

## Checks run here

- `python Scripts/audit-splash.py`: catalog identical (820 rows); facts identical (24 + 12); every
  English/Hebrew text passed to `tr()` / `AppText.t()` on iOS exists verbatim in the Android
  sources (125 pairs; only the 15 ads/purchase pairs are Android-only); 69 images pixel-identical;
  6 MP3 and 2 JSON files byte-identical; Swift files LF-only with exactly one `@main`.
- Golden vectors from the real Android classes: 6 Kotlin `Random` streams, 8 `hashCode`s, 4
  `HashMap` orders, 168 generated questions, 6 skill-choice sequences, 116 catalog lookups in four
  languages and 54 engine question layouts. A Python mirror of the Swift generator, engine and
  catalog logic reproduced all of them (0 mismatches); the XCTest suite asserts the same.
- Not run: Swift compilation and XCTest (no macOS here).

## Android files read (SHA-256)

| File | SHA-256 |
| --- | --- |
| `ASSET_MANIFEST.md` | `4f00331c31f9ea966954375321294bd18739636d97eafab0e961848d8b41a8a0` |
| `BUILD_STATUS.md` | `c5d55ad85f862a9e02c1289c5c40e232c9b972d5c9ac0ed4d645fe6fb18a0a18` |
| `DECISIONS.md` | `35320b39075a0505ce30a9706042073eb73cae1c8014b20db66521ff8768015c` |
| `EXTERNAL_ACTIONS_REQUIRED.md` | `2e433ad040e4420f9f4e1e5db5e6fc8303b96f566ff51999dfb56f34560db91b` |
| `NEXT_GAME_BRIEF.md` | `83aad9be1aa26eb97a9c10ab6188086e2b8ea73e99004065743a9163deb95c4d` |
| `README.md` | `35ae367f5791aec761e732331e772228cb6e53f0264f0b5b20d229c5b136459e` |
| `app/build.gradle.kts` | `5f3e92fa21b3cc5c334ed8598c2412a2ef3d7e3a7c0882100c33b0c03e5e5199` |
| `app/src/androidTest/java/com/appsbybros/minik/splash/DeviceInteractionTest.kt` | `2a31a587a19f3c501790a7b228e846e25bcdc7a3245f099b93abdbe7a72d8fd4` |
| `app/src/androidTest/java/com/appsbybros/minik/splash/LanguageDeviceTest.kt` | `60fa707c84076d00f2f2395aea6ec245d02746cd9e5f451e86d51610aaed4f56` |
| `app/src/androidTest/java/com/appsbybros/minik/splash/TypographyCaptureTest.kt` | `63172872429925c0bfe1da2e3f294cc15a8847c026c77d9a772ad70d3a8277f3` |
| `app/src/main/AndroidManifest.xml` | `0c8072fb2fef8c302dae95f001eabddbf7e50e966645c453daef7d68c9b23b02` |
| `app/src/main/assets/art/amber.webp` | `aafe40ef9fcef4cea3f79bd59782788bd82e70d7530c79848d37a09e1e72ab15` |
| `app/src/main/assets/art/amber_directions.webp` | `ee8d2aad1ba1c412c208bafa2ea2f222826604c2a5011ba5570f99d30d67bc81` |
| `app/src/main/assets/art/arena_andromeda.webp` | `0a774402d7300cdb0da47b693702488f397edeb6a5c82c576a97f91eaa129b2b` |
| `app/src/main/assets/art/arena_beach.webp` | `d31f1ab3d7f7e526ab8f5a4c3ad6bf25274ecc667958e6635b3dde790806d507` |
| `app/src/main/assets/art/arena_park.webp` | `312e65bacbeb5a7ad5387c40d71f4ede93fcb47889987bc1944d1fc74fb94259` |
| `app/src/main/assets/art/atlas.json` | `84278dde8c760396f4a0d910339fdad3b264794f614ae824f180537bd2785faf` |
| `app/src/main/assets/art/balloon_blue.webp` | `5e5714d323e2e54d6555f575b6523e40d4232cebe5f9401a7e13b641c71c913c` |
| `app/src/main/assets/art/balloon_cyan.webp` | `09e357f0aa6e08516e73add8fe05f9bdef63d577c2230d944224ba4a631d61fc` |
| `app/src/main/assets/art/balloon_green.webp` | `a9b7c59db424495aaf77a470f2ab7330ce6aaa777d04358ca8389875428dd96a` |
| `app/src/main/assets/art/balloon_orange.webp` | `46dcbf9ba96ee4470901eb7028e967fc560fd533ab0fcda88fbbdb51c1331a4d` |
| `app/src/main/assets/art/balloon_pink.webp` | `1000f991dbc32d1cf830d12f259c3e1b0416b4cf0acbfc2264c2cada17ee03af` |
| `app/src/main/assets/art/balloon_yellow.webp` | `01f7d28f388d448b58d063b72ef9ec4d06fea74fd0c732fc65a582ed0cf43fc7` |
| `app/src/main/assets/art/coach67.webp` | `739155051349f81539954c99fffd1a31d65d9d9d05ee3501c3c9005585e4eb51` |
| `app/src/main/assets/art/coach67_directions.webp` | `d3ab6747f0da9c786ee1bb43143ff54884af97938c179cebbb0dd57231b225fd` |
| `app/src/main/assets/art/comet.webp` | `06b716836ef6cb34eb25776a33aa21edd7cdcac6a839d0ee5ce87db9d124a288` |
| `app/src/main/assets/art/comet_directions.webp` | `8f6aa9717679aa596571aaf2aa98fb54506f450a2358d11dfad5c86375562446` |
| `app/src/main/assets/art/directions.json` | `3f919d2a6605ee93ad5390900f417bba0496402c6290407376dc9bb20f567ad3` |
| `app/src/main/assets/art/flare.webp` | `61ecd11f421ada0316691f652a85d3fb5ac31551a55f86a7611d0def5542f22b` |
| `app/src/main/assets/art/flare_directions.webp` | `6c383f6797e4a8542bbb694a75a82aced02141ee2230fff1f8bcb614afe410c2` |
| `app/src/main/assets/art/gaya.webp` | `bcd36629137fbc2ab233e476092a96508cbecb627dd82f3c8cfc9042d50f76a1` |
| `app/src/main/assets/art/gaya_directions.webp` | `c1f535b57fdecdb50ee9f10a00bf33970af28ef67331b4c344e59232a2be0178` |
| `app/src/main/assets/art/june.webp` | `f9c73ae55c447f8124aeb6844ba7307d3669e9fcadba0630e301296434102ffc` |
| `app/src/main/assets/art/june_directions.webp` | `bfc6b9495ccbb72e002b8e6931e9c5a540a54a44363c67fdde6bdfdf8678def5` |
| `app/src/main/assets/art/kyra.webp` | `0401549ca130dd45600d0d1aff3c2989c816fb2497a1bfb484325481122d2f69` |
| `app/src/main/assets/art/kyra_directions.webp` | `f6bd06204137ce02b7fdd872b50e0a5f4fef24743e2a6e7af04dbeab6815030f` |
| `app/src/main/assets/art/lagoon.webp` | `baf843f999ba83a672493ca68bed2da2d2bc9aefc731359b59233f2487e7a839` |
| `app/src/main/assets/art/mia.webp` | `aa7cb8cc5dfbf0788999f4e7fe5d11b9a30acf52653b8e7f184bd962b9d386bc` |
| `app/src/main/assets/art/mia_directions.webp` | `9a967ef72c540d94d3f670b73e72b0a7cbfac46af8ad01c511562fb790b51ae2` |
| `app/src/main/assets/art/minik.webp` | `4ea4b9975bbdbba30240951c79ad38cbbdd6ab2f4bac9e27393dd11290f9eb63` |
| `app/src/main/assets/art/minik_directions.webp` | `e9845311ede62366289194018c709ea088f62e5b61451fe9b59b39fa5474bcdf` |
| `app/src/main/assets/art/miniko.webp` | `1803d53735b1dcaf7e900e02439528bc1a0388e54d7da964067c07d3dd81622a` |
| `app/src/main/assets/art/miniko_directions.webp` | `5289b05c9f632f9462b92f6e9963055b97a26abb39bcba2c1585f6d976713a47` |
| `app/src/main/assets/art/moshiko.webp` | `25c2644fc7e640e3b0797850ed310c70401b6ada519c8c57550c5f4ee458b6f2` |
| `app/src/main/assets/art/moshiko_directions.webp` | `affb1a276e1c002d91b7b6eb5f89fd1b2b49569e95a1e5b91f6f285a82e05691` |
| `app/src/main/assets/art/splash_0.webp` | `208a81fbc46464e8c7e7085d20c445f59bcfa4be9f5b0bfaa30222da5b4bc30c` |
| `app/src/main/assets/art/splash_0_c0.webp` | `f398926fc7593c1e3ce06fad0dabfda555cf32393a4c3d5d22b4464d95f37ac0` |
| `app/src/main/assets/art/splash_0_c1.webp` | `147ae66b0fb7d3b6d2738fe4da77898b3cb2f68aab5a2fb6e89ff03127774535` |
| `app/src/main/assets/art/splash_0_c2.webp` | `e8d7b055790fcbe9eb54477cbc229ff37cfb027c3eac6d8f227f45e0511fb16c` |
| `app/src/main/assets/art/splash_0_c3.webp` | `29171f681a501318c260eae634317b29af7276557a1c8a8656e0eb180c8c0436` |
| `app/src/main/assets/art/splash_0_c4.webp` | `67777d7ca54389a6d080e18687fd732d7df886d7a54d5fe5fda47088249c2100` |
| `app/src/main/assets/art/splash_0_c5.webp` | `5568781d2278dd6fa4e70a431586c0f7572343367389bebc60324f0e555f5c71` |
| `app/src/main/assets/art/splash_1.webp` | `55d0d041d7dba8b27572b6dfcb135ca64c96d79d30fc1681e10a60f5c51657db` |
| `app/src/main/assets/art/splash_1_c0.webp` | `6b5e2aafc54eee8bd106ef76a7c98dc250d7b55cfd41f0a601c65d8f1a9d91f2` |
| `app/src/main/assets/art/splash_1_c1.webp` | `8aa03297bc24605484dec54240559fd7edf2c947423bc1ef0dd70f8981c539d1` |
| `app/src/main/assets/art/splash_1_c2.webp` | `fe5dc2fe17713d656c676ca1643b555c755f2bb1137916c086c7751ce250df34` |
| `app/src/main/assets/art/splash_1_c3.webp` | `8cc2631f37166fb143dffbf7045d2f7a718fd2bf6c3b79e4e7c555e52dbc1e3f` |
| `app/src/main/assets/art/splash_1_c4.webp` | `05b706345d7694b520685063ebd30bbd2a9a815fcf75c393e1cd7369b37fbdfa` |
| `app/src/main/assets/art/splash_1_c5.webp` | `52080b0a7db37bcebc78e8b0de225bef88f8af8a6f04cbe0d10e4dcdd62d78c2` |
| `app/src/main/assets/art/splash_2.webp` | `d00b1d78db7451debb8c5185d63125f4ade27de806bc4808425756829d29775d` |
| `app/src/main/assets/art/splash_2_c0.webp` | `7fa005e4b65b82c5c665159f52ac63531d16e6575d7aa84b91d75a4122587348` |
| `app/src/main/assets/art/splash_2_c1.webp` | `01da5bab20eace4ff8837f18577b425f21b10e5d845e9a2463067d346f61ff3e` |
| `app/src/main/assets/art/splash_2_c2.webp` | `5e8f4aef577d42739987c0293295bf325f5f60e5137e085a7435c325d3ac5c57` |
| `app/src/main/assets/art/splash_2_c3.webp` | `2437af6f1bec85b7851ddaac1b9200ebec971ecf17889260e7db2e34a2e6a2ad` |
| `app/src/main/assets/art/splash_2_c4.webp` | `4e168cb0dce34d79160a9cc7bc1ddb28747fb8d103d4bcd8fa0c5f732c43a7b4` |
| `app/src/main/assets/art/splash_2_c5.webp` | `47505f015526bcee573f3b61049e88bab2dbb06992c2e4bfb285a1d99b61653a` |
| `app/src/main/assets/art/splash_3.webp` | `8e1d9989fbae2f67efa15fbcae8165e95144bbda2992ac10f6e20f29ff1649a2` |
| `app/src/main/assets/art/splash_3_c0.webp` | `c2743d640bd3fa84153c1ea72abb2ea9122fe3a761cdaa8e22465271a80012ef` |
| `app/src/main/assets/art/splash_3_c1.webp` | `7fc9b0586d7eb5e4a797099f11415f892a5d62f4e1c73e7a297e0fccbd9f9c88` |
| `app/src/main/assets/art/splash_3_c2.webp` | `71d10316e8b14a9f9d015bb0633eb937acdaa7e576183ecb0c7c3987e1af1378` |
| `app/src/main/assets/art/splash_3_c3.webp` | `1fc5731173b0aa39fa6ef8aa7e7e8dad1be75d52b783c51d1d2f67d9dc47a0fe` |
| `app/src/main/assets/art/splash_3_c4.webp` | `2e071d70bc59b4e30ffe5071e0bbcef07ce59d62a11da1a9701c2e4fbfbe3933` |
| `app/src/main/assets/art/splash_3_c5.webp` | `355e016a80c601f474111d599927b26a028842b19b3b7a73d7d5d793eef370f3` |
| `app/src/main/assets/art/splash_4.webp` | `45987e2c098850103e8c3d662d621eb8ce566af8c92779e62c9c49aa34145dc8` |
| `app/src/main/assets/art/splash_4_c0.webp` | `1f21a0a7273e296d7f9792414e1278541a53072703cba328e814c2ef8b3fe5f2` |
| `app/src/main/assets/art/splash_4_c1.webp` | `91f6a59e0e07a4768d578997ef3c1f22dafca378c49bd22580f32959d0457f4b` |
| `app/src/main/assets/art/splash_4_c2.webp` | `913b51bb321f7ca06dfa120d354769062d95e6f94f94afd89789a4f8b46211e5` |
| `app/src/main/assets/art/splash_4_c3.webp` | `67f7ede367b055b1a2c4afb2e285439376e3f7d9a94924a05bda566db7426075` |
| `app/src/main/assets/art/splash_4_c4.webp` | `6e859729792075ebcf8a27029fc9cad7c32ffe21c829a645ff4cd28585e261cb` |
| `app/src/main/assets/art/splash_4_c5.webp` | `0b6a3fdd57b40a31cf4674c97e62de8cd956dbe74ee6c4f089b83f460032ba81` |
| `app/src/main/assets/art/splash_5.webp` | `2103a6c1c2a89657d9be5b27f12bc430e0ab2e86fc44a288fe6b5a4fb7a11b10` |
| `app/src/main/assets/art/splash_5_c0.webp` | `9bba6126946e4216120336325155e813d5715c3fb03be01df457664f6cc22a0a` |
| `app/src/main/assets/art/splash_5_c1.webp` | `1c5556f0e2e01f29d5722b937e76ff980c3e1b608715ad9011c8a0505fa2b5aa` |
| `app/src/main/assets/art/splash_5_c2.webp` | `645c867a4374657099a4d2f8ff4850bc5f479f565b768a2a45b0d55f52c29060` |
| `app/src/main/assets/art/splash_5_c3.webp` | `75cfa50b2ca1d0fb9ef87b6d4c9b9892d922b3c6d8e9c54b602efafc6b7bd186` |
| `app/src/main/assets/art/splash_5_c4.webp` | `bb0fb61308acdd58eccf4ce2fc36dd1619e285c22940919e15e2cee3f5a475b6` |
| `app/src/main/assets/art/splash_5_c5.webp` | `805e1e59e524eff1d270bfb152a85bedbaf3030d003f903c8d74ba571e4378cb` |
| `app/src/main/java/com/appsbybros/minik/localization/AppText.kt` | `7bba0d0c8ee52aaa13f08d8c8a8281381224d7c0a0985c05d6cb5dd89e7b5f94` |
| `app/src/main/java/com/appsbybros/minik/splash/ArtStore.kt` | `abbe532f6d7bc73f5db789080df0ec4f0eede9b2033e907344faead0dd211e46` |
| `app/src/main/java/com/appsbybros/minik/splash/LocalBattleStore.kt` | `de08f25341165e4d7259bc9c8b982168d7439397f85826cc9454764fa89f44d4` |
| `app/src/main/java/com/appsbybros/minik/splash/MenuMusic.kt` | `337f60ec6aa501d7d4d150348972a920999f6d1a70d454359c66cfe43fedc55f` |
| `app/src/main/java/com/appsbybros/minik/splash/OnlineSession.kt` | `6b812e64139822ff12601559d0d847d5a8f77b2162d8abdffd64dc9c5514723d` |
| `app/src/main/java/com/appsbybros/minik/splash/ReplicaEvents.kt` | `34afbaf8992f72aa67d98000d6190c2c6615e1c5a6aafdf62c61d948b4aaf129` |
| `app/src/main/java/com/appsbybros/minik/splash/ReplicaTimeline.kt` | `268b5779cd608b48fe5dd116c79cc51c5a33585e5bfa57a4902235eeba60a39f` |
| `app/src/main/java/com/appsbybros/minik/splash/SplashActivity.kt` | `bbb9616250582ef0826dec513a936687de10df0bc1f7decbae87025e1be9a32a` |
| `app/src/main/java/com/appsbybros/minik/splash/SplashAds.kt` | `1cdd48459bf48aa9cdf73fe6e5e30f1e9484acb55fe75976b1d7f471e6480914` |
| `app/src/main/java/com/appsbybros/minik/splash/SplashView.kt` | `8dee92ad6b5b5eb1d2d6e8a106c8191b417802c3ad0f964f3fbecd72a9d98b91` |
| `app/src/main/java/com/appsbybros/minik/splash/WorldCodec.kt` | `e8d59f07115c56f85b31c40d5f4acf24fe0df05fed72d6dea9fdae5b71cfb512` |
| `app/src/main/java/com/appsbybros/minik/splash/core/Facing.kt` | `50949c3f6420ae9f3cefbce0ae080ddd94f96608757ede510cf8936ae844458d` |
| `app/src/main/java/com/appsbybros/minik/splash/core/Gestures.kt` | `2d6e768ca3e9cdd2f95c24c9bbe081efed6e902c904c5c9c870e1ca4e82e5738` |
| `app/src/main/java/com/appsbybros/minik/splash/core/Learning.kt` | `92150dbfdd36d2a7e8f045b1fa117138847b412381d9ce6e5e9e3f263688e07f` |
| `app/src/main/java/com/appsbybros/minik/splash/core/PlayerSettings.kt` | `17359d93d37f1997af44f095ee4bf50580460ac671ead845d5f63273d22631f3` |
| `app/src/main/java/com/appsbybros/minik/splash/core/SplashConfig.kt` | `c1f33c4464d74faca351b8d4a94db332a63d0300c6fb2cb18a0018364bc8b5ee` |
| `app/src/main/java/com/appsbybros/minik/splash/core/SplashEngine.kt` | `c98400e541b68be90d0d127be9dfd85b065429c633f11657b417f5f5137c6708` |
| `app/src/main/java/com/appsbybros/minik/splash/monetization/AdPolicy.java` | `532b4f2c874a968e65847c86871e8d8f83b4e1c63a939a34d95bb1ad39325189` |
| `app/src/main/java/com/appsbybros/minik/splash/monetization/Entitlements.java` | `f98ffb71eb39c76a5fd1cbee3085687fdf56c7319bc7bfb7fb5d68c0a64a02e0` |
| `app/src/main/java/com/appsbybros/minik/splash/monetization/LicenseReceipt.java` | `c2aefe4d1e6451cbaec7c36468bc7814f4bd0033109be4dc8873ec39483f5379` |
| `app/src/main/java/com/appsbybros/minik/splash/monetization/MonetizationConfig.java` | `03ba5e6aa163ade0b26926cb0b9cff12384de14a89a0beec7e95a9c809a836ea` |
| `app/src/main/java/com/appsbybros/minik/splash/monetization/RemoveAdsBilling.java` | `e2b5ae94b78d1d3a1928865bbe997dad78d1108bf1e37029e48cfcc4664de4d6` |
| `app/src/main/res/drawable-nodpi/splash_icon.png` | `3b01da18d243e51253912f60a0ea51d41b1e024e67dd3afe063a8afd893a3d93` |
| `app/src/main/res/drawable-nodpi/splash_launcher_foreground.png` | `7bbb2be5f27f969c6db80fd3d539b1d5303d891ccfdf34a662bdb42441f39642` |
| `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | `cc99622f0edc125b8a35ef724505fc8b43926ba780b3c1d32735ddc78e3bd8d4` |
| `app/src/main/res/raw/cool_music2.mp3` | `8739c47026ed62f4dde407a432d013b151af6d191a3d9a4fc5a0392c9071563e` |
| `app/src/main/res/raw/minik_kick2.mp3` | `d2a6e6eb3191c0498637b24897b420717bcae71c4b73f1ab5237db9c47a802f6` |
| `app/src/main/res/raw/sfx_finish.mp3` | `e5d4f4c8c99745d054493aeb5dc33ad30c0888777ccd327c9747c6ad45c406c1` |
| `app/src/main/res/raw/sfx_hit.mp3` | `de20197edd7aec007b8a3d2e45e6add57163b6878c446e71501e4b51f531980e` |
| `app/src/main/res/raw/sfx_pickup.mp3` | `e36d07f178d49a49ebebdd56ae26dcfd0b9e5a5e4f45024d9eae8ffbe7e8c8e9` |
| `app/src/main/res/raw/sfx_throw.mp3` | `3b5bf005e77004c80e785ad396a4d110f631dd35638117af6e356cfd9e1ad020` |
| `app/src/main/res/raw/sfx_wrong.mp3` | `c3af78f5f0a591aa006b0959aedaa8b20e0224bc7e1454857ac4784807cfd896` |
| `app/src/main/res/values-v31/styles.xml` | `7c02c8df11f62a4e358b1e4eee2561f35393b64525db03457931b7d5943a69a3` |
| `app/src/main/res/values/launcher_colors.xml` | `0e5bcde93f57139648a713b4bbdbd2a6b0718bedf5520cee1953c4d0559dec11` |
| `app/src/main/res/values/styles.xml` | `f827af2dd356a385895e4de94da84bd44aa25f2c4f36cd1b959a23f70ec7cbfa` |
| `app/src/test/java/com/appsbybros/minik/localization/LanguageTest.kt` | `5117994247324664c1255499754de48c2b5c9fe40e2505c62f3656c0d53c8cb0` |
| `app/src/test/java/com/appsbybros/minik/splash/MonetizationTest.kt` | `37433106f4d2fb75da8d3d192f0673696a1de89f2b9765637d6baad51f8b98bd` |
| `app/src/test/java/com/appsbybros/minik/splash/NetworkStateTest.kt` | `5bdfcb8b7d71d5c0d1cf6fee8b58a12250d8e84c07517830bb4ab73fe8b38b09` |
| `app/src/test/java/com/appsbybros/minik/splash/ReplicaEventsTest.kt` | `81f48b587afec128a2f8f3bbbcf80b9a27a01fcdbc4794363c0bd00cc903153b` |
| `app/src/test/java/com/appsbybros/minik/splash/ReplicaTimelineTest.kt` | `168f4ed327c5a775dccebed5c7d5eaed36b13c0522d9c698e07940714f655235` |
| `app/src/test/java/com/appsbybros/minik/splash/RevisionTest.kt` | `dcb6fbb39c1e2bf6e8b0ba901e277564241194450a509d8c10e8d6abbad24ad0` |
| `app/src/test/java/com/appsbybros/minik/splash/core/LearningAcceptanceTest.kt` | `c30b1af916a28a339faa9634162dd9e7cbf9ad2e835081631cd7627add80dfcf` |
| `app/src/test/java/com/appsbybros/minik/splash/core/SplashCoreTest.kt` | `7d528449ec483ade512c4b2f06c6da3737f118fd2bec75c96a1a97a151c84282` |
| `delivery/revision-2026-10-04/REPORT.md` | `2fac949228444a1b74a28d15662a5d7de199d242fddf2f7de848efb471418fd6` |
| `delivery/revision-sdk-branding-2026-10-04/STATUS.md` | `35e332e38b99b69b4f8cecafe7b5a8a622f3ed779b046967337f155929287ab5` |
| `firebase/database.rules.json` | `2a53a90118aac1f1803186cf19aefe5f97056e304e852dec9dc7e08bfb64471c` |
| `firebase/firebase.json` | `7bed1c13d00ec37ca29856ff30af28f00f06509e5a925bc21d66527670dc94f9` |
| `firebase/rules-test.cjs` | `f17140d48f57c7d2baa07d00db30a7e4f6ab19cc721279f55faf08b722b2c229` |
| `firebase/start-emulators.ps1` | `28c3a00402243f93613c6d97a5eded2a27cb62ea3d243678bbc607c34c5d71f2` |
