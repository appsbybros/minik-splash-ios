import Foundation
import XCTest
@testable import MinikPlus

final class MathM9ContentProviderTests: XCTestCase {
    private let provider = MathM9ContentProvider()

    func testPoolCoversEveryFormAndTypedModelsRejectFalseAnswers() throws {
        XCTAssertTrue(MathM9Form.allCases.allSatisfy { form in
            MathM9ContentProvider.problems.contains { $0.form == form }
        })
        XCTAssertEqual(Set(provider.balancedProblems(count: 6).map(\.form)), Set(MathM9Form.allCases))
        XCTAssertNil(MathPowerRepresentation(
            base: 3, exponent: 2, exactValue: 8,
            structureID: .init(rawValue: "bad-power")
        ))
        XCTAssertNil(MathOrderOfOperationsRepresentation(
            first: 2, firstOperation: .addition, second: 3,
            secondOperation: .multiplication, third: 4, exactValue: 20,
            structureID: .init(rawValue: "bad-order")
        ))
        XCTAssertNil(MathOneStepEquationRepresentation(
            operation: .addition, operand: 5, result: 12, solution: 8,
            structureID: .init(rawValue: "bad-equation")
        ))
        let ratio = try XCTUnwrap(MathM9ContentProvider.problems.first { $0.form == .ratio })
        XCTAssertEqual(ratio.answer, try XCTUnwrap(Rational(numerator: 2, denominator: 3)))
    }

    func testEveryChoiceHasExactlyOneExactAnswer() throws {
        for problem in provider.balancedProblems(count: 10) {
            for direction in [MathM9ChoiceDirection.promptToAnswer, .answerToRepresentation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(problem: problem, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(challenge.choices.filter {
                    $0.semanticValue.isNumericallyEquivalent(to: .rational(problem.answer))
                }.count, 1)
            }
        }
    }

    func testBuildNumberSupportsSignedAndFractionTokensAndRejectsMalformedOrder() throws {
        let challenges = try MathM9ContentProvider.problems.map {
            try XCTUnwrap(provider.buildNumberChallenge(problem: $0))
        }
        let visible = challenges.flatMap(\.availableTokens).map(\.representation.accessibilityDescription).joined()
        XCTAssertTrue(visible.contains("-"))
        XCTAssertTrue(visible.contains("/"))
        for challenge in challenges {
            let extra = try XCTUnwrap(challenge.availableTokens.first {
                !challenge.expectedTokenSequence.contains($0.id)
            })
            var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
            (Array(challenge.expectedTokenSequence.dropLast()) + [extra.id]).forEach {
                session.selectToken($0)
            }
            session.submit()
            XCTAssertEqual(session.answerResult, .incorrect)
        }
    }

    func testNumberLineAndEveryProductionContentFamilyAreAvailable() throws {
        XCTAssertEqual(provider.studyCards().count, 10)
        XCTAssertEqual(provider.equivalenceSets().count, 6)
        XCTAssertNotNil(provider.soccerRound())
        for problem in provider.balancedProblems(count: 6) {
            XCTAssertNotNil(provider.buildMathChallenge(problem: problem))
            XCTAssertNotNil(provider.towerChallenge(problem: problem))
        }
        let signed = try XCTUnwrap(MathM9ContentProvider.problems.first { $0.form == .signedNumberLine })
        let round = try XCTUnwrap(provider.numberLineRound(problem: signed))
        XCTAssertEqual(round.mathLevelID, .m9)
        XCTAssertEqual(round.target, signed.answer.numerator)

        let probe = M9FitProbe()
        let rejecting = MathM9ContentProvider(fitGate: MathContentFitGate { _, _ in
            probe.record()
            return false
        })
        XCTAssertNil(rejecting.buildNumberChallenge(problem: signed))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
    }
}

private final class M9FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func record() { lock.lock(); value += 1; lock.unlock() }
}
