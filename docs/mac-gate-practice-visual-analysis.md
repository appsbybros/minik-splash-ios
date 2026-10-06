# Shared practice visual Mac-gate repair — 2026-09-05

Status: source correction and Windows static audit complete; Xcode confirmation pending.

Correction after the next supplied Mac run at `d2d8d79`: the choice-style error did not recur, but all four apps failed on the invalid Cards accessibility action. The Cards row below overstated the prior review: SDK overload resolution was not established. The earlier no-additional-defect finding was incomplete. See [the second failure red-team review](cards-accessibility-mac-analysis.md) for the introducing commit, default-action repair, authoritative API evidence, entire-Sources candidate review, and compiler-dependent limits.

## Failure, history, and correction

The supplied real Xcode 26.6 / Swift 6.3.3 Simulator result checked out
`d6b3cbfad3a0cd5f9fe872a5965beac77ac7d846`. All four schemes failed on the
same shared source error: `state` was out of scope at lines 252 and 258 of
`Sources/MinikPracticeVisuals.swift`. ProductConfigurationTests did not run.

`git log -S "state == .idle" -- Sources/MinikPracticeVisuals.swift`, line blame,
and the introducing diff identify
`a90e0a0815d76eab79e8e8f00fbec180b1e6b811`
(`checkpoint: fix first simulator activity findings`). That commit replaced
the choice button's uniform palette stroke with an idle purple/cyan gradient
and a two-point idle border. It introduced both invalid references together.

`MinikChoiceButtonStyle` has owned `feedbackState: FeedbackState` since its
creation in `3e71a7eeac67e49bff4bf4f6e1302e61a44c1cd5`. The introducing
commit did not remove or rename a property/parameter. `makeBody` already used
`palette(for: feedbackState)`. The identifier `state` is the local parameter of
the separate `palette(for state: FeedbackState)` helper; it is unavailable in
`makeBody` and its overlay closure. Neighboring Match/Memory/Soccer styles
legitimately own their own `state`, which does not make it visible here.

The exact correction changes only the two border conditions to
`feedbackState == .idle`. The first chooses the idle gradient versus the
selected/correct/incorrect palette stroke; the second chooses the idle width
versus that same feedback palette's width. Both must read the same stored
feedback value as the fill/shadow palette. There is no evidence for adding a
second state property, removing either conditional, moving this styling to a
different component, or reverting the visual work. History proves a wrong-name
scope reference; it cannot prove the author's editing/copy-paste process.

## Complete component review

- `feedbackState` and `compact` are the memberwise constructor inputs. The
  enabled and Reduce Motion values come from the existing Environment wrappers.
  `configuration.label` and `configuration.isPressed` come from ButtonStyle.
- `palette(for:)` handles all four declared feedback cases. ChoicePalette's
  fill, stroke, lineWidth, shadow, shadowRadius, and shadowY declarations match
  every use. Local helper `state` is valid and remains unchanged.
- Idle retains the purple/cyan gradient and width 2; selected retains its blue
  stroke/width 2.2; correct retains green/2.4; incorrect retains coral/2.2.
  Fill, shadows, disabled opacity, padding, and minimum heights remain intact.
- The sole constructor call is in `MultipleChoiceView.choiceGrid`, with labels
  `feedbackState:` then `compact:`. Its helper maps unselected to idle, selected
  without result to selected, and the optional answer result to correct or
  incorrect. Its accessibility hint switch covers the same four cases.
- Language First Letter, picture/word directions, and Mixed use this shared
  choice view. Math M1–M10 choice routes use it with the standard presentation
  and explicit Math metadata. No second product-specific state API is needed.
- Caller labels/hints, correct/incorrect textual cues, disabled selection, the
  Dynamic Type single-column fallback, and independent learned-content direction
  remain intact. Reduce Motion still suppresses both press scale and animation.
  This source review does not establish rendered contrast or VoiceOver output.
- `project.yml` gives every app the complete Sources directory through
  MinikApplication. This shared defect therefore blocks all four schemes even
  when runtime routing does not expose a choice activity in Ping Pong.

## Audit range and method

Last evidenced Mac compile-clean checkpoint:
`b1c3e811da1dc72e3c0204c82e6c9596b8d85a9c` (Gate #6). The master plan records
MinikPlus and ProductConfigurationTests compilation, bundle loading, and 763
executed tests at that SHA. Assertions failed; compile-clean does not mean
test-clean. Gate #5 built all four apps at `7bc1511`; Git shows no Sources
changes between it and `b1c3e81`. Subsequent Windows checkpoints are not Mac
baselines, including the first test-fixture correction `27ccca2`.

The audited range is `b1c3e81..d6b3cbf`: 25 commits, 38 production Swift files
and 18 test Swift files. The union from `git log --name-only` equals the net
`git diff --name-only` list (56 files), so no touched-and-reverted Swift file
was omitted. The net Swift diff is 2,649 additions and 609 removals. Each
changed hunk was reviewed, with containing declarations and related APIs/callers
inspected where needed; the complete repaired component and its file were read.

Review checked identifier scope, constructor labels/order/default arguments,
optional speech/content properties, enum declarations and switches, renamed or
removed helpers, generic ViewBuilder versus single-expression/explicit-return
functions, State/StateObject initialization, binding writes, conformance and
actor ownership, and shared target membership. New speech cue/content values
retain Hashable/Sendable value dependencies; speech players remain MainActor
objects. No detached work or target-condition split was introduced by this
range. Existing project Swift language mode is 5.9 with iOS 17 minimum; no build
setting or workflow change is part of this repair.

Additional concrete compile defects found: **none**. This is a source-review
result, not a claim that a compiler has accepted the range.

## Complete Swift inventory

Paths below are repository-relative. Every row belongs to the range above.

| File | Principal contract checked |
|---|---|
| Sources/ActivityCatalog.swift | Existing activity cases and section arrays |
| Sources/BuildSession.swift | Optional content unwrap, token dictionary, String/Character construction |
| Sources/BuildView.swift | Presentation case, initializer defaults/order, StateObject, per-token tracker and speech calls |
| Sources/CardsSession.swift | StudyCardID overload and Bool return |
| Sources/CardsView.swift | View composition, captured card ID and task cancellation; accessibility API argument mapping was missed (see correction above) |
| Sources/ContentContracts.swift | Failable build-content init, Hashable/Sendable members, optional default, token validation |
| Sources/DomainFoundations.swift | Prompt/Choice initializers, optional cue defaults and extension dependencies |
| Sources/LanguageFirstLetterChoiceContentProvider.swift | Guard scope, learned-text cue and Choice argument order |
| Sources/LanguageFirstLetterPictureContentProvider.swift | Choice? compactMap, guard scope, speech cue label |
| Sources/LanguageLearnDevelopmentView.swift | Learn/choice/build presentation arguments and defaults |
| Sources/LanguageMixedPracticeView.swift | Mode switch, typed child presentation and callback order |
| Sources/LanguageOrderedTokenAttemptTracker.swift | Supported families, optional skillID and ActivityAttemptData labels |
| Sources/LanguageWordBuildContentProvider.swift | String filtering, failable content and BuildChallenge labels |
| Sources/LanguageWordContentProvider.swift | Typed choices result, optional speech cue definite initialization |
| Sources/LearningSpeech.swift | Cue extensions, optional language/text, Hashable/Sendable value and MainActor player |
| Sources/LearnView.swift | Presentation init, Group branches, cardContent ViewBuilder, added context |
| Sources/MathCardsView.swift | Branded replay view and existing replay action |
| Sources/MathCountConstructionView.swift | Branded replay view/action/asset member |
| Sources/MathFractionConstructionView.swift | Branded replay view/action/asset member |
| Sources/MathNumberLinePlacementView.swift | Branded replay view/action/asset member |
| Sources/MathStructuredConstructionView.swift | Branded replay view/action/asset member |
| Sources/MemoryView.swift | Scene-phase environment, card-face ViewBuilder and artwork API |
| Sources/MinikActivityHubView.swift | Optional route associated values, exhaustive destination, Binding and caller signatures |
| Sources/MinikHomeVisuals.swift | Defaulted usesArtwork input, matching LinearGradient branches and removed helper |
| Sources/MinikPracticeVisuals.swift | Entire style/palette/component file; two repaired scope errors |
| Sources/MinikVisualAssets.swift | Activity switch, asset member declarations and default ContentMode |
| Sources/MultipleChoiceView.swift | Entire view, feedback mapping, identity helper, presentation cases and speech/attempt APIs |
| Sources/PairsView.swift | Existing selection-style case, ViewBuilder branch and artwork API |
| Sources/ParentAreaView.swift | Initializer/callbacks, settingsHeading signature, ViewThatFits and new ButtonStyle |
| Sources/PingPongRallyModel.swift | CGFloat arithmetic and first/second-bounce definite initialization |
| Sources/PingPongScene.swift | Table/arena CGRect members, CGSize/CGPoint types and strike signature |
| Sources/PingPongView.swift | Rounded Font.system overloads |
| Sources/RecordsLeaderboardUnavailableView.swift | Entire new View, onClose closure and Home/artwork API |
| Sources/RepresentationView.swift | Added context covered by switches; explicit ViewBuilder for differing foreground styles |
| Sources/SoccerIntroduction.swift | Entire repository, UserDefaults API and Bool return |
| Sources/SoccerView.swift | Both initializers, optional repository, StateObjects, new helpers/ViewBuilders and speech APIs |
| Sources/TicTacToeView.swift | Renamed mascot declaration/call and asset member |
| Sources/TowerView.swift | New helper arguments, explicit multi-statement return, CGFloat sizing and optional block IDs |
| Tests/ProductConfigurationTests/ActivityCatalogTests.swift | Existing string assertion |
| Tests/ProductConfigurationTests/ActivityProgressTests.swift | Default UUID fixture argument preserves existing calls |
| Tests/ProductConfigurationTests/BuildSessionTests.swift | Typed build-content fixture and optional helper argument |
| Tests/ProductConfigurationTests/CardsSessionTests.swift | Identity-guarded overload and Bool assertions |
| Tests/ProductConfigurationTests/LanguageFirstLetterChoiceContentProviderTests.swift | Cue/identity/session APIs and optional pending action cases |
| Tests/ProductConfigurationTests/LanguageFirstLetterPictureContentProviderTests.swift | Cue/identity/session APIs and optional pending action cases |
| Tests/ProductConfigurationTests/LanguageMixedPracticeTests.swift | Mode/session cases, optional child factory and tracker argument order |
| Tests/ProductConfigurationTests/LanguageOrderedTokenAttemptTrackerTests.swift | Family cases, optional skillID and retry fields |
| Tests/ProductConfigurationTests/LanguageProductionParityTests.swift | Catalog methods, artwork mapping and session speech members |
| Tests/ProductConfigurationTests/LanguageSoccerContentProviderTests.swift | Optional display text and stableKey property |
| Tests/ProductConfigurationTests/LanguageSpeechContractTests.swift | Entire new XCTest class, request/cue signatures and imported types |
| Tests/ProductConfigurationTests/LanguageTowerContentProviderTests.swift | stableKey property |
| Tests/ProductConfigurationTests/LanguageWordBuildContentProviderTests.swift | String filtering, typed content optionality and factory helper |
| Tests/ProductConfigurationTests/LanguageWordContentProviderTests.swift | stableKey optionality, semantic answer cases and session APIs |
| Tests/ProductConfigurationTests/MathActivitySessionFactoryTests.swift | Typed missing-value representation, operation and throwing map helper |
| Tests/ProductConfigurationTests/PingPongRallyModelTests.swift | Serve-plan signatures, CGFloat and accuracy assertions |
| Tests/ProductConfigurationTests/PingPongTableLayoutTests.swift | Throwing unwrap and scalar accuracy assertions |
| Tests/ProductConfigurationTests/SoccerIntroductionRepositoryTests.swift | Entire new XCTest class and repository initializer |

## Regression audit and Windows validation

`Scripts/audit-minik-practice-visuals.ps1` is a focused source-contract guard.
It isolates this component/makeBody/helper, verifies the actual stored state,
palette fields/cases, both border expressions, and the shared caller's labels
and accessibility integration. It does not ban valid `state` parameters in
other helpers/styles or attempt general Swift name resolution. Intentional API
changes require updating its explicit expectations after review.

The existing Language visual audit now invokes it, preventing omission from
that regular validation path. `-SelfTest` changes source strings in memory:
both historical references, either reference alone, missing stored property,
palette input drift, stale feedback case, and wrong caller label are all
rejected (seven mutations). No fixture changes the working tree.

All 20 applicable scripts passed on Windows, including the focused audit:

- ProductConfigurationTests compatibility: 80 test files, 16,063 lines,
  2 manifest constructors, 33 LearningText constructors, zero compatibility errors.
- Localization source audit: zero hardcoded/dynamic/missing-key/catalog errors;
  catalog validator: 469 keys, 11 Full locales and 10 English Only locales.
- Language visual (41 contracts plus focused component), speech (27), Mixed
  (21), Cards (23), Soccer (52), Tower (25), Memory (23), Tic-Tac-Toe (30),
  and production parity (13 records): zero reported errors.
- English Only policy (22 contracts) and parity (469 keys, 10 locales,
  16 surfaces): zero reported errors.
- Minik asset and provenance audits: 36 assets/rows, zero errors.
- Math assets: 100 objects, 3 zero states, 6 grouping assets, 10 categories;
  Math visual consistency: 13 identities, M1/M5/M10, 12 shared screens;
  zero reported errors.
- Workflow safety read-only: four manual-only workflows, zero automatic-trigger
  errors. No workflow file was changed and no workflow was dispatched.
- Focused practice visual audit and all seven regression self-tests passed.
- `git diff --check` passed. Repair and full staged diffs were reviewed before
  the single local checkpoint; pre-existing dirty paths were excluded.

## Limits and preserved work

No Swift/Swiftc executable was found on PATH or in the checked standard Windows
toolchain location; no Swift parser integration exists in repository Scripts.
The available bundled Python environment has no tree_sitter, tree_sitter_swift,
tree_sitter_languages, or swift module; bundled Node modules contain no Swift
or tree-sitter parser. No toolchain was installed. These text audits cannot
validate Swift overload inference, SDK availability, actor diagnostics, or
SwiftUI's generated generic types as the real Apple compiler does.

Xcode compilation of all four schemes, ProductConfigurationTests execution,
asset/String Catalog compilation, Simulator/device layout, VoiceOver, speech,
Reduce Motion, lifecycle timing, and visual confirmation remain unvalidated by
this repair session. No Xcode or XCTest success is claimed.

The initial index was empty. The 805 pre-existing modified/deleted/untracked
file paths were recorded with SHA-256 hashes (or a missing-file marker) before
editing, including all Phase 41 assets, manifests, benchmark work, the dirty
LanguageWordCatalogTests file, and deleted README. The final export records
their preservation check, checkpoint HEAD, and complete final short status.
No fetch, push, workflow execution, reset, stash, clean, rebase, or amend is
part of this repair.
