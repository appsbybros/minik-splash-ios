# Firebase leaderboard contract and security readiness

Status: cross-platform public schema verified; secure iOS ownership source and strict Rules are checked in. Deployment remains blocked on the coordinated legacy cutover and updated Android client described in `docs/firebase-leaderboard-migration.md`.

## Production Android contract

The canonical implementation is `subscriptionlib/src/main/java/com/minik/subscription/RecordsDetails.kt`. `android/app/src/main/java/com/minik/minik/fragments/IntroScreen.kt` supplies the persisted profile identity. The machine-readable counterpart is `Config/Firebase/leaderboard-contract.json`.

| Concern | Verified contract |
| --- | --- |
| Normal score path | `score_records/{player_id}` |
| English Only score path | `score_records_english_only/{player_id}` |
| Both products' streak path | `correct_answers_in_row/{player_id}` |
| Secure ownership path | private `leaderboard_owners/{player_id}` containing only `owner_uid` |
| Updated-client participant key | persisted per-product/per-profile `v2_<UUID>`; never `auth.uid` |
| Filter/order/limit | `app_id == "3"`; descending `score` or `correct_answers_in_row`; limit 20 |
| Timestamp | Firebase server timestamp in legacy-spelled `date_achived` |
| Score fields | `app_id`, `player_id`, `score`, `correct_answers_in_row`, `date_achived`, `user_name` |
| Streak fields | `app_id`, `player_id`, `correct_answers_in_row`, `date_achived`, `user_name` |
| iOS-safe extension | optional curated `avatar_id`; Android ignores fields it does not read |
| Qualification | positive values only; a full table requires a value strictly above the last value; ties share rank; an equal/better loaded value for the same player is not replaced |
| Write atomicity | if both score and streak qualify, Android and iOS use one Firestore write batch; a single qualifying type uses one write |

The client first reads the top 20 and then writes. That read/qualification/write sequence is not a Firestore transaction on either platform, so concurrent clients can race. A write batch makes a two-document result all-or-nothing; it does not make the preceding top-20 decision serializable. The migration-ready Rules add monotonic update checks, but a server-authoritative transaction would be needed to enforce a globally exact top-20 admission decision under concurrency.

Android has no public-record deletion API in the inspected production source. iOS deletion targets only the current participant's normal-or-English score document and the shared streak document in one batch. It leaves all local learning state intact.

## iOS privacy boundary

iOS writes the Android field names and paths, plus optional `avatar_id`. `user_name` is always the app-curated public alias; the local child/profile name is absent from repository, Firebase Auth, participant-ID, and payload inputs. Incoming names are shown as published (owner decision, 2026-10-05: Android's typed public names, at most five characters, are approved): iOS displays any `user_name` that meets the deployed Firestore contract (1-32 characters, no leading or trailing whitespace), refusing only control characters, line separators and bidirectional embeddings/overrides/isolates, which show as "Player" (`PublicLeaderboardAlias.validatedRemoteAlias`). The curated-alias requirement in the undeployed strict Rules below would reject Android's names and must follow this decision before any deployment.

Before every Firestore query, write batch, or delete batch, `AuthenticatedRemoteRecordsDataSource` obtains an anonymous Firebase UID. Before a write/delete, `AuthenticatedRemoteRecordsOwnershipStore` creates or reasserts the private immutable `leaderboard_owners/{player_id}` binding with that UID. One UID can own multiple profile IDs; the UID is never copied into public leaderboard documents or displayed. Authentication/configuration/ownership failures leave the best candidate pending locally. A later eligible submission or re-enabling the setting retries it. Firebase Console must have **Authentication → Sign-in method → Anonymous** enabled.

Updated iOS deliberately uses a new `minik.records.player-id.v2` storage namespace and `v2_<UUID>` value. It does not import or claim a v1/legacy UUID. Existing local rewards, progress, alias, and pending candidate remain intact, so the next eligible submission republishes the current local best under the secure ID after cutover.

## Secure Rules and remaining deployment blocker

No Firestore Rules source or `firebase.json` was present in the workspace or repository history before the closure work. The repository Rules now preserve profile identity instead of replacing it with `auth.uid`: public document ID must equal its secure `player_id`, and a private ownership document must map that ID to `request.auth.uid`. Ownership documents contain only `owner_uid`, reject legacy IDs, cannot be read/listed/deleted by clients, and cannot be transferred. Public fields are allowlisted and typed, values are bounded, aliases/avatars are curated, timestamps use `request.time`, top-list reads require authentication and limit 20, values cannot regress, and all unrelated paths are denied.

Those Rules are still **not deployable against legacy production data/clients**. Android creates an unversioned `player_id` with `UUID.randomUUID()` per selected local profile and currently writes a locally entered free-text name into `user_name`. Historical records have no cryptographic ownership mapping. The secure Rules therefore reject unversioned IDs and arbitrary aliases rather than allowing a new anonymous session to claim a public legacy UUID.

The selected migration is an archive-and-clean-cutover, not an insecure claim: export/archive the three legacy public collections with Admin credentials, verify the archive, clear the active collections during a maintenance window, deploy the strict Rules/indexes, and release updated iOS/Android clients that create new versioned IDs, private ownership bindings, and curated aliases. Existing profiles can then republish their retained local best. The complete sequence, Android file-level contract, App Check ordering, and rollback rules are in `docs/firebase-leaderboard-migration.md`. No source in this repository deploys or deletes backend data.

## App Check rollout

The two Language targets link `FirebaseAppCheck`, carry the production App Attest entitlement, and select the App Attest provider before `FirebaseApp.configure` in non-DEBUG builds. Explicit DEBUG builds select Firebase's debug provider for Simulator/local development; no debug token is stored in source. Math and Ping Pong link no Firebase products or App Check entitlement.

Console work remains: register both canonical Apple apps for App Check with App Attest, retain any debug token only in protected developer/CI configuration, distribute and monitor valid/invalid request metrics, and keep enforcement **off**. Register and verify every legitimate Android and Apple production client before enabling enforcement; otherwise existing Android traffic can be rejected.
