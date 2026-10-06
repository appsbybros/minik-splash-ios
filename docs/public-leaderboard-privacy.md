# Public leaderboard privacy model

Status: source-implemented; owner/legal policy approval and deployed-backend validation remain required.

## Identity boundary

The local child/profile name is local-only. It is not an input to the records repository, Firebase authentication, the public participant identifier, or a Firestore payload.

Public identity is a typed `PublicLeaderboardAlias` assembled only from app-owned adjective and noun enums, a number from 1 through 99, and an optional app-owned avatar ID. The child chooses from four generated options and can reroll those options. There is no free-text, real-name, initials, photo, email, phone, address, or date-of-birth field. The selected alias, participation preference, and best pending candidate are stored locally per product and local profile scope.

## Participation lifecycle

1. A qualifying local score is celebrated and retained locally. If no public alias exists, the child can choose a curated alias immediately.
2. Before an alias is selected, no candidate query or write is made and the best candidate remains pending locally. There is no alias request during onboarding.
3. Selecting an alias activates participation for the normal first-score flow and immediately attempts to publish the pending candidate when Firebase is configured. Later qualifying candidates reuse the same alias and publish automatically. Parent Area shows the current alias and can replace it only with another generated curated choice; the replacement is persisted for future qualifying publications.
4. Parent Area provides a persistent **Online leaderboard** On/Off control. A Parent opt-out remains authoritative: disabling participation persists immediately, blocks later uploads, and cannot be overridden by child alias selection. It does not remove local progress, local rewards, the chosen alias, or the pending best candidate.
5. While participation is disabled, Parent Area offers deletion of both public score and streak documents belonging to the existing opaque participant ID. This action does not require an additional approval challenge, never creates a new participant identity, and never changes local progress.

Reading the public leaderboard may establish Firebase anonymous authentication for transport. The anonymous Firebase user is not named from the local child/profile and the local name is never passed to Firebase.

Each updated-client profile has its own persisted opaque `v2_<UUID>` public participant ID. Firebase privately binds it to the current anonymous Auth UID in `leaderboard_owners/{player_id}`. That private document contains only `owner_uid`, cannot be read/listed by clients, is never displayed, and allows one authenticated installation to own multiple local profile IDs. The Auth UID never replaces `player_id` in a public record.

## Remote allowlist

The Android-compatible collections and field names remain in use. The only app-owned values written are:

| Firestore field | Meaning |
| --- | --- |
| `player_id` | Opaque, product/profile-scoped participant identifier |
| `user_name` | Curated generated public alias; never the local child name |
| `avatar_id` | Optional identifier from the app-owned avatar enum |
| `score` | Qualifying score, on score records |
| `correct_answers_in_row` | Best streak/correct-answer value required by the existing schema |
| `app_id` | Existing Android-compatible product/app identifier (`3`) |
| `date_achived` | Existing legacy field spelling, populated with a Firebase server timestamp |

The score collections remain `score_records` and `score_records_english_only`; the shared streak collection remains `correct_answers_in_row`. No local child name or other arbitrary profile content is copied into legacy `user_name`. Incoming values that do not match the curated alias grammar are not displayed as a public name by the iOS client.

## Release approvals still required

Before enabling the production leaderboard, the owner/legal reviewer must approve the final child-directed privacy notice and store disclosures, including Firebase as the service provider, purposes, retention, deletion handling, and applicable territorial/age obligations. This source model does not itself establish that curated-alias participation satisfies every jurisdiction or storefront rule. Production deletion behavior, offline/retry behavior, App Check, and archive privacy reporting require macOS/device/backend validation.

The exact repository-prepared website replacement wording is in `docs/privacy-policy-website-replacement.md`, and App Store disclosure facts are in `docs/app-store-privacy-data-inventory.md`. Neither is legal approval or evidence that the live website/App Store listing has been updated.

Strict repository-owned Rules and indexes now exist, but they must not be deployed until the administrator archive/clear cutover and updated Android rollout in `docs/firebase-leaderboard-migration.md` are ready. Updated iOS never claims a legacy UUID; it uses a new versioned profile ID while retaining local progress, rewards, bests, alias, and pending publication state.
