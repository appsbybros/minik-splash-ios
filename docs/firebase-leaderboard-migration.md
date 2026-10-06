# Secure leaderboard migration runbook

Status: repository-prepared coordinated cutover. No Firebase data, Rules, indexes, Auth setting, or App Check enforcement has been changed by this document.

## Selected strategy

Keep the established active public collection names—`score_records`, `score_records_english_only`, and `correct_answers_in_row`—so Android and iOS continue to share one leaderboard. Archive the legacy contents outside the active ranking namespace, clear the active collections in a controlled maintenance window, and restart the active leaderboard with authenticated private ownership.

Do not let a client claim a legacy UUID. Updated clients generate and persist a new opaque `v2_<UUID>` for each product/profile. The private document `leaderboard_owners/{player_id}` contains only `owner_uid`, binds that profile ID to the current Firebase anonymous UID, and is never part of public display. One UID may own many profile IDs. Public documents keep the Android-compatible fields and never contain `owner_uid` or platform-specific fields.

Local learning progress, rewards, current bests, selected curated aliases, and pending candidates are not deleted or reset. After cutover, an updated client can publish the retained local best under its new secure participant ID through the normal qualifying-score retry path.

## Pre-deployment facts

- Legacy records use unversioned per-profile UUIDs with no historical Auth mapping.
- Legacy Android may publish locally entered free text as `user_name`.
- A public legacy `player_id` is not proof that the current anonymous user owns it.
- The checked-in Rules reject unversioned IDs and free-text aliases.
- Deploying the strict Rules before the cutover will stop legacy writes; leaving legacy documents in active collections would mix unauthenticated history with the secure ranking.

## Owner/admin cutover sequence

1. Enable Firebase Anonymous Auth for the project, but keep App Check enforcement off.
2. Prepare release candidates for both platforms. Updated clients must use the same three public collections, `app_id == "3"`, `v2_<UUID>` per profile, `leaderboard_owners/{player_id}`, curated aliases/avatars, and the existing public allowlist.
3. Verify the Rules and the 19 ownership/migration cases with the Firebase Emulator Suite using both platform fixtures. Do not point test clients at production.
4. Announce a maintenance window. Prevent administrative/editor writes and record the exact production project/database selected.
5. Create a Firebase/Google Cloud managed export or equivalent administrator-controlled immutable backup of the three legacy public collections. Record collection counts, export location, timestamp, and operator. Restrict the archive from client access.
6. Optionally copy legacy data to a separate administrator-only archive namespace for business retention needs. Do not expose that namespace through client Rules or combine it with active top-20 queries.
7. Verify the export can be enumerated/restored and that its counts match the pre-cutover collections. Do not delete active data until this verification succeeds.
8. Using authenticated administrator tooling—not an app client—clear legacy documents from the three active public collections and clear any pre-production `leaderboard_owners` documents. Never delete local app data.
9. Deploy the checked-in composite indexes, then deploy the checked-in strict Rules. Confirm the deployed versions and run production-project read/write/delete probes only with dedicated test participants.
10. Release the updated Android and iOS clients as one coordinated generation. Older clients will no longer be able to publish after the strict Rules activate; plan support/forced-update messaging accordingly.
11. Verify that each profile creates a distinct versioned ID, one anonymous UID can own multiple profiles, another UID cannot update/delete them, public queries remain shared, and retained local bests republish without legacy duplication.
12. Monitor Auth, Firestore denial/error rates, ownership creation, rankings, deletion, and App Check metrics before considering enforcement.

## Updated Android implementation contract (read-only workspace)

The Android reference repositories are read-only under `AGENTS.md`, so this iOS commit intentionally does not leave Android changes behind. The Android repository owner must implement and commit these changes in its proper repository:

- `android/app/src/main/java/com/minik/minik/fragments/IntroScreen.kt`: stop reusing an unversioned active-leaderboard ID; persist a new `v2_<UUID>` per `selectedUserIndex` without deleting the old local key until rollback is no longer needed.
- `android/app/src/main/java/com/minik/minik/helpers/SharedPreferencesCache.kt`: add a versioned secure-player-ID key scoped to the selected local profile; never derive it from the child's name or Auth UID.
- `subscriptionlib/src/main/java/com/minik/subscription/RecordsDetails.kt`: anonymously authenticate before protected operations; create/reassert `leaderboard_owners/{player_id}` with only `owner_uid`; retain the three public collection names, `app_id`, query/order/limit, public fields, server timestamp, qualification, and batch behavior.
- `android/app/src/main/java/com/minik/minik/fragments/WriteScreen.kt` and `LetterPairsFragment.kt`: remove the legacy records-name free-text path and supply only the shared curated adjective + noun + number alias and optional curated avatar.
- `android/app/src/main/java/com/minik/minik/fragments/RecordsLeaderboardDialogFragment.kt`: display only curated active aliases and never expose `owner_uid`.

Android must use Firebase anonymous Auth as transport identity but must not replace the per-profile `player_id` with `auth.uid`. It must preserve local progress/rewards and republish the locally retained best under the new ID after cutover.

## App Check sequence

1. Obtain Apple Developer Program membership/Team ID and register the two canonical Apple Language App IDs.
2. Register Minik Plus iOS and Minik Plus English iOS with Firebase App Check using App Attest.
3. Register every legitimate updated Android application with the appropriate supported Android App Check provider.
4. Ship updated clients while enforcement remains off.
5. Monitor valid, invalid, and unverified App Check metrics together with Auth/Firestore errors through a representative adoption period.
6. Enable enforcement only after both platforms are healthy and legacy clients have been intentionally retired. Roll out per Firebase product rather than assuming one setting covers all services.

## Rollback considerations

- Preserve the verified legacy export and old client source/tag. Never merge archived legacy records back into the secure active ranking without an administrator-reviewed transformation.
- If strict Rules cause unexpected denial, disable active publication through an owner-controlled release/configuration response or temporarily restore a reviewed authenticated rule version; do not restore broad unauthenticated writes.
- If the new client identity implementation is defective, pause rollout and publication. Keep local progress/rewards/pending candidates intact so repaired clients can retry.
- Do not enable App Check enforcement as part of the same irreversible step as the ownership cutover. Ownership/rules health must be established first.
- Record every deployed Rules/index version, export identifier, client version, operator, and timestamp so the exact cutover can be audited.
