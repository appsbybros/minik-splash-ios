# Cards accessibility Mac failure: repair and red-team review — 2026-09-05

Status: one evidenced API defect repaired in source; real Xcode confirmation remains pending. No claim that this is the last compiler defect.

## Evidence and root cause

The user-supplied run checked out `d2d8d79deeb51cb65dc92a8a1d82187849e9cc75` on macOS 26.5.2, Xcode 26.6, Swift 6.3.3, and iPhoneSimulator SDK 26.5. The previous choice-style `state` diagnostic did not recur. All four app schemes failed at `Sources/CardsView.swift:71:42`, `.accessibilityAction(advance)`, with “missing argument for parameter 'named' in call”; the diagnostic displayed the named-Text candidate. ProductConfigurationTests did not run. Four occurrences of one shared error do not establish that subsequent compilation is clear.

Full Cards source, containing views, both callers, `git blame`, `git log -S ".accessibilityAction(advance)"`, and the complete file history identify introducing commit `248b5d3b5ba890e1e76ff4c342ae4baba10d1418`, `checkpoint: harden Language Word Cards`. It moved activation from a Button/Next control to the scroll surface, retaining `.onTapGesture(perform: advance)` and adding button traits plus the invalid accessibility call. The later identity-guarded `advance(ifCurrentCardID:)` overload in `5661e2b` did not introduce this error: the invalid call already existed.

Apple documents the default-action overload as `accessibilityAction(_ actionKind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void)`. The parenthesized sole `advance` expression does not correctly supply that call's handler after its defaulted leading parameter. The compiler's named-Text candidate is diagnostic evidence of failed overload selection, not a requirement to invent a name. A trailing handler closure, with either an omitted or explicit default action kind, matches the documented API. [Apple default accessibility action](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(_:_:)).

The production repair is exactly:

```swift
.accessibilityAction(.default) {
    advance()
}
```

Default activation is the intended action: the surface has button traits, ordinary tapping advances, and the retained hint says “Double tap to advance to the next word.” The prior Button had this same activation purpose. A named custom action would introduce a different accessibility interaction; neither the product contract nor this surface calls for one. Explicit `.default` makes the choice reviewable and the closure invokes the existing zero-argument method. Apple also documents named Text, StringProtocol, and LocalizedStringKey overloads; those are appropriate for the separate Add/Move custom actions elsewhere, not this repair. [Apple named Text](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:)-6t20v), [named StringProtocol](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:)-8ssvg), [named LocalizedStringKey](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:)-9ra29).

The complete production diff replaces this one expression. Manual `advance()` still stops speech and advances the session. Timer duration, card identity capture/check, task cancellation, scene-phase behavior, replay, exit, shuffle/session behavior, representations, layout, and styling are unchanged. The header's replay/exit controls remain outside the tap surface. Android RandomWordCards remains the behavioral reference, subject to `android-known-fixes.md`; no Android file changed. `project.yml` compiles the complete Sources directory for all four app targets, explaining why this Language view also blocks the Math and Ping Pong builds.

## Correction to the previous review

The previous Cards inventory claimed “overload resolution” was checked. That wording was too strong and the review missed an invalid API call. It inspected the view's composition and lifecycle but did not establish this call's argument mapping against an authoritative signature. The Word Cards guard checked the manual tap and activity contracts, not the accessibility action. The earlier choice-style guard checked identifier scope in another component. Recognizing an existing method and plausible behavior was insufficient API evidence.

The general disclaimer about Windows overload inference did not justify the specific claim. The prior report is corrected with an explicit addendum and a replacement Cards row. This review records each candidate's actual call shape, the relevant authoritative signature where available, and compiler-dependent uncertainty separately. Broad scans produce review candidates, never a blanket compiler-valid result. The exact historical invalid expression now has a regression guard. No evidence establishes that an SDK change caused or newly tightened this defect.

## Evidence categories and entire-Sources coverage

- **A — source inspection:** identifiers, declarations, labels/order, optional unwrapping, closure bodies and intended semantics can be compared locally. This is not Swift parsing or compilation.
- **B — SDK/API evidence:** matching an Apple declaration supports the described API shape and documented availability. It does not mean the compiler selected that overload for the full expression. Without a matching declaration, this category remains unresolved.
- **C — compiler/runtime confirmation:** exact Xcode 26.6 SDK overload selection, contextual types, availability diagnostics, generated ViewBuilder types, actor conversions, and actual behavior require the real toolchain/runtime.

All 133 current `Sources/**/*.swift` files were searched, independently of the committed-diff inventory. The requested 18 modifier families yield 52 sites: accessibilityAction 6, onTapGesture 1, onAppear 12, onDisappear 15, task 7, onChange 10, sheet 1. The other 11 requested families have zero sites, including trailing-closure forms. A separate generic sole-parenthesized-identifier/member scan in SwiftUI-importing files yielded 188 initial candidates (187 after this repair), plus 76 simple action/perform reference sites. These counts overlap; they are not distinct defects. Wider searches also covered multi-argument Button callbacks, Binding closures, drag/drop, feedback, presentation, accessibility values, and new visual modifiers. Complete paths, lines, snippets, dispositions, and authoritative declarations are in the external `swiftui-overload-risk-audit.txt` export and repeated in the main analysis export.

Reviewed dispositions:

| Family / candidate | A: source evidence | B: authoritative API shape | C: remaining confirmation |
|---|---|---|---|
| Cards default activation | One invalid bare handler repaired; default semantics traced through history | Explicit kind plus trailing `() -> Void` handler, iOS 13+ | All four builds; VoiceOver focus and activation |
| Build / Math Count named Add actions | Explicit `named: Text(...)`, trailing closure; session mutation stays inside closure | Named Text plus `() -> Void`, iOS 13+ | Contextual closure typing and accessibility behavior |
| Ping Pong Return Left/Right and Tower Place actions | Explicit named String/literal expression, trailing closure | StringProtocol / LocalizedStringKey named forms, iOS 14+ | Exact string-overload selection; actor inference |
| onTapGesture | `perform: advance`, zero-argument Void method | Default count plus labeled `perform: () -> Void`, iOS 13+ | Actor/contextual conversion |
| onAppear / onDisappear | Labeled zero-argument methods, optional callback shape or trailing closure; bodies inspected | `perform: (() -> Void)? = nil`, iOS 13+ | MainActor speech/player conversions |
| task(id:) | Equatable identity values, async trailing closure, cancellation/identity guards inspected | Current Apple task signature supports defaulted intervening arguments, iOS 15+ | Live docs include newer parameters/annotations; exact 26.6 declaration and isolation must be confirmed |
| onChange(of:) | Two-parameter old/new closures; observed values conform to Equatable | Two-value action with default `initial: false`, iOS 17+ | Exact generic/isolation inference |
| sheet | Binding<Bool>, trailing ViewBuilder content; optional dismissal omitted | isPresented/onDismiss/content declaration, iOS 13+ | Generated sheet content type and binding isolation |
| Button references | `action:` label present; zero-argument methods/closure properties; optional Ping Pong exit unwrapped with `if let` | action/label and title/action declarations, iOS 13+ | MainActor conversions; concrete title overload |
| draggable / dropDestination | String payloads; preview ViewBuilder; drop closure has two arguments and Bool return; isTargeted takes Bool | Transferable payload/preview and typed drop signatures, iOS 16+ | Concrete conformance, preview types, contextual return and isolation |
| accessibility label/hint/value | Text, literal/localized/dynamic String values; no bare handler used as text | Text/StringProtocol/LocalizedStringKey forms, iOS 14+ | Concrete overload/context; localization rendering |
| accessibility element/traits/hidden | Labeled child behavior, trait values, Bool expressions | Corresponding SwiftUI declarations, iOS 13/14+ | SDK/compiler and VoiceOver tree |
| Generic bare values | Fonts, Colors/styles, IDs, tags, text, Bool flags; callbacks distinguished from ordinary data | Font?, ShapeStyle, Hashable, StringProtocol and Bool parameter shapes | Generic inference and actual contextual types |
| New visual/presentation work | ViewBuilder branches, explicit returns, CGFloat/frame labels and color/gradient inputs inspected | Font.system, frame, fill/strokeBorder, background, foregroundStyle, scaleEffect, lineLimit, ViewThatFits/GeometryReader, animation, presentation and sensoryFeedback declarations | Full generated types, actor diagnostics and rendered result |
| Swift/custom false positives | Collection flatMap/init, session selection, speech, repository calls; declaration/caller comparison | Not treated as SwiftUI handler overloads | Swift compiler and behavior |

Primary authorities beyond the accessibility links above: [tap](https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:perform:)), [appear](https://developer.apple.com/documentation/swiftui/view/onappear(perform:)), [disappear](https://developer.apple.com/documentation/swiftui/view/ondisappear(perform:)), [two-value change](https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)-4psgg), [current task](https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:)), [sheet](https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)), [Button](https://developer.apple.com/documentation/swiftui/button/init(action:label:)), [drag](https://developer.apple.com/documentation/swiftui/view/draggable(_:)), [drop](https://developer.apple.com/documentation/swiftui/view/dropdestination(for:action:istargeted:)). The export records all retrieved declarations and their availability metadata, including disambiguated overload pages rather than relying on a group's default page.

Apple's live documentation is authoritative for its published signatures, but is not a dump of the user's Xcode 26.6 SDK. It already includes some newer task/Binding annotations and future iOS 27 deprecations. No migration is inferred from those. The inspected call forms have applicable documented iOS 17-or-earlier APIs; that source/documentation comparison is not an SDK availability check. No local Swift/Swiftc or usable Swift parser was found; no toolchain was installed.

## Repeated committed Swift review

Baseline `b1c3e811da1dc72e3c0204c82e6c9596b8d85a9c` remains the last evidenced compile-clean app/test checkpoint (Gate #6; assertions failed). Gate #5 built all four apps at `7bc1511`; no Sources changes separate those two gates. The reviewed starting range `b1c3e81..d2d8d79` contains 26 commits and 56 changed Swift files: 38 production, 18 tests, 2,649 additions and 609 removals. The union of touched paths equals the net diff inventory. Every committed Swift diff was reviewed again, with containing declarations and related source contracts inspected as needed. The final checkpoint adds only the Cards expression to that Swift range; the file inventory remains 56.

The following table records A evidence per file. B applies to the documented API families above wherever present; no row claims compiler overload resolution. C remains open for every file, including XCTest compilation/execution. New/changed result builders, speech/lifecycle closures, actor-owned players, optional callbacks, and Text/String overloads received the separate family review above.

| File | A: source contract re-inspected (B/C limits above apply) |
|---|---|
| Sources/ActivityCatalog.swift | Existing activity cases and section arrays |
| Sources/BuildSession.swift | Optional content unwrap, token dictionary, String/Character construction |
| Sources/BuildView.swift | Presentation case, initializer defaults/order, StateObject, per-token tracker and speech calls |
| Sources/CardsSession.swift | StudyCardID overload and Bool return |
| Sources/CardsView.swift | Complete view/history; default activation intent, manual/timed advance signatures, captured identity and cancellation; invalid accessibility call repaired |
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
| Sources/MinikActivityHubView.swift | Route cases and destinations; constructor labels/defaults; Binding getter/setter bodies and presentation content |
| Sources/MinikHomeVisuals.swift | Defaulted usesArtwork input, matching LinearGradient branches and removed helper |
| Sources/MinikPracticeVisuals.swift | Complete component declarations, corrected feedbackState scope, same-type gradient branches and result-builder boundaries |
| Sources/MinikVisualAssets.swift | Activity switch, asset member declarations and default ContentMode |
| Sources/MultipleChoiceView.swift | Entire view, feedback mapping, identity helper, presentation cases and speech/attempt APIs |
| Sources/PairsView.swift | Existing selection-style case, ViewBuilder branch and artwork API |
| Sources/ParentAreaView.swift | Initializer/callbacks, settingsHeading signature, ViewThatFits and new ButtonStyle |
| Sources/PingPongRallyModel.swift | CGFloat arithmetic and first/second-bounce definite initialization |
| Sources/PingPongScene.swift | Table/arena CGRect members, CGSize/CGPoint types and strike signature |
| Sources/PingPongView.swift | Font.system labels and TextStyle/size inputs; callback declarations and optional exit unwrapping |
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

## Findings, regression guard, and validation

Additional concrete source/API defects found by this repeated review: **none identified**. This records the outcome of inspection, not acceptance by the compiler or assurance that no hidden defect remains.

Unresolved candidates are the actual MainActor callback conversions (speech stop/appearance/Button), task isolation/signature under the exact SDK, Binding isolation, and SwiftUI generic/result-builder expressions listed above. Their source shape did not establish another invalid call, so they were left unchanged. The full candidate export preserves their locations. Text versus String/LocalizedStringKey overload selection also remains compiler-dependent despite matching documented families.

`Scripts/audit-cards-swiftui-api.ps1` rejects the historical bare call, requires one explicit default action on the button-trait tap surface, checks manual advance/speech stop and the existing hint, and is invoked by the Word Cards audit. Six in-memory mutations cover the historical call, missing action, wrong action kind, custom action substitution, wrong handler, and commented-out repair. `-ReportCandidates` inventories the requested families plus generic bare arguments and labeled references without assigning compiler-error status. This is a focused textual contract, not a Swift parser or regex substitute for Xcode.

All 21 applicable Windows scripts returned exit code 0 using the bundled PowerShell 7 with `-NoProfile -ExecutionPolicy Bypass -File`. The bypass is process-only; no policy/configuration changed. An earlier direct invocation was blocked by shell execution policy; process-only invocation passed. Exact commands and outputs are preserved in the external analysis.

| Script | Exact result (exit 0 for every row) |
|---|---|
| audit-product-configuration-tests.ps1 | PRODUCT_CONFIGURATION_TEST_FILES_AUDITED=80; PRODUCT_CONFIGURATION_TEST_LINES_AUDITED=16063; MANIFEST_ENTRY_CALLS_AUDITED=2; TEST_MANIFEST_ENTRY_CALLS_AUDITED=1; LEARNING_TEXT_CALLS_AUDITED=33; OPTIONAL_ANDROID_WORD_ID_INTERPOLATIONS=0; TEST_OPAQUE_VIEW_RETURN_SITES=0; PRODUCT_CONFIGURATION_TEST_COMPATIBILITY_ERRORS=0 |
| audit-localization.ps1 | LIKELY_USER_VISIBLE_HARDCODED_STRINGS=0; DYNAMIC_USER_VISIBLE_UNLOCALIZED_STRINGS=0; MISSING_CATALOG_KEYS=0; CATALOG_ERRORS=0 |
| validate-localization-catalog.ps1 | 469 keys; 11 Full locales; 10 English Only locales |
| audit-language-visuals.ps1 | LANGUAGE_VISUAL_CONTRACTS_AUDITED=41; LANGUAGE_VISUAL_CONTRACT_ERRORS=0; PASS: MinikChoiceButtonStyle state/palette/caller/accessibility source contract.; LANGUAGE_VISUAL_AUDIT_OK |
| audit-language-speech.ps1 | LANGUAGE_SPEECH_CONTRACTS_AUDITED=27; LANGUAGE_SPEECH_CONTRACT_ERRORS=0; LANGUAGE_SPEECH_STATIC_AUDIT_OK |
| audit-language-mixed.ps1 | LANGUAGE_MIXED_CONTRACTS_AUDITED=21; LANGUAGE_MIXED_CONTRACT_ERRORS=0; LANGUAGE_MIXED_AUDIT_OK |
| audit-language-word-cards.ps1 | LANGUAGE_WORD_CARDS_CONTRACTS_AUDITED=23; LANGUAGE_WORD_CARDS_CONTRACT_ERRORS=0; CARDS_SWIFTUI_API_CONTRACT_OK; LANGUAGE_WORD_CARDS_AUDIT_OK |
| audit-language-soccer.ps1 | LANGUAGE_SOCCER_CONTRACTS_AUDITED=52; LANGUAGE_SOCCER_CONTRACT_ERRORS=0; LANGUAGE_SOCCER_AUDIT_OK |
| audit-language-tower.ps1 | LANGUAGE_TOWER_CONTRACTS_AUDITED=25; LANGUAGE_TOWER_CONTRACT_ERRORS=0; LANGUAGE_TOWER_AUDIT_OK |
| audit-language-picture-memory.ps1 | LANGUAGE_PICTURE_MEMORY_CONTRACTS_AUDITED=23; LANGUAGE_PICTURE_MEMORY_CONTRACT_ERRORS=0; LANGUAGE_PICTURE_MEMORY_AUDIT_OK |
| audit-language-tic-tac-toe.ps1 | LANGUAGE_TIC_TAC_TOE_CONTRACTS_AUDITED=30; LANGUAGE_TIC_TAC_TOE_CONTRACT_ERRORS=0; LANGUAGE_TIC_TAC_TOE_AUDIT_OK |
| audit-language-production-parity.ps1 | LANGUAGE_PRODUCTION_PARITY_RECORDS_AUDITED=13; LANGUAGE_PRODUCTION_PARITY_ERRORS=0; LANGUAGE_PRODUCTION_PARITY_LOCK_OK |
| audit-english-only-production-policy.ps1 | ENGLISH_ONLY_POLICY_CONTRACTS_AUDITED=22; ENGLISH_ONLY_POLICY_ERRORS=0; ENGLISH_ONLY_PRODUCTION_POLICY_OK |
| audit-english-only-parity.ps1 | ENGLISH_ONLY_CATALOG_KEYS=469; ENGLISH_ONLY_CATALOG_LOCALES=10; ENGLISH_ONLY_SURFACES_AUDITED=16; ENGLISH_ONLY_PARITY_ERRORS=0; ENGLISH_ONLY_PRODUCT_PARITY_OK |
| audit-minik-visual-assets.ps1 | MINIK_VISUAL_ASSETS_EXPECTED=36; MINIK_VISUAL_ASSET_ERRORS=0; MINIK_VISUAL_ASSET_AUDIT_OK |
| audit-minik-visual-provenance.ps1 | MINIK_VISUAL_PROVENANCE_ROWS=36; MINIK_VISUAL_PROVENANCE_ERRORS=0; MINIK_VISUAL_PROVENANCE_AUDIT_OK |
| validate-math-assets.ps1 | MATH_ASSET_ERRORS=0; MATH_OBJECTS=100; MATH_ZERO_STATES=3; MATH_GROUPING_SUPPORT=6; MATH_ASSET_CATEGORIES=10 |
| audit-math-visual-consistency.ps1 | MATH_VISUAL_IDENTITIES_AUDITED=13; MATH_VISUAL_REPRESENTATIVE_LEVELS=M1,M5,M10; MATH_VISUAL_SHARED_SCREENS_AUDITED=12; MATH_VISUAL_ERRORS=0; MATH_VISUAL_CONSISTENCY_OK |
| audit-ios-simulator-workflow.ps1 | IOS_SIMULATOR_WORKFLOW_ERRORS=0; IOS_SIMULATOR_WORKFLOW_TRIGGER=workflow_dispatch; IOS_SIMULATOR_WORKFLOW_TEST_COMMANDS=1; IOS_SIMULATOR_WORKFLOW_RETENTION_UPLOADS=6; WORKFLOW_DIRECTORY_AUTOMATIC_TRIGGER_ERRORS=0; WORKFLOW_DIRECTORY_FILES_AUDITED=4 |
| audit-minik-practice-visuals.ps1 -SelfTest | PASS: seven in-memory regression mutations rejected; repaired source accepted.; PASS: MinikChoiceButtonStyle state/palette/caller/accessibility source contract. |
| audit-cards-swiftui-api.ps1 -SelfTest | CARDS_SWIFTUI_API_SELF_TESTS=6 rejected mutations; current source accepted; SWIFTUI_SCAN_SOURCE_FILES=133; CARDS_SWIFTUI_API_CONTRACT_OK |

The Cards run also used `-ReportCandidates`. The workflow audit only read four workflow definitions and reported zero automatic-trigger errors; nothing was dispatched. Final diff/staged-check and preservation results are recorded in the external analysis.


Required Mac follow-up remains: compile all four app schemes at the resulting checkpoint, compile/run ProductConfigurationTests, compile assets/String Catalogs, then confirm Cards VoiceOver default activation, speech, manual/automatic progression, lifecycle timing, and relevant visual/Reduce Motion behavior in Simulator/device. This session neither compiles Xcode nor executes XCTest, CI, or workflows.

The initially empty index and all 805 pre-existing modified/deleted/untracked paths were captured before editing with SHA-256 or a missing-file marker, plus the root AGENTS.md hash and exact short status. The external final analysis records comparison results, final HEAD/status, the complete preservation manifest, and the exact checkpoint patch. No Phase 41 path or AGENTS.md belongs in this checkpoint. No push, fetch, workflow-trigger change, reset, stash, clean, rebase, or amend is part of this repair.
