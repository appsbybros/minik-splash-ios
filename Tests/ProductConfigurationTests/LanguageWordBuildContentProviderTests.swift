import XCTest
@testable import MinikPlus

final class LanguageWordBuildContentProviderTests: XCTestCase {
    func testValidEnglishAndHebrewRequestsReturnRealFruitChallenges() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let item = try catalogItem(for: challenge)

            XCTAssertEqual(challenge.prompt.representations, [.imageAsset(item.image)])
            XCTAssertTrue(challenge.id.rawValue.contains(item.id.rawValue))
            XCTAssertEqual(challenge.validationMode, .immediatePrefix)
            XCTAssertEqual(challenge.languageWordContent?.contentItemID, item.id)
        }
    }

    func testAvailableTokensAreExactTargetGraphemeInstances() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let item = try catalogItem(for: challenge)
            let target = try XCTUnwrap(LanguageWordContentProvider.learnedText(
                for: item,
                language: language
            ))

            XCTAssertEqual(
                try tokenTexts(challenge.availableTokens),
                target.text.filter { !$0.isWhitespace }.map(String.init)
            )
            XCTAssertEqual(
                challenge.availableTokens.count,
                target.text.filter { !$0.isWhitespace }.count
            )
        }
    }

    func testLanguageContentExcludesWhitespaceTokensAndRetainsExactTargetText() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let content = try XCTUnwrap(challenge.languageWordContent)

            XCTAssertFalse(challenge.availableTokens.contains { token in
                guard case .learningText(let text) = token.representation else {
                    return false
                }
                return text.text.contains(where: { $0.isWhitespace })
            })
            XCTAssertEqual(
                try expectedText(for: challenge),
                content.targetText.text.filter { !$0.isWhitespace }
            )
        }
    }

    func testExpectedVisibleSequenceReconstructsExactLearnedWord() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let item = try catalogItem(for: challenge)
            let target = try XCTUnwrap(LanguageWordContentProvider.learnedText(
                for: item,
                language: language
            ))

            XCTAssertEqual(
                try expectedText(for: challenge),
                target.text.filter { !$0.isWhitespace }
            )
        }
    }

    func testTokenMetadataUsesRequestedLanguageAndDirection() throws {
        let english = try makeChallenge(language: .english)
        let hebrew = try makeChallenge(language: .hebrew)

        try assertMetadata(english, language: .english, direction: .leftToRight)
        try assertMetadata(hebrew, language: .hebrew, direction: .rightToLeft)
    }

    func testDuplicateVisibleLettersHaveDistinctPhysicalTokenIDs() throws {
        let challenge = try challengeContainingDuplicateCharacters(language: .english)
        let groupedTokens = Dictionary(grouping: challenge.availableTokens) { token in
            token.representation
        }
        let duplicateTokens = try XCTUnwrap(groupedTokens.values.first { $0.count > 1 })

        XCTAssertEqual(Set(duplicateTokens.map(\.id)).count, duplicateTokens.count)
    }

    func testDuplicatePhysicalTokensRemainCorrectByVisibleOrderedSequence() throws {
        let challenge = try challengeContainingDuplicateCharacters(language: .english)
        let tokensByID = Dictionary(
            uniqueKeysWithValues: challenge.availableTokens.map { ($0.id, $0) }
        )
        var selectedIDs = challenge.expectedTokenSequence
        let equalPair = try XCTUnwrap(firstEqualRepresentationPair(
            in: selectedIDs,
            tokensByID: tokensByID
        ))
        selectedIDs.swapAt(equalPair.0, equalPair.1)
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        selectedIDs.forEach { session.selectToken($0) }
        session.submit()

        XCTAssertEqual(session.answerResult, .correct)
    }

    func testSessionPresentationIsNotAlreadySolved() throws {
        let challenge = try makeChallenge(language: .english)
        let session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        XCTAssertNotEqual(
            try representations(for: session.tokenPresentationOrder, in: challenge),
            try representations(for: challenge.expectedTokenSequence, in: challenge)
        )
    }

    func testFactoryBuildsCompleteUniqueTypedImmediatePrefixPool() throws {
        let session = try XCTUnwrap(
            LanguageActivitySessionFactory(configuration: .configuration(for: .minikPlus))
                .makeWordBuildSession(for: .english)
        )

        XCTAssertGreaterThan(session.challengeCount, 6)
        XCTAssertEqual(
            Set(session.challenges.compactMap { $0.languageWordContent?.contentItemID }).count,
            session.challengeCount
        )
        XCTAssertTrue(session.challenges.allSatisfy {
            $0.validationMode == .immediatePrefix
                && $0.languageWordContent != nil
                && $0.primarySkill == LanguageSkillIDs.wordConstruction
        })
    }

    func testInvalidRequestShapesReturnNil() throws {
        let provider = makeProvider()
        let wrongActivity = try makeRequest(activityType: .multipleChoice)
        let wrongStage = try makeRequest(curriculumStage: LanguageCurriculumStageIDs.alphabet)
        let wrongSkill = try makeRequest(primarySkill: LanguageSkillIDs.wordRecognition)
        let wrongInteraction = try makeRequest(interaction: .singleChoice)
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 2))
        let wrongCount = try makeRequest(countRequirement: count)

        XCTAssertNil(provider.buildChallenge(for: wrongActivity, learnedLanguage: .english))
        XCTAssertNil(provider.buildChallenge(for: wrongStage, learnedLanguage: .english))
        XCTAssertNil(provider.buildChallenge(for: wrongSkill, learnedLanguage: .english))
        XCTAssertNil(provider.buildChallenge(for: wrongInteraction, learnedLanguage: .english))
        XCTAssertNil(provider.buildChallenge(for: wrongCount, learnedLanguage: .english))
    }

    func testProductAndLearnedLanguagePolicyIsEnforced() throws {
        let request = try makeRequest()
        let plus = LanguageWordBuildContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnly = LanguageWordBuildContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageWordBuildContentProvider(
            configuration: .configuration(for: .minikMath)
        )

        XCTAssertNotNil(plus.buildChallenge(for: request, learnedLanguage: .english))
        XCTAssertNotNil(plus.buildChallenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNotNil(englishOnly.buildChallenge(for: request, learnedLanguage: .english))
        XCTAssertNil(englishOnly.buildChallenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNil(math.buildChallenge(for: request, learnedLanguage: .english))
        XCTAssertNil(plus.buildChallenge(
            for: request,
            learnedLanguage: LanguageIdentifier(rawValue: "fr")
        ))
    }

    private func makeChallenge(language: LanguageIdentifier) throws -> BuildChallenge {
        let request = try makeRequest()
        return try XCTUnwrap(makeProvider().buildChallenge(
            for: request,
            learnedLanguage: language
        ))
    }

    private func challengeContainingDuplicateCharacters(
        language: LanguageIdentifier
    ) throws -> BuildChallenge {
        for _ in 0 ..< 100 {
            let challenge = try makeChallenge(language: language)
            let representations = challenge.availableTokens.map(\.representation)
            if Set(representations).count < representations.count {
                return challenge
            }
        }
        throw TestError.noDuplicateCharacterChallengeGenerated
    }

    private func catalogItem(for challenge: BuildChallenge) throws -> LanguageWordCatalogItem {
        guard challenge.prompt.representations.count == 1,
              case .imageAsset(let image) = challenge.prompt.representations[0],
              let item = LanguageWordContentProvider.levelAFruits.first(where: {
                  $0.image == image
              }) else {
            throw TestError.expectedCatalogImagePrompt
        }
        return item
    }

    private func tokenTexts(_ tokens: [BuildToken]) throws -> [String] {
        try tokens.map { token in
            guard case .learningText(let text) = token.representation else {
                throw TestError.expectedLearningTextToken
            }
            return text.text
        }
    }

    private func expectedText(for challenge: BuildChallenge) throws -> String {
        let tokensByID = Dictionary(
            uniqueKeysWithValues: challenge.availableTokens.map { ($0.id, $0) }
        )
        return try challenge.expectedTokenSequence.map { tokenID in
            guard let token = tokensByID[tokenID],
                  case .learningText(let text) = token.representation else {
                throw TestError.expectedLearningTextToken
            }
            return text.text
        }.joined()
    }

    private func assertMetadata(
        _ challenge: BuildChallenge,
        language: LanguageIdentifier,
        direction: ContentDirection
    ) throws {
        for token in challenge.availableTokens {
            guard case .learningText(let text) = token.representation else {
                throw TestError.expectedLearningTextToken
            }
            XCTAssertEqual(text.language, language)
            XCTAssertEqual(text.direction, direction)
        }
    }

    private func firstEqualRepresentationPair(
        in tokenIDs: [BuildTokenID],
        tokensByID: [BuildTokenID: BuildToken]
    ) -> (Int, Int)? {
        for firstIndex in tokenIDs.indices {
            for secondIndex in tokenIDs.indices where secondIndex > firstIndex {
                if tokensByID[tokenIDs[firstIndex]]?.representation
                    == tokensByID[tokenIDs[secondIndex]]?.representation {
                    return (firstIndex, secondIndex)
                }
            }
        }
        return nil
    }

    private func representations(
        for tokenIDs: [BuildTokenID],
        in challenge: BuildChallenge
    ) throws -> [Representation] {
        let tokensByID = Dictionary(
            uniqueKeysWithValues: challenge.availableTokens.map { ($0.id, $0) }
        )
        return try tokenIDs.map { tokenID in
            guard let token = tokensByID[tokenID] else {
                throw TestError.missingToken
            }
            return token.representation
        }
    }

    private func makeProvider() -> LanguageWordBuildContentProvider {
        LanguageWordBuildContentProvider(
            configuration: .configuration(for: .minikPlus),
            categoryID: .fruits
        )
    }

    private func makeRequest(
        activityType: ActivityType = .build,
        curriculumStage: CurriculumStageID = LanguageCurriculumStageIDs.wordsLevelA,
        primarySkill: SkillID = LanguageSkillIDs.wordConstruction,
        interaction: Interaction = .orderedTokens,
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
        case expectedCatalogImagePrompt
        case expectedLearningTextToken
        case missingToken
        case noDuplicateCharacterChallengeGenerated
    }
}
