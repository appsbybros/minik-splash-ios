# Language Learn Letters release audit

Status: Windows-static audit completed on 2026-09-03; macOS and device validation remain required.

## Scope and authority

This audit compares the iOS Learn Letters path with the production Android `LearnScreen.kt`, its phone/tablet layouts, alphabet content, localized `from_the_beginning` values, and `docs/android-known-fixes.md`. It covers Minik Plus English/Hebrew and Minik Plus English Only. Android analytics implementation details are out of scope; Firebase, StoreKit, ads, and notifications were not started.

## Static parity findings

| Contract | Result |
| --- | --- |
| English sequence | 26 cards, A–Z, with every Android example word and illustration asset ID locked by deterministic tests. |
| Hebrew sequence | 22 standard letters followed by the five final forms, with all 27 Android example words, illustration IDs, and final-form speech text locked by tests. |
| Progression | Corrected: Language Learn now changes the final action to localized “Start over” and loops to the first card, matching Android. The shared Learn session keeps its existing complete-after-final default for non-Language clients. |
| Speech and replay | Existing automatic letter-then-word speech and explicit replay remain. Advancing, exiting, disappearing, or moving the app out of the active scene stops current speech. Final-form pronunciation metadata remains intact. |
| Product policy | Minik Plus supports English and Hebrew; English Only supports English and rejects Hebrew content. |
| Level/read-skill policy | Android Learn exposes the complete alphabet rather than filtering it by reading level. iOS preserves that instructional, non-graded behavior and does not emit mastery attempts. |
| Localization | “Start over” uses the reviewed Android translations in all 11 full locales and the 10 English Only locales. It is explicitly localized at the dynamic String boundary. |
| Responsive/RTL structure | The SwiftUI surface uses the shared adaptive practice layout, Dynamic Type-compatible text, semantic content-direction metadata, and Hebrew RTL metadata. Static review found no phone-only fixed frame or forced LTR behavior. |

## Asset review

All 53 word-illustration asset IDs referenced by the provider have tracked image sets and image files. Android also presents separate decorative lowercase/capital letter mascot art (106 source drawables across the English and Hebrew alphabets). Those decorative top-letter assets are not currently represented in the tracked iOS asset catalog; iOS renders the letter as native text. Resolving or explicitly approving that visual difference is still a visual parity/release blocker and was not folded into unrelated vocabulary-art work.

## Tests authored

- Language sessions use looping progression for Plus English, Plus Hebrew, and English Only English.
- A looping multi-card session returns from the final card to the first without completing.
- A one-card looping session remains valid and never completes.
- Every English and Hebrew example word and illustration ID matches the Android ordering.
- Existing coverage continues to lock counts, endpoints, representation ordering, speech metadata, directions, and learned-language policy.

## Remaining release gates

- Compile all products and execute `ProductConfigurationTests` once on macOS through a deliberate manual validation run.
- Exercise automatic speech, replay, rapid advance, exit, and background/foreground interruption with real voices.
- Inspect iPhone and iPad layouts at large accessibility text sizes.
- Run VoiceOver and mixed interface/content-language checks, especially Hebrew RTL content in both interface directions.
- Review all shipped translations with native speakers and do not treat unrelated fallback catalog entries as linguistically approved.
- Resolve or explicitly approve the missing decorative letter-mascot artwork difference.

This activity is therefore implementation-audited, not release-complete.
