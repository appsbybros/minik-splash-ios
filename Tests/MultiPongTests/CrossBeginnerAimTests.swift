import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../cross/CrossBeginnerAimTest.kt (MinikCrossPong 828c6fc).
/// Beginner aiming (user decision): the latest small sideways swipe aims the automatic return, whenever it is made before
/// the hit (not only after the ball's bounce), and a Beginner aim never sends the ball out.
final class CrossBeginnerAimTests: XCTestCase {
    private func table(_ players: Int) -> CrossEngine {
        let seats = players == 3 ? localTable("mia", "june") : localTable("mia", "june", "amber")
        return CrossEngine(seats: seats, control: .beginner, target: 7, seed: 5)
    }

    /// After the local seat's single contact: the seat whose territory received the return (nil when it faulted).
    private func receiverOfReturn(_ e: CrossEngine, file: StaticString = #filePath, line: UInt = #line) -> Int? {
        let events = e.play(4) { (e.referee.striker == 0 && e.referee.phase == .receivable) || e.referee.phase == .resolved }
        XCTAssertTrue(events.contacts(0).count <= 1, "the paddle must have returned the ball once", file: file, line: line)
        if e.referee.phase == .receivable && e.referee.striker == 0 { return e.referee.receiver }
        return nil
    }

    // Kotlin: aSwipeBeforeTheBounceAimsAndNeverGoesOut
    func testASwipeBeforeTheBounceAimsAndNeverGoesOut() {
        for players in 3...4 {
            let e = table(players)
            let from = players == 4 ? 2 : 1
            e.approaching(from: from, to: 0, u: 0.28, v: 0.82)
            let g = e.geometry
            // The finger lands left and swipes 110 dp right onto the ball's line BEFORE it bounces: that is aim (to the
            // right-hand player), limited so the return still lands on the table.
            e.touch(g.fromLocal(0, -0.35, 0.95), down: true)
            e.touch(g.fromLocal(0, 0.28, 0.95), drag: MPPoint(110, 0), down: false)
            XCTAssertEqual(CrossAimMap(g).opponents(0).last, e.aimTarget)
            let contact = e.play(3) { e.referee.striker == 0 }
            XCTAssertEqual(1, contact.contacts(0).count)
            XCTAssertEqual(CrossAimMap(g).opponents(0).last, receiverOfReturn(e), "players=\(players)")
        }
    }

    /// Device-found loop: two idle Beginner humans facing each other returned every neutral ball onto the other's resting
    /// paddle forever. Neutral assisted targets now alternate sides beyond the automatic reach of a centred paddle.
    // Kotlin: neutralReturnsNeverLandOnAnIdleCentredPaddle
    func testNeutralReturnsNeverLandOnAnIdleCentredPaddle() {
        for players in 3...4 {
            let g = CrossGeometry(players)
            let aims = CrossAimMap(g)
            for side in [-1.0, 1.0] {
                let aim = aims.aim(0, dragDp: 0, sender: 1, variation: side)
                let lateral = g.toLocal(aim.opponent, aim.point).u
                XCTAssertTrue(abs(lateral) > CrossEngine.autoReach, "players=\(players) side=\(side) lateral=\(lateral)")
                XCTAssertEqual(aim.opponent, g.owner(aim.point)) // still inside the chosen opponent's territory
            }
        }
    }

    // Kotlin: aSidewaysMoveIntoTheBallAfterTheBounceAims
    func testASidewaysMoveIntoTheBallAfterTheBounceAims() {
        let order = CrossAimMap(CrossGeometry(4)).opponents(0)
        let left = order[0]
        let right = order[order.count - 1]
        let cases: [(Double, Int)] = [(1.0, right), (-1.0, left)]
        for (direction, expected) in cases {
            let e = table(4)
            e.approaching(from: 2, to: 0, u: 0.28, v: 0.82)
            let g = e.geometry
            // Paddle parked out of reach until the ball has bounced.
            e.touch(g.fromLocal(0, 0.28 - direction * 0.55, 1.0), down: true)
            e.endTouch()
            e.play(3) { e.referee.phase == .receivable }
            XCTAssertEqual(0, e.referee.receiver)
            // Then a small sideways move into the ball: the approach direction is the aim.
            let ball = g.toLocal(0, e.ballPosition)
            e.touch(g.fromLocal(0, ball.u - direction * 0.30, ball.v + 0.03), down: true)
            e.touch(g.fromLocal(0, ball.u, ball.v + 0.03), drag: MPPoint(direction * 70.0, 0), down: false)
            XCTAssertEqual(expected, receiverOfReturn(e), "direction=\(direction)")
        }
    }
}
