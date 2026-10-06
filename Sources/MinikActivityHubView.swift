import SwiftUI

struct MinikActivityHubView: View {
    private enum Route {
        case language(LanguageActivityKind, LanguageIdentifier, UUID)
        case math(MathProductionActivityID, MathCurriculumLevelID, UUID)
        case ticTacToe(UUID)
        case pingPong(UUID)
        case parentArea
        case progress
        case records(returnToParentArea: Bool)
        case recordsLeaderboard([RemoteRecordPlacement])
    }

    let configuration: ProductConfiguration
    @ObservedObject private var interfaceLocaleController: InterfaceLocaleController
    @ObservedObject private var learningReminderController: LearningReminderController
    @ObservedObject private var commerceController: MinikCommerceController
    private let adCoordinator: MinikAdCoordinator

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedLanguage: LanguageIdentifier
    @State private var mathLevelController: MathLevelController
    @State private var languageActivitySessionID = ActivitySessionID()
    @State private var mathActivitySessionID = ActivitySessionID()
    @State private var route: Route?
    @State private var languageMenuIsPresented = false
    @State private var hasShownLanguageOpening = false
    @State private var languageRewards = RewardState()
    @State private var languageWordBonusRun = 0
    @State private var pingPongCompletedMatchCount = 0
    @State private var languageLevelSettings: LanguageParentLevelSettings
    @State private var languageAutoState: LanguageAutoProgressionState
    @State private var publicAliasPromptIsPresented = false
    @State private var publicAliasChoices: [PublicLeaderboardAlias] = []
    @State private var publicAliasIsSaving = false
    @State private var pendingPublicationNoticeIsPresented = false
    @State private var lastPendingNoticeKey: String?
    @StateObject private var publicLeaderboardController: PublicLeaderboardController

    private let mathFactory: MathActivitySessionFactory
    private let mathM1Factory: MathM1ActivitySessionFactory?
    private let mathM2Factory: MathM2ActivitySessionFactory?
    private let mathM3Factory: MathM3ActivitySessionFactory?
    private let mathM4Factory: MathM4ActivitySessionFactory?
    private let mathM5Factory: MathM5ActivitySessionFactory?
    private let mathM6Factory: MathM6ActivitySessionFactory?
    private let mathM7Factory: MathM7ActivitySessionFactory?
    private let mathM8Factory: MathM8ActivitySessionFactory?
    private let mathM9Factory: MathM9ActivitySessionFactory?
    private let mathM10Factory: MathM10ActivitySessionFactory?
    private let progressRepository: LocalProgressRepository
    @State private var wordRewardService: LanguageWordPracticeRewardService
    private let rewardRepository: LocalRewardRepository
    private let rewardService: LocalRewardService
    private let rewardRecordSubmissionService: RewardRecordSubmissionService
    @State private var outcomeDispatcher: ActivityOutcomeDispatcher

    private let learnedLanguageRepository: LearnedLanguageRepository
    private let languageLevelRepository: LanguageParentLevelSettingsRepository
    private let languageAutoRepository: LanguageAutoProgressRepository

    @MainActor
    init(
        configuration: ProductConfiguration,
        interfaceLocaleController: InterfaceLocaleController,
        learningReminderController: LearningReminderController,
        commerceController: MinikCommerceController,
        adCoordinator: MinikAdCoordinator,
        learnedLanguageRepository: LearnedLanguageRepository = LearnedLanguageRepository(),
        languageLevelRepository: LanguageParentLevelSettingsRepository = LanguageParentLevelSettingsRepository(),
        languageAutoRepository: LanguageAutoProgressRepository = LanguageAutoProgressRepository(),
        remoteRecordsRepository: (any RecordsRepository)? = nil
    ) {
        self.configuration = configuration
        self.interfaceLocaleController = interfaceLocaleController
        self.learningReminderController = learningReminderController
        self.commerceController = commerceController
        self.adCoordinator = adCoordinator
        self.learnedLanguageRepository = learnedLanguageRepository
        self.languageLevelRepository = languageLevelRepository
        self.languageAutoRepository = languageAutoRepository
        self.mathFactory = MathActivitySessionFactory(configuration: configuration)
        let progressRepository = LocalProgressRepository()
        self.progressRepository = progressRepository
        let rewardRepository = LocalRewardRepository()
        let rewardService = LocalRewardService(repository: rewardRepository)
        self.rewardRepository = rewardRepository
        self.rewardService = rewardService
        let rewardScope = RewardScope(
            ownerID: .localDefault,
            product: configuration.variant
        )
        let publicLeaderboardStore = UserDefaultsPublicLeaderboardStateStore(scope: rewardScope)
        let resolvedRecordsRepository = remoteRecordsRepository
            ?? ProductionRecordsRepositoryFactory.make(
                for: configuration.variant,
                ownerID: rewardScope.ownerID,
                publicLeaderboardStore: publicLeaderboardStore
            )
        let rewardRecordSubmissionService = RewardRecordSubmissionService(
            scope: rewardScope,
            repository: resolvedRecordsRepository,
            localStateStore: publicLeaderboardStore
        )
        self.rewardRecordSubmissionService = rewardRecordSubmissionService
        _publicLeaderboardController = StateObject(wrappedValue: PublicLeaderboardController(
            service: rewardRecordSubmissionService
        ))
        let wordRewardService = LanguageWordPracticeRewardService(repository: rewardRepository)
        _wordRewardService = State(initialValue: wordRewardService)
        _languageRewards = State(initialValue: ((try? rewardRepository.loadLedger()) ?? RewardLedger()).state(
            for: RewardScope(ownerID: .localDefault, product: configuration.variant)
        ))
        _outcomeDispatcher = State(initialValue: ActivityOutcomeDispatcher(
            progressSink: progressRepository,
            rewardHandler: { event in
                if let rewardEvent = LanguageLetterPairsRewardMapper.rewardEvent(for: event) {
                    _ = try rewardService.process(rewardEvent, policy: .androidLetterPairsReference)
                }
                if let rewardEvent = LanguageTowerRewardMapper.rewardEvent(for: event) {
                    _ = try rewardService.process(rewardEvent, policy: .androidTowerReference)
                }
                if let rewardEvent = LanguagePictureMemoryRewardMapper.rewardEvent(for: event) {
                    _ = try rewardService.process(rewardEvent, policy: .androidPictureMemoryReference)
                }
                try wordRewardService.processAttempt(event)
            }
        ))
        self.mathM1Factory = configuration.variant == .minikMath
            ? MathM1ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM2Factory = configuration.variant == .minikMath
            ? MathM2ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM3Factory = configuration.variant == .minikMath
            ? MathM3ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM4Factory = configuration.variant == .minikMath
            ? MathM4ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM5Factory = configuration.variant == .minikMath
            ? MathM5ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM6Factory = configuration.variant == .minikMath
            ? MathM6ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM7Factory = configuration.variant == .minikMath
            ? MathM7ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM8Factory = configuration.variant == .minikMath
            ? MathM8ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM9Factory = configuration.variant == .minikMath
            ? MathM9ActivitySessionFactory(configuration: configuration)
            : nil
        self.mathM10Factory = configuration.variant == .minikMath
            ? MathM10ActivitySessionFactory(configuration: configuration)
            : nil
        _selectedLanguage = State(initialValue:
            learnedLanguageRepository.load(for: configuration)
                ?? Self.defaultLearnedLanguage(for: configuration)
        )
        let initialLanguageSettings = configuration.contentDomain == .language
            ? languageLevelRepository.load(for: configuration.variant)
            : .androidDefault
        _languageLevelSettings = State(initialValue: initialLanguageSettings)
        _languageAutoState = State(initialValue: languageAutoRepository.load(
            scope: LanguageAutoScope(product: configuration.variant),
            currentLevel: initialLanguageSettings.wordLevel
        ))
        let persistedMathState = LocalMathLevelRepository().load()
        let mathController = MathLevelController(state: persistedMathState)
        _mathLevelController = State(initialValue: mathController)
    }

    private var languageFactory: LanguageActivitySessionFactory {
        LanguageActivitySessionFactory(
            configuration: configuration,
            vocabularyLevel: languageLevelSettings.wordLevel,
            vocabularyRamp: languageAutoState.ramp
        )
    }

    private var reloadedLanguageFactory: LanguageActivitySessionFactory {
        let settings = languageLevelRepository.load(for: configuration.variant)
        let state = languageAutoRepository.load(
            scope: LanguageAutoScope(product: configuration.variant),
            currentLevel: settings.wordLevel
        )
        return LanguageActivitySessionFactory(
            configuration: configuration,
            vocabularyLevel: settings.wordLevel,
            vocabularyRamp: state.ramp
        )
    }

    var body: some View {
        ZStack {
            destination
                .environment(\.languageRewardState, languageRewards)
                .environment(\.languageWordBonusRun, languageWordBonusRun)
                .environment(\.languageEncouragementEnabled, EncouragementPreferenceRepository().load(for: configuration.variant))
        }
        .overlay {
            if configuration.contentDomain == .language, case .parentArea = route {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    parentAreaContent
                }
            }
        }
        .overlay {
            if configuration.contentDomain == .language && !hasShownLanguageOpening {
                LanguageOpeningView(onFinish: { hasShownLanguageOpening = true })
            }
        }
        .overlay {
            if publicAliasPromptIsPresented {
                publicAliasPrompt
            } else if pendingPublicationNoticeIsPresented {
                pendingPublicationNotice
            }
        }
        .sheet(isPresented: parentAreaPresented) {
            parentAreaContent
                .presentationDetents([.fraction(0.82), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
                .presentationCornerRadius(34)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard configuration.contentDomain == .language,
                  oldPhase != .background,
                  newPhase == .background else { return }
            languageAutoState.applicationDidStop()
            languageAutoRepository.save(languageAutoState)
        }
        .onAppear(perform: applyStoreScreenshotScene)
    }

    /// App Store screenshot captures open one screen at launch; see StoreScreenshotScene.
    private func applyStoreScreenshotScene() {
        guard let scene = StoreScreenshotScene.name, route == nil else { return }
        hasShownLanguageOpening = scene != "opening"
        if let raw = StoreScreenshotScene.value(after: "language"),
           let activity = LanguageActivityKind(rawValue: raw) {
            launchLanguageActivity(activity)
        } else if let raw = StoreScreenshotScene.value(after: "math"),
                  let activity = MathProductionActivityID(rawValue: raw) {
            route = .math(activity, selectedMathLevelID, UUID())
            mathActivitySessionID = ActivitySessionID()
        } else if scene == "progress" {
            route = .progress
        } else if scene == "parents" {
            route = .parentArea
        } else if scene == "menu" || scene == "menu.games" {
            // The Language activity menu; "menu.games" scrolls it to its end
            // (LanguageMenuView.applyStoreScreenshotScroll).
            languageMenuIsPresented = true
        }
    }

    private var parentAreaContent: some View {
        ParentAreaView(
            configuration: configuration,
            interfaceLocaleController: interfaceLocaleController,
            selectedLanguage: selectedLanguage,
            languageLevelSettings: languageLevelSettings,
            mathLevelState: configuration.contentDomain == .math ? mathLevelController.state : nil,
            learningReminderController: learningReminderController,
            commerceController: commerceController,
            publicLeaderboardController: publicLeaderboardController,
            onSelectLanguage: selectLearnedLanguage,
            onSetLanguageLevels: setLanguageLevels,
            onSetMathMode: setMathLevelMode,
            onSelectMathLevel: selectManualMathLevel,
            onShowProgress: { route = .progress },
            onShowRecords: { route = .records(returnToParentArea: true) },
            onExit: { route = nil }
        )
    }

    @ViewBuilder
    private var destination: some View {
        switch route {
        case .none, .parentArea:
            if configuration.contentDomain == .language {
                languageHome
            } else {
                hubBody
            }
        case .language(let activity, let language, let launchID):
            languageDestination(for: activity, language: language)
                .id(launchID)
        case .math(let activity, let levelID, let launchID):
            mathDestination(for: activity, levelID: levelID)
                .id(launchID)
        case .ticTacToe(let launchID):
            TicTacToeView(
                onResolvedRound: recordLanguageTicTacToeCompletion,
                onCompletedRound: { recordLanguageAdOpportunity(.languageTicTacToe) },
                onExit: returnToHub
            )
                .id(launchID)
        case .pingPong(let launchID):
            MathPingPongChooser(
                commerce: commerceController,
                onCompletedMatch: { recordLanguageAdOpportunity(.mathRound) },
                onExit: returnToHub
            )
                .id(launchID)
        case .progress:
            ProgressStatisticsView(
                model: progressReadModel,
                onBack: { route = .parentArea }
            )
        case .records(let returnToParentArea):
            RecordsStreaksView(
                model: recordsReadModel,
                onBack: { route = returnToParentArea ? .parentArea : nil }
            )
        case .recordsLeaderboard(let highlightedPlacements):
            RecordsLeaderboardView(
                product: configuration.variant,
                highlightedPlacements: highlightedPlacements,
                onClose: returnToHub
            )
        }
    }

    private var parentAreaPresented: Binding<Bool> {
        Binding(
            get: {
                if configuration.contentDomain != .language, case .parentArea = route { return true }
                return false
            },
            set: { isPresented in
                if !isPresented, case .parentArea = route {
                    route = nil
                }
            }
        )
    }

    /// The menu's Trophy opens the Top 20 as a dialog over the menu itself, as
    /// Android's RecordsLeaderboardDialogFragment does, so it needs no route.
    @ViewBuilder
    private var languageHome: some View {
        if languageMenuIsPresented {
            LanguageMenuView(
                configuration: configuration,
                learnedLanguage: selectedLanguage,
                onSelect: launchLanguageActivity,
                onHome: { languageMenuIsPresented = false; route = nil }
            )
        } else {
            LanguageIntroView(
                rewards: languageRewards,
                variant: configuration.variant,
                onPractice: { languageMenuIsPresented = true },
                onParentArea: { route = .parentArea }
            )
        }
    }

    private func launchLanguageActivity(_ activity: LanguageActivityKind) {
        languageActivitySessionID = ActivitySessionID()
        try? wordRewardService.beginSession(languageActivitySessionID, product: configuration.variant)
        languageWordBonusRun = wordRewardService.cleanWordRun
        if activity == .ticTacToe {
            route = .ticTacToe(UUID())
        } else {
            route = .language(activity, selectedLanguage, UUID())
        }
    }

    private var hubBody: some View {
        MinikHomeScreen { metrics in
            VStack(alignment: .leading, spacing: metrics.compact ? 20 : 26) {
                headerSection(compact: metrics.compact)

                if configuration.contentDomain == .math {
                    mathLevelStatusSection(compact: metrics.compact)
                }

                if configuration.contentDomain == .language {
                    MinikHomeSectionCard(compact: metrics.compact) {
                        VStack(alignment: .leading, spacing: metrics.compact ? 24 : 30) {
                            ForEach(ActivityCatalog.languageSections(for: configuration)) { section in
                                languageSection(
                                    section,
                                    compact: metrics.compact,
                                    availableWidth: metrics.contentMaxWidth
                                )
                            }
                        }
                    }
                }

                ForEach(ActivityCatalog.mathSections(
                    for: configuration,
                    levelID: selectedMathLevelID
                )) { section in
                    mathSection(
                        section,
                        compact: metrics.compact,
                        availableWidth: metrics.contentMaxWidth
                    )
                }

                ForEach(ActivityCatalog.productGameSections(for: configuration)) { section in
                    productGameSection(
                        section,
                        compact: metrics.compact,
                        availableWidth: metrics.contentMaxWidth
                    )
                }
            }
        }
    }

    private func headerSection(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            HStack(alignment: .center, spacing: compact ? 14 : 20) {
                MinikArtworkImage(name: MinikVisualAsset.logo)
                    .frame(width: compact ? 58 : 72, height: compact ? 58 : 72)

                Spacer(minLength: 8)

                Button {
                    route = nil
                } label: {
                    MinikArtworkImage(name: MinikVisualAsset.home)
                        .frame(width: compact ? 52 : 62, height: compact ? 52 : 62)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Home"))
                .accessibilityHint(String(localized: "Returns to the activity menu"))
                .accessibilityAddTraits(.isSelected)

                // Only products with a public leaderboard show the trophy;
                // like Android Math, iOS Math has none.
                if RemoteRecordsConfiguration.androidCompatible(for: configuration.variant) != nil {
                    Button {
                        route = .recordsLeaderboard([])
                    } label: {
                        MinikArtworkImage(name: MinikVisualAsset.trophy)
                            .frame(width: compact ? 42 : 50, height: compact ? 52 : 62)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Top 20 records"))
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                route = .parentArea
            } label: {
                Text("Parent Area")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.25, blue: 0.67))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.9), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Parent Area"))
            .accessibilityHint(String(localized: "Opens learning settings and progress"))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func mathLevelStatusSection(compact: Bool) -> some View {
        MinikHomeSectionCard(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 14 : 16) {
                Label(selectedMathLevel.title, systemImage: "wand.and.stars")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.14, green: 0.39, blue: 0.49))

                Text(selectedMathLevel.subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.31, green: 0.49, blue: 0.57))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: mathLevelController.state.mode == .automatic
                ? String(localized: "Automatic math level: %@")
                : String(localized: "Manual math level: %@"),
            selectedMathLevel.title
        ))
    }

    private func languageSection(
        _ section: ActivitySection<LanguageActivityKind>,
        compact: Bool,
        availableWidth: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            Text(section.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.14, green: 0.39, blue: 0.49))

            LazyVGrid(
                columns: cardColumns(for: availableWidth, compact: compact),
                spacing: compact ? 14 : 18
            ) {
                ForEach(section.activities) { activity in
                    activityCard(
                        title: activity.title,
                        subtitle: activity.subtitle,
                        symbolName: activity.symbolName,
                        theme: activity.theme,
                        artworkName: MinikVisualAsset.activityArtwork(
                            for: activity,
                            language: selectedLanguage
                        )
                    ) {
                        if activity == .ticTacToe {
                            route = .ticTacToe(UUID())
                        } else {
                            languageActivitySessionID = ActivitySessionID()
                            route = .language(activity, selectedLanguage, UUID())
                        }
                    }
                }
            }
        }
    }

    private func mathSection(
        _ section: ActivitySection<MathProductionActivityID>,
        compact: Bool,
        availableWidth: CGFloat
    ) -> some View {
        sectionBody(title: section.title, subtitle: section.subtitle, compact: compact) {
            LazyVGrid(
                columns: cardColumns(for: availableWidth, compact: compact),
                spacing: compact ? 14 : 18
            ) {
                ForEach(section.activities) { activity in
                    activityCard(
                        title: activity.title,
                        subtitle: activity.subtitle,
                        symbolName: activity.symbolName,
                        theme: activity.theme,
                        iconArtworkName: activity == .pingPong ? PingPongAssetNames.minikPong : nil
                    ) {
                        if activity.launchRoute(for: selectedMathLevelID) == .pingPong {
                            pingPongCompletedMatchCount = 0
                        }
                        route = .math(activity, selectedMathLevelID, UUID())
                        mathActivitySessionID = ActivitySessionID()
                    }
                }
            }
        }
    }

    private func productGameSection(
        _ section: ActivitySection<ProductGameKind>,
        compact: Bool,
        availableWidth: CGFloat
    ) -> some View {
        sectionBody(title: section.title, subtitle: section.subtitle, compact: compact) {
            LazyVGrid(
                columns: cardColumns(for: availableWidth, compact: compact),
                spacing: compact ? 14 : 18
            ) {
                ForEach(section.activities) { game in
                    activityCard(
                        title: game.title,
                        subtitle: game.subtitle,
                        symbolName: game.symbolName,
                        theme: game.theme,
                        iconArtworkName: game == .pingPong ? PingPongAssetNames.minikPong : nil
                    ) {
                        switch game {
                        case .pingPong:
                            pingPongCompletedMatchCount = 0
                            route = .pingPong(UUID())
                        }
                    }
                }
            }
        }
    }

    private func sectionBody<Content: View>(
        title: String,
        subtitle: String,
        compact: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        MinikHomeSectionCard(compact: compact) {
            VStack(alignment: .leading, spacing: compact ? 14 : 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.14, green: 0.39, blue: 0.49))

                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.31, green: 0.49, blue: 0.57))
                }

                content()
            }
        }
    }

    private func activityCard(
        title: String,
        subtitle: String,
        symbolName: String,
        theme: ActivityTheme,
        artworkName: String? = nil,
        iconArtworkName: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let artworkName {
                    VStack(spacing: 8) {
                        MinikArtworkImage(name: artworkName)
                            .frame(maxWidth: .infinity)
                            .frame(height: 92)

                    Text(title)
                        .font(.headline.weight(.bold))
                            .foregroundStyle(Color(red: 0.13, green: 0.39, blue: 0.49))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.24))
                                .frame(width: 54, height: 54)

                            if let iconArtworkName {
                                MinikArtworkImage(name: iconArtworkName)
                                    .frame(width: 46, height: 46)
                            } else {
                                Image(systemName: symbolName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        Text(subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title) + Text(verbatim: ". ") + Text(subtitle))
        }
        .buttonStyle(MinikHomeActivityCardStyle(theme: theme, usesArtwork: artworkName != nil))
    }

    private func cardColumns(for availableWidth: CGFloat, compact: Bool) -> [GridItem] {
        if dynamicTypeSize >= .accessibility1 {
            return [GridItem(.flexible(minimum: 0, maximum: 340), spacing: compact ? 14 : 18)]
        }

        let minimumWidth: CGFloat
        if availableWidth < 420 {
            minimumWidth = 150
        } else if availableWidth < 700 {
            minimumWidth = 170
        } else {
            minimumWidth = 210
        }

        return [GridItem(.adaptive(minimum: minimumWidth, maximum: 280), spacing: compact ? 14 : 18)]
    }

    @ViewBuilder
    private func languageDestination(
        for activity: LanguageActivityKind,
        language: LanguageIdentifier
    ) -> some View {
        switch activity {
        case .learn:
            if let session = languageFactory.makeLearnSession(for: language) {
                LearnView(
                    session: session,
                    presentation: .language,
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .multipleChoice:
            if let session = languageFactory.makeMultipleChoiceSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    progressActivityFamily: .multipleChoice,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .firstLetterChoices:
            if let session = languageFactory.makeFirstLetterChoicesSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    progressActivityFamily: .multipleChoice,
                    presentation: .firstLetterPictureToLetter,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    makeNextSession: { languageFactory.makeFirstLetterChoicesSession(for: language) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .firstLetterPictures:
            if let session = languageFactory.makeFirstLetterPicturesSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    progressActivityFamily: .multipleChoice,
                    presentation: .firstLetterLetterToPicture,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    makeNextSession: { languageFactory.makeFirstLetterPicturesSession(for: language) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .build:
            if let session = languageFactory.makeBuildSession(for: language) {
                BuildView(
                    session: session,
                    progressActivityFamily: .buildWord,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .pairs:
            if let session = languageFactory.makePairsSession(for: language) {
                PairsView(
                    session: session,
                    progressActivityFamily: .pairs,
                    languageSkillID: LanguageSkillIDs.letterWordAssociation,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .memory:
            if let session = languageFactory.makeMemorySession(for: language) {
                MemoryView(
                    session: session,
                    progressActivityFamily: .memory,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .wordBuild:
            if let session = languageFactory.makeWordBuildSession(for: language) {
                BuildView(
                    session: session,
                    progressActivityFamily: .buildWord,
                    presentation: .word,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onWordCompleted: { recordLanguageWordCompletion($0, activity: activity) },
                    languageAutoEvaluationLevel: languageLevelSettings.wordLevel,
                    onLanguagePoolExhausted: recordLanguagePoolBoundary,
                    nextLanguageAutoEvaluationLevel: {
                        languageLevelRepository.load(for: configuration.variant).wordLevel
                    },
                    makeNextSession: {
                        reloadedLanguageFactory.makeWordBuildSession(for: language)
                    },
                    onComplete: returnToHub,
                    onAdvance: { recordLanguageAdOpportunity(.languageWriteScreen) },
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .letterPairs:
            if let session = languageFactory.makeLetterPairsSession(for: language) {
                PairsView(
                    session: session,
                    progressActivityFamily: .pairs,
                    languageSkillID: LanguageSkillIDs.initialLetterAssociation,
                    makeNextSession: {
                        languageFactory.makeLetterPairsSession(for: language)
                    },
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .imageToWord:
            if let session = languageFactory.makeImageToWordSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    progressActivityFamily: .multipleChoice,
                    presentation: .pictureToWord,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    makeNextSession: { languageFactory.makeImageToWordSession(for: language) },
                    onComplete: returnToHub,
                    onAdvance: { recordLanguageAdOpportunity(.languageWriteScreen) },
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .wordToImage:
            if let session = languageFactory.makeWordToImageSession(for: language) {
                MultipleChoiceView(
                    session: session,
                    progressActivityFamily: .multipleChoice,
                    presentation: .wordToPicture,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    makeNextSession: { languageFactory.makeWordToImageSession(for: language) },
                    onComplete: returnToHub,
                    onAdvance: { recordLanguageAdOpportunity(.languageWriteScreen) },
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .wordMemory:
            if let session = languageFactory.makeWordMemorySession(for: language) {
                MemoryView(
                    session: session,
                    progressActivityFamily: .memory,
                    presentation: .languagePicture,
                    makeNextSession: {
                        languageFactory.makeWordMemorySession(for: language)
                    },
                    onLanguageGameCompleted: { eventID in
                        recordLanguagePictureMemoryCompletion(eventID: eventID)
                    },
                    onRoundCompleted: {
                        recordLanguageAdOpportunity(.languagePictureMemory)
                    },
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onComplete: returnToHub,
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .wordCards:
            if let session = languageFactory.makeWordCardsSession(for: language) {
                CardsView(session: session, onExit: returnToHub)
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .mixed:
            if let session = languageFactory.makeMixedPracticeSession(for: language) {
                LanguageMixedPracticeView(
                    session: session,
                    sessionFactory: languageFactory,
                    learnedLanguage: language,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onWordCompleted: { recordLanguageWordCompletion($0, activity: activity) },
                    onAdOpportunity: {
                        recordLanguageAdOpportunity(.languageWriteScreen)
                    },
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .soccer:
            if let practiceSession = languageFactory.makeSoccerPracticeSession(for: language) {
                LanguageSoccerView(
                    practiceSession: practiceSession,
                    productionConfiguration: LanguageSoccerProductionConfiguration(
                        parentSoccerLevel: languageLevelSettings.soccerLevel
                    ),
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onMatchResolved: recordLanguageSoccerCompletion,
                    onWordCompleted: { recordLanguageAdOpportunity(.languageSoccer) },
                    onPoolExhausted: recordLanguagePoolBoundary,
                    makeNextPracticeSession: {
                        reloadedLanguageFactory.makeSoccerPracticeSession(for: language)
                    },
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .tower:
            if let practiceSession = languageFactory.makeTowerPracticeSession(for: language) {
                TowerView(
                    languagePracticeSession: practiceSession,
                    onAttempt: { recordLanguageAttempt($0, activity: activity) },
                    onWordCompleted: {
                        recordLanguageTowerCompletion($0)
                        recordLanguageAdOpportunity(.languageTower)
                    },
                    onPoolExhausted: recordLanguagePoolBoundary,
                    makeNextPracticeSession: {
                        reloadedLanguageFactory.makeTowerPracticeSession(for: language)
                    },
                    onExit: returnToHub
                )
            } else {
                unavailableActivityView(title: activity.title)
            }
        case .ticTacToe:
            // Defensive destination for direct callers. Normal hub routing uses
            // Route.ticTacToe and never passes the learned language into the game.
            TicTacToeView(
                onResolvedRound: recordLanguageTicTacToeCompletion,
                onCompletedRound: { recordLanguageAdOpportunity(.languageTicTacToe) },
                onExit: returnToHub
            )
        }
    }

    @ViewBuilder
    private func mathDestination(
        for activity: MathProductionActivityID,
        levelID: MathCurriculumLevelID
    ) -> some View {
        if activity.launchRoute(for: levelID) == .pingPong {
            MathPingPongChooser(
                commerce: commerceController,
                onCompletedMatch: { recordLanguageAdOpportunity(.mathRound) },
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m1Production,
                  let mathM1Factory,
                  let session = mathM1Factory.makeSession(for: activity) {
            MathM1SessionView(
                session: session,
                sessionFactory: mathM1Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m2Production,
                  let mathM2Factory,
                  let session = mathM2Factory.makeSession(for: activity) {
            MathM2SessionView(
                session: session,
                sessionFactory: mathM2Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m3Production,
                  let mathM3Factory,
                  let session = mathM3Factory.makeSession(for: activity) {
            MathM3SessionView(
                session: session,
                sessionFactory: mathM3Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m4Production,
                  let mathM4Factory,
                  let session = mathM4Factory.makeSession(for: activity) {
            MathM4SessionView(
                session: session,
                sessionFactory: mathM4Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m5Production,
                  let mathM5Factory,
                  let session = mathM5Factory.makeSession(for: activity) {
            MathM5SessionView(
                session: session,
                sessionFactory: mathM5Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m6Production,
                  let mathM6Factory,
                  let session = mathM6Factory.makeSession(for: activity) {
            MathM6SessionView(
                session: session,
                sessionFactory: mathM6Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m7Production,
                  let mathM7Factory,
                  let session = mathM7Factory.makeSession(for: activity) {
            MathM7SessionView(
                session: session,
                sessionFactory: mathM7Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m8Production,
                  let mathM8Factory,
                  let session = mathM8Factory.makeSession(for: activity) {
            MathM8SessionView(
                session: session,
                sessionFactory: mathM8Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m9Production,
                  let mathM9Factory,
                  let session = mathM9Factory.makeSession(for: activity) {
            MathM9SessionView(
                session: session,
                sessionFactory: mathM9Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if activity.launchRoute(for: levelID) == .m10Production,
                  let mathM10Factory,
                  let session = mathM10Factory.makeSession(for: activity) {
            MathM10SessionView(
                session: session,
                sessionFactory: mathM10Factory,
                onAttempt: { recordMathAttempt($0, activity: activity) },
                onComplete: completeMathRound,
                onExit: returnToHub
            )
        } else if case .curriculumEngine(let engine)? = activity.launchRoute(for: levelID),
                  let session = mathFactory.makeSession(for: engine, levelID: levelID) {
            switch session {
            case .learn(let session):
                LearnView(session: session, onComplete: returnToHub, onExit: returnToHub)
            case .multipleChoice(let session):
                MultipleChoiceView(session: session, onComplete: returnToHub, onExit: returnToHub)
            case .build(let session):
                BuildView(session: session, onComplete: returnToHub, onExit: returnToHub)
            case .tower(let session):
                TowerView(session: session, onComplete: returnToHub, onExit: returnToHub)
            case .pairs(let session):
                PairsView(session: session, onComplete: returnToHub, onExit: returnToHub)
            case .memory(let session):
                MemoryView(session: session, onComplete: returnToHub, onExit: returnToHub)
            case .soccer(let session):
                SoccerView(session: session, onComplete: returnToHub, onExit: returnToHub)
            }
        } else {
            unavailableActivityView(title: activity.title)
        }
    }

    private func unavailableActivityView(title: String) -> some View {
        MinikHomeUnavailableView(
            title: String(
                format: String(localized: "%@ is unavailable right now"),
                title
            ),
            message: "This activity could not be loaded for the current product or content set.",
            onBack: returnToHub
        )
    }

    private func returnToHub() {
        if configuration.contentDomain == .language {
            languageMenuIsPresented = true
            switch route {
            case .language, .ticTacToe:
                submitLanguageRewardRecordCandidate()
            default:
                break
            }
        }
        route = nil
    }

    private func submitLanguageRewardRecordCandidate() {
        let state = ((try? rewardRepository.loadLedger()) ?? RewardLedger()).state(
            for: RewardScope(ownerID: .localDefault, product: configuration.variant)
        )
        let scope = RewardScope(ownerID: .localDefault, product: configuration.variant)
        let noticeKey = "\(state.points)-\(state.bestStreak)"
        Task {
            let result = await rewardRecordSubmissionService.submit(
                state: state,
                scope: scope,
                achievedAt: Date()
            )
            await MainActor.run { handleRecordSubmission(result, noticeKey: noticeKey) }
        }
    }

    private var publicAliasPrompt: some View {
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Great score!")
                    .font(.title.bold())
                    .foregroundStyle(Color(red: 0.12, green: 0.37, blue: 0.46))
                Text("Choose a fun public alias for the online leaderboard.")
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.27, green: 0.45, blue: 0.53))

                VStack(spacing: 10) {
                    ForEach(publicAliasChoices) { alias in
                        Button {
                            selectPublicAlias(alias)
                        } label: {
                            HStack(spacing: 12) {
                                if let avatar = alias.avatar {
                                    Image(systemName: avatar.symbolName)
                                        .frame(width: 24)
                                }
                                Text(verbatim: alias.publicAlias)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "checkmark.circle")
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(publicAliasIsSaving)
                    }
                }

                Button("Show different aliases") { rerollPublicAliases() }
                    .buttonStyle(.plain)
                    .disabled(publicAliasIsSaving)

                Text("Nothing is shared before you choose a public alias.")
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.35, green: 0.47, blue: 0.52))

                HStack(spacing: 14) {
                    Button("Not now") {
                        publicAliasPromptIsPresented = false
                        Task { await rewardRecordSubmissionService.dismissPublicAliasPrompt() }
                    }
                        .buttonStyle(.bordered)
                        .disabled(publicAliasIsSaving)
                }
                if publicAliasIsSaving {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Choosing alias"))
                }
            }
            .padding(28)
            .frame(maxWidth: 480)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    private var pendingPublicationNotice: some View {
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(red: 0.24, green: 0.64, blue: 0.45))
                    .accessibilityHidden(true)
                Text("Saved on this device")
                    .font(.title2.bold())
                    .foregroundStyle(Color(red: 0.12, green: 0.37, blue: 0.46))
                Text("This score is ready to publish when Online leaderboard is on and Firebase is available.")
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.27, green: 0.45, blue: 0.53))
                Button("Done") { pendingPublicationNoticeIsPresented = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(28)
            .frame(maxWidth: 480)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    /// `noticeKey` identifies the local best; "Saved on this device" is shown at
    /// most once per best, and never for a parent opt-out or an unconfigured build.
    private func handleRecordSubmission(_ result: RewardRecordSyncResult, noticeKey: String? = nil) {
        switch result {
        case .publicAliasRequired:
            rerollPublicAliases()
            publicAliasPromptIsPresented = true
        case .participationDisabled, .notConfigured:
            publicAliasPromptIsPresented = false
        case .failed:
            publicAliasPromptIsPresented = false
            if noticeKey == nil || noticeKey != lastPendingNoticeKey {
                lastPendingNoticeKey = noticeKey
                pendingPublicationNoticeIsPresented = true
            }
        case .saved(let placements):
            publicAliasPromptIsPresented = false
            if !placements.isEmpty {
                route = .recordsLeaderboard(placements)
            }
        case .noEligibleValue, .noNewRecord:
            break
        }
    }

    private func selectPublicAlias(_ alias: PublicLeaderboardAlias) {
        publicAliasIsSaving = true
        Task {
            let result = await rewardRecordSubmissionService.selectPublicAliasAndRetry(alias)
            await MainActor.run {
                publicAliasIsSaving = false
                publicAliasPromptIsPresented = false
                handleRecordSubmission(result)
            }
        }
    }

    private func rerollPublicAliases() {
        publicAliasChoices = PublicLeaderboardAliasGenerator().choices()
    }

    /// Like Android Math, a finished Math round is an ad opportunity.
    private func completeMathRound() {
        recordLanguageAdOpportunity(.mathRound)
        returnToHub()
    }

    private func recordLanguageAdOpportunity(_ opportunity: MinikAdOpportunity) {
        let removesAds = commerceController.isRemoveAdsActive
        Task {
            await adCoordinator.record(opportunity, isRemoveAdsActive: removesAds)
        }
    }

    private func recordPingPongCompletedMatch() {
        pingPongCompletedMatchCount += 1
        let isOpportunity = PingPongInterstitialPolicy().isOpportunity(
            afterCompletedMatch: pingPongCompletedMatchCount
        )
        guard isOpportunity else { return }
        let removesAds = commerceController.isRemoveAdsActive
        Task {
            await adCoordinator.record(.pingPongMatch, isRemoveAdsActive: removesAds)
        }
    }

    private func selectLearnedLanguage(_ language: LanguageIdentifier) {
        guard configuration.allowsLearnedLanguage(language) else { return }
        selectedLanguage = configuration.fixedLearnedLanguage ?? language
        learnedLanguageRepository.save(selectedLanguage, for: configuration)
    }

    private func setMathLevelMode(_ mode: MathLevelMode) {
        guard configuration.contentDomain == .math else { return }
        switch mode {
        case .automatic:
            mathLevelController.returnToAutomatic()
        case .manual:
            mathLevelController.setManualLevel(mathLevelController.state.activeLevelID)
        }
        LocalMathLevelRepository().save(mathLevelController.state)
    }

    private func selectManualMathLevel(_ levelID: MathCurriculumLevelID) {
        guard configuration.contentDomain == .math,
              mathLevelController.state.mode == .manual else { return }
        mathLevelController.setManualLevel(levelID)
        LocalMathLevelRepository().save(mathLevelController.state)
    }

    private var selectedMathLevel: MathCurriculumLevelDescriptor {
        MathCurriculumPolicy.level(for: selectedMathLevelID)
            ?? MathCurriculumPolicy.defaultRunnableLevel
    }

    private var selectedMathLevelID: MathCurriculumLevelID {
        mathLevelController.state.activeLevelID
    }

    private func recordMathAttempt(
        _ attempt: ActivityAttemptData,
        activity: MathProductionActivityID
    ) {
        let context = ActivityEventContext(
            product: .minikMath,
            activityID: ProgressActivityID(rawValue: "math.\(activity.rawValue)"),
            curriculumStageID: attempt.mathLevelID?.curriculumStageID,
            skillID: attempt.skillID
        )
        if let event = ActivityEvent(
            sessionID: mathActivitySessionID,
            context: context,
            kind: .gradedAttempt,
            occurredAt: Date(),
            attemptData: attempt
        ) {
            try? outcomeDispatcher.dispatch(event)
        }
        mathLevelController.record(attempt)
        LocalMathLevelRepository().save(mathLevelController.state)
    }

    private func recordLanguageAttempt(
        _ attempt: ActivityAttemptData,
        activity: LanguageActivityKind
    ) {
        let context = ActivityEventContext(
            product: configuration.variant,
            activityID: ProgressActivityID(rawValue: "language.\(activity.rawValue)"),
            skillID: attempt.skillID
        )
        guard let event = ActivityEvent(
            sessionID: languageActivitySessionID,
            context: context,
            kind: .gradedAttempt,
            occurredAt: Date(),
            attemptData: attempt
        ) else { return }
        try? outcomeDispatcher.dispatch(event)
        if let autoActivity = LanguageAutoEvidenceRouting.attemptActivity(
            for: attempt.activityFamily
        ),
           let contentItemID = attempt.languageContentItemID,
           let vocabularyLevel = attempt.languageVocabularyLevel {
            languageAutoState.record(
                id: event.id,
                evidence: LanguageAutoAttemptEvidence(
                    contentItemID: contentItemID,
                    vocabularyLevel: vocabularyLevel,
                    activity: autoActivity,
                    result: attempt.result
                )
            )
            languageAutoRepository.save(languageAutoState)
        }
        languageWordBonusRun = wordRewardService.cleanWordRun
        languageRewards = ((try? rewardRepository.loadLedger()) ?? RewardLedger()).state(
            for: RewardScope(ownerID: .localDefault, product: configuration.variant)
        )
    }

    private func recordLanguageWordCompletion(_ completion: LanguageWordCompletion, activity: LanguageActivityKind) {
        guard configuration.contentDomain == .language, activity == .wordBuild || activity == .mixed else { return }
        let now = Date()
        if let autoActivity = LanguageAutoEvidenceRouting.completionActivity(for: activity),
           let vocabularyLevel = completion.vocabularyLevel {
            languageAutoState.record(
                id: completion.id,
                evidence: LanguageAutoAttemptEvidence(
                    contentItemID: completion.contentItemID,
                    vocabularyLevel: vocabularyLevel,
                    activity: autoActivity,
                    result: .correct
                )
            )
            languageAutoRepository.save(languageAutoState)
        }
        try? wordRewardService.processCompletion(completion, sessionID: languageActivitySessionID,
                                                product: configuration.variant, occurredAt: now)
        if let event = ActivityEvent(id: completion.id, sessionID: languageActivitySessionID,
            context: ActivityEventContext(product: configuration.variant,
                activityID: ProgressActivityID(rawValue: "language.\(activity.rawValue)"), skillID: LanguageSkillIDs.wordConstruction),
            kind: .completed, occurredAt: now) {
            try? outcomeDispatcher.dispatch(event)
        }
        languageWordBonusRun = wordRewardService.cleanWordRun
        languageRewards = ((try? rewardRepository.loadLedger()) ?? RewardLedger()).state(
            for: RewardScope(ownerID: .localDefault, product: configuration.variant)
        )
    }

    private func setLanguageLevels(_ settings: LanguageParentLevelSettings) {
        guard configuration.contentDomain == .language else { return }
        languageLevelSettings = settings
        languageLevelRepository.save(settings, for: configuration.variant)
        languageAutoState.synchronizeCurrentLevel(settings.wordLevel)
        languageAutoRepository.save(languageAutoState)
    }

    private func recordLanguagePoolBoundary(_ boundary: LanguageAutoPoolBoundary) {
        guard configuration.contentDomain == .language else { return }
        var updatedSettings = languageLevelSettings
        let evaluation = languageAutoState.evaluate(
            boundary,
            settings: &updatedSettings
        )
        if case .promoted = evaluation {
            languageLevelSettings = updatedSettings
            languageLevelRepository.save(updatedSettings, for: configuration.variant)
        }
        languageAutoRepository.save(languageAutoState)
    }

    private func recordLanguageTowerCompletion(_ completion: LanguageTowerCompletion) {
        guard configuration.contentDomain == .language else { return }
        let event = ActivityEvent(
            id: completion.id,
            sessionID: languageActivitySessionID,
            context: ActivityEventContext(
                product: configuration.variant,
                activityID: ProgressActivityID(rawValue: "language.tower"),
                skillID: LanguageSkillIDs.wordConstruction
            ),
            kind: .completed,
            occurredAt: Date()
        )
        guard let event else { return }
        try? outcomeDispatcher.dispatch(event)
        languageRewards = ((try? rewardRepository.loadLedger()) ?? RewardLedger()).state(
            for: RewardScope(ownerID: .localDefault, product: configuration.variant)
        )
    }

    private func recordLanguagePictureMemoryCompletion(eventID: UUID) {
        let event = ActivityEvent(
            id: eventID,
            sessionID: languageActivitySessionID,
            context: ActivityEventContext(
                product: configuration.variant,
                activityID: ProgressActivityID(rawValue: "language.wordMemory"),
                skillID: LanguageSkillIDs.wordImageAssociation
            ),
            kind: .completed,
            occurredAt: Date()
        )
        guard let event else { return }
        try? outcomeDispatcher.dispatch(event)
        refreshLanguageRewards()
    }

    private func recordLanguageSoccerCompletion(_ outcome: LanguageSoccerMatchOutcome) {
        let eventID = UUID()
        let occurredAt = Date()
        if let reward = LanguageSoccerRewardMapper.rewardEvent(
            sourceEventID: eventID,
            product: configuration.variant,
            outcome: outcome,
            occurredAt: occurredAt
        ) {
            _ = try? rewardService.process(reward, policy: .androidSoccerReference)
        }
        refreshLanguageRewards()
    }

    private func recordLanguageTicTacToeCompletion(_ outcome: TicTacToeOutcome) {
        let eventID = UUID()
        let occurredAt = Date()
        if let reward = LanguageTicTacToeRewardMapper.rewardEvent(
            sourceEventID: eventID,
            product: configuration.variant,
            outcome: outcome,
            occurredAt: occurredAt
        ) {
            _ = try? rewardService.process(reward, policy: .androidTicTacToeReference)
        }
        refreshLanguageRewards()
    }

    private func refreshLanguageRewards() {
        languageRewards = ((try? rewardRepository.loadLedger()) ?? RewardLedger()).state(
            for: RewardScope(ownerID: .localDefault, product: configuration.variant)
        )
    }

    private var progressReadModel: EducationalProgressReadModel {
        EducationalProgressReadModelBuilder.make(
            snapshot: (try? progressRepository.loadSnapshot()) ?? ProgressSnapshot(),
            product: configuration.variant,
            mathLevelState: configuration.contentDomain == .math
                ? mathLevelController.state
                : nil
        )
    }

    private var recordsReadModel: LocalRecordsReadModel {
        LocalRecordsReadModelBuilder.make(
            ledger: (try? rewardRepository.loadLedger()) ?? RewardLedger(),
            product: configuration.variant
        )
    }

    private var headerSubtitle: String {
        switch configuration.contentDomain {
        case .language:
            return String(localized: "Jump into playful reading activities.")
        case .math:
            return String(localized: "Pick a math adventure and start playing.")
        case .game:
            return String(localized: "Play with Minik.")
        }
    }

    private static func defaultLearnedLanguage(for configuration: ProductConfiguration) -> LanguageIdentifier {
        configuration.fixedLearnedLanguage ??
            configuration.allowedLearnedLanguages.sorted { $0.rawValue < $1.rawValue }.first ??
            .english
    }
}
