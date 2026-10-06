# C8 Language Mixed Release Audit

Status: `ANDROID_PARITY_IMPLEMENTED_SOURCE`. Windows-static audit complete. Apple-platform compilation, XCTest, visual, speech, accessibility, and interaction validation remain pending.

## Android authority inspected

- `ButtonsMenuFragment.kt` launches Mixed in picture-choice mode.
- `WriteScreen.kt` changes mode only after an answer/explicit next actually advances the current word. Its production schedule is 20 Word-to-Picture challenges, 10 Picture-to-Word challenges, then 5 Word Build challenges before repeating.
- Android gates later modes by learner capability. The current iOS Level A vocabulary has the image, learned-text, speech, and ordered-token capability required by all three approved modes.
- Each mode retains its normal activity presentation and behavior; Mixed is an orchestrated cycle, not a fourth generic exercise engine.

`docs/android-known-fixes.md` contains no superseding C8 correction.

## iOS contract verified or corrected

- `LanguageMixedProgression` retains the approved 20/10/5 repeating schedule and increments only for `.advancedCurrentWord`. Incorrect selections, retries, and other non-advancing interactions do not move the schedule.
- A mode change creates its next child before committing the transition. If creation fails, both the prior counter and prior child remain intact, preventing a skipped or duplicated advance.
- Schedule advancement and completed-child replacement both require the active child presentation UUID. A callback from a replaced child is ignored before it can increment, skip, duplicate, or replace the current mode.
- Word-to-Picture and Picture-to-Word now enter their explicit typed Multiple Choice presentations, restoring the correct instruction, image accessibility boundary, and stable expected vocabulary identity. Word Build now enters the explicit word presentation rather than the generic build UI.
- All three child modes use the shared Minik practice frame, branded close/replay, activity-appropriate image/text proportions, and shared correct/try-again feedback. No new generic icon or artwork substitution was introduced.
- Choice modes retain retry-until-correct, learned-language prompt/choice speech, semantic word identity, first-attempt/retry indices, and one attempt per selection.
- Word Build retains immediate-prefix validation, whitespace-free physical tokens with exact display restoration, wrong-token retry, final-word speech, and per-token `wordID.ordered-token.index` evidence under `.mixed`.
- `LanguageMixedPracticeView` rewrites child attempts to `.mixed` while preserving item identity, attempt index, result, response duration, and skill. It does not attach Math fields. The hub dispatches each callback once under `language.mixed`.
- The typed Auto eligibility boundary maps only standalone Build Word completion to `.write`; Mixed Build is deterministically excluded even though it preserves the same immediate-prefix educational behavior and completion reward boundary.
- Both child views stop speech when backgrounded or dismissed. Their existing native button, drag-optional, VoiceOver, Dynamic Type, Reduce Motion, and learned-text direction behavior remains in force for English and Hebrew.

## Deterministic evidence

Existing tests cover two complete repeating 20/10/5 cycles, non-advancing interaction exclusion, capability-based mode omission, atomic child replacement, product/language policy, Words grouping, and the exact challenge shapes/skills of all three children.

This audit adds coverage for:

- rollback of the counter and child when a threshold transition cannot create its next child;
- stale former-child advance and completion callbacks leaving the current child, mode, and counter unchanged;
- semantic vocabulary telemetry identity and learned-language speech across both choice modes in English and Hebrew;
- Mixed Word Build per-token identity, retry index, word-construction skill, `.mixed` family, and absence of Math fields;
- typed exclusion of Mixed completion from Android Write Auto evidence while standalone Build, Tower, and Soccer remain eligible;
- explicit source contracts for all three presentations and exactly two child progress routes.

The focused audit now rejects five negative fixtures covering a wrong schedule identity, removal of the stale-child guard, generic choice presentation, Math-family telemetry leakage, and Mixed feeding Write Auto.

## Remaining release gates

- Compile all four products and execute ProductConfigurationTests on macOS/Xcode.
- Confirm the 20/10/5 visual transitions, continuous repeat, wrong-answer retry, and absence of duplicated progress on Simulator/device.
- Confirm real English/Hebrew prompt, choice, token, and final-word speech plus replay/interruption/background cancellation.
- Confirm compact iPhone, iPad, landscape, Dynamic Type, VoiceOver focus/labels, keyboard/Switch Control, Reduce Motion, and mixed RTL/LTR layouts.
- Obtain native-language review of catalog translations; fallback values are not claimed as linguistically reviewed.

No GitHub Actions workflow was triggered by this audit.
