# Minik Plus English production policy

## Windows-static result

MinikPlusEnglish retains the exact 13 child-visible Language activities and their C1-C14 routes while fixing the learned language to English. It is a Language product-policy variant, not a separate activity architecture. This result is source/static only; Xcode, XCTest, Simulator/device, speech, accessibility, RTL, performance, visual, and linguistic validation remain pending.

## Locked boundaries

- `ProductConfiguration` permits only English, resolves missing or stale Hebrew learned-language state to English, and disables learned-language selection.
- The child-facing Home has no learned-language selector. Parent Area shows English as a read-only learned-language value and retains the independent interface-language control.
- The interface locale policy retains English, Amharic, Arabic, German, Spanish, French, Dutch, Brazilian Portuguese, European Portuguese, and Russian. Hebrew is excluded and stale Hebrew interface state resolves to English.
- The target packages the English Only localization catalog and Language image/vocabulary resources. It does not package Math-object or Ping Pong resources.
- All 13 routes match MinikPlus, generic engine identities stay off the production menu, and Math/Ping Pong sections remain absent.
- Home artwork is resolved with fixed English. Deterministic coverage rejects any English route that selects a Hebrew-specific artwork identifier.
- Learned text and learned speech retain typed English/LTR metadata. Interface narration continues to use the independently selected allowed interface locale.

## Runtime gates

- Compile MinikPlusEnglish and run ProductConfigurationTests on macOS.
- Confirm all 13 routes launch on iPhone/iPad without generic, Math, or Ping Pong leakage.
- Confirm Parent Area cannot change learned English and excludes Hebrew from interface choices.
- Confirm English learned speech in every speech-bearing activity while interface instructions follow each selected allowed locale.
- Confirm Arabic interface RTL keeps English learned content LTR.
- Complete independent visual, accessibility, and linguistic review.
