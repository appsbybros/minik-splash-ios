import XCTest
@testable import MinikPlus

final class LanguageMatchingContentProviderTests: XCTestCase {
    func testValidEnglishPairsRequestReturnsFourSets() throws {
        let sets = try makeSets(activityType: .pairs, language: .english)

        XCTAssertEqual(sets.count, 4)
        XCTAssertNotNil(PairsSession(equivalenceSets: sets))
    }

    func testValidEnglishMemoryRequestReturnsFourSets() throws {
        let sets = try makeSets(activityType: .memory, language: .english)

        XCTAssertEqual(sets.count, 4)
        XCTAssertNotNil(MemorySession(equivalenceSets: sets))
    }

    func testSetsReuseLetterAndWordRepresentationsInSourceOrder() throws {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)
        let cards = LanguageLearnContentProvider(configuration: configuration)
            .studyCards(for: .english)
        let sourceRepresentations = Dictionary(uniqueKeysWithValues: cards.map {
            (
                SemanticValue.contentItem(ContentItemID(rawValue: $0.id.rawValue)),
                Array($0.representations.prefix(2))
            )
        })
        let sets = try makeSets(
            activityType: .pairs,
            language: .english,
            configuration: configuration
        )

        for set in sets {
            XCTAssertEqual(set.representations.count, 2)
            XCTAssertEqual(set.representations, sourceRepresentations[set.semanticValue])
        }
    }

    func testSemanticContentIdentitiesAreUnique() throws {
        let sets = try makeSets(activityType: .pairs, language: .english)

        XCTAssertEqual(Set(sets.map(\.semanticValue)).count, sets.count)
        for set in sets {
            guard case .contentItem = set.semanticValue else {
                return XCTFail("Expected stable content-item semantics.")
            }
        }
    }

    func testHebrewSetsPreserveLanguageAndRightToLeftDirection() throws {
        let sets = try makeSets(activityType: .memory, language: .hebrew)

        for representation in sets.flatMap(\.representations) {
            guard case .learningText(let text) = representation else {
                return XCTFail("Expected learning-text content.")
            }
            XCTAssertEqual(text.language, .hebrew)
            XCTAssertEqual(text.direction, .rightToLeft)
        }
    }

    func testCustomItemCountsAreHonored() throws {
        let twoItems = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 2))
        let sixItems = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 6))

        XCTAssertEqual(
            try makeSets(activityType: .pairs, language: .english, countRequirement: twoItems).count,
            2
        )
        XCTAssertEqual(
            try makeSets(activityType: .memory, language: .english, countRequirement: sixItems).count,
            6
        )
    }

    func testInvalidRequestShapesFailSafely() throws {
        let provider = makeProvider(for: .minikPlus)
        let choices = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 4))
        let tooMany = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 7))
        let wrongInteraction = try makeRequest(interaction: .singleChoice)
        let wrongStage = try makeRequest(stage: CurriculumStageID(rawValue: "M1"))
        let wrongSkill = try makeRequest(skill: SkillID(rawValue: "language.unsupported"))
        let wrongCountKind = try makeRequest(countRequirement: choices)
        let unsupportedCount = try makeRequest(countRequirement: tooMany)

        XCTAssertTrue(provider.equivalenceSets(for: wrongInteraction, learnedLanguage: .english).isEmpty)
        XCTAssertTrue(provider.equivalenceSets(for: wrongStage, learnedLanguage: .english).isEmpty)
        XCTAssertTrue(provider.equivalenceSets(for: wrongSkill, learnedLanguage: .english).isEmpty)
        XCTAssertTrue(provider.equivalenceSets(for: wrongCountKind, learnedLanguage: .english).isEmpty)
        XCTAssertTrue(provider.equivalenceSets(for: unsupportedCount, learnedLanguage: .english).isEmpty)
    }

    func testProviderEnforcesProductLearnedLanguagePolicy() throws {
        let request = try makeRequest()
        let plusProvider = makeProvider(for: .minikPlus)
        let englishOnlyProvider = makeProvider(for: .minikPlusEnglish)

        XCTAssertFalse(plusProvider.equivalenceSets(for: request, learnedLanguage: .english).isEmpty)
        XCTAssertFalse(plusProvider.equivalenceSets(for: request, learnedLanguage: .hebrew).isEmpty)
        XCTAssertFalse(englishOnlyProvider.equivalenceSets(for: request, learnedLanguage: .english).isEmpty)
        XCTAssertTrue(englishOnlyProvider.equivalenceSets(for: request, learnedLanguage: .hebrew).isEmpty)
    }

    private func makeSets(
        activityType: ActivityType,
        language: LanguageIdentifier,
        configuration: ProductConfiguration = .configuration(for: .minikPlus),
        countRequirement: ContentCountRequirement? = nil
    ) throws -> [EquivalenceSet] {
        let request = try makeRequest(
            activityType: activityType,
            countRequirement: countRequirement
        )
        return LanguageMatchingContentProvider(configuration: configuration)
            .equivalenceSets(for: request, learnedLanguage: language)
    }

    private func makeProvider(for variant: ProductVariant) -> LanguageMatchingContentProvider {
        LanguageMatchingContentProvider(configuration: .configuration(for: variant))
    }

    private func makeRequest(
        activityType: ActivityType = .pairs,
        stage: CurriculumStageID = LanguageCurriculumStageIDs.alphabet,
        skill: SkillID = LanguageSkillIDs.letterWordAssociation,
        interaction: Interaction = .matching,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: stage,
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(0.5)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }
}
