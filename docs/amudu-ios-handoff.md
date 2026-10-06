# Spud (Minik Amudu / מיניק עמודו) — iOS port handoff

Source: Android project `C:/Projects/MinikAmudu` (read-only; state of 2026-10-04, delivery
`delivery/revision-sdk-branding-2026-10-04`). Target: XcodeGen app `MinikAmudu` (`Amudu/**`, bundle
`com.appsbybros.minik.spud`, display name per language) and test target `AmuduTests`. Nothing in `project.yml`,
`Sources/**`, `MultiPong/**` or `Splash/**` was changed. Nothing was committed, built in CI, deployed or pushed.

## Status

- Full behavior port of every screen, the game rules, controls, house players, sounds, speech, saved games/settings,
  six languages with RTL, localized app names, and the private-room Realtime Database protocol.
- The Swift has **not been compiled** (no Swift toolchain on the Windows machine). It was written against the iOS 17 SDK
  and Swift 5.9 and re-read line by line; see "Least-sure compile spots" before the first macOS build.
- Ads, purchases and code redemption are off (no AdMob, UMP or StoreKit); Android's "Ads & purchases" button is hidden.
- Online rooms activate only when this app's `GoogleService-Info.plist` (bundle `com.appsbybros.minik.spud`, with a
  `DATABASE_URL`) is bundled. Without it, "Join by code" and "Open private room" show Android's
  "Online activation is pending." and everything else runs offline.

## Android file → iOS file

| Android | iOS | Notes |
|---|---|---|
| `core/Models.kt` | `Amudu/Core/AmuduModels.swift` | `Scene`→`ArenaScene`, `Actor`→`GameActor`, `Character(s)`→`AmuduCharacter(s)`, `Event`→`GameEvent`, `Command`→`GameCommand` (Swift/SwiftUI already own those names). Enum raw values are the Kotlin enum names (wire format). |
| `core/AmuduEngine.kt` | `Amudu/Core/AmuduEngine.swift` | Statement-by-statement port: same physics constants, same order of random draws and floating-point operations; `step` split into helpers without reordering. |
| (kotlin.random, Java) | `Amudu/Core/KotlinCompat.swift` | Exact `kotlin.random.Random(seed)` (XorWow), Java `String.hashCode`, `Math.floorMod`, Kotlin trim/isBlank/`toInt`, UTF-16 string order, stable sort, insertion-ordered map/set (`linkedMapOf`, `LinkedHashSet`). |
| `Codec.kt` | `Amudu/Core/AmuduCodec.swift` | Identical field names; NSNull for Kotlin `null`; Booleans and numbers kept apart like Kotlin's `as? Number` / `as? Boolean`. |
| `localization/AppText.kt` | `Amudu/Text/AppText.swift` + `Amudu/Text/AmuduCatalog.json` | All 820 rows extracted in order (`es, ar, hi, nl` columns); `{0}` templates matched like Kotlin (longest key first). |
| `GameText.kt` | `Amudu/Text/AppText.swift` (`GameText`) | Names, stop calls and the 14 branding overrides verbatim. |
| `ArtStore.kt` | `Amudu/Art/ArtStore.swift` | Same frame selection, facing, mirrored side art and 256x320 hand anchors. |
| `AmuduView.kt` | `Amudu/Game/ArenaView.swift` | UIKit view: arena picture in a `UIImageView`, every frame drawn with Core Graphics (the same immediate-mode drawing as Android's Canvas), `CADisplayLink` loop, identical touch arbitration. |
| `SelectionWidgets.kt` | `Amudu/UI/Widgets.swift` | `SkillStars`, `AvatarArrow`, spinner (`ChoiceMenu`), buttons, labels, page scaffold, toast. |
| `AmuduActivity.kt` | `Amudu/UI/AppModel.swift`, `Amudu/UI/Screens.swift`, `Amudu/UI/GameScreen.swift`, `Amudu/AmuduApp.swift` | Screens, settings, dialogs, saved game, event sounds/speech, lifecycle. |
| `OnlineRoom.kt` | `Amudu/Online/OnlineRoom.swift` | Same RTDB paths, transactions, lease/host takeover, 12 Hz snapshots, command queue, huddle protocol. |
| `AmuduAds.kt`, `monetization/*.java` | — | Not ported (ads and purchases off on iOS). |
| `res/raw/*` | `Amudu/Audio/*` | Copied unchanged (all 10 files; `sfx_hit.mp3` is unused on Android too). |
| `assets/art/*.webp`, `tennis.png` | `Amudu/Assets.xcassets/<name>.imageset` | Decoded and re-encoded as PNG, pixel-identical (verified by decode comparison); 1x only, so frame crops use the atlas pixel rectangles. |
| `assets/art/atlas.json`, `directions.json` | `Amudu/Art/` | Copied unchanged. |
| `res/values*/app_name.xml` | `Amudu/{en,he,ar,es,hi,nl}.lproj/InfoPlist.strings` | `CFBundleDisplayName` = Android `app_name` per language. |
| launcher icon | `Amudu/Assets.xcassets/AppIcon` | Pre-existing, kept. |
| `firebase/*` | `Tests/AmuduFirebase/*` | Byte-identical reference copies plus README. |
| `src/test/**`, `src/androidTest/**` | `Tests/AmuduTests/*` | See Tests. |

## Behavior decisions

- **Language**: Android uses the phone's first language (`resources.configuration.locales[0]`), normalized to
  en/he/es/ar/hi/nl (else English; `iw`→`he`). iOS uses `Locale.preferredLanguages.first`, which also reflects the
  per-app language chosen in iOS Settings. Hebrew and Arabic switch the menus to right-to-left; the avatar row stays
  left-to-right as on Android; the arena is drawn in absolute coordinates.
- **Texts**: every user-visible and protocol literal of the Android Kotlin sources is present verbatim in Swift
  (checked by `Scripts/audit-amudu.py`; the only exclusions are ads/billing/QA strings).
- **Physics and timing**: all constants from `DECISIONS.md` (190 ms double tap, 700 ms catch, 100 ms running settle and
  ×0.82 reach, 2.2 s resolve, 24 s huddle, 12 Hz snapshots, gravity/run/bounce per arena, ball tuning, wind 0/0.45/1.5,
  Standard/Easy throw formulas, swipe→power mappings with points ≈ dp). The engine sub-steps at 1/120 s exactly as on
  Android.
- **House players**: the exact four-star table; catch roll `stars/5`, two stars lower while running; identical
  reaction, accuracy and power formulas; Kotlin `Random(seed)` replayed bit for bit, so a seeded local game makes the
  same bot choices.
- **Touch**: Android pointer semantics mapped to UIKit — first finger = `ACTION_DOWN`; the primary finger lifting while
  another stays down = `ACTION_POINTER_UP` (cancels); last finger up = `ACTION_UP`. `postDelayed` → main-queue work items.
- **Sounds and speech**: AVAudioPlayer pools (3 per sound, volume 0.7, `.ambient` session so the silent switch is
  honored); AVSpeechSynthesizer with the phone-language voice, US English for Hindi "STOP!" and for Hebrew Mia/Gaya before
  renaming (Android's rules). Android has no haptics, so none were added.
- **Screen**: kept awake like Android `FLAG_KEEP_SCREEN_ON`; portrait only (already in project.yml).
- **Firebase**: named app `minik-amudu-production` (Android's production app name), configured only from a bundled
  plist whose `BUNDLE_ID` matches and that has a `DATABASE_URL` (without one `Database.database(app:)` would throw).
  Anonymous auth, `.info/serverTimeOffset` clock, root `minikAmudu/rooms/{CODE}`.

## iOS-only differences

- Arena rendering is a UIKit/Core Graphics view. The Android code is immediate-mode Canvas drawing; Core Graphics is
  its direct equivalent and keeps text layout, radial lights and the `DST_OUT` night light pools identical. The drawing
  layer uses at most 2 pixels per point to keep 60 fps on older phones.
- Saved local game: UserDefaults `amudu.saved` holds JSON `{checkpoint, order}`. A Swift dictionary has no order, so
  the roster order is saved next to the Android checkpoint. Other settings use `amudu.*` keys with the Android names;
  the house-player choice is an ordered array.
- Snapshots from Firebase are decoded with actors in UTF-16 key order (Android uses its HashMap order, also arbitrary);
  lobby lines are sorted by slot so the list does not jump; online huddle proposals are listed in key order.
- Dialogs: Android AlertDialogs become SwiftUI alerts (pause, typed nickname, join code), confirmation dialogs (preset
  phrases, funny-word list) and an overlay card for the private nickname huddle (not dismissable, refreshed every
  350 ms). The pause alert cannot be dismissed by tapping outside; "Continue" is that path.
- No hardware back button: pages keep their Back buttons; in the arena the back chevron opens the pause dialog.
- Defensive differences where Kotlin would crash: unknown enum names fall back to defaults, a full room with no free
  slot is skipped, `coerceIn` with an empty range is clamped safely, NaN and out-of-range numbers convert like Kotlin
  `toInt()`. `Skills` clamps to 1…5 instead of throwing (only constants are used).

## Not ported (and why)

- AdMob interstitials, UMP consent, Play Billing "Remove ads", signed code redemption, the parent gate and the "Ads &
  purchases" page: ads and purchases stay off on iOS until the app has its own AdMob IDs and App Store products.
- `AdPolicyTest` (ad frequency policy): its code belongs to the excluded ads stack.
- Debug-only QA hooks (`qaDemo`, `qaCapture`, intent overrides, `qa-state.json`) and the Android debug build's Firebase
  emulator wiring (`127.0.0.1:9098/9006`, demo project): a fabricated `FirebaseOptions` app ID risks a FirebaseCore
  configuration exception; supply a real plist to test online play.
- Instrumentation tests that inject raw `MotionEvent`s or take screenshots: their logic checks are ported as unit tests
  (`DeviceEquivalentTests`); touch injection needs UI tests on a Mac.

## Tests

`Tests/AmuduTests` (XCTest, hosted in the app):

- `AmuduEngineTests` (16), `OctoberRefinementTests` (6), `RevisionTests` (21), `BrandingBallTests` (6),
  `NetworkStateTests` (4), `LanguageTests` (4): ports of every Android JVM test except `AdPolicyTest`, with the same
  seeds and tolerances.
- `KotlinParityTests`: XorWow reference values printed by kotlin-stdlib, `String.hashCode`, `floorMod`, name rules.
- `ProtocolTests`: member/config/command field names and enum wire names against the RTDB rules, JSON validity, saved
  game JSON round trip, Boolean/number separation.
- `DeviceEquivalentTests`: catch pose, back and mirrored frames, the huddle target's neutral pause, Hebrew feedback
  naming the other player, arena command routing, bundled art and audio, localized display names = Android `app_name`.
- `AmuduAppTests` (existing) kept.

Firebase rules: `Tests/AmuduFirebase/rules-test.cjs` ran against the local database emulator jar only (no Firebase CLI,
no network): **106 passed, 0 failed, 0 production writes** (the same count as Android's 2026-10-04 run).

Static audit: `python Scripts/audit-amudu.py` (catalog identical, overrides identical, 0 Android literals missing,
assets present, Swift hygiene: one `@main`, LF endings, balanced brackets, no `try!`). `--hashes` prints the table
below.

## Least-sure compile spots

- `Amudu/Game/ArenaView.swift` — `MainActor.assumeIsolated` inside `DispatchWorkItem`/renderer closures (`afterDelay`,
  `canvas.renderer`); the `@objc` method on the `@MainActor` `DisplayLinkProxy`; callback properties typed
  `(@MainActor () -> Void)?`.
- `Amudu/Online/OnlineRoom.swift` — Firebase iOS signatures: `runTransactionBlock(_:andCompletionBlock:)`,
  `MutableData.childData(byAppendingPath:)`, `observe(_:with:withCancel:)` returning `UInt`, async `setValue`,
  `updateChildValues([AnyHashable: Any])`, `getData()`, `signInAnonymously()`; synchronous `setValue` calls are made only
  from synchronous contexts.
- `Amudu/UI/GameScreen.swift`, `Amudu/UI/Screens.swift` — SwiftUI alerts with `TextField`, the iOS 17
  `onChange(of:) { old, new in }` form, `confirmationDialog(titleVisibility:)`.
- `Amudu/Core/AmuduCodec.swift` — `CFGetTypeID(n) == CFBooleanGetTypeID()` on `NSNumber`.
- `Tests/AmuduTests/DeviceEquivalentTests.swift` — `@MainActor` test methods in a nonisolated `XCTestCase`.

## SHA-256 of the Android files used (for re-sync)

| Android file | SHA-256 |
|---|---|
| `ASSET_MANIFEST.md` | `2b09c9249dfd127d561635c0245f763220d92bdf20c3d24a6e8448791945e83e` |
| `BUILD_STATUS.md` | `29fb6f0e5a819989144d74d5540d9e0e8a821da1042d15d428dc5a33c4256d6c` |
| `DECISIONS.md` | `4b3b4b500f563cc977db57b56efe8d0cc1958f055938f68b87e85c6f4eb9525b` |
| `EXTERNAL_ACTIONS_REQUIRED.md` | `ded11506e23914eaf50e6d143a565e82362ec3dfd1bd7fc54e8aef4aa74f1aba` |
| `README.md` | `7de4257a8011343cb3306a443b6f55fc8d691a811fd1c97866af4a9ef1f0c41b` |
| `app/build.gradle.kts` | `38448d56c92810567d04c3322bd3557064a6c646767f08845877f9e148651c37` |
| `app/src/androidTest/java/com/appsbybros/minik/amudu/DeviceInteractionTest.kt` | `4cf149ff6cc7cfd1967c1cec0eeb3f4cead08886fcc692654d317bb4a3d5b498` |
| `app/src/androidTest/java/com/appsbybros/minik/amudu/IdentityDeviceTest.kt` | `7d3fa7dc893abbdb6c8668a7aca53562eb7978258e534f3eca6a8f24dbb2b093` |
| `app/src/androidTest/java/com/appsbybros/minik/amudu/RefinementDeviceTest.kt` | `420ae7b1cd9ece0f6a91ab716f30214677e9ac6174dbc43ccb34130ba6837552` |
| `app/src/main/AndroidManifest.xml` | `631ce73fefec71142cad9e3cb8d6e838db75fe1bbabdd08502651e4d2f04e4fa` |
| `app/src/main/assets/art/amber.webp` | `aafe40ef9fcef4cea3f79bd59782788bd82e70d7530c79848d37a09e1e72ab15` |
| `app/src/main/assets/art/amber_directions.webp` | `ee8d2aad1ba1c412c208bafa2ea2f222826604c2a5011ba5570f99d30d67bc81` |
| `app/src/main/assets/art/andromeda.webp` | `0a774402d7300cdb0da47b693702488f397edeb6a5c82c576a97f91eaa129b2b` |
| `app/src/main/assets/art/atlas.json` | `84278dde8c760396f4a0d910339fdad3b264794f614ae824f180537bd2785faf` |
| `app/src/main/assets/art/beach.webp` | `d31f1ab3d7f7e526ab8f5a4c3ad6bf25274ecc667958e6635b3dde790806d507` |
| `app/src/main/assets/art/beachball.webp` | `6c06be19bd1c2c84c102afe2dfdf328ab98420285d4cf813340599dd9a08cf54` |
| `app/src/main/assets/art/coach67.webp` | `739155051349f81539954c99fffd1a31d65d9d9d05ee3501c3c9005585e4eb51` |
| `app/src/main/assets/art/coach67_directions.webp` | `d3ab6747f0da9c786ee1bb43143ff54884af97938c179cebbb0dd57231b225fd` |
| `app/src/main/assets/art/comet.webp` | `06b716836ef6cb34eb25776a33aa21edd7cdcac6a839d0ee5ce87db9d124a288` |
| `app/src/main/assets/art/comet_directions.webp` | `8f6aa9717679aa596571aaf2aa98fb54506f450a2358d11dfad5c86375562446` |
| `app/src/main/assets/art/directions.json` | `3f919d2a6605ee93ad5390900f417bba0496402c6290407376dc9bb20f567ad3` |
| `app/src/main/assets/art/flare.webp` | `61ecd11f421ada0316691f652a85d3fb5ac31551a55f86a7611d0def5542f22b` |
| `app/src/main/assets/art/flare_directions.webp` | `6c383f6797e4a8542bbb694a75a82aced02141ee2230fff1f8bcb614afe410c2` |
| `app/src/main/assets/art/foam.webp` | `8f7b30837bb7c8fd6e288ee0ef03ab9f4b484f3a6e10a7c77eb641c61d2968b3` |
| `app/src/main/assets/art/gaya.webp` | `bcd36629137fbc2ab233e476092a96508cbecb627dd82f3c8cfc9042d50f76a1` |
| `app/src/main/assets/art/gaya_directions.webp` | `c1f535b57fdecdb50ee9f10a00bf33970af28ef67331b4c344e59232a2be0178` |
| `app/src/main/assets/art/june.webp` | `f9c73ae55c447f8124aeb6844ba7307d3669e9fcadba0630e301296434102ffc` |
| `app/src/main/assets/art/june_directions.webp` | `bfc6b9495ccbb72e002b8e6931e9c5a540a54a44363c67fdde6bdfdf8678def5` |
| `app/src/main/assets/art/kyra.webp` | `0401549ca130dd45600d0d1aff3c2989c816fb2497a1bfb484325481122d2f69` |
| `app/src/main/assets/art/kyra_directions.webp` | `f6bd06204137ce02b7fdd872b50e0a5f4fef24743e2a6e7af04dbeab6815030f` |
| `app/src/main/assets/art/mia.webp` | `aa7cb8cc5dfbf0788999f4e7fe5d11b9a30acf52653b8e7f184bd962b9d386bc` |
| `app/src/main/assets/art/mia_directions.webp` | `9a967ef72c540d94d3f670b73e72b0a7cbfac46af8ad01c511562fb790b51ae2` |
| `app/src/main/assets/art/minik.webp` | `4ea4b9975bbdbba30240951c79ad38cbbdd6ab2f4bac9e27393dd11290f9eb63` |
| `app/src/main/assets/art/minik_directions.webp` | `e9845311ede62366289194018c709ea088f62e5b61451fe9b59b39fa5474bcdf` |
| `app/src/main/assets/art/miniko.webp` | `1803d53735b1dcaf7e900e02439528bc1a0388e54d7da964067c07d3dd81622a` |
| `app/src/main/assets/art/miniko_directions.webp` | `5289b05c9f632f9462b92f6e9963055b97a26abb39bcba2c1585f6d976713a47` |
| `app/src/main/assets/art/moshiko.webp` | `25c2644fc7e640e3b0797850ed310c70401b6ada519c8c57550c5f4ee458b6f2` |
| `app/src/main/assets/art/moshiko_directions.webp` | `affb1a276e1c002d91b7b6eb5f89fd1b2b49569e95a1e5b91f6f285a82e05691` |
| `app/src/main/assets/art/neon.webp` | `ddf50eac6667be189a34ab233b2b072e6571eef57b74af2b8aae75ceb1906582` |
| `app/src/main/assets/art/park.webp` | `312e65bacbeb5a7ad5387c40d71f4ede93fcb47889987bc1944d1fc74fb94259` |
| `app/src/main/assets/art/tennis.png` | `28dd6f6d70b7bec6d9af9524f7a76326689f9923dfb9900ada258d26fd257595` |
| `app/src/main/java/com/appsbybros/minik/amudu/AmuduActivity.kt` | `332c0db0a76ff96e0cd1b2d9457a31a3ccd0e2f0be0fc567890dc22efe1ecf83` |
| `app/src/main/java/com/appsbybros/minik/amudu/AmuduAds.kt` | `5a04a907a33b0794f135375615288d57dc8ff4d6362a9e5200ed735a0bff9ef5` |
| `app/src/main/java/com/appsbybros/minik/amudu/AmuduView.kt` | `a3cfa36ca5034ec0a5332127491c0980e4b99a5f072b0f0c29ebf5c71b434566` |
| `app/src/main/java/com/appsbybros/minik/amudu/ArtStore.kt` | `1c0288b39bfe75b19b01301432e6deaefdc4252665ff7650d5a67eab3447e860` |
| `app/src/main/java/com/appsbybros/minik/amudu/Codec.kt` | `4b0ca06c8683df22d57ac1c1fc874a612e960f714f39ddf118eb0c2fe03d72de` |
| `app/src/main/java/com/appsbybros/minik/amudu/GameText.kt` | `5db1de7ed80f753dcf35698bb4aca4ffc0c6b8db255f2863b9df22d7c2986fca` |
| `app/src/main/java/com/appsbybros/minik/amudu/OnlineRoom.kt` | `6101c587ecb328caca54acb7df6ddc3aee48c1c0bbe8ee23b0aa26c1c00c84b1` |
| `app/src/main/java/com/appsbybros/minik/amudu/SelectionWidgets.kt` | `777b90fcd0149f757e84803169bec3dc9d0c66334e9e839574740449b5cbb489` |
| `app/src/main/java/com/appsbybros/minik/amudu/core/AmuduEngine.kt` | `9375d2ff7ef743140f3aac4cbc25802d6821c29527c6c3fefcfae9ed03c59fd0` |
| `app/src/main/java/com/appsbybros/minik/amudu/core/Models.kt` | `8e91816d5ca8258bde05273c71695753b8570476071de70241b74da015c4972f` |
| `app/src/main/java/com/appsbybros/minik/amudu/monetization/AdPolicy.java` | `53cb60e56332e62ef6263d2ae009addec3762d51cea25256db25ff1f40c5d528` |
| `app/src/main/java/com/appsbybros/minik/amudu/monetization/Entitlements.java` | `b81b3a1877f0f3754fc4199a96814da84c2cf16ad95e4b74294eccf597285222` |
| `app/src/main/java/com/appsbybros/minik/amudu/monetization/LicenseReceipt.java` | `1e50da0e80bb945190af153bacde135387b63a7d85a1b3da15c8577573f7063c` |
| `app/src/main/java/com/appsbybros/minik/amudu/monetization/MonetizationConfig.java` | `551fea37900fb810bdb849e2db267143502af96eff71286e82ea5b4f16384783` |
| `app/src/main/java/com/appsbybros/minik/amudu/monetization/RemoveAdsBilling.java` | `40334dfbc1c348fdbc2af22338006ebf66f2c9423ef60cba00406f0d1e6597e6` |
| `app/src/main/java/com/appsbybros/minik/localization/AppText.kt` | `7bba0d0c8ee52aaa13f08d8c8a8281381224d7c0a0985c05d6cb5dd89e7b5f94` |
| `app/src/main/res/drawable-nodpi/amudu_icon.png` | `d511d8d1e96f82a84e808434427d9d54da098db15b098a4d4dfd425fe280c730` |
| `app/src/main/res/drawable-nodpi/launcher_ball.webp` | `ddf50eac6667be189a34ab233b2b072e6571eef57b74af2b8aae75ceb1906582` |
| `app/src/main/res/drawable/ic_dropdown.xml` | `05122469fcb5b5cdd9f3cb06f35ffd5ef281bfc53b9e069da13b61a80d0c12a2` |
| `app/src/main/res/drawable/launcher_foreground.xml` | `6f9d9dbe78395e8e260ef626cbb756ad74d589b01bbba69f5a0958052e64d6c2` |
| `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | `976f6ca1864caafdec22af1e8a968059c8549f7769133bc9da72906dda8c502f` |
| `app/src/main/res/raw/ball_catch.wav` | `bb6348a073afe0ddc0d7615df69938f8103777e4655b9bca875addf6d728dace` |
| `app/src/main/res/raw/bounce.wav` | `046f176a0f68b1045ed831d4a039689791e9d55ba0e8ee8b1261f9042bdfcab3` |
| `app/src/main/res/raw/connected.mp3` | `7ef89d2e8bbc02e558b0bdbad3e0ae67b171ff8759e59a24bcd69ba0124f71e8` |
| `app/src/main/res/raw/player_ready.mp3` | `e36d07f178d49a49ebebdd56ae26dcfd0b9e5a5e4f45024d9eae8ffbe7e8c8e9` |
| `app/src/main/res/raw/sfx_finish.mp3` | `e5d4f4c8c99745d054493aeb5dc33ad30c0888777ccd327c9747c6ad45c406c1` |
| `app/src/main/res/raw/sfx_hit.mp3` | `de20197edd7aec007b8a3d2e45e6add57163b6878c446e71501e4b51f531980e` |
| `app/src/main/res/raw/sfx_pickup.mp3` | `e36d07f178d49a49ebebdd56ae26dcfd0b9e5a5e4f45024d9eae8ffbe7e8c8e9` |
| `app/src/main/res/raw/sfx_throw.mp3` | `3b5bf005e77004c80e785ad396a4d110f631dd35638117af6e356cfd9e1ad020` |
| `app/src/main/res/raw/sfx_wrong.mp3` | `c3af78f5f0a591aa006b0959aedaa8b20e0224bc7e1454857ac4784807cfd896` |
| `app/src/main/res/raw/whistle.wav` | `9d89cc81545aef6ef985f00f6acf1ad8a5e2ecb18e5e3f5f9cc24b0509c37929` |
| `app/src/main/res/values-ar/app_name.xml` | `64f738228ccfed9bc2dbbc10077ad85987447056ff0152046fdd090cc7af938c` |
| `app/src/main/res/values-es/app_name.xml` | `9c90194a8c2e8a797a4f42ba1c9ea4439136154939fb5baa16469268f378406b` |
| `app/src/main/res/values-hi/app_name.xml` | `7f2e78d9c212b66ba8d7ce16270eea3b44bdbf88d933f05c2828a04523b12a02` |
| `app/src/main/res/values-iw/app_name.xml` | `2a0cc0bfdb55723842faa581515e3119a9494c13d6884bc4918c76f54fe9a95b` |
| `app/src/main/res/values-nl/app_name.xml` | `c23e51fa9beee38238282acaf945073455a1912dcebd56cf010685facfedd276` |
| `app/src/main/res/values-v27/styles.xml` | `b4e7495a06ecfb77eacdacef9cf89ebb9f2d1176d373d1b7cfd89823b779472c` |
| `app/src/main/res/values/app_name.xml` | `d025d0d91fef4c63a82864e72c76f61fdbd7f150de2f297e9a2747faed762e25` |
| `app/src/main/res/values/launcher_colors.xml` | `b92e7f826723d5ebbbd88b70f4c414d716fbaa536312ef84dd0b18ea7a391546` |
| `app/src/main/res/values/styles.xml` | `4acc0e649e0bcc0fcbc9f5fed0b5b5cbd91ee56fb3e4987a757e99b8df919fd0` |
| `app/src/test/java/com/appsbybros/minik/amudu/AdPolicyTest.kt` | `23fe0de37154442d0089071137d4e860956d8ec4efaeb55cb8ad6918f3364906` |
| `app/src/test/java/com/appsbybros/minik/amudu/BrandingBallTest.kt` | `623c9df9df93c141b41e3ab5784180e7697f83727750f3d10a3b834c9cb052d7` |
| `app/src/test/java/com/appsbybros/minik/amudu/NetworkStateTest.kt` | `88093ed9ea3f275c4cb8c524e83f9e91e89e1cd091375578b37fc49b15eb1bde` |
| `app/src/test/java/com/appsbybros/minik/amudu/core/AmuduEngineTest.kt` | `dfe2c79357f03f9bb23a5aa3227aa771e77a622355ece157f3d0cff8d0579981` |
| `app/src/test/java/com/appsbybros/minik/amudu/core/OctoberRefinementTest.kt` | `a5693d00fc56fb7163b210fc4221a9bf939b11320e1cf479729a1f59733b20ca` |
| `app/src/test/java/com/appsbybros/minik/amudu/core/RevisionTest.kt` | `d1d4ba785b54ba5771856ca5b5a20983a77ae1f816eabc03be5039b47d3ed053` |
| `app/src/test/java/com/appsbybros/minik/localization/LanguageTest.kt` | `5117994247324664c1255499754de48c2b5c9fe40e2505c62f3656c0d53c8cb0` |
| `firebase/database.rules.json` | `74628dae6ab286fafc44a35b91ce734b31755ccedcce091bcf5b8180cb19b688` |
| `firebase/firebase.json` | `8980a41bdbd7e364174987800b571acfefb536320293a4bc2fdae3d7c1510e75` |
| `firebase/rules-test.cjs` | `12c6f3fbcc3d658883720e8060135c15e35167b4d1220e909fdbafead257bbc7` |
| `firebase/start-emulators.ps1` | `28c3a00402243f93613c6d97a5eded2a27cb62ea3d243678bbc607c34c5d71f2` |
