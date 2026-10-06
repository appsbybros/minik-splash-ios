import Foundation
import XCTest
@testable import MinikPlus

final class MathM4ContentProviderTests: XCTestCase {
    private let provider = MathM4ContentProvider()

    func testWeightedPoolCoversPlaceValueAndOperationsWithinOneHundred() {
        let problems = provider.balancedProblems(count: 10)
        XCTAssertEqual(problems.filter { $0.category == .placeValue }.count, 4)
        XCTAssertEqual(problems.filter { $0.category == .addition }.count, 3)
        XCTAssertEqual(problems.filter { $0.category == .subtraction }.count, 3)
        XCTAssertTrue(MathM4ContentProvider.problems.allSatisfy { (0...100).contains($0.answer) })
    }

    func testLearnIncludesPlaceValueOperationsAndMagnitude() {
        let cards = provider.studyCards()
        XCTAssertEqual(cards.count, 10)
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.placeValue })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.addition })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.subtraction })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.magnitude })
    }

    func testChoiceDirectionsHaveFourUniqueAnswersWithOneCorrect() throws {
        for problem in provider.balancedProblems(count: 6) {
            for direction in [MathM4ChoiceDirection.promptToAnswer, .answerToRepresentation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(problem: problem, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, 4)
                XCTAssertEqual(
                    challenge.choices.filter { $0.semanticValue == .integer(problem.answer) }.count,
                    1
                )
            }
        }
    }

    func testBuildNumberSupportsHundredWithDistinctRepeatedZeroIDs() throws {
        let hundred = try XCTUnwrap(MathM4ContentProvider.problems.first { $0.answer == 100 })
        let challenge = try XCTUnwrap(provider.buildNumberChallenge(problem: hundred))
        XCTAssertEqual(challenge.expectedTokenSequence.count, 3)
        XCTAssertEqual(Set(challenge.expectedTokenSequence).count, 3)
        XCTAssertGreaterThan(challenge.availableTokens.count, 3)
    }

    func testBuildQuantityUsesTensAndOnesRatherThanIndividualObjects() throws {
        let fortySeven = try XCTUnwrap(MathM4ContentProvider.problems.first { $0.answer == 47 })
        let round = try XCTUnwrap(provider.structuredRound(problem: fortySeven))
        XCTAssertEqual(round.targetValue, 47)
        XCTAssertEqual(round.expectedUnitCounts[.placeValue(10)], 4)
        XCTAssertEqual(round.expectedUnitCounts[.placeValue(1)], 7)
        XCTAssertLessThan(round.availableTokens.count, round.targetValue)
    }

    func testBuildMathUsesFiveTokenGrammar() throws {
        for problem in provider.balancedProblems(count: 6) {
            let challenge = try XCTUnwrap(provider.buildEquationChallenge(problem: problem))
            XCTAssertEqual(challenge.expectedTokenSequence.count, 5)
            XCTAssertGreaterThan(challenge.availableTokens.count, 5)
        }
    }

    func testTowerSupportsSmallCountAndLargeAnswerTokens() throws {
        let small = try XCTUnwrap(MathM4ContentProvider.problems.first { $0.answer == 12 })
        let count = try XCTUnwrap(provider.countRound(problem: small))
        XCTAssertEqual(count.mathLevelID, .m4)
        XCTAssertGreaterThan(count.availableTokenIDs.count, count.target)

        let large = try XCTUnwrap(MathM4ContentProvider.problems.first { $0.answer == 100 })
        let tokens = try XCTUnwrap(provider.answerTokenTowerChallenge(problem: large))
        XCTAssertEqual(tokens.expectedTokenSequence.count, 3)
        XCTAssertEqual(Set(tokens.expectedTokenSequence).count, 3)
    }

    func testSoccerKeepsSixUniqueReadableAnswers() throws {
        let round = try XCTUnwrap(provider.soccerRound())
        XCTAssertEqual(round.answerBalls.count, 6)
        XCTAssertEqual(Set(round.answerBalls.map(\.semanticValue)).count, 6)
        XCTAssertEqual(round.challengeTargets.count, 6)
    }

    func testGenerationIsBoundedByPresentationFitPolicy() throws {
        let probe = M4FitProbe()
        let rejecting = MathM4ContentProvider(fitGate: MathContentFitGate { _, _ in
            probe.record()
            return false
        })
        let problem = try XCTUnwrap(MathM4ContentProvider.problems.first)
        XCTAssertNil(rejecting.buildNumberChallenge(problem: problem))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
        XCTAssertNil(rejecting.choiceChallenge(problem: problem, direction: .promptToAnswer))
        XCTAssertNil(rejecting.soccerRound())
    }
}

private final class M4FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func record() { lock.lock(); value += 1; lock.unlock() }
}
