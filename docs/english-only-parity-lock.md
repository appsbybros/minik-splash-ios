# English Only localization and visual parity lock

## Windows-static result

The English Only catalog has exact key parity with the All catalog at 469 keys and contains exactly 10 interface locales: Amharic, Arabic, Dutch, English, French, German, Russian, Spanish, Brazilian Portuguese, and European Portuguese. Hebrew is absent as an interface locale and fixed-English product policy prevents Hebrew learned-language state. Counts describe the current validated catalogs, not a promise that keys will never be added.

The following is source/static evidence only. Xcode, XCTest, Simulator/device, speech, accessibility, RTL, performance, visual, and independent linguistic validation remain pending.

## Surface lock

| Surface | Static lock | Runtime gate |
|---|---|---|
| Home | Same 13 production identities as MinikPlus; fixed-English artwork mapping; no learned-language selector | Confirm every card, crop, route, and iPhone/iPad layout |
| Parent Area | English shown as read-only learned language; 10-locale interface picker excludes Hebrew | Confirm stale-state fallback, picker options, and spoken interface copy |
| Learn | English/LTR typed content and original English Learn artwork | Confirm all cards, examples, replay, and looping |
| Letter Pairs | English typed word/letter speech and original Pairs art | Confirm any-two interaction, speech, layout, and feedback |
| Word Cards | English typed content with original Cards background/mascot | Confirm manual/timed flow, crop, replay, and lifecycle |
| Soccer | English tokens/speech with localized tap instructions and original field/goal/goalkeeper/ball | Confirm introduction persistence, speech, tap controls, shot timing, and scoring |
| Tower | English tokens/speech with original sand/gift-mascot/beach composition | Confirm base lock, drag/tap accessibility, growth, speech, and layout |
| Picture Memory | English reveal speech, original mascot placement, blank card backs | Confirm reveal timing, pair identity, speech, and responsive grid |
| Tic-Tac-Toe | Same ungraded game, exact mascot, hidden cumulative score | Confirm levels/AI, no visible score, feedback/audio, and composition |

## Direction and translation boundary

Arabic may set the interface environment to RTL, but every English learned-text representation carries explicit LTR metadata and learned speech remains English. Interface strings may be localized into the selected allowed locale; learned English words, letters, and speech are never translated into the interface language.
