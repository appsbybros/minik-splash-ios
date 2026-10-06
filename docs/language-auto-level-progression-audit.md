# Language Auto word-level progression audit

Status: `ANDROID_PARITY_IMPLEMENTED_SOURCE`. Windows-static audits pass; Xcode/XCTest and runtime lifecycle validation remain pending.

## Android contract

The complete owning path was re-read in `IntroScreen.kt`, `LanguagesAndLevelsDialogFragment.kt`, `LevelsDifficultyDialogFragment.kt`, `SharedPreferencesCache.kt`, `LevelsHelper.kt`, `WordItem.kt`, `WriteScreen.kt`, `LettersTowerFragment.kt`, `LettersSoccerGame.kt`, and `MainActivity.kt`.

- Auto defaults on and the shared persisted word level defaults to A. Manual and Auto use the same A-E value; switching modes does not reset counters, pass streaks, or ramp.
- Correct/wrong counts are durable per profile and semantic word ID and shared across the eligible activities. The iOS records retain activity and source vocabulary stage as additional typed evidence without changing that shared-counter evaluation.
- The iOS Write mapping is Build Word: Android `WriteScreen` with `Screen.DRAG`, not the separate keyboard `Screen.WRITE` branch. DRAG increments a word's correct count once when the whole word completes. Its rejected-letter retry path does not persist a wrong count.
- Tower and Soccer increment the current word once for every accepted correct letter and once for every rejected wrong letter. Shot outcome does not alter Soccer educational correctness.
- Evaluation occurs only when the complete activity word pool is exhausted: Write needs 100 attempts at 90%; Tower and Soccer need 600 letter attempts at 80%. Integer percentage truncation matches Android.
- The same profile/current-level gate must pass twice consecutively. A failed evaluation, including an insufficient sample, resets the current-level streak. Manual, E-level, duplicate, and stale-level boundaries do not evaluate. Promotion is upward only, persists the same Parent A-E value, preserves counters, and sets ramp to 90.
- Android ramp is list-count mixing. For the previous and current eligible lists independently, it rounds `count * ramp / 100` and `count * (100-ramp) / 100`, caps each count, takes shuffled subsets, combines them, and shuffles again. Thus 90 means a roughly 90%-previous / 10%-current transition, not a per-item 90% probability.
- Ramp is restored across restart. Android decrements it by 10, floored at zero, from `MainActivity.onStop`; iOS maps that application lifecycle boundary to the scene entering background. Android does not condition this decay on Auto mode or activity identity.

## iOS implementation boundaries

`LanguageAutoProgressionState` and `LanguageAutoProgressRepository` persist product/profile scope, shared current level, ramp, typed per-content/activity/stage counts, per-level consecutive-pass state, applied evidence IDs, and applied pool-boundary IDs. This is separate from aggregate `ProgressSnapshot` and from Math progression.

Build Word now runs the complete unique eligible word pool before replenishment. Tower and Soccer retain their existing continuous mechanics and expose exactly-once typed boundaries when their bags replenish. Each boundary carries its construction level and exact content set, so a delayed callback from an old pool cannot promote a later level. After any boundary, the replacement pool is created from the newly persisted level/ramp; activity UI, reward, speech, physics, and retry behavior are unchanged.

Plus and English Only have product-scoped persistence. English Only remains fixed to learned English; Plus learned-language choice is independent of level/ramp. The shared hub currently initializes and loads an inert in-memory Language Auto state for every product configuration. Math never uses that state for routing, records evidence, evaluates or promotes a Language level, applies background ramp decay, or persists Language Auto state; its own progression remains separate and unchanged.

`LanguageAutoEvidenceRouting` is the production eligibility boundary: standalone Build Word completion maps to Android Write, Tower/Soccer typed attempts map to their respective gates, and every other activity returns no Auto source. In particular, Mixed Word Build retains `.mixed` progress/reward semantics and cannot feed `.write` evidence.

Deterministic XCTest source covers the 32 required contracts plus shared Android counters, skipped evidence, duplicate-boundary idempotency, and typed production eligibility. These tests are authored but not executed on Windows. The focused audit includes seven negative fixtures for aggregate-only state, one-pass promotion, stale pools, E overflow, missing ramp persistence, a disconnected factory, and Mixed incorrectly feeding Write Auto.
