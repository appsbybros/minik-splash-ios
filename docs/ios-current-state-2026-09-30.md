# MINIK iOS: current state of every product (2026-09-30)

## About this audit

**Scope.** This is a read-only audit of five iOS products:

1. MINIK PLUS
2. MINIK PLUS ENGLISH ONLY
3. MINIK Math
4. Modern standalone MINIK Ping Pong
5. Retro / 80's Ping Pong, both the standalone target and the version inside Math

**What was not done.** No source, `project.yml`, Firebase, App Store Connect or signing setting was changed. Nothing was committed or pushed. This file is the only file the audit wrote.

**Source audited.**
- Tree: `C:\Projects\Minik-to-IOS\ios-main-merge`, branch `main`.
- HEAD: `eeb326e`, 2026-09-28 21:00 +0300.
- It is **4 commits ahead of `origin/main` `946447c`** (2026-09-14). Those 4 commits are not pushed. See §0.1.

**Method.**
- Static reading of Swift sources, `project.yml`, resources, workflows, docs and git history.
- String catalogs and plists were parsed with scripts that only read files.
- Android repositories were used only as a read-only reference for concepts and wire contracts:
  - `C:\Projects\Minik`: Languages, and `firebase/firestore.rules`
  - `C:\Projects\MinikPingPong`: Modern Pong, HEAD `202b808`
  - `C:\Projects\minikMath`
  - `C:\Projects\MinikPaddleAndLearn`: Bounce & Learn
  - `C:\Projects\minik80sPingPong`
- **This machine has no Mac or Xcode, so nothing was built or run.**
- GitHub Actions run history could not be inspected: the `gh` CLI is not installed and the repository is private. All CI evidence below therefore comes from documents inside the repo.
- The Firebase console was not queried. Deployed rules, App Check enforcement and app registrations are **UNKNOWN** unless a document records them.
- Secret values are never printed. Credentials are named only by purpose or suggested secret name.

**Wording.** "Implemented" means present in source and reviewed statically. **Nothing at HEAD has been compiled by Xcode.**

**Apple verification levels**

| Level | Meaning |
|---|---|
| L0 | Source only |
| L1 | Windows static checks or tests |
| L2 | Xcode project generated |
| L3 | Xcode build |
| L4 | Simulator run |
| L5 | Real device |
| L6 | TestFlight build |
| L7 | App Store Connect upload |

---

## Summary table

| Product | Target | Bundle ID | Current source completeness | Highest Apple verification level | Firebase status | Monetization status | iPhone status | iPad status | Main code blockers | External blockers | TestFlight readiness |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **MINIK PLUS** | `MinikPlus` | `com.appsbybros.minik.plus` | **High for a single-owner app.** Has 13 activities, a Parent Area, points and streaks, automatic word levels, the v2 public leaderboard and a Remove Ads purchase behind the parent gate. **Missing:** child profiles; about 73% of UI strings are untranslated in each non-English language; about 250 strings follow the device language instead of the in-app choice; the leaderboard nickname prompt has defects. | **L1 at HEAD.** In the past it reached **L4**: an Appetize Simulator run from a build at or before `180155b` (2026-09-05). That was before Firebase, ads, StoreKit and the leaderboard existed. | Config file present: project `easycallandanswer`, bundle ID matches. Uses anonymous sign-in, Firestore v2 and App Attest in Release. Console registration, App Check and whether anonymous sign-in is enabled: **UNKNOWN**. | **BOTH.** The purchase code exists but has never been compiled. Ads are off (flags NO, empty IDs). No access-code redemption. | Portrait and landscape are declared. Not verified at HEAD. Landscape may be cramped. | All orientations declared. Never run. | Never compiled with its current libraries. **Possible launch crash:** the Google ads SDK is linked while the ads app ID is empty. Nickname-prompt defects. Language leakage. | Apple team and signing; App ID with App Attest; App Store Connect record; `remove_ads` in-app purchase; App Attest registration in Firebase; privacy policy published online. | **NOT READY** |
| **MINIK PLUS ENGLISH ONLY** | `MinikPlusEnglish` | `com.appsbybros.minik.plus.english` | Same as Plus. The learned language is locked to English. Interface languages: 10 (no Hebrew). **Not a hard English + left-to-right lock** (see §2.3). | **L1 at HEAD.** In the past **L3** (built at `180155b`). It has never been run under XCTest or on a Simulator. | Same as Plus, with its own config file (`easycallandanswer`, bundle ID matches). Writes to `score_records_english_only`. | **BOTH** (same as Plus). | Same as Plus. | Same as Plus. | Same as Plus. Also, no test ever loads this target or its string catalog. | Same as Plus, for this bundle ID. | **NOT READY** |
| **MINIK Math** | `MinikMath` | `com.appsbybros.minik.math` | **High for the curriculum:** levels M1–M10 with 12 activities each, plus Mixed and Cards; Automatic/Manual levels; Parent Area; a Ping Pong chooser (Modern Simple and Retro). **Gaps:** the trophy leads nowhere; Math strings are English in all 10 non-English languages; no points or rewards; no ad placements. | **L1 at HEAD.** In the past **L3** (`7bc1511`, `180155b`). | **None, by design.** Firebase is not linked and there is no config file. | **NOT IMPLEMENTED:** no ad placements and no access codes. The Remove Ads purchase exists but removes nothing; this needs an owner decision. | Portrait and landscape declared. Not verified. | All orientations declared. Never run. | Never compiled at HEAD. It compiles all of `Sources/`, including the new, never-built Pong code. Possible launch crash (ads SDK with an empty app ID). Remove Ads is sold with no ads. Trophy leads nowhere. | Apple team and signing; App Store Connect record; **the bundle ID is also used by the v23 WebView package**. | **NOT READY** |
| **Modern Ping Pong** (standalone) | `MinikPingPong` | `com.appsbybros.minik.pingpong` (Android uses `…pingpong.modern`) | **Substantial source:** engine, 8-step tutorial, 11-character roster, profiles, friendly rooms, tournaments and the online transport. **Behind Android's 2026-09-29 changes.** The Beginner difficulty is missing. Hebrew cannot be reached. | **L1.** The L3 builds of 09-04/05 were of the *old* engine, which can no longer be reached. | Config file: project `minikswish`, bundle ID matches. Uses anonymous sign-in and the Realtime Database. **No App Check.** Writes to the production database on first launch. | **BOTH + NOT IMPLEMENTED.** There are no production ads (Debug test ads only), and Google's *sample* ads app ID ships in Release. Purchase, restore and offer codes exist, but **with no parent gate**. | Declared. Not verified. | Declared. Never run. | Never compiled. Difficulty-4 results are rejected when iOS runs the match (§4.4). Hebrew unreachable. Ungated purchase. Sample ads app ID in Release. | Signing; App Store Connect record; in-app purchase and offer codes; confirm which database rules are live and the API-key restrictions. | **NOT READY** |
| **Retro / 80's Ping Pong** | `MinikRetroPingPong` (standalone), and inside `MinikMath` | `com.appsbybros.minik.pingpong.retro` | The Android 80's web game runs inside a web view (WKWebView). Every gameplay feature is present in web form. The payload was copied from the **obsolete** `minik80sPingPong`, so it lacks Bounce & Learn's branding, Back behaviour, layout fix, tablet portrait support and monetization. | **L1.** Never built. | **None, by design.** | **NOT IMPLEMENTED, by design:** no ads, purchase or codes. | Declared. Not verified. | Declared. Only a "landscape recommended" hint in portrait. Never run. | Never compiled. Its only commits are unpushed. Back in the standalone app leads to a dead-end "Game closed" screen. The icon is byte-identical to Modern's. | Bundle ID registration; App Store Connect record; a way to archive and upload. | **NOT READY** |

**In one sentence:** no iOS product has ever been built with its current code and libraries, and no product has ever been signed, archived, run on a real device, uploaded to TestFlight or uploaded to App Store Connect.

---

## 0. Ground truth

### 0.1 Which tree is the real current source

| Candidate | What it is | Branch / HEAD / date | State | Verdict |
|---|---|---|---|---|
| `C:\Projects\Minik-to-IOS\ios-main-merge` | Worktree of the `ios` repository (remote `github.com/appsbybros/MinikPlus-iOS`, private) | `main` / `eeb326e` / 2026-09-28 21:00 | No tracked changes. **4 commits ahead** of `origin/main` `946447c`, confirmed with a read-only `git ls-remote`. Untracked files are listed below. | **CURRENT SOURCE OF TRUTH** |
| `C:\Projects\Minik-to-IOS\ios` | The main working tree. It holds the shared `.git` object store. | `codex-sprint-8h-20260830` / `eccf153` / 2026-09-07 | 9 modified or deleted files and 401 untracked (vocabulary images, also present in `main`). The branch matches its remote and is fully contained in `main`. An uncommitted, undated note says GitHub-hosted macOS is *"blocked by the account billing/spending-limit status"*. | Older. Must not be deleted: it holds the only copy of the 4 unpushed commits. |
| `C:\Projects\Minik-to-IOS\main-ci-fix` | Orphaned worktree folder | `ci-manual-only` / `2f00c04` / 2026-09-03 | **Broken link.** Its `.git` points to `C:/Projects/Minik/ios/.git/worktrees/main-ci-fix`, which does not exist. `git worktree list` shows it as *prunable* at the old path `C:/Projects/Minik/main-ci-fix`. `origin/main` was force-moved away from `2f00c04` on 2026-09-07 18:55. Its content is superseded. | Stale / broken |
| `C:\Users\User\Downloads\Minik-WebApps-Native-v23` (v10–v16 also exist) | Separate package, not a git repo, dated 2026-09-22: two web-view wrappers, 4 Swift files, 174 lines | n/a | Never built (`README_FIRST.txt:157-161`). **It uses the same bundle IDs as native Math and Pong** (`ios/MinikWebApps/project.yml:22-26,44-48`). Its own docs call the IDs undecided and say it "must not overwrite" the larger iOS Math. | Not canonical. An open bundle-ID conflict. |
| `C:\Projects\MinikPingPongWorkspace` | Android task workspace | – | – | Not iOS |

**Other branches:**
- `fix/storekit-grace-30s-20260912` (`ef1aea5`) matches its remote and is contained in `main`.
- The local `FETCH_HEAD` dates from 2026-09-05, so the local view of the remote is stale. The last push to `origin/main` was 2026-09-14.

**Unpushed commits on `main`:**

| Commit | Date | Content |
|---|---|---|
| `23ce35b` | 09-18 | Minik Math app icon |
| `ac3e71d` | 09-19 | Native SpriteKit "80s Style" mode. Now dead code; not mentioned in the master plan. |
| `b15717f` | 09-28 | Modern Ping Pong port (118 files, +6,167 lines) |
| `eeb326e` | 09-28 | Retro Pong web view, the `MinikRetroPingPong` target, `retro-pong-simulator.yml`, and the Math chooser (97 files, +9,225 lines) |

**Single-copy risk.** These four commits exist only in `C:\Projects\Minik-to-IOS\ios\.git`. No bundle or backup was found. Because the CI workflows run only on the default branch, **no CI run has ever seen the Math icon, Modern Pong, Retro, or the Retro workflow.**

**Untracked items in `ios-main-merge`:**

| Item | Size / note |
|---|---|
| `website/` | 30 MB, Android-only website |
| `website.zip` | 28 MB |
| `docs/Minik-iOS-PingPong-80s-Reference-v2.zip` | 1.5 MB |
| `rollout-2026-09-02T…jsonl - File too big …` | 0 bytes; the file name is an upload error message |
| `%USERPROFILE%/` | Empty folders |
| `node_modules/`, `firestore-debug.log` | Ignored by git |

`.gitignore` does not cover `website/`, `*.zip`, `rollout-*` or `%USERPROFILE%`, so a `git add -A` would sweep in about 60 MB. `tmp_phase39_probe.js` is a stray file that *is* tracked.

**Can the repository fetch and report status normally?** `git status` works. `git ls-remote` reached the remote. Fetch was deliberately not run, because it would change local refs.

### 0.2 Target and project map (`project.yml` at HEAD)

**Shared settings (the `MinikApplication` template)**
- XcodeGen, iOS **17.0**, Swift 5.9.
- `TARGETED_DEVICE_FAMILY "1,2"` (iPhone and iPad).
- `CODE_SIGN_STYLE Automatic`, **no `DEVELOPMENT_TEAM`**.
- Version **1.7.9**, build **79**.
- `UILaunchScreen {}`, i.e. the plain system launch screen.
- Orientations: iPhone Portrait / LandscapeLeft / LandscapeRight; iPad all four.
- **Every app target compiles all of `Sources/`** (`project.yml:45-46`). Products differ only by their `SWIFT_ACTIVE_COMPILATION_CONDITIONS` flag.
- Default Info keys:
  - `MinikRemoveAdsProductIdentifier = remove_ads`
  - `MINIK_ADS_ENABLED = NO`, `MINIK_ADS_POLICY_APPROVED = NO`
  - ads app ID and ad-unit ID empty
  - Privacy `https://miniklearn.com/privacy`, Terms `https://www.easycallandanswer.com/terms.html`, Support `https://miniklearn.com/contact`
- There is no `ITSAppUsesNonExemptEncryption` key.

| | MinikPlus | MinikPlusEnglish | MinikMath | MinikPingPong | MinikRetroPingPong |
|---|---|---|---|---|---|
| Scheme | `MinikPlus` (**the only scheme with a test action**) | `MinikPlusEnglish` | `MinikMath` | `MinikPingPong` | `MinikRetroPingPong` (`:369-374`) |
| Bundle ID | `com.appsbybros.minik.plus` | `com.appsbybros.minik.plus.english` | `com.appsbybros.minik.math` | `com.appsbybros.minik.pingpong` | `com.appsbybros.minik.pingpong.retro` (**a literal**, `:325`) |
| Display name | Minik Plus | Minik Plus English | Minik Math | Minik Ping Pong | Minik 80s Pong |
| Compile flag | `MINIK_PLUS` | `MINIK_PLUS_ENGLISH` | `MINIK_MATH` | `MINIK_PING_PONG` | `MINIK_RETRO_PING_PONG` (runs as `ProductVariant.minikPingPong`, `MinikApp.swift:27`) |
| Entry point → root view | `MinikApp` → `RootView` → `MinikActivityHubView` (Language) | same | same (Math hub) | `RootView` → `PingPongOnlyRootView` → `ModernPongView(.full)` | `MinikApp.swift:10-11` → `RetroPongView()`, skipping `RootView` (no commerce, no reminders) |
| App icon set | `MinikPlusAppIcon` | `MinikPlusEnglishAppIcon` (differs from Plus) | `MinikMathAppIcon` (1024 px, RGB, no alpha; provenance undocumented) | `ModernPongAppIcon` | `RetroPongAppIcon`, **byte-identical to `ModernPongAppIcon`** (sha256 `035f38e4…`, git blob `da291adf`) |
| Firebase config file | `Config/Firebase/MinikPlus`, copied by a pre-build script that checks BUNDLE_ID (`:113-134`) | `Config/Firebase/MinikPlusEnglish`, same script (`:187-208`) | none | `Config/Firebase/MinikPingPong`, **bundled directly** with no BUNDLE_ID check (`:270-271`) | none |
| Entitlements | `Resources/Entitlements/MinikLanguage.entitlements` (App Attest, production) | same file | none | none | none |
| StoreKit product | `remove_ads` | `remove_ads` | `remove_ads` | `remove_ads`, plus Apple's offer-code sheet | none used (the package is linked only so the shared code compiles) |
| Ads configuration | GoogleMobileAds linked; ads off; app ID `""` | same | same | GoogleMobileAds linked; **Google sample app ID in every configuration** (`:283`); test ads in Debug only (`:285,293`) | not linked |
| Privacy manifest | `Privacy/Language` (User ID and gameplay content, linked; no tracking) | `Privacy/Language` | `Privacy/LocalOnly` (collects nothing) | `Privacy/ModernPong` (User ID and gameplay content, linked; no tracking) | `Privacy/LocalOnly` |
| String catalog / `CFBundleLocalizations` | `Localization/All` / en am ar de es fr **he** nl pt-BR pt-PT ru | `Localization/EnglishOnly` / en am **ar** de es fr nl pt-BR pt-PT ru | `All` / 11 languages | `All` / 11 languages (UI is English or Hebrew only) | bundles `All` (11 languages) but declares `[en, he]` |
| Swift packages | FirebaseAuth, Core, Firestore, AppCheck; GoogleMobileAds; AppStoreCommerceKit | same | GoogleMobileAds; AppStoreCommerceKit | FirebaseCore, Auth, Database; GoogleMobileAds; AppStoreCommerceKit | AppStoreCommerceKit |
| Extra resources | Language media and vocabulary | same | Math assets, `RetroPong` folder, Modern Pong assets and audio, `PingPongAssets.xcassets` (about 15 MB, almost all unused) | Modern Pong assets and audio | `RetroPong` folder |
| Tests hosted | `ProductConfigurationTests` | – | – | – | – |

**Non-app targets**
- `ProductConfigurationTests`, hosted by MinikPlus (`:332-346`).
- The package test host `Packages/AppStoreCommerceKit/IntegrationTestHost/AppStoreCommerceKitTestHost.xcodeproj`, which is separate from the app project.

**Accidental or legacy targets.** None are defined in `project.yml`. The legacy artefacts are:
- the dead legacy Pong code compiled into every target (§9);
- `codemagic.yaml` (manual, deprecated, 4 schemes);
- the v23 WebView package outside the repo, which reuses two bundle IDs.

**Info.plist and capabilities**
- No usage-description keys, and none are needed: speech is synthesis only, notifications are local, and there is no microphone, camera, photos or location use.
- No background modes, no remote push, no URL schemes.
- No `SKAdNetworkItems` and no `NSUserTrackingUsageDescription`.

### 0.3 Apple build evidence per target

There are no Apple logs, `.xcresult` bundles, `.app`/`.ipa` files or run URLs in the repository. Every Apple result below is a **summary recorded in docs**, supplied by the owner or a reviewer. The only direct runtime artefacts are 10 owner Appetize screenshots **outside the repo** at `C:\Projects\Minik-to-IOS\review-input\language-simulator-qa\*.png` (dated 2026-09-06; iPhone 14 Pro, iOS 17.2, title "Minik Plus").

**Gate timeline (GitHub-hosted macOS)**

| Gate | Commit (date) | Result | Source |
|---|---|---|---|
| G1 | before `8eac5e6` (09-02/03) | Project generated; MinikPlus compile FAILED | `MINIK_MASTER_PLAN.md:1956,2544` |
| G2–G4 | `085d704`, `898a8e6` (09-03/04) | All 4 apps FAILED to compile | `MINIK_MASTER_PLAN.md:1940-1944` |
| **G5** | **`7bc1511`** (09-04 04:50) | **All 4 BUILD SUCCEEDED.** Test target failed to compile. | `MINIK_MASTER_PLAN.md:1946,2645` |
| G6 | `b1c3e81` (09-04) | MinikPlus built; 763 tests ran, 8 failed | `MINIK_MASTER_PLAN.md:1948,2657` |
| Appetize QA #1 | build not recorded | Owner review of Language and old-Pong screens | `docs/first-iphone-simulator-qa.md` |
| G7, G8 | `d6b3cbf`, `d2d8d79` (09-05) | All 4 FAILED | `docs/mac-gate-practice-visual-analysis.md`, `docs/cards-accessibility-mac-analysis.md` |
| **G9 (last green)** | **`180155b`** (2026-09-05 14:13, Xcode 26.6) | **All 4 BUILD SUCCEEDED; 797 tests ran, 796 passed.** The failure at `MathActivitySessionFactoryTests.swift:231` was fixed in `084ca2a` but **never re-run**. | `docs/m3-build-xctest-root-cause.md:5-7`; `MINIK_MASTER_PLAN.md:1924` |
| Appetize QA #2 | consistent with G9 | 10 Language screenshots | `docs/language-second-simulator-correction-ledger.md:62-80` and the external PNGs |
| Not documented | around 09-07 | The commit `316616b` "repair shared layout direction compile gate" implies a failed compile. No doc records it. | git history |
| Everything after 09-07 | – | **Explicitly not run** | `MINIK_MASTER_PLAN.md:3109,3163,3258,3268`; `docs/apple-release-checklist.md:93` |

**What changed after the last green build (`180155b`)**
- 66 commits, 29 of which touched `Sources/`: 100 files, +13,464 / −646 lines.
- `project.yml` changed by +223 / −7 lines.
- **All three Swift package dependencies were added afterwards:** Firebase (`38ead8a`, 09-12), AppStoreCommerceKit (`b465124`, 09-12) and GoogleMobileAds (`a2fdd9e`, 09-12).
- The Firebase pre-build script (`06b9a3e`) and the App Attest entitlement (`8000d02`) also came afterwards.

| Target | Highest level ever proven | Proven on | Level at HEAD `eeb326e` |
|---|---|---|---|
| MinikPlus | **L4** (Appetize run, owner screenshots) and L3 with 796/797 tests | build at or before `180155b` | **L1** |
| MinikPlusEnglish | **L3** (G5, G9). No Simulator run can be attributed to it. | `180155b` | **L1** |
| MinikMath | **L3** (G5, G9) | `180155b` | **L1** |
| MinikPingPong | **L3, for the old SpriteKit product only** (possibly L4 through Appetize QA #1, not attributable) | `180155b` | **L1.** Evidence: 43/43 database-rules emulator tests (JavaScript SDK, 09-28, `docs/modern-pong-verification/firebase-rules-test.log`), Windows source checks, and 25 XCTests that were written but never run. |
| MinikRetroPingPong | **L1**: `docs/retro-pong-evidence/windows-checks.json` (`"native_build_verified": false`) | `eeb326e` | **L1** |
| AppStoreCommerceKit (package) | **L1.** No recorded native pass (`NATIVE-VALIDATION.md:58` says "NOT RUN"). | – | L1 |

**Not one target has any L5, L6 or L7 claim anywhere.**

---

## 1. MINIK PLUS

### 1.1 Startup, intro, lifecycle and restore
- **Entry.** `MinikApp.swift:3-33`: the `MINIK_PLUS` flag selects `.minikPlus`. Product policy (`ProductConfiguration.swift:89-97`): language domain, learned languages {en, he}, and a learned-language picker.
- **App delegate.** `MinikAppDelegate.swift:8` calls `FirebaseBootstrap.configureIfAvailable`, which installs the App Check provider and then calls `FirebaseApp.configure` (`FirebaseRecordsIntegration.swift:44-68`).
- **`RootView`:**
  - forces light mode for the language domain (`RootView.swift:66`);
  - injects the locale and layout direction from the in-app interface language (`:68-72`);
  - a `.task` starts reminders, purchases, ads and the Remove Ads reminder (`:73-78`).
- **Screen flow:** opening clip → Intro (Points, Best streak, Parent Area, Practice) → menu → activity (`MinikActivityHubView.swift:213-217,321-335`; `LanguageShellViews.swift`).
- **Intro video.** `intro_animation_plus.mp4` plays at volume 0.2 on **every cold launch** (`LanguageOpeningView.swift:30-67`). Tap to skip; 10 s fallback; skipped under Reduce Motion.
- **Audio session.** Nothing in `Sources/` configures an audio session, so iOS defaults apply: the silent switch mutes speech and video, and the app interrupts other audio. Not verified at runtime.
- **Going to the background:**
  - The automatic word level decays by 10 and is saved (`MinikActivityHubView.swift:232-238`).
  - Individual activity views handle backgrounding. Tic-Tac-Toe has no handling.
- **After the app is killed:** only saved settings (UserDefaults) come back. The screen and any in-progress session are not restored; a cold launch always goes clip → Intro. A pending leaderboard entry does survive.

### 1.2 Children and profiles
- **There are no child profiles on iOS.** There is one owner, `RewardOwnerID.localDefault` = `"local-default"` (`Rewards.swift:11`). It is used for rewards, the automatic level, and leaderboard identity and state.
- There is no create, delete or switch UI, no limit, and no per-child data. Multiple owners appear only in tests (`RemoteRecordsTests.swift:490-563`).
- Android works differently: per-slot v2 IDs, and deleting a slot shifts the data. Whether iOS needs profiles is an **owner decision**; it is not assumed here.
- **Storage** is all UserDefaults. The keys are:
  - `minik.interface-locale.v1` (global)
  - `minik.learned-language.v1.<product>`
  - `minik.encouragement-enabled.v1.<product>`
  - `minik.language-levels.v1.<product>.{mode,words,soccer}`
  - `minik.tic-tac-toe.*` (not product-scoped)
  - `minik.language-auto-progress.v1.<product>.local-default`
  - `minik.rewards.v1`
  - `minik.activity-progress.v1`
  - `minik.public-leaderboard.v1.<product>.local-default`
  - `minik.records.player-id.v2.<product>.local-default`
  - `minik.commerce.remove-ads.v1.<product>`
  - ads, reminder and Soccer-intro keys
- Two ever-growing lists have no size limit: `processedEventIDs` (`Rewards.swift:213,230`) and `appliedEvidenceIDs` (`LanguageAutoLevelProgression.swift:163,189`).

### 1.3 Language selection, right-to-left, Hebrew, Arabic and translations
- **Interface language.** 11 choices: en am ar de es fr he nl pt-BR pt-PT ru (`InterfaceLocale.swift:4-16`). Only he and ar are right-to-left (`:20-22`).
  - The default is English; **the device language is never read** (a search found no `Locale.current` or `preferredLanguages` in `Sources/`).
  - It can only be changed in the Parent Area picker (`ParentAreaView.swift:153-167`).
- **Learned language.** Plus has an English/Hebrew picker (`ParentAreaView.swift:134-151`) and defaults to English (`EducationalParentSettings.swift:26-31`). Android picks a default from the device language instead (a Hebrew device learns English, any other learns Hebrew). This difference is noted, not judged.
- **How direction is applied.** Through SwiftUI only: the root (`RootView.swift:70-72`) plus per-view overrides for learned content. Game boards (Memory, Tic-Tac-Toe, Tower) are forced left-to-right. There is no UIKit direction override.
- **Key defect: three different ways of looking up strings are mixed.**
  1. SwiftUI `Text`/`Button` literals follow the injected interface language.
  2. `InterfaceLocaleID.text()` uses the selected language explicitly (menus, instructions, speech).
  3. `String(localized:)` **without a locale follows the device language, not the in-app choice.** About 250 distinct keys on Language screens use it (334 across all of `Sources/`).
     - Visible examples: the Soccer intro, score bubbles and Start button (`LanguageSoccerView.swift:218,225,603,618-619`); the Tic-Tac-Toe phrases, which are also spoken with the interface-language voice (`TicTacToeFeedbackPlayer.swift:5-36,56-74`); Top 20 titles and states; Parent Area status messages; Build labels; many VoiceOver labels.
     - Result: when the interface language and the device language differ, screens mix languages. The repository acknowledges this (`InterfaceLocale.swift:24-25`).
- **Translation completeness** (parsed from `Resources/Localization/All/Localizable.xcstrings`):
  - 596 keys in 11 languages, with no missing or stale entries.
  - In each non-English language only about 154 keys are really translated. About 437–444 are **identical to English** and marked `needs_review`.
  - So **roughly 73% of UI strings are English in every other language, including Hebrew.** Examples: "Scores", "Best streaks", "Online leaderboard", "Remove Ads", "Restore Purchases", "Learning reminders".
  - Five strings used in the UI are missing from the catalog: "Privacy, support & legal", "Privacy Policy", "Terms of Use", "Support" (`ParentAreaView.swift:623,669-671`) and "App version" (`:659`).
- **Text-clipping risks** (not verified):
  - Nicknames are cut to one line (`RecordsLeaderboardView.swift:200-203`).
  - The Tic-Tac-Toe title shrinks to 65% (`TicTacToeView.swift:123-137`).
  - The learned word shrinks to 40% (`LanguageBuildPage.swift:47`).
  - Word Cards tiles have a fixed width (`LanguageShellViews.swift:114-120`).
  - The statistics row is capped at 280 pt (`:22-29`).
  - Long language names such as "Portuguese (Portugal)" sit in the Parent picker row.
  - There is probably no Amharic voice, so Amharic falls back to the en-US voice (`LearningSpeech.swift:85-92`).

### 1.4 Levels, progression, points and streaks
- **Levels.**
  - Words A–E; Soccer A–C; Tic-Tac-Toe A–E, Random or Adaptive.
  - Defaults: Auto mode, words A, Soccer A, Tic-Tac-Toe Adaptive (`EducationalParentSettings.swift:81-93`).
  - UI: `LanguageParentLevelsView.swift`. The word-level picker is enabled only in Manual mode.
- **Automatic word level.** Evidence comes from standalone Word Build (at least 100 attempts at 90% or better) and Tower/Soccer letters (at least 600 attempts at 80% or better). A level-up needs 2 passes in a row, never goes down, and fades by 10 whenever the app goes to the background (`LanguageAutoLevelProgression.swift:3-38,208-265`).
- **Points and streaks** are kept per product (`Rewards.swift:19-29`). Points never go below 0.
  - Word practice: +1 to +5 by streak tier, −1 when wrong.
  - Letter Pairs ±1; Tower +2; Picture Memory +2.
  - Soccer: win 3, draw 1. Tic-Tac-Toe: win 2, draw 1, loss −1.
- "Stars" are decoration only; there is no star currency.

### 1.5 Activities, navigation and Parent Area
- **13 production activities** (`ActivityCatalog.swift:181-211`):
  - Letters: Learn, Letter Pairs, First Letter, Picture Starters.
  - Words: Mixed, Word Build, Picture→Word, Word→Picture, Word Cards.
  - Games: Soccer, Alphabet Blocks (Tower), Picture Memory, Tic-Tac-Toe.
- **Navigation.** Intro ↔ menu. Home goes to Intro. The trophy opens Top 20. Leaving an activity returns to the menu and submits a leaderboard candidate (`MinikActivityHubView.swift:1056-1067`).
- **Parent Area.** Shown as an overlay in the language products.
  - **Entry is not gated**: the "Parent Area" button is reachable by the child (`LanguageShellViews.swift:40`).
  - Contents: learned and interface language, encouragement, reminders, online leaderboard, purchases, legal links, levels, progress, local records.
  - **Only purchase, restore and the external links** go through `ParentalGateView` (`ParentAreaView.swift:76-84,571-590,625-644,675-690`). The gate is a two-digit addition typed on a number pad and read with `Int(...)`, so Arabic-Indic digits may not be accepted (not verified).
  - The text "Your child's local name stays on this device" (`:437`) is inaccurate: iOS stores no local child name.

### 1.6 iPhone, iPad, orientation and dark mode
- **Layout.** There are no device-type checks. Layout switches at width breakpoints: 430 / 768 / 1100 (`MinikHomeVisuals.swift:31-59`), 430 / 800 / 1100 (`MinikPracticeVisuals.swift:670-693`), and "wide" at 700 pt or more (`LanguageShellViews.swift:15`, `CardsView.swift:30`, `LanguageLearnPage.swift:74`).
- **Orientation.** Nothing is locked in code. iPhone allows landscape (Android forces portrait). **iPhone landscape (about 844–932 pt wide) switches on the wide layouts with only about 390 pt of height**, so screens may be cramped. Not verified.
- **iPad.** Declared but never run.
- **Dark mode.** Light mode is forced for Language and colours are hard-coded, so dark mode has no effect.

### 1.7 Leaderboard (details and production-rule compatibility in §6)
- Top 20 has two cards, Scores and Best streaks, with up to 20 rows each, a highlight for the player's placement, an offline cache label and Retry (`RecordsLeaderboardView.swift:82-221`).
- **The iOS client implements the v2 ownership contract:**
  - `v2_` + lowercase UUIDv4 player IDs;
  - anonymous sign-in;
  - a private `leaderboard_owners/{id}` record holding `{owner_uid}`;
  - `app_id "3"`;
  - collections `score_records` + `correct_answers_in_row`;
  - a server timestamp;
  - publishing only a new best.
- **Defects found by reading the source:**
  - (a) **Repeated nickname prompt.** The "Great score!" nickname prompt appears on **every** exit from a language activity or Tic-Tac-Toe whenever points or streak are above 0 and no nickname exists, even when the score would not reach the Top 20 (`RemoteRecords.swift:105-124`; `MinikActivityHubView.swift:1059-1061,1178-1180`). "Not now" only hides it until the next exit.
  - (b) **Prompt after a parent turns sharing off.** The prompt still appears; nothing is published (`RemoteRecords.swift:124-125,138,173`).
  - (c) **Repeated modal.** "Saved on this device" appears on every exit when sharing is off, Firebase is not set up, or the device is offline (`MinikActivityHubView.swift:1148-1174,1181-1183`).
  - (d) **Wrong highlight on ties.** Placement counts ties, but the displayed ranks are sequential, so the highlight can land on the wrong row (`RemoteRecords.swift:600-609`; `RecordsLeaderboardView.swift:124-129,237-241`).
  - (e) Every Android v2 name (1–5 characters) is shown as "**Player**" on iOS, because iOS only displays names matching its curated "Adjective Noun N" pattern (`RemoteRecords.swift:638-640,661-663`).
  - (f) **Top 20 fails without sign-in.** iOS signs in anonymously **before reading** as well; the production rules allow reads without it. If sign-in fails, Top 20 fails.
  - (g) **No recovery if the sign-in identity changes.** The owner UID is not stored locally, so there is no mismatch detection or recovery.
  - (h) **Possible offline hang.** Awaited writes finish only when the server acknowledges them, so the "Updating…" state may hang offline (not verified).
- Android's current 5-character public-name design is **not** treated here as an iOS requirement. iOS uses curated nicknames of 10–19 characters with an optional avatar. The production rules accept these (§6.3).

### 1.8 Monetization and privacy (short; details in §7)
- Ads: implemented with safe defaults and switched off; no ad IDs.
- Remove Ads (`remove_ads`) is sold behind the parent gate even though no ads can appear. No access-code redemption.
- Privacy manifest: `Privacy/Language`.

### 1.9 Tests covering Plus (written; **none run since 2026-09-05**)
- `ProductConfigurationTests`, `InterfaceLocaleTests`, `LanguageInterfaceLocalizationTests` (checks only **2 keys per language** for real translation).
- `ParentAreaPolicyTests`, `LanguageProductionParityTests` (exactly 13 activities, routes, left-to-right metadata).
- `ActivityCatalogTests`. At G6, `testTicTacToeIsAJustForFunGameInBothLanguageProductsOnly` failed, because it compares a device-language lookup with "Tic-Tac-Toe".
- `RemoteRecordsTests` (21; fake data source and sign-in; schema, top-20, nickname privacy, ownership, pending retry). **The real Firestore data source and sign-in classes are private and untested.**
- Reward, automatic-level, speech, reminder, commerce and ads tests, plus the Language content-provider and session tests.

### 1.10 Documentation claims (Plus)

| Doc | Classification |
|---|---|
| `firebase-leaderboard-contract.md` | **Mostly STALE / CONTRADICTED.** Wrong: :3 "deployment blocked on the legacy cutover"; :7 canonical source is `subscriptionlib`; :26 "Android has no deletion"; :40 "Android writes unversioned IDs"; :46 "Ping Pong links no Firebase". **CURRENT AND VERIFIED BY SOURCE:** :30 (free-text names suppressed), :32 (sign-in before every operation), :44-46 (App Check wiring). |
| `firebase-leaderboard-migration.md` :7-12, :21-46 | **CONTRADICTED** by what Android actually deployed: legacy and v2 coexist, and Android kept free-text names. |
| `public-leaderboard-privacy.md` | :77, :79, :80 are CURRENT AND VERIFIED BY SOURCE. :72/:84 "per local profile" is CONTRADICTED (iOS has one owner). Not documented: the prompt after a parent opts out. |
| `language-second-simulator-correction-ledger.md` SH06 ("selected-language lookup fixed") | **Partly CONTRADICTED** (about 250 device-language keys remain) |
| `localization-qa-status.md` | **CONTRADICTED** (286 keys vs 596; 29 translated vs about 154) |
| `current-migration-status.md` | **CONTRADICTED / STALE** (3 targets, 12/543 images, "no persistence") |
| `second-iphone-simulator-readiness.md` | STALE (4 products, Parent Area shown as a sheet) |

### MINIK PLUS: status lists

**ALREADY BUILT (source)**
- Intro with video; menu; 13 activities in English and Hebrew, with right-to-left learned content.
- Parent Area: learned and interface language, encouragement, weekly reminders, levels (Auto A–E, Soccer, Tic-Tac-Toe), progress, local records.
- Points and streaks; automatic word level.
- v2 Firestore leaderboard: anonymous sign-in, App Attest in Release, ownership records, curated nicknames, opt-out, deletion.
- Remove Ads with purchase and restore behind the parent gate; legal links behind the gate.
- Light mode forced; declared for iPhone and iPad.

**CONFIRMED FINISHED**
- Nothing at HEAD has Apple evidence.
- Only historical evidence exists: BUILD SUCCEEDED plus 796/797 tests at `180155b`, and Appetize screenshots (09-06). Both predate Firebase, ads, StoreKit, the leaderboard, reminders and the 09-06 Language rebuild.

**IMPLEMENTED BUT NOT APPLE-TESTED**
- Everything above, especially:
  - Firebase and App Attest at runtime; the pre-build config-copy script;
  - StoreKit; Hebrew right-to-left rendering; speech and audio;
  - iPad and landscape layouts;
  - all Language views changed since 09-06.

**CODE STILL MISSING** (some items depend on owner decisions, marked ◇)
- Consistent use of the in-app interface language (about 250 device-language `String(localized:)` keys).
- Translations: about 73% untranslated in every language; 5 Parent Area keys missing from the catalog.
- Leaderboard fixes (a)–(d), (g) and (h) above.
- An audio-session policy.
- Limits on `processedEventIDs` and `appliedEvidenceIDs`.
- Parent-gate handling of non-Western digits (to verify).
- Correct the "child's local name" text.
- ◇ Child profiles (only if Android parity is wanted).
- ◇ A gate on entering the Parent Area.
- ◇ Access-code redemption.
- ◇ The learned-language default.

**EXTERNAL SETUP STILL MISSING**
- Apple Team ID and signing; App ID `com.appsbybros.minik.plus` with the **App Attest** capability; distribution certificate and profile.
- App Store Connect record; a `remove_ads` non-consumable (decide whether ads exist first); agreements, tax and banking.
- Firebase console:
  - confirm the iOS app registration;
  - register App Attest in App Check (keep enforcement off);
  - confirm anonymous sign-in is enabled;
  - confirm the composite indexes are deployed.
- The privacy policy published at `miniklearn.com/privacy`; review the Terms URL domain (`easycallandanswer.com`).
- Age rating and Kids Category decision; App Privacy answers; screenshots.

**EXACT BLOCKERS TO TESTFLIGHT**
1. The first Xcode build of HEAD, with Firebase 12.x, GoogleMobileAds 13.x and AppStoreCommerceKit resolved (never done).
2. The pre-build config-copy script must work under Xcode's script sandboxing (never run).
3. A Simulator launch check for the empty ads app ID with the ads SDK linked.
4. Team, signing and a provisioning profile with App Attest.
5. An App Store Connect app record.
6. An archive and upload path: none exists in the repo (§8).

**EXACT BLOCKERS TO APP REVIEW**
- A Remove Ads purchase in an app that shows no ads (guidelines 2.1 / 3.1 risk), unless ads are enabled.
- The privacy policy and App Privacy answers must cover the leaderboard data (User ID, gameplay content) and the Google ads SDK's own privacy manifest.
- If the app goes into the Kids Category: the ads SDK is linked while unused; the Parent Area entry is ungated; the gate is simple addition.
- The repeated nickname prompt and modal.
- The UI is mostly English while 11 languages are declared.
- A launch crash if the vocabulary files are packaged wrongly (`LanguageWordCatalog.swift:104-110`, `preconditionFailure`).

---

## 2. MINIK PLUS ENGLISH ONLY

### 2.1 Target
- Bundle ID `com.appsbybros.minik.plus.english`; display name "Minik Plus English".
- Icon `MinikPlusEnglishAppIcon`: 1024 px, RGB, no alpha, different from Plus.
- Its own Firebase config file (`easycallandanswer`, BUNDLE_ID matches), copied by the same pre-build script, which has no input or output files declared and has never run in Xcode.
- App Attest entitlement; the same Swift packages as Plus, including GoogleMobileAds.
- Catalog `Localization/EnglishOnly`: 596 keys × 10 languages, no `he`, about 153 translated each, **158 strings in Arabic script**. Its only difference from the All catalog is the key "Mode".
- `CFBundleLocalizations` is `[en, am, ar, de, es, fr, nl, pt-BR, pt-PT, ru]`.
- **It has no test action, and no test ever loads its catalog or runs this target.**

### 2.2 How English is enforced
- **The learned language is locked to English** at every layer:
  - product configuration (`ProductConfiguration.swift:98-106,73-85`);
  - the settings store (`EducationalParentSettings.swift:26-36`);
  - the hub (`MinikActivityHubView.swift:1229-1233`);
  - each content provider (e.g. `LanguageLearnContentProvider.swift:42`).
- The Parent Area shows a fixed "English" (`ParentAreaView.swift:147-149`).
- Learned content stays left-to-right, and Hebrew artwork is excluded (`LanguageProductionParityTests.swift:175-201`).
- **The interface language:**
  - defaults to English and ignores the device language;
  - cannot be Hebrew (`InterfaceLocale.swift:32-36`);
  - but **can be Arabic**: the Parent Area picker lists every allowed language (`ParentAreaView.swift:160`), and `allowedLocales` removes only Hebrew.
- Selecting Arabic makes the **whole app right-to-left** (`RootView.swift:70-72`; `InterfaceLocale.swift:20-22`). This is intended and tested (`LanguageInterfaceLocalizationTests.swift:43`) and documented (`english-only-parity-lock.md:25`).
- Android reference, read-only (`C:\Projects\Minik\app\src\main\java\com\minik\minik\MainActivity.kt:40-57,87-102,248-251`): English Only redirects a **Hebrew** device language to English and forces left-to-right in that case. Other languages, including Arabic, keep their own direction.
- **Activities:** the same 13 as Plus.
- **Leaderboard:** `score_records_english_only` plus the shared `correct_answers_in_row` (`RemoteRecords.swift:392-399`). This matches Android's `Board.score(englishOnly)` / `STREAK`.
- **Store:** `remove_ads` behind the parent gate. No access codes. Parent Area as in Plus.
- **Hebrew and Arabic files compiled in.**
  - The catalog contains 158 Arabic strings.
  - There are no Hebrew *strings*, but Hebrew letter art (e.g. `language_letter_alef`), Hebrew vocabulary (`words-normalized.xml`, manifest) and Hebrew literals (`ActivityCatalog.swift:298`, Modern Pong) are packaged or compiled in. None of these can be reached from the UI.

### 2.3 Is it guaranteed to stay ENGLISH + LEFT-TO-RIGHT on a Hebrew or Arabic device? **No.**

| Situation | What happens (from source; **not verified at runtime**) |
|---|---|
| Hebrew device | The app ships no `he`. The interface language defaults to English and the root layout is left-to-right. The app's own screens are English, **unless** the device's preferred-language list ranks another bundled language (e.g. Arabic or Russian) above English. In that case the ~250 device-language strings appear in that language. System screens (StoreKit sheets, notification permission, keyboard) are Hebrew and right-to-left. |
| Arabic device | App resources resolve to `ar`, so **about 65 device-language keys that have real Arabic text appear in Arabic inside the left-to-right English UI.** Examples: Tic-Tac-Toe phrases (also spoken in an English voice), "Available blocks", the Top 20 "Done", the Soccer hint. UIKit-level direction follows the resolved language (right-to-left), while SwiftUI is left-to-right; bridged controls such as menu pickers and the video player are unverified. Numbers from `.formatted()` use the device locale. |
| Any device, parent selects Arabic in the Parent Area | **The whole app becomes right-to-left.** Intended; matches Android. |
| Learned content (words, letters) | **Always English and left-to-right.** Guaranteed by policy at every layer. |

**Conclusion.**
- **Guaranteed:** English learned content; an English default interface; no Hebrew interface.
- **Not guaranteed:** an all-English, all-left-to-right app.
- Whether a hard English + left-to-right lock is *required* for iOS is an **owner decision**:
  - If it is required, the missing code is: remove Arabic from the choices and from `CFBundleLocalizations`, force left-to-right at the root, and stop device-language lookups.
  - If Android parity is the requirement, only the device-language leakage is a defect.

### MINIK PLUS ENGLISH ONLY: status lists

**ALREADY BUILT (source)**
- The same 13 activities with English locked at every layer.
- 10 interface languages (no Hebrew).
- Its own bundle ID, icon, Firebase config file and EnglishOnly catalog.
- Leaderboard on `score_records_english_only` plus the shared streak board.
- Parent Area and store as in Plus.

**CONFIRMED FINISHED**
- None. The last compile evidence is 2026-09-05 (`180155b`), before the parity work and before Firebase. It has never run under XCTest or on a Simulator.

**IMPLEMENTED BUT NOT APPLE-TESTED**
- Everything above, including the Arabic right-to-left interface with English left-to-right content, and the EnglishOnly catalog selection.

**CODE STILL MISSING**
- Everything listed for Plus.
- ◇ A strict English + left-to-right lock, if the owner requires it (§2.3).
- The device-language leakage, which is a defect under either requirement.
- A test or smoke run that actually runs this target and loads its catalog.

**EXTERNAL SETUP STILL MISSING**
- Same as Plus, for `com.appsbybros.minik.plus.english`: App ID with App Attest, profile, App Store Connect record, its own `remove_ads` in-app purchase (if kept), Firebase App Attest registration.
- Store metadata that accurately describes the language support (English learning vs. 10 declared UI languages).

**EXACT BLOCKERS TO TESTFLIGHT**
- The same six as Plus.
- Plus: this target must be built and smoke-launched on its own. No existing test covers it.

**EXACT BLOCKERS TO APP REVIEW**
- Same as Plus.
- Metadata accuracy for an "English" product that declares 9 other UI languages and offers an Arabic right-to-left option.
- Mixed-language screens on non-English devices.

---

## 3. MINIK Math

### 3.1 Inventory
- **Entry.** `MinikApp.swift:10-14` → `RootView` → Math hub. The Firebase bootstrap returns "unsupported" (`FirebaseRecordsIntegration.swift:48-49`). Math follows the system colour scheme and the system layout direction (`RootView.swift:66,70-72`).
- **Home** (`MinikActivityHubView.swift:395-460`):
  - logo, Home, a **trophy that always shows "Remote records are not configured for this build."** (`:413-421`; `RecordsLeaderboardView.swift:92-97`). Its accessibility hint also says "The records could not be loaded.".
  - the Parent Area button and the level card.
- **Sections** (`ActivityCatalog.swift:29-63`; `MathProductionActivity.swift:150-172`):
  - Learn: Learn Math, Math Cards / Facts Table.
  - Practice: Pairs, Build Number, Build Quantity, Visual→Answer, Answer→Representation, Build Math, Mixed.
  - Games: Soccer, Tower, Memory.
  - Just for Fun: Ping Pong.
  - There is no Math opening screen or onboarding.
- **Curriculum** (`MathCurriculum.swift:48-109`). Each level has its own content provider, a factory covering 12 activity types, and a SwiftUI router. Sessions have 6 challenges.

| Level | Topic and range |
|---|---|
| M1 | Quantities 0…10 |
| M2 | Addition and subtraction within 0…10 (14 facts) |
| M3 | Relationships within 0…20 (16) |
| M4 | Place value to 100 (19) |
| M5 | Multiplication and division (15 fixed facts) |
| M6 | Fluency, factors and fractions (17) |
| M7 | Fractions and decimals (12) |
| M8 | Fractions, decimals, percentages and ratio (about 10) |
| M9 | Pre-algebra, signed number line −10…10 (about 12) |
| M10 | Equations, proportion, probability, geometry (10) |

  The question pools are small (10–19 items at M2–M10), so children will see repeats quickly.
- **Levels** (`MathLevelProgression.swift`). Automatic mode starting at M1 is the default.
  - Placement: 3 calibration attempts (3/3 moves up 2, 2/3 up 1, otherwise down 1).
  - Promotion: 8 correct in a row, or 18 of the last 20.
  - Demotion: 7 wrong in a row, or 8 or fewer of the last 20.
  - After a promotion, 6 probation attempts; 4 failures revert it. After any change, a 10-attempt cooldown.
  - Manual mode never adapts. The Parent Area has the controls (`ParentAreaView.swift:271-311`).
  - Stored under `minik.math-level-state.v1` (not per product) and saved after every attempt.
- **Scoring and rewards.** Attempts feed progress and the level engine. **Math earns no points or streaks**; the master plan calls the Math reward policy "unapproved". Math's Records and Streaks screen is empty.
- **Children.** No profiles; one global Math level.
- **Localization.**
  - Of the 94 `String(localized:)` keys in `Math*.swift`, 71 are English in Hebrew.
  - **All 19 activity names and all 19 level titles are English in all 10 non-English languages** ("Learn Math", "Level 1", "Automatic", "Just for Fun").
  - The Ping Pong chooser and games have hard-coded English and Hebrew only.
  - Math strings follow the device language, while the Parent Area's interface-language picker changes only the injected locale. So a Hebrew device shows a mix until a parent selects Hebrew. Not verified at runtime.
- **Hebrew and right-to-left.** The hub follows the system direction. Math visuals are forced left-to-right (e.g. `MathStructuredRepresentationView.swift:29,110`; `MathNumberLinePlacementView.swift:81`).
- **Sound.** Prompts and facts are spoken in the interface-language voice. The submit buzzer vibrates. **There are no success or failure sound effects in Math.**
- **The "Encouraging messages" toggle appears in the Math Parent Area but does nothing there** (`ParentAreaView.swift:222`).
- **Lifecycle.** `RootView.swift:79-88` refreshes reminders, purchases and the Remove Ads reminder. `MathCardsView`'s timed mode does not respond to the app going to the background (`:70-72`).
- **iPhone and iPad.** Layout switches by width; nothing is locked to an orientation; nothing adapts to height for iPhone landscape. Not verified.
- **Parent Area.** Opens as a sheet; **entry is not gated**.
  - Contents: Math level, interface language, encouragement (no effect), weekly reminder, purchases, legal links, version, progress and records. There is no leaderboard section.
  - The addition gate protects purchase, restore and links.
- **Icon and Info.plist.**
  - `MinikMathAppIcon` is valid (1024 px, RGB, no alpha). Its provenance is undocumented (`app-icon-provenance.md` is contradicted).
  - `GADApplicationIdentifier` is `""` while the ads SDK is linked.
  - No entitlements file.

### 3.2 Ping Pong inside Math (documented only; nothing fixed)
- **Which implementation opens.** Two routes both open `MathPingPongChooser(commerce:onExit: returnToHub)` (`MinikActivityHubView.swift:283-284,920-921`). The chooser shows **MODERN** and **80's STYLE** (hard-coded English/Hebrew).
- **Modern Simple is integrated.** It opens `ModernPongView(experience: .simple, …)` (`MathPingPongChooser.swift:13`).
  - It always uses the local repository and never connects (`MPController.swift:47-51,61`).
  - Its menu has Standard/Pro, points, the opponent carousel, Start and the guide.
  - It reuses Math's purchase controller.
- **Retro 80's is integrated.** It opens `RetroPongView(onExit:)`, a web view loading `RetroPong/index.html` from the app bundle, with navigation outside the folder blocked and a strict content-security policy with `connect-src 'none'`.
- **Shared engines and files.**
  - `Sources/ModernPong/*` (14 files), Modern Pong assets and audio are shared with MinikPingPong (which runs `.full`).
  - `Sources/RetroPong/*` and `Resources/RetroPong` are shared with MinikRetroPingPong.
- **Parameters passed:**
  - **Modern:** the language comes from the injected locale (Hebrew or English only); Standard/Pro and the points target come from `modern.pong.v2.*`.
  - **Retro:** receives `window.__minikRetroConfig={language, state, paused}` (`RetroPongStorage.swift:43-48`).
  - **The Math level is not passed to either game.**
  - Retro inside Math runs with **Balloon Madness on by default** and `cameFromMath=false`, so it shows standalone "Minik Ping Pong" branding and no language toggle. Android Math instead launches `?from=math&madness=off`. The handoff records this as the owner's choice (`retro-pong-ios-handoff.md:26`).
- **Returning to Math.**
  - Modern: a finished match calls `completion(result)`; Back calls `completion(nil)`. Math ignores the result.
  - Retro: the page's `exitPong` sends an `exit` message, which calls `onExit` once.
  - Both then call `returnToHub()` (`route = nil`).
- **Does Math's state survive the trip?** Yes, by construction. Pong is a route inside the same hub view, so the hub's state stays alive, and the level state is saved after every attempt. Not verified at runtime.
- **Old and duplicate Pong engines still compiled into Math.** About 3,000 lines, none of them reachable from any screen:
  - `PingPongView` (446), `PingPongScene` (715), `PingPongRallyModel` (623), `PingPongRetroRally` (583), `PingPongRetroStyle` (332, of which only the `PingPongVisualStyle` enum is used), `PingPongMatchSession`, `PingPongTableLayout`, `PingPongPreferences`, and most of `PingPongModels` (only `PingPongAssetNames.minikPong` is used).
  - `PingPongAssets.xcassets` (about 15 MB) ships in Math although only `minik_pong` is used.
  - Six MP3s are duplicated between Modern and Retro, plus an 844 KB base64 audio bank.
- **Does unfinished Pong code block Math?** **Yes, potentially.** MinikMath compiles all of `Sources/`, including Modern (`b15717f`) and Retro (`eeb326e`), which Xcode has never type-checked. Any compile error in them, in the legacy Pong code, or in the ads adapters blocks the Math build. There is also a link-error risk: `FirebaseRecordsIntegration.swift:3` uses a bare `canImport(...)` and could succeed for Math inside a shared DerivedData folder. The simulator workflow avoids this by using a separate DerivedData per scheme. Unproven.

### 3.3 Tests (written; not run at HEAD)
- 27 `Math*Tests.swift` files with 290 methods: content providers (ranges, uniqueness, distractors, fraction semantics), factories (every activity type builds a session; Mixed never repeats the previous mode), `MathLevelProgressionTests` (26), sessions.
- `MathObjectCatalogTests` decodes inline JSON only, never the bundled manifest, which starts with a UTF-8 byte-order mark and is read with `try?`.
- Pong in Math:
  - `ModernPongParityTests.testSimpleMatchDoesNotConnectAndClosesOnce`;
  - `RetroPongHostTests` (7; no web view);
  - JavaScript tests for Retro.
- **Never tested:** the chooser, the Math→Pong→Math round trip, Math-target resources and Info.plist, and runtime localization. The MinikPlus test host does not bundle the Math resources.

### 3.4 Documentation claims (Math)
- `math-production-matrix.md` (120 cells): CURRENT, VERIFIED BY SOURCE, not verified at runtime. Its Ping Pong cells are STALE.
- `math-educational-core-audit.md`: M1–M10 claims VERIFIED. Its "286 keys" and "no hard-coded strings" are STALE / CONTRADICTED.
- **CONTRADICTED:**
  - `math-levels-4-10-inventory.md`
  - `product-architecture.md:124,126`
  - `current-migration-status.md`
  - `release-configuration.md:114-116` and `app-store-privacy-data-inventory.md:11` ("Math shows ads through Ping Pong")
  - `MINIK_MASTER_PLAN` §7.13 (the old Pong engine)
  - `app-icon-provenance.md`
- `apple-release-checklist.md:11,91`: VERIFIED BY SOURCE. Its `:40` (create `remove_ads` for Math) conflicts with Math having no ads.

### MINIK Math: status lists

**ALREADY BUILT (source)**
- The Math target, hub, levels M1–M10 × 12 activities, Mixed and Cards.
- Automatic/Manual level engine with saved state; local progress statistics.
- Parent Area (level, interface language, reminders, gated purchase, restore and links).
- Remove Ads purchase code; local-only privacy manifest; app icon.
- The Ping Pong chooser with Modern Simple (native) and Retro (web view), including the return to Math.

**CONFIRMED FINISHED**
- Static only: the Math `project.yml` wiring (bundle ID, name, version, resources, packages without Firebase); a valid icon; a privacy manifest present.
- The Retro web layer's Windows tests are recorded as passing.
- Historical only: MinikMath BUILD SUCCEEDED at `7bc1511` and `180155b`.
- **Nothing is confirmed on Apple at HEAD.**

**IMPLEMENTED BUT NOT APPLE-TESTED**
- All M1–M10 activities and layouts; speech and vibration; right-to-left; Dynamic Type and VoiceOver.
- Automatic levels; Parent Area and gate; StoreKit; reminders.
- Modern Simple and Retro inside Math, and the round trip.
- iPad, landscape and dark mode.
- The ads SDK linked with an empty app ID.
- Compiling the asset catalogs (about 175 MB of raw resources); decoding the manifest that starts with a byte-order mark.

**CODE STILL MISSING** (◇ = needs an owner decision first)
- ◇ Either Math ad placements, **or** removing Remove Ads (and possibly the ads SDK) from Math.
- ◇ Either Math records and leaderboard, **or** hiding the trophy.
- ◇ A points and rewards policy for Math.
- Translations of the Math strings.
- ◇ Ping Pong languages beyond English and Hebrew.
- Consistent use of the interface language vs. the device language.
- ◇ Child profiles.
- ◇ Access-code redemption (Android Math uses `app_id "4"`).
- ◇ Larger question pools.
- The encouragement toggle wired into Math, or removed from it.
- The 2 missing catalog keys; the trophy's accessibility hint text.
- Removing the legacy Pong code and assets.

**EXTERNAL SETUP STILL MISSING**
- Push the 4 commits; run the Simulator workflows or a Mac build.
- Apple Team, App ID, certificate and profile.
- App Store Connect record, category, age rating, Kids decision, App Privacy answers (including the ads SDK's own manifest), export compliance.
- The live privacy policy and Terms decision.
- ◇ A `remove_ads` in-app purchase, if Remove Ads is kept.
- **The owner must decide who owns `com.appsbybros.minik.math`: native Math or the v23 WebView package.**
- Screenshots from a working build.

**EXACT BLOCKERS TO TESTFLIGHT**
1. HEAD has never been compiled. Any compile error anywhere in `Sources/` blocks Math.
2. A Simulator launch check for the empty ads app ID with the ads SDK linked.
3. Team, App ID, signing and profile; an App Store Connect record; an archive and upload path.
4. The bundle-ID conflict with the v23 WebView package must be resolved before any upload.
5. Minor: the export-compliance answer at upload; 1.7.9 / 79 must be valid for the new record.

**EXACT BLOCKERS TO APP REVIEW**
- A Remove Ads purchase and Restore in an app with no ads (guidelines 2.1 / 2.3 / 3.1).
- A home trophy that always says "not configured" (an incomplete feature).
- 11 declared languages while the Math content is English in 10 of them.
- Kids Category, age rating, privacy policy and App Privacy answers; a declared "local-only" privacy manifest while the ads SDK is linked.
- Device testing and screenshots have never been done.

---

## 4. Modern Ping Pong (standalone)

The Android reference is `C:\Projects\MinikPingPong`, HEAD `202b808` (2026-09-30), clean working tree.

### 4.1 Full vs Simple
- The `ModernPongExperience` enum (`MPMultiplayerModels.swift:3-9`) has two modes:
  - `.full` has online play, tournaments and profiles;
  - `.simple` closes after one match.
- **Full = the standalone app** (`MinikApp.swift:13` → `RootView.swift:54-55` → `PingPongOnlyRootView.swift:6`). Firebase is used only when `MINIK_PING_PONG` is set and Firebase can be imported (`MPController.swift:47-51`). Otherwise it falls back to `MPLocalRepository`.
- **Simple = inside Math** (§3.2).
- **`eeb326e` did not change `Sources/ModernPong/*`.** All 14 files still match the hashes recorded in `docs/modern-pong-changes.json`.
- **The iOS port is behind Android.** It was made on 09-28 (`b15717f`), and Android changed 18 core files on 2026-09-29, including `ModernEngine.kt`, `Tuning.kt`, `BotRoster.kt`, `MatchLink.kt`, `PongModels.kt`, `FirebasePongRepository.kt`, `HouseStrategy.kt` and the database rules generator.
- **The repository's own parity check now FAILS:** `Scripts/audit-modern-pong.py` stops with `AssertionError: Exact Android house-player identity/skills: flare`. The handoff's "PASS: 152 checks" is stale. All 43 Android asset hashes are still identical.

### 4.2 LOCAL gameplay

**Nothing in this table has been compiled, run on a Simulator or device, or tested between Android and iOS.**

| Item | Status | Evidence | Unit test (written, **never run**) |
|---|---|---|---|
| Physics (flight, gravity, spin, net, bounce) | Yes | `MPPhysics.swift:203-276`, matching `ModernEngine.kt:221-323` | `testPlainTapKeepsLateralDirection`, `testWideDiagonalReturnsReachOppositeSideline`, `testProRetainsWeakAndOverpoweredFailures` |
| Serving (tap, swipe, Minik serve, alternation) | Partial | `MPPhysics.swift:152-172`, `MPEngine.swift:149-160`. Minik's serve faults use a plain random roll; Android now uses `ServeReliability`. | `testServeSpreadsDiagonalAcrossBothBounces`, `testPaddleNeverFollowsServeTargetAcrossNetAndPersistsOnRelease` |
| Scoring (3/5/7/10 and 3/5/7/11, deuce) | Yes, for levels 0–3 | `MPPhysics.swift:22-28,52-64` | Indirect only |
| Faults (net, first bounce out, second bounce, left table, illegal serve, unreturned) | Yes | `MPPhysics.swift:29-32`, `MPEngine.swift:236-250` | `testGuideRejectsWrongServeSide` |
| Net and bounce handling | Yes | part of physics | as above |
| Difficulty | **Partial** | Four levels, easy to superHard. The UI offers Standard/Pro, and practice offers four levels. **Android's `BEGINNER` level (automatic contact, now Android's default) is missing.** The Standard stroke window differs: iOS 0.62 vs Android STARTER 0.40. | `testControlMappingAndForgiveness`, `testPracticeDoesNotInheritHousePlayerEasyAssistance` |
| Controls: Tap / Swipe / Arrows | Tap and Swipe: Yes. **Arrows: not applicable** (Modern has no arrows on either platform; arrows exist only in Retro). | `MPEngine.swift:253-303`, `MPScene.swift:166-183` | `testControlMappingAndForgiveness` |
| Tutorial / guide | Partial | 8 steps; Android has 9, including a Beginner lesson. **The "Don't show the guide automatically" toggle does nothing** (`MPController.swift:242,290`; `ModernPongView.swift:375`). | `testTutorialOrderAndRealLandingFeedback` |
| Settings | Partial | Control level and points; in-game settings sheet. **No sound toggle.** | `testOldControlPreferenceIgnoredAndSimpleCapabilities` |
| Sound | Yes | `MPAudio.swift:25-38`. Small difference: iOS plays the failure sound on an illegal serve; Android does not. | none |
| Presentation | Yes | SpriteKit scene at 120 Hz with opponent sprite sheets. iOS keeps a walk cycle that Android removed. | none |
| House-player roster (11 characters) | Yes, **but out of date** | `MPRoster.swift:3-16`. iOS: Flare speed 10, Kyra 9, Kyra's Hebrew name "קשת". Android now: Flare 9, Kyra 10, "ספיר". | `testSpeedCapsAndStrongerHousePlayers` asserts the *old* order |
| Character stats → AI | Partial | Stats always start from the easy base. Android now derives the level from skill and adds `HouseStrategy`. | as above |
| Bots (intercept, reach) | Yes | `MPEngine.swift:50-68,210-235` | `testRequestedAIProbabilitiesUseAllAttempts`, `testStatisticalAIOrderingAcrossZonesAndFatigue` |

### 4.3 The standalone product

| Item | Status | Evidence |
|---|---|---|
| Startup and menu | Yes | `ModernPongView.swift:90-125`. **On the first launch of Full it signs in anonymously and reserves a nickname in the production database without any user action** (`MPController.swift:61-69`; `MPRepository.swift:129,144-157`). |
| **Hebrew** | **Unreachable (found by reading source)** | `RootView.swift:69` injects the interface language, which defaults to English. The only language picker is in the Parent Area, which the Pong app does not have. So `he` in `ModernPongView.swift:31` is always false: no Hebrew UI, right-to-left layout or Hebrew nicknames. `CFBundleLocalizations` still declares 11 languages. |
| Profile, nickname, avatars | Yes | 11 characters plus 6 emoji; 100 curated names per language (`ModernPongView.swift:179-200`; `MPPreferences.swift:3-20`) |
| Opponent selector | Yes | Carousel with stats (`ModernPongView.swift:145-161`) |
| Game history | Partial | Room lists, fixtures and notices. For local single games only `lastCompletedMatch` is kept. |
| Local play | Yes | In Full, choosing a house player **creates a Firebase room when online**. It is purely local only when offline (`MPController.swift:97-107`). |

### 4.4 ONLINE (Full only; `MPFirebaseRepository` is compiled only in the MinikPingPong target)
- **Firebase.**
  - Project `minikswish`; iOS app `com.appsbybros.minik.pingpong`. Android uses `…pingpong.modern`, a different app ID.
  - Named Firebase app `minik-ping-pong-ios`, started only if the bundle ID and project ID match (`MPRepository.swift:112,118-124`).
  - The database URL (europe-west1) is in the config file and also hard-coded (`:126`). Root path `minikPingPong`.
  - **No App Check.**

| Item | Implemented (source) | Evidence | Test (written, not run) |
|---|---|---|---|
| Anonymous sign-in | Yes | `MPRepository.swift:129` | none (Firebase code is not compiled in the test host) |
| Root paths | Yes, **identical to Android**: `profiles`, `nicknames`, `openSlots/{uid}/{kind}/{0..2}`, `friendlyRooms`, `tournaments`, `live/{match}/checkpoint`, `live/{match}/actions/{uid}/{seq%16}` | `MPRepository.swift:130-235` | none |
| Friendly rooms, room code, host and guest | Yes | `MPMultiplayerModels.swift:149-162`; `MPController.swift:108-134` | `testReadyStartsExactlyOnceAndOnlyAuthorityFinishes` |
| Ready and a single start | Yes | `:187-199`; `MPController.swift:141-168` | same |
| Authority (smallest human UID) | Yes | `MPSession.authority` (`:108`) | same |
| Live checkpoints and revisions | Yes | `MPMatchLink.swift` (lines 71-89); `MPRepository.swift:222-231` | `testCheckpointReflectionIsInvolutive`, `testRestoringOnlineCheckpointDoesNotJumpLocalPaddle` |
| Bounded action ring and sequence handling | Yes | `MPRepository.swift:232-234`; `MPMatchLink` `seen[remote]`; saved sequence | none |
| Reconnection, presence, disconnect and rejoin | Yes | onDisconnect presence slots and `.info/connected` (`MPRepository.swift:205-215`); lifecycle handling (`MPController.swift:248-259`) | `testFirebaseNumericPresenceSlotsDecode` |
| Result finished once only | Yes | `MPRules.finish` (`:205-212`); `handledResults` | as above |
| Bot matches and human vs human | Yes (source only) | `MPController.launch` (`:205-213`) | `testSelectingHousePlayerStartsFriendlyOnceWithoutExtraScreen` (local repository) |
| Cleanup and the 3 + 3 open-room limit | Yes | `MPRepository.swift:165-176,247-265` | `testLocalOpenGameLimitAndPersistence` |

**Android / iOS wire format.** Every field name and type matches Android for rooms, matches, identity, bots, checkpoints, actions, engine state, score, flight and serve. The match-ID seed folding, enum strings and numeric-slot handling also match.

**Mismatches in meaning:**
1. **Difficulty 4 (Beginner), Android's default room setting, breaks on iOS.** iOS `validFinal` requires a two-point lead for every `difficulty >= 2` (`MPMultiplayerModels.swift:200-204`), while Android and the current rules require no lead for 4. iOS also plays difficulty 4 with the Standard engine. **When iOS runs the match, a final score such as 7-6 throws `invalidResult`. The result is never saved and the match stays PLAYING.**
2. **Roster stats and names differ** (Flare, Kyra). **Nickname risk:** the current Android rules accept Kyra's Hebrew nicknames only as "ספיר …", so iOS "קשת …" nicknames would be rejected if that rules version is live.
3. An iOS guest awards points locally; Android does not.
4. The late-return grace period is 0.65 s on iOS vs 2.0 s on Android, so an iOS match host gives Android guests less time.
5. iOS lacks Android's "acknowledged local flight" restore shortcut.
6. Bot-vs-bot tournament results use a different random generator. Harmless, because the result is written once.
7. Only the host can close a friendly room on iOS. Stricter than Android, but compatible.
8. **The rules snapshot in the repo is stale.** `Tests/ModernPongFirebase/rules/merged.json` differs from Android's 09-29 rules in 6 expressions; the 88 paths themselves are identical. The iOS copy of the rules tests is also stale.

**Cross-platform status: NOT COMPLETE.** There is **no Android ↔ iOS runtime evidence**. Only Android ↔ Android was tested live (`LIVE_FIREBASE_VERIFICATION.md` in the Android repo).

### 4.5 Tournaments

| Item | Status | Evidence (tests written, not run) |
|---|---|---|
| Creation; 2–8 players; play each opponent once or twice | Yes | `ModernPongView.swift:170-178`; `MPRules.start` (`:169-186`) |
| Humans and house bots, no duplicates | Yes | `MPRules.add` (`:163-168`); `testTournamentUniqueHousePlayersAndDurableResults`. **Removing a house player (which Android has) is missing.** |
| Round robin; bot-vs-bot results decided at the start | Yes | same test |
| Win/loss points | **Partial.** Standings use the stored values, but iOS is **fixed at 3/0**, with no 1–5 selector. | `:225-237` |
| Standings and match history | Yes | `ModernPongView.swift:257-296` |
| Continues without the host; host transfer | Yes | `MPRules.leave` (`:214-224`); `testLeavingTournamentTransfersHostAndPreservesFinishedResults` |
| Reconnect and duplicate-result protection | Yes | same mechanisms as friendly rooms |

### 4.6 Verification matrix (Modern)

| Evidence type | Status |
|---|---|
| Implemented in source | Most items (tables above) |
| Covered by Swift unit or parity tests | 25 methods in `ModernPongParityTests`, **written but never run**. They do not cover `MPFirebaseRepository`, `MPMatchLink`, `MPScene` or `MPAds`. |
| Statically inspected only | Everything |
| Compiled by Xcode | **No** |
| Run on a Simulator | **No** |
| Run on real Apple hardware | **No** |
| Tested Android ↔ iOS | **No** |
| Database rules emulator | 43/43 passed on 09-28 (JavaScript SDK), **against a rules snapshot that is now stale** |

### 4.7 Monetization and privacy (short; details in §7)
- Ads: Debug only, with Google test IDs. **Release has no ads**, yet **Release ships Google's sample `GADApplicationIdentifier`** (`project.yml:283`).
- Menu → "Remove ads" → purchase, restore and **"Redeem App Store code" with no parent gate** (`ModernPongView.swift:116,403-414,66`).
- `RootView` still starts the app-wide ad coordinator and Remove Ads reminder for Pong.
- **No in-app privacy link.** Profiles and nicknames are created at launch with no opt-in and cannot be deleted from the app (only rooms can be closed).

### 4.8 Documentation claims (Modern)
- **CURRENT AND VERIFIED BY SOURCE:**
  - the Full and Simple entry points and the Math routing (handoff note at :5);
  - the Firebase project, bundle ID, named app, database and paths;
  - the AI-profile table and the audio table;
  - ads Debug-only;
  - the rules test log (43/43);
  - "25 XCTests written, not run" and "Xcode not run".
- **CURRENT BUT NOT RUNTIME-VERIFIED:** every behaviour claim.
- **STALE:** "152 checks PASS"; "Math routes unchanged" and "Math not wired" (:14, :25); "builds all four flavors"; the rules snapshot and tests; the Kyra naming.
- **CONTRADICTED:** "house-player stats match the reference"; "grace period matches Android"; overall "current Android" parity (Beginner, 9-lesson tutorial, `controlTuning`, `HouseStrategy`, `ServeReliability`).
- **Also CONTRADICTED:** `MINIK_MASTER_PLAN.md:2064` "Standalone MinikPingPong has no commerce surface".
- **UNKNOWN:** which database rules are live; API-key restrictions; whether the owner has enabled anonymous sign-in.

### Modern Ping Pong: status lists

**ALREADY BUILT (source)**
- Native engine and tuning, tutorial, SpriteKit court, audio, 11-character roster.
- Profiles and nicknames; friendly rooms; tournaments.
- Database transport: presence, action ring, checkpoints, match authority, cleanup, the 3 + 3 limit.
- Debug test ads; StoreKit UI; the Full and Simple entry points.
- 25 XCTests; a Node rules-test harness.

**CONFIRMED FINISHED**
- By evidence only, not at runtime:
  - the Firebase config file matches the bundle ID and project;
  - all 43 asset hashes match Android;
  - the AI-profile numbers match current Android;
  - the database rules emulator passed 43/43 against the now-stale snapshot.

**IMPLEMENTED BUT NOT APPLE-TESTED**
- Everything: 0 compiles, 0 XCTest runs, 0 Simulator runs, 0 device runs, 0 Android ↔ iOS runs.

**CODE STILL MISSING** (◇ = owner scope decision)
1. Beginner (difficulty 4): the `validFinal` fix, automatic contact, the Beginner tutorial lesson.
2. Update the roster (Flare and Kyra stats, Kyra's Hebrew name) and its test.
3. ◇ Port Android's 09-29 engine changes: `controlTuning`, `HouseStrategy`, `ServeReliability`, no guest scoring, the 2.0 s grace period, the restore shortcut, the stroke window, presentation.
4. Make Hebrew reachable in the standalone app.
5. Make the skip-guide toggle work.
6. ◇ The win-points selector and removing a house player from a tournament.
7. ◇ A sound toggle.
8. ◇ Local match history.
9. Tests for `MPFirebaseRepository` and `MPMatchLink`.
10. Refresh the rules snapshot and rules tests.
11. A parent gate before purchase, restore and offer codes.
12. ◇ A production ads path, **or** hide Remove Ads; replace the sample ads app ID in Release either way.
13. An in-app privacy link.
14. ◇ An opt-in before creating the online profile, and profile deletion.

**EXTERNAL SETUP STILL MISSING**
- Push the 4 commits and run `ios-simulator.yml`, or build on a Mac.
- Apple App ID, certificate and profile.
- App Store Connect record, a `remove_ads` in-app purchase and offer codes (and confirm offer codes for non-consumables are supported with an iOS 17 minimum).
- Firebase `minikswish`:
  - confirm the iOS app registration and API-key restrictions;
  - confirm anonymous sign-in is enabled;
  - publish or confirm the current (09-29) database rules and check they accept iOS writes.
- ◇ An App Check decision for the database.
- ◇ A production AdMob iOS app ID and ad units, plus SKAdNetwork entries, if ads are wanted.
- Publish the privacy-policy addendum; fill in the App Privacy labels.

**EXACT BLOCKERS TO TESTFLIGHT**
1. No Xcode compile ever. The Firebase code that only exists in this target and the long type-inference expressions are the least-known parts.
2. Team, App ID, profile, and a successful Release archive (Release has never been compiled for any target).
3. An App Store Connect record for `com.appsbybros.minik.pingpong`.
4. For meaningful online testing: the confirmed live database rules and API key. Note that **any launch, including CI smoke tests, writes to the production database.**

**EXACT BLOCKERS TO APP REVIEW**
1. No runtime or crash evidence on any device.
2. Remove Ads is sold while Release shows no ads; the in-app purchase must also exist and be submitted.
3. Privacy policy and a data-deletion path for profiles and nicknames that are created automatically at launch; no in-app privacy link (guideline 5.1.1).
4. Kids Category, if chosen: purchase and offer codes have no gate; an ads SDK is linked; Google's sample app ID ships in Release.
5. 11 declared languages while the standalone UI is English only (Hebrew cannot be reached).
6. Cross-platform play must not dead-end: fix the difficulty-4 result bug first.
7. Guideline 4.3 (similar apps) risk: two Pong apps, plus Math containing both.

---

## 5. Retro / 80's Ping Pong

### 5.1 What exists
- **The current game** is the Android web game (HTML, Canvas and JavaScript), bundled into the app and shown in a web view (WKWebView):
  - `Sources/RetroPong/RetroPongView.swift` (130 lines), the native host:
    - loads `RetroPong/index.html` from the app bundle;
    - handles `save`, `music` and `exit` messages from the page;
    - blocks navigation outside the game folder (`:119-122`);
    - recovers if the web process is killed (`:125-128`);
    - plays the menu music natively (`:92-98`).
  - `RetroPongStorage.swift` (58 lines) checks and mirrors progress to `minik.retro-pong.progress.v1`, and imports older settings keys.
  - `MathPingPongChooser.swift` (35 lines).
  - `Resources/RetroPong/`: 73 files from Android plus `ios-host.js` and `ios-host.css`. `index.html` adds an offline content-security policy.
- **An abandoned native attempt:** `Sources/PingPongRetroStyle.swift` (332) and `PingPongRetroRally.swift` (583), from `ac3e71d`. Basic Pong only. **It cannot be reached from any screen but is compiled into every target.**
- **Where the web game came from:**
  - `docs/retro-pong-android-provenance.json`: all 73 entries point to the **obsolete** `C:\Projects\minik80sPingPong` (last changed 09-26).
  - The only iOS edits:
    - the device check accepts `MinikNative/(iOS)`;
    - the language comes from the host;
    - iOS is always treated as a mobile device;
    - the content-security policy and host files.
  - **Current Bounce & Learn** (`MinikPaddleAndLearn`, changed 09-28 to 09-30) has things iOS lacks:
    - its branding and logo;
    - in-game Back returning to setup;
    - `minik-monetization.js` (ads after a match, a parent menu);
    - the `pong-layout.css` fix that stops the win/lose caption being clipped.
  - **Android Math's copy** also adds a Math mode, an English/Hebrew toggle, and full-screen portrait on tablets.
- **Verdict:** the core gameplay matches current Android. Branding, Back behaviour, monetization, the layout fix and tablet portrait are behind.

### 5.2 Feature checklist (all gameplay is in the web layer)

| Feature | Present | Evidence |
|---|---|---|
| Basic Pong | Yes | `app.js:2206` `go("pong")`; `:2076-2079` |
| Train maths questions | Yes | `pong-extras.js:114` `makeQuestion`; first train after 5 s, again after 15 s (`:137-139,643,659`) |
| Tapping wagons | Yes | `pong-extras.js:424-428,455-467` (a correct answer gives +3) |
| Train collisions | Yes, **only when Balloon Madness is on** | `pong-extras.js:577-607`; `app.js:1994` |
| Balloon Madness | Yes | `app.js:1075,1078,1616,1643,1668,1894,909,929` |
| Cumulative points | Yes | `pong-extras.js:180-187`; `app.js:940` |
| Paddle ranks | Yes | thresholds 0/100/200/300/500/700/900/1200 (`pong-extras.js:7-10,83`) |
| Paddle colours | Yes | `pong-extras.js:82,84` |
| Paddle widths | Yes | `pong-extras.js:86-87`; `app.js:1044` |
| Arrows | Yes (the default control) | `pong-extras.js:56,104` |
| Difficulty | Yes | `app.js:1194-1219,955,1011`; checked natively at `RetroPongStorage.swift:15` |
| Points to win 3/5/7/11 | Yes | `app.js:963,1018` |
| 3-2-1 countdown | Yes | `app.js:1978-1985` |
| Help and settings | Yes | `app.js:939`; `pong-extras.js:14-26,32,265,330-345` |
| Saved progress | Yes (web localStorage plus a native copy) | `pong-extras.js:5,59,73`; `ios-host.js`; `RetroPongStorage.swift:37-48` |
| Audio | Yes | `minik-audio.js:71,116,145`; native menu music |
| English | Yes | `app.js:148-164` |
| Hebrew and right-to-left | Yes | `app.js:64-80,401-402`. **Standalone:** language comes from the device locale (`RetroPongView.swift:7,12,23`). **Inside Math:** from Math's interface language (English unless a parent selects Hebrew). |
| iPhone | Declared, **not verified** | `project.yml` device family and orientations |
| iPad | Declared, **not verified**. Portrait shows only a "landscape recommended" hint (`app.js:388-397`); no tablet-portrait fix. | – |

### 5.3 The five questions

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Does Retro code exist? | **Yes.** The web game and native host are in `Sources/RetroPong/*` and `Resources/RetroPong/`. There is also the unreachable native skin (`PingPongRetroStyle` / `PingPongRetroRally`). | files listed above |
| 2 | Is there a standalone Retro app target? | **Yes, in source.** `MinikRetroPingPong`, `com.appsbybros.minik.pingpong.retro`, "Minik 80s Pong". **Its Back button has no `onExit`**, so it shows a dead-end "Game closed – return to Home screen" panel (`app.js:466-487`). | `project.yml:306-331,369-374`; `MinikApp.swift:10-11` |
| 3 | Can MINIK Math open Retro? | **Yes, in source.** Just for Fun → Ping Pong → chooser → "80's STYLE" → `RetroPongView(onExit:)`. Back returns to Math. | `ActivityCatalog.swift:50-62`; `MinikActivityHubView.swift:283-284,549-551`; `MathPingPongChooser.swift:14,25,33`; `project.yml:226-228` |
| 4 | Can Retro be reached in the Modern standalone app? | **No.** `PingPongOnlyRootView` shows only `ModernPongView(.full)`. The target does not bundle `Resources/RetroPong`. The old "Modern / 80s Style" mode picker (`PingPongView.swift:183-186,226-232`) is dead code. | `PingPongOnlyRootView.swift:3-6`; `project.yml:263-305` |
| 5 | Has any Retro build been compiled or run through Xcode? | **No (UNPROVEN).** `"native_build_verified": false`. `retro-pong-simulator.yml` runs only when started by hand and has never been pushed, so it has never run. The last Mac build (09-05) predates Retro. No screenshots, `.xcresult` or logs exist. | `retro-pong-ios-handoff.md:3,106-110`; `docs/retro-pong-evidence/windows-checks.json`; `git log origin/main -- .github/workflows/retro-pong-simulator.yml` is empty |

### 5.4 Tests
- **XCTest:** `RetroPongHostTests` has 7 tests: storage defaults, legacy import, validation and the 8 KB limit, safe startup-script injection, navigation containment. **They have never run.** They are hosted by MinikPlus, which does not bundle the Retro folder. **Nothing tests the web view itself.**
- **JavaScript:** `Tests/RetroPong/engine.test.cjs` (16) and `host.test.cjs` (7), using a fake DOM at 1000×400 only, with no iPad size. **Recorded as passing** in `windows-checks.json`. They were not re-run in this audit: permission to run them was denied, and I did not work around the denial.
- **Static checks:** `Scripts/audit-retro-pong.py`, 191 checks, recorded as passing.
- No TODO, FIXME, fatalError or placeholder markers in Retro files.

### 5.5 Identity and monetization
- **Names disagree.** The app is "Minik 80s Pong", but the in-game branding says "Minik Ping Pong" (`index.html:11`; `minik-ping-pong-logo.webp`), which is also the name of the separate Modern app. Android's equivalent is "MINIK Bounce & Learn" (`com.appsbybros.minik.bouncelearn`).
- **The icon is byte-identical to Modern Pong's.**
- Retro reuses `ProductVariant.minikPingPong`. Any future per-product configuration or purchase would need its own variant.
- **Languages.** The target bundles the 11-language catalog but declares `[en, he]`.
- **Monetization.** No ads, no Remove Ads, no purchase, no code redemption, recorded as the owner's decision (`MINIK_MASTER_PLAN.md:2206`). Android Bounce & Learn uses access codes with `app_id "5"`. AppStoreCommerceKit is linked only so the shared code compiles.
- **Privacy.** `LocalOnly` is accurate. **There is no in-app privacy link**: the web footer link is hidden (`ios-host.css:4`) and all outside navigation is blocked.

### 5.6 Documentation claims (Retro)
- **CURRENT AND VERIFIED BY SOURCE:**
  - handoff :3 and :106-110 (no Xcode, IPA or Simulator run);
  - :10-11 (commits not pushed);
  - :12 (reference is `minik80sPingPong`);
  - the launch table, bundle and name;
  - the gameplay tables;
  - the storage notes;
  - 73 provenance entries;
  - `retro-pong-changes.json` (all 96 hashes match the working tree);
  - "old native Pong unused".
- **CURRENT BUT NOT RUNTIME-VERIFIED:** safe-area and web-view layout; the audio table; the recorded Windows results.
- **STALE:** "current Android 80's game / current Back behaviour" (:15-17, :32, :48), and the master plan's "matches current Android 80's", because current Android is now Bounce & Learn.
- **UNKNOWN:** "six Swift files parse without grammar errors" (no log).

### Retro / 80's: status lists

**ALREADY BUILT (source)**
- The shared web game with its native host, storage copy, background/foreground handling, navigation lock, web-process recovery and menu music.
- The standalone target, icon and scheme.
- The Math chooser route with Back to Math.
- 7 XCTests, 23 JavaScript tests, the provenance and audit script, and a Simulator workflow started by hand.

**CONFIRMED FINISHED**
- Source wiring for questions 2–4.
- The payload is exactly the obsolete Android version plus four small iOS edits (hashes).
- The 96-file inventory matches the working tree.
- Windows checks recorded as passing.
- **Nothing is confirmed on Apple.**

**IMPLEMENTED BUT NOT APPLE-TESTED**
- Every feature in §5.2.
- Both routes; saved progress; audio; Hebrew right-to-left; iPhone and iPad layouts; background and foreground; web-process recovery; the 7 XCTests.
- **Whether the page even loads** under `file://` with the content-security policy (`script-src 'self'`) and script URLs that carry query strings.

**CODE STILL MISSING** (◇ = depends on the owner's choice of baseline and scope)
- ◇ Bounce & Learn branding and logo, or a consistent iOS name.
- Back in the standalone app that does not lead to a dead end.
- The `pong-layout.css` caption fix.
- ◇ Tablet portrait support.
- ◇ A Math-flavoured version inside iOS Math (`from=math`, Madness off).
- ◇ Monetization parity (ads, Remove Ads, parent menu, `app_id 5` codes).
- A separate `ProductVariant` for Retro.
- Trimming the target's languages to English and Hebrew.
- An in-app privacy link.
- A distinct app icon.
- Any runtime or UI test of the web view.

**EXTERNAL SETUP STILL MISSING**
- Push the 4 commits and run `retro-pong-simulator.yml`, or build on a Mac.
- Register the new App ID `com.appsbybros.minik.pingpong.retro`; profile.
- App Store Connect record (the SKU is "owner to choose"), name, URLs, age rating, App Privacy label, iPhone and iPad screenshots.
- A signed archive and upload path. `codemagic.yaml` and `ios-simulator.yml` list only 4 schemes, and the Retro workflow is Simulator-only and unsigned.

**EXACT BLOCKERS TO TESTFLIGHT**
1. Never compiled. It also compiles all of `Sources/`, including Modern (`b15717f`), which has also never been compiled.
2. The commits are not pushed, so its workflow cannot run.
3. No team or profile; App ID not registered; no App Store Connect record.
4. No archive, export or upload path for `MinikRetroPingPong`.

Not blockers: the icon is technically valid, and the launch screen and privacy manifest are present.

**EXACT BLOCKERS TO APP REVIEW**
1. No proof the game loads. A blank screen would be a guideline 2.1 rejection.
2. The standalone Back leads to a dead end.
3. A universal app with no iPad check; portrait shows only a hint (guideline 2.4.1).
4. Metadata: "Minik 80s Pong" vs the in-game "Minik Ping Pong"; 11 bundled languages vs English and Hebrew support; no in-app privacy link.
5. Risk under guideline 4.3 (two Pong apps plus Math containing both) and 4.2 (a wrapped web game). These are risks, not certainties.
6. The same icon as Modern Pong.

---

## 6. Shared Firebase and leaderboard compatibility

### 6.1 Firebase per target

| Target | Firebase project | Config file (BUNDLE_ID matches?) | Auth | Firestore | Realtime Database | Analytics | Crashlytics | App Check | Registration status |
|---|---|---|---|---|---|---|---|---|---|
| MinikPlus | `easycallandanswer` | Yes, copied by the pre-build script that checks BUNDLE_ID | Anonymous | Yes (leaderboard v2) | Not used (the config file has a database URL) | Off (`IS_ANALYTICS_ENABLED` false); SDK not linked | Not linked | **App Attest in Release; debug provider in DEBUG**; no DeviceCheck fallback; `appattest-environment = production` | Config file is iOS-typed. Console registration and App Check: **UNKNOWN** |
| MinikPlusEnglish | `easycallandanswer` | Yes (same script) | Anonymous | Yes | Not used | Off | Not linked | same as Plus | same |
| MinikMath | – | none | – | – | – | – | – | – | none, by design |
| MinikPingPong | **`minikswish`** | Yes, bundled directly (no build-time check; a mismatch silently falls back to local mode) | Anonymous | – | **Yes** (`minikPingPong` root) | Off | Not linked | **None** (no dependency, no entitlement) | Config file present. The owner says anonymous sign-in and database rules are enabled (`apple-release-checklist.md:61`); **UNKNOWN** from the repo. |
| MinikRetroPingPong | – | none | – | – | – | – | – | – | none, by design |

- **Startup order (Plus and English).** The App Check provider is installed before `FirebaseApp.configure(options:)` (`FirebaseRecordsIntegration.swift:62-63`). The Release `preconditionFailure` at `:121` cannot be reached.
- **Pong.** Firebase starts lazily in `MPFirebaseRepository.configured()`, as a named app, and only if the bundle ID and project match.
- **Build risk.** `FirebaseRecordsIntegration.swift` is guarded only by `canImport` (`:3,52,82,113`), with no product condition. This is a possible link-error risk when several schemes share one DerivedData folder (`ios-ci.yml` does this). Unproven.
- **Docs print the Pong `GOOGLE_APP_ID` in full:** `apple-release-checklist.md:61`, `release-configuration.md:229`, `MINIK_MASTER_PLAN.md:3255`. It is a client identifier, not a secret, but worth noting.

### 6.2 Firestore rules: which file is authoritative
- **Rules compared against:** `C:\Projects\Minik\firebase\firestore.rules`, the Android repository's rules. Android work treats this file as the production rules. **The live console state was not queried in this audit.**
- **The iOS repository's `firestore.rules` must not be deployed as it is.** Its header says "SECURE ACTIVE-LEADERBOARD MIGRATION TARGET — DO NOT DEPLOY YET" (`:3-6`). Compared with the Android file:
  - It ends with a **deny-everything rule** (`:155-157`), which would block `referrers`, `apps`, `access_tokens`, `details_of_payment`, `install_referrals`, `invalid_referrals` and `correct_answers_in_row_english_only` used by Android and other apps in the same project.
  - It has no legacy write path.
  - Its curated-nickname regex (`:31-36`) would **reject Android's 1–5 character names**.
  - Owner records are unreadable.
  - Listing requires sign-in and at most 20 results.
  - Streaks may not go down on update.
  - Delete requires the document to exist, which would deny iOS's own two-document delete batch if either document is missing. Untested.
  - `firebase.json` in the iOS repo points at this file.
- `firebase-leaderboard-migration.md` describes an archive-and-clear cutover that **was not what Android deployed**. That doc is CONTRADICTED.

### 6.3 iOS leaderboard writes against the Android rules file (static analysis)

| # | Operation | Rule | iOS behaviour | Result |
|---|---|---|---|---|
| 1 | Claim ownership (create) | `:86-89`: signed in, `isV2PlayerId`, `keys().hasOnly(['owner_uid'])`, `owner_uid == auth.uid` | Lowercase `v2_` + UUIDv4; `setData(["owner_uid": uid], merge: false)` | **ACCEPTED** |
| 2 | Re-assert ownership (update) | `:90-94`: existing `owner_uid == auth.uid` | Same UID | **ACCEPTED** |
| 2b | Re-assert when the anonymous UID has changed | same | e.g. the sign-in identity is lost while saved settings survive | **DENIED permanently.** iOS has no recovery; every later write or delete fails. |
| 3 | Write score to `score_records` / `score_records_english_only` | `:98-126` with `isValidV2Score` (`:63-70`) and `hasValidV2Common` (`:47-61`): allowed keys; `user_name` 1–32 characters with no leading or trailing space; `avatar_id` in the allowed list; streak an integer ≤ 1e6; `date_achived == request.time`; 0 < score ≤ 1e9; updates keep `player_id` and never lower the score | Nickname 10–19 characters; server timestamp; best-only; `merge` writes | **ACCEPTED** in the normal flow. **DENIED** if an outdated snapshot is missing the player's own higher record. |
| 4 | Write streak to `correct_answers_in_row` | `:129-142`, `isValidV2Streak` | value > 0 guaranteed | **ACCEPTED** |
| 5 | Delete | `ownsV2PlayerId && (resource == null \|\| …)` | Deletes 2 documents (the product's score board and the shared streak board) | **ACCEPTED** (missing documents are allowed) |
| 6 | Read Top 20 | `allow read: if true`; composite indexes in `firestore.indexes.json` | `app_id == "3"`, ordered, limit 20 | **ACCEPTED.** Whether the indexes are deployed is UNKNOWN; Android runs the identical query. |

- **Android emulator tests.** The Android repository's tests model iOS writes: the "curated alias" case (`firebase/tests/leaderboard.rules.test.mjs:127-131`) and the "iOS contract" case (`:191-202`). Their emulator log is dated 2026-09-28; the pass/fail result is not recorded.
- **Verdict.** iOS implements the **current v2 wire contract**, not an older one, and its writes fit the rules file. It is **not identical** to Android v2:
  - one ID per product (Android: one per child slot);
  - a plain ownership write instead of a transaction; no stored owner UID;
  - `merge` writes;
  - curated 10–19-character nicknames plus `avatar_id` (Android: 1–5 characters);
  - iOS signs in even to read;
  - iOS asks for a nickname before checking whether the score qualifies;
  - iOS deletes 2 boards, Android 3;
  - iOS may create an ownership record just in order to delete;
  - no retry queue.
- **Risks for installs that already exist.** iOS has not shipped. A v1 key with an uppercase, unversioned UUID existed only from 2026-09-12 to 09-14 (`5bf5cf9`). It is now ignored and not migrated. No evidence shows any build with it was ever distributed.
- **Remaining compatibility risks:**
  - permanent loss of write access if the anonymous UID changes;
  - public records left behind after a reinstall, which can no longer be deleted from the app;
  - Android names shown as "Player" on iOS;
  - Android must lay out iOS nicknames of up to 19 characters.
- **Android ↔ iOS runtime evidence for the leaderboard: none.**

### 6.4 Modern Pong database rules
- The rules are **not deployed from this repository**: the root `firebase.json` covers Firestore only, and `Tests/ModernPongFirebase/rules/merged.json` is a snapshot.
- The snapshot is **stale** against Android's 09-29 rules (6 expressions; §4.4).
- Which rules version is live: **UNKNOWN**.
- Every launch of MinikPingPong, including CI smoke tests, writes to the production `minikswish` database.

---

## 7. StoreKit, ads and child safety

### 7.1 StoreKit (shared AppStoreCommerceKit)
- **Product.** `remove_ads` is read from the Info key (`MinikCommerce.swift:24-31`). It is one non-consumable entitlement.
- **StoreKit 2** (`Packages/AppStoreCommerceKit/.../StoreKitCommerceStore.swift`):
  - loads with `Product.products`;
  - buys with `purchase()` and checks the verification result (an unverified result throws);
  - reads `Transaction.currentEntitlements`;
  - restores with `AppStore.sync()`;
  - listens to `Transaction.updates`;
  - calls `finish()` only after the purchase has been delivered.
- **Refunds and revocations.** Every update re-reads `currentEntitlements` (which excludes revoked purchases) and saves `false`. After a mid-session refund, ads would not restart until the next launch.
- **Saving and offline.** The result is cached as a per-product bool; a failed refresh keeps the cached value. One unverified transaction makes the whole refresh fail (`:55`).
- **Test configuration.**
  - The only `.storekit` file is the package fixture (`org.example.appstorecommerce.fixture.*`).
  - **There is no `.storekit` file for `remove_ads`, and no app scheme references one.**
  - App tests use `InMemoryCommerceStore` only.
  - The package's native tests are recorded as "NOT RUN" (`NATIVE-VALIDATION.md:58-59`).

### 7.2 Ads
- **Language and Math ad layer** (`MinikAds.swift`). Ads are off unless all four settings are present: `MinikAdsEnabled`, `MinikAdsPolicyApproved`, an app ID and an ad-unit ID (`:56-62`). Google sample IDs count as missing (`:73-87`). **As configured, ads cannot run in Debug or Release.**
- **Adapter** (`GoogleMobileAdsInterstitialService.swift`). Requests ads as `ageRestrictedTreatment = .child`, rating G, personalization off (`:47-50`). Whether that property name exists in GoogleMobileAds 13.9 is **unverified** (it has never been compiled).
- **Frequency** (`AndroidCompatibleInterstitialPolicy`, `:176-244`):
  - the first eligible completion only starts the timer;
  - a 60 s warm-up;
  - at least 7 minutes between ads, stepping down to 3 minutes after the app goes to the background;
  - completion weights apply.
- **Where ads can appear.** At activity-completion boundaries on **Language screens only**: `MinikActivityHubView.swift:771,802,817,836,860,876,893,279,909`. **Math has none** (`recordPingPongCompletedMatch` has no callers).
- **Modern Pong (`MPAds`)**:
  - its own schedule: the first two matches ad-free, then every 2 matches or 210 s, at least 120 s apart;
  - **test ads only** (Debug flag *and* the sample app ID);
  - a hard-coded Google test ad unit (`MPAds.swift:43,75`).
- **No consent or tracking framework:** no UMP consent form, no App Tracking Transparency, no AdSupport, no `SKAdNetworkItems`.
- **Possible launch crash.** Plus, English and Math link the ads SDK with `-ObjC` and an **empty** `GADApplicationIdentifier`. Google's SDK has historically raised an error at launch when the app ID is missing. **Unverified; must be checked on the first Simulator launch.**

### 7.3 Status per product

| Product | Ads | Remove Ads / StoreKit | Access codes | Overall |
|---|---|---|---|---|
| MINIK PLUS | Adapter and Language placements; off by default; no IDs | Purchase and restore behind the parent gate; `remove_ads`; **sold although no ads show** | **Not implemented** (Android `access_tokens` app_id "3" not ported) | **BOTH.** Code exists (never compiled). Needs AdMob IDs, flags, a policy / Kids decision, and the App Store Connect product. |
| MINIK PLUS ENGLISH ONLY | same as Plus | same as Plus | **Not implemented** | **BOTH** |
| MINIK Math | SDK linked, **no placements** | Behind the parent gate, **but there is nothing to remove** | **Not implemented** (Android Math app_id "4") | **NOT IMPLEMENTED** (ads, codes). StoreKit code ready; needs an owner decision. |
| Modern Ping Pong | **Debug test ads only; no production path**; sample app ID in Release | Purchase, restore and **Apple offer codes with no parent gate** | Apple offer-code sheet only; no Firebase codes (Android Pong app_id "6") | **BOTH + NOT IMPLEMENTED** (production ads, gate, App Check) |
| Retro / 80's | none (SDK not linked) | none at runtime | **Not implemented** (Android Bounce & Learn app_id "5") | **NOT IMPLEMENTED, by design** |

- An untracked note, `website/minik-apps/PRIVACY-SOURCE-NOTES.md`, says Android Math and Modern Pong use a "signed entitlement/code verification service" and that only Bounce & Learn uses Firestore access codes. This differs from the `access_tokens` app_id mapping. **Owner confirmation needed**; this audit does not settle which Android code path is current.

### 7.4 Privacy, child safety and App Store

**Privacy manifests**
- `Language`: no tracking; collects User ID and gameplay content, linked to the user, for app functionality; UserDefaults reason CA92.1.
- `LocalOnly`: collects nothing; CA92.1.
- `ModernPong`: collects User ID and gameplay content, linked, no tracking; CA92.1.
- No other required-reason APIs were found.

**Mismatches**
- **Math** declares LocalOnly but links GoogleMobileAds, whose own manifest will appear in the archive's privacy report.
- **Plus, English and Pong** app manifests say nothing about ads. This is acceptable while ads are off, but the App Privacy answers must account for the SDK's manifest.
- **Pong's** manifest does not reflect that data is sent at launch without an opt-in.
- **Language:** opening Top 20 signs in anonymously **even when sharing is off** (acknowledged in `public-leaderboard-privacy.md:19`).

**Parent gate**
- Language and Math: a gate on purchase, restore and external links only. **Entering the Parent Area is not gated**, so a child can switch sharing on or off, delete public records and turn on reminders. **Leaderboard sharing is on by default** (`PublicLeaderboardPrivacy.swift:170,181,196-199`).
- Modern Pong: **no gate at all.**
- Retro: no purchases and no links.

**External links**
- Only in the Parent Area, behind the gate, pointing to the `project.yml:41-43` URLs.
- **Modern Pong and Retro have no in-app privacy policy link** (guideline 5.1.1).
- `docs/privacy-policy-website-replacement.md` is a draft, unpublished. The untracked `website/` folder is Android-only. All iOS apps point to `https://miniklearn.com/privacy`.

**Account and data deletion**
- Language: public score and streak records can be deleted, but only while sharing is off (`ParentAreaView.swift:511-518`). The `leaderboard_owners` record cannot be deleted by the app, and the anonymous user is never deleted.
- Pong: profiles and nicknames cannot be deleted from the app.

**Where purchases appear**
- Parent Area (gated) in Plus, English and Math.
- Directly in the child menu in Modern Pong (ungated).

**Permissions.** None requested, none needed: speech synthesis only, local notifications, copying to the pasteboard.

**Analytics and crash reporting.** None.

**Age rating and Kids Category.** Not decided (owner). The ads SDK linked in every Kids-candidate app is a review risk even while ads are off.

---

## 8. CI, GitHub, signing and App Store Connect

### 8.1 Workflows

**Every workflow runs only when started by hand (`workflow_dispatch`).** None uses secrets. There is no archive, signing, export or upload step anywhere.

| File (last commit) | Runner | What it does | Targets | Notes |
|---|---|---|---|---|
| `ios-ci.yml` (`5b64a3a`, 09-02) | `macos-26` | XcodeGen (unpinned, via brew); Debug Simulator build with signing off; `xcodebuild test -scheme MinikPlus` | Plus, English, Math | **Not Pong or Retro.** One shared DerivedData (the `canImport` risk). Uses `actions/checkout@v7`. |
| `ios-simulator.yml` (`767af60`, 09-13) | `macos-latest`, 60 min | Builds 4 schemes, each with its own DerivedData; runs ProductConfigurationTests if all four compile; boots an iPhone and for each app installs, launches, checks it survives 5 s, takes a screenshot and collects crashes | Plus, English, Math, Pong | **No Retro.** Never run since it was added (`MINIK_MASTER_PLAN.md:3109`). **Launching Pong writes to production Firebase.** |
| `retro-pong-simulator.yml` (`eeb326e`, **unpushed**) | `macos-latest`, Node 22 | Python audit and Node tests; builds Retro and Math into a shared DerivedData; full `xcodebuild test -scheme MinikPlus`; launches Retro in English and Hebrew and takes screenshots | Retro, Math | Cannot be started until it is on the default branch. Picks the Simulator somewhat unpredictably (`:34`). |
| `ipad-unsigned-ipa.yml` (`59502f2`, 08-24) | `macos-26` | Math Debug build for a real device, unsigned, zipped as `MinikMath-unsigned.ipa` | Math | **Cannot be distributed.** No run evidence. |
| `app-store-commerce-tests.yml` (`fa9b085`, 09-10) | `macos-15` | Package unit tests plus the hosted StoreKit test plan | package only | No documented pass |
| `image-format-benchmark.yml` (`ad11b2b`, 08-25) | `macos-26` | Image-format benchmark script | – | Has uncommitted edits in the `ios` worktree |
| `codemagic.yaml` (`108c90e`, 09-02) | `mac_mini_m2`, Xcode "latest" | Debug Simulator builds of 4 schemes plus ProductConfigurationTests | Plus, English, Math, Pong | Manual only; deprecated; no publishing or signing |

- **Searches with no matches** in `.github`, `codemagic.yaml` and `project.yml`: `secrets.`, `APP_STORE`, `ASC_`, `ISSUER`, `KEY_ID`, `TEAM_ID`, `DEVELOPMENT_TEAM`, `PROVISION`, `CERTIFICATE`, `P12`, `KEYCHAIN`, `exportArchive`, `archive`, `altool`, `notarytool`, `fastlane`, `testflight`.
- **Files that do not exist:** no Fastfile, ExportOptions.plist, `.xcconfig`, `.p12`, `.p8` or `.mobileprovision`.
- **Run history.** The GitHub Actions history could not be inspected. An uncommitted note says GitHub-hosted macOS is blocked by the account's billing or spending limit (date and state UNKNOWN).

### 8.2 The 11 stages, per target

**Legend**
- **READY:** ready in the repo.
- **SECRET:** needs a GitHub secret.
- **APPLE-DEV:** needs Apple Developer setup.
- **ASC:** needs an App Store Connect record.
- **FIREBASE:** needs Firebase configuration.
- **UNPROVEN/BROKEN:** no evidence, or known broken.

| # | Stage | MinikPlus | MinikPlusEnglish | MinikMath | MinikPingPong | MinikRetroPingPong |
|---|---|---|---|---|---|---|
| 1 | Checkout | **BROKEN for HEAD**: `eeb326e` is unpushed. Only `946447c` can be checked out. | same | same (icon, Modern Simple, Retro unpushed) | same (Modern port unpushed) | **BROKEN**: the target exists only in unpushed `eeb326e` |
| 2 | Generate the Xcode project | READY in repo (XcodeGen 2.38+, installed unpinned). **UNPROVEN** for the current `project.yml`. | same | same | same | UNPROVEN (new target with a folder resource) |
| 3 | Select a compatible Xcode | **UNPROVEN.** No `xcode-select` or setup action; runner default only. History: Xcode 26.6. | same | same | same | same |
| 4 | Resolve Swift packages | **UNPROVEN.** Firebase (from 12.14.0), GoogleMobileAds (from 13.9.0) and AppStoreCommerceKit have never been resolved in an app build. Versions float, because no `Package.resolved` is committed. | same | UNPROVEN (ads SDK, commerce) | UNPROVEN (Firebase Core/Auth/Database, ads SDK, commerce) | UNPROVEN (commerce) |
| 5 | Build each target | READY in repo (config file committed; pre-build check). **UNPROVEN at HEAD.** **The Release configuration has never been compiled for any target.** | same | same | UNPROVEN (the 09-05 build was of the old engine) | **Never built** |
| 6 | Run tests | **BROKEN/UNPROVEN.** Last run: 796/797 at `180155b`. The fix was never re-run. About 194 of the 991 test methods have never run. | no test action | no test action | no test action (Modern tests run inside the MinikPlus host; the Firebase code is not compiled there) | no test action (tests run in the MinikPlus host; Node tests only in the unpushed workflow) |
| 7 | Build and run on a Simulator | READY in repo (`ios-simulator.yml`), **never run** | READY, never run | READY, never run; also in the Retro workflow | READY, never run. **Side effect: writes to the production database.** | Retro workflow only; cannot start until pushed |
| 8 | Archive Release | Not present. **APPLE-DEV + SECRET** | same | same | same | same |
| 9 | Sign | **APPLE-DEV**: Team ID, App ID **with App Attest**, distribution certificate, App Store profile. **SECRET** for CI. | same, with App Attest | App ID, certificate, profile | App ID, certificate, profile | **new** App ID `…pingpong.retro`, profile |
| 10 | Export IPA | **APPLE-DEV + SECRET.** No ExportOptions.plist. | same | same | same | same |
| 11 | Upload to App Store Connect / TestFlight | **ASC** record plus the `remove_ads` product; **SECRET** App Store Connect API key; no upload tooling | same | same | same, plus offer codes | ASC record (no in-app purchase) |
| – | Firebase runtime | **FIREBASE** (`easycallandanswer`): anonymous sign-in, App Attest registration, indexes (enforcement off) | same | n/a | **FIREBASE** (`minikswish`): confirm live database rules and API-key restrictions | n/a |

### 8.3 External credentials and setup (by purpose; the secret names are suggestions)
- **Apple Team ID** → `APPLE_TEAM_ID`, injected as `DEVELOPMENT_TEAM` (missing from `project.yml`).
- **Apple Distribution certificate** → `IOS_DIST_CERT_P12_BASE64` and `IOS_DIST_CERT_PASSWORD`, plus a temporary keychain password `KEYCHAIN_PASSWORD`.
- **App Store provisioning profiles**, one per bundle ID: `com.appsbybros.minik.plus`, `.plus.english`, `.math`, `.pingpong`, `.pingpong.retro`. Alternatively, automatic signing with `-allowProvisioningUpdates` and an App Store Connect API key.
- **App Store Connect API key** → `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY` (the `.p8` file).
- **Bundle ID registration**: 5 explicit App IDs. App Attest must be enabled on Plus and English.
- **App Store Connect app records**: 5. Plus up to 4 `remove_ads` in-app purchases (◇ per product), Pong offer codes, and agreements, tax and banking.
- **Firebase Apple registration**:
  - `easycallandanswer`: the Plus and English iOS apps.
  - `minikswish`: the Pong iOS app.
  - App Attest provider for Plus and English.
  - A deploy credential (e.g. `FIREBASE_TOKEN`) only if rules deployment is ever moved into CI. It is not needed to build.
- **AdMob**: production app and interstitial IDs per product that will show ads. These are configuration values, not secrets. None exist.
- **Codemagic**: nothing configured (deprecated).

### 8.4 Other CI risks
- XcodeGen and Xcode versions are not pinned. `apple-release-checklist.md:74` refers to a "pinned XcodeGen contract" that does not exist.
- Package versions float, because no `Package.resolved` is committed.
- AppStoreCommerceKit is linked into both the host app and the test bundle. This may cause duplicate-type problems (unproven).
- `windows-ios-simulator-testing.md:16-32` documents workflow inputs that were removed.

### 8.5 Tests: what each suite proves

| Suite | Size | What it proves (if run) | Has it run? |
|---|---|---|---|
| `ProductConfigurationTests` (XCTest, hosted by MinikPlus, `@testable import MinikPlus`) | 95 files, **991 methods** | Covered below | Last run at `180155b` (797 methods, 796 passed). About 194 methods have never run, including all Modern and Retro tests. |
| – Language providers and sessions; Math M1–M10 providers and factories (e.g. `MathContentProviderTests`, 105) | majority | Content ranges, uniqueness, distractors, session construction per activity type | partly, before 09-05 |
| – Parity tests with Android numbers (`LanguageAutoLevelProgressionTests` 37, `LanguageSoccerShotPhysicsTests` 21, `LanguageProductionParityTests` 11, `TicTacToeSessionTests` 24) | – | Android numbers reproduced in the pure logic | not at HEAD |
| – Saved-state tests (ActivityProgress, MathLevelProgression, ParentArea, RewardFoundation, RetroPongHost) | – | Save and restore round trips in UserDefaults | not at HEAD |
| – Localization (`InterfaceLocaleTests` 4, `LanguageInterfaceLocalizationTests` 5) | 9 | Language policy per product; **only 2 keys per language** are checked for a real translation; he and ar are right-to-left | not at HEAD |
| – Protocol (`RemoteRecordsTests` 21) | 21 | Firestore schema mapping, top-20 rules, nickname privacy, ownership and pending retry, **using fakes** | not at HEAD |
| – Ads and commerce (`MinikAdsTests` 13, `MinikCommerceIntegrationTests` 8) | 21 | Ads stay off when unconfigured and sample IDs are rejected; commerce state **with `InMemoryCommerceStore` only** | not at HEAD |
| – `ModernPongParityTests` | 25 | Engine invariants, AI ordering, tutorial, pure `MPRules` (Ready, authority, tournament, host transfer), local repository, ad frequency. **Does not touch Firebase, `MPMatchLink`, the scene or ads.** | **never** |
| – `RetroPongHostTests` | 7 | Storage and startup-script safety; navigation containment. No web view. | **never** |
| – Legacy `PingPong*Tests` | 31 | **Code that no target can reach** | before 09-05 |
| `Tests/RetroPong/engine.test.cjs`, `host.test.cjs` (Node) | 16 + 7 | The real `app.js` in a Node sandbox with a fake DOM; the JavaScript bridge with a fake `webkit` | Recorded as passing (Windows) |
| `Tests/ModernPongFirebase/tests/rules.test.cjs` (emulator) | 43 | Database rules: profiles, rooms, tournaments of 2–8, presence, nicknames, server-only monetization | 43/43 on 09-28, **against the stale snapshot**; no workflow; no lockfile |
| `Tests/FirebaseRules/firestore.rules.test.mjs` (emulator) | 35 | The **iOS repository's** rules (not production): ownership, scores only going up, allowed fields, index JSON | Emulator ran around 09-14; **no result log** |
| AppStoreCommerceKit package tests | 25 | Deliver before acknowledging; replays; purchase policy; in-memory store | No documented pass |
| Hosted StoreKit tests (`SKTestSession`) | 4 | Real StoreKit purchase, restore, refund and grace period, with **fixture IDs, not `remove_ads`** | "NOT RUN" |
| 42 `Scripts/audit-*.ps1` / `.py` | – | Static text-pattern guards | Not in CI (except the Retro audit). **`audit-modern-pong.py` now FAILS.** **`audit-release-closure.ps1:130`** and **`audit-remote-records.ps1:97-102`** should fail by inspection. `audit-firebase-leaderboard.ps1` checks against old Android snapshots. `audit-minik-ads.ps1` never scans `Sources/ModernPong`. |

- **No UI-test (XCUITest) target exists.**
- **Only the MinikPlus host is tested.** Code behind `MINIK_MATH`, `MINIK_PING_PONG` or `MINIK_RETRO_PING_PONG`, and each target's resources, are never exercised.

**Release-critical behaviour with no test**
- Real StoreKit with `remove_ads` in any app.
- The parent-gate UI.
- Ads SDK start and presentation (and the empty-app-ID launch).
- The Firebase clients: bootstrap, App Attest, the Firestore data source, anonymous sign-in, `MPFirebaseRepository`, `MPMatchLink`.
- iOS ↔ Android play in the same room.
- The Retro web view.
- Full localization; right-to-left at runtime; each target's launch and routing.
- iPad layouts, Dynamic Type, VoiceOver.
- The notifications adapter; packaging (privacy manifests, Info.plist, entitlements); Release-configuration behaviour.

---

## 9. Dead, stale and duplicate code

### 9.1 Code findings

| Location | Finding | Reachable in a release target? |
|---|---|---|
| `project.yml:283` | **Google's sample ads app ID** in MinikPingPong's base settings, so it ships in the Release `GADApplicationIdentifier` | **Yes**, MinikPingPong |
| `ModernPong/MPAds.swift:43,75` | Hard-coded Google test ad unit; runs only with a Debug flag and the sample ID | Code is compiled in Release but inactive there |
| `ModernPong/ModernPongView.swift:116,403-414,66` | Purchase, restore and offer codes with **no parent gate** | **Yes**, MinikPingPong Full |
| `project.yml:36-40` | `remove_ads` sold in 4 apps while ads are off everywhere | **Yes**: Plus, English, Math, Pong |
| `project.yml:39,57` | **Empty** `GADApplicationIdentifier` and ad unit while the ads SDK is linked | **Yes**: Plus, English, Math (launch safety unverified) |
| `ModernPongView.swift:55`; `MPRepository.swift:118-155` | Anonymous sign-in and profile write to the **production** database at first launch; no App Check | **Yes**, MinikPingPong |
| `PingPongView.swift` (446), `PingPongScene.swift` (715), `PingPongRallyModel.swift` (623), `PingPongRetroRally.swift` (583), `PingPongRetroStyle.swift` (332), `PingPongMatchSession` / `TableLayout` / `Preferences`, most of `PingPongModels` | **Old Pong engine plus the first native "80s" attempt.** About 3,000–3,300 lines with no callers; 31 tests still cover them | Compiled in all 5; reachable in **none** |
| `Resources/PingPongAssets.xcassets` | About 15 MB; only `minik_pong` is used | Shipped in Math |
| `PingPongHostServices.swift:3-37`; `MinikAds.swift:362-388`; `RootView.swift:12,45`; `MinikActivityHubView.swift:1217-1227` | Unused host services and `recordPingPongCompletedMatch` (no callers); a stale comment at `MinikAds.swift:141` | Dead |
| `LanguageLearnDevelopmentView.swift`, `MathLearnDevelopmentView.swift` | "Temporary entry point" screens, never referenced | Dead |
| `MinikActivityHubView.swift:677-753,904-911` | Generic multiple-choice, build, pairs and memory destinations, and a defensive Tic-Tac-Toe case | Compiled; not reachable from the UI |
| `RetroPongAppIcon` = `ModernPongAppIcon` | Byte-identical icons | Retro, Pong |
| ModernPongAudio vs `RetroPong/assets/audio` | 6 duplicate MP3s plus an 844 KB base64 audio bank | Math ships both |
| `FirebaseRecordsIntegration.swift:3,52,82,113` | Bare `canImport` with no product condition (link-error risk with a shared DerivedData) | Build-time risk |
| `LanguageWordCatalog.swift:104-110` | `preconditionFailure` if the vocabulary fails to load, i.e. **a launch crash** | Plus, English |
| Other `preconditionFailure` / `precondition` (invariants current data cannot trigger) | `LanguageSoccerPracticeSession.swift:52,63`; `LanguageTowerPracticeSession.swift:48,55,62`; `LanguageMixedPractice.swift:34,41`; `LanguageMixedPracticeView.swift:80`; `ContentContracts.swift:287`; `SoccerSession.swift:28`; `TowerSession.swift:89,100`; `ActivityProgress.swift:247`; `LanguageWordCatalog.swift:49`; `MathCurriculum.swift:120,127`; `MathM6ContentProvider.swift:86,461`; `MPPhysics.swift:118` (satisfied); `CommerceTypes.swift:7,18` (guarded) | Compiled; not triggered by current data |
| `FirebaseRecordsIntegration.swift:121` | `preconditionFailure` if the debug App Check provider is used in Release | Cannot be reached |
| `MinikActivityHubView.swift:416` → `RecordsLeaderboardView.swift:93` | Math trophy always shows "not configured" | **Yes**, MinikMath |
| `project.yml:270` | Pong config file skips the BUNDLE_ID check; a mismatch silently falls back to local mode | MinikPingPong |
| `InMemoryCommerceStore.swift:5` | A public test double linked into every app | Compiled; unused in production code |
| `Resources/GameAudio/README.md` | Copied into the app bundle | Plus, English |
| `docs/…` (see §6.1) | Pong `GOOGLE_APP_ID` printed in full | Docs only |
| v23 WebView package (outside the repo) | **Duplicate bundle IDs** `…minik.math` and `…minik.pingpong` | Would conflict if uploaded |
| Legacy leaderboard ID | The v1 uppercase UUID key (09-12..14) is ignored and not migrated; the v2 key is used | Not reachable |

**Search results with nothing found:**
- No TODO, FIXME, XXX or HACK in app code or the Retro payload.
- No `fatalError` or `mock` in the Modern or Retro sources.
- No localhost or emulator endpoints; no `print` or `NSLog`; no committed debug token.
- The only `#if DEBUG` blocks are at `FirebaseRecordsIntegration.swift:21,118`.
- The only "placeholder" is a UI token in `BuildView.swift:292,463`.
- Fakes exist only in tests (apart from `InMemoryCommerceStore`).

### 9.2 Repository hygiene
- **The 4 unpushed commits have exactly one copy** (§0.1).
- About 60 MB of untracked, non-ignored files (`website/`, `website.zip`, a reference zip, a 0-byte "rollout … File too big" file, `%USERPROFILE%/`) would be swept in by `git add -A`.
- `tmp_phase39_probe.js` is tracked.
- The `main-ci-fix` worktree link is broken and its branch `ci-manual-only` is prunable.
- The `ios` worktree has 9 uncommitted modified or deleted files.
- `C:\Projects\Minik-to-IOS\AGENTS.md` is STALE. It knows only `ios/` and allows commits only on `codex-sprint-8h-20260830`, yet `b15717f` and `eeb326e` were committed on `main`.

### 9.3 Documentation classification (consolidated)

**CURRENT AND VERIFIED BY SOURCE**
- `README.md`
- `Packages/AppStoreCommerceKit/README.md` and `NATIVE-VALIDATION.md` ("NOT RUN")
- `Tests/FirebaseRules/README.md`
- `docs/reference/android-ui/README.md`
- vocabulary docs (543/543)
- `release-configuration.md:12-18,74-90,120-135,146-154,185-201` (IDs, config files, App Check split, one entitlement, ads defaults, notifications)
- `public-leaderboard-privacy.md:9-37,77-80`
- `privacy-policy-website-replacement.md:9-21,29-35` (content, but unpublished)
- `app-store-privacy-data-inventory.md:9-12,18-25,27,41` (Plus, English, Pong rows)
- `apple-release-checklist.md` table rows for all 5 targets and :11, :17, :21, :60, :89, :91
- `english-only-production-policy.md:34-41`
- `MINIK_MASTER_PLAN.md:1908,1912,1954,2001,3071` and §28 (09-28 routing)
- Retro handoff (§5.6); Modern handoff structural claims (§4.8)
- `math-educational-core-audit.md` (M1–M10); `product-architecture.md:92`

**CURRENT BUT NOT RUNTIME-VERIFIED**
- `apple-release-checklist.md` (overall; :61 "anonymous sign-in and database rules already enabled")
- `modern-pong-ios-handoff.md` and `retro-pong-ios-handoff.md` (behaviour claims)
- `tic-tac-toe-parity.md`, `math-production-matrix.md`
- the Build-word, Soccer, Tower, Mixed and automatic-level docs (09-07)
- `english-only-parity-lock.md:25` (right-to-left boundary)
- `release-configuration.md:106-113` (commerce "covered by native tests")
- `firebase-leaderboard-contract.md:30,32,44-46`

**STALE**
- `release-configuration.md:27,141-144,207,224` ("four targets")
- `app-store-privacy-data-inventory.md` (omits Retro)
- `first-iphone-simulator-qa.md` and `second-iphone-simulator-readiness.md` (old Pong; four products)
- `post-c9-independent-review-corrections.md:43`
- `activity-event-integration-plan.md`
- `english-only-parity-lock.md:5` (469 keys vs 596)
- `product-architecture.md:74`
- `math-object-art-requirements.md` ("used by M1–M7")
- `MINIK_MASTER_PLAN.md:1914,1916,1938,2029,2036,3061,3063` and §23
- Modern handoff "152 checks PASS" and its rules snapshot
- Retro handoff "current Android 80's" (:15-17, :32, :48)
- `AGENTS.md`
- the Language release audits of 09-03..09-06 (visual claims)
- `m3-build-xctest-root-cause.md`, `mac-gate-practice-visual-analysis.md`, `cards-accessibility-mac-analysis.md`: accurate *historical* records, not current state

**CONTRADICTED BY CURRENT SOURCE**
- `current-migration-status.md`
- `product-architecture.md:124,126`
- `math-levels-4-10-inventory.md`
- `localization-qa-status.md` (counts; its "Math strings fall back to English" is still true)
- `app-icon-provenance.md`
- `windows-ios-simulator-testing.md` (inputs; the Appetize handoff)
- `release-configuration.md:114-117,136-139`
- `app-store-privacy-data-inventory.md:11`
- `apple-release-checklist.md:15` (Retro ID is a literal), `:36` (gate implied for every product), `:59` ("never sample IDs in Release")
- `MINIK_MASTER_PLAN.md:101,339,1129,1134-1137,1186-1196,2002,2059-2060,2064,3055` and §7.13
- `firebase-leaderboard-contract.md:3,7,26,40,46`
- `firebase-leaderboard-migration.md:7-12,21-46`
- `public-leaderboard-privacy.md:72,84`
- `language-second-simulator-correction-ledger.md` SH06 (partly)
- `english-only-production-policy.md:40` (partly)
- `math-visual-consistency.tsv:14`
- Modern handoff (stats, grace period, parity)

**UNKNOWN**
- Android `google-services.json` facts (`release-configuration.md:38-42`)
- deployed Firestore and database rules; App Check enforcement; console registrations
- live website content
- `MINIK_MASTER_PLAN.md` §25 "Math 80–85%" (an estimate)
- "Swift files parse" claims (no log)
- `activity-contract.md` and the sprite prompt (historical)
- `Downloads\Minik-WebApps-Native-v23\README_FIRST.txt` (source only; IDs undecided)

---

## 10. Remaining work: one checklist, ordered by dependency

Order follows **dependencies only**, not product preference.

**Tags**
- **[OWNER]:** a decision or action only the owner can take.
- **[EXT]:** external (Apple, Google, Firebase, App Store Connect).
- **[CODE]:** a source change, for a later task.
- **[MAC]:** needs macOS and Xcode.
- ◇ items depend on an earlier [OWNER] decision.

Products: P = Plus, E = English Only, M = Math, MP = Modern Pong, R = Retro.

### Phase A: protect and publish the source
- [ ] A1 [OWNER] Back up the 4 local-only commits (`23ce35b`, `ac3e71d`, `b15717f`, `eeb326e`), e.g. with a `git bundle`, and push `main` when ready. *Everything in CI depends on this.*
- [ ] A2 [OWNER] Decide what to do with the untracked `website/`, `website.zip`, the reference zip, the 0-byte "rollout" file and `%USERPROFILE%/` before any `git add -A`. Optionally extend `.gitignore`. Prune the broken `main-ci-fix` worktree and remove `tmp_phase39_probe.js`, if wanted.
- [ ] A3 [OWNER] Confirm GitHub-hosted macOS minutes are available (billing or spending limit), or provide a Mac.

### Phase B: owner decisions that change what code is needed (none are made here)
- [ ] B1 [OWNER] (P, E, M, MP) Remove Ads while no ads show: enable ads, or hide or remove the purchase, per product.
- [ ] B2 [OWNER] (all) Kids Category and age rating per product. This decides the parent-gate requirements, whether the ads SDK is acceptable, and whether a consent or UMP flow is needed.
- [ ] B3 [OWNER] (E) Is strict English + left-to-right required (no Arabic interface, no device-language leakage), or is Android parity enough?
- [ ] B4 [OWNER] (P, E, M) Are child profiles required on iOS?
- [ ] B5 [OWNER] (P, E) Public-name model: keep curated nicknames of 10–19 characters. Not assumed to become Android's 1–5-character design. Also decide how Android names should display on iOS (currently "Player").
- [ ] B6 [OWNER] (M) Math trophy (records vs hidden), Math rewards policy, Math ads.
- [ ] B7 [OWNER] (M, MP) Who owns `com.appsbybros.minik.math` and `com.appsbybros.minik.pingpong`: native, or the v23 WebView package?
- [ ] B8 [OWNER] (R) Retro baseline and identity: stay on the obsolete `minik80sPingPong` payload or move to current Bounce & Learn; app name; icon; Math flavour inside Math; monetization scope.
- [ ] B9 [OWNER] (MP) Scope of parity with Android's 09-29 engine and rules; production ads; an opt-in before the online profile; App Check for the database.
- [ ] B10 [OWNER] (all) Access-code redemption on iOS (Android app_ids 3/4/5/6), and confirm which Android code path is current (`access_tokens` or the "signed entitlement" service).
- [ ] B11 [OWNER] (all) Terms URL domain (`easycallandanswer.com` vs `miniklearn.com`) and privacy-policy content.

### Phase C: first Apple compile of HEAD (needs A1 and A3)
- [ ] C1 [MAC] Run `ios-simulator.yml` (P, E, M, MP) and `retro-pong-simulator.yml` (R, M), or build locally, each scheme in its **own** DerivedData. Record the logs and `.xcresult` files in the repo.
  - Be aware: launching MP writes to the production `minikswish` database.
- [ ] C2 [CODE] Fix whatever compile errors appear in *any* `Sources/` file (every target compiles all of them).
- [ ] C3 [MAC] First-launch check of P, E and M with the ads SDK linked and an **empty** `GADApplicationIdentifier`: crash or not.
- [ ] C4 [MAC] Check the pre-build Firebase config-copy script under Xcode's script sandboxing (P, E).
- [ ] C5 [MAC] Run `ProductConfigurationTests`; confirm the `084ca2a` fix; run the about 194 never-run tests (including Modern and Retro).
- [ ] C6 [MAC] Build the **Release** configuration of every target at least once (never done).
- [ ] C7 [MAC] (R, M) Prove the Retro page loads under `file://` with the content-security policy.

### Phase D: code fixes known today (after C; ◇ items after the matching B decision)
- [ ] D1 [CODE] (MP) A parent gate before purchase, restore and offer codes; remove Google's sample ads app ID from Release (◇ B1 / B9 decides the replacement).
- [ ] D2 [CODE] (MP) Accept difficulty 4 correctly in `validFinal` and support Beginner; update the roster (Flare, Kyra) and its test; refresh the rules snapshot and rules tests from Android's 09-29 rules; ◇ port the other 09-29 changes.
- [ ] D3 [CODE] (MP) Make Hebrew reachable; make the skip-guide toggle work; add an in-app privacy link; ◇ opt-in and deletion for the online profile; tests for `MPFirebaseRepository` and `MPMatchLink`.
- [ ] D4 [CODE] (P, E) Leaderboard: prompt only when useful and never after a parent opts out; stop the repeated "Saved on this device" modal; fix the tie highlight; handle a changed anonymous UID; fix the possible offline "Updating…" hang; ◇ read Top 20 without signing in.
- [ ] D5 [CODE] (P, E, M) Resolve device-language `String(localized:)` lookups against the interface language; add the missing catalog keys; ◇ B3 for English Only (Arabic choice, `CFBundleLocalizations`, left-to-right lock).
- [ ] D6 [CODE] (P, E) Audio-session policy; limits on `processedEventIDs` and `appliedEvidenceIDs`; correct the "child's local name" text; parent-gate digit parsing (after checking at runtime).
- [ ] D7 [CODE] (M) ◇ B6 (trophy, rewards, ads or Remove Ads); make the encouragement toggle work or remove it; fix the trophy accessibility hint.
- [ ] D8 [CODE] (R) Back in the standalone app that does not dead-end; a separate `ProductVariant`; trim the target's languages; an in-app privacy link; a distinct icon; ◇ B8 changes to the payload.
- [ ] D9 [CODE] (all) Remove the dead legacy Pong code, `PingPongAssets` and unused host services; add a product condition to the Firebase `canImport` guards; ◇ trim duplicate audio.
- [ ] D10 [CODE] (all) Fix or retire the stale audit scripts (`audit-modern-pong.py`, `audit-release-closure.ps1:130`, `audit-remote-records.ps1:97-102`, the Android-snapshot paths in `audit-firebase-leaderboard.ps1`, the ModernPong blind spot in `audit-minik-ads.ps1`) and the contradicted docs (§9.3).
- [ ] D11 [CODE] (all) Add Retro to `ios-simulator.yml`; pin the Xcode and XcodeGen versions; commit a `Package.resolved`; ◇ add test hosts (or UI smoke tests) for the E, M, MP and R targets.
- [ ] D12 [CODE] (P, E, M, MP) ◇ A `.storekit` configuration for `remove_ads` in each app scheme that keeps the purchase.

### Phase E: Apple Developer setup (can run in parallel with C and D; needs B7 for M and MP)
- [ ] E1 [EXT] Get the Apple Team ID (→ `DEVELOPMENT_TEAM` / `APPLE_TEAM_ID`).
- [ ] E2 [EXT] Register 5 explicit App IDs. Enable **App Attest** on `com.appsbybros.minik.plus` and `.plus.english`.
- [ ] E3 [EXT] Create an Apple Distribution certificate and an App Store provisioning profile per bundle ID (or plan for automatic signing with an App Store Connect API key).

### Phase F: Firebase console (no rules changes from the iOS repo)
- [ ] F1 [EXT] `easycallandanswer`: confirm the iOS apps for P and E are registered, register the App Attest provider (keep enforcement **off**), confirm anonymous sign-in is enabled, and confirm the composite indexes are deployed.
- [ ] F2 [EXT] **Do not deploy the iOS repository's `firestore.rules`** to `easycallandanswer` (its deny-everything rule would break Android and other apps).
- [ ] F3 [EXT] `minikswish`: confirm the Pong iOS app registration and API-key restrictions, confirm anonymous sign-in, and confirm which database rules version is live and that it accepts iOS writes (after D2). ◇ B9: App Check.

### Phase G: App Store Connect (needs E2 and the B decisions)
- [ ] G1 [EXT] Create the app records needed (up to 5), with SKU, primary language, category and age rating (B2).
- [ ] G2 [EXT] ◇ `remove_ads` non-consumable in-app purchase per product that keeps it (B1); Pong offer codes (check support for non-consumables with an iOS 17 minimum).
- [ ] G3 [EXT] Agreements, tax and banking.
- [ ] G4 [EXT] App Privacy answers per product, **including the Google ads SDK's manifest where it is linked**; the privacy policy URL live at `miniklearn.com/privacy` (B11); support URL.
- [ ] G5 [EXT] Create an App Store Connect API key (issuer ID, key ID, `.p8`) for CI uploads.

### Phase H: release pipeline (needs E, G5 and a passing C)
- [ ] H1 [CODE] Add an archive, sign, export and upload workflow (or document a manual Xcode Organizer path): ExportOptions.plist; GitHub secrets `APPLE_TEAM_ID`, `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `KEYCHAIN_PASSWORD`, `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY` (plus profiles if signing manually).
- [ ] H2 [MAC] First signed Release archive per target that is going ahead; export-compliance answer; check that build 79 is unique per record.

### Phase I: verification on Apple (needs C and D)
- [ ] I1 [MAC] Simulator QA for each product on iPhone (portrait and landscape) and iPad (all orientations), with the interface in English, Hebrew and Arabic and the device in Hebrew and Arabic. For E: record the result of §2.3.
- [ ] I2 [MAC] StoreKit testing with a local `.storekit` for `remove_ads` (buy, restore, refund), then sandbox testing.
- [ ] I3 [MAC] (P, E) Live leaderboard check against production rules; an Android ↔ iOS Top 20 check (names, nickname length, tie ranks).
- [ ] I4 [MAC] (MP) **Android ↔ iOS** friendly room and tournament in both directions (iOS host and Android host), including a difficulty-4 room. **Online must not be called complete before this.**
- [ ] I5 [MAC] (M, R) Math → Modern Simple → Math and Math → Retro → Math round trips; Retro standalone.

### Phase J: TestFlight, then App Review
- [ ] J1 [EXT] Upload the first builds (L7), process them, and test internally on TestFlight (L6).
- [ ] J2 [MAC] Test on real iPhone and iPad (L5), including App Attest on a device (P, E).
- [ ] J3 [EXT] Screenshots (iPhone and iPad), metadata that matches the declared languages, review notes (the parent-gate location and online-play instructions for MP), and submission.
