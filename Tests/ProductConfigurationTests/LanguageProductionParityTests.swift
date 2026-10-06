import XCTest
@testable import MinikPlus

final class LanguageProductionParityTests: XCTestCase {
    private let expectedSections: [(id: String, activities: [LanguageActivityKind])] = [
        ("letters", [.learn, .letterPairs, .firstLetterChoices, .firstLetterPictures]),
        ("words", [.mixed, .wordBuild, .imageToWord, .wordToImage, .wordCards]),
        ("games", [.soccer, .tower, .wordMemory, .ticTacToe])
    ]

    func testProductionCatalogExposesExactlyTheThirteenAndroidActivities() {
        let expectedKinds = expectedSections.flatMap(\.activities)

        XCTAssertEqual(expectedKinds.count, 13)
        XCTAssertEqual(LanguageActivityKind.productionKinds, expectedKinds)
        XCTAssertEqual(Set(expectedKinds).count, 13)

        for product in [ProductVariant.minikPlus, .minikPlusEnglish] {
            let sections = ActivityCatalog.languageSections(
                for: .configuration(for: product)
            )
            XCTAssertEqual(sections.map(\.id), expectedSections.map { $0.id })
            XCTAssertEqual(sections.map(\.activities), expectedSections.map { $0.activities })
        }
    }

    func testGenericEnginesAreNotSeparateProductionMenuActivities() {
        let internalOnly: Set<LanguageActivityKind> = [
            .multipleChoice, .build, .pairs, .memory
        ]

        XCTAssertTrue(internalOnly.isDisjoint(with: Set(LanguageActivityKind.productionKinds)))
        XCTAssertTrue(internalOnly.isSubset(of: Set(LanguageActivityKind.allCases)))
    }

    func testLearnCardsAndTicTacToeRemainOutsideMasteryProgress() {
        for activityID in ["language.learn", "language.wordCards", "language.ticTacToe"] {
            XCTAssertFalse(EducationalProgressActivityPolicy.isMasteryActivity(
                ProgressActivityID(rawValue: activityID)
            ))
        }
    }

    func testPictureMemoryIsGroupedAsAGameWithoutChangingProductionCount() throws {
        let sections = ActivityCatalog.languageSections(
            for: .configuration(for: .minikPlus)
        )
        let words = try XCTUnwrap(sections.first { $0.id == "words" })
        let games = try XCTUnwrap(sections.first { $0.id == "games" })

        XCTAssertFalse(words.activities.contains(.wordMemory))
        XCTAssertTrue(games.activities.contains(.wordMemory))
        XCTAssertEqual(sections.flatMap(\.activities).count, 13)
    }

    func testEveryLearnedLanguageProductionActivityHasItsIntendedSession() {
        let products: [(ProductVariant, [LanguageIdentifier])] = [
            (.minikPlus, [.english, .hebrew]),
            (.minikPlusEnglish, [.english])
        ]

        for (product, languages) in products {
            let factory = LanguageActivitySessionFactory(
                configuration: .configuration(for: product)
            )
            for language in languages {
                assertEducationalSessionsExist(factory: factory, language: language)
            }
        }
    }

    func testProductAndLearnedLanguagePoliciesAreComplete() {
        let englishOnly = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikMath)
        )

        assertEducationalSessionsDoNotExist(factory: englishOnly, language: .hebrew)
        assertEducationalSessionsDoNotExist(factory: math, language: .english)

        // Tic-Tac-Toe intentionally has no language-factory API: it is a
        // product-menu game whose session has no learned-language input.
        XCTAssertEqual(TicTacToeSession().level, .adaptive)
    }

    func testLanguageLearnUsesAndroidLoopingProgression() throws {
        for (product, language) in [
            (ProductVariant.minikPlus, LanguageIdentifier.english),
            (.minikPlus, .hebrew),
            (.minikPlusEnglish, .english)
        ] {
            let factory = LanguageActivitySessionFactory(
                configuration: .configuration(for: product)
            )
            let session = try XCTUnwrap(factory.makeLearnSession(for: language))

            XCTAssertEqual(session.progressionPolicy, .loopFromFinalCard)
        }
    }

    func testEveryProductionActivityUsesTheAndroidSourceArtworkMapping() {
        let english: [LanguageActivityKind: String] = [
            .learn: "minik_activity_learn_english",
            .letterPairs: "minik_activity_pairs",
            .firstLetterChoices: "minik_activity_first_letter_english",
            .firstLetterPictures: "minik_activity_first_letter_english",
            .mixed: "minik_activity_mixed",
            .wordBuild: "minik_activity_build",
            .imageToWord: "minik_activity_picture_to_word",
            .wordToImage: "minik_activity_word_to_picture",
            .wordCards: "minik_activity_cards",
            .soccer: "minik_activity_soccer",
            .tower: "minik_activity_tower",
            .wordMemory: "minik_activity_memory",
            .ticTacToe: "minik_activity_tic_tac_toe"
        ]
        var hebrew = english
        hebrew[.learn] = "minik_activity_learn_hebrew"
        hebrew[.firstLetterChoices] = "minik_activity_first_letter_hebrew"
        hebrew[.firstLetterPictures] = "minik_activity_first_letter_hebrew"
        hebrew[.wordBuild] = "minik_activity_build_hebrew"
        hebrew[.wordCards] = "minik_activity_cards_hebrew"

        XCTAssertEqual(english.count, 13)
        XCTAssertEqual(hebrew.count, 13)
        for activity in LanguageActivityKind.productionKinds {
            XCTAssertEqual(
                MinikVisualAsset.activityArtwork(for: activity, language: .english),
                english[activity],
                "English artwork mismatch for \(activity)"
            )
            XCTAssertEqual(
                MinikVisualAsset.activityArtwork(for: activity, language: .hebrew),
                hebrew[activity],
                "Hebrew artwork mismatch for \(activity)"
            )
        }

        XCTAssertEqual(
            english[.firstLetterChoices],
            english[.firstLetterPictures],
            "Android intentionally shares the First Letter source art"
        )
        XCTAssertNotEqual(english[.imageToWord], english[.wordToImage])
    }

    func testEnglishOnlyLocksTheSameThirteenRoutesToEnglishPolicy() {
        let full = ProductConfiguration.configuration(for: .minikPlus)
        let englishOnly = ProductConfiguration.configuration(for: .minikPlusEnglish)

        XCTAssertEqual(
            ActivityCatalog.languageSections(for: englishOnly).map(\.activities),
            ActivityCatalog.languageSections(for: full).map(\.activities)
        )
        XCTAssertEqual(
            ActivityCatalog.languageSections(for: englishOnly).flatMap(\.activities),
            LanguageActivityKind.productionKinds
        )
        XCTAssertEqual(LanguageActivityKind.productionKinds.count, 13)
        XCTAssertTrue(ActivityCatalog.mathSections(for: englishOnly, levelID: .m1).isEmpty)
        XCTAssertTrue(ActivityCatalog.productGameSections(for: englishOnly).isEmpty)
    }

    func testEnglishOnlyProductionArtworkNeverSelectsHebrewVariants() throws {
        for activity in LanguageActivityKind.productionKinds {
            let artwork = try XCTUnwrap(
                MinikVisualAsset.activityArtwork(for: activity, language: .english)
            )
            XCTAssertFalse(artwork.contains("hebrew"), "Hebrew artwork leaked into \(activity)")
        }
    }

    func testEnglishOnlySpeechBearingProductionSessionsUseEnglishLearnedSpeech() throws {
        let factory = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikPlusEnglish)
        )

        let learn = try XCTUnwrap(factory.makeLearnSession(for: .english))
        let learnText = learn.cards.flatMap(\.representations).compactMap(learningText)
        XCTAssertFalse(learnText.isEmpty)
        XCTAssertTrue(learnText.allSatisfy {
            $0.language == .english && $0.direction == .leftToRight
        })

        let cards = try XCTUnwrap(factory.makeWordCardsSession(for: .english))
        let cardText = cards.presentationCards.flatMap(\.representations).compactMap(learningText)
        XCTAssertFalse(cardText.isEmpty)
        XCTAssertTrue(cardText.allSatisfy {
            $0.language == .english && $0.direction == .leftToRight
        })

        let letterPairs = try XCTUnwrap(factory.makeLetterPairsSession(for: .english))
        let pairSpeech = (letterPairs.leftItems + letterPairs.rightItems)
            .compactMap(\.details.speechUtterance)
        XCTAssertFalse(pairSpeech.isEmpty)
        XCTAssertTrue(pairSpeech.allSatisfy { $0.language == .english })

        let soccer = try XCTUnwrap(factory.makeSoccerPracticeSession(for: .english))
        XCTAssertEqual(soccer.currentSpeechCue.language, .english)

        let tower = try XCTUnwrap(factory.makeTowerPracticeSession(for: .english))
        XCTAssertEqual(tower.currentSpeechCue.language, .english)
    }

    private func learningText(_ representation: Representation) -> LearningTextRepresentation? {
        guard case .learningText(let text) = representation else { return nil }
        return text
    }

    private func assertEducationalSessionsExist(
        factory: LanguageActivitySessionFactory,
        language: LanguageIdentifier,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(factory.makeLearnSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeLetterPairsSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeFirstLetterChoicesSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeFirstLetterPicturesSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeMixedPracticeSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeWordBuildSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeImageToWordSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeWordToImageSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeWordMemorySession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeWordCardsSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeSoccerPracticeSession(for: language), file: file, line: line)
        XCTAssertNotNil(factory.makeTowerPracticeSession(for: language), file: file, line: line)
    }

    private func assertEducationalSessionsDoNotExist(
        factory: LanguageActivitySessionFactory,
        language: LanguageIdentifier,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(factory.makeLearnSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeLetterPairsSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeFirstLetterChoicesSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeFirstLetterPicturesSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeMixedPracticeSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeWordBuildSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeImageToWordSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeWordToImageSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeWordMemorySession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeWordCardsSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeSoccerPracticeSession(for: language), file: file, line: line)
        XCTAssertNil(factory.makeTowerPracticeSession(for: language), file: file, line: line)
    }
}
