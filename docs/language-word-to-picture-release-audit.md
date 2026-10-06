# C6 Word-to-Picture Release Audit

Status: Windows-static audit complete. Apple-platform compilation, XCTest, visual, speech, and accessibility validation remain pending.

## Android authority inspected

- `WriteScreen.kt` with `Screen.SELECT_FROM_PICTURES` presents the learned word and four image-ready choices from the same vocabulary category.
- The Android menu routes this practice independently from Picture-to-Word; ordinary word mode uses full learned-word identity rather than first-letter identity.
- A wrong choice disables input, shows try-again feedback for 1.5 seconds, resets the same choices, and permits a retry. A correct choice advances after feedback.
- The current learned word is spoken on presentation/replay. Pictured choices correspond to learned vocabulary words.
- `01-language-word-to-picture-pea.png` is the visual reference: Minik frame, one white practice surface, branded close/replay, concise instruction, prominent word, and a two-column picture grid.

`docs/android-known-fixes.md` contains no superseding C6 correction.

## iOS contract verified or corrected

- `LanguageWordContentProvider` requires an allowed Language product/language, a real vocabulary stage, word-image-association skill, single-choice interaction, and 2...4 choices (four by default).
- The prompt is exactly one English LTR or Hebrew RTL learned word and retains the approved speech override metadata.
- Every choice is a distinct image-ready item from the prompt category, carries its actual learned-word speech cue, and has a stable vocabulary identity. Exactly one identity matches the prompt.
- `LanguageActivitySessionFactory` supplies six challenges with `retryUntilCorrect`, matching the shared 1.5-second wrong-answer reset.
- C6 now selects an explicit `wordToPicture` presentation. It uses the localized “Find the picture for the word” instruction while retaining the shared Minik background, white panel, close art, branded replay, adaptive picture grid, feedback, and Reduce Motion behavior.
- Every pictured choice's VoiceOver label resolves to the actual learned word rather than generic “Educational image” copy; the prompt keeps its visible learned-word label and direction.
- C6 progress records the stable expected vocabulary-word ID, while the random challenge UUID remains the presentation identity. Retry indices continue within that presentation and reset on advance.
- Prompt replay and picture selection use learned-language speech. Speech stops for inactive scene, disappearance, or exit; no Math speech or Math progress fields are introduced.

## Deterministic evidence

Existing provider tests cover learned-word prompt/image choices, exact identity, same-category choices, English/Hebrew direction, approved speech correction, 2...4 counts, request rejection, and product policy.

This audit adds coverage for:

- English/Hebrew prompt text and speech resolving to the expected vocabulary item;
- every picture choice exposing learned-word speech/accessibility metadata;
- expected answer and stable progress resolving to the same vocabulary ID, distinct from the presentation UUID;
- six-challenge factory construction and retry-until-correct reset of the same presentation.

## Remaining release gates

- Compile all four products and execute ProductConfigurationTests on macOS/Xcode.
- Confirm word sizing, picture grid, instruction, feedback, and Minik shell at compact iPhone, iPad, landscape, and accessibility Dynamic Type sizes.
- Confirm VoiceOver announces the learned-word prompt and actual pictured words without duplicate generic image copy.
- Confirm real English/Hebrew prompt/selection speech, replay, interruption, background cancellation, and mixed RTL/LTR presentation.
- Obtain native-language review of catalog translations; fallback entries are not claimed as linguistically reviewed.

No GitHub Actions workflow was triggered by this audit.
