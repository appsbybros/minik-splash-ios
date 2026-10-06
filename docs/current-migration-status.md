# Current Migration Status

Status date: 2026-08-28. This resume note reflects the inspected repository rather than any historical phase label.

## Product and architecture

- The two primary outcomes are Minik language learning and Minik Math. `MinikPlus` remains the current language target/code name; no rename has been performed.
- Minik Plus English is a language-product policy variant with English fixed as the learned language, not a separate application architecture.
- `project.yml` defines one iOS 17 Swift/SwiftUI source base for iPhone and iPad, with `MinikPlus`, `MinikPlusEnglish`, and `MinikMath` targets selected through central `ProductConfiguration` policy.
- Language and Math share semantic content contracts and the reusable Learn, Multiple Choice, Build, Pairs, and Memory engines. Cards is currently language-facing; Tower and Soccer are currently Math-facing.
- Android remains the behavioral/content/product reference, but a concretely better native iOS/iPadOS convention takes precedence for presentation and interaction. Educational contracts are unchanged by that rule.

## Language activities already present

- The activity hub currently exposes letter Learn, Choose, Build, Pairs, and Memory plus word First Letter, Picture Starters, Word Build, Letter Pairs, Picture to Word, Word to Picture, Word Memory, and Word Cards.
- `LanguageActivitySessionFactory` connects those routes to shared session/view engines.
- Catalog-driven providers are present for alphabet Learn, multiple choice, build, matching, first-letter choice and picture activities, word choice, word build, letter pairs, word memory, and word cards.
- The normalized vocabulary loader validates and joins the packaged XML and image manifest into the runtime word catalog.

## Math state

- The Math hub currently exposes Learn, Choose, Build, Tower, Pairs, Memory, and Soccer through the same reusable activity UI where appropriate.
- `MathContentProvider` generates quantity, addition/subtraction, missing-addend, ordering, and equivalence content and supplies the specialized comparable, build, and soccer contracts.
- Current factory routes are an initial M1 quantity and M2 practice slice. Although the provider includes some M3 generation support and the architecture documents a provisional M1-M10 direction, the complete Math curriculum, adaptive orchestration, progress/persistence, and all later-stage content are not implemented.

## Vocabulary normalization

- Validation reports 1,270 generated entries across 142 arrays and 46 normalized categories: 955 lexical entries and 315 sentences.
- Final lexical counts are A 181, B 192, C 241, D 162, and E 179. Sentence counts are A 0, B 6, C 9, D 100, and E 200.
- Stable-key, schema, Unicode, collision, and XML/manifest metadata checks pass in `words-normalized-validation.txt`.
- Canonical docs and packaged runtime copies of both `words-normalized.xml` and `vocabulary-image-manifest.tsv` are byte-identical at this inspection.

## Image readiness and migration

- The manifest has 543 image-capable items: 12 `reuse_ios`, 397 `migrate_android`, 33 `trusted_acquire`, and 101 `create_new`.
- The 12 reusable assets are the only rows currently marked ready in iOS; 531 rows remain `missing_ios` by manifest lifecycle.
- All 397 Android migration rows resolve uniquely in `android/app/src/main/res/drawable`: 395 WebP and 2 PNG, with no missing, ambiguous, case-colliding, unsupported, vector, or XML assets.
- ImageMagick `7.1.2-29 Q16-HDRI x64` is available at `C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe`. Its format inventory reports WEBP read/write and PNG read/write support, and direct `identify` probes successfully decoded representative project WebP and PNG files.
- The 397 Android migrations have not been converted or added to the iOS asset catalog. No manifest lifecycle or resource files are changed here.
- Trusted acquisition and new image creation are intentionally later work.

## Reference correctness and working tree

- Always read `android-known-fixes.md` before reproducing Android behavior. Its intended behavior overrides the snapshot, currently including the Plus English learned-language initialization fix and Word Memory image-word pairing fix.
- The actual Git repository root is `ios/`; `C:\Projects\Minik` itself is not a Git repository.
- Before this documentation task, the iOS working tree contained one user-owned modification: `Tests/ProductConfigurationTests/LanguageWordContentProviderTests.swift`. It is preserved untouched.
- This task modifies `docs/product-architecture.md` and adds this status document inside the iOS repository. It also updates the workspace-level `AGENTS.md`, which is outside the iOS Git repository.

## Immediate blocker and next task

The earlier local-decoder blocker is cleared. The next implementation task is a separately authorized migration of the 397 resolved Android assets using the verified ImageMagick executable, followed by validation and manifest lifecycle updates. Do not start that migration merely from this resume note.

Still intentionally incomplete: the 397 Android asset conversions, the 33 trusted acquisitions, the 101 generated images, their manifest lifecycle updates, full production localization, persistence/adaptive progress, the full Math curriculum, and macOS/Xcode compilation and device validation.
