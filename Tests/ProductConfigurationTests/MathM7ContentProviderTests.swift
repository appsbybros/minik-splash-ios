import Foundation
import XCTest
@testable import MinikPlus

final class MathM7ContentProviderTests: XCTestCase {
    private let provider = MathM7ContentProvider()

    func testPoolCoversRequiredTypedFormsAndExactHundredths() {
        XCTAssertTrue(MathM7Form.allCases.allSatisfy { form in MathM7ContentProvider.problems.contains { $0.form == form } })
        XCTAssertTrue(MathM7ContentProvider.problems.contains { $0.value == Rational(numerator: 3, denominator: 10)! })
        XCTAssertTrue(MathM7ContentProvider.problems.contains { $0.value == Rational(numerator: 25, denominator: 100)! })
        XCTAssertTrue(MathM7ContentProvider.problems.contains { $0.value == Rational(numerator: 12, denominator: 100)! })
    }

    func testEquivalenceSetsAreUniqueExactRationals() {
        let sets = provider.equivalenceSets()
        XCTAssertEqual(sets.count, 6)
        XCTAssertEqual(Set(sets.map(\.semanticValue)).count, sets.count)
        XCTAssertTrue(sets.allSatisfy { if case .rational = $0.semanticValue { return true }; return false })
    }

    func testChoiceDirectionsHaveOneOfFourExactAnswers() throws {
        for problem in provider.balancedProblems(count: 6) {
            for direction in [MathM7ChoiceDirection.promptToAnswer, .answerToRepresentation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(problem: problem, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(challenge.choices.filter { $0.semanticValue.isNumericallyEquivalent(to: .rational(problem.value)) }.count, 1)
            }
        }
    }

    func testDecimalBuildAndTowerUseDistinctOrderedTokens() throws {
        let problem = try XCTUnwrap(MathM7ContentProvider.problems.first { $0.decimalText == "0.25" })
        let build = try XCTUnwrap(provider.buildNumberChallenge(problem: problem))
        XCTAssertEqual(build.expectedTokenSequence.count, 4)
        XCTAssertEqual(Set(build.expectedTokenSequence).count, 4)
        XCTAssertEqual(try XCTUnwrap(provider.towerChallenge(problem: problem)).expectedTokenSequence.count, 4)
    }

    func testAllActivityContentAndBoundedFitAreAvailable() throws {
        XCTAssertEqual(provider.studyCards().count, 10)
        XCTAssertEqual(provider.equivalenceSets().count, 6)
        XCTAssertNotNil(provider.soccerRound())
        let problem = try XCTUnwrap(MathM7ContentProvider.problems.first)
        XCTAssertNotNil(provider.fractionRound(problem: problem))
        let probe = M7FitProbe()
        let rejecting = MathM7ContentProvider(fitGate: MathContentFitGate { _, _ in probe.record(); return false })
        XCTAssertNil(rejecting.buildNumberChallenge(problem: problem))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
    }
}

private final class M7FitProbe: @unchecked Sendable {
    private let lock = NSLock(); private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func record() { lock.lock(); value += 1; lock.unlock() }
}
