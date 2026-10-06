# Multi Ping Pong (iOS) — port handoff

This document covers the iOS app target `MinikMultiPingPong` (bundle `com.appsbybros.minik.crosspong`, display name
"Multi Ping Pong"). It is a port of the Android app **Multi Ping Pong** (`C:\Projects\MinikCrossPong`, commit
`828c6fc094f3afb05d86fea0616704a17976dfaf`): table tennis for 3 or 4 players on a cross-shaped table. Android forked that app
from **Modern Ping Pong** (`C:\Projects\MinikPingPong`, commit `7f5dd0a844ef8986eacd662f4afbbc34c7e92f56`). The iOS starting
point was `MultiPong/`, a copy of `Sources/ModernPong` that is compiled only into this target. The port keeps the Modern Ping
Pong type names (`MPController`, `MPEngine`, `ModernPongView` and so on), so the shared `Sources/**` code still compiles
unchanged:

- `ModernPongView(experience: .full, commerce: commerce)` is used by `Sources/PingPongOnlyRootView.swift`.
- `ModernPongView(experience: .simple, commerce: commerce) { result in … }` is used by `Sources/RetroPong/MathPingPongChooser.swift`.
- `ModernPongExperience` (`.full` / `.simple`) and `ModernPongResult` have the same declarations as before.

The Android repositories were used read-only. Nothing in them was changed.

## What changed in this repository (all uncommitted)

| Area | Files |
| --- | --- |
| New game core | `MultiPong/CrossGeometry.swift`, `CrossBall.swift`, `CrossReferee.swift`, `CrossShots.swift`, `CrossHouse.swift`, `CrossEvents.swift`, `CrossState.swift`, `CrossEngine.swift`, `CrossMatch.swift`, `CrossLink.swift`, `CrossText.swift`, `CrossTutorial.swift` |
| New court renderer | `MultiPong/CrossScene.swift` (SpriteKit) |
| New tournament logic | `MultiPong/MPGroupMatch.swift` |
| New room UI | `MultiPong/ModernPongRooms.swift` |
| Rewritten | `MultiPong/MPMultiplayerModels.swift`, `MPKnockout.swift`, `MPController.swift`, `ModernPongView.swift` |
| Edited | `MultiPong/MPRepository.swift`, `MPMatchLink.swift`, `MPEngine.swift`, `MPPreferences.swift`, `MPAds.swift` |
| Resources (this app only) | `Resources/MultiPongAssets.xcassets`: `mpx_app_icon` plus the `mpx_legs_*` and `mpx_bot_*` sheets of amber, comet, flare, gaya, june, mia and moshiko, converted from the Android `webp` files to PNG |
| Project | `project.yml`: one entry in the `MinikMultiPingPong` sources, `Resources/MultiPongAssets.xcassets` (resources build phase) |
| Unit tests | `Tests/MultiPongTests/*.swift` (`MultiPongAppTests.swift` kept as it was) |
| Firebase rules mirror | `Tests/MultiPongFirebase/**` |
| This document | `docs/multi-pong-ios-handoff.md` |
| Audit script | `Scripts/audit-multi-pong.py` |

`git status` also lists `MultiPong/MPTuning.swift` as modified, but `git diff` shows no content change. The file's line
endings differ from what `core.autocrlf` expects, and that is the only difference.

Nothing under `Sources/**`, `Sources/ModernPong/**`, other targets, other apps' resources, workflows or other scripts was
touched.

Regenerate the Xcode project with XcodeGen (`xcodegen generate`) before building, because `project.yml` gained the asset
catalog.

## Android → iOS mapping

| Android (828c6fc, `app/src/main/java/com/appsbybros/minik/pingpong/`) | iOS (`MultiPong/`) |
| --- | --- |
| `cross/CrossGeometry.kt` | `CrossGeometry.swift`. It also holds the rest of Kotlin `Random` on top of `MPKotlinRandom`, `crossMod` and `crossFold`. |
| `cross/CrossBall.kt` | `CrossBall.swift` |
| `cross/CrossReferee.kt` | `CrossReferee.swift` |
| `cross/CrossShots.kt` (shots, `AimMap`) | `CrossShots.swift` (`CrossShots`, `CrossAimMap`) |
| `cross/CrossHouse.kt`, `HouseStrategy.kt`, `RallyVariation.kt`, `ActorPresentation.kt` (timing) | `CrossHouse.swift` (`CrossHouse`, `CrossStrategy`, `CrossVariation`, `CrossMotion`, `CrossForecast`, `CrossActor`, `CrossHouseStrategy`, `CrossServeReliability`) |
| `cross/CrossEvents.kt` (`CrossEvent`, `Cue`, `CrossSoundPolicy`) | `CrossEvents.swift`. Cues map onto the existing `MPAudio` samples. |
| `cross/CrossState.kt` (wire format, protocol 2) | `CrossState.swift` |
| `cross/CrossEngine.kt` | `CrossEngine.swift` |
| `cross/CrossMatch.kt` (stages, elimination, goals) | `CrossMatch.swift` |
| `cross/CrossLink.kt` (checkpoints, actions, authority) | `CrossLink.swift` |
| `cross/CrossText.kt` | `CrossText.swift` (EN/HE verbatim) |
| `cross/CrossTutorial.kt` | `CrossTutorial.swift` |
| `cross/CrossCourt.kt`, `BotArt.kt`, `SpriteSampling.kt`, `MinikMotion.kt` (cross parts) | `CrossScene.swift` |
| `cross/CrossActivity.kt` | `MPController.swift`: local cross game, tour, settings, result, pause and restart. `ModernPongRooms.swift`: `crossGame`, `crossSettings`, tour cards and result view. |
| `multiplayer/PlayActivity.kt` | `ModernPongView.swift` (home, controls, house-player carousel, profile, create/join forms, room lists, help, result) and `ModernPongRooms.swift` (lobby, seat lobby, tournament roster, play list, bracket, group bracket, standings). Flow logic is in `MPController.swift`. |
| `multiplayer/PrivateMatchActivity.kt` | `MPController.launch` and `MPMatchLink.swift` (classic two-player fixtures), `ModernPongView.classicMatchScreen` |
| `multiplayer/PongModels.kt` (`Session`, `MatchRecord`, `PongRules`), `CrossFixture.kt`, `ControlChoice.kt` | `MPMultiplayerModels.swift` (`MPSession`, `MPFixture`, `MPRules`, `MPSequenceGate`, …), `MPGroupMatch.swift` (`MPCrossFixture`), `MPKnockout.swift` (`MPControlChoice`) |
| `multiplayer/GroupMatch.kt` | `MPGroupMatch.swift` (`MPGroupTournament`, `MPTableSimulation`) |
| `multiplayer/Knockout.kt`, `CompletionText.kt`, `MatchText.kt` | `MPKnockout.swift` (`MPKnockout`, `MPCompletionText`, `MPMatchText`, `MPKotlinRandom`) |
| `multiplayer/KnockoutBracketView.kt` | `MPKnockoutBracketView.swift` (classic bracket) and `ModernPongRooms.groupBracket` (group tables per round) |
| `multiplayer/PongCodec.kt`, `PongRepository.kt`, `FirebasePongRepository.kt` | `MPRepository.swift` (`MPCodec`, `MPRepository`, `MPLocalRepository`, `MPFirebaseRepository`, `MPRepositoryOrder`) |
| `multiplayer/MatchLink.kt` | `MPMatchLink.swift` |
| `multiplayer/BotRoster.kt` | `MPRoster.swift` (unchanged) and `MPRules.housePlayer` / `copyNumber` (house copies "Kyra 2", …) |
| `multiplayer/RoomBook.kt` | `MPPreferences.swift` (saved rooms, completion and celebration flags) |
| `multiplayer/LobbyAudio.kt`, `LobbyEvents.kt` | `MPController.lobbyCues` + `MPAudio` |
| `multiplayer/Nicknames.kt` | `MPNames` in `MPPreferences.swift` (existing) |
| `multiplayer/ExpandButton.kt`, `MenuExpansion.kt`, `MenuScrollView.kt`, `SettingSelector.kt`, `BotPicker.kt`, `HousePlayerPicker.kt`, `GuideDialog.kt` | SwiftUI equivalents in `ModernPongView.swift` (`expandHeader`, `controls`, `carousel`, `housePicker`, `help`) |
| `VictoryConfetti.kt` | `MPVictoryConfetti` (existing, `MPKnockoutBracketView.swift`) |
| `ModernEngine.kt`, `ModernGame.kt`, `ModernEvents.kt`, `Tuning.kt`, `ModernTutorial.kt`, `ModernCourt.kt`, `ModernAudio.kt` | Classic two-player game kept from Modern Ping Pong: `MPEngine.swift`, `MPPhysics.swift`, `MPTuning.swift`, `MPTutorial.swift`, `MPScene.swift`, `MPAudio.swift`. The fork's changes are ported: `suddenDeath` (1:0 tie-break), `alternateServe`, and the Beginner aim reset. |
| `LocalizedActivity.kt` | The `hebrew` flag from the app language, with RTL layout (since 2026-10-04: `MPText`, six languages; see the update at the end) |
| `NetworkState.kt` | The repository connection state (`connected` / `connecting`, offline note) |
| `monetization/*` | Not ported (see below). `MPAds` has no ad unit. |

## Feature inventory

**Ported**

- **The 3/4-player game:**
  - Geometry: arms, territories, radial nets, centre post, and the round hub for 3 players.
  - Ball physics in fixed 1/120 s substeps.
  - Referee: a miss gives the striker +1 and the responsible receiver −1; a fault costs only its owner 1; nobody drops below 0. The serve rotates every rally. Each rally resolves exactly once. Classic and elimination scoring.
  - Shots and aiming (Beginner, Standard, Pro), house players (strategy, variation, serve reliability, timing), the cross guide (tutorial drills and the guided tour), and the event and sound policy.
- **Court (SpriteKit):**
  - Per-seat rotation (your seat at the bottom), and an overview / full-screen camera toggle that is remembered (`MPPreferences.crossFullScreen`).
  - Scoreboard, name tags, +1/−1 notes, receiver highlight, an off-screen ball arrow, and upright characters with legs.
  - Pause, restart and settings: players, control, target, opponents.
- **Home and flows, as on Android:**
  - Friendly tables of 2, 3 or 4 seats, with a seat lobby (take or change your own seat; the host places house players).
  - Tournaments of classic pairs (round robin 2–8, knockout 2–9) or group tables of 3/4 (round robin 3–8, knockout 3–32), including the elimination game type.
  - Group round-robin points 3/2/1/0, group-knockout "top two" with tie-breaks, duels and walkovers, and knockouts of any size.
  - The classic bracket and the group bracket.
  - A court pauses while a human of the fixture is away, and resumes from the latest checkpoint after the app returns from the background.
  - Completed entries are not kept in the saved-room list.
  - Completion texts, headlines and confetti.
- **Online code:**
  - The Firebase root is `minikCrossPong`, under the Android app name `minik-cross-pong`.
  - The wire format and the CrossLink protocol (protocol-2 checkpoints, the actions ring with seat/stage/rallyId/hitIndex/strike, `MPSequenceGate`, authority = smallest human uid) are byte-compatible with Android records.
  - Firebase arrays and index maps are both accepted, and so are legacy `a`/`b` pair records.
- **Offline:**
  - Without a `GoogleService-Info.plist` for `com.appsbybros.minik.crosspong`, `MPFirebaseRepository.configured()` returns nil and the app uses `MPLocalRepository`.
  - Nothing crashes. Practice, local cross games, the guide, local friendly tables with house players and the house-only tournaments all work.
  - The forms show the Android offline note. Join says "Online rooms are not available in this version yet."
- **Ads and purchases off:** there is no ads or purchase UI and no ad request (`MPAds.interstitialUnit` is always nil, so the Google SDK is never started from `MultiPong/`).
- **Texts:** English and Hebrew are verbatim from Android, with RTL. Since the 2026-10-04 update (end of this document) also
  Spanish, Arabic, Hindi and Dutch from Android's catalog, with RTL for Arabic too.

**Partial**

- **Online play is ported but dormant.** No Firebase registration file for `com.appsbybros.minik.crosspong` exists in `Config/Firebase/`, and none was added: creating one would need the Firebase console or API, which this port was not allowed to use. Online rooms start working once a plist for that bundle id (project `minikswish`) is placed in the target's resources. `MPFirebaseRepository.configured()` checks the bundle id and the project. The database rules candidate (`Tests/MultiPongFirebase/rules/merged.json`) has not been deployed.
- **Art.**
  - The seven characters with Android legs sheets use the Android body and legs art (`mpx_*`).
  - Kyra, Coach67 and Miniko use the existing shared Modern Ping Pong atlases (`mp_bot_*`) without separate legs, as before.
  - Fonts, exact sizes and colours follow SwiftUI/SpriteKit defaults close to Android, not pixel-identical.
- **Commerce.** `Sources/RootView` (shared, not editable here) may still start the shared commerce controller for this product variant. Multi Ping Pong shows no purchase UI and makes no ad request, but a StoreKit product query by shared code is outside `MultiPong/`. Check this when App Store products exist.

**Not ported, and why**

- **Android monetization:** `monetization/*`, `AdCoordinator`, `RemoveAdsBilling`, `MonetizationActivity`, access codes and `monetization-backend/`. The task requires ads and purchases off.
- **Android device QA tooling** (`tools/*.cjs`, `firebase.device-qa.json`): this is Android/ADB-specific.
- **Rules generator and production reader** (`firebase/generate-rules.cjs`, `knockout-rules.cjs`, `read-production-rules.cjs`, `live.rules.template.json`): the iOS mirror stores their outputs (`rules/crosspong.fragment.json`, `rules/merged.json`, `rules/current.json`) and never reads or deploys production.
- **Android-only unit tests:** monetization, Firebase activation through Gradle properties, sprite sampling of Android bitmaps, and the Modern Ping Pong engine tests that are unchanged in the fork. See the test section.

## Decisions

- **Invalid input is clamped, not rejected.** Where Android `require`s valid input (geometry seat count, referee target, classic scoring with more than two players, start scores, match goal), the Swift port clamps or corrects the value instead of throwing. A corrupt online record can therefore never crash the court. Restores of checkpoints still throw (`CrossStateError`) and are rejected as a whole, as on Android.
- **CrossLink constructor.** The four Android `require`s in the `CrossLink` constructor (2–4 players matching the match, seat
  kinds in fixture order, the fixture's first server, a networked match when there are remote humans) are not repeated in
  Swift. `MPController` always builds the match from `CrossLink.seats` and `CrossLink.firstServer`, so they hold by
  construction.
- **CrossLink writes outlive the link.** The checkpoint, action and result writes run in `Task`s that hold the link
  strongly, as the Kotlin repository callbacks do. The last checkpoint written by `close()` therefore still reaches the
  database when the owner drops the link immediately (`crossLink?.close(); crossLink = nil`).
- **Tolerant records.** `MPBot` and `MPIdentity` decode like Android `PongCodec.bot` / `PongCodec.identity`:
  - A missing stat reads as 5 and a missing skill as the accuracy.
  - Every decoded value is `safe()`.
  - One older or partial house record can no longer fail the whole participants map of a room.
  - A new duel fixture stores its authority like every other fixture.
- **Android behaviour restored after review:**
  - **Local repository** (`MPLocalRepository`):
    - It reads its store on every call, so two instances agree.
    - It refuses a duplicate code.
    - It stamps creation and activity times, but `mutate` stamps activity only on a real change.
    - It keeps checkpoints only in UserDefaults, refuses to store a non-plist value, and removes them on leave.
  - **Room flows:**
    - `refreshRooms` skips failures instead of failing as a whole.
    - A failed room transition only affects the room still shown, and `maybeStart` is revisited only after a success.
    - Returning from the background reattaches the full room observer without stale cues.
    - A friendly house player's seat is chosen inside the transaction.
  - **Forms and results:**
    - Friendly rooms are created with legs 1 and win points 3.
    - "Points to win" opens at 7.
    - A finished local match does not show its result again after the guide.
- **Kotlin `Random` parity.** `MPKotlinRandom` replays `kotlin.random.Random(seed)` (XorWow) exactly: `nextInt`, `nextInt(until)`, `nextDouble`, `nextDouble(from, until)`, `nextBoolean`, `nextLong`, `shuffled`, `random`. Seeded house players, table simulations and knockout draws therefore choose as on Android. The values were checked against kotlin-stdlib 2.1.0 (see `KotlinRandomParityTests`).
- **Classic first server.** The first server of an online classic fixture is the authority, as in the Android rule. The old iOS copy used `match.a`.
- **Local strike identity.** Android publishes a local strike when it is a new object (`!==`). iOS numbers strikes (`CrossEngine.localStrikeID`) instead.
- **Live action order.** Buffered live actions are applied in (rallyId, hitIndex, sequence) order (`MPRepositoryOrder`), which also covers Firebase delivering children out of order.
- **Presence.** Lobby presence follows Android `syncLobbyPresence`. iOS uses one presence for lobby and court, so a court about to launch keeps it rather than dropping and reopening it.
- **Re-entrancy.** `MPLocalRepository` notifies synchronously, so presence acquisition and release, and `MPSubscription.close`, are re-entrancy safe.
- **Assets.** The Android `webp` files were converted to PNG, giving about 21.8 MB.

## iOS differences

- **Rendering.** SpriteKit replaces Android Canvas. The table outline is unioned with `CGPath` set operations (iOS 16+), the far end of the table is drawn with the same perspective factor, and the full-screen camera follows the local seat.
- **Navigation.** Navigation is SwiftUI routes (`MPRoute`) instead of Android activities. Back follows the Android order.
- **Language.** Hebrew comes from the app or system language rather than an in-app language activity. Since the 2026-10-04
  update the app follows the primary device language like Android `LocalizedActivity` (see that section).
- **Lifecycle.** The app returning to the foreground re-opens the room observer and, for a fixture court, returns to the lobby. The court then re-opens from the latest checkpoint, like Android `onResume`.

### Known smaller differences

These were found in review and left as they are. None affects scoring, the wire format or the rules.

- **Court:**
  - When the engine is swapped (an elimination stage change), `CrossScene` cancels the touch in progress and clears the floating +1/−1 notes. Android keeps both.
  - The ball shadow is a solid ellipse rather than Android's radial gradient.
  - A room's cross match screen also shows the overview / full-screen button.
- **Lists:**
  - The friendly participant row and the house-player and "mine" lists are ordered by id. Android uses map order.
  - The profile avatar is picked from a grid instead of Android's house-player picker with a "Use this character" button.
- **Records:**
  - `MPSession` decodes `participants`, `connections` and `seats` as whole maps: one malformed entry empties that map. Android decodes them entry by entry.
  - A house profile outside the roster (impossible in the new `minikCrossPong` namespace) uses the roster tuning formula, not Android's generic accuracy formula.
- **Local (offline) repository, inherited from Modern Ping Pong iOS:**
  - Presence is one slot per player, not one token per subscription.
  - `observe` sends nothing for a missing room.
  - `leave` drops a local tournament instead of applying the tournament leave rules.
  - A duplicate code reports the generic error text.
- **Controller messages and flows:**
  - A classic match-link error shows as an alert, not as the inline warning line.
  - Cross-link failures show "Connection interrupted…" rather than the raw message.
  - There is no dedicated "Another player connected" text when a delete is refused.
  - A new identity starts at nickname 0 instead of a random one.
  - A fixture that finishes while the app is in the background shows the room on return, not the result dialog.
- **Classic engine** (unchanged `Sources/ModernPong` behaviour):
  - House controls apply only when the engine has a bot.
  - The lowest level has no separate "move the paddle" status.
- **Pure-function differences** that tests document:
  - Invalid group-table shapes return an empty design or simulation instead of throwing.
  - `MPMatchText` has no `standing` builder and no three-argument `summary` builder. Neither is used by the Android UI.

## Tests

### Unit tests (`Tests/MultiPongTests`, target `MultiPongTests`, `@testable import MinikMultiPingPong`)

The suite has 291 ported XCTest methods plus the existing `MultiPongAppTests`. Every method names its Kotlin original in a
`// Kotlin: <name>` comment. Where Kotlin `require`s and Swift clamps, the test asserts the clamped value; each such
place is commented "Swift clamps instead of throwing". Kotlin assertions that cannot run on iOS are written as
`// Not ported: <name> — <reason>` comments. Shared helpers (Kotlin `CrossTestSupport.kt` and `CrossEngineSupport.kt`)
live in `CrossTestSupport.swift`.

| Kotlin test (828c6fc) | Swift file | Ported / Kotlin |
| --- | --- | --- |
| `cross/CrossGeometryTest` | `CrossGeometryTests` | 12/12 |
| `cross/CrossBallTest` | `CrossBallTests` | 13/13 |
| `cross/CrossRefereeTest` | `CrossRefereeTests` | 19/19 |
| `cross/CrossShotsTest` | `CrossShotsTests` | 15/15 |
| `cross/CrossBeginnerAimTest` | `CrossBeginnerAimTests` | 3/3 |
| `cross/CrossControlTest` | `CrossControlTests` | 12/12 |
| `cross/CrossHouseTest` | `CrossHouseTests` | 8/8 |
| `cross/CrossEventsTest` | `CrossEventsTests` | 3/3 |
| `cross/CrossRallyTest` | `CrossRallyTests` | 3/3 |
| `cross/CrossExerciseTest` | `CrossExerciseTests` | 3/3 |
| `cross/CrossMatchTest` | `CrossMatchTests` | 7/7 |
| `cross/CrossModesTest` | `CrossModesTests` | 10/10 |
| `cross/CrossNetworkTest` | `CrossNetworkTests` | 9/9 |
| `cross/CrossLinkTest` | `CrossLinkTests` (in-file fake repository) | 11/11 (two constructor `assertThrows` not ported) |
| `cross/CrossAdversarialTest` | `CrossAdversarialTests` | 24/24 |
| `multiplayer/GroupTournamentTest` | `GroupTournamentTests` | 12/12 |
| `multiplayer/GroupMatchModelTest` | `GroupMatchModelTests` | 16/17 (`lobbyReadyCueListensToEverySeat`: the cue logic is private in `MPController`) |
| `multiplayer/GroupMatchAdversarialTest` | `GroupMatchAdversarialTests` | 15/15 (two partial) |
| `multiplayer/MatchTextTest` | `MatchTextTests` | 4/4 (`standing` and the 3-argument `summary` builders do not exist on iOS) |
| `GameModeTournamentTest` | `GameModeTournamentTests` | 19/19 |
| `ClassicTiebreakTest` | `ClassicTiebreakTests` | 3/3 |
| `ClassicFixesTest` | `ClassicFixesTests` | 2/2 |
| `KnockoutTest` | `KnockoutTests` | 12/12 |
| `MultiplayerTest` | `MultiplayerTests` | 20/20 |
| `RoomPolicyTest` | `RoomPolicyTests` | 5/6 (`noticesUseStableMatchIds…`: iOS retired the notice book; nickname validator checks not ported) |
| `LobbyPauseTest` | `LobbyPauseTests` | 2/2 |
| `TournamentUpdateTest` | `TournamentUpdateTests` | 7/8 (LobbyEvents / RoomStartGate are private `MPController` state) |
| `FriendlyFlowTest` | `FriendlyFlowTests` | 3/3 |
| `UnifiedFriendlyTest` | `UnifiedFriendlyTests` | 3/3 |
| `BotRosterTest` | `BotRosterTests` | 8/9 (atlas cell mapping is private in `CrossScene`) |
| `PeerMatchTest` | `PeerMatchTests` (in-file fake repository) | 3/3 |
| — (iOS only) | `KotlinRandomParityTests` | 5 (reference values from kotlin-stdlib 2.1.0) |

**Not ported**

- **Monetization tests** (`monetization/*Test.java`, 59 tests): ads and purchases are off in this app.
- **`FirebaseActivationTest`** (Gradle properties) and **`SpriteSamplingTest`** (Android bitmaps): these are Android-only. The iOS equivalents are `Tests/MultiPongFirebase/tests/configuration.test.cjs` and the asset catalog.
- **The unchanged classic-engine tests:**
  - `ModernEngineTest`, `ModernDifficultyControlTest`, `ModernFollowupTest`, `ModernRefinementTest`, `ModernTutorialTest`, `SwipePhysicsTest`, `ServeFlightRegressionTest`, `PointPowerTest`, `PracticeRallyTest`, `BeginnerAndStrategyTest`, `MinikMotionTest`, `ControlAndCompletionRegressionTest` and `ProfileAvatarTest` (102 tests).
  - These files are byte-identical to Modern Ping Pong `7f5dd0a`. Their iOS counterpart is the classic engine `MPEngine`, which is unchanged from `Sources/ModernPong` apart from the fork's three changes (sudden-death tie-break, alternating network serve, Beginner aim reset). That engine has no XCTest suite in this repository either.
  - Its seeded RNG (`MPRandom`) is not Kotlin's `Random`, so most of these exact-rally tests would need redesign rather than a port.
  - The three fork changes are covered by `ClassicTiebreakTests`, `ClassicFixesTests`, `MultiplayerTests` and `PeerMatchTests`.
  - Porting them was started but stopped by the account usage limit. Suggested follow-up.

**Expected to differ at runtime** (faithful assertions kept):

- **The bidi tests** in `MatchTextTests`, `GroupTournamentTests` and `GroupMatchModelTests` lay out text with CoreText instead of `java.text.Bidi`. They need CoreText to treat Unicode isolates the way Java does.
- **Statistical tests seeded through `MPRandom`** (`BotRosterTests`, `ClassicFixesTests`) keep only Kotlin's bounds.
- **Long simulations** (`CrossAdversarialTests`, `CrossMatchTests`, `GameModeTournamentTests`, `GroupMatchAdversarialTests`, `CrossLinkTests`) take tens of seconds in a Debug simulator build.

Nothing here has been compiled or run. This Windows machine has no Swift toolchain. The checks that were run are listed below.

### Firebase rules (`Tests/MultiPongFirebase`)

The folder mirrors the Android `firebase/` verification:

- **`rules/`**
  - `merged.json`: byte-identical to `firebase-setup/merged-database-rules.json`.
  - `current.json`: the live-rules snapshot the merge was checked against.
  - `crosspong.fragment.json`
- **`tests/`**
  - `crosspong.test.cjs` and `pingpong-regression.test.cjs`: verbatim except for the three rule-file paths.
  - `configuration.test.cjs`: rewritten for iOS. It checks the `minikCrossPong` root, the `minik-cross-pong` app name and the bundle id in `MPRepository.swift`, the closed root, and this folder's emulator configuration.
- **`firebase.json`** (database emulator on 127.0.0.1:9000) and **`package.json`** (`npm run test:emulator` with `--project demo-minik-crosspong`).

Result on 2026-10-03, local Firebase RTDB emulator only: **64 tests, 64 passed, 0 failed**.

- The run used the Android `firebase/node_modules` (firebase-tools 15.31.0, cached database emulator v4.11.2) through `NODE_PATH` and JetBrains Runtime 21.
- Isolation:
  - It ran from a scratch copy of the folder, with an empty firebase-tools configstore (no login token, MOTD marked fresh).
  - A preloaded Node guard refused every non-loopback DNS lookup or socket in every Node process. Its log stayed empty.
  - Nothing was deployed, and no Firebase or Google service was contacted.

To rerun on a Mac, from the folder:

```sh
npm ci
npm run test:emulator
```

## Checks run

- **Syntax:** every `MultiPong/*.swift` and `Tests/MultiPongTests/*.swift` file parses without errors with tree-sitter-swift. Bracket balance was checked as well (`Scripts/audit-multi-pong.py`).
- **Compile review:** line-by-line, against the real declarations, for all new and changed production files and all test files. Definite compile risks were fixed (expression splits for the type checker). Doubts are listed in the final report.
- **Static audit:** `python3 Scripts/audit-multi-pong.py [--android <MinikCrossPong checkout>]` checks:
  - the shared entry points;
  - the Firebase root and registration;
  - that no ad unit is configured;
  - the rules-mirror hash;
  - `@testable` imports;
  - bracket balance;
  - optionally, every Android SHA-256 below (all 138 matched).
- **Kotlin `Random` parity:** the Swift algorithm was replayed in Python and compared with values printed by kotlin-stdlib 2.1.0 on the JBR, for int seeds, negative seeds and long seeds. They are identical.
- **Firebase rules:** passed in the local emulator, as above.


## SHA-256 of the Android files used

Hashes are of the committed blobs at `828c6fc` (`git show HEAD:<path> | sha256sum`). Some working-tree copies on the
Android machine have CRLF line endings, so their working-file hashes differ. `MinikPingPong@7f5dd0a` was used only as the diff
base, to find what the fork changed, and is not listed.

Kotlin sources (all of app/src/main/java/com/appsbybros/minik/pingpong) (57 files):

```text
97e6c175c9bcfde4eb07e42150a9b5306e889cca8ed46df5c74446a49947a197  app/src/main/java/com/appsbybros/minik/pingpong/ActorPresentation.kt
53411f3236c67bf7edfa5ff798e653332114c480b33d2dd4598cbbe14dfa3ca4  app/src/main/java/com/appsbybros/minik/pingpong/BotArt.kt
d608d34e48c417833e0097c5d8b41f87bebf3721c5176b528acd3e7085134cfd  app/src/main/java/com/appsbybros/minik/pingpong/BotPicker.kt
304c724bfca95022b9ea6ff5e939bd6043371535963783ca8450d1117122c9d9  app/src/main/java/com/appsbybros/minik/pingpong/GuideDialog.kt
e6d7507d355864d9d66eeab6afaf408329fde450a61ba49500ea4a226969f473  app/src/main/java/com/appsbybros/minik/pingpong/HousePlayerPicker.kt
b490e3c79d8b28314c6f1c966ea350a744e9bbcfdc92f3d5bae242bac9766989  app/src/main/java/com/appsbybros/minik/pingpong/HouseStrategy.kt
5ce242740ee0d17e5127b8fd6a90bc12d583c9cc923d52f86111f2dfdb8ebfd8  app/src/main/java/com/appsbybros/minik/pingpong/LocalizedActivity.kt
f152395827b3e876c91159278332b85023acb71a3a6633cfd2f183af1ee02bec  app/src/main/java/com/appsbybros/minik/pingpong/MinikMotion.kt
ceb76971f7db7ab0b653ff950daf20f1273362352f1b6fc00ab1535b9b0d02fe  app/src/main/java/com/appsbybros/minik/pingpong/ModernActivity.kt
8c3d6bc0c7891ab7143223269b28057106d142cf7c26ceea7bfe4e4d5086ca25  app/src/main/java/com/appsbybros/minik/pingpong/ModernAudio.kt
d670bf97dff1c82dff8574073e354024315eb40796ae9d363167103790b8654d  app/src/main/java/com/appsbybros/minik/pingpong/ModernCourt.kt
1dbfeb8393f3eaebc673d566819a1446742302633e85c387491b892a13460e48  app/src/main/java/com/appsbybros/minik/pingpong/ModernEngine.kt
ba7e218ec5a9bb30448306d90d44ac14808d4648cd02c6f57f5c43962950ab45  app/src/main/java/com/appsbybros/minik/pingpong/ModernEvents.kt
ba6b2b6fe56196466c7dcaa7d173e46e05f804d625b452cac83dc5f3f5227757  app/src/main/java/com/appsbybros/minik/pingpong/ModernGame.kt
2dc6e620d4fffe644beff37ec3efc4cc7255b3036db01abd34c4a6c5407cb3e7  app/src/main/java/com/appsbybros/minik/pingpong/ModernTutorial.kt
5bab7bec089943d870f98aef0daa7a28ecfb7904d0eb308673a826d216680660  app/src/main/java/com/appsbybros/minik/pingpong/NetworkState.kt
948f4ce9e37c370e52ddfa428ee195aabbf0067aa169a2d0509554cda0370dc0  app/src/main/java/com/appsbybros/minik/pingpong/RallyVariation.kt
17655c1f408bbf82082fe422606572e2b6f3390b3c67669678f84bee23fb8d2c  app/src/main/java/com/appsbybros/minik/pingpong/SettingSelector.kt
d657d63391fbd3002c38933b847fabb89a1bf0291c3a439a7a7402806782e5ed  app/src/main/java/com/appsbybros/minik/pingpong/SpriteSampling.kt
d8791489501a20a8f3694bdd901c36b49915e6ac5e233cd767f088d15acb16cb  app/src/main/java/com/appsbybros/minik/pingpong/Tuning.kt
37be9d496034a3b9aaaac518077d62146996270c88a50fc828d9972547a55d4a  app/src/main/java/com/appsbybros/minik/pingpong/VictoryConfetti.kt
04b812d709ed7744c4c697cc86ea3798608ff44dd6564a75c829a4a180d06314  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossActivity.kt
ba5bfe0e3638e7b18e753139197b573ed3f495ffa21c2c83bceff0df01acb0b5  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossBall.kt
da5aee266ab9ffd04b09e4a67c3214cc15141462e52927699a27e1384d61cc7c  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossCourt.kt
ed7ad7b40b8d38cb34e0ec1d276e8f69d912aaa07da89dfa9d018cffd9a66880  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossEngine.kt
ecd8868d326a0d57dc672db01b04d5dc54ec86c62c6e8035a658d09ae8f03dcc  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossEvents.kt
191f173cbbcb4c5ccb668dfec2dd9e47dd6ee073c233911496fc8ff584d77fa8  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossGeometry.kt
5e6d5593367aa6eb92fac1c8cfec02c0afdcaef6b0c4efc6ff9bd5127e9e6b05  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossHouse.kt
0f394b8ec83c3a4b7dbb0cce1a7a857fbc03ac499157686eed5b5206d1a0adfa  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossLink.kt
a12f2a0ace4d02acc6fe8d12e8a3f73e7d9e9236db36f00070c66c274347cafd  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossMatch.kt
6d6032dce2482e7b3f34c84826ba28bd5f8d9fd1b693de3822283be572e37017  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossReferee.kt
b108a98176700ff7a3849fbfa4a394b7d6474094bd3f9a503f2c369673348f98  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossShots.kt
b64dbe9ad8ec6f79107a8a7be40a4091bcdd262860ad50d5d97988b37b4686c0  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossState.kt
7b76a63d4b0fe97f80f0bc73021fddaa3f3b5fa7b83003fb8773fa0af9abd011  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossText.kt
c61071e1be2f1fd9684f2006819ba8050d46263a64cdc90ff133690bd9113313  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossTutorial.kt
8e1908d4c70eef01554e4f791a682e5a348a3995a4585abbbb89af3fbd51a6cf  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/BotRoster.kt
a3617644fc37ef82321cc572bb56b7ee20697a7944b6c42a0ea6a6fedde257e2  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/CompletionText.kt
38e45acb652bb02bd3971c0105b1222597e1e99910dede2c5c0b0a695b744ee5  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/ControlChoice.kt
02675891e0d31c9999770178c72b6d41a5271672c11737e73b3d91448ab3289a  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/CrossFixture.kt
24f8cab6dd3db9d999b810ca7a9cb3537ca794dd164f940eee14e034583facc5  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/ExpandButton.kt
d7051174bceb3c709b0613b4dec7c90c787a31df4872fcfcc50b6502af411329  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/FirebasePongRepository.kt
b98b694830f12fcc8f8f0429e4bd5fc864056ecc0b311f2ddb4ec0ff6f784f3f  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/GroupMatch.kt
899d32e0792f2fa99eb4eae2a4819d323732d493d24b7ec399dd9dc3618e36af  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/Knockout.kt
830e7ec204c7bfa49974dda54612e24534b8c5f8622c793808f2e510edb8bbf0  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/KnockoutBracketView.kt
a06c683dc320e2dc049ffef10cb2c0fcf5b48d1277d8e97c950183958aa4afd2  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/LobbyAudio.kt
9305c1faca41d216793755116ecd230971e23cf4caa5bc6fe478488120ac60e3  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/LobbyEvents.kt
338a9ae241843c6d87110ff58d262ae8c5d2f999e6cec7633ce5390488dce874  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/MatchLink.kt
97bc53ff08c82928ad0f13f7f2de87763fc1d7707c634e9b4cc8d6c052663e35  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/MatchText.kt
1558269ac8f2769cbc6cc9710912362a5395b87d39bd20218385700f50e258b3  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/MenuExpansion.kt
5ba15a361ad0228240d11ccb6a8455ea11c0b18e9a61714b48aa513aa5451320  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/MenuScrollView.kt
fb11e7c8107f69796da0c88582ff5c33156577596dc5bb3476f11a9cc45c823f  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/Nicknames.kt
58ffec013e635a031c09386211991597fb4c1753696b362fda7c301c81c01a41  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PlayActivity.kt
9729c963acd3e00b624e340d25904eac4a34c4f5ef9bc79f54661a92241e4ed8  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PongCodec.kt
04f18d46abdd90a2d854ef98bbc0d7eda617fd5cd8b57840f795df318c85f42f  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PongModels.kt
38fd94419a96512c56a01209ec2c2f2dcee6308a21019df11ac72357fbc57a92  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PongRepository.kt
319b74c97a900086763fe6c1f2813ab4bc7451c664f163defb35339385542119  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PrivateMatchActivity.kt
254ad8380f31fb7f494c5d3c24f089199714afd8cb0e02341dbe6b0dec4e2c34  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/RoomBook.kt
```

Resources (texts and converted art) (17 files):

```text
2e5554dcc9f38d99310dbec5d544a1365266e56b09df3a0108613ce99182f8e9  app/src/main/res/values/strings.xml
df77ba589c4d4bce3c871455bf6dfa37dd1d1a3d38109532fe14cd76bc56f712  app/src/main/res/values-iw/strings.xml
bb61cf126def0c0b2f1af4f34c3171b93770723f694dd42949e25229a97f5085  app/src/main/res/drawable-nodpi/app_icon_cross.webp
9b18d3c8b42cd646453882eea3204b10c42c82bff4fdf308fc202d48530db90e  app/src/main/res/drawable-nodpi/bot_amber.webp
e1d069ebd454d1eeb05263f29660b5d5ab22389291e07635e290718acf6b691a  app/src/main/res/drawable-nodpi/legs_amber.webp
3cb9a966ac623eb356f931b8e94e3e21cb748fcebafd7455f702902f406234f8  app/src/main/res/drawable-nodpi/bot_comet.webp
f8644286e5bb1008ba56904ae800be3e047e8bc41bc8e1978506794febddc644  app/src/main/res/drawable-nodpi/legs_comet.webp
565696812d7edb0cf800bb1a21de35e2ff91841dff37174e6ae69f2753ad55d1  app/src/main/res/drawable-nodpi/bot_flare.webp
bbb9f43e786c1eb0e6a7537467a17eb6e16dde2b4c498f26855567f3a3f57341  app/src/main/res/drawable-nodpi/legs_flare.webp
4f463df6fd2004d56ad60bfe8dfafbddf39854a0ed13dddf9ab4078c3a900d4a  app/src/main/res/drawable-nodpi/bot_gaya.webp
a728d62881fd123254b2eba3a49cd1624347955db8227e19ae69e5820591fcc3  app/src/main/res/drawable-nodpi/legs_gaya.webp
3144cabf603f9b99591cd189bf6f0d0d771feb6bc9cb50de97491dfcb623192a  app/src/main/res/drawable-nodpi/bot_june.webp
0399abc1a296958ad0ad90f4dbe61b79206c72d3e2e1e8dec0565631ef11422b  app/src/main/res/drawable-nodpi/legs_june.webp
ddc80c99c253a16325083883bfd9432dea5f20f2e7c2330ccf2db6242ecae032  app/src/main/res/drawable-nodpi/bot_mia.webp
c51d3848ece1b05fdc14400a85740cf5c6055f943245fe3b40f1a16cd17cd7e9  app/src/main/res/drawable-nodpi/legs_mia.webp
4487ad66fbae95be4469ce91e4c0ac1c2e6b130227667d8416ad2c58cb1ed628  app/src/main/res/drawable-nodpi/bot_moshiko.webp
5b04765ecaadca0d24706096bea9a01ec9ca114e7b0722ee4b4e6c8d48549e50  app/src/main/res/drawable-nodpi/legs_moshiko.webp
```

Unit tests (app/src/test, ported or reviewed) (54 files):

```text
3357b9d3135a69226aa108f0472c1597680a66ac7264d5c8bf4e2a15ee9dcdd5  app/src/test/java/com/appsbybros/minik/monetization/AccessCodesContractTest.java
0a2c7a7df3b90cec6ef6c8dbfea5130d9b702bcfbf227d41b5abf14f6d6fb6f9  app/src/test/java/com/appsbybros/minik/monetization/AccessTokenRulesTest.java
818e643f0fe9d3f12ee385015063a61aec1d9ddba1eedc7c8cbbe8077695f730  app/src/test/java/com/appsbybros/minik/monetization/AdPolicyTest.java
959f8ef51b2622ca38903468a490d59f1ab1c7a5cdb2f36ec1f13646ca7d6f32  app/src/test/java/com/appsbybros/minik/monetization/EntitlementStoreTest.java
45f938e0850f7f8c6a96b81f86d786dca8dcbbf22d69be18e64212518f0580ac  app/src/test/java/com/appsbybros/minik/monetization/LicenseReceiptTest.java
dfbdb53b01e219f5952c01e107f503f389e1e5f0d1a93ebd5effd483bdbef50d  app/src/test/java/com/appsbybros/minik/pingpong/BeginnerAndStrategyTest.kt
bfac0b3965ed78593556448775f4a34b703fbf21a8d0038d2184efec28624c78  app/src/test/java/com/appsbybros/minik/pingpong/BotRosterTest.kt
7ea3267a1db951d2709f99fe8d1b968a7821b66b31d2422c098ffeeef015c215  app/src/test/java/com/appsbybros/minik/pingpong/ClassicFixesTest.kt
350be385df7ff2a1324932eb5bbb879f224e7c7dfb02f5953025865c18332e7e  app/src/test/java/com/appsbybros/minik/pingpong/ClassicTiebreakTest.kt
70e7d70943027ebb2f02908d81362519d9a2fbf2b25d83376fbc598ddda767c5  app/src/test/java/com/appsbybros/minik/pingpong/ControlAndCompletionRegressionTest.kt
283f75e8bbdc0b296bcc710aff9c709cfc9b034243c034d576a4bee59b1628cc  app/src/test/java/com/appsbybros/minik/pingpong/FirebaseActivationTest.kt
a26d4f90ceeb60c2b0dfeb03f0321f91cefc86438e7a022e3f9370a61dee51d1  app/src/test/java/com/appsbybros/minik/pingpong/FriendlyFlowTest.kt
aa9024e861dea092c401bb128edda5eb2ab88a55c7ecb1727536f577955eeadc  app/src/test/java/com/appsbybros/minik/pingpong/GameModeTournamentTest.kt
1b6fa92e5b406e7e03f8711f4ee01e28bfea71856ac31c46429b06163da1abf2  app/src/test/java/com/appsbybros/minik/pingpong/KnockoutTest.kt
bd927c709c9ab96aa453601beef875f57077300311a81988e2826c7b78307cb0  app/src/test/java/com/appsbybros/minik/pingpong/LobbyPauseTest.kt
40bd0310d709dc66fa78156b7cc019e7b1b178d1943aecc058f1dd2302d2dd6a  app/src/test/java/com/appsbybros/minik/pingpong/MinikMotionTest.kt
f151396b23f93535b13e453462bcdc6859e83840d7dc3fd18ae1c1a30daf936a  app/src/test/java/com/appsbybros/minik/pingpong/ModernDifficultyControlTest.kt
f889c4b088a44cf19e8f0e0c4d548ea55a9df0b9837f70ce6c5019e06e913bbb  app/src/test/java/com/appsbybros/minik/pingpong/ModernEngineTest.kt
199506c5ce09639a04708eb58ec095e523bfa76fdbf2024a916eef0725bc76be  app/src/test/java/com/appsbybros/minik/pingpong/ModernFollowupTest.kt
896e7619b83df04278dda1a95656ec57b944b5624a407c3f1f19ad555b0ea202  app/src/test/java/com/appsbybros/minik/pingpong/ModernRefinementTest.kt
d3eb80365ebe7fcbef01ab24dada8e41c88e84a6eae8740b5257712fc1b338cb  app/src/test/java/com/appsbybros/minik/pingpong/ModernTutorialTest.kt
37e47c55c4806df3c691baaff128b5283da8acc6b3c55166dc08230b328c6846  app/src/test/java/com/appsbybros/minik/pingpong/MultiplayerTest.kt
b326eb2c4ac91b49262d7d426f6796cc57870e45d59bee0f013fef2b8cb9f4a5  app/src/test/java/com/appsbybros/minik/pingpong/PeerMatchTest.kt
18072c570aa208dc54e393c283f0e06348929e914c85284165a600b5482d11b6  app/src/test/java/com/appsbybros/minik/pingpong/PointPowerTest.kt
eef15534c5c9a9d05d5edb000c48c6b3cbab8c71f2fd8f18e32588e10c8d5603  app/src/test/java/com/appsbybros/minik/pingpong/PracticeRallyTest.kt
b953ea9a6d1ab27271efd903b4766601eeb933a1289344d2f8e7ea15332e85f0  app/src/test/java/com/appsbybros/minik/pingpong/ProfileAvatarTest.kt
8f0707218249891ea3e8d781d3bb79881aba27be9bf2054ad890782289a80d5a  app/src/test/java/com/appsbybros/minik/pingpong/RoomPolicyTest.kt
de7c430f2701c74c8d6c09ceaa3f3634139943b2d56f52ee742c9ccc43f4d3b2  app/src/test/java/com/appsbybros/minik/pingpong/ServeFlightRegressionTest.kt
0cf449d4c37adf327135f198cfef9cbb31aab047e50c81f03f0c69a5b4ab3892  app/src/test/java/com/appsbybros/minik/pingpong/SpriteSamplingTest.kt
51bcf40f69bec38c50ba3e60b3d8d9e4968c6de88602ba0684b03fa43a91f98c  app/src/test/java/com/appsbybros/minik/pingpong/SwipePhysicsTest.kt
34994da24a112664ab03b4ab435780c28e808e722d8b563ff3c08ac4899d01f2  app/src/test/java/com/appsbybros/minik/pingpong/TournamentUpdateTest.kt
6bfe1129902dc28e6b06e23015bad6d56164d927f74823d01b571634a66155d0  app/src/test/java/com/appsbybros/minik/pingpong/UnifiedFriendlyTest.kt
942abb567bea0108290878b4dbf0a29ee34f1fe219dd3241302e8f6b234130f9  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossAdversarialTest.kt
ba595d6a2f5b6872e643879ffed659a5b2ae1bb6d1383f84779099c1a1f56680  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossBallTest.kt
42062fbf25c34f5c7c5e320988b90f26d92ffe585598f0244fdc44dd7c00ab68  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossBeginnerAimTest.kt
d44429f3e8f70e9f85a3e8296119b332dd01b499127b20265dbdcf1af18343b9  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossControlTest.kt
53d0e46da002a2897dfffc380db7c0a9c0c25c1c42d9f3d347cd992556abab40  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossEngineSupport.kt
c550ee08e122a7df11e23f81b4281f5dc141e532839bd87a3f1841047869033c  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossEventsTest.kt
2722d47e42ddf86171e02200db9301cd9b606c14cf4335462a8326161b382c76  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossExerciseTest.kt
098e28eb89b6eb31a94f4eb65595bd03401fbebd48a755902fc87bbf16e308e4  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossGeometryTest.kt
8272e2fac76efd58df71850aed6563d06b2e4e2d18c304faffe88929c1578fd8  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossHouseTest.kt
95aaa23ba1181b22aa7e74f105849fe801339d2c28da6e3f8ea7147d58c8ff7d  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossLinkTest.kt
c021b9838c671a06f2936fbda3785e968d86b7e362c465a1d895087a115d7484  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossMatchTest.kt
3b995f5267f8a2b1813718ddea2132b239a2b3a901adfb6c986c8222a639a353  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossModesTest.kt
e7efabf7323de7155f923df0eb7fac64941eb7f52ee2c289ecd339cdbc76e992  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossNetworkTest.kt
76865cedc6b81b0a4888ab3ca7a7b83be30d28bff86eaf0f62fbf7075b02ec4c  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossRallyTest.kt
06e2012004d02e00bd6fc660d162e6834061ff414a81b055cbe357e73a014944  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossRefereeTest.kt
a405b34c9e73f9910f29e8ebcb8ea8a33af026521452741f0f213b06c86291c5  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossShotsTest.kt
bdbd279ef7eaf6ba02f8ebaa62e669d7a059000caa0db61fde9203b0f55713e9  app/src/test/java/com/appsbybros/minik/pingpong/cross/CrossTestSupport.kt
279934726be9876962d37b6a8ef63c2ab56a8461b4e8cf7e9cb054fe4b5b8949  app/src/test/java/com/appsbybros/minik/pingpong/multiplayer/GroupMatchAdversarialTest.kt
0c91635db7026b8429c0a3aa7d18409d212ad4452780ae98028c37b43258d265  app/src/test/java/com/appsbybros/minik/pingpong/multiplayer/GroupMatchModelTest.kt
2e0c7e39588e6e98a100a71d1f7d08f126d68112fc3b141a1557282d9ceffe2d  app/src/test/java/com/appsbybros/minik/pingpong/multiplayer/GroupTournamentTest.kt
8ede08976a4cf47d96209ca5ea89bef51f72c834eadd9598c01e26eef8ffd6e6  app/src/test/java/com/appsbybros/minik/pingpong/multiplayer/MatchTextTest.kt
0304ce7735d4f4f4ee4723126eb245ccd12e26a6f6e22dc8534ff3db93164156  app/src/test/java/org/json/AndroidJsonForTests.kt
```

Firebase rules, tests and configuration (9 files):

```text
5b679aed52eec99c7704f4bbc6e58fae83dd58958cf626f239791a7958d8a93c  firebase/README.md
91067b0b5f51b3cd70cf8959f4579037626f538933670b691ccfc03a1691e4b6  firebase/crosspong.rules.fragment.json
3d44d94a6cad6b9364fd76f6e1b21016e857dd96b54f9be303a0279041d4798f  firebase/package.json
cdb470a1640237b0bc40eae0cdd688fda0238a2a33220aae5c2224139f3df231  firebase/tests/configuration.test.cjs
e0fcfd485ad48079b395d62f6bed296535e4a60a864a28e540b3209d734ef8df  firebase/tests/crosspong.test.cjs
911482b5e9da99ce3aa4a21a37b50a45f506a31bfc2785ee605c97a936ea9732  firebase/tests/pingpong-regression.test.cjs
eb60d8c525bf443018dff3c1a420b3646dc323f06cd4240aea6d8c70fa48750b  firebase-setup/current-database-rules.json
3b5c89c44c5bb4182fa4b6303fd5b4315578c134d0258e1df89a01591a9a27f8  firebase-setup/merged-database-rules.json
67ee6a435147a9802fce092951a1a5a60934c1ea77536fd34f6d833009371131  firebase.emulator.json
```

Design reference (1 files):

```text
89d04d8c3d903b37a964bd00ef26a515c9250b8695053006f6762ea09a2f9c7c  docs/CROSS_DESIGN.md
```

## Update 2026-10-04: six languages (Android working tree on 828c6fc)

Source: the uncommitted working tree of `C:\Projects\MinikCrossPong` on top of `828c6fc` (the delivered revision in its
`delivery/revision-2026-10-04/`). It adds Spanish, Arabic, Hindi and Dutch to English and Hebrew with one catalog,
`localization/AppText.kt`, and passes the game's English/Hebrew text pairs through it. Android's `firebase/` did not change, so
`Tests/MultiPongFirebase/` did not change either. The Android repository was only read.

### What changed in this repository (uncommitted)

| Area | Files |
| --- | --- |
| New | `MultiPong/MPText.swift` (Android `AppText`: language rules and lookup), `MultiPong/MPTextCatalog.swift` (its 820 rows, generated from `AppText.kt`), `Tests/MultiPongTests/LanguageTests.swift` |
| Edited | `MultiPong/CrossText.swift`, `CrossTutorial.swift`, `MPKnockout.swift`, `MPKnockoutBracketView.swift`, `MPGroupMatch.swift`, `MPMultiplayerModels.swift`, `MPController.swift`, `ModernPongView.swift`, `MPTutorial.swift` |
| Project | `project.yml`: only the `CFBundleLocalizations` of `MinikMultiPingPong`, now `[en, he, ar, es, hi, nl]` |
| Audit | `Scripts/audit-multi-pong.py` (see "Checks run" below) |
| This document | this section and three pointers above |

The edited and new files have LF line endings. Git's index already stores LF for them, so the line endings add no diff.
`Sources/**`, other targets and the Firebase mirror were not touched. No `xcodegen` change is needed beyond the one plist value.

### Language rules (Android `LocalizedActivity` and `AppText`)

- **Device language.** The app language is the primary device language (`Locale.preferredLanguages.first`), read again whenever
  `ModernPongView` is created, as Android reads it in every activity. Only the language part counts ("es-MX" is Spanish; iOS
  "_" separators are accepted too), "iw" is Hebrew, and any language other than the six is English.
- **No in-app choice**, as on Android. Android's only override is a debug-build extra for its screenshot test, which is not
  ported. On iOS a language can be tried with the Xcode scheme's App Language or with the app's own Language row in the
  Settings app, which iOS reports as the first preferred language.
- **Right to left.** Hebrew and Arabic lay out right to left: the whole screen, its sheets and its alert (the layout
  environment is now the last modifier of `ModernPongView.body`), the back arrow, and the knockout bracket's cards, titles and
  player rows. As on Android, the bracket's column order (and its scroll anchor) stays mirrored for Hebrew only.
- **Host locale.** The shared `Sources/RootView` gives this app only an English or Hebrew `\.locale` and layout direction.
  `ModernPongView` no longer reads `\.locale`; it sets its own direction.
- **Names never translate.** House-player names, nicknames, stored names and network values never pass through the catalog:
  Hebrew names in Hebrew, English names in every other language, as on Android.

### How a text is looked up (`MPText.t(en, he, hebrew)`, Android `AppText.t`)

1. `hebrew` true: the Hebrew text.
2. English (or Hebrew with `hebrew` false): the English text.
3. Spanish, Arabic, Hindi, Dutch: the catalog row with exactly this English text.
4. Else the first `{0}` key that matches the whole text (longest key first, catalog order between equal lengths, each `{n}`
   as short as possible); its `{n}` are filled with the matched names and numbers.
5. Else the row of the text without its leading and trailing spaces, keeping those spaces.
6. Else a " · " prefix is kept and the rest looked up.
7. Else the English text.

`MPText.t(en)` (Android `AppText.t(en)`) uses the English text as the Hebrew one. The Swift ports call it exactly where the
Android working tree does, including the two double lookups: the whole rally outcome in `CrossText.outcome`, and the guide's
control line in `CrossTutorial.card` (its control name is translated before the line is looked up).

### Android → iOS mapping (working tree)

| Android (working tree on 828c6fc) | iOS |
| --- | --- |
| `localization/AppText.kt` | `MPText.swift` (`normalize`, `configure`, `configureFromDevice`, `language`, `rtl`, `t`, `translated`, `keys`; `MPTextTemplate` for the `{n}` keys) and `MPTextCatalog.swift` (the rows in Android order; regenerate with `python3 Scripts/audit-multi-pong.py --android <MinikCrossPong> --write-catalog`) |
| `res/values-ar`, `values-es`, `values-hi`, `values-nl` `strings.xml` | Not copied. Each of their 103 strings except four (the app name "Multi Ping Pong", "Minik" and two format-only strings, identical in every language) is a catalog row with the same translation in all four languages, so iOS shows them through `MPText`. This was checked string by string. |
| `LocalizedActivity.kt` (language, RTL, Back) | `ModernPongView.init` (`MPText.configureFromDevice()`), `he`, `t`, `backButton` and the layout direction; `MPController.hebrew` and `MPController.text` |
| `GuideDialog.kt` (RTL) | The guide card and the sheets read in the screen's direction |
| `BotPicker.kt`, `HousePlayerPicker.kt` | `ModernPongView.housePicker`, `carousel` and `statsLine` |
| `ModernActivity.kt` | Not applicable. Its three changed texts ("Match finished", "Opponent: ", "Select") belong to Android's local classic screen, which this port does not have. The Simple experience's own texts go through the same `t`. |
| `cross/CrossActivity.kt`, `multiplayer/PlayActivity.kt`, `PrivateMatchActivity.kt` (`tr`) | `ModernPongView.t` (also used by `ModernPongRooms.swift`) and `MPController.text` |
| `PlayActivity.avatarNames` | `ModernPongView.avatarName`: the six profile icons get these spoken names (they had no accessibility name on iOS) |
| `PlayActivity` share text (`AppText.rtl` gravity) | `ModernPongRooms.friendlyRoom`: leading alignment, which is right in Hebrew and Arabic |
| `cross/CrossText.kt` | `CrossText.swift` |
| `cross/CrossTutorial.kt` | `CrossTutorial.swift` (`controlName`, `side`, the control line, "Return the ball to …") |
| `multiplayer/Knockout.kt`, `CompletionText.kt`, `ControlChoice.kt`, `MatchText.kt` | `MPKnockout.swift` (`MPKnockout`, `MPCompletionText`, `MPControlChoice`, `MPMatchText.duelTitle`); `TournamentFormat.title` is `MPTournamentFormat.title` in `MPMultiplayerModels.swift`. `advanceText` stays English/Hebrew, as on Android. |
| `multiplayer/GroupMatch.kt` | `MPGroupMatch.swift` (`MPGroupTournament.stage`) |
| `multiplayer/PongModels.kt` | `MPMultiplayerModels.swift` (`MPGameMode.title`, `explanation`) |
| `multiplayer/KnockoutBracketView.kt` | `MPKnockoutBracketView.swift` |
| `test/.../localization/LanguageTest.kt` | `LanguageTests.swift` |
| `androidTest/.../LanguageDeviceTest.kt` | `LanguageTests.testSixDeviceLanguagesResolveTextsAndDirection` (in part) |
| `LocalizedActivity.visualQA`, the QA guards in `PlayActivity` | Not ported: Android device-QA tooling |
| `monetization/MonetizationActivity.java`, `app/build.gradle.kts` | Not ported: Android purchases and build (version code, test runner, a Fragment constraint). This app has no ads or purchases. |

### Decisions and remaining differences

- **House-player stats line.** Android's picker writes "Power 9  •  Forehand …" with "•", which never matches the catalog key
  "Power {0}  ·  Forehand {1}  ·  Backhand {2}  ·  Serve {3}", so Android shows it in English in the four new languages. iOS writes
  the English line in the key's form, so Android's catalog translation shows. The Hebrew line is unchanged.
- **Players steppers.** "Players: n" and "Standings points per win (pairs): n" are now `t("Players") + ": n"` and
  `t("Standings points per win (pairs)") + ": n"`, the labels of Android's selectors, which are catalog keys. The English and
  Hebrew output is unchanged.
- **Texts without a catalog row stay English** in the four new languages, exactly as on Android. Among the ported texts these
  are: "Elimination", "Winner takes all" and their explanations, "Bye · advances", "Playing now", "🏆 Winner!", "Who will win?",
  the bracket's spoken description, "Previous nickname", "Next nickname", the advance messages ("You reached the final!", …,
  which Android does not pass through `AppText`), and the two connection messages of a cross match.
- **iOS-only texts** have no Android counterpart and therefore no translation; none was invented: the header captions
  "Tournament match", "Ping Pong" and "Match result", "OK" (Android uses the system's OK), "Retry online connection", "Loading",
  "Expanded", "Collapsed", and the classic screens of the Simple experience (not reachable in this app). "Multi Ping Pong" (the
  app name) stays English, as in Android's four new `strings.xml`.
- **Digits** stay Western, as Android's catalog inserts them; `\.locale` is not changed.
- **Unit tests and the simulator language.** `LanguageTests` resets the language to English after each test, like Kotlin's
  `@After`. The other suites expect English for `hebrew: false`, as before, so they need a simulator whose first language is
  English (or Hebrew, or another language outside the six), which is the default.

### Tests

`Tests/MultiPongTests/LanguageTests.swift`, 9 methods; each names its Kotlin original:

| Kotlin | Swift |
| --- | --- |
| `LanguageTest.deviceTagsMapToSupportedLanguages`, `allFourLanguagesHaveCompleteCatalogColumns`, `rtlAndExistingHebrewArePreserved`, `placeholdersPreservePrivateNamesAndNumbers` | the same names, 4/4 |
| `LanguageDeviceTest.sixDeviceLanguagesResolveResourcesAndRenderCrossCourt` (instrumentation) | `testSixDeviceLanguagesResolveTextsAndDirection`: language, direction and a translated resource text for all six; the activity launches and screenshots are not ported |
| — (iOS) | `testLanguagesFollowAndroid`, `testPaddingAndSuffixKeepTheirSpacing`, `testGameTextsUseTheCatalog`, `testCrossTourTextsUseTheCatalog` |

Their expected texts were computed by replaying the `MPText` lookup in Python over the generated catalog and compared with the
Swift sources. Nothing has been compiled or run: this Windows machine has no Swift toolchain.

### Checks run

- `python3 Scripts/audit-multi-pong.py --android C:/Projects/MinikCrossPong`: OK. Besides the earlier checks it now
  - re-hashes the working-tree files listed below (the 138 committed blobs at `828c6fc` still match);
  - compares `MPTextCatalog.swift` with Android's `AppText.kt` row by row (820 rows) and checks the hash it names;
  - checks every catalog row (four non-blank columns, no duplicate key, no placeholder missing from its key);
  - checks that `MPText.languages`, `MPText.columns` and the target's `CFBundleLocalizations` agree.
- Every `MultiPong/*.swift` and `Tests/MultiPongTests/*.swift` file parses without errors with tree-sitter-swift 0.7.4.
- A scan of every `t(…)`, `tr(…)`, `text(…)` and `MPText.t(…)` English literal against the catalog gave the lists in "Decisions"
  above; all the other ported texts have a row.
- Line-by-line compile review of every changed Swift file against the declarations it uses.

### SHA-256 of the Android working-tree files used (2026-10-04)

Hashes of the files as they are on disk in the Android working tree (CRLF line endings), `sha256sum <path>`.

Ported or used for the port (24 files):

```text
7bba0d0c8ee52aaa13f08d8c8a8281381224d7c0a0985c05d6cb5dd89e7b5f94  app/src/main/java/com/appsbybros/minik/localization/AppText.kt
5542d7312af8247dc1bd1cbed881d278b182be69f8c9ac8c31af8b90877937ac  app/src/main/res/values-ar/strings.xml
64a2f5c5dba04cb74cab39a828bde4923f83f9f7c771abeeb246d707aca89fbc  app/src/main/res/values-es/strings.xml
485efd28216ebd0699b0b31549f95c11ebff5b7deb6e6864d97eb0216bc4e864  app/src/main/res/values-hi/strings.xml
e857189ce1a9353a4e8be1852324644aad3b3fe609b5a2f0f6d82ff6e362a575  app/src/main/res/values-nl/strings.xml
fae78f0c5cfd25c4447c59f13907b5a48dc3fb7a29639431282d206174423969  app/src/main/java/com/appsbybros/minik/pingpong/LocalizedActivity.kt
2f785d6441cd85d31062c426ea3ba9b8fe6709ffc05fbbffb137d7d11360ca75  app/src/main/java/com/appsbybros/minik/pingpong/BotPicker.kt
b540453d6425836a562af0ce5830c249c3f75ed7ea9dbef6734a98f947a33ddd  app/src/main/java/com/appsbybros/minik/pingpong/GuideDialog.kt
b5ad992e3c7b8335749c7dad25d6ef54767b5309492841bd5c7012d047ccd132  app/src/main/java/com/appsbybros/minik/pingpong/HousePlayerPicker.kt
d8dd558aafadab50c7b307e18ade3d3dcac780e97f3d6188635175d83e972f93  app/src/main/java/com/appsbybros/minik/pingpong/ModernActivity.kt
662532070826f740d8735a7d7e469beee4c69e5fb425ac39d6f6cc5a248ad2e4  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossActivity.kt
dc24925fadde508528f248dfa40d012f4faffdc311a7c0b8a98dac3567e32f1f  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossText.kt
1aef643ed335a401e7374e45a4f860fe1734fb95c7860e03c2bf2fb0a846f002  app/src/main/java/com/appsbybros/minik/pingpong/cross/CrossTutorial.kt
c67e98bc5ee8540af68ee6281db6af41d3a9698e884d83114d3c780b89a8da72  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/CompletionText.kt
bc865a4618e048bee01ba8a0eb81d7911b1b5d7cbe161baf4b24e546b53fbf19  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/ControlChoice.kt
c14c2802a8897287d1267e14b46559ffb9f68589fb79fb64bee30aad33d8f106  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/GroupMatch.kt
86d49f84cd724104bea8085d0242e1743747f710cc42052115d5e4643c9d5d87  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/Knockout.kt
44558073ed1cdeaed3e00b0759a75e5ecc9c061a186e9c9a64e5f5f7a60ea7f2  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/KnockoutBracketView.kt
4ac1b5225e5c054904e73f11d3cf03e201441229ec8cb9a375506025820a8da6  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/MatchText.kt
069ba849fa4dba8ef420b5b87924a3cb0980e2f4bbbf04ff88e7b68e49410ab5  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PlayActivity.kt
18e58ce32730e5096fee748d2e9837cf8e7136746a01ae1e22ffb4fc112a6a36  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PongModels.kt
da967922f28d3fd07cb620427b81a756f03e9c48a2e7648a0d3d0564c9aab28f  app/src/main/java/com/appsbybros/minik/pingpong/multiplayer/PrivateMatchActivity.kt
5117994247324664c1255499754de48c2b5c9fe40e2505c62f3656c0d53c8cb0  app/src/test/java/com/appsbybros/minik/localization/LanguageTest.kt
c7b9ac59de7a17bf2f93a9656f552b9bb04998b88db94cddc6c371157c364236  app/src/androidTest/java/com/appsbybros/minik/pingpong/LanguageDeviceTest.kt
```

Reviewed and not ported (Android-only, 2 files):

```text
ebcd1efbc2806bd362ee86edae472877bc15c553f1abcf645681e4c253493948  app/src/main/java/com/appsbybros/minik/monetization/MonetizationActivity.java
a11491a87c1cba784c601ca2ed62b0e933142464a54e8f03bd238ce1c84691a5  app/build.gradle.kts
```

