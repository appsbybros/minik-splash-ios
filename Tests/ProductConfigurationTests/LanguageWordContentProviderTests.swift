import XCTest
@testable import MinikPlus

final class LanguageWordContentProviderTests: XCTestCase {
    func testCatalogMigratesLevelAFruitsInAndroidSourceOrder() {
        let items = LanguageWordContentProvider.levelAFruits

        XCTAssertEqual(items.count, 10)
        XCTAssertEqual(items.map(\.englishText), [
            "Apple", "Lemon", "Plum", "Peach", "Grapes",
            "Mango", "Banana", "Orange", "Lime", "Kiwi"
        ])
        XCTAssertEqual(items.map(\.hebrewText), [
            "תפוח", "לימון", "שזיף", "אפרסק", "ענבים",
            "מנגו", "בננה", "תפוז", "ליים", "קיווי"
        ])
        XCTAssertEqual(items.map(\.image.rawValue), [
            "apple", "lemon", "plum", "peach", "grapes",
            "mango", "banana", "orange", "lime", "kiwi"
        ])
        XCTAssertEqual(items.map(\.stableKey), [
            "fruits_apple", "fruits_lemon", "fruits_plum", "fruits_peach",
            "fruits_grapes", "fruits_mango", "fruits_banana", "fruits_orange",
            "fruits_lime", "fruits_kiwi"
        ])
        XCTAssertEqual(items.map(\.id.rawValue), items.map {
            "language.words.\($0.stableKey)"
        })
        XCTAssertEqual(items.compactMap(\.androidWordID), items.map(\.stableKey))
        XCTAssertTrue(items.allSatisfy { $0.androidLevel == "A" })
        XCTAssertTrue(items.allSatisfy { $0.category == "fruits" })
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
    }

    func testValidRequestUsesImagePromptAndFourLearnedWordChoices() throws {
        let challenge = try makeChallenge(language: .english)

        XCTAssertEqual(challenge.prompt.representations.count, 1)
        guard case .imageAsset = challenge.prompt.representations[0] else {
            return XCTFail("Expected an image prompt.")
        }
        XCTAssertEqual(challenge.choices.count, 4)
        XCTAssertTrue(challenge.choices.allSatisfy {
            if case .learningText = $0.representation { return true }
            return false
        })
    }

    func testChallengeUsesExactContentIdentityAndOneCorrectChoice() throws {
        let challenge = try makeChallenge(language: .english)
        guard case .semanticValue(let expected) = challenge.expectedAnswer else {
            return XCTFail("Expected a semantic answer.")
        }

        XCTAssertEqual(challenge.validationRule, .exactIdentity)
        XCTAssertEqual(challenge.choices.filter { $0.semanticValue == expected }.count, 1)
        XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, 4)
        XCTAssertEqual(Set(challenge.choices.map(\.id)).count, 4)
    }

    func testEnglishAndHebrewChoicesPreserveContentDirection() throws {
        let english = try makeChallenge(language: .english)
        let hebrew = try makeChallenge(language: .hebrew)

        assertChoices(in: english, language: .english, direction: .leftToRight)
        assertChoices(in: hebrew, language: .hebrew, direction: .rightToLeft)
    }

    func testHebrewKiwiRetainsAndroidSpeechCorrection() throws {
        let kiwi = try XCTUnwrap(LanguageWordContentProvider.levelAFruits.first {
            $0.englishText == "Kiwi"
        })
        let representation = try XCTUnwrap(LanguageWordContentProvider.learnedText(
            for: kiwi,
            language: .hebrew
        ))

        XCTAssertEqual(kiwi.hebrewText, "קיווי")
        XCTAssertEqual(kiwi.hebrewSpeechText, "Kiwi")
        XCTAssertEqual(representation.text, "קיווי")
        XCTAssertEqual(representation.speechText, "Kiwi")
        XCTAssertTrue(LanguageWordContentProvider.levelAFruits
            .filter { $0.id != kiwi.id }
            .allSatisfy { $0.hebrewSpeechText == nil })
    }

    func testExplicitChoiceCountsTwoThroughFourAreHonored() throws {
        for count in 2 ... 4 {
            let request = try makeRequest(
                countRequirement: try XCTUnwrap(ContentCountRequirement(
                    kind: .choices,
                    count: count
                ))
            )
            let challenge = try XCTUnwrap(provider.challenge(
                for: request,
                learnedLanguage: .english
            ))
            XCTAssertEqual(challenge.choices.count, count)
        }
    }

    func testInvalidCountRequirementsAreRejected() throws {
        let tooMany = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .choices, count: 5)
        ))
        let items = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .items, count: 4)
        ))

        XCTAssertNil(provider.challenge(for: tooMany, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: items, learnedLanguage: .english))
    }

    func testUnsupportedRequestShapeIsRejected() throws {
        let wrongActivity = try makeRequest(activityType: .multipleChoice)
        let wrongStage = try makeRequest(curriculumStage: LanguageCurriculumStageIDs.alphabet)
        let wrongSkill = try makeRequest(primarySkill: LanguageSkillIDs.alphabetRecognition)
        let wrongInteraction = try makeRequest(interaction: .orderedTokens)

        XCTAssertNil(provider.challenge(for: wrongActivity, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: wrongStage, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: wrongSkill, learnedLanguage: .english))
        XCTAssertNil(provider.challenge(for: wrongInteraction, learnedLanguage: .english))
    }

    func testProductConfigurationEnforcesLearnedLanguagePolicy() throws {
        let request = try makeRequest()
        let plus = LanguageWordContentProvider(configuration: .configuration(for: .minikPlus))
        let englishOnly = LanguageWordContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )

        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .english))
        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNotNil(englishOnly.challenge(for: request, learnedLanguage: .english))
        XCTAssertNil(englishOnly.challenge(for: request, learnedLanguage: .hebrew))
    }

    func testPromptImageAndExpectedIdentityReferToSameCatalogItem() throws {
        for _ in 0 ..< 25 {
            let challenge = try makeChallenge(language: .english)
            guard case .imageAsset(let image) = challenge.prompt.representations[0],
                  case .semanticValue(.contentItem(let expectedID)) = challenge.expectedAnswer else {
                return XCTFail("Expected an image prompt and content-item answer.")
            }
            let item = try XCTUnwrap(LanguageWordContentProvider.levelAFruits.first {
                $0.image == image
            })
            XCTAssertEqual(expectedID, item.id)
        }
    }

    func testPictureToWordSpeechAndProgressUseThePromptWord() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(language: language)
            guard case .imageAsset(let image) = challenge.prompt.representations[0],
                  case .semanticValue(.contentItem(let expectedID)) = challenge.expectedAnswer else {
                return XCTFail("Expected an image prompt and content-item answer.")
            }
            let item = try XCTUnwrap(LanguageWordContentProvider.levelAFruits.first {
                $0.image == image
            })
            let learnedText = try XCTUnwrap(
                LanguageWordContentProvider.learnedText(for: item, language: language)
            )

            XCTAssertEqual(expectedID, item.id)
            XCTAssertEqual(challenge.prompt.learningSpeechCue, learnedText.learningSpeechCue)
            XCTAssertTrue(challenge.choices.allSatisfy { $0.learningSpeechCue != nil })
            XCTAssertEqual(
                MultipleChoiceAttemptIdentity.itemID(
                    for: challenge,
                    usesExpectedSemanticIdentity: true
                ).rawValue,
                item.id.rawValue
            )
            XCTAssertNotEqual(challenge.id.rawValue, item.id.rawValue)
        }
    }

    func testImageToWordFactoryPreservesSixChallengeRetryUntilCorrectProgression() throws {
        var session = try XCTUnwrap(
            LanguageActivitySessionFactory(configuration: .configuration(for: .minikPlus))
                .makeImageToWordSession(for: .english)
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
        XCTAssertEqual(session.pendingAction, .resetAfterIncorrect(challengeID: challengeID))
        session.resetTransientIncorrectAttempt(for: challengeID)

        XCTAssertNil(session.answerResult)
        XCTAssertTrue(session.canSelectChoices)
        XCTAssertEqual(session.currentChallenge.id, challengeID)
    }

    func testEnglishWordToImageUsesLearningTextPromptAndFourImageChoices() throws {
        let challenge = try makeChallenge(
            language: .english,
            skill: LanguageSkillIDs.wordImageAssociation
        )

        XCTAssertEqual(challenge.prompt.representations.count, 1)
        guard case .learningText(let prompt) = challenge.prompt.representations[0] else {
            return XCTFail("Expected a learned-word prompt.")
        }
        XCTAssertEqual(prompt.language, .english)
        XCTAssertEqual(prompt.direction, .leftToRight)
        XCTAssertEqual(challenge.choices.count, 4)
        XCTAssertTrue(challenge.choices.allSatisfy {
            if case .imageAsset = $0.representation { return true }
            return false
        })
    }

    func testHebrewWordToImageUsesRightToLeftPromptAndImageChoices() throws {
        let challenge = try makeChallenge(
            language: .hebrew,
            skill: LanguageSkillIDs.wordImageAssociation
        )

        guard challenge.prompt.representations.count == 1,
              case .learningText(let prompt) = challenge.prompt.representations[0] else {
            return XCTFail("Expected one learned-word prompt.")
        }
        XCTAssertEqual(prompt.language, .hebrew)
        XCTAssertEqual(prompt.direction, .rightToLeft)
        if prompt.text == "קיווי" {
            XCTAssertEqual(prompt.speechText, "Kiwi")
        }
        XCTAssertTrue(challenge.choices.allSatisfy {
            if case .imageAsset = $0.representation { return true }
            return false
        })
    }

    func testWordToImageUsesExactContentIdentityAndSameCategoryChoices() throws {
        let challenge = try makeChallenge(
            language: .english,
            skill: LanguageSkillIDs.wordImageAssociation
        )
        guard case .semanticValue(let expected) = challenge.expectedAnswer else {
            return XCTFail("Expected a semantic answer.")
        }
        let choiceValues = challenge.choices.map(\.semanticValue)
        let catalogByID = Dictionary(uniqueKeysWithValues:
            LanguageWordContentProvider.levelAFruits.map { ($0.id, $0) }
        )

        XCTAssertEqual(challenge.validationRule, .exactIdentity)
        XCTAssertEqual(choiceValues.filter { $0 == expected }.count, 1)
        XCTAssertEqual(Set(choiceValues).count, challenge.choices.count)
        for value in choiceValues {
            guard case .contentItem(let id) = value else {
                return XCTFail("Expected a content-item choice identity.")
            }
            XCTAssertEqual(catalogByID[id]?.category, "fruits")
        }
    }

    func testWordToPictureSpeechAccessibilityAndProgressUseVocabularyIdentity() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try makeChallenge(
                language: language,
                skill: LanguageSkillIDs.wordImageAssociation
            )
            guard case .learningText(let prompt) = challenge.prompt.representations[0],
                  case .semanticValue(.contentItem(let expectedID)) = challenge.expectedAnswer else {
                return XCTFail("Expected a learned-word prompt and content-item answer.")
            }
            let expectedItem = try XCTUnwrap(LanguageWordContentProvider.levelAFruits.first {
                $0.id == expectedID
            })

            XCTAssertEqual(prompt.text, language == .english
                ? expectedItem.englishText
                : expectedItem.hebrewText)
            XCTAssertEqual(challenge.prompt.learningSpeechCue, prompt.learningSpeechCue)
            XCTAssertTrue(challenge.choices.allSatisfy { $0.learningSpeechCue != nil })
            XCTAssertEqual(
                MultipleChoiceAttemptIdentity.itemID(
                    for: challenge,
                    usesExpectedSemanticIdentity: true
                ).rawValue,
                expectedItem.id.rawValue
            )
            XCTAssertNotEqual(challenge.id.rawValue, expectedItem.id.rawValue)
        }
    }

    func testWordToImageFactoryPreservesSixChallengeRetryUntilCorrectProgression() throws {
        var session = try XCTUnwrap(
            LanguageActivitySessionFactory(configuration: .configuration(for: .minikPlus))
                .makeWordToImageSession(for: .hebrew)
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
        XCTAssertEqual(session.pendingAction, .resetAfterIncorrect(challengeID: challengeID))
        session.resetTransientIncorrectAttempt(for: challengeID)

        XCTAssertNil(session.answerResult)
        XCTAssertTrue(session.canSelectChoices)
        XCTAssertEqual(session.currentChallenge.id, challengeID)
    }

    func testWordToImageHonorsChoiceCountsTwoThroughFour() throws {
        for count in 2 ... 4 {
            let request = try makeRequest(
                primarySkill: LanguageSkillIDs.wordImageAssociation,
                countRequirement: try XCTUnwrap(ContentCountRequirement(
                    kind: .choices,
                    count: count
                ))
            )
            let challenge = try XCTUnwrap(provider.challenge(
                for: request,
                learnedLanguage: .english
            ))

            XCTAssertEqual(challenge.choices.count, count)
        }
    }

    func testWordToImageEnforcesEveryProductLanguagePolicy() throws {
        let request = try makeRequest(primarySkill: LanguageSkillIDs.wordImageAssociation)
        let plus = LanguageWordContentProvider(configuration: .configuration(for: .minikPlus))
        let englishOnly = LanguageWordContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageWordContentProvider(configuration: .configuration(for: .minikMath))

        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .english))
        XCTAssertNotNil(plus.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNotNil(englishOnly.challenge(for: request, learnedLanguage: .english))
        XCTAssertNil(englishOnly.challenge(for: request, learnedLanguage: .hebrew))
        XCTAssertNil(math.challenge(for: request, learnedLanguage: .english))
    }

    func testUnsupportedLanguageAndUnrelatedSkillDoNotFallBackToEnglish() throws {
        let unsupportedLanguage = LanguageIdentifier(rawValue: "fr")
        let item = try XCTUnwrap(LanguageWordContentProvider.levelAFruits.first)
        let imageToWord = try makeRequest()
        let wordToImage = try makeRequest(primarySkill: LanguageSkillIDs.wordImageAssociation)
        let unrelatedSkill = try makeRequest(primarySkill: LanguageSkillIDs.alphabetRecognition)

        XCTAssertNil(LanguageWordContentProvider.learnedText(
            for: item,
            language: unsupportedLanguage
        ))
        XCTAssertNil(provider.challenge(for: imageToWord, learnedLanguage: unsupportedLanguage))
        XCTAssertNil(provider.challenge(for: wordToImage, learnedLanguage: unsupportedLanguage))
        XCTAssertNil(provider.challenge(for: unrelatedSkill, learnedLanguage: .english))
    }

    private var provider: LanguageWordContentProvider {
        LanguageWordContentProvider(configuration: .configuration(for: .minikPlus))
    }

    private func makeChallenge(
        language: LanguageIdentifier,
        skill: SkillID = LanguageSkillIDs.wordRecognition
    ) throws -> Challenge {
        let request = try makeRequest(primarySkill: skill)
        return try XCTUnwrap(provider.challenge(for: request, learnedLanguage: language))
    }

    private func makeRequest(
        activityType: ActivityType = .chooseRepresentation,
        curriculumStage: CurriculumStageID = LanguageCurriculumStageIDs.wordsLevelA,
        primarySkill: SkillID = LanguageSkillIDs.wordRecognition,
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

    private func assertChoices(
        in challenge: Challenge,
        language: LanguageIdentifier,
        direction: ContentDirection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for choice in challenge.choices {
            guard case .learningText(let text) = choice.representation else {
                return XCTFail("Expected learning text.", file: file, line: line)
            }
            XCTAssertEqual(text.language, language, file: file, line: line)
            XCTAssertEqual(text.direction, direction, file: file, line: line)
        }
    }
}
