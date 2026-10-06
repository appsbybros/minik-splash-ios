import XCTest
@testable import MinikPlus

final class ParentAreaPolicyTests: XCTestCase {
    func testParentAreaIsAvailableOnlyForEducationalProducts() {
        XCTAssertTrue(EducationalParentAreaPolicy.isAvailable(for: .minikPlus))
        XCTAssertTrue(EducationalParentAreaPolicy.isAvailable(for: .minikPlusEnglish))
        XCTAssertTrue(EducationalParentAreaPolicy.isAvailable(for: .minikMath))
        XCTAssertFalse(EducationalParentAreaPolicy.isAvailable(for: .minikPingPong))
    }

    func testEnglishOnlyAlwaysResolvesLearnedLanguageToEnglish() {
        let suite = "ParentAreaPolicyTests.EnglishOnly.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = LearnedLanguageRepository(userDefaults: defaults)
        let configuration = ProductConfiguration.configuration(for: .minikPlusEnglish)

        repository.save(.hebrew, for: configuration)

        XCTAssertEqual(repository.load(for: configuration), .english)
        XCTAssertFalse(configuration.isLearningLanguageSelectionAvailable)
    }

    func testFullLanguageProductPersistsSupportedLearnedLanguage() {
        let suite = "ParentAreaPolicyTests.Language.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = LearnedLanguageRepository(userDefaults: defaults)
        let configuration = ProductConfiguration.configuration(for: .minikPlus)

        repository.save(.hebrew, for: configuration)

        XCTAssertEqual(repository.load(for: configuration), .hebrew)
    }

    func testUnsetLearnedLanguageFollowsInterfaceLanguageLikeAndroid() {
        let suite = "ParentAreaPolicyTests.LearnedDefault.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let plus = ProductConfiguration.configuration(for: .minikPlus)
        let english = ProductConfiguration.configuration(for: .minikPlusEnglish)

        let hebrewInterface = LearnedLanguageRepository(userDefaults: defaults, interfaceLocale: { _ in .hebrew })
        XCTAssertEqual(hebrewInterface.load(for: plus), .english)
        XCTAssertEqual(hebrewInterface.load(for: english), .english)

        let otherInterface = LearnedLanguageRepository(userDefaults: defaults, interfaceLocale: { _ in .french })
        XCTAssertEqual(otherInterface.load(for: plus), .hebrew)
        XCTAssertEqual(otherInterface.load(for: english), .english)

        otherInterface.save(.english, for: plus)
        XCTAssertEqual(otherInterface.load(for: plus), .english)
    }

    func testEncouragementDefaultsOnAndPersistsPerProduct() {
        let suite = "ParentAreaPolicyTests.Encouragement.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = EncouragementPreferenceRepository(userDefaults: defaults)

        XCTAssertTrue(repository.load(for: .minikMath))
        repository.save(false, for: .minikMath)

        XCTAssertFalse(repository.load(for: .minikMath))
        XCTAssertTrue(repository.load(for: .minikPlus))
    }

    func testMathModeSwitchesKeepTheCurrentLevelAsStartingPoint() {
        var controller = MathLevelController()
        controller.setManualLevel(.m7)

        XCTAssertEqual(controller.state.mode, .manual)
        XCTAssertEqual(controller.state.activeLevelID, .m7)

        controller.returnToAutomatic()

        XCTAssertEqual(controller.state.mode, .automatic)
        XCTAssertEqual(controller.state.activeLevelID, .m7)
        XCTAssertEqual(controller.state.phase, .calibration)
    }

    func testAutomaticToManualInitializesAtCurrentAutomaticLevel() {
        var controller = MathLevelController(state: MathLevelState(
            mode: .automatic,
            activeLevelID: .m5,
            phase: .stable,
            previousLevelID: nil,
            firstAttemptWindow: [],
            consecutiveCorrect: 0,
            consecutiveUnsuccessful: 0,
            phaseAttemptCount: 0,
            phaseFailureCount: 0,
            cooldownRemaining: 0,
            timeBaselines: [:],
            verySlowSignalCount: 0
        ))

        controller.setManualLevel(controller.state.activeLevelID)

        XCTAssertEqual(controller.state.mode, .manual)
        XCTAssertEqual(controller.state.activeLevelID, .m5)
    }

    func testManualModeIgnoresAutomaticProgressionAttempts() throws {
        var controller = MathLevelController()
        controller.setManualLevel(.m4)
        let attempt = try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "manual-level-attempt"),
            attemptIndex: 1,
            result: .correct,
            activityFamily: .multipleChoice,
            mathLevelID: .m4
        ))

        for _ in 0..<20 { controller.record(attempt) }

        XCTAssertEqual(controller.state.mode, .manual)
        XCTAssertEqual(controller.state.activeLevelID, .m4)
    }

    func testParentInterfaceLocalePolicyMatchesProductPolicy() {
        XCTAssertEqual(
            InterfaceLocalePolicy.allowedLocales(for: .minikMath),
            InterfaceLocaleID.allCases
        )
        XCTAssertFalse(
            InterfaceLocalePolicy.allowedLocales(for: .minikPlusEnglish).contains(.hebrew)
        )
    }

    func testLanguageLevelDefaultsAndAllowedOrderMatchAndroid() {
        XCTAssertEqual(LanguageParentLevelSettings.androidDefault, LanguageParentLevelSettings(
            mode: .automatic,
            wordLevel: .a,
            soccerLevel: .a,
            ticTacToeLevel: .adaptive
        ))
        XCTAssertEqual(LanguageVocabularyLevel.allCases.map(\.rawValue), ["A", "B", "C", "D", "E"])
        XCTAssertEqual(LanguageSoccerLevel.allCases.map(\.rawValue), ["A", "B", "C"])
        XCTAssertEqual(
            TicTacToeLevel.allCases.map(\.rawValue),
            ["A", "B", "C", "D", "E", "RANDOM", "ADAPTIVE"]
        )
    }

    func testLanguageLevelsPersistAcrossRepositoryReentryAndRecoverInvalidValues() {
        let suite = "ParentAreaPolicyTests.LanguageLevels.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = LanguageParentLevelSettingsRepository(userDefaults: defaults)
        let selected = LanguageParentLevelSettings(
            mode: .manual,
            wordLevel: .d,
            soccerLevel: .c,
            ticTacToeLevel: .random
        )

        repository.save(selected, for: .minikPlus)
        XCTAssertEqual(
            LanguageParentLevelSettingsRepository(userDefaults: defaults).load(for: .minikPlus),
            selected
        )

        defaults.set("unknown", forKey: "minik.language-levels.v1.minikPlus.mode")
        defaults.set("Z", forKey: "minik.language-levels.v1.minikPlus.words")
        defaults.set("Z", forKey: "minik.language-levels.v1.minikPlus.soccer")
        defaults.set("Z", forKey: "minik.tic-tac-toe.selected-level")

        XCTAssertEqual(repository.load(for: .minikPlus), .androidDefault)
    }

    func testLanguageLevelsAreProductScopedAndIndependentOfOtherParentSettings() {
        let suite = "ParentAreaPolicyTests.LanguageLevelIsolation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let levels = LanguageParentLevelSettingsRepository(userDefaults: defaults)
        let learnedLanguage = LearnedLanguageRepository(userDefaults: defaults)
        let plus = ProductConfiguration.configuration(for: .minikPlus)

        var selected = LanguageParentLevelSettings.androidDefault
        selected.mode = .manual
        selected.wordLevel = .e
        levels.save(selected, for: .minikPlus)
        learnedLanguage.save(.hebrew, for: plus)
        EncouragementPreferenceRepository(userDefaults: defaults).save(false, for: .minikMath)

        XCTAssertEqual(levels.load(for: .minikPlus), selected)
        XCTAssertEqual(levels.load(for: .minikPlusEnglish).wordLevel, .a)
        XCTAssertEqual(levels.load(for: .minikMath).wordLevel, .a)
        XCTAssertEqual(learnedLanguage.load(for: plus), .hebrew)
        XCTAssertFalse(EncouragementPreferenceRepository(userDefaults: defaults).load(for: .minikMath))
    }

    func testSelectedWordLevelDrivesProductionVocabularyStageForBothLearnedLanguages() throws {
        let plus = ProductConfiguration.configuration(for: .minikPlus)
        let factory = LanguageActivitySessionFactory(configuration: plus, vocabularyLevel: .e)

        let englishCards = try XCTUnwrap(factory.makeWordCardsSession(for: .english))
        let hebrewCards = try XCTUnwrap(factory.makeWordCardsSession(for: .hebrew))
        let englishChoice = try XCTUnwrap(factory.makeImageToWordSession(for: .english))

        XCTAssertEqual(englishCards.currentCard.curriculumStage, LanguageCurriculumStageIDs.wordsLevelE)
        XCTAssertEqual(hebrewCards.currentCard.curriculumStage, LanguageCurriculumStageIDs.wordsLevelE)
        XCTAssertEqual(englishChoice.currentChallenge.curriculumStage, LanguageCurriculumStageIDs.wordsLevelE)
    }

    func testEnglishOnlyUsesItsSelectedVocabularyLevelWithoutChangingFixedEnglishPolicy() throws {
        let configuration = ProductConfiguration.configuration(for: .minikPlusEnglish)
        let factory = LanguageActivitySessionFactory(configuration: configuration, vocabularyLevel: .c)

        XCTAssertEqual(configuration.fixedLearnedLanguage, .english)
        XCTAssertNil(factory.makeWordCardsSession(for: .hebrew))
        XCTAssertEqual(
            try XCTUnwrap(factory.makeWordCardsSession(for: .english)).currentCard.curriculumStage,
            LanguageCurriculumStageIDs.wordsLevelC
        )
    }
}
