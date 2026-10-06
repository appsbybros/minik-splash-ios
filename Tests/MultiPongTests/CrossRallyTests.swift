import XCTest
@testable import MinikMultiPingPong

// Android cross/CrossRallyTest.kt (MinikCrossPong 828c6fc): geometry, ball, shots and referee together, driven the way the
// engine drives them.
final class CrossRallyTests: XCTestCase {
    private let tuning = MPTuning.values(.easy)

    private struct Run {
        var outcome: CrossRallyOutcome?
        var phases: [CrossRallyPhase]
        var contacts: [Int]
    }

    /// Steps the ball in engine substeps; `returns` maps a receiver to the seat it aims at (absent = no return).
    private func play(_ g: CrossGeometry, _ referee: CrossReferee, _ ball: CrossBall, _ returns: [Int: Int]) -> Run {
        var phases = [referee.phase]
        var contacts: [Int] = []
        for _ in 0..<2400 {
            let event = ball.step(CrossBall.substep)
            var outcome: CrossRallyOutcome? = nil
            if let event { outcome = referee.ball(event) }
            if outcome == nil { outcome = referee.follow(ball.state) }
            if phases.last != referee.phase { phases.append(referee.phase) }
            if let outcome { return Run(outcome: outcome, phases: phases, contacts: contacts) }
            if let receiver = referee.receiver, let aim = returns[receiver], g.inStrikeZone(receiver, ball.position), ball.height <= 0.55 {
                XCTAssertTrue(referee.strike(receiver, ball.position))
                contacts.append(receiver)
                let target = g.fromLocal(aim, 0, 0.8)
                let shot = CrossShots.targeted(g, tuning, from: ball.position, height: ball.height, target: target, pace: CrossShots.basePace(tuning))
                ball.launch(ball.position, ball.height, shot)
                phases.append(referee.phase)
            }
        }
        return Run(outcome: nil, phases: phases, contacts: contacts)
    }

    private func served(_ g: CrossGeometry, _ plan: CrossServe) -> CrossBall {
        CrossBall(g, tuning: tuning, initial: CrossBallState(position: plan.start, height: plan.height, velocity: plan.launch.velocity,
                                                             lift: plan.launch.lift, rebound: plan.rebound))
    }

    // Kotlin: aServedRallyWithReturnsEndsWithTheLastReceiversMiss
    func testAServedRallyWithReturnsEndsWithTheLastReceiversMiss() {
        for g in [CrossGeometry(3), CrossGeometry(4)] {
            let referee = CrossReferee(g, target: 7)
            let aims = CrossAimMap(g)
            let second = aims.aim(0, dragDp: 60).point // right-hand opponent: seat 1
            let plan = CrossShots.serve(g, tuning, server: 0, start: g.home(0), first: g.fromLocal(0, 0, 0.78), second: second,
                                        pace: CrossShots.basePace(tuning))
            let ball = served(g, plan)
            XCTAssertTrue(referee.serve(0, plan.start))
            let last = g.wrap(2)
            let run = play(g, referee, ball, [1: last])
            guard let outcome = run.outcome else {
                XCTFail("The rally never resolved (\(g.players) players)")
                continue
            }
            XCTAssertEqual([1], run.contacts)
            XCTAssertEqual([CrossRallyPhase.serveOwn, .toReceiver, .receivable, .toReceiver, .receivable, .resolved], run.phases)
            XCTAssertEqual(CrossRallyKind.missed, outcome.kind)
            XCTAssertEqual(1, outcome.striker)
            XCTAssertEqual(last, outcome.receiver)
            XCTAssertEqual(1, outcome.deltas[1])
            XCTAssertEqual(1, referee.hits)
            XCTAssertEqual(1, referee.score(1))
        }
    }

    // Kotlin: aReturnAimedIntoTheStrikersOwnTerritoryIsItsFault
    func testAReturnAimedIntoTheStrikersOwnTerritoryIsItsFault() {
        let g = CrossGeometry(4)
        let referee = CrossReferee(g, target: 7)
        let plan = CrossShots.serve(g, tuning, server: 0, start: g.home(0), first: g.fromLocal(0, 0, 0.78), second: g.fromLocal(2, 0, 0.8),
                                    pace: CrossShots.basePace(tuning))
        let ball = served(g, plan)
        XCTAssertTrue(referee.serve(0, plan.start))
        // Seat 2 "returns" into its own arm.
        guard let outcome = play(g, referee, ball, [2: 2]).outcome else { return XCTFail("The rally never resolved") }
        XCTAssertEqual(CrossRallyKind.ownSide, outcome.kind)
        XCTAssertEqual(2, outcome.faultOwner)
    }

    // Kotlin: anUnreturnedServeIsMissedOnceTheBallLeavesTheReceiversReach
    func testAnUnreturnedServeIsMissedOnceTheBallLeavesTheReceiversReach() {
        for g in [CrossGeometry(3), CrossGeometry(4)] {
            for server in g.seats {
                for receiver in g.seats where receiver != server {
                    let referee = CrossReferee(g, target: 7, firstServer: server)
                    let plan = CrossShots.serve(g, tuning, server: server, start: g.home(server), first: g.fromLocal(server, 0.2, 0.7),
                                                second: g.fromLocal(receiver, 0, 0.9), pace: CrossShots.basePace(tuning))
                    let ball = served(g, plan)
                    XCTAssertTrue(referee.serve(server, plan.start))
                    guard let outcome = play(g, referee, ball, [:]).outcome else {
                        XCTFail("No outcome for \(server) -> \(receiver)")
                        continue
                    }
                    XCTAssertEqual(CrossRallyKind.missed, outcome.kind)
                    XCTAssertEqual(server, outcome.striker)
                    XCTAssertEqual(receiver, outcome.receiver)
                    XCTAssertEqual([1], outcome.deltas.filter { $0 != 0 })
                    XCTAssertTrue(outcome.floored)
                    XCTAssertTrue(referee.nextRally())
                    XCTAssertEqual(g.wrap(server + 1), referee.server)
                }
            }
        }
    }
}
