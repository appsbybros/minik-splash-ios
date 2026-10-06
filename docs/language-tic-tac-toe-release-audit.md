# Language Tic-Tac-Toe release audit

## Windows-static result

C13's bounded reconstruction is complete at Windows-static/source-audit level. The complete Android `TicTacToeFragment.kt`, all four phone/sw600dp regular/Plus layouts, game/AI and reset paths, strings, dimensions/colors, sounds, animations, lifecycle cleanup, referenced assets, and `docs/reference/android-ui/12-tic-tac-toe.png` were inspected read-only. No Xcode, XCTest, Simulator, device, VoiceOver, speech/audio, or independent visual/linguistic validation is claimed.

The dedicated iOS screen now carries the exact decoded Android pastel scene and `minik_plus_with_tic_tac_toe.webp` board-holding mascot—not the prior dab substitute. Its inside branded close, blue/teal/green localized title, X/O choice, status, white 3x3 cells, and purple/pink/teal gradient edges reproduce the Android composition without generic practice-card chrome. The complete game fits ordinary phones without a `ScrollView`; short-height and accessibility-size layouts alone use a deliberate fallback. Cumulative scores remain an internal session invariant and are deliberately not rendered in the child-facing game.

## Locked behavior

The child starts every round and defaults to X. X/O may change only before the first move, locks during a round, and remains selected while unlocking when the next round resets. A/B/C/D/E/Random/Adaptive levels remain modeled, Adaptive remains the persisted default, Easy remains random, Medium retains Android tactical probabilities and win/block/center/corner/edge priority, and Hard retains minimax. The documented Android production mismatch—Adaptive reads adaptive state while Random updates it—remains isolated by compatibility policy and deterministic coverage.

Rounds continue automatically after 5.5 seconds for a child win and 4 seconds for a loss/draw while hidden cumulative child/Minik game scores remain in the session and survive reset. Child and AI moves resolve synchronously in one session mutation, so no delayed AI callback exists to fire twice or mutate a new round; the delayed result transition is single-task, cancelled before replacement and on exit. Introduction, first-use instruction, interface-language feedback, Android-compatible result phrasing, the two child kick sounds, silent AI moves, status blinking, confetti, and next-round feedback remain wired. Reduce Motion removes nonessential animation without changing result timing. Board positions stay spatially left-to-right under RTL interfaces and expose row/column/mark accessibility semantics.

Tic-Tac-Toe remains a just-for-fun Game. It does not accept or emit `ActivityAttemptData`, is not recorded through the Language attempt pipeline, and does not affect graded mastery or reward policy.

## Remaining runtime gates

- Compile all product targets and execute ProductConfigurationTests on macOS.
- Verify iPhone/iPad panel, board, mascot scale/crop, X/O controls, Dynamic Type, RTL interface composition, and the absence of a visible score treatment.
- Verify VoiceOver board order/state/hints, Switch Control, keyboard focus, and mark-selection locking.
- Verify interface-locale introduction/result speech, first-use persistence, move sounds, timing, automatic next round, cancellation, and Reduce Motion.
- Verify original mascot/background visual parity and complete independent visual and linguistic review.
