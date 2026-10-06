# Math Object Art Requirements

Status: initial approved production pack integrated and used by the functional M1–M7 slices on 2026-09-02; macOS asset compilation and device-scale visual QA remain required.

## Integrated initial pack

`Resources/MathObjects.xcassets` contains 109 approved production image sets tracked by `Resources/MathObjectManifest.json`:

- 100 countable object themes: ten each in animals, everyday, food, fruits, nature, school, science-space, toys, treasures, and treats;
- three genuine zero-state scenes: basket, plate, and tray;
- six grouping supports: grouping basket, grouping tray, sorting ring, ten frame, two-compartment tray, and place-value organizer.

The MinikMath target alone receives the catalog and manifest. Production quantity rendering selects a single stable object theme per representation, repeats that object for the requested cardinality, keeps the semantic numeric value independent of artwork, and uses the manifest-provided empty scene for zero. M4 place-value and M5 equal-group renderers now use the approved organizer, tray, and ten-frame supports rather than unstructured high-cardinality piles. Dot/circle rendering remains a missing-resource/debug fallback, not normal MinikMath presentation.

## Original delivery contract

Provide isolated artwork of one clear, countable, child-friendly object per asset. Suitable themes may include fruit, sweets, toys, balls, stars, school objects, or nature objects; no single object type is mandated by product logic.

For an initial production pack, supply:

- 6–8 distinct single-object themes, enough to vary repeated 0–10 practice without changing its meaning;
- one neutral empty-container scene for each visual family that needs a zero state (at least basket/container and plate/tray variants);
- optional container/background elements that remain visually subordinate to the countable objects;
- no fraction or number-line art yet unless it is separately approved for a later curriculum level.

Each countable-object asset must:

- show exactly one isolated object;
- have a transparent or background-safe edge treatment;
- remain recognizable at approximately 36–64 points on a small iPhone;
- use a clear, visually distinct silhouette;
- contain no printed numeral, word, operator, brand, or other answer-revealing text;
- share a consistent child-friendly, polished art direction across the pack;
- avoid tiny decorative details that could be mistaken for additional countable objects;
- remain readable against light, darkened, turquoise, coral, and sky-toned activity surfaces.

Zero-state artwork must show a genuinely empty quantity scene. It must not contain the numeral `0`, a written hint, a faint object, or decorative items that a child could count.

## Delivery format

- Preferred working master: layered vector or high-resolution lossless raster with documented ownership/source.
- iOS handoff: transparent square PNG during review; final source format remains subject to the separate Xcode asset-format benchmark.
- Recommended raster master: at least 1024×1024 pixels, centered with safe padding and consistent optical scale.
- Keep one object per file; do not pre-compose quantities such as three or five objects.
- Use stable semantic names such as `math_object_<theme>_single` and `math_empty_<container>`.

## Review gate

The Windows validation script verifies manifest counts/categories, stable unique IDs, catalog JSON, and every referenced file. Remaining review: compile the asset catalog with Xcode, inspect representative 36–64 point rendering on iPhone/iPad, verify optical scale and contrast, and exercise zero/place-value/equal-group layouts with VoiceOver and Dynamic Type. M6–M7 fraction bars and M7 number lines are mathematically exact native SwiftUI geometry and require no decorative image asset. Later mathematical representations should likewise prefer native geometry; no additional final decorative art requirement is currently identified.
