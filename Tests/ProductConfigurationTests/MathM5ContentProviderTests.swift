import Foundation
import XCTest
@testable import MinikPlus

final class MathM5ContentProviderTests: XCTestCase {
    private let provider = MathM5ContentProvider()

    func testPolicyUsesConfirmedFamiliesAndExactDivision() {
        XCTAssertEqual(MathM5ContentProvider.policy.factFamilies, [1, 2, 3, 4, 5, 10])
        XCTAssertEqual(provider.balancedProblems(count: 5).filter { $0.operation == .multiplication }.count, 3)
        XCTAssertEqual(provider.balancedProblems(count: 5).filter { $0.operation == .division }.count, 2)
        XCTAssertTrue(MathM5ContentProvider.problems.filter { $0.operation == .division }
            .allSatisfy { $0.right > 0 && $0.left % $0.right == 0 && $0.left / $0.right == $0.answer })
    }

    func testLearnAndPairsPreserveMultiplicationDivisionMeaning() {
        let cards = provider.studyCards()
        XCTAssertEqual(cards.count, 10)
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.multiplication })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.division })
        XCTAssertEqual(provider.equivalenceSets().count, 4)
    }

    func testChoiceDirectionsHaveFourUniqueAnswersAndOneCorrect() throws {
        for problem in provider.balancedProblems(count: 6) {
            for direction in [MathM5ChoiceDirection.promptToAnswer, .answerToRepresentation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(problem: problem, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, 4)
                XCTAssertEqual(challenge.choices.filter { $0.semanticValue == .integer(problem.answer) }.count, 1)
            }
        }
    }

    func testBuildQuantityUsesExactEqualGroupStructure() throws {
        let problem = try XCTUnwrap(MathM5ContentProvider.problems.first { $0.id == "multiply.3.4" })
        let round = try XCTUnwrap(provider.structuredRound(problem: problem))
        XCTAssertEqual(round.targetValue, 12)
        XCTAssertEqual(round.expectedUnitCounts[.equalGroup(itemsPerGroup: 4)], 3)
        XCTAssertTrue(round.availableTokens.contains { $0.unit == .equalGroup(itemsPerGroup: 3) })
    }

    func testBuildMathUsesFiveTokenGrammarAndHundredKeepsRepeatedZeroIDs() throws {
        for problem in provider.balancedProblems(count: 6) {
            XCTAssertEqual(try XCTUnwrap(provider.buildEquationChallenge(problem: problem)).expectedTokenSequence.count, 5)
        }
        let hundred = try XCTUnwrap(MathM5ContentProvider.problems.first { $0.answer == 100 })
        let challenge = try XCTUnwrap(provider.buildNumberChallenge(problem: hundred))
        XCTAssertEqual(challenge.expectedTokenSequence.count, 3)
        XCTAssertEqual(Set(challenge.expectedTokenSequence).count, 3)
    }

    func testSoccerAndTowerPoolsStayReadableAndDistinct() throws {
        let soccer = try XCTUnwrap(provider.soccerRound())
        XCTAssertEqual(soccer.answerBalls.count, 6)
        XCTAssertEqual(Set(soccer.answerBalls.map(\.semanticValue)).count, 6)
        let small = try XCTUnwrap(MathM5ContentProvider.problems.first { $0.answer <= 20 })
        XCTAssertGreaterThan(try XCTUnwrap(provider.countRound(problem: small)).availableTokenIDs.count, small.answer)
        let large = try XCTUnwrap(MathM5ContentProvider.problems.first { $0.answer == 100 })
        XCTAssertEqual(try XCTUnwrap(provider.answerTokenTowerChallenge(problem: large)).expectedTokenSequence.count, 3)
    }

    func testFitRejectionIsBounded() throws {
        let probe = M5FitProbe()
        let rejecting = MathM5ContentProvider(fitGate: MathContentFitGate { _, _ in probe.record(); return false })
        let problem = try XCTUnwrap(MathM5ContentProvider.problems.first)
        XCTAssertNil(rejecting.buildNumberChallenge(problem: problem))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
        XCTAssertNil(rejecting.choiceChallenge(problem: problem, direction: .promptToAnswer))
        XCTAssertNil(rejecting.soccerRound())
    }
}

private final class M5FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func record() { lock.lock(); value += 1; lock.unlock() }
}
