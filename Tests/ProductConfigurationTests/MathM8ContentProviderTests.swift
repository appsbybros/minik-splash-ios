import Foundation
import XCTest
@testable import MinikPlus

final class MathM8ContentProviderTests: XCTestCase {
    private let provider = MathM8ContentProvider()

    func testPoolCoversEveryM8FormWithExactEquivalence() throws {
        XCTAssertTrue(MathM8Form.allCases.allSatisfy { form in
            MathM8ContentProvider.problems.contains { $0.form == form }
        })
        let half = try XCTUnwrap(MathM8ContentProvider.problems.first { $0.id == "half.fraction" })
        XCTAssertEqual(half.value, try XCTUnwrap(Rational(numerator: 50, denominator: 100)))
        XCTAssertEqual(half.value, try XCTUnwrap(Rational(numerator: 5, denominator: 10)))
    }

    func testEveryChoiceHasExactlyOneExactAnswer() throws {
        for problem in provider.balancedProblems(count: 10) {
            for direction in [MathM8ChoiceDirection.promptToAnswer, .answerToRepresentation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(problem: problem, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(challenge.choices.filter {
                    $0.semanticValue.isNumericallyEquivalent(to: .rational(problem.value))
                }.count, 1)
            }
        }
    }

    func testBuildNumberSupportsDecimalFractionPercentAndRatioTokens() throws {
        let challenges = try MathM8ContentProvider.problems.map {
            try XCTUnwrap(provider.buildNumberChallenge(problem: $0))
        }
        let visible = challenges.flatMap(\.availableTokens).map(\.representation.accessibilityDescription).joined()
        XCTAssertTrue(visible.contains("."))
        XCTAssertTrue(visible.contains("/"))
        XCTAssertTrue(visible.contains("%"))
        XCTAssertTrue(visible.contains(":"))
        XCTAssertTrue(challenges.allSatisfy {
            Set($0.expectedTokenSequence).count == $0.expectedTokenSequence.count
        })
    }

    func testMalformedPercentAndFractionTokenOrdersAreRejected() throws {
        for problem in MathM8ContentProvider.problems.prefix(4) {
            let challenge = try XCTUnwrap(provider.buildNumberChallenge(problem: problem))
            let extra = try XCTUnwrap(challenge.availableTokens.first { !challenge.expectedTokenSequence.contains($0.id) })
            var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
            let malformed = Array(challenge.expectedTokenSequence.dropLast()) + [extra.id]
            malformed.forEach { session.selectToken($0) }
            session.submit()
            XCTAssertEqual(session.answerResult, .incorrect)
        }
    }

    func testAllActivityContentAndBoundedFitAreAvailable() throws {
        XCTAssertEqual(provider.studyCards().count, 10)
        XCTAssertEqual(provider.equivalenceSets().count, 6)
        XCTAssertNotNil(provider.soccerRound())
        for problem in provider.balancedProblems(count: 6) {
            XCTAssertNotNil(provider.proportionRound(problem: problem))
            XCTAssertNotNil(provider.buildMathChallenge(problem: problem))
            XCTAssertNotNil(provider.towerChallenge(problem: problem))
        }
        let probe = M8FitProbe()
        let rejecting = MathM8ContentProvider(fitGate: MathContentFitGate { _, _ in
            probe.record()
            return false
        })
        XCTAssertNil(rejecting.buildNumberChallenge(problem: MathM8ContentProvider.problems[0]))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
    }
}

private final class M8FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func record() { lock.lock(); value += 1; lock.unlock() }
}
