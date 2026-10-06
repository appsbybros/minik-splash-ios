import XCTest
@testable import MinikPlus

final class MathFractionConstructionSessionTests: XCTestCase {
    func testRequiresExactSelectedNumeratorAndPreservesRetryAttempts() throws {
        let half = Rational(numerator: 1, denominator: 2)!
        let prompt = Representation.math(.fraction(MathFractionRepresentation(
            value: half, structureID: .init(rawValue: "test.half")
        )))
        let round = try XCTUnwrap(MathFractionConstructionRound(
            id: .init(rawValue: "fraction.half"), target: half, prompt: prompt,
            spokenPrompt: "one half", mathLevelID: .m6, skillID: MathSkillIDs.simpleFractions
        ))
        var session = try XCTUnwrap(MathFractionConstructionSession(rounds: [round]))
        session.addPart()
        session.addPart()
        XCTAssertEqual(session.submit(), .incorrect)
        XCTAssertEqual(session.submissionCount, 1)
        session.removePart()
        XCTAssertEqual(session.submit(), .correct)
        XCTAssertEqual(session.submissionCount, 2)
        session.nextRound()
        XCTAssertTrue(session.isComplete)
    }

    func testSelectionNeverExceedsDenominatorOrDropsBelowZero() throws {
        let quarter = Rational(numerator: 1, denominator: 4)!
        let prompt = Representation.math(.fraction(MathFractionRepresentation(
            value: quarter, structureID: .init(rawValue: "test.quarter")
        )))
        var session = try XCTUnwrap(MathFractionConstructionSession(rounds: [
            MathFractionConstructionRound(
                id: .init(rawValue: "fraction.quarter"), target: quarter, prompt: prompt,
                spokenPrompt: "one quarter", mathLevelID: .m6, skillID: MathSkillIDs.simpleFractions
            )!
        ]))
        for _ in 0..<8 { session.addPart() }
        XCTAssertEqual(session.selectedPartCount, 4)
        for _ in 0..<8 { session.removePart() }
        XCTAssertEqual(session.selectedPartCount, 0)
    }
}
