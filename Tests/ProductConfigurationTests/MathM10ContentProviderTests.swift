import Foundation
import XCTest
@testable import MinikPlus

final class MathM10ContentProviderTests: XCTestCase {
    private let provider = MathM10ContentProvider()

    func testPoolCoversEveryFormAndRejectsInvalidTypedRelationships() throws {
        XCTAssertEqual(Set(provider.balancedProblems(count: 6).map(\.form)), Set(MathM10Form.allCases))
        XCTAssertNil(MathTwoStepEquationRepresentation(
            multiplier: 3, offset: 2, result: 20, solution: 7,
            structureID: .init(rawValue: "bad-equation")))
        XCTAssertNil(MathLinearRelationshipRepresentation(
            input: 4, multiplier: 2, offset: 3, output: 12,
            structureID: .init(rawValue: "bad-linear")))
        XCTAssertNil(MathProportionRepresentation(
            leftNumerator: 3, leftDenominator: 4, rightNumerator: 6, missingDenominator: 7,
            structureID: .init(rawValue: "bad-proportion")))
        XCTAssertNil(MathProbabilityRepresentation(
            favorableCount: 6, totalCount: 5, structureID: .init(rawValue: "bad-probability")))
        XCTAssertNil(MathGeometryRepresentation(
            measure: .rectangleArea, width: 4, height: 3, exactValue: 11,
            structureID: .init(rawValue: "bad-geometry")))
    }

    func testEveryChoiceHasExactlyOneExactAnswer() throws {
        for problem in provider.balancedProblems(count: 10) {
            for direction in [MathM10ChoiceDirection.promptToAnswer, .answerToRepresentation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(problem: problem, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(challenge.choices.filter {
                    $0.semanticValue.isNumericallyEquivalent(to: .rational(problem.answer))
                }.count, 1)
            }
        }
    }

    func testProductionFamiliesAndExactProbabilityConstructionAreAvailable() throws {
        XCTAssertEqual(provider.studyCards().count, 10)
        XCTAssertEqual(provider.equivalenceSets().count, 6)
        XCTAssertNotNil(provider.soccerRound())
        for problem in provider.balancedProblems(count: 6) {
            XCTAssertNotNil(provider.buildNumberChallenge(problem: problem))
            XCTAssertNotNil(provider.buildMathChallenge(problem: problem))
            XCTAssertNotNil(provider.towerChallenge(problem: problem))
        }
        let probability = try XCTUnwrap(MathM10ContentProvider.problems.first { $0.form == .probability })
        let round = try XCTUnwrap(provider.probabilityRound(problem: probability))
        XCTAssertEqual(round.target, probability.answer)
        XCTAssertEqual(round.mathLevelID, .m10)
    }

    func testMalformedAnswerTokenOrderAndBoundedFit() throws {
        let problem = MathM10ContentProvider.problems[0]
        let challenge = try XCTUnwrap(provider.buildNumberChallenge(problem: problem))
        let extra = try XCTUnwrap(challenge.availableTokens.first { !challenge.expectedTokenSequence.contains($0.id) })
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        (Array(challenge.expectedTokenSequence.dropLast()) + [extra.id]).forEach { session.selectToken($0) }
        session.submit()
        XCTAssertEqual(session.answerResult, .incorrect)

        let buildMath = try XCTUnwrap(provider.buildMathChallenge(problem: problem))
        let buildExtra = try XCTUnwrap(buildMath.availableTokens.first {
            !buildMath.expectedTokenSequence.contains($0.id)
        })
        var buildSession = try XCTUnwrap(BuildSession(challenges: [buildMath]))
        (Array(buildMath.expectedTokenSequence.dropLast()) + [buildExtra.id]).forEach {
            buildSession.selectToken($0)
        }
        buildSession.submit()
        XCTAssertEqual(buildSession.answerResult, .incorrect)

        let probe = M10FitProbe()
        let rejecting = MathM10ContentProvider(fitGate: MathContentFitGate { _, _ in
            probe.record(); return false
        })
        XCTAssertNil(rejecting.buildNumberChallenge(problem: problem))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
    }
}

private final class M10FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func record() { lock.lock(); value += 1; lock.unlock() }
}
