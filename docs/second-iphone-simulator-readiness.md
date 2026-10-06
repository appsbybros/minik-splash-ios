# Second iPhone Simulator readiness

## Evidence boundary

This ledger consolidates the first iPhone/Appetize findings after the post-C14, English Only, and Math visual-consistency source work. It is a pre-Mac review artifact, not permission or an instruction to run a Simulator build. No Xcode, XCTest, Simulator/device, audible speech, runtime performance, accessibility, or final visual result is claimed here.

Allowed statuses:

- `FIXED_STATIC`: source and deterministic Windows checks contain the intended correction; runtime confirmation may still be listed.
- `REQUIRES_RUNTIME_CONFIRMATION`: Windows evidence cannot determine the result or interaction quality.
- `OPEN`: further known source/product work remains before runtime confirmation.

## Known first-Simulator findings

| Finding | Product coverage | Status | Static evidence and remaining gate |
|---|---|---|---|
| Language Home hierarchy and activity art | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Home uses logo/Home/Records/Parent hierarchy and exact 13-activity artwork mapping. English Only resolves every card through fixed English. Confirm crop, density, typography, and iPhone/iPad layout. |
| Learn presentation | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Dedicated Language Learn composition, bounded illustration, learned text, branded replay, and looping progression are source-locked. Confirm every English/Hebrew card, Dynamic Type, replay, and layout. |
| Letter Pairs framing and any-two behavior | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Shared Minik frame, eight-tile any-two board, learned speech metadata, and deterministic C2 contracts remain present. Confirm tile fit, speech, feedback, and accessibility. |
| Success/failure feedback | MinikPlus; MinikPlusEnglish; MinikMath | FIXED_STATIC | Shared graded surfaces use owned Minik success/try-again art with Reduce Motion-safe presentation. Confirm visual weight, animation, and announcement timing. |
| Picture Memory placement and blank backs | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Picture Memory remains in Games, uses original mascot placement, blank face-down content, Android-color gradient backs, and typed reveal speech. Confirm responsive grid, reveal timing, speech, and card proportions. |
| Soccer letters, introduction, and controls | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Language tokens are visible colored controls; native tap-to-kick behavior, localized tap-only visible/spoken introduction, and original field/goal/goalkeeper/ball are locked. Confirm first-three persistence, tap targets, shot timing, RTL/LTR, and scoring presentation. |
| Tower composition | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Language Tower has prominent target/replay, colored tokens, visible locked base, bottom-up growth, and exact sand/gift-mascot/beach assets without changing Math Tower. Confirm drag/tap alternatives, fitted height, speech, and iPhone/iPad composition. |
| Tic-Tac-Toe hidden score and visual composition | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Cumulative scores persist only in session state; a source guard rejects direct score rendering. Exact mascot, branded close, X/O controls, board, AI levels, feedback, and ungraded policy remain. Confirm no visible score, AI/timing, audio, and layout. |
| Parent Area | MinikPlus; MinikPlusEnglish; MinikMath | FIXED_STATIC | Compact sheet composition, product close/logo art, interface locale, encouragement, progress/records, fixed-English read-only policy, and Math level policy are source-locked. Confirm detents, dimming, picker behavior, stale-state fallback, and accessibility. |
| Word Cards | MinikPlus; MinikPlusEnglish | FIXED_STATIC | Original Cards background/mascot, branded controls, typed learned content, shuffled continuous cycles, and manual/timed modes are locked. Confirm crop, timing, replay, lifecycle, and accessibility. |
| Ping Pong table/mascot composition and typography | MinikMath; MinikPingPong | FIXED_STATIC | Dedicated arena, top-band Minik placement, table geometry, and rounded HUD hierarchy remain source-locked. Confirm common iPhone/iPad crop, obstruction, and legibility. |
| Ping Pong tap/swipe serve feel | MinikMath; MinikPingPong | REQUIRES_RUNTIME_CONFIRMATION | Coordinate mapping and deterministic lane/depth assertions are present, but natural serve feel, hit targeting, trajectory, and touch calibration cannot be proven statically. |
| Language learned and interface speech | MinikPlus; MinikPlusEnglish | REQUIRES_RUNTIME_CONFIRMATION | Typed cue/voice boundaries and lifecycle cancellation are source-audited. English Only learned speech is fixed English while interface speech follows an allowed locale. Audible output, voice availability/fallback, sequencing, interruption, and background behavior require runtime confirmation. |
| Math prompt/fact speech | MinikMath | REQUIRES_RUNTIME_CONFIRMATION | Specialized and shared Math screens retain prompt/fact speech calls with interface-locale voice selection and branded replay. Audible output and mathematical phrasing require runtime confirmation. |
| Loading and performance | MinikPlus; MinikPlusEnglish; MinikMath; MinikPingPong | REQUIRES_RUNTIME_CONFIRMATION | Windows evidence cannot distinguish Appetize streaming delay from app launch, asset decode, navigation, or session cost. Profile launch/memory/repeated sessions on Apple runtime before claiming improvement. |
| English Only production policy | MinikPlusEnglish | FIXED_STATIC | Exact 13-route parity, fixed-English state, no learned-language selector, 10 interface locales without Hebrew, English art/speech metadata, Arabic-interface RTL versus English LTR, and product isolation pass deterministic audits. Confirm all routes, Parent choices, speech, RTL, and visuals. |
| Math visual consistency | MinikMath | FIXED_STATIC | All 13 identities have M1/M5/M10 records; M1-M10 factories are complete; educational screens share Math frame/light surfaces/branded close/feedback, and specialized replay uses owned Minik art. Confirm every representation, layout, interaction, RTL interface, and low/mid/high readability. |
| Four-product build, package, and launch | MinikPlus; MinikPlusEnglish; MinikMath; MinikPingPong | REQUIRES_RUNTIME_CONFIRMATION | Windows audits do not compile Swift or validate target resource packaging. All four products still require a separately authorized macOS compile/package/launch review before release claims. |

## Product-specific next review scope

### MinikPlus

- `REQUIRES_RUNTIME_CONFIRMATION`: English and Hebrew routes, LTR/RTL learned content, speech, Parent selection, accessibility, and iPhone/iPad visual review.
- `REQUIRES_RUNTIME_CONFIRMATION`: build/package/launch and loading/performance.

### MinikPlusEnglish

- `REQUIRES_RUNTIME_CONFIRMATION`: all 13 fixed-English routes across the 10 interface locales, especially Arabic-interface RTL with learned-English LTR.
- `REQUIRES_RUNTIME_CONFIRMATION`: Parent fixed-English policy, speech boundary, build/package/launch, and loading/performance.

### MinikMath

- `REQUIRES_RUNTIME_CONFIRMATION`: all 13 identities across representative Level 1, Level 5, and Level 10 content, precise representation fit, branded controls/feedback, and RTL-interface/LTR-math behavior.
- `REQUIRES_RUNTIME_CONFIRMATION`: Ping Pong serve feel, Math speech, build/package/launch, and loading/performance.

### MinikPingPong

- `REQUIRES_RUNTIME_CONFIRMATION`: standalone setup/match/results, table/mascot composition, tap/swipe controls, serve feel, typography, accessibility, and lifecycle.
- `REQUIRES_RUNTIME_CONFIRMATION`: build/package/launch and loading/performance.
