import XCTest
@testable import MinikMultiPingPong

// Android cross/CrossEventsTest.kt (MinikCrossPong 828c6fc).
final class CrossEventsTests: XCTestCase {
    private func outcome(_ kind: CrossRallyKind, _ striker: Int, _ receiver: Int?, _ fault: Int?, _ deltas: [Int]) -> CrossRallyOutcome {
        CrossRallyOutcome(rallyId: 1, kind: kind, striker: striker, receiver: receiver, faultOwner: fault, deltas: deltas,
                          scoresAfter: Array(repeating: 0, count: deltas.count), floored: false, nextServer: 1, winner: nil)
    }

    private func rally(_ kind: CrossRallyKind, _ striker: Int, _ receiver: Int?, _ fault: Int?, _ deltas: Int...) -> CrossEvent {
        .rally(outcome(kind, striker, receiver, fault, deltas))
    }

    // Kotlin: strokeAndNetSamplesPlayForEverySeat
    func testStrokeAndNetSamplesPlayForEverySeat() {
        let policy = CrossSoundPolicy(localSeat: 2)
        for seat in 0...3 {
            XCTAssertEqual([CrossCue.swing], policy.cues(.swing(seat: seat, id: 1)))
            XCTAssertEqual([CrossCue.contact], policy.cues(.contact(seat: seat, id: 1, point: MPPoint(0, 1), height: 0.1)))
            XCTAssertEqual([CrossCue.net], policy.cues(.net(striker: seat, point: MPPoint(0.1, 0.1), height: 0)))
            XCTAssertEqual([CrossCue](), policy.cues(.bounce(owner: seat, point: MPPoint(0.1, 0.1))))
            XCTAssertEqual([CrossCue](), policy.cues(.served(seat: seat)))
        }
    }

    // Kotlin: pointCuesFollowTheLocalSeat
    func testPointCuesFollowTheLocalSeat() {
        let policy = CrossSoundPolicy(localSeat: 1)
        // The local seat gains: success; the third gain in a row is the special cue.
        XCTAssertEqual([CrossCue.ordinaryPoint], policy.cues(rally(.missed, 1, 0, nil, -1, 1, 0, 0)))
        XCTAssertEqual([CrossCue.ordinaryPoint], policy.cues(rally(.missed, 1, 2, nil, 0, 1, -1, 0)))
        XCTAssertEqual([CrossCue.thirdPoint], policy.cues(rally(.missed, 1, 3, nil, 0, 1, 0, -1)))
        XCTAssertEqual(3, policy.streak)
        // Other seats' points and faults are silent and end the streak.
        XCTAssertEqual([CrossCue](), policy.cues(rally(.missed, 2, 3, nil, 0, 0, 1, -1)))
        XCTAssertEqual(0, policy.streak)
        XCTAssertEqual([CrossCue](), policy.cues(rally(.net, 0, nil, 0, -1, 0, 0, 0)))
        // The local seat's own faults sound as failures, also when floored at 0.
        for kind in [CrossRallyKind.net, .out, .ownSide] {
            XCTAssertEqual([CrossCue.playerFault], policy.cues(rally(kind, 1, nil, 1, 0, -1, 0, 0)))
            XCTAssertEqual([CrossCue.playerFault], policy.cues(rally(kind, 1, nil, 1, 0, 0, 0, 0)))
        }
        // Like the classic policy, a missed receive or a bad serve has no invented failure cue.
        XCTAssertEqual([CrossCue](), policy.cues(rally(.missed, 0, 1, nil, 1, -1, 0, 0)))
        XCTAssertEqual([CrossCue](), policy.cues(rally(.badServe, 1, nil, 1, 0, -1, 0, 0)))
        XCTAssertEqual([CrossCue.ordinaryPoint], policy.cues(rally(.missed, 1, 0, nil, 0, 1, 0, 0)))
        policy.reset()
        XCTAssertEqual(0, policy.streak)
    }

    // Kotlin: applauseOnlyForTheLocalWinnerAndNothingWhenSpectating
    func testApplauseOnlyForTheLocalWinnerAndNothingWhenSpectating() {
        XCTAssertEqual([CrossCue.applause], CrossSoundPolicy(localSeat: 3).cues(.victory(seat: 3)))
        XCTAssertEqual([CrossCue](), CrossSoundPolicy(localSeat: 3).cues(.victory(seat: 0)))
        let spectator = CrossSoundPolicy(localSeat: nil)
        XCTAssertEqual([CrossCue](), spectator.cues(.victory(seat: 0)))
        XCTAssertEqual([CrossCue](), spectator.cues(rally(.missed, 0, 1, nil, 1, -1, 0)))
        XCTAssertEqual([CrossCue.contact], spectator.cues(.contact(seat: 0, id: 4, point: MPPoint(0, 1), height: 0.1)))
    }
}
