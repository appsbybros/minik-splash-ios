import XCTest
@testable import MinikPlus

final class LanguageFirstLetterChoiceContentProviderTests: XCTestCase {
    func testCorrectRequestSucceeds() throws {
        XCTAssertNotNil(try makeChallenge(language: .english))
    }

    func testDefaultProducesFourChoicesAndExplicitTwoThroughFourAreAccepted() throws {
        let defaultChallenge = try makeChallenge(language: .english)
        XCTAssertEqual(defaultChallenge.choices.count, 4)
        XCTAssertEqual(Set(defaultChallenge.choices.map(\.id)).count, defaultChallenge.choices.count)

        for count in 2 ... 4 {
            let request = try makeRequest(countRequirement: try XCTUnwrap(
                ContentCountRequirement(kind: .choices, count: count)
            ))
            let challenge = try XCTUnwrap(provider.challenge(
                for: request,
                learnedLanguage: .english
            ))

            XCTAssertEqual(challenge.choices.count, count)
            XCTAssertEqual(Set(challenge.choices.map(\.id)).count, challenge.choices.count)
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

    func testPromptUsesExactlyOneImageAssetForEnglishAndHebrew() throws {
        try assertPromptImage(language: .english)
        try assertPromptImage(language: .hebrew)
    }

    func testImagePromptSpeechUsesTheLearnedWord() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let item = try promptItem(for: challenge)
            let learnedText = try XCTUnwrap(
                LanguageWordContentProvider.learnedText(for: item, language: language)
            )

            XCTAssertEqual(challenge.prompt.learningSpeechCue, learnedText.learningSpeechCue)
        }
    }

    func testChoicesUseSingleLearnedLanguageLetterWithCorrectMetadata() throws {
        let english = try makeChallenge(language: .english)
        let hebrew = try makeChallenge(language: .hebrew)

        try assertChoiceLetters(
            in: english,
            language: .english,
            direction: .leftToRight
        )
        try assertChoiceLetters(
            in: hebrew,
            language: .hebrew,
            direction: .rightToLeft
        )
    }

    func testChoicesUseDistinctInitialsAndExactlyOneExpectedSemanticIdentity() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let displayedInitials = try choiceTexts(in: challenge)

            XCTAssertEqual(Set(displayedInitials).count, challenge.choices.count)
            guard case .semanticValue(let expected) = challenge.expectedAnswer else {
                return XCTFail("Expected semantic answer.")
            }
            XCTAssertEqual(challenge.choices.filter { $0.semanticValue == expected }.count, 1)
            XCTAssertEqual(challenge.validationRule, .exactIdentity)
        }
    }

    func testChallengeUsesSameCategoryPromptAndDistinctDistractorInitials() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let correctItem = try promptItem(for: challenge)
            let correctInitial = try XCTUnwrap(
                LanguageLetterPairsContentProvider.initialLetter(
                    for: correctItem,
                    language: language
                )
            )
            let displayedInitials = try choiceTexts(in: challenge)
            let distractorInitials = displayedInitials.filter { $0 != correctInitial }

            XCTAssertEqual(correctItem.category, "fruits")
            XCTAssertEqual(distractorInitials.count, challenge.choices.count - 1)
            XCTAssertFalse(distractorInitials.contains(correctInitial))
            XCTAssertEqual(Set(distractorInitials).count, distractorInitials.count)

            for distractorInitial in distractorInitials {
                XCTAssertTrue(LanguageWordContentProvider.levelAFruits.contains { item in
                    item.id != correctItem.id
                        && item.category == correctItem.category
                        && LanguageLetterPairsContentProvider.initialLetter(
                            for: item,
                            language: language
                        ) == distractorInitial
                })
            }
        }
    }

    func testExpectedAnswerMatchesPromptInitialConceptIdentity() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            let item = try promptItem(for: challenge)
            let initial = try XCTUnwrap(LanguageLetterPairsContentProvider.initialLetter(
                for: item,
                language: language
            ))

            XCTAssertEqual(
                challenge.expectedAnswer,
                .semanticValue(.contentItem(
                    LanguageLetterPairsContentProvider.initialConceptID(
                        language: language,
                        initial: initial
                    )
                ))
            )
        }
    }

    func testCorrectnessDoesNotDependOnChoicePosition() throws {
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

    func testDifferentWordsCanResolveToSameInitialConceptIdentity() throws {
        let grapes = try XCTUnwrap(
            LanguageLetterPairsContentProvider.catalogItems.first { $0.stableKey == "fruits_grapes" }
        )
        let garlic = try XCTUnwrap(
            LanguageLetterPairsContentProvider.catalogItems.first { $0.stableKey == "vegetables_garlic" }
        )
        let grapesInitial = try XCTUnwrap(
            LanguageLetterPairsContentProvider.initialLetter(for: grapes, language: .english)
        )
        let garlicInitial = try XCTUnwrap(
            LanguageLetterPairsContentProvider.initialLetter(for: garlic, language: .english)
        )

        XCTAssertEqual(grapesInitial, "G")
        XCTAssertEqual(garlicInitial, "G")
        XCTAssertEqual(
            LanguageLetterPairsContentProvider.initialConceptID(
                language: .english,
                initial: grapesInitial
            ),
            LanguageLetterPairsContentProvider.initialConceptID(
                language: .english,
                initial: garlicInitial
            )
        )
    }

    func testGeneratedChallengeInstancesUseUniqueChallengeIDs() throws {
        let firstChallenge = try makeChallenge(language: .english)
        let secondChallenge = try makeChallenge(language: .english)

        XCTAssertNotEqual(firstChallenge.id, secondChallenge.id)
        XCTAssertEqual(Set(firstChallenge.choices.map(\.id)).count, firstChallenge.choices.count)
        XCTAssertEqual(Set(secondChallenge.choices.map(\.id)).count, secondChallenge.choices.count)
    }

    func testProgressUsesStableExpectedInitialIdentityInsteadOfChallengeInstanceID() throws {
        let challenge = try makeChallenge(language: .english)
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
                .makeFirstLetterChoicesSession(for: .english)
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
        let plus = LanguageFirstLetterChoiceContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnly = LanguageFirstLetterChoiceContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageFirstLetterChoiceContentProvider(
            configuration: .configuration(for: .minikMath)
        )

        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .english))
        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNotNil(englishOnly.challenge(for: request, learnedLanguage: .english))
        XCTAssertNil(englishOnly.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNil(math.challenge(for: request, learnedLanguage: .english))
        XCTAssertNil(math.challenge(for: request, learnedLanguage: .hebrew))
    }

    private var provider: LanguageFirstLetterChoiceContentProvider {
        LanguageFirstLetterChoiceContentProvider(configuration: .configuration(for: .minikPlus))
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

    private func assertPromptImage(
        language: LanguageIdentifier,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let challenge = try makeChallenge(language: language)

        XCTAssertEqual(challenge.prompt.representations.count, 1, file: file, line: line)
        guard case .imageAsset(let image) = challenge.prompt.representations[0] else {
            return XCTFail("Expected image prompt.", file: file, line: line)
        }
        XCTAssertNotNil(
            LanguageWordContentProvider.levelAFruits.first { $0.image == image },
            file: file,
            line: line
        )
    }

    private func assertChoiceLetters(
        in challenge: Challenge,
        language: LanguageIdentifier,
        direction: ContentDirection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for choice in challenge.choices {
            guard case .learningText(let text) = choice.representation else {
                return XCTFail("Expected learning text choice.", file: file, line: line)
            }
            XCTAssertEqual(text.language, language, file: file, line: line)
            XCTAssertEqual(text.direction, direction, file: file, line: line)
            XCTAssertEqual(text.text.count, 1, file: file, line: line)
            XCTAssertEqual(Array(text.text).count, 1, file: file, line: line)
        }
    }

    private func choiceTexts(in challenge: Challenge) throws -> [String] {
        try challenge.choices.map { choice in
            guard case .learningText(let text) = choice.representation else {
                throw TestError.invalidChoiceRepresentation
            }
            return text.text
        }
    }

    private func promptItem(for challenge: Challenge) throws -> LanguageWordCatalogItem {
        guard case .imageAsset(let image) = challenge.prompt.representations[0],
              let item = LanguageWordContentProvider.levelAFruits.first(where: {
                  $0.image == image
              }) else {
            throw TestError.invalidPromptRepresentation
        }
        return item
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
    }
}
