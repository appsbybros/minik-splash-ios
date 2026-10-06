import XCTest
@testable import MinikPlus

final class LanguageWordCardsContentProviderTests: XCTestCase {
    func testNilCategoryReturnsWholeLevelLexicalPool() throws {
        let cards = try cards(for: .english)
        let expectedItems = expectedItems(for: .english, categoryID: nil)

        XCTAssertEqual(cards.map(\.id), expectedItems.map(expectedCardID))
        XCTAssertGreaterThan(cards.count, LanguageWordContentProvider.levelAFruits.count)
        for (card, item) in zip(cards, expectedItems) {
            XCTAssertEqual(card.representations.count, 1)
            guard case .learningText(let text) = card.representations[0] else {
                return XCTFail("Expected a single learned-word representation.")
            }
            XCTAssertEqual(text.text, expectedLearningText(for: item, language: .english).text)
        }
    }

    func testHebrewReturnsSameStableContentIdentities() throws {
        let english = try cards(for: .english)
        let hebrew = try cards(for: .hebrew)

        XCTAssertEqual(hebrew.count, english.count)
        XCTAssertEqual(hebrew.map(\.id), english.map(\.id))
    }

    func testExplicitFruitsCategoryReturnsOnlyFruits() throws {
        let request = try makeRequest()
        let explicitEnglish = LanguageWordCardsContentProvider(
            configuration: .configuration(for: .minikPlus),
            categoryID: .fruits
        ).studyCards(for: request, learnedLanguage: .english)
        let explicitHebrew = LanguageWordCardsContentProvider(
            configuration: .configuration(for: .minikPlus),
            categoryID: .fruits
        ).studyCards(for: request, learnedLanguage: .hebrew)
        let expectedEnglishItems = expectedItems(for: .english, categoryID: .fruits)
        let expectedHebrewItems = expectedItems(for: .hebrew, categoryID: .fruits)

        XCTAssertEqual(explicitEnglish.map(\.id), expectedEnglishItems.map(expectedCardID))
        XCTAssertEqual(explicitHebrew.map(\.id), expectedHebrewItems.map(expectedCardID))
        XCTAssertEqual(explicitEnglish.map(\.id), expectedCardIDs)
        XCTAssertEqual(explicitHebrew.map(\.id), expectedCardIDs)
    }

    func testSentencesNeverEnterCards() throws {
        let request = try makeRequest(curriculumStage: LanguageCurriculumStageIDs.wordsLevelB)
        let cards = makeProvider().studyCards(for: request, learnedLanguage: .english)
        let sentenceIDs = Set(
            LanguageWordCatalog.items(for: .b)
                .filter { $0.contentKind == .sentence }
                .map(expectedCardID)
        )

        XCTAssertFalse(cards.isEmpty)
        XCTAssertTrue(sentenceIDs.isDisjoint(with: Set(cards.map(\.id))))
    }

    func testCrossLevelCardsRemainLexicalOnlyAndPreserveStableIDs() throws {
        for level in LanguageVocabularyLevel.allCases {
            for language in [LanguageIdentifier.english, .hebrew] {
                let cards = makeProvider().studyCards(
                    for: try makeRequest(curriculumStage: level.curriculumStageID),
                    learnedLanguage: language
                )
                let expectedItems = expectedItems(for: language, categoryID: nil, level: level)

                XCTAssertEqual(cards.map(\.id), expectedItems.map(expectedCardID))
                XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)

                let sentenceIDs = Set(
                    LanguageWordCatalog.items(for: level)
                        .filter { $0.contentKind == .sentence }
                        .map(expectedCardID)
                )
                XCTAssertTrue(sentenceIDs.isDisjoint(with: Set(cards.map(\.id))))
            }
        }
    }

    func testEnglishLearningTextMetadataIsEnglishAndLeftToRight() throws {
        for card in try cards(for: .english) {
            let text = try learnedText(in: card)
            XCTAssertEqual(text.language, .english)
            XCTAssertEqual(text.direction, .leftToRight)
        }
    }

    func testHebrewLearningTextMetadataIsHebrewAndRightToLeft() throws {
        for card in try cards(for: .hebrew) {
            let text = try learnedText(in: card)
            XCTAssertEqual(text.language, .hebrew)
            XCTAssertEqual(text.direction, .rightToLeft)
        }
    }

    func testHebrewKiwiPreservesSpeechCorrection() throws {
        let kiwiID = StudyCardID(rawValue: "study.language.words.fruits_kiwi")
        let kiwi = try XCTUnwrap(try cards(for: .hebrew).first { $0.id == kiwiID })

        XCTAssertEqual(try learnedText(in: kiwi).speechText, "Kiwi")
    }

    func testCardsPreserveRequestedStudyMetadata() throws {
        for card in try cards(for: .english) {
            XCTAssertEqual(card.primarySkill, LanguageSkillIDs.wordRecognition)
            XCTAssertEqual(card.curriculumStage, LanguageCurriculumStageIDs.wordsLevelA)
            XCTAssertEqual(card.secondarySkills, [])
        }
    }

    func testProductLanguagePolicyIsEnforced() throws {
        let request = try makeRequest()
        let plus = LanguageWordCardsContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnly = LanguageWordCardsContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageWordCardsContentProvider(
            configuration: .configuration(for: .minikMath)
        )

        XCTAssertEqual(
            plus.studyCards(for: request, learnedLanguage: .english).count,
            expectedItems(for: .english, categoryID: nil).count
        )
        XCTAssertEqual(
            plus.studyCards(for: request, learnedLanguage: .hebrew).count,
            expectedItems(for: .hebrew, categoryID: nil).count
        )
        XCTAssertEqual(englishOnly.studyCards(
            for: request,
            learnedLanguage: .english
        ).count, expectedItems(for: .english, categoryID: nil).count)
        XCTAssertEqual(englishOnly.studyCards(
            for: request,
            learnedLanguage: .hebrew
        ), [])
        XCTAssertEqual(math.studyCards(for: request, learnedLanguage: .english), [])
        XCTAssertEqual(math.studyCards(for: request, learnedLanguage: .hebrew), [])
        XCTAssertEqual(plus.studyCards(
            for: request,
            learnedLanguage: LanguageIdentifier(rawValue: "fr")
        ), [])
    }

    func testInvalidRequestShapesReturnNoCards() throws {
        let provider = makeProvider()
        let wrongActivity = try makeRequest(activityType: .learn)
        let wrongStage = try makeRequest(curriculumStage: LanguageCurriculumStageIDs.alphabet)
        let wrongSkill = try makeRequest(primarySkill: LanguageSkillIDs.wordImageAssociation)
        let wrongInteraction = try makeRequest(interaction: .singleChoice)
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 2))
        let wrongCount = try makeRequest(countRequirement: count)

        XCTAssertEqual(provider.studyCards(for: wrongActivity, learnedLanguage: .english), [])
        XCTAssertEqual(provider.studyCards(for: wrongStage, learnedLanguage: .english), [])
        XCTAssertEqual(provider.studyCards(for: wrongSkill, learnedLanguage: .english), [])
        XCTAssertEqual(provider.studyCards(for: wrongInteraction, learnedLanguage: .english), [])
        XCTAssertEqual(provider.studyCards(for: wrongCount, learnedLanguage: .english), [])
    }

    func testUnsupportedCategoryReturnsNoCardsWithoutFallingBackToFruits() throws {
        let provider = LanguageWordCardsContentProvider(
            configuration: .configuration(for: .minikPlus),
            categoryID: LanguageWordCategoryID(rawValue: "unsupported.test.category")
        )
        let request = try makeRequest()

        XCTAssertEqual(provider.studyCards(for: request, learnedLanguage: .english), [])
        XCTAssertEqual(provider.studyCards(for: request, learnedLanguage: .hebrew), [])
    }

    private var expectedCardIDs: [StudyCardID] {
        LanguageWordContentProvider.levelAFruits.map {
            StudyCardID(rawValue: "study.\($0.id.rawValue)")
        }
    }

    private func expectedItems(
        for language: LanguageIdentifier,
        categoryID: LanguageWordCategoryID?,
        level: LanguageVocabularyLevel = .a
    ) -> [LanguageWordCatalogItem] {
        let locale = locale(for: language)
        var seenNormalizedWords = Set<String>()

        return LanguageWordLevelContent.content(for: level).items(
            constrainedTo: categoryID,
            including: { $0.isLexical }
        ).compactMap { item in
            let learnedText = expectedLearningText(for: item, language: language)
            let normalizedKey = learnedText.text.lowercased(with: locale)
            guard seenNormalizedWords.insert(normalizedKey).inserted else {
                return nil
            }
            return item
        }
    }

    private func expectedLearningText(
        for item: LanguageWordCatalogItem,
        language: LanguageIdentifier
    ) -> LearningTextRepresentation {
        try! XCTUnwrap(
            LanguageWordContentProvider.learnedText(for: item, language: language)
        )
    }

    private func expectedCardID(
        for item: LanguageWordCatalogItem
    ) -> StudyCardID {
        StudyCardID(rawValue: "study.\(item.id.rawValue)")
    }

    private func cards(for language: LanguageIdentifier) throws -> [StudyCard] {
        makeProvider().studyCards(for: try makeRequest(), learnedLanguage: language)
    }

    private func learnedText(in card: StudyCard) throws -> LearningTextRepresentation {
        XCTAssertEqual(card.representations.count, 1)
        guard case .learningText(let text) = card.representations[0] else {
            throw TestError.expectedLearningText
        }
        return text
    }

    private func makeProvider() -> LanguageWordCardsContentProvider {
        LanguageWordCardsContentProvider(configuration: .configuration(for: .minikPlus))
    }

    private func locale(for learnedLanguage: LanguageIdentifier) -> Locale {
        switch learnedLanguage {
        case .english:
            return Locale(identifier: "en_US_POSIX")
        case .hebrew:
            return Locale(identifier: "he_IL")
        default:
            return Locale(identifier: learnedLanguage.rawValue)
        }
    }

    private func makeRequest(
        activityType: ActivityType = .cards,
        curriculumStage: CurriculumStageID = LanguageCurriculumStageIDs.wordsLevelA,
        primarySkill: SkillID = LanguageSkillIDs.wordRecognition,
        interaction: Interaction? = nil,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: curriculumStage,
            primarySkill: primarySkill,
            difficulty: try XCTUnwrap(Difficulty(0.5)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private enum TestError: Error {
        case expectedLearningText
    }
}
