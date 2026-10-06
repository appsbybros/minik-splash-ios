# Product Architecture

## Shared product model

Minik has two primary product outcomes:

- **Minik language learning:** Supports English and Hebrew learning initially. Current iOS target and code names may still say `MinikPlus`; they are not renamed as part of this architecture clarification.
- **Minik Math:** Math product with no learned-language selection.

**Minik Plus English / English Only** is a product-policy variant of the language application. It fixes English as the learned language but does not form a third independent application architecture or justify duplicated engines and UI.

One shared native Swift/SwiftUI codebase serves these outcomes. Targets select a central product configuration instead of duplicating source code or distributing behavior across unrelated flags. Math and Language share the application shell and activity mechanics where useful, while product-specific activities remain valid. Shared code must not force Math into language-specific concepts.

User-visible levels and internal curriculum stages do not need to be identical.

## Android reference and native iOS precedence

Android is the behavioral, content, and product reference for Minik. Preserve its educational intent, content and semantic contracts, simplicity, professional child-facing character, recognizable product identity, and proven game mechanics where appropriate.

When an Android UI, presentation, navigation, or interaction implementation conflicts with a clearly better native iOS/iPadOS convention, the native Apple approach takes precedence. A material deviation must have a concrete platform reason, such as native navigation or presentation, adaptive iPhone/iPad layout, accessibility, Dynamic Type, safe areas, platform lifecycle, native controls, gestures or input, or RTL behavior. This rule does not permit arbitrary redesign, and visual convention must not change educational correctness or product contracts.

Confirmed intended behavior in `android-known-fixes.md` always takes precedence over bugs in the Android reference snapshot.

## Two independent language axes

The architecture treats these as separate concerns:

1. **Interface locale** is the language in which menus, settings, labels, buttons, instructions, and messages communicate with the user.
2. **Learned language** is the language being taught to the child.

A locale present in vocabulary, `words.xml`, audio, or other learning content is not by itself an interface locale.

Current learned-language policy is:

- Minik Plus allows English and Hebrew; no default learned language is decided here.
- Minik Plus English allows only English, fixes English as the learned language, and resolves stored Hebrew or any unsupported learned language to English.
- Minik Math has no learned-language selection and resolves learned-language state to none.

Learned languages use locale-based identifiers so future languages can be added without changing the core product-variant type. Adding a learned language should primarily add catalog/content when existing capabilities are sufficient, but genuinely new linguistic capabilities may require implementation work.

## Verified Android interface-localization inventory

The Android reference has one shared app resource source set for all flavors. The app-facing locale enum and selectors contain exactly the following supported interface choices (`android/app/src/main/java/com/minik/minik/managers/UserLanguageManager.kt` and both selector lists in `android/app/src/main/java/com/minik/minik/fragments/IntroScreen.kt` and `LanguagesAndLevelsDialogFragment.kt`):

| Interface locale | Android qualifier/tag | Main app strings |
| --- | --- | --- |
| English | unqualified default, selected as `en` | `android/app/src/main/res/values/strings.xml` |
| Amharic | `am` | `android/app/src/main/res/values-am/strings.xml` |
| Arabic | `ar` | `android/app/src/main/res/values-ar/strings.xml` |
| German | `de` | `android/app/src/main/res/values-de/strings.xml` |
| Spanish | `es` | `android/app/src/main/res/values-es/strings.xml` |
| French | `fr` | `android/app/src/main/res/values-fr/strings.xml` |
| Hebrew | `he`; legacy alias `iw` | `android/app/src/main/res/values-he/strings.xml`; `android/app/src/main/res/values-iw/strings.xml` |
| Dutch | `nl` | `android/app/src/main/res/values-nl/strings.xml` |
| Portuguese (Brazil) | `pt-BR`, qualifier `pt-rBR` | `android/app/src/main/res/values-pt-rBR/strings.xml` |
| Portuguese (Portugal) | `pt-PT`, qualifier `pt-rPT` | `android/app/src/main/res/values-pt-rPT/strings.xml` |
| Russian | `ru` | `android/app/src/main/res/values-ru/strings.xml` |

This inventory is based on actual UI translations and the selectable hosting/interface-language lists, not learning-content filenames. The manifest declares RTL support in `android/app/src/main/AndroidManifest.xml`; there is no explicit Android locale-config resource in the snapshot.

The app directly includes `appupdatelib`, `userengagementlib`, `subscriptionlib`, and `sharedmoduleslib` in `android/app/build.gradle.kts`. Their strings are user-visible update, rating, subscription, and shared-service copy. Each library has localized `strings.xml` under:

- `<module>/src/main/res/values-{ar,de,es,fr,he,hi,id,in,iw,ja,ko,nl,ru,zh}/strings.xml`, plus unqualified English defaults;
- where `<module>` is `appupdatelib`, `userengagementlib`, `subscriptionlib`, or `sharedmoduleslib`.

Hindi (`hi`), Indonesian (`id` and legacy `in`), Japanese (`ja`), Korean (`ko`), and Chinese (`zh`) therefore exist only as partial shared-library translations. They are not present in the main app UI strings, `LanguagesEnum`, or the app-language selectors and are not counted as supported Minik interface locales. Conversely, the shared libraries have no Amharic or Portuguese locale directories, so their user-visible copy falls back to their default strings for those otherwise supported app locales.

### Android flavor behavior

All five Android flavors use the same main localization resources: `standard`, `standard-english-only`, `games`, `plus`, and `plus-english-only` are declared in `android/app/build.gradle.kts`; no flavor-specific string source set changes the locale inventory.

The two `ENGLISH_ONLY` flavors do not literally restrict the whole interface to English. In `LanguagesAndLevelsDialogFragment.kt`, they remove Hebrew from the interface-language choices while leaving English, Spanish, French, Russian, Arabic, Dutch, German, both Portuguese variants, and Amharic selectable. They also hide learned-language selection. If the dialog observes Hebrew as the actual/saved interface language, it applies English. Thus the verified product policy relevant to Minik Plus English is: English is the fixed **learned** language, while Hebrew is specifically excluded as an **interface** locale even though other translated interface locales remain available.

The Hebrew resources are still packaged from the shared `main` source set. Startup handling in `MainActivity.kt` does not independently apply the English-only Hebrew exclusion; the explicit correction is in the language dialog. The iOS architecture should preserve the confirmed exclusion policy, not this enforcement gap.

## iOS localization architecture

Interface localization is resource-driven. iOS should use Apple-native localization resources, preferably String Catalogs (`.xcstrings`), when localization implementation begins. Adding an ordinary interface translation should require adding or updating localization resources, not changing activity-engine logic.

Activity engines must not hard-code the ordinary interface-locale set. Central product policy may exclude an otherwise available locale where intentionally required; Minik Plus English’s verified exclusion of Hebrew interface localization is such a product-level rule. No translations beyond the verified inventory are assumed complete.

UI strings and educational content remain separate resource concepts. A translated button label does not define learned content, and a vocabulary translation does not make the surrounding interface localized.

## Directionality contract

RTL/LTR behavior is a first-class requirement. Hebrew and Arabic are already supported RTL interface locales in the verified Android inventory.

- Interface direction and learning-content direction are independent.
- Normal UI layout uses semantic leading/trailing behavior rather than assuming physical left/right.
- A Hebrew UI may show English learned content that remains LTR.
- An English, Spanish, or other UI may show Hebrew learned content that remains RTL.
- Mathematical expressions such as `8 + 5 = 13` must not reverse merely because the interface is RTL.
- Textual learning representations carry sufficient locale/direction metadata; activity engines do not infer their direction from the interface locale.
- Build and letter/token ordering follows the learned content, not the app UI direction.
- Images and other non-directional representations do not receive unnecessary direction metadata.

This is a responsibility boundary, not a commitment to a large custom bidirectional-text framework.

## Localized copy and layout

Child-facing game copy should be concise by design. Long instructions should be avoided when a short equivalent communicates the same action.

Layouts must not assume English string width. Translated sentence fragments must not be concatenated; use complete localized messages with placeholders where needed. Compact alternative strings may exist for genuinely constrained UI, but must not become a workaround for poor layout.

Dynamic Type and localization-safe layouts must be considered when UI implementation begins. No arbitrary fixed character limits are defined at this stage.

## Math curriculum direction

The current conceptual progression is:

- **M1 — Number represents quantity:** counting, cardinality, and matching numerals to quantities.
- **M2 — Numbers compose/decompose; early operations:** parts and wholes, early addition and subtraction.
- **M3 — Operations and relationships between expressions:** operation meaning and relationships among expressions.
- **M4 — Place value / numbers to 100 / richer addition-subtraction:** tens and ones with broader addition and subtraction.
- **M5 — Meaning of multiplication and division:** equal groups, arrays, sharing, and grouping.
- **M6 — Fluency, factors/multiples, initial fraction relationships:** operational fluency and early multiplicative/fraction connections.
- **M7 — Fractions and decimals as numbers:** magnitude, number-line placement, comparison, and equivalence.
- **M8 — Fraction/decimal/percent/ratio relationships:** translating and reasoning across related forms.
- **M9 — Pre-algebra:** negatives, order of operations, powers, ratios, and simple equations.
- **M10 — Algebraic relationships:** linear equations, proportional reasoning, and introductory probability/geometry concepts.

Language and Math have independent curriculum-level systems. Minik Language currently uses five vocabulary content levels, A–E. Minik Math is intended to have ten distinct curriculum levels, M1–M10. There is no A–E mapping for Math and no requirement that the two products expose the same number of levels; they share reusable activity infrastructure, not curriculum-level identity or count.

One Math curriculum policy owns the stable level identities, user-facing level metadata, planned availability, and activity capabilities. The hub and development selector iterate the runnable descriptors supplied by that policy rather than owning a fixed level list or using array indexes as identity. Selection is manual; performance-driven or adaptive progression is separate future work.

The currently runnable routing slice is M1–M3, but M1 and M2 still have curriculum-parity blockers. M1 uses quantity-to-number content across Learn, Choose, Tower, Pairs, Memory, and Soccer. Build remains blocked until the product defines an ordered construction interaction that genuinely practices the quantity-to-numeral relationship. M2 routes all seven activity families, but only Learn, Choose, Build, and Soccer currently practice addition. Tower currently orders direct numbers, while Pairs and Memory match a number with a visual quantity. Making those three activities genuinely Level-2-specific requires an approved definition of the Level 2 ordering representations and equivalence relationships—such as how composition, decomposition, or early operations should appear in each mechanic—plus their numeric and difficulty rules. M3 has provider-backed operations-and-relationships content across all seven activities: missing-addend study and answer tasks, expression construction, ordering expressions by typed numeric value, and matching equivalent direct-number/arithmetic representations. M4–M10 are recognized planned identities but have no sessions, aliases, fallback content, or placeholder activities until their distinct curricula are implemented.

Age associations are approximate guidance only. A level is a capability range, not a hard age or grade assignment. The ten-level progression is the current product plan, but identity types, views, storage, and shared activity engines must remain extensible rather than assuming that every product—or Math forever—has exactly ten levels.
