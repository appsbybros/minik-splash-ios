# Minik Math visual consistency

## Authority and scope

There is no Android Math product, so this pass does not claim Android parity and does not copy Language mechanics as a Math specification. It audits all 13 established iOS Math identities against the shared Minik visual system and representative low/mid/high content at M1, M5, and M10. Mathematical representations, curriculum, correctness, progression, rewards, and telemetry are unchanged.

The machine-readable activity-by-activity record is `docs/math-visual-consistency.tsv`. Every row remains `static_consistent_runtime_pending`; this is not a Simulator/device result.

## Shared visual boundary

- Educational screens use the dedicated `math_frame_background`, shared light/white `MinikPracticeSurface`, branded close control, and consistent responsive spacing.
- Replay on specialized count, structured, fraction, number-line, and Math Cards screens now uses the owned Minik speaker artwork instead of an SF speaker substitute. Functional controls without an owned semantic equivalent retain native symbols.
- Graded shared and specialized screens use the same owned Minik success/try-again reactions.
- Typed quantities, place value, equal groups, fractions, number lines, percent, ratio, probability, and geometry remain primary; decoration does not replace mathematical evidence.
- Math expressions and spatial mathematical controls remain LTR under RTL interface locales.
- Child-facing levels remain Level 1 through Level 10. Math configuration has no learned-language state.
- Ping Pong remains the 13th canonical identity and a non-curriculum game with its dedicated arena; serve feel still requires runtime confirmation.

## Validation boundary

Windows source/static audits cover identity completeness, M1/M5/M10 representative routing, all M1-M10 factories, shared surfaces, branded controls, feedback art, LTR contracts, and Math resource validation. Xcode, XCTest, Simulator/device layout, Dynamic Type, VoiceOver/Switch Control, interaction feel, animation, audible speech, performance, and independent visual review remain pending.
