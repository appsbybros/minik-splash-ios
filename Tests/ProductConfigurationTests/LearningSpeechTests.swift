import XCTest
@testable import MinikPlus

final class LearningSpeechTests: XCTestCase {
    func testAlphabetCardProducesLetterThenWordAndIgnoresImage() throws {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)
        let card = try XCTUnwrap(
            LanguageLearnContentProvider(configuration: configuration)
                .studyCards(for: .english)
                .first
        )

        let plan = LearningSpeechPlan(card: card)

        XCTAssertEqual(plan.utterances, [
            LearningSpeechUtterance(text: "a", language: .english),
            LearningSpeechUtterance(text: "Apple", language: .english)
        ])
    }

    func testSpeechOverrideDoesNotChangeVisibleText() throws {
        let representation = LearningTextRepresentation(
            text: "A a",
            language: .english,
            direction: .leftToRight,
            speechText: "a"
        )
        let card = try makeCard(representations: [.learningText(representation)])

        XCTAssertEqual(representation.text, "A a")
        XCTAssertEqual(LearningSpeechPlan(card: card).utterances.map(\.text), ["a"])
    }

    func testEnglishUsesUnitedStatesVoiceLocale() {
        XCTAssertEqual(LearningSpeechVoiceLocale.identifier(for: .english), "en-US")
        XCTAssertEqual(
            LearningSpeechVoiceLocale.identifier(for: LanguageIdentifier(rawValue: "fr")),
            "fr"
        )
    }

    func testHebrewUtteranceAndVoiceLocaleRemainHebrew() throws {
        let card = try makeCard(representations: [
            .learningText(LearningTextRepresentation(
                text: "א",
                language: .hebrew,
                direction: .rightToLeft
            ))
        ])
        let plan = LearningSpeechPlan(card: card)

        XCTAssertEqual(plan.utterances, [LearningSpeechUtterance(text: "א", language: .hebrew)])
        XCTAssertEqual(LearningSpeechVoiceLocale.identifier(for: .hebrew), "he-IL")
    }

    func testLearningTextWithoutLanguageIsIgnored() throws {
        let card = try makeCard(representations: [
            .learningText(LearningTextRepresentation(
                text: "Interface text",
                language: nil,
                direction: nil
            ))
        ])

        XCTAssertTrue(LearningSpeechPlan(card: card).utterances.isEmpty)
    }

    func testNonLearningRepresentationsDoNotProduceSpeech() throws {
        let card = try makeCard(representations: [
            .imageAsset(AssetReference(rawValue: "image")),
            .audioAsset(AssetReference(rawValue: "audio")),
            .mathExpression(MathExpressionRepresentation(
                expression: "2 + 3",
                structureID: RepresentationStructureID(rawValue: "math.add.2.3")
            )),
            .visualQuantity(VisualQuantityRepresentation(
                quantity: 5,
                structureID: RepresentationStructureID(rawValue: "math.quantity.5")
            ))
        ])

        XCTAssertTrue(LearningSpeechPlan(card: card).utterances.isEmpty)
    }

    func testCardWithNoSpeakableContentCreatesEmptyPlan() throws {
        let card = try makeCard(representations: [
            .imageAsset(AssetReference(rawValue: "silent-image"))
        ])

        XCTAssertTrue(LearningSpeechPlan(card: card).utterances.isEmpty)
    }

    private func makeCard(representations: [Representation]) throws -> StudyCard {
        try XCTUnwrap(StudyCard(
            id: StudyCardID(rawValue: "speech.test"),
            representations: representations,
            primarySkill: SkillID(rawValue: "speech.skill"),
            curriculumStage: CurriculumStageID(rawValue: "speech.stage")
        ))
    }
}
