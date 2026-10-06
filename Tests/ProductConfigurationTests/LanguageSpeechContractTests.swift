import XCTest
@testable import MinikPlus

final class LanguageSpeechContractTests: XCTestCase {
    func testLearningTextResolvesSpeechOverrideAndNonTextDoesNotInventSpeech() throws {
        let hebrew = LearningTextRepresentation(
            text: "קיווי",
            language: .hebrew,
            direction: .rightToLeft,
            speechText: "Kiwi"
        )
        XCTAssertEqual(
            hebrew.learningSpeechCue,
            LearningSpeechUtterance(text: "Kiwi", language: .hebrew)
        )
        XCTAssertNil(Representation.imageAsset(AssetReference(rawValue: "fruit")).learningSpeechCue)
    }

    func testFirstLetterDirectionsExposeLearnedLanguagePromptAndChoiceSpeech() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let request = try choiceRequest(skill: LanguageSkillIDs.initialLetterAssociation)
            let pictureToLetter = try XCTUnwrap(
                LanguageFirstLetterChoiceContentProvider(
                    configuration: .configuration(for: .minikPlus),
                    categoryID: .fruits
                ).challenge(for: request, learnedLanguage: language)
            )
            let letterToPicture = try XCTUnwrap(
                LanguageFirstLetterPictureContentProvider(
                    configuration: .configuration(for: .minikPlus),
                    categoryID: .fruits
                ).challenge(for: request, learnedLanguage: language)
            )

            assertCue(pictureToLetter.prompt.learningSpeechCue, language: language)
            pictureToLetter.choices.forEach {
                assertCue($0.learningSpeechCue, language: language)
            }
            assertCue(letterToPicture.prompt.learningSpeechCue, language: language)
            letterToPicture.choices.forEach {
                assertCue($0.learningSpeechCue, language: language)
            }
        }
    }

    func testPictureWordDirectionsExposeSpeechForImageAndTextSurfaces() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let provider = LanguageWordContentProvider(
                configuration: .configuration(for: .minikPlus),
                categoryID: .fruits
            )
            for skill in [
                LanguageSkillIDs.wordRecognition,
                LanguageSkillIDs.wordImageAssociation
            ] {
                let challenge = try XCTUnwrap(provider.challenge(
                    for: try choiceRequest(skill: skill),
                    learnedLanguage: language
                ))

                assertCue(challenge.prompt.learningSpeechCue, language: language)
                challenge.choices.forEach {
                    assertCue($0.learningSpeechCue, language: language)
                }
            }
        }
    }

    func testWordBuildImagePromptAndEveryTokenExposeLearnedLanguageSpeech() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let challenge = try XCTUnwrap(
                LanguageWordBuildContentProvider(
                    configuration: .configuration(for: .minikPlus),
                    categoryID: .fruits
                ).buildChallenge(
                    for: try buildRequest(),
                    learnedLanguage: language
                )
            )

            assertCue(challenge.prompt.learningSpeechCue, language: language)
            challenge.availableTokens.forEach {
                assertCue($0.representation.learningSpeechCue, language: language)
            }
        }
    }

    func testMathRepresentationsDoNotAcquireLearningSpeech() throws {
        let prompt = try XCTUnwrap(Prompt(representations: [
            .mathExpression(MathExpressionRepresentation(
                expression: "2 + 2",
                structureID: RepresentationStructureID(rawValue: "sum")
            ))
        ]))
        XCTAssertNil(prompt.learningSpeechCue)
    }

    private func choiceRequest(skill: SkillID) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: .chooseRepresentation,
            curriculumStage: LanguageCurriculumStageIDs.wordsLevelA,
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(0.5)),
            interaction: .singleChoice,
            countRequirement: nil
        )
    }

    private func buildRequest() throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: .build,
            curriculumStage: LanguageCurriculumStageIDs.wordsLevelA,
            primarySkill: LanguageSkillIDs.wordConstruction,
            difficulty: try XCTUnwrap(Difficulty(0.5)),
            interaction: .orderedTokens,
            countRequirement: nil
        )
    }

    private func assertCue(
        _ cue: LearningSpeechUtterance?,
        language: LanguageIdentifier,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(cue?.language, language, file: file, line: line)
        XCTAssertFalse(cue?.text.isEmpty ?? true, file: file, line: line)
    }
}
