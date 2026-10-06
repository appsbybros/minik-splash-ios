# Post-C9 independent-review corrections

Windows-static evidence only. Xcode, XCTest, Simulator, device behavior, VoiceOver, and linguistic review remain pending.

## Interface localization provenance

`Scripts/migrate-android-interface-localizations.ps1` copies established product translations from the read-only Android `app/src/main/res/values*/strings.xml` catalogs into both iOS string catalogs. Locale mapping is direct: `values` -> `en`, `values-am` -> `am`, `values-ar` -> `ar`, `values-de` -> `de`, `values-es` -> `es`, `values-fr` -> `fr`, `values-he` -> `he`, `values-nl` -> `nl`, `values-pt-rBR` -> `pt-BR`, `values-pt-rPT` -> `pt-PT`, and `values-ru` -> `ru`. English Only intentionally excludes Hebrew.

The migrated mappings are:

- `start` -> `Start`
- `plus_menu_home_description` -> `Home`
- `game_dialog_text` -> the Soccer introduction paragraph
- `records_dialog_title` -> `Top 20 records`
- `records_load_error` -> `The records could not be loaded.`
- `records_close` -> `Done`

The current English iOS Soccer paragraph remains the approved tap-based iOS source copy. Its non-English values come from Android's established full game instructions, including Hebrew. `translated` records source migration; it is not a claim of new independent linguistic review.

## Home trophy semantics

Android `fragment_select_screen_plus.xml` identifies the trophy as `selectScreensShowRecords`. `ButtonsMenuFragment` sends that control to `showRecordsLeaderboard()`, which loads remote top records and presents `RecordsLeaderboardDialogFragment`. Therefore the iOS Home trophy no longer opens the on-device `Records & Streaks` screen. It opens a separate, truthful unavailable leaderboard boundary. Parent Area retains the local records destination. No remote results are fabricated and no local streak is presented as a leaderboard result.

## Word Cards timer identity

Each timed task captures the presented `StudyCardID`. `CardsSession.advance(ifCurrentCardID:)` rejects a stale timer after a manual advance. Deterministic tests cover stale-timeout no-op, no skipped next card, at-most-one guarded advance for a presentation, and normal current-card timed advance. Android timing and continuous shuffled-bag behavior are unchanged.
