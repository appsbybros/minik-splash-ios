# C3 First Letter Picture-to-Letter Release Audit

Status: Windows-static audit complete. Apple-platform compilation, XCTest, visual, speech, and accessibility validation remain pending.

## Android authority inspected

- `WriteScreen.kt` in `lettersMode` with `Screen.SELECT_FROM_TEXT_OPTIONS` presents the localized picture-to-letter instruction, a pictured vocabulary word, and four initial-letter choices.
- `getCategoryWordsForQuestion` keeps distractors in the prompt category, removes the correct initial, and retains one word per distinct distractor initial.
- A wrong selection disables input, shows try-again feedback for 1.5 seconds, resets the same choices, and permits a retry. A correct selection advances after feedback.
- The learned word is spoken on presentation; a correct letter selection speaks the learned-language initial.
- `03-language-first-letter-picture-to-letter.png` is the visual reference: Minik frame, one white practice surface, branded close/replay, concise instruction, a large picture, and four high-contrast letter controls.

`docs/android-known-fixes.md` contains no superseding C3 correction.

## iOS contract verified or corrected

- `LanguageFirstLetterChoiceContentProvider` requires the Language product, allowed learned language, Level A word stage, initial-letter skill, single-choice interaction, and 2...4 choices (four by default).
- The prompt is exactly one image-ready vocabulary asset. Its typed speech cue contains the full learned word in English or Hebrew.
- Choices are one-character learned-language text with explicit language/direction metadata. The correct initial and all distractor initials are distinct; distractors come from the same category.
- Correctness uses the stable learned-language initial concept and never choice position. Each presentation still has a unique challenge/choice instance identity.
- `LanguageActivitySessionFactory` supplies six challenges with `retryUntilCorrect`, matching the 1.5-second wrong-answer reset already implemented by `MultipleChoiceView`.
- C3 now selects an explicit `firstLetterPictureToLetter` presentation. It uses the localized “Choose the starting letter” instruction instead of the generic multiple-choice instruction while retaining the shared Minik background, white panel, close art, branded replay, high-contrast adaptive controls, feedback, and Reduce Motion behavior.
- The pictured prompt's VoiceOver label resolves to the actual learned word rather than the generic “Educational image”. Letter choices retain their visible letter labels and selection-result hints.
- C3 progress records the stable expected initial concept as `ActivityItemID`; the random challenge UUID remains solely the presentation identity. Retry attempt indices continue within the same presentation and reset on the next challenge.
- Speech stops when the scene becomes inactive, the view disappears, or the activity exits. No Math speech or Math progress fields are introduced.

## Deterministic evidence

Existing provider tests cover request rejection, English/Hebrew policy, image readiness, 2...4 counts, single-character direction metadata, same-category and distinct-initial distractors, semantic correctness after reordering, repeated-word initial identity, unique presentation IDs, and product variants.

This audit adds coverage for:

- learned-word prompt speech in English and Hebrew;
- stable semantic progress identity distinct from the challenge instance UUID;
- six-challenge factory construction and retry-until-correct reset of the same presentation.

## Remaining release gates

- Compile all four products and execute ProductConfigurationTests on macOS/Xcode.
- Confirm the picture, instruction, letter controls, feedback, and Minik shell at compact iPhone, iPad, landscape, and accessibility Dynamic Type sizes.
- Confirm VoiceOver announces the actual pictured word and each learned-language letter without duplicate generic image copy.
- Confirm real English/Hebrew speech, replay, interruption, background cancellation, and mixed RTL/LTR presentation.
- Obtain native-language review of catalog translations; fallback entries are not claimed as linguistically reviewed.

No GitHub Actions workflow was triggered by this audit.
