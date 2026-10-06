import XCTest
@testable import MinikPlus

final class LanguageFirstLetterPictureContentProviderTests: XCTestCase {
    func testCorrectRequestSucceeds() throws {
        XCTAssertNotNil(try makeChallenge(language: .english))
    }

    func testNilCountProducesFourChoicesAndExplicitChoiceCountsWork() throws {
        let defaultChallenge = try makeChallenge(language: .english)
        XCTAssertEqual(defaultChallenge.choices.count, 4)

        for count in 2 ... 4 {
            let request = try makeRequest(countRequirement: try XCTUnwrap(
                ContentCountRequirement(kind: .choices, count: count)
            ))
            let challenge = try XCTUnwrap(provider.challenge(
                for: request,
                learnedLanguage: .english
            ))

            XCTAssertEqual(challenge.choices.count, count)
        }
    }

    func testWrongRequestShapesAndInvalidCountRequirementsReturnNil() throws {
        let wrongActivity = try makeRequest(activityType: .memory)
        let wrongStage = try makeRequest(curriculumStage: LanguageCurriculumStageIDs.alphabet)
        let wrongSkill = try makeRequest(primarySkill: LanguageSkillIDs.wordRecognition)
        let wrongInteraction = try makeRequest(interaction: .orderedTokens)
        let wrongKind = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .items, count: 4)
        ))
        let tooFew = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .choices, count: 1)
        ))
        let tooMany = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .choices, count: 5)
        ))

        XCTAssertNil(provider.challenge(for: wrongActivity, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: wrongStage, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: wrongSkill, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: wrongInteraction, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: wrongKind, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: tooFew, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: tooMany, learnedLanguage: .english))
    }

    func testPromptUsesExactlyOneInitialLetterWithCorrectMetadata() throws {
        try assertPrompt(language: .english, direction: .leftToRight)
        try assertPrompt(language: .hebrew, direction: .rightToLeft)
    }

    func testPromptEqualsInitialExtractedFromExpectedSemanticItem() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let promptInitial = try promptText(from: challenge)
            let correctItem = try correctItem(for: challenge, language: language)
            let expectedInitial = try XCTUnwrap(
                LanguageLetterPairsContentProvider.initialLetter(
                    for: correctItem,
                    language: language
                )
            )

            XCTAssertEqual(promptInitial, expectedInitial)
        }
    }

    func testChoicesUseLevelAFruitImagesFromOneCategoryWithDistinctInitials() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let correctItem = try correctItem(for: challenge, language: language)
            let promptInitial = try promptText(from: challenge)
            let choiceItems = try imageChoiceItems(for: challenge)
            let choiceIDs = choiceItems.map(\.id)
            let choiceInitials = try choiceItems.map { item in
                try XCTUnwrap(LanguageLetterPairsContentProvider.initialLetter(
                    for: item,
                    language: language
                ))
            }

            XCTAssertTrue(challenge.choices.allSatisfy {
                if case .imageAsset = $0.representation { return true }
                return false
            })
            XCTAssertEqual(Set(choiceItems.map(\.image)).count, choiceItems.count)
            XCTAssertEqual(Set(choiceIDs).count, choiceIDs.count)
            XCTAssertTrue(choiceItems.allSatisfy { $0.category == correctItem.category })
            XCTAssertEqual(correctItem.category, "fruits")
            XCTAssertEqual(Set(choiceInitials).count, choiceInitials.count)
            XCTAssertEqual(choiceInitials.filter { $0 == promptInitial }.count, 1)
            XCTAssertEqual(choiceInitials.filter { $0 != promptInitial }.count, challenge.choices.count - 1)
        }
    }

    func testImageChoiceSpeechUsesEachLearnedWord() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let items = try imageChoiceItems(for: challenge)

            for (choice, item) in zip(challenge.choices, items) {
                let learnedText = try XCTUnwrap(
                    LanguageWordContentProvider.learnedText(for: item, language: language)
                )
                XCTAssertEqual(choice.learningSpeechCue, learnedText.learningSpeechCue)
            }
        }
    }

    func testExpectedAnswerAndChoiceSemanticValuesUseInitialConceptIdentity() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let correctItem = try correctItem(for: challenge, language: language)
            let correctInitial = try XCTUnwrap(
                LanguageLetterPairsContentProvider.initialLetter(
                    for: correctItem,
                    language: language
                )
            )

            XCTAssertEqual(
                challenge.expectedAnswer,
                .semanticValue(.contentItem(
                    LanguageLetterPairsContentProvider.initialConceptID(
                        language: language,
                        initial: correctInitial
                    )
                ))
            )
            guard case .semanticValue(let expected) = challenge.expectedAnswer else {
                return XCTFail("Expected semantic answer.")
            }

            for (choice, item) in zip(challenge.choices, try imageChoiceItems(for: challenge)) {
                let itemInitial = try XCTUnwrap(
                    LanguageLetterPairsContentProvider.initialLetter(
                        for: item,
                        language: language
                    )
                )
                XCTAssertEqual(
                    choice.semanticValue,
                    .contentItem(
                        LanguageLetterPairsContentProvider.initialConceptID(
                            language: language,
                            initial: itemInitial
                        )
                    )
                )
            }

            XCTAssertEqual(
                challenge.choices.filter { $0.semanticValue == expected }.count,
                1
            )
        }
    }

    func testCorrectnessRemainsCorrectAfterReorderingChoices() throws {
        let challenge = try makeChallenge(language: .english)
        guard case .semanticValue(let expected) = challenge.expectedAnswer else {
            return XCTFail("Expected semantic answer.")
        }
        let correctChoice = try XCTUnwrap(challenge.choices.first {
            $0.semanticValue == expected
        })
        var originalSession = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))
        var reorderedSession = try XCTUnwrap(MultipleChoiceSession(challenges: [
            reorderedChallenge(challenge)
        ]))

        originalSession.selectChoice(correctChoice.id)
        reorderedSession.selectChoice(correctChoice.id)

        XCTAssertEqual(originalSession.answerResult, .correct)
        XCTAssertEqual(reorderedSession.answerResult, .correct)
    }

    func testGeneratedChallengeInstancesUseUniqueChallengeIDsAndChoiceIDs() throws {
        let firstChallenge = try makeChallenge(language: .english)
        let secondChallenge = try makeChallenge(language: .english)

        XCTAssertNotEqual(firstChallenge.id, secondChallenge.id)
        XCTAssertEqual(Set(firstChallenge.choices.map(\.id)).count, firstChallenge.choices.count)
        XCTAssertEqual(Set(secondChallenge.choices.map(\.id)).count, secondChallenge.choices.count)
    }

    func testProgressUsesStableExpectedInitialIdentityInsteadOfChallengeInstanceID() throws {
        let challenge = try makeChallenge(language: .hebrew)
        guard case .semanticValue(.contentItem(let expectedInitialID)) = challenge.expectedAnswer else {
            return XCTFail("Expected an initial-letter semantic identity.")
        }

        let itemID = MultipleChoiceAttemptIdentity.itemID(
            for: challenge,
            usesExpectedSemanticIdentity: true
        )

        XCTAssertEqual(itemID.rawValue, expectedInitialID.rawValue)
        XCTAssertNotEqual(itemID.rawValue, challenge.id.rawValue)
    }

    func testFactoryPreservesSixChallengeRetryUntilCorrectProgression() throws {
        var session = try XCTUnwrap(
            LanguageActivitySessionFactory(configuration: .configuration(for: .minikPlus))
                .makeFirstLetterPicturesSession(for: .hebrew)
        )
        let challengeID = session.currentChallenge.id
        guard case .semanticValue(let expected) = session.currentChallenge.expectedAnswer else {
            return XCTFail("Expected semantic answer.")
        }
        let wrongChoice = try XCTUnwrap(session.currentChallenge.choices.first {
            $0.semanticValue != expected
        })

        XCTAssertEqual(session.challengeCount, 6)
        XCTAssertEqual(session.progressionPolicy, .retryUntilCorrect)

        session.selectChoice(wrongChoice.id)
        XCTAssertEqual(session.answerResult, .incorrect)
        XCTAssertEqual(session.pendingAction, .resetAfterIncorrect(challengeID: challengeID))

        session.resetTransientIncorrectAttempt(for: challengeID)
        XCTAssertNil(session.answerResult)
        XCTAssertTrue(session.canSelectChoices)
        XCTAssertEqual(session.currentChallenge.id, challengeID)
    }

    func testProductConfigurationEnforcesEveryLanguagePolicy() throws {
        let request = try makeRequest()
        let plus = LanguageFirstLetterPictureContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnly = LanguageFirstLetterPictureContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageFirstLetterPictureContentProvider(
            configuration: .configuration(for: .minikMath)
        )

        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .english))
        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNotNil(englishOnly.challenge(for: request, learnedLanguage: .english))
        XCTAssertNil(englishOnly.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNil(math.challenge(for: request, learnedLanguage: .english))
        XCTAssertNil(math.challenge(for: request, learnedLanguage: .hebrew))
    }

    private var provider: LanguageFirstLetterPictureContentProvider {
        LanguageFirstLetterPictureContentProvider(configuration: .configuration(for: .minikPlus))
    }

    private func makeChallenge(
        language: LanguageIdentifier
    ) throws -> Challenge {
        try XCTUnwrap(provider.challenge(
            for: try makeRequest(),
            learnedLanguage: language
        ))
    }

    private func makeRequest(
        activityType: ActivityType = .chooseRepresentation,
        curriculumStage: CurriculumStageID = LanguageCurriculumStageIDs.wordsLevelA,
        primarySkill: SkillID = LanguageSkillIDs.initialLetterAssociation,
        interaction: Interaction = .singleChoice,
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

    private func assertPrompt(
        language: LanguageIdentifier,
        direction: ContentDirection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let challenge = try makeChallenge(language: language)

        XCTAssertEqual(challenge.prompt.representations.count, 1, file: file, line: line)
        guard case .learningText(let text) = challenge.prompt.representations[0] else {
            return XCTFail("Expected learning text prompt.", file: file, line: line)
        }
        XCTAssertEqual(text.language, language, file: file, line: line)
        XCTAssertEqual(text.direction, direction, file: file, line: line)
        XCTAssertEqual(text.text.count, 1, file: file, line: line)
        XCTAssertEqual(Array(text.text).count, 1, file: file, line: line)
    }

    private func promptText(from challenge: Challenge) throws -> String {
        guard case .learningText(let text) = challenge.prompt.representations[0] else {
            throw TestError.invalidPromptRepresentation
        }
        return text.text
    }

    private func imageChoiceItems(for challenge: Challenge) throws -> [LanguageWordCatalogItem] {
        try challenge.choices.map { choice in
            guard case .imageAsset(let image) = choice.representation,
                  let item = LanguageWordContentProvider.levelAFruits.first(where: {
                      $0.image == image
                  }) else {
                throw TestError.invalidChoiceRepresentation
            }
            return item
        }
    }

    private func correctItem(
        for challenge: Challenge,
        language: LanguageIdentifier
    ) throws -> LanguageWordCatalogItem {
        guard case .semanticValue(let expected) = challenge.expectedAnswer else {
            throw TestError.invalidExpectedAnswer
        }

        let items = try imageChoiceItems(for: challenge)
        return try XCTUnwrap(items.first { item in
            guard let initial = LanguageLetterPairsContentProvider.initialLetter(
                for: item,
                language: language
            ) else {
                return false
            }
            return expected == .contentItem(
                LanguageLetterPairsContentProvider.initialConceptID(
                    language: language,
                    initial: initial
                )
            )
        })
    }

    private func reorderedChallenge(_ challenge: Challenge) -> Challenge {
        Challenge(
            id: challenge.id,
            prompt: challenge.prompt,
            choices: Array(challenge.choices.reversed()),
            interaction: challenge.interaction,
            validationRule: challenge.validationRule,
            expectedAnswer: challenge.expectedAnswer,
            primarySkill: challenge.primarySkill,
            secondarySkills: challenge.secondarySkills,
            curriculumStage: challenge.curriculumStage,
            difficulty: challenge.difficulty
        )
    }

    private enum TestError: Error {
        case invalidChoiceRepresentation
        case invalidPromptRepresentation
        case invalidExpectedAnswer
    }
}
