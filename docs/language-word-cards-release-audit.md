# C9 Language Word Cards Release Audit

Status: Windows-static implementation and source audit complete. Apple-platform compilation, visual, speech, accessibility, timing, and interaction validation remain pending.

## Android authority inspected

- `RandomWordCardsFragment.kt` loads distinct lexical words for the learner's current level, presents one shuffled bag without duplicates, prevents the last word of one bag from immediately opening the next, speaks every displayed word, and accepts either a whole-screen tap or a length-based timeout as the next-card action.
- `fragment_random_word_cards.xml` uses the dedicated `cards_background`, Minik Plus logo, branded close control, centered Cards title, white gradient-border word card, tap hint, and `pairs_image` mascot. The screenshot `docs/reference/android-ui/05-language-word-cards-corn.png` confirms that recognizable composition.
- Android requests `alsoLoadPicture = false`; the production card is intentionally learned text only. No image was invented for iOS.

`docs/android-known-fixes.md` contains no superseding C9 correction.

## iOS contract verified or corrected

- `CardsView` now consumes the original sky/meadow background and Android mascot, with adaptive logo, title, branded close/replay controls, centered white word card, source-matched purple/pink/cyan border, blue/teal/green word treatment, and the existing tap hint.
- Manual card tap, background tap, and the cancellable 4.5-to-11-second length-based automatic advance all converge on the same `advance()` boundary. A card change cancels the prior pending task.
- `CardsSession` remains a continuous shuffled-bag session: every stable `StudyCardID` appears once per cycle and a multi-card cycle never repeats its prior final card immediately.
- Cards remain non-graded. There is no attempt callback, fake completion, score, or progress-pill UI.
- The learned language, direction, and corrected speech text stay in `LearningTextRepresentation`. Speech plays once for each presentation, replay is explicit, and exit/background/dismissal stop it.
- MinikPlus supports English and Hebrew; MinikPlusEnglish remains English-only; Math never routes into this Language view.

## Deterministic evidence

Existing `CardsSessionTests` cover empty/duplicate rejection, exactly-once cycle identity, sequential advance, safe one-card looping, and no immediate cross-cycle repeat. `LanguageWordCardsContentProviderTests` cover lexical-only content, all vocabulary levels, stable IDs, English/Hebrew direction and speech metadata, duplicate-word removal, category behavior, and product policy.

The focused C9 source audit additionally rejects the generic practice shell and any `onAttempt` progress boundary while requiring the exact visual, navigation, timing, lifecycle, content, and test contracts above.

## Remaining release gates

- Compile all four products and execute ProductConfigurationTests on macOS/Xcode.
- Confirm background crop, logo/title/card/mascot balance, long and multiword text fit, compact iPhone, landscape, iPad, and all Dynamic Type sizes.
- Confirm manual-versus-timeout cancellation never double-advances, repeated cycles remain continuous, and Reduce Motion removes the card transition.
- Confirm real English/Hebrew speech, replay, interruption, background cancellation, mixed RTL/LTR layout, VoiceOver order/labels, keyboard, and Switch Control.
- Obtain native-language review of catalog translations; fallback values are not claimed as linguistically reviewed.

No GitHub Actions workflow was triggered by this audit.
