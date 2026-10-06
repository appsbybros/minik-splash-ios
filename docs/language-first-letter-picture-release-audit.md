# C4 First Letter Letter-to-Picture Release Audit

Status: Windows-static audit complete. Apple-platform compilation, XCTest, visual, speech, and accessibility validation remain pending.

## Android authority inspected

- `WriteScreen.kt` in `lettersMode` with `Screen.SELECT_FROM_PICTURES` presents the localized reverse instruction, a learned-language initial, and four pictured vocabulary choices.
- `getCategoryWordsForQuestion` requires image-bearing same-category candidates, removes candidates sharing the correct initial, and keeps one picture per distinct distractor initial.
- A wrong selection disables input, shows try-again feedback for 1.5 seconds, resets the same choices, and permits a retry. A correct selection advances after feedback.
- The prompt letter is spoken in the learned language. Image choices carry their learned words for speech.
- `04-language-first-letter-letter-to-picture.png` is the visual reference: Minik frame, one white practice surface, branded close/replay, concise instruction, prominent initial, and a two-column picture grid.

`docs/android-known-fixes.md` contains no superseding C4 correction.

## iOS contract verified or corrected

- `LanguageFirstLetterPictureContentProvider` requires the Language product, allowed learned language, Level A word stage, initial-letter skill, single-choice interaction, and 2...4 image choices (four by default).
- The prompt is exactly one learned-language initial with explicit English LTR or Hebrew RTL metadata and typed speech.
- Every choice is a unique image-ready vocabulary item from the prompt's category. Choice initials are distinct and exactly one matches the prompt initial.
- Choice speech uses the actual pictured learned word. Correctness uses the stable initial concept and never image position.
- `LanguageActivitySessionFactory` supplies six challenges with `retryUntilCorrect`, matching the shared 1.5-second wrong-answer reset.
- C4 now selects an explicit `firstLetterLetterToPicture` presentation. It uses the localized “Match the first sound to a picture” instruction while retaining the shared Minik background, white panel, close art, branded replay, adaptive two-column-capable grid, feedback, and Reduce Motion behavior.
- Every pictured choice's VoiceOver label resolves to its learned word rather than generic “Educational image” copy; selection-result feedback remains in the button hint.
- C4 progress records the stable expected initial concept as `ActivityItemID`, while the random challenge UUID remains the presentation identity. Retry indices remain local to that presentation and reset on advance.
- Speech stops when the scene becomes inactive, the view disappears, or the activity exits. No Math speech or Math progress fields are introduced.

## Deterministic evidence

Existing provider tests cover request rejection, English/Hebrew prompt metadata, prompt-to-picture semantic mapping, image readiness, same-category and distinct-initial distractors, exact correctness after reordering, unique presentation IDs, and product variants.

This audit adds coverage for:

- every English/Hebrew image choice carrying its pictured learned word speech cue;
- stable semantic progress identity distinct from the challenge instance UUID;
- six-challenge factory construction and retry-until-correct reset of the same presentation.

## Remaining release gates

- Compile all four products and execute ProductConfigurationTests on macOS/Xcode.
- Confirm initial sizing, image grid, instruction, feedback, and Minik shell at compact iPhone, iPad, landscape, and accessibility Dynamic Type sizes.
- Confirm VoiceOver announces the prompt initial and actual pictured learned words without duplicate generic image copy.
- Confirm real English/Hebrew speech, replay, selection speech, interruption, background cancellation, and mixed RTL/LTR presentation.
- Obtain native-language review of catalog translations; fallback entries are not claimed as linguistically reviewed.

No GitHub Actions workflow was triggered by this audit.
