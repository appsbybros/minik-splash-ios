# C7 Build Word Release Audit

Status: Windows-static audit complete. Apple-platform compilation, XCTest, visual, speech, accessibility, and interaction validation remain pending.

## Android authority inspected

- `WriteScreen.kt` in the drag/build route constructs the learned word from individually selectable letters and presents learned-word speech/replay.
- The Android flow evaluates the next letter immediately: a correct visible letter is accepted into the word, while a wrong letter is not consumed and remains retryable.
- Physical instances remain distinct when the same visible letter occurs more than once.
- `06-language-build-word-hebrew.png` is the visual reference: Minik frame, one white practice surface, branded close/replay, concise build instruction, a prominent target/prompt, a constructed-word area, and high-contrast letter controls.

`docs/android-known-fixes.md` contains no superseding C7 correction.

## iOS contract verified or corrected

- `LanguageWordBuildContentProvider` requires an allowed Language product/language, a real vocabulary stage, word-construction skill, ordered-token interaction, image readiness, and no incompatible count request.
- Each challenge now carries typed `LanguageWordBuildContent`: the stable vocabulary item identity plus its exact English LTR or Hebrew RTL learned target and speech metadata.
- Available letters have unique physical token IDs. Validation compares the next visible representation, so equivalent duplicate-letter instances are interchangeable without losing ordered correctness.
- Whitespace is no longer exposed as an invisible draggable/tappable token. The exact target retains whitespace, and `BuildSession.builtDisplayText` restores a space only when the following visible letter has been accepted.
- C7 uses `immediatePrefix`: wrong letters remain unconsumed and retryable, correct letters advance the prefix, and the final correct letter completes and advances automatically after feedback.
- The production route now uses the explicit word presentation: localized “Build the word” / “Your word” copy, exact progressive word display, the shared Minik background and white panel, product close/replay art, adaptive colored letter controls, and Reduce Motion-safe feedback.
- The image prompt's VoiceOver label is the actual learned word. Letter controls are native buttons with learned-letter labels and add hints; the constructed region exposes its current exact word as an accessibility value. Drag remains optional rather than required.
- The final accepted letter speaks first, followed by the complete learned word. Prompt replay and individual letters use learned-language speech; background/disappearance/exit stop speech.
- The previous immediate-prefix path emitted no progress because it never called `submit()`. It now records each valid letter selection through `LanguageOrderedTokenAttemptTracker`: stable `wordID.ordered-token.index` identity, retry attempt increments for the same presented token, reset at a new token/presentation, word-construction skill, response duration, and no Math fields. Mixed can preserve the same token evidence under its `.mixed` family.

## Deterministic evidence

Existing provider/session tests cover English/Hebrew image-ready challenges, exact grapheme instances, exact expected ordering, language/direction, duplicate-letter physical identity/interchangeability, non-solved shuffle, immediate correct/wrong/final behavior, undo/submit exclusion, request rejection, and product policy.

This audit adds coverage for:

- typed content item/target association on generated Word Build challenges;
- whitespace-free physical tokens with exact target text retained;
- deterministic `ICE CREAM` progressive display (`ICE` then `ICE C`) without a space token;
- six typed immediate-prefix factory challenges;
- Build Word semantic token telemetry, retry indices, word-construction skill, and absence of Math fields.

## Remaining release gates

- Compile all four products and execute ProductConfigurationTests on macOS/Xcode.
- Confirm drag and tap behavior, duplicate letters, wrong-letter retry, final auto-advance, and spaced multiword display on Simulator/device.
- Confirm compact iPhone, iPad, landscape, Dynamic Type, VoiceOver rotor/focus order, Switch Control, keyboard focus/activation, and mixed RTL/LTR layouts.
- Confirm real English/Hebrew prompt/letter/final-word speech, replay, sequencing, interruption, and background cancellation.
- Obtain native-language review of catalog translations; fallback entries are not claimed as linguistically reviewed.

No GitHub Actions workflow was triggered by this audit.

## Language Auto integration

Production Build Word now uses the complete unique eligible vocabulary pool instead of treating a six-challenge batch as Android pool exhaustion. It maps to Android `WriteScreen`'s `Screen.DRAG` branch: a completed whole word adds one durable correct count; rejected letters remain retry feedback and do not add durable wrong counts. One idempotent full-pool boundary feeds the shared 100-attempt/90%-accuracy/two-pass Auto gate. The next pool is rebuilt from the persisted Parent level and vocabulary ramp without changing Build UI, correctness, reward, retry, or speech behavior.
