# Shared activity event integration plan

## Boundary now available

`ActivityEvent` is the storage-neutral contract for Language, Math, and game
progress. `ActivityEventSink` is the only dependency sessions or coordinators
need. `LocalProgressRepository` implements both the sink and a versioned local
repository; a future backend adapter can implement the same protocols without
changing activity logic.

Reward effects are deliberately absent from `ActivityEvent`. Unit 7 consumes
activity outcomes through its own typed reward processor so views never own
points or streak calculations.

## Mechanical integration order

1. Inject an optional/no-op `ActivityEventSink` at each activity coordinator or
   practice-session boundary; do not import persistence or Firebase in views.
2. Emit `sessionStarted` once when a real practice session begins and
   `sessionEnded` once with measured active duration when it ends.
3. Emit `attempted`, then exactly one of `answeredCorrectly` or
   `answeredIncorrectly`, from the domain transition that accepts the attempt.
4. Emit `skipped` or `advanced` only for explicit child actions, and `completed`
   only when the activity's existing completion contract fires.
5. Map Language and Math curriculum/skill IDs when they genuinely exist. Leave
   those fields nil for just-for-fun games.
6. Map Ping Pong's existing completed-match host boundary to `matchCompleted`;
   do not report rallies as curriculum attempts.
7. Add per-session duplicate-event guards and deterministic transition tests
   before wiring the next activity family.

## Recommended rollout

Start with one provider-backed choice activity, then Build, Pairs/Memory,
Soccer/Tower, Mixed/Cards/Learn, Tic-Tac-Toe, and finally Ping Pong. Validate
each family on macOS before a broad app-shell composition change.

Firebase, profile ownership, backend sync/conflict policy, analytics, final
progress UI, and product reward amounts remain outside this foundation.
