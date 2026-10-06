# MINIK iOS: answers and fix plan up to GitHub CI and an iPad test (2026-10-01)

## About this document

**Purpose.** This document answers every question that has to be settled before the iOS fixing starts, and lays out the fixes in order. The goal is two finish lines:
1. the code is good enough to push to GitHub and build there;
2. it is good enough to test on an iPad.

It builds on `docs/ios-current-state-2026-09-30.md`, the full audit, and corrects it where the source has changed since.

**How it was made.**
- Read-only. No code, project, Firebase, App Store Connect or signing change was made. Nothing was committed or pushed.
- No Pixel or other device was used. None is attached, and no Android emulator is installed on this machine.
- Evidence came from:
  - the iOS tree `C:\Projects\Minik-to-IOS\ios-main-merge`;
  - your recorded decisions in `docs/MINIK_MASTER_PLAN.md` (Part X, the decision log);
  - your own instructions in this session;
  - the current Android apps (read-only): `C:\Projects\Minik`, `C:\Projects\minikMath`, `C:\Projects\MinikPingPong`, `C:\Projects\MinikPaddleAndLearn`;
  - a live check of the two website URLs the iOS apps use.

**How to answer.** Section 3 holds the only questions that need you. Section 5 lists decisions derived from Android that need a one-word confirmation. A short reply template is at the end.

---

## 1. What changed since the 09-30 audit

**A later session changed the iOS tree without committing.** It updated Retro to match current Android **Bounce & Learn** (`C:\Projects\MinikPaddleAndLearn`), as you asked on 09-30. Files and changes:
- `Resources/RetroPong/*`, `Sources/RetroPong/*`, `Tests/RetroPong/host.test.cjs`, `project.yml` and `docs/retro-pong-*`.
- New docs: `docs/bounce-refresh-2026-09-30.md`, `docs/math-result-banner-2026-09-30.md`, `docs/pong-hud-2026-09-30.md`.
- New `tools/bounce-refresh/` (QA scripts, 104 KB) and `artifacts/` (54 MB of screenshots and packages).
- Standalone display name is now **"Minik Bounce"** (the same as Android).
- It has its **own icon**, no longer identical to Modern Pong's.
- **Back on the court returns to setup**, and Back from setup returns to Math when hosted there. The standalone "Game closed" dead end is gone.
- A portrait layout adapter for iPhone and iPad was added.

**These Retro findings from the 09-30 audit are now outdated:** the old payload source, the identical icon, the Back dead end and the "Minik 80s Pong" name.

**How the iOS Retro files compare with current Bounce (checked today):**
- 70 of 74 files are identical.
- The other 4 differ only by the documented iOS adapters, plus one missing fix: Bounce commit `d5d0392` (09-30 22:15), where the Hebrew total label follows right-to-left direction.
- `MinikPaddleAndLearn` also has **newer uncommitted edits**, the last at 01:22 today: a new logo `minik-brand.png` and score typography.

**The 4 unpushed commits are still only in `C:\Projects\Minik-to-IOS\ios\.git`.** The Bounce refresh exists only as uncommitted files on this disk.

**Nothing else in the iOS product code changed.** The Android AdMob change of 09-30 (in `C:\Projects\Minik`) doesn't affect iOS.

---

## 2. The two finish lines

### Gate 1: good enough for GitHub
1. All iOS work is committed and pushed to `github.com/appsbybros/MinikPlus-iOS`. Large or unrelated files are excluded.
2. On a GitHub macOS runner, all **5** app targets build: MinikPlus, MinikPlusEnglish, MinikMath, MinikPingPong and MinikRetroPingPong.
3. `ProductConfigurationTests` passes, and the Retro JavaScript tests pass.
4. Each of the 5 apps installs, launches and stays up for at least 5 seconds with no crash, on **an iPhone Simulator and an iPad Simulator**. Screenshots are saved.
5. No CI run writes test data to production Firebase.

### Gate 2: good enough for an iPad test
1. Gate 1 is green.
2. The fixes in Wave 3 (§7) are done and Gate 1 is green again.
3. A build is installed on your iPad by the route you choose in Q4: TestFlight, or free sideloading.
4. You walk through the iPad checklist (§7, after Wave 4).

**Not in scope yet:** App Store release items such as Kids Category, age rating, App Privacy answers, prices, store listings and final translations for all 11 languages. They are listed in §6 so nothing is lost.

---

## 3. Questions only you can answer

Each question says why it matters and what I will do with each possible answer.

**Q1. GitHub macOS runners.** An uncommitted note in the `ios` folder says GitHub-hosted macOS was "blocked by the account billing/spending-limit status". Without a Mac runner nothing can be built.
- For private repositories GitHub counts macOS minutes at 10× the Linux rate against your included minutes. With a $0 spending limit, macOS jobs stop once those are used up.
- One full simulator run can take up to about an hour (the workflow's limit).
- What is the status now? Options:
  - **(a)** raise the Actions spending limit or budget;
  - **(b)** make the repository public (standard runners are free for public repos);
  - **(c)** you have a Mac I can use instead.

**Q2. Commit and push the iOS repository.** May I commit and push `main` to `github.com/appsbybros/MinikPlus-iOS`? My plan:

| Include | Exclude (add to `.gitignore`) |
|---|---|
| The 4 local commits, the uncommitted Bounce refresh, the new docs (including the audit and this file), `tools/bounce-refresh/` | `artifacts/` (54 MB), `website/` and `website.zip` (Android website, about 60 MB), the 0-byte `rollout-…File too big…` file, the empty `%USERPROFILE%/` folder, `docs/Minik-iOS-PingPong-80s-Reference-v2.zip` (input for the dead native 80s attempt) |

- If GitHub has moved ahead, I will ask before rebasing, as with the Android repo.

**Q3. Apple account.**
- Do you have a **paid Apple Developer Program** membership ($99/year)?
- Under which account or team? All bundle IDs start with `com.appsbybros`.
- Do you have access to any Mac?
- A paid membership is needed for TestFlight and for the App Store. A free Apple ID is enough only for route B in Q4.

**Q4. The iPad.** Which model is it, and which iPadOS version? The apps need **iPadOS 17 or newer**. Which way should builds get onto it?
- **(A) TestFlight (recommended if you have, or will get, the paid membership).**
  - Real Release builds, installed from the TestFlight app. Leaderboard App Check (App Attest) and in-app purchases (sandbox) can be tested.
  - Needs Q3 plus App Store Connect app records.
  - I will write the signed archive-and-upload workflow. You create the certificate and API key and add them as GitHub secrets (names in §7, Wave 4).
- **(B) Free sideloading from Windows** (e.g. Sideloadly with a free Apple ID).
  - CI produces unsigned `.ipa` files (the existing `ipad-unsigned-ipa.yml`, extended to all 5 apps). You install them over USB.
  - Limits: apps expire after 7 days; a free account can keep only 3 sideloaded apps at once; purchases can't be tested; capabilities such as App Attest may not be available.
- **(A + B)** Start with B now and move to A once the account is ready.

**Q5. iOS AdMob apps.** The Google ads SDK is linked into Plus, English Only, Math and Ping Pong. In Plus, English Only and Math the ads app ID is **empty**, which Google's SDK is known to crash on at launch. Ping Pong ships Google's *sample* app ID in Release. On Android you just created real AdMob apps. Options:
- **(a)** In AdMob, add **4 iOS apps** (Minik Plus, Minik Plus English Only, Minik Math, Minik Ping Pong), each with **one interstitial unit**, and send me the 8 IDs. Ads stay switched off until you decide to enable them.
- **(b)** For now I use Google's sample app ID in **Debug and internal test builds only** (ads stay off). Real IDs are then required before App Store submission.
- With (b), TestFlight builds would carry a sample ID until replaced, so (a) is cleaner.

**Q6. Firebase App Check for the leaderboard.** Your Android work (registering debug tokens; "App Check is blocking the debug code test") strongly suggests **App Check enforcement is ON for Firestore** in `easycallandanswer`. Is it?
- If it is on, the iOS leaderboard (Plus, English Only) is rejected until App Check is set up for the two iOS apps:
  - for route A, register **App Attest** for each iOS app in Firebase App Check (this needs the Team ID from Q3);
  - for route B, the leaderboard will most likely stay offline, which is acceptable for a UI test.
- Modern Pong's `minikswish` database has no App Check on Android either, so online Pong is not affected.

**Q7. Is Android Bounce finished?** `MinikPaddleAndLearn` has uncommitted edits made until 01:22 today (a new logo and score typography).
- **Now:** sync iOS to Bounce's committed HEAD (`d5d0392`).
- **Later:** wait until Bounce is committed, then sync once.

**Q8. Bundle ID for the iOS Bounce app.** It is currently `com.appsbybros.minik.pingpong.retro`, created on 09-28 and not yet registered with Apple. Android uses `com.appsbybros.minik.bouncelearn`. A bundle ID can't be changed after it is used in App Store Connect, so choose before registration:
- keep `…pingpong.retro`; or
- change to `com.appsbybros.minik.bouncelearn`, the same as Android.

**Q9. Confirm the derived decisions D1–D9 in §5.** "Yes to all" is enough, or name the exceptions.

**Q10. Hebrew translations before the iPad test.** In the iOS string catalog about **437 of 596 strings are still English in Hebrew**, so a Hebrew iPad will show many English words. May I fill them now?
- I'll reuse the Android Hebrew wording where the same text exists, and translate the rest myself.
- Each string stays marked "needs review", so you check them on the iPad.
- The other 9 languages come later.

---

## 4. Already decided: no question needed

| Topic | Answer | Source |
|---|---|---|
| Apple bundle IDs | `com.appsbybros.minik.plus`, `.plus.english`, `.math`, `.pingpong`; tests `com.appsbybros.minik.tests`. The v23 WebView package must not use them. | Decision log 2026-09-13 |
| iOS Retro / Bounce source | Current Android Bounce & Learn (`MinikPaddleAndLearn`), not `minik80sPingPong`. Already applied (uncommitted). | Your 09-30 instruction; `docs/bounce-refresh-2026-09-30.md` |
| Retro / Bounce monetization on iOS | No ads, no purchases, no codes | Decision log 2026-09-28 |
| Retro / Bounce display name | "Minik Bounce", the same as Android `values/strings.xml:2` | Android; already applied |
| Where the games open | Math opens both Modern (Simple) and Bounce. The Modern standalone app has no Bounce. | Decision log 2026-09-28 |
| Modern Pong scope | Port the **current** Android Modern Pong, including online play, tournaments, ads and Apple purchases. This covers Android's 09-29 changes (Beginner as the default level, roster, serve and house-player logic). | Decision log 2026-09-28 |
| Modern Pong language | Follow the device's main language: Hebrew device → Hebrew right-to-left, anything else → English. No in-app picker. | Android `LocalizedActivity.kt:17-26` |
| Modern Pong first launch | Anonymous sign-in and an automatic curated nickname at first launch, **the same as Android**, so it's not a bug. No profile deletion on Android either. | Android `PlayActivity.kt:71`, `FirebasePongRepository.kt:24-54` |
| Modern Pong App Check | None, the same as Android's multiplayer database | Android `AccessCodes.java` (the only App Check use) |
| Modern Pong parent gate | A gate **before** Remove Ads, restore and code entry (Android: four spelled-out digits) | Android `MonetizationActivity.java:65-85` |
| Public leaderboard name on iOS | Curated nickname ("Adjective Noun N") with an optional avatar. Android's typed 5-character name is **not** an iOS requirement. | Decision log 2026-09-13; your 09-30 brief |
| When to ask for a nickname | Only when a score actually qualifies for the leaderboard. "Not now" waits until the next new best. | Decision log 2026-09-13; Android `LeaderboardPublisher.kt:45-51`, `LeaderboardState.kt:81-86` |
| Leaderboard on/off and delete | Behind the grown-up gate (an iOS decision; Android has no gate) | Decision log 2026-09-13 |
| English Only languages | Hebrew never. A Hebrew device gets English and left-to-right. Other languages, including Arabic (right-to-left), stay available, the same as Android. | Decision log 2026-08-31; your 09-27 instruction; Android `MainActivity.kt:40-57,87-102,248-251` |
| English Only learned language | Always English (already true on iOS) | Android `MainActivity.kt:119-180` |
| Remove Ads product ID | `remove_ads` in every app | Decision log 2026-09-13; all Android apps |
| Ad format and child settings | Interstitial only, at completion boundaries; child-directed, rated G, non-personalized. The iOS code already follows this. | All Android apps; `GoogleMobileAdsInterstitialService.swift:47-50` |
| Privacy and support URLs | `https://miniklearn.com/privacy` and `https://miniklearn.com/contact` both load (checked 10-01). The policy covers Minik, Plus, Games and Math and mentions Apple/StoreKit, but **does not name Ping Pong or Bounce**. | Live check |
| Firebase iOS registrations | Plus and English Only are registered in `easycallandanswer` (their config files could only be downloaded after registering). Ping Pong iOS is registered in `minikswish` (09-28). | `Config/Firebase/*`; decision log 2026-09-28 |
| Hosted Apple validation | GitHub Actions only; no Codemagic or Appetize | Decision log 2026-09-13 |

---

## 5. Derived from your Android decisions: please confirm (Q9)

| # | Change on iOS | Why (evidence) | Today on iOS |
|---|---|---|---|
| D1 | English Only uses **the same cat app icon as Plus**. The kids-on-a-pencil logo is shown only inside the app. | On 09-28 you said both launchers share one logo and the English Only logo is for inside the app. Android plus and plus-english-only have identical icon XMLs. | English Only's app icon is the kids-on-a-pencil picture |
| D2 | English Only home-screen name **"Minik"** | Android: `// English is called Minik and not Plus` (`build.gradle.kts:97-98`) | "Minik Plus English" |
| D3 | The interface language **starts as the device language** when supported (Hebrew device → Hebrew in Plus, English in English Only). The Parent Area picker still overrides it. | Android follows the device (`UserLanguageManager.kt:114-135`). This is also normal iOS behavior, and it removes most of the mixed-language screens found in the audit. | Always starts in English |
| D4 | Plus default learned language: Hebrew interface → learns English; any other interface → learns Hebrew | Android `MainActivity.kt:109-138` | Always English |
| D5 | Math: **hide the trophy** until Math records exist | Android Math has no leaderboard, records or trophy | Trophy always says "not configured" |
| D6 | Math: hide the "Encouraging messages" switch | It has no effect in Math | Shown, does nothing |
| D7 | Bounce inside Math: keep the 09-28 decision (the same game as standalone). Android Math instead uses Math branding "Minik Ping Pong" and Balloon Madness **off**. | Decision log 2026-09-28 vs Android `minikMath app.js:446-452` | Same as standalone (Madness on) |
| D8 | Modern Pong: port **all** of Android's 09-29 changes (Beginner level and lesson, roster stats and names, house-player strategy, serve reliability, 2.0 s grace, no guest-side scoring, restore shortcut) | Follows from the 09-28 scope decision. Beginner is Android's default for rooms, so today an iOS-hosted 7-6 Beginner result is rejected. | Behind Android |
| D9 | CI smoke tests launch Modern Pong **offline**, so no writes to production `minikswish`. Normal launches stay online like Android. | Keeps test data out of production | Every CI launch writes a profile to production |

---

## 6. Still open, but not blocking GitHub or the iPad test

Each needs a decision before App Store submission; none blocks Gates 1 and 2.

| Topic | Facts to decide with |
|---|---|
| Kids Category and age rating | Apple's Kids rules restrict third-party ads and analytics and require a parental gate before purchases and links. They decide whether iOS ads are allowed at all. |
| Enabling iOS ads, and Remove Ads when there are no ads | Android shows ads in all apps. Until iOS ads are on, a Remove Ads purchase sells nothing. Without an App Store product the purchase button simply doesn't appear. |
| Ad consent (UMP) and Pong's age question | Android Math, Pong and Bounce run Google's consent form. Android Pong asks for an age group (only "18+" turns child treatment off). iOS has neither. Only relevant once ads are on. |
| Access codes | All Android apps redeem Firestore `access_tokens` codes (app_id 3/4/5/6) for ad-free use. On iOS, Apple guideline 3.1.1 does not allow unlocking features with your own codes. The Apple alternative is **App Store offer codes**, which Modern Pong already has. |
| Child profiles | Android Languages has several children; iOS has one owner. Decision log §30.3 lists it as open. |
| Terms URL | iOS links to `easycallandanswer.com/terms.html`. The Android apps show no Terms link. |
| Privacy policy coverage | The live policy does not name Ping Pong or Bounce. App Privacy answers are needed per app. |
| Crash and usage reporting on iOS | Android Languages uses Firebase Analytics and Crashlytics; the other Android apps don't. iOS has neither. TestFlight shows crash reports without them. |
| Math records and rewards | Your 08-30 decision listed records and points for the full app, but neither Android Math nor iOS Math has them. |
| The other 9 UI languages | About 73% of strings are untranslated in each |
| Store names, prices, screenshots | For each App Store Connect record |

---

## 7. The fix plan, in order (ready to run once §3 is answered)

**Sizes:** S = under an hour, M = a few hours, L = a day or more. Evidence for every file and line is in the 09-30 audit.

### Wave 0: save and publish (needs Q1, Q2)
- **0.1** Add the `.gitignore` entries from Q2. Commit the Bounce refresh, the new docs and `tools/` as separate, clearly named commits. **S**
- **0.2** Push `main`. The unpushed commits and the refresh then exist on GitHub, not only on this disk. **S**

### Wave 1: make the first CI run count (before dispatching)
- **1.1** Ads app ID (from Q5): set a valid `GADApplicationIdentifier` for Plus, English Only, Math and Ping Pong in `project.yml`, either the real iOS IDs or the sample ID in Debug only. Ads stay off (`MINIK_ADS_ENABLED: NO`). This removes the likely launch crash. **S**
- **1.2** CI offline launch for Modern Pong (D9): a launch argument read in `MPController.swift:45-52` selects `MPLocalRepository`, and the smoke step passes it. **S**
- **1.3** `ios-simulator.yml`:
  - add MinikRetroPingPong to the build and launch lists (`:47`, `:296`);
  - add an **iPad Simulator** pass (install, launch, 5 s survival, screenshot) for all 5 apps;
  - run the Retro Node tests;
  - log the Xcode version used;
  - keep a separate DerivedData folder per app. **M**
- **1.4** `ipad-unsigned-ipa.yml`, **only if route B**: build all 5 apps for a real device (unsigned) and package one `.ipa` each. **S**

### Wave 2: first real Apple build (Gate 1)
- **2.1** Run the workflow. Fix compile errors **one at a time**, re-running after each fix. Nothing at HEAD has ever been compiled, so the number of errors is unknown. Most likely spots: Firebase, ads SDK and StoreKit code added after 09-05; Modern and Retro. **M–L**
- **2.2** Get `ProductConfigurationTests` green. This includes the 09-05 fix that was never re-run and about 194 tests that have never run. **M**
- **2.3** Launch smoke on iPhone and iPad for all 5 apps. Fix any launch crash. **S–M**
- **Gate 1 reached** when all five pass in one run.

### Wave 3: fixes that make the iPad test meaningful

**Plus and English Only**
- **3.1** D3: start the interface language from the device language (`InterfaceLocale.swift:38-63`), keeping the Parent Area override. **S**
- **3.2** D4: default learned language by interface language (`EducationalParentSettings.swift:26-31`). **S**
- **3.3** Nickname prompt (decided):
  - offer it only when the new best actually qualifies for the Top 20, checking participation first;
  - "Not now" waits until the next new best;
  - show "Saved on this device" at most once per new best.
  
  Files: `RemoteRecords.swift:100-127`, `MinikActivityHubView.swift:1056-1190`, plus tests. **M**
- **3.4** Put the leaderboard on/off switch and delete behind the grown-up gate (`ParentAreaView.swift:424-527`, reusing `ParentalGateView`). **S**
- **3.5** Fix the Top 20 tie highlight (`RemoteRecords.swift:600-609`, `RecordsLeaderboardView.swift:124-129`). **S**
- **3.6** Add the 5 missing catalog strings; Q10 Hebrew completion. **S** for the keys; **M** for Hebrew.
- **3.7** D1 and D2: English Only icon and name (`project.yml:174-179`). **S**

**Math**
- **3.8** D5 hide the trophy; D6 hide the encouragement switch (`MinikActivityHubView.swift:413-421`, `ParentAreaView.swift:222`). **S**

**Modern Pong**
- **3.9** Parent gate before Remove Ads, Restore and Redeem code (`ModernPongView.swift:116,403-415`, reusing `ParentalGateView`). **S**
- **3.10** Hebrew from the device language for the Ping Pong app (`RootView.swift:68-72` for `launchExperience == .pingPong`). **S**
- **3.11** Accept Beginner results (`MPMultiplayerModels.swift:200-204`) and update the roster (`MPRoster.swift`, and its test). **S**
- **3.12** D8: port the rest of Android's 09-29 changes: Beginner engine and lesson, house-player strategy, serve reliability, grace period, guest scoring, restore shortcut. Also refresh the rules snapshot and tests, then re-run `audit-modern-pong.py`. **L**
- **3.13** Make "Don't show the guide automatically" work (`MPController.swift:242,290`). **S**

**Bounce**
- **3.14** Sync to Bounce (from Q7); update `docs/retro-pong-android-provenance.json`; re-run the Node tests and `audit-retro-pong.py`. **S**

**All**
- **3.15** Re-run Gate 1.

### Wave 4: put it on the iPad (from Q3, Q4, Q6)

**Route A, TestFlight**
- **Your steps (external):**
  - register the 5 App IDs, with App Attest on Plus and English Only;
  - create the App Store Connect app records;
  - create an Apple Distribution certificate and an App Store Connect API key;
  - add GitHub secrets `APPLE_TEAM_ID`, `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `KEYCHAIN_PASSWORD`, `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY`;
  - in Firebase App Check, register App Attest for the two Language iOS apps.
- **My steps:**
  - add `ExportOptions.plist` and a manual "archive → sign → upload to TestFlight" workflow;
  - set `DEVELOPMENT_TEAM` from the secret.
- **Result:** install from the TestFlight app on the iPad.

**Route B, sideloading**
- Run the extended unsigned-IPA workflow, download the `.ipa` files and install them with Sideloadly using your Apple ID. Up to 3 apps at a time, re-installed every 7 days.

**iPad checklist (both routes).** For each app, in portrait and landscape and with the iPad in Hebrew and in English:
- first launch;
- every menu and activity once;
- Parent Area, including the gate;
- background and return;
- rotation mid-activity.

Per product:
- **Plus / English Only:** Hebrew right-to-left; English Only stays English on a Hebrew iPad; leaderboard (route A only, if App Check is on).
- **Math:** both Pong entries and returning to Math with the level kept.
- **Modern Pong:** local match, friendly room, tournament with house players, Hebrew UI.
- **Bounce:** setup, Help, a match with train and balloons, Back behavior, saved points.

**Not possible now:** Android ↔ iOS cross-play and cross-platform leaderboard checks need an Android device or emulator. None is available today.

---

## 8. What I will not do without your explicit OK

- Commit or push the iOS repository (Q2).
- Rebase onto newer GitHub commits.
- Anything in the Firebase console, App Store Connect, AdMob or Apple Developer, and any certificate or secret.
- Delete any file, including the reference zip and the 0-byte file.
- Touch the Android repositories.

---

## Reply template

```
Q1: a / b / c
Q2: yes / no (exceptions: …)
Q3: paid membership yes/no, account: …, Mac: yes/no
Q4: iPad model …, iPadOS …, route A / B / A+B
Q5: a (IDs follow) / b
Q6: App Check on / off / don't know
Q7: sync now / wait
Q8: keep …pingpong.retro / change to …bouncelearn
Q9: yes to all D1–D9 (except: …)
Q10: yes / no
```
