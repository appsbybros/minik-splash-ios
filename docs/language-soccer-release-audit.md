# Language Soccer release audit

## Windows-static reconstruction result

Language Soccer now has a dedicated production view derived from the complete live Android `LettersSoccerGame.kt`, `SoccerIntroDialog.kt`, phone/sw600dp layouts, strings, dimensions, assets, and binding references 08/09. The active asset trace covered `minik_splash`, Plus `plus_background`, `mimik_star`, `minik_goalie_new_right` / Plus `minik_plus_goalie`, `minik_soccer_field_new`, `mink_gate_new`, `minik_soccer_ball_new` / live `soccer_ball`, `minik_kick`, `minik_kick2`, crowd applause/disappointment, claps, streak sound, and completion animation choices. Existing iOS exact-original field, goal, keeper, football, kick, and wrong-letter-goal swoosh assets are reused; the Plus intro aliases the already-provenanced `plus_background` pixels. This is source evidence only: Xcode compilation, XCTest execution, Simulator/device interaction, VoiceOver, real audio, performance, and independent visual/linguistic review remain pending.

The production route no longer uses the shared Math Soccer tap/random-outcome presentation. A child drags one colored physical letter upward from below the release line. Crossing the line launches immediately; release uses Android's 10-point deadband; releasing lower cancels without selecting, scoring, consuming, or recording an attempt. The launched object is the original football carrying the chosen token. Its constant-speed straight trajectory comes from the last measured drag vector, with the Android minimum upward component and duration bounds.

Keeper, left/right post, crossbar, goal mouth, and ball use one field coordinate system. The live Android file computes a crossbar rectangle but comments out its collision branch; the owner's explicit crossbar requirement supersedes that one source discrepancy, so iOS evaluates it alongside both posts. The first physical collision determines `saved` or `miss`; a clear goal-mouth crossing determines `goal`; keeper/frame contact rebounds before finalization. The typed `idle → dragging → launched → inFlight → rebounding → finalized` lifecycle uses a unique shot ID, rejects stale/duplicate callbacks, accepts one shot at a time, and cancels unresolved state on background/exit. Reduce Motion shortens, rather than removes, state transitions. The 56-point semantic accessibility target offers the same deterministic launch path as a fallback; drag remains primary.

## Educational and difficulty contracts

Physical outcome never rewrites educational correctness:

| token | physical result | child | keeper | consume/advance |
|---|---|---:|---:|---|
| correct | goal | +1 | 0 | yes |
| correct | miss/saved | 0 | 0 | yes |
| wrong | goal | 0 | 0 | no |
| wrong | miss/saved | 0 | +1 | no |

Duplicate character instances retain distinct physical IDs and equivalent semantic value. Correct tokens build/consume even after a miss/save; wrong tokens remain for retry even after a goal. Specialized attempts retain presentation identity, semantic content-item/token identity, retry index, response duration, Soccer family, and no Math fields. Target replay and launched-token pronunciation use learned-language speech metadata. Completion advances through the complete shuffled pool without an immediate repeat.

The Parent Soccer A/B/C setting now has a production effect matching Android. Reference phone keeper sizes are A `65×80`, B `80×97`, C `95×115` and scale together for the available field. A's first two attempts are stationary and movement alternates beginning on attempt 3; B's first attempt is stationary and all later attempts move; C moves immediately. Initial one-way sweep periods are 3.0/1.1/0.8 seconds. After ten shots Android's goal-ratio adjustment applies with 1.0/0.6/0.4-second floors. Movement is clamped to the goal mouth. Attempt performance persists across word transitions as in the Android game.

Pool exhaustion is exposed as an idempotent typed `LanguageAutoPoolBoundary` when the continuous bag replenishes. Specialized attempts now retain semantic content-item identity and actual source A-E stage. The boundary evaluates the Android 600-letter/80%-accuracy/two-pass gate and rebuilds the next pool from the persisted shared Parent level/ramp. Shot physics, scoring, and retry semantics are unchanged.

## Presentation and localization

The first three launches retain the persisted dedicated introduction. Its visible and interface-spoken copy now says to drag upward in all 11 Full / 10 English Only locale entries; English is `translated`, supplied non-English text remains `needs_review`. The gameplay keeps the original field, goal, keeper, football, branded close/speaker, compact edge scores, centered target/constructed word, and one fitted row of colored letters in a no-ordinary-scroll composition. Math Soccer remains on its previous presentation and behavior.

## Remaining release gates

- Compile all products and execute ProductConfigurationTests on Xcode/macOS.
- Validate real drag velocity, release deadband, goal/post/crossbar/keeper collision/rebound, exact-once scoring, interruption, and background/exit behavior.
- Validate A/B/C keeper scale, first-attempt behavior, sweep timing, and performance adjustment on device.
- Review compact iPhone, iPad, Dynamic Type, RTL/LTR, VoiceOver, Switch Control, Reduce Motion, speech/replay, sound, and animation performance.
- Obtain native-language review for every non-English introduction marked `needs_review`.
- Validate the integrated Auto promotion and ramp transition on a real app background/restart cycle.
