import XCTest
@testable import MinikPlus

final class LanguageMultipleChoiceContentProviderTests: XCTestCase {
    func testValidEnglishRequestCreatesFourUniqueChoices() throws {
        let challenge = try makeChallenge(language: .english)

        XCTAssertEqual(challenge.choices.count, 4)
        XCTAssertEqual(Set(challenge.choices.map(\.id)).count, 4)
        XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, 4)
    }

    func testExpectedAnswerUsesExactContentIdentity() throws {
        let challenge = try makeChallenge(language: .english)

        XCTAssertEqual(challenge.validationRule, .exactIdentity)
        guard case .semanticValue(.contentItem) = challenge.expectedAnswer else {
            return XCTFail("Expected a content-item semantic answer.")
        }
    }

    func testExactlyOneChoiceHasExpectedContentIdentity() throws {
        let challenge = try makeChallenge(language: .english)
        guard case .semanticValue(let expectedValue) = challenge.expectedAnswer else {
            return XCTFail("Expected a semantic answer.")
        }

        XCTAssertEqual(
            challenge.choices.filter { $0.semanticValue == expectedValue }.count,
            1
        )
    }

    func testPromptAndChoicesReuseAlphabetCardRepresentations() throws {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)
        let cards = LanguageLearnContentProvider(configuration: configuration)
            .studyCards(for: .english)
        let challenge = try makeChallenge(language: .english, configuration: configuration)
        let letters = Set(cards.map { $0.representations[0] })
        let wordsByContentID = Dictionary(uniqueKeysWithValues: cards.map {
            (SemanticValue.contentItem(ContentItemID(rawValue: $0.id.rawValue)), $0.representations[1])
        })

        XCTAssertEqual(challenge.prompt.representations.count, 1)
        XCTAssertTrue(letters.contains(challenge.prompt.representations[0]))
        for choice in challenge.choices {
            XCTAssertEqual(choice.representation, wordsByContentID[choice.semanticValue])
        }
    }

    func testHebrewChallengePreservesLanguageAndRightToLeftDirection() throws {
        let challenge = try makeChallenge(language: .hebrew)
        let representations = challenge.prompt.representations
            + challenge.choices.map(\.representation)

        for representation in representations {
            guard case .learningText(let text) = representation else {
                return XCTFail("Expected learning-text content.")
            }
            XCTAssertEqual(text.language, .hebrew)
            XCTAssertEqual(text.direction, .rightToLeft)
        }
    }

    func testProviderEnforcesProductLearnedLanguagePolicy() throws {
        let request = try makeRequest()
        let plusProvider = LanguageMultipleChoiceContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnlyProvider = LanguageMultipleChoiceContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )

        XCTAssertNotNil(plusProvider.challenge(for: request, learnedLanguage: .english))
        XCTAssertNotNil(plusProvider.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNotNil(englishOnlyProvider.challenge(for: request, learnedLanguage: .english))
        XCTAssertNil(englishOnlyProvider.challenge(for: request, learnedLanguage: .hebrew))
    }

    private func makeChallenge(
        language: LanguageIdentifier,
        configuration: ProductConfiguration = .configuration(for: .minikPlus)
    ) throws -> Challenge {
        let request = try makeRequest()
        let provider = LanguageMultipleChoiceContentProvider(configuration: configuration)
        return try XCTUnwrap(provider.challenge(for: request, learnedLanguage: language))
    }

    private func makeRequest() throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: .multipleChoice,
            curriculumStage: LanguageCurriculumStageIDs.alphabet,
            primarySkill: LanguageSkillIDs.alphabetRecognition,
            difficulty: try XCTUnwrap(Difficulty(0.5)),
            interaction: .singleChoice,
            countRequirement: nil
        )
    }
}
