# C5 Picture-to-Word Release Audit

Status: Windows-static audit complete. Apple-platform compilation, XCTest, visual, speech, and accessibility validation remain pending.

## Android authority inspected

- `WriteScreen.kt` with `Screen.SELECT_FROM_TEXT_OPTIONS` presents an image-ready current word and four text choices from the same vocabulary category.
- The Android menu routes this practice independently from Word-to-Picture; ordinary word mode uses full learned words rather than initial-letter semantics.
- A wrong choice disables input, shows try-again feedback for 1.5 seconds, resets the same choices, and permits a retry. A correct choice advances after feedback.
- The current learned word is spoken on presentation/replay, and text choices are learned-language words.
- `02-language-picture-to-word-pig.png` is the visual reference: Minik frame, one white practice surface, branded close/replay, concise instruction, a large picture, and four high-contrast word controls.

`docs/android-known-fixes.md` contains no superseding C5 correction.

## iOS contract verified or corrected

- `LanguageWordContentProvider` requires an allowed Language product/language, a real vocabulary stage, word-recognition skill, single-choice interaction, and 2...4 choices (four by default).
- The prompt is exactly one image-ready vocabulary asset. Its typed speech cue is the pictured learned word, including the approved Hebrew Kiwi speech override.
- All choices are distinct learned-language words from the prompt category with explicit English LTR or Hebrew RTL metadata. Exactly one stable word identity matches the pictured prompt.
- `LanguageActivitySessionFactory` supplies six challenges with `retryUntilCorrect`, matching the shared 1.5-second wrong-answer reset.
- C5 now selects an explicit `pictureToWord` presentation. It uses the localized “Find the word for the picture” instruction while retaining the shared Minik background, white panel, close art, branded replay, adaptive word controls, feedback, and Reduce Motion behavior.
- The pictured prompt's VoiceOver label resolves to the actual learned word rather than generic “Educational image” copy. Word controls retain their visible learned-word labels and selection-result hints.
- C5 progress records the stable expected vocabulary-word ID, while the random challenge UUID remains the presentation identity. Retry attempt indices continue within that presentation and reset on advance.
- Prompt replay and choice selection use learned-language speech. Speech stops for inactive scene, disappearance, or exit; no Math speech or Math progress fields are introduced.

## Deterministic evidence

Existing provider tests cover vocabulary source order, image prompt/word choices, exact identity, English/Hebrew direction, approved speech correction, 2...4 counts, request rejection, same prompt/answer item, same-category identity, and product policy.

This audit adds coverage for:

- English/Hebrew prompt speech and selectable-word speech availability;
- prompt image, expected answer, and stable progress all resolving to the same vocabulary item;
- semantic progress identity remaining distinct from the presentation UUID;
- six-challenge factory construction and retry-until-correct reset of the same presentation.

## Remaining release gates

- Compile all four products and execute ProductConfigurationTests on macOS/Xcode.
- Confirm image sizing, long-word controls, instruction, feedback, and Minik shell at compact iPhone, iPad, landscape, and accessibility Dynamic Type sizes.
- Confirm VoiceOver announces the actual pictured word and readable word choices without duplicate generic image copy.
- Confirm real English/Hebrew prompt/selection speech, replay, interruption, background cancellation, and mixed RTL/LTR presentation.
- Obtain native-language review of catalog translations; fallback entries are not claimed as linguistically reviewed.

No GitHub Actions workflow was triggered by this audit.
