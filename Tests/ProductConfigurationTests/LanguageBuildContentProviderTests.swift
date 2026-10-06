import XCTest
@testable import MinikPlus

final class LanguageBuildContentProviderTests: XCTestCase {
    func testValidEnglishRequestCreatesNonemptyChallenge() throws {
        let challenge = try makeChallenge(language: .english)

        XCTAssertFalse(challenge.availableTokens.isEmpty)
        XCTAssertEqual(challenge.availableTokens.count, challenge.expectedTokenSequence.count)
    }

    func testPromptReusesLetterRepresentationFromAlphabetCard() throws {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)
        let cards = LanguageLearnContentProvider(configuration: configuration)
            .studyCards(for: .english)
        let challenge = try makeChallenge(language: .english, configuration: configuration)
        let sourceLetters = Set(cards.map { $0.representations[0] })

        XCTAssertEqual(challenge.prompt.representations.count, 1)
        XCTAssertTrue(sourceLetters.contains(challenge.prompt.representations[0]))
    }

    func testExpectedGraphemeSequenceReconstructsAssociatedWord() throws {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)
        let cards = LanguageLearnContentProvider(configuration: configuration)
            .studyCards(for: .english)
        let challenge = try makeChallenge(language: .english, configuration: configuration)
        let promptLetter = try XCTUnwrap(challenge.prompt.representations.first)
        let sourceCard = try XCTUnwrap(cards.first { $0.representations[0] == promptLetter })
        guard case .learningText(let sourceWord) = sourceCard.representations[1] else {
            return XCTFail("Expected a learning-text word.")
        }
        let tokensByID = Dictionary(
            uniqueKeysWithValues: challenge.availableTokens.map { ($0.id, $0) }
        )
        let tokenTexts = try challenge.expectedTokenSequence.map { tokenID in
            guard let token = tokensByID[tokenID],
                  case .learningText(let text) = token.representation else {
                throw TestError.expectedLearningTextToken
            }
            return text.text
        }

        XCTAssertEqual(tokenTexts, Array(sourceWord.text).map(String.init))
    }

    func testEveryPhysicalTokenIDIsUnique() throws {
        let challenge = try makeChallenge(language: .english)

        XCTAssertEqual(
            Set(challenge.availableTokens.map(\.id)).count,
            challenge.availableTokens.count
        )
    }

    func testHebrewTokensPreserveLanguageAndRightToLeftDirection() throws {
        let challenge = try makeChallenge(language: .hebrew)

        for token in challenge.availableTokens {
            guard case .learningText(let text) = token.representation else {
                return XCTFail("Expected a learning-text token.")
            }
            XCTAssertEqual(text.language, .hebrew)
            XCTAssertEqual(text.direction, .rightToLeft)
        }
    }

    func testProviderEnforcesProductLearnedLanguagePolicy() throws {
        let request = try makeRequest()
        let plusProvider = LanguageBuildContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnlyProvider = LanguageBuildContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )

        XCTAssertNotNil(plusProvider.buildChallenge(for: request, learnedLanguage: .english))
        XCTAssertNotNil(plusProvider.buildChallenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNotNil(englishOnlyProvider.buildChallenge(for: request, learnedLanguage: .english))
        XCTAssertNil(englishOnlyProvider.buildChallenge(for: request, learnedLanguage: .hebrew))
    }

    private func makeChallenge(
        language: LanguageIdentifier,
        configuration: ProductConfiguration = .configuration(for: .minikPlus)
    ) throws -> BuildChallenge {
        let request = try makeRequest()
        let provider = LanguageBuildContentProvider(configuration: configuration)
        return try XCTUnwrap(provider.buildChallenge(for: request, learnedLanguage: language))
    }

    private func makeRequest() throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: .build,
            curriculumStage: LanguageCurriculumStageIDs.alphabet,
            primarySkill: LanguageSkillIDs.wordConstruction,
            difficulty: try XCTUnwrap(Difficulty(0.5)),
            interaction: .orderedTokens,
            countRequirement: nil
        )
    }

    private enum TestError: Error {
        case expectedLearningTextToken
    }
}
