# Android reward behavior reference

Inspected 2026-08-31. This records production behavior; it does not approve a
new Math reward policy.

## Stored state and scope

- `DeviceStatusManager` holds total points, current correct-answer streak, and
  best correct-answer streak in memory.
- `SharedPreferencesCache` persists all three with the selected Android user
  index in each key. Missing or negative stored values load as zero; saved
  points are clamped to zero.
- `IntroScreen` restores the selected user's values. Firebase leaderboard
  submission is a separate records concern, not the local calculation path.

## Observed rules

- Main word choice practice: correct adds 1 point at bonus runs 1-2, 2 at 3-4,
  3 at 5-9, 4 at 10-19, and 5 from 20 onward. Correct increments the persisted
  displayed streak/best. Wrong deducts 1 (floor zero) and resets both runs.
- Build Word uses WriteScreen's DRAG screen in tap mode. It scores the completed
  word once, not each accepted letter. A rejected letter leaves points and the
  persisted displayed streak unchanged, but resets the local bonus run and
  marks this word as having errors. Repairing that word awards 1 point and
  increments the displayed streak; it does not increment the clean bonus run.
- These two runs are initialized together from the saved displayed streak when
  WriteScreen controls initialize (DRAG line 3463; choices line 3555). They can
  diverge within Build after a rejected letter (4531-4572). Re-entry restores
  the local run from the persisted streak again. Award thresholds and completion
  logic are at 2415-2482 and following branches; choice errors at 2717-2746.
- Letter Pairs: +1 for each correct pair.
- Tower: +2 when the word is completed.
- Soccer match: +3 win, +1 draw, no observed point change for a loss.
- Tic-Tac-Toe round: +2 win, +1 draw, −1 loss with a zero floor.
- Memory: +2 at game completion regardless of whether the child or Minik won;
  this is an observable quirk and is not generalized as a shared policy.

The rules are materially activity-specific. The iOS foundation therefore uses
typed reward reasons plus injected central policies rather than applying one
generic policy to every route. Production Language now integrates the observed
choice/Build distinction, Letter Pairs, Tower, Picture Memory, Soccer, and
Tic-Tac-Toe rules through the existing product-scoped local ledger. Event-ID
deduplication includes zero-point, streak-neutral markers for rejected Build
letters. Aggregate Language points/best-streak state is offered to the existing
Android-compatible remote-record boundary when a production activity exits;
missing Firebase configuration and remote failure do not alter the local ledger.
Math still has no approved reward values, and Ping Pong has no reward contract in
the inspected Android product, so neither receives an invented policy.

## Android source inspected

- `app/src/main/java/com/minik/minik/managers/DeviceStatusManager.kt`
- `app/src/main/java/com/minik/minik/helpers/SharedPreferencesCache.kt`
- `app/src/main/java/com/minik/minik/fragments/IntroScreen.kt`
- `app/src/main/java/com/minik/minik/fragments/WriteScreen.kt`
- `app/src/main/java/com/minik/minik/fragments/LetterPairsFragment.kt`
- `app/src/main/java/com/minik/minik/fragments/LettersTowerFragment.kt`
- `app/src/main/java/com/minik/minik/fragments/LettersSoccerGame.kt`
- `app/src/main/java/com/minik/minik/fragments/TicTacToeFragment.kt`
- `app/src/main/java/com/minik/minik/fragments/MemoryGameFragment.kt`
