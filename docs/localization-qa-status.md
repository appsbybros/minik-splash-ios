# Localization QA status

Status as of 2026-09-02. The deterministic source audit reports zero likely user-visible hardcoded strings, zero missing catalog keys, and zero catalog errors. Both catalogs contain 286 keys. The full catalog has 11 locales; English Only has the same keys in 10 locales and intentionally excludes Hebrew.

`translated` below means the 29 shared strings whose existing translations are retained from verified Android copy. `Pending native QA` identifies Math/iOS-only catalog entries that currently retain the English source as an explicit fallback; it does not claim linguistic completion.

| Locale | Total keys | Android-verified | Math/iOS-only pending native QA | English fallback remaining | Blocker |
|---|---:|---:|---:|---:|---|
| English (`en`) | 286 | 29 shared keys | 0 | 0 | Source locale; product copy review still applies |
| Amharic (`am`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |
| Arabic (`ar`) | 286 | 29 | 257 | 257 | Native-language translation, RTL, and in-context QA |
| German (`de`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |
| Spanish (`es`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |
| French (`fr`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |
| Hebrew (`he`) | 286 | 29 | 257 | 257 | Full product only; native-language translation, RTL, and in-context QA |
| Dutch (`nl`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |
| Brazilian Portuguese (`pt-BR`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |
| European Portuguese (`pt-PT`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |
| Russian (`ru`) | 286 | 29 | 257 | 257 | Native-language translation and in-context QA |

M4 through M10 introduced no new localization keys: they reuse typed math representations and existing localized shared activity copy. M8 adds native percent-bar and ratio-group visuals; M9 adds typed pre-algebra forms and signed-number placement; M10 adds typed algebraic relationships plus native probability and geometry diagrams while retaining existing localized shared copy and accessibility formats. Native linguistic review, Xcode String Catalog compilation, layout checks, VoiceOver, and RTL verification remain macOS/device gates.
