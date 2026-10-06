# Language Picture Memory release audit

## Windows-static result

C12 is complete at Windows-static/source-audit level. Android `MemoryGameFragment.kt`, `fragment_memory_game.xml`, its strings, and `docs/reference/android-ui/10-language-picture-memory.png` were inspected read-only. No Xcode, XCTest, Simulator, device, VoiceOver, speech, or independent visual/linguistic validation is claimed.

Picture Memory remains a production Language Game and routes through the typed catalog-backed word-memory provider. The iOS composition uses the shared original Minik background and branded close, a framed surface, original Memory mascot, responsive grid, and blank Android-like gradient card backs. Face-down cards deliberately contain no generic symbol.

## Locked behavior

The provider creates six semantic vocabulary groups by default. Each group contains two identical image representations for one content item, while the session assigns the two physical cards distinct stable IDs. Matching is based on semantic group identity rather than representation equality, so identical artwork in different groups cannot falsely match.

An accepted reveal returns at most one learned-language speech cue. Duplicate taps, unknown cards, unavailable third selections, and matched cards return no cue; generic Math Memory remains silent when no reveal cues are supplied. Incorrect pairs return face down after continuation, correct pairs stay matched, and the final continuation completes safely.

The board uses available width and Dynamic Type to select adaptive iPhone/iPad columns, with a single-column accessibility threshold. Face-down, face-up, matched, unavailable, and already-matched states expose explicit labels, values, and hints. Backgrounding, dismissal, and explicit exit stop speech. Shared feedback and completion remain intact.

## Remaining runtime gates

- Compile all product targets and execute ProductConfigurationTests on macOS.
- Verify the Games menu grouping, original artwork, card proportions, grid density, and frame composition on compact iPhone and regular-width iPad.
- Verify Dynamic Type, VoiceOver reading order/state announcements, Switch Control, keyboard focus, and tap locking.
- Verify English/Hebrew reveal speech, exact-once audible behavior, RTL/LTR presentation, and background/exit cancellation.
- Verify feedback timing, continuous completion/return behavior, and independent visual and linguistic review.
