import XCTest
@testable import MinikPlus

final class MathNumberLinePlacementSessionTests: XCTestCase {
    func testSelectionIsBoundedAndCorrectSubmissionAdvances() throws {
        let first = try round(id: "first", target: -4)
        let second = try round(id: "second", target: 7)
        var session = try XCTUnwrap(MathNumberLinePlacementSession(rounds: [first, second]))

        session.move(by: -100)
        XCTAssertEqual(session.selectedValue, -10)
        session.move(by: .min)
        XCTAssertEqual(session.selectedValue, -10)
        session.move(by: 6)
        XCTAssertEqual(session.submit(), .correct)
        session.nextRound()
        XCTAssertEqual(session.currentRoundIndex, 1)
        XCTAssertEqual(session.selectedValue, 0)
    }

    func testIncorrectSubmissionCanRetryAndCannotAdvance() throws {
        var session = try XCTUnwrap(MathNumberLinePlacementSession(rounds: [try round(id: "only", target: -2)]))
        XCTAssertEqual(session.submit(), .incorrect)
        session.nextRound()
        XCTAssertFalse(session.isComplete)
        session.move(by: -2)
        XCTAssertEqual(session.submit(), .correct)
        XCTAssertEqual(session.submissionCount, 2)
        session.nextRound()
        XCTAssertTrue(session.isComplete)
    }

    func testRoundRejectsOutOfRangeTarget() {
        XCTAssertNil(MathNumberLinePlacementRound(
            id: .init(rawValue: "bad"), lowerBound: -10, upperBound: 10, target: 11,
            prompt: numeral(11), spokenPrompt: "11", mathLevelID: .m9,
            skillID: MathSkillIDs.signedNumbers
        ))
    }

    private func round(id: String, target: Int) throws -> MathNumberLinePlacementRound {
        try XCTUnwrap(MathNumberLinePlacementRound(
            id: .init(rawValue: id), lowerBound: -10, upperBound: 10, target: target,
            prompt: numeral(target), spokenPrompt: String(target), mathLevelID: .m9,
            skillID: MathSkillIDs.signedNumbers
        ))
    }

    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(
            value: value, structureID: .init(rawValue: "test.numeral.\(value)")
        )))
    }
}
