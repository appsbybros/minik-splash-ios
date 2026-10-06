import Foundation
import XCTest
@testable import MinikPlus

final class MathM6ContentProviderTests: XCTestCase {
    private let provider = MathM6ContentProvider()

    func testPoolCoversFluencyFactorsMultiplesAndHalvesQuarters() {
        XCTAssertEqual(MathM6ContentProvider.factFamilies, Array(1...10))
        XCTAssertTrue(MathM6Category.allCases.allSatisfy { category in
            MathM6ContentProvider.problems.contains { $0.category == category }
        })
        XCTAssertTrue(MathM6ContentProvider.problems.compactMap { problem -> (Int, Int)? in
            guard case .division(let dividend, let divisor) = problem.kind else { return nil }
            return (dividend, divisor)
        }.allSatisfy { $0.1 > 0 && $0.0 % $0.1 == 0 })
    }

    func testLearnAndEquivalenceSetsIncludeAllFiveCategories() {
        let cards = provider.studyCards()
        XCTAssertEqual(cards.count, 10)
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.multiplication })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.division })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.factors })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.multiples })
        XCTAssertTrue(cards.contains { $0.primarySkill == MathSkillIDs.simpleFractions })
        XCTAssertEqual(provider.equivalenceSets().count, 5)
    }

    func testBothChoiceDirectionsHaveFourNumericallyUniqueAnswers() throws {
        for problem in provider.balancedProblems(count: 6) {
            for direction in [MathM6ChoiceDirection.promptToAnswer, .answerToRepresentation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(problem: problem, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                for (index, choice) in challenge.choices.enumerated() {
                    XCTAssertFalse(challenge.choices.dropFirst(index + 1).contains {
                        choice.semanticValue.isNumericallyEquivalent(to: $0.semanticValue)
                    })
                }
                XCTAssertEqual(challenge.choices.filter {
                    $0.semanticValue.isNumericallyEquivalent(to: problem.answer)
                }.count, 1)
            }
        }
    }

    func testBuildNumberSupportsHundredAndFractionTokens() throws {
        let hundred = try XCTUnwrap(MathM6ContentProvider.problems.first { $0.answerText == "100" })
        let hundredBuild = try XCTUnwrap(provider.buildNumberChallenge(problem: hundred))
        XCTAssertEqual(hundredBuild.expectedTokenSequence.count, 3)
        XCTAssertEqual(Set(hundredBuild.expectedTokenSequence).count, 3)
        let half = try XCTUnwrap(MathM6ContentProvider.problems.first { $0.answerText == "1/2" })
        XCTAssertEqual(try XCTUnwrap(provider.buildNumberChallenge(problem: half)).expectedTokenSequence.count, 3)
    }

    func testBuildQuantitySupportsGroupsAndFractionBars() throws {
        let multiplication = try XCTUnwrap(MathM6ContentProvider.problems.first {
            $0.category == .multiplication && ($0.integerAnswer ?? 101) <= 50
        })
        let groups = try XCTUnwrap(provider.structuredRound(problem: multiplication))
        XCTAssertEqual(groups.mathLevelID, .m6)
        let half = try XCTUnwrap(MathM6ContentProvider.problems.first { $0.answerText == "1/2" })
        let fraction = try XCTUnwrap(provider.fractionRound(problem: half))
        XCTAssertEqual(fraction.target, Rational(numerator: 1, denominator: 2)!)
        XCTAssertEqual(fraction.mathLevelID, .m6)
    }

    func testBuildMathSoccerAndTowerContracts() throws {
        for problem in provider.balancedProblems(count: 6) {
            XCTAssertEqual(try XCTUnwrap(provider.buildMathChallenge(problem: problem)).expectedTokenSequence.count, 5)
        }
        let soccer = try XCTUnwrap(provider.soccerRound())
        XCTAssertEqual(soccer.answerBalls.count, 6)
        let small = try XCTUnwrap(MathM6ContentProvider.problems.first { ($0.integerAnswer ?? 101) <= 20 })
        XCTAssertGreaterThan(try XCTUnwrap(provider.countRound(problem: small)).availableTokenIDs.count, small.integerAnswer!)
        let half = try XCTUnwrap(MathM6ContentProvider.problems.first { $0.answerText == "1/2" })
        XCTAssertEqual(try XCTUnwrap(provider.answerTokenTowerChallenge(problem: half)).expectedTokenSequence.count, 3)
    }

    func testFitRejectionIsBounded() throws {
        let probe = M6FitProbe()
        let rejecting = MathM6ContentProvider(fitGate: MathContentFitGate { _, _ in probe.record(); return false })
        let problem = try XCTUnwrap(MathM6ContentProvider.problems.first)
        XCTAssertNil(rejecting.buildNumberChallenge(problem: problem))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
        XCTAssertNil(rejecting.choiceChallenge(problem: problem, direction: .promptToAnswer))
        XCTAssertNil(rejecting.soccerRound())
    }
}

private final class M6FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func record() { lock.lock(); value += 1; lock.unlock() }
}
