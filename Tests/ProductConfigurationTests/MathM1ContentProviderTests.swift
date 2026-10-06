import XCTest
@testable import MinikPlus

final class MathM1ContentProviderTests: XCTestCase {
    private let provider = MathM1ContentProvider()

    func testStudyCardsCoverZeroThroughTenAndZeroUsesQuantityRepresentation() throws {
        let cards = provider.studyCards()
        XCTAssertEqual(cards.count, 11)
        XCTAssertEqual(cards.map(\.id.rawValue), (0...10).map { "m1.card.\($0)" })
        guard case .math(.quantity(let zero)) = cards[0].representations[1] else {
            return XCTFail("Expected neutral zero quantity representation.")
        }
        XCTAssertEqual(zero.count, 0)
    }

    func testBothChoiceDirectionsHaveFourUniqueChoicesAndOneCorrectAnswer() throws {
        for target in 0...10 {
            for direction in [MathM1ChoiceDirection.quantityToNumeral, .numeralToQuantity] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(
                    target: target,
                    direction: direction
                ))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, 4)
                XCTAssertEqual(
                    challenge.choices.filter { $0.semanticValue == .integer(target) }.count,
                    1
                )
            }
        }
    }

    func testBuildNumberHasOneExpectedNumeralAndNoKeyboardInteraction() throws {
        let challenge = try XCTUnwrap(provider.buildNumberChallenge(target: 7))
        XCTAssertEqual(challenge.expectedTokenSequence.count, 1)
        XCTAssertEqual(challenge.availableTokens.count, 4)
        XCTAssertEqual(challenge.validationMode, .submitSequence)
    }

    func testBuildCountUsesOneThroughTargetWithExtraZeroToken() throws {
        let challenge = try XCTUnwrap(provider.buildCountChallenge(target: 5))
        XCTAssertEqual(challenge.expectedTokenSequence.count, 5)
        XCTAssertEqual(challenge.availableTokens.count, 6)
        let expected = challenge.expectedTokenSequence.compactMap { id in
            challenge.availableTokens.first { $0.id == id }?.representation
        }
        XCTAssertEqual(expected, (1...5).map { value in
            Representation.math(.numeral(MathNumeralRepresentation(
                value: value,
                structureID: RepresentationStructureID(rawValue: "math.m1.numeral.\(value)")
            )))
        })
    }

    func testBuildCountRejectsZeroButOtherM1ActivitiesIncludeIt() {
        XCTAssertNil(provider.buildCountChallenge(target: 0))
        XCTAssertNotNil(provider.countRound(target: 0))
    }

    func testCountRoundsAlwaysHaveExtraPhysicalTokens() throws {
        for target in 0...10 {
            let round = try XCTUnwrap(provider.countRound(target: target))
            XCTAssertGreaterThan(round.availableTokenIDs.count, target)
            XCTAssertEqual(Set(round.availableTokenIDs).count, round.availableTokenIDs.count)
        }
    }

    func testSoccerUsesAReusablePoolOfAtLeastFourUniqueNumberedBalls() throws {
        let round = try XCTUnwrap(provider.soccerRound())
        XCTAssertEqual(round.answerBalls.count, 6)
        XCTAssertEqual(Set(round.answerBalls.map(\.id)).count, 6)
        XCTAssertEqual(Set(round.answerBalls.map(\.semanticValue)).count, 6)
        XCTAssertEqual(round.challengeTargets.count, round.answerBalls.count)
    }
}
