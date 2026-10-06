# Language Letter Pairs Release Audit

Status: Windows-static C2 audit complete; macOS/device validation and shared final-art/feedback gates remain.

## Authority inspected

- Android `LetterPairsFragment.kt`.
- Android phone and `sw600dp` Letter Pairs layouts plus the physical tile layout.
- `docs/android-known-fixes.md` (English Only must always learn English).
- Current iOS provider, factory, session, SwiftUI view, speech, progress, rewards, localization, and deterministic test sources.

## Production contract

- One board contains four distinct learned-language initial-letter concepts and eight distinct image tiles.
- Each concept owns two different word/image tiles whose learned words begin with the same normalized letter.
- The eight physical tiles are mixed together. A child may choose any two; correctness is typed group identity, never image name or visible/accessibility text.
- Selecting a new tile speaks that physical tile's learned word once using learned-language TTS. Selecting the same first tile again cancels the selection without speaking again.
- A correct pair leaves play; an incorrect pair remains available after Continue. Input is locked while result feedback is pending.
- Completing four pairs starts another generated board in the same activity. Exit remains explicit.
- Android Letter Pairs awards one point for a correct pair, subtracts one for an incorrect pair with a zero floor, and does not use a correctness streak. iOS routes this through the shared replay-safe reward boundary.

## C2 defects corrected

1. The reusable Pairs engine previously required one selection from each visible left/right column. Letter Pairs now opts into an `anyTwoTiles` interaction and a mixed eight-tile grid; Math and other column-based Pairs callers retain the existing default.
2. Image representations previously exposed only the generic “Educational image” label and produced no learned-word speech. Letter Pairs physical tiles now carry their exact learned word as accessibility metadata and an English/Hebrew learned-language speech utterance.
3. The provider did not enforce Android's board-wide image uniqueness. Round construction now makes bounded attempts and accepts a board only when all eight external physical image references are distinct.
4. Progress previously used shuffled group ordinals and one global retry counter. C2 now records the stable semantic initial concept, tracks retries per concept and presentation, resets repeated concepts to attempt 1 on a genuinely new board, and emits no Math level/skill data.
5. Completing a board previously returned to the activity hub. The production Letter Pairs route now creates the next board in place.
6. Letter Pairs points were not connected to the local reward ledger. Correct/incorrect graded events now map narrowly to the verified Android `+1/-1`, zero-floor, streak-unchanged policy; the source activity event ID is reused for replay idempotency.

## Product and language policy

- MinikPlus supports learned English and Hebrew.
- MinikPlusEnglish accepts English only; stored or requested Hebrew remains rejected by central product policy.
- Semantic IDs include the learned language and normalized initial. Physical IDs remain separate `(groupIndex, side)` identities even when representations are visually similar.
- Learned-word speech follows `en-US` / `he-IL`; interface copy and layout direction continue to follow the selected interface locale.
- Hebrew correctness uses normalized learned-language initial identity, not rendered text equality. Image-grid ordering does not force Math/LTR semantics into Language.

## Accessibility, layout, motion, and lifecycle

- Each image button announces the represented learned word, selected/incorrect state, and an actionable localized hint.
- The mixed board uses two adaptive columns normally and one column for accessibility Dynamic Type or exceptionally narrow width. The surrounding shared practice screen remains scrollable for small iPhone and large text; the same grid expands within the iPad content cap.
- Existing tile press animation already disables scaling under Reduce Motion.
- Exit, disappearance, and transition to an inactive/background scene stop pending learned-word speech. Each new utterance replaces the previous utterance, preventing overlap.

## Deterministic XCTest source coverage

- four groups / eight physical tiles;
- all physical IDs and all board image references unique;
- arbitrary same-side physical choices in mixed mode;
- deselection, correct match, incorrect retry, match removal, and completion;
- English and Hebrew semantic groups, accessibility labels, and learned-language speech metadata;
- English Only rejection of Hebrew;
- stable semantic progress identity, per-concept retry count, new-board reset, invalid-duration handling, and absent Math fields;
- Android Letter Pairs reward mapping, point deltas, unchanged streak, product/activity filtering, and event-ID reuse.

The XCTest files were authored/reviewed on Windows and were not executed here because Swift, Xcode, and XCTest are unavailable.

## Remaining release gates

- Generate with XcodeGen and compile all four products on macOS.
- Run ProductConfigurationTests, including the new C2 cases.
- Simulator/device smoke test on small/large iPhone and iPad with English and Hebrew learned language, LTR and RTL interface combinations, Dynamic Type, VoiceOver, Reduce Motion, backgrounding, interruption, and rapid selection/exit.
- Confirm final success/failure audio, encouragement/Minik art, and visual polish through the shared B6/B7/L2 systems instead of adding a C2-only feedback stack.
- Complete native-language review of catalog fallback values.
