import XCTest
@testable import MinikPlus

final class DomainFoundationsTests: XCTestCase {
    func testRationalReducesEquivalentFractionsToTheSameValue() throws {
        let oneHalf = try XCTUnwrap(Rational(numerator: 1, denominator: 2))
        let twoFourths = try XCTUnwrap(Rational(numerator: 2, denominator: 4))

        XCTAssertEqual(oneHalf, twoFourths)
    }

    func testRationalNormalizesNegativeDenominator() throws {
        let negativeDenominator = try XCTUnwrap(Rational(numerator: 1, denominator: -2))
        let negativeNumerator = try XCTUnwrap(Rational(numerator: -1, denominator: 2))

        XCTAssertEqual(negativeDenominator, negativeNumerator)
        XCTAssertEqual(negativeDenominator.numerator, -1)
        XCTAssertEqual(negativeDenominator.denominator, 2)
    }

    func testRationalRejectsZeroDenominator() {
        XCTAssertNil(Rational(numerator: 1, denominator: 0))
    }

    func testRationalRejectsUnrepresentableSignNormalization() {
        XCTAssertNil(Rational(numerator: .min, denominator: -1))
    }

    func testSemanticContentItemIdentityRemainsStable() {
        let horse = ContentItemID(rawValue: "animals_horse")

        XCTAssertEqual(SemanticValue.contentItem(horse), .contentItem(horse))
        XCTAssertEqual(horse.rawValue, "animals_horse")
    }

    func testNumericSemanticEqualityUsesNormalizedRationalValues() throws {
        let oneHalf = try XCTUnwrap(Rational(numerator: 1, denominator: 2))
        let twoFourths = try XCTUnwrap(Rational(numerator: 2, denominator: 4))

        XCTAssertEqual(SemanticValue.rational(oneHalf), .rational(twoFourths))
    }

    func testEquivalentNumericResultsRetainDistinctExpressionStructure() {
        let value = SemanticValue.integer(12)
        let threeByFourStructure = RepresentationStructureID(rawValue: "multiply.3-by-4")
        let twoBySixStructure = RepresentationStructureID(rawValue: "multiply.2-by-6")
        let threeByFour = Representation.mathExpression(MathExpressionRepresentation(
            expression: "3 × 4",
            structureID: threeByFourStructure
        ))
        let twoBySix = Representation.mathExpression(MathExpressionRepresentation(
            expression: "2 × 6",
            structureID: twoBySixStructure
        ))
        let firstChoice = Choice(
            id: ChoiceID(rawValue: "choice.3-by-4"),
            representation: threeByFour,
            semanticValue: value
        )
        let secondChoice = Choice(
            id: ChoiceID(rawValue: "choice.2-by-6"),
            representation: twoBySix,
            semanticValue: value
        )

        XCTAssertEqual(firstChoice.semanticValue, secondChoice.semanticValue)
        XCTAssertNotEqual(threeByFourStructure, twoBySixStructure)
        XCTAssertNotEqual(firstChoice.representation, secondChoice.representation)
    }

    func testStructuralExpectedAnswerStoresOnlyStructureIdentity() {
        let structureID = RepresentationStructureID(rawValue: "groups.3-by-4")
        let expectedAnswer = ExpectedAnswer.structure(structureID)

        XCTAssertEqual(expectedAnswer, .structure(structureID))
    }

    func testDifficultyAcceptsBoundaryValues() throws {
        XCTAssertEqual(try XCTUnwrap(Difficulty(0)).value, 0)
        XCTAssertEqual(try XCTUnwrap(Difficulty(1)).value, 1)
    }

    func testDifficultyRejectsValuesOutsideBounds() {
        XCTAssertNil(Difficulty(-0.001))
        XCTAssertNil(Difficulty(1.001))
    }

    func testSkillIDAcceptsFutureIdentifier() {
        let futureSkill = SkillID(rawValue: "fractions.compare.unlike-denominators")

        XCTAssertEqual(futureSkill.rawValue, "fractions.compare.unlike-denominators")
    }

    func testCurriculumStageIDAcceptsFutureStage() {
        let futureStage = CurriculumStageID(rawValue: "M11")

        XCTAssertEqual(futureStage.rawValue, "M11")
    }

    func testEnglishEducationalTextCanBeLeftToRight() {
        let text = LearningTextRepresentation(
            text: "horse",
            language: .english,
            direction: .leftToRight
        )

        XCTAssertEqual(text.language, .english)
        XCTAssertEqual(text.direction, .leftToRight)
    }

    func testHebrewEducationalTextCanBeRightToLeft() {
        let text = LearningTextRepresentation(
            text: "סוס",
            language: .hebrew,
            direction: .rightToLeft
        )

        XCTAssertEqual(text.language, .hebrew)
        XCTAssertEqual(text.direction, .rightToLeft)
    }

    func testArabicEducationalTextCanBeRightToLeft() {
        let arabic = LanguageIdentifier(rawValue: "ar")
        let text = LearningTextRepresentation(
            text: "حصان",
            language: arabic,
            direction: .rightToLeft
        )

        XCTAssertEqual(text.language, arabic)
        XCTAssertEqual(text.direction, .rightToLeft)
    }

    func testPromptContainsEducationalContentWithoutUIInstructions() throws {
        let stimulus = Representation.mathExpression(MathExpressionRepresentation(
            expression: "8 + 5",
            structureID: RepresentationStructureID(rawValue: "addition.8-plus-5")
        ))
        let prompt = try XCTUnwrap(Prompt(representations: [stimulus]))

        XCTAssertEqual(prompt.representations, [stimulus])
    }

    func testChallengeDistinguishesPrimaryAndSecondarySkills() throws {
        let primary = SkillID(rawValue: "addition.within-20")
        let secondary = SkillID(rawValue: "number-recognition")
        let prompt = try XCTUnwrap(Prompt(representations: [
            .mathExpression(MathExpressionRepresentation(
                expression: "8 + 5",
                structureID: RepresentationStructureID(rawValue: "addition.8-plus-5")
            ))
        ]))
        let difficulty = try XCTUnwrap(Difficulty(0.4))
        let challenge = Challenge(
            id: ChallengeID(rawValue: "addition.8-plus-5.answer"),
            prompt: prompt,
            choices: [],
            interaction: .numericInput,
            validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.integer(13)),
            primarySkill: primary,
            secondarySkills: [secondary],
            curriculumStage: CurriculumStageID(rawValue: "M2"),
            difficulty: difficulty
        )

        XCTAssertEqual(challenge.primarySkill, primary)
        XCTAssertEqual(challenge.secondarySkills, [secondary])
        XCTAssertFalse(challenge.secondarySkills.contains(primary))
    }
}
