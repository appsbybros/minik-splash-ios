import XCTest
@testable import MinikPlus

final class MathCountConstructionSessionTests: XCTestCase {
    func testEveryRoundRequiresMoreAvailableTokensThanTarget() {
        XCTAssertNil(round(target: 3, available: 3))
        XCTAssertNotNil(round(target: 3, available: 4))
    }

    func testZeroIsCorrectWithNoSelectedTokens() throws {
        var session = try XCTUnwrap(MathCountConstructionSession(
            rounds: [try XCTUnwrap(round(target: 0, available: 4))]
        ))
        XCTAssertEqual(session.submit(), .correct)
    }

    func testWrongCountStaysEditableUntilCorrect() throws {
        var session = try XCTUnwrap(MathCountConstructionSession(
            rounds: [try XCTUnwrap(round(target: 2, available: 5))]
        ))
        session.add(session.availableTokenIDs[0])
        XCTAssertEqual(session.submit(), .incorrect)
        session.add(session.availableTokenIDs[0])
        XCTAssertNil(session.answerResult)
        XCTAssertEqual(session.submit(), .correct)
        XCTAssertEqual(session.submissionCount, 2)
    }

    func testOvershootCanBeCorrectedByRemoveOrUndo() throws {
        var session = try XCTUnwrap(MathCountConstructionSession(
            rounds: [try XCTUnwrap(round(target: 1, available: 4))]
        ))
        let first = session.availableTokenIDs[0]
        let second = session.availableTokenIDs[1]
        session.add(first)
        session.add(second)
        XCTAssertEqual(session.submit(), .incorrect)
        session.remove(first)
        XCTAssertEqual(session.currentCount, 1)
        session.add(first)
        session.undo()
        XCTAssertEqual(session.currentCount, 1)
    }

    private func round(target: Int, available: Int) -> MathCountRound? {
        MathCountRound(
            id: ChallengeID(rawValue: "round-\(target)-\(available)"),
            target: target,
            availableTokenIDs: (0..<available).map {
                MathCountTokenID(rawValue: "token-\($0)")
            }
        )
    }
}
