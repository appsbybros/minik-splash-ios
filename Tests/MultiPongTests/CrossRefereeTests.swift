import XCTest
@testable import MinikMultiPingPong

// Android cross/CrossRefereeTest.kt (MinikCrossPong 828c6fc).

private let away = CrossBallEvent.landed(point: MPPoint(3, 3))

/// Stand-in returned when a helper's rally did not resolve (the failure is already recorded); Kotlin's `!!` would throw.
private let noOutcome = CrossRallyOutcome(rallyId: 0, kind: .net, striker: 0, receiver: nil, faultOwner: nil, deltas: [], scoresAfter: [],
                                          floored: false, nextServer: 0, winner: nil)

private func required(_ outcome: CrossRallyOutcome?, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) -> CrossRallyOutcome {
    guard let outcome else {
        XCTFail("Expected a rally outcome \(message)", file: file, line: line)
        return noOutcome
    }
    return outcome
}

fileprivate extension CrossReferee {
    func bounceAt(_ seat: Int, _ u: Double = 0, _ v: Double = 0.85) -> CrossBallEvent {
        .bounce(point: geometry.fromLocal(seat, u, v), owner: seat)
    }

    @discardableResult
    func withScores(_ values: Int...) -> CrossReferee {
        var state = exportState()
        state.scores = values
        do { try restore(state) } catch { XCTFail("withScores: \(error)") }
        return self
    }

    /// A legal serve; with `to`, its receiving bounce lands in `to`'s territory.
    func legalServe(_ to: Int? = nil) {
        XCTAssertTrue(serve(server))
        XCTAssertNil(ball(bounceAt(server, 0.1, 0.75)))
        XCTAssertEqual(CrossRallyPhase.toReceiver, phase)
        XCTAssertTrue(serving)
        if let to {
            XCTAssertNil(ball(bounceAt(to)))
            XCTAssertEqual(CrossRallyPhase.receivable, phase)
            XCTAssertEqual(to, receiver)
        }
    }

    /// A rally in which `strikerSeat` makes the last hit and `receiverSeat`, responsible after the legal bounce, lets it bounce twice.
    func missedBy(_ receiverSeat: Int, _ strikerSeat: Int) -> CrossRallyOutcome {
        legalServe(server == strikerSeat ? receiverSeat : strikerSeat)
        if receiver == strikerSeat {
            XCTAssertTrue(strike(strikerSeat))
            XCTAssertNil(ball(bounceAt(receiverSeat)))
        }
        XCTAssertEqual(receiverSeat, receiver)
        XCTAssertEqual(strikerSeat, striker)
        return required(ball(bounceAt(receiverSeat, -0.2, 1.0)), "missedBy")
    }

    /// A rally in which `seat`, hitting a return (not the serve), sends the ball off the table.
    func outBy(_ seat: Int) -> CrossRallyOutcome {
        let other = geometry.wrap(seat + 1)
        legalServe(server == seat ? other : seat)
        if receiver == other {
            XCTAssertTrue(strike(other))
            XCTAssertNil(ball(bounceAt(seat)))
        }
        XCTAssertTrue(strike(seat))
        return required(ball(away), "outBy")
    }

    @discardableResult
    func play(_ rally: (CrossReferee) -> CrossRallyOutcome) -> CrossRallyOutcome {
        let outcome = rally(self)
        if winner == nil { XCTAssertTrue(nextRally()) }
        return outcome
    }
}

final class CrossRefereeTests: XCTestCase {
    private let four = CrossGeometry(4)
    private let three = CrossGeometry(3)
    private let a = 0
    private let b = 1
    private let c = 2
    private let d = 3

    // Kotlin: startsAtRallyOneWithTheFirstServerAwaitingTheServe
    func testStartsAtRallyOneWithTheFirstServerAwaitingTheServe() {
        let r = CrossReferee(four, target: 7, firstServer: 6)
        XCTAssertEqual(1, r.rallyId)
        XCTAssertEqual(0, r.ralliesPlayed)
        XCTAssertEqual(c, r.server)
        XCTAssertEqual(c, r.firstServer)
        XCTAssertEqual(CrossRallyPhase.awaitingServe, r.phase)
        XCTAssertEqual([0, 0, 0, 0], r.scores)
        XCTAssertNil(r.winner)
        XCTAssertNil(r.receiver)
        XCTAssertEqual(0, r.hits)
        XCTAssertNil(r.lastOutcome)
        // Swift clamps instead of throwing: Android rejects target 0; iOS corrects a corrupt target to 1.
        XCTAssertEqual(1, CrossReferee(four, target: 0).target)
    }

    // Kotlin: aMissGivesTheStrikerAPointAndTakesOneFromTheReceiver
    func testAMissGivesTheStrikerAPointAndTakesOneFromTheReceiver() {
        let r = CrossReferee(four, target: 11)
        for _ in 0..<4 { r.play { $0.missedBy(self.c, self.a) } }
        for _ in 0..<2 { r.play { $0.missedBy(self.d, self.b) } }
        XCTAssertEqual([4, 2, 0, 0], r.scores)
        let o = r.play { $0.missedBy(self.b, self.a) }
        XCTAssertEqual(CrossRallyKind.missed, o.kind)
        XCTAssertEqual(a, o.striker)
        XCTAssertEqual(b, o.receiver)
        XCTAssertNil(o.faultOwner)
        XCTAssertEqual(b, o.loser)
        XCTAssertEqual([1, -1, 0, 0], o.deltas)
        XCTAssertEqual([5, 1, 0, 0], o.scoresAfter)
        XCTAssertFalse(o.floored)
        XCTAssertNil(o.winner)
        XCTAssertEqual([5, 1, 0, 0], r.scores)
        XCTAssertEqual([5, 2, 0, 0], r.pointsWon)
        XCTAssertEqual([0, 1, 4, 2], r.misses)
        XCTAssertEqual([0, 0, 0, 0], r.faults)
    }

    // Kotlin: aMissByAReceiverAtZeroStillGivesTheStrikerAPoint
    func testAMissByAReceiverAtZeroStillGivesTheStrikerAPoint() {
        let r = CrossReferee(four, target: 11)
        for _ in 0..<4 { r.play { $0.missedBy(self.c, self.a) } }
        let o = r.play { $0.missedBy(self.b, self.a) }
        XCTAssertEqual([1, 0, 0, 0], o.deltas)
        XCTAssertEqual([5, 0, 0, 0], o.scoresAfter)
        XCTAssertTrue(o.floored)
    }

    // Kotlin: aFaultCostsOnlyTheFaultingPlayer
    func testAFaultCostsOnlyTheFaultingPlayer() {
        let r = CrossReferee(four, target: 11)
        for _ in 0..<4 { r.play { $0.missedBy(self.c, self.a) } }
        for _ in 0..<2 { r.play { $0.missedBy(self.d, self.b) } }
        let o = r.play { $0.outBy(self.a) }
        XCTAssertEqual(CrossRallyKind.out, o.kind)
        XCTAssertEqual(a, o.faultOwner)
        XCTAssertEqual(a, o.striker)
        XCTAssertNil(o.receiver)
        XCTAssertEqual([-1, 0, 0, 0], o.deltas)
        XCTAssertEqual([3, 2, 0, 0], r.scores)
        XCTAssertFalse(o.floored)
        XCTAssertEqual(1, r.faults[a])
    }

    // Kotlin: aFaultAtZeroChangesNoScoreButStillEndsTheRally
    func testAFaultAtZeroChangesNoScoreButStillEndsTheRally() {
        let r = CrossReferee(four, target: 11)
        let server = r.server
        let o = r.outBy(a)
        XCTAssertEqual(CrossRallyPhase.resolved, r.phase)
        XCTAssertTrue(r.resolved)
        XCTAssertEqual([0, 0, 0, 0], o.deltas)
        XCTAssertEqual([0, 0, 0, 0], r.scores)
        XCTAssertTrue(o.floored)
        XCTAssertEqual(1, o.rallyId)
        XCTAssertEqual(1, r.ralliesPlayed)
        XCTAssertEqual(four.wrap(server + 1), o.nextServer)
        XCTAssertEqual(o, r.lastOutcome)
        XCTAssertTrue(r.nextRally())
        XCTAssertEqual(2, r.rallyId)
        XCTAssertEqual(four.wrap(server + 1), r.server)
        XCTAssertEqual(CrossRallyPhase.awaitingServe, r.phase)
        XCTAssertFalse(r.nextRally())
    }

    // Kotlin: anOwnSideBounceAfterAReturnIsTheStrikersFault
    func testAnOwnSideBounceAfterAReturnIsTheStrikersFault() {
        let r = CrossReferee(four, target: 11, firstServer: b).withScores(2, 3, 0, 1)
        r.legalServe(a)
        XCTAssertTrue(r.strike(a))
        XCTAssertFalse(r.serving)
        XCTAssertEqual(CrossRallyKind.ownSide, r.verdict(r.bounceAt(a, 0.2, 0.5)))
        let o = required(r.ball(r.bounceAt(a, 0.2, 0.5)))
        XCTAssertEqual(CrossRallyKind.ownSide, o.kind)
        XCTAssertEqual(a, o.faultOwner)
        XCTAssertNil(o.receiver)
        XCTAssertEqual([-1, 0, 0, 0], o.deltas)
        XCTAssertEqual([1, 3, 0, 1], r.scores)
    }

    // Kotlin: aNetBeforeTheReceivingBounceIsTheStrikersFault
    func testANetBeforeTheReceivingBounceIsTheStrikersFault() {
        let r = CrossReferee(four, target: 11).withScores(1, 1, 1, 1)
        r.legalServe(c)
        XCTAssertTrue(r.strike(c))
        let o = required(r.ball(.net(point: MPPoint(-0.2, -0.2), height: 0.04)))
        XCTAssertEqual(CrossRallyKind.net, o.kind)
        XCTAssertEqual(c, o.faultOwner)
        XCTAssertEqual([0, 0, -1, 0], o.deltas)
    }

    // Kotlin: badServesCostOnlyTheServer
    func testBadServesCostOnlyTheServer() {
        let s = c
        let other = d
        let cases: [(String, (CrossReferee) -> CrossRallyOutcome?)] = [
            ("first bounce too short", { r in r.serve(s); return r.ball(r.bounceAt(s, 0, 0.4)) }),
            ("first bounce too wide", { r in r.serve(s); return r.ball(r.bounceAt(s, 0.45, 0.8)) }),
            ("first bounce too deep", { r in r.serve(s); return r.ball(r.bounceAt(s, 0, 1.05)) }),
            ("first bounce on an opponent", { r in r.serve(s); return r.ball(r.bounceAt(other)) }),
            ("net before the own bounce", { r in r.serve(s); return r.ball(.net(point: MPPoint(0, 0), height: 0.02)) }),
            ("off the table before the own bounce", { r in r.serve(s); return r.ball(away) }),
            ("second bounce on the own side", { r in r.legalServe(); return r.ball(r.bounceAt(s, 0, 0.3)) }),
            ("second bounce off the table", { r in r.legalServe(); return r.ball(away) }),
            ("net after the own bounce", { r in r.legalServe(); return r.ball(.net(point: MPPoint(0.1, 0.1), height: 0.05)) }),
            ("weak or backward swipe", { r in r.serveFault(s) }),
        ]
        for (name, rally) in cases {
            let r = CrossReferee(four, target: 11, firstServer: c).withScores(1, 1, 1, 1)
            guard let o = rally(r) else {
                XCTFail("\(name): no outcome")
                continue
            }
            XCTAssertEqual(CrossRallyKind.badServe, o.kind, name)
            XCTAssertEqual(c, o.faultOwner, name)
            XCTAssertEqual(c, o.striker, name)
            XCTAssertNil(o.receiver, name)
            XCTAssertEqual([0, 0, -1, 0], o.deltas, name)
            XCTAssertEqual(1, r.faults[c], name)
            XCTAssertEqual(d, o.nextServer, name)
            XCTAssertEqual(CrossRallyPhase.resolved, r.phase, name)
        }
        let r = CrossReferee(four, target: 11, firstServer: c)
        XCTAssertFalse(r.serve(a))
        XCTAssertNil(r.serveFault(a))
        XCTAssertEqual(CrossRallyPhase.awaitingServe, r.phase)
        XCTAssertFalse(r.serve(c, four.fromLocal(c, 0, 0.3))) // contact outside the server's strike zone
        XCTAssertTrue(r.serve(c, four.home(c)))
    }

    // Kotlin: afterALegalBounceTheReceiversOwnBadShotIsTheReceiversFault
    func testAfterALegalBounceTheReceiversOwnBadShotIsTheReceiversFault() {
        let faults: [CrossBallEvent] = [away, .net(point: MPPoint(0.2, 0.2), height: 0.03)]
        for fault in faults {
            let r = CrossReferee(four, target: 11).withScores(2, 2, 2, 2)
            r.legalServe(b)
            XCTAssertFalse(r.strike(c))
            XCTAssertFalse(r.strike(a))
            XCTAssertFalse(r.strike(d)) // only the receiver may hit
            XCTAssertFalse(r.strike(b, four.fromLocal(b, 0, 0.3))) // ... from inside its strike zone
            XCTAssertTrue(r.strike(b, four.home(b)))
            XCTAssertEqual(b, r.striker)
            XCTAssertNil(r.receiver)
            XCTAssertEqual(1, r.hits)
            XCTAssertEqual(CrossRallyPhase.toReceiver, r.phase)
            XCTAssertFalse(r.strike(b)) // no second contact before the next legal bounce
            let o = required(r.ball(fault))
            XCTAssertEqual(b, o.faultOwner)
            XCTAssertEqual(b, o.striker)
            XCTAssertEqual([0, -1, 0, 0], o.deltas)
        }
        // The receiver's own side after its return.
        let r = CrossReferee(four, target: 11).withScores(2, 2, 2, 2)
        r.legalServe(b)
        XCTAssertTrue(r.strike(b))
        XCTAssertEqual(CrossRallyKind.ownSide, r.ball(r.bounceAt(b, -0.1, 0.7))?.kind)
        XCTAssertEqual([2, 1, 2, 2], r.scores)
    }

    // Kotlin: theReceiverChangesWithEveryLegalBounce
    func testTheReceiverChangesWithEveryLegalBounce() {
        let r = CrossReferee(three, target: 11)
        r.legalServe(b)
        XCTAssertTrue(r.strike(b))
        XCTAssertNil(r.ball(r.bounceAt(a)))
        XCTAssertEqual(a, r.receiver) // back to the server
        XCTAssertTrue(r.strike(a))
        XCTAssertEqual(2, r.hits)
        XCTAssertNil(r.ball(r.bounceAt(c)))
        XCTAssertEqual(c, r.receiver)
        XCTAssertTrue(r.strike(c))
        XCTAssertEqual(3, r.hits)
        XCTAssertNil(r.ball(r.bounceAt(b)))
        XCTAssertEqual(b, r.receiver)
        let o = required(r.ball(r.bounceAt(b, 0.1, 1.0)))
        XCTAssertEqual(CrossRallyKind.missed, o.kind)
        XCTAssertEqual(c, o.striker)
        XCTAssertEqual(b, o.receiver)
        XCTAssertEqual([0, 0, 1], o.deltas)
    }

    // Kotlin: anyEventAfterTheLegalBounceWithoutAReturnIsTheReceiversMiss
    func testAnyEventAfterTheLegalBounceWithoutAReturnIsTheReceiversMiss() {
        let bSeat = b
        let cSeat = c
        let seconds: [(CrossReferee) -> CrossBallEvent] = [
            { $0.bounceAt(bSeat, 0.1, 1.0) },
            { $0.bounceAt(cSeat) },
            { _ in away },
            { _ in .net(point: MPPoint(0.3, -0.3), height: 0.02) },
        ]
        for second in seconds {
            let r = CrossReferee(four, target: 11).withScores(3, 3, 3, 3)
            r.legalServe(b)
            let event = second(r)
            XCTAssertEqual(CrossRallyKind.missed, r.verdict(event))
            let o = required(r.ball(event))
            XCTAssertEqual(CrossRallyKind.missed, o.kind)
            XCTAssertEqual(a, o.striker)
            XCTAssertEqual(b, o.receiver)
            XCTAssertEqual([1, -1, 0, 0], o.deltas)
        }
    }

    // Kotlin: aBallLeavingTheReceiversReachIsMissed
    func testABallLeavingTheReceiversReachIsMissed() {
        let r = CrossReferee(four, target: 11, firstServer: d)
        r.legalServe(b)
        // Still on its way to the strike zone, or inside it: playable.
        XCTAssertNil(r.follow(CrossBallState(position: four.fromLocal(b, 0.1, 0.4), height: 0.1, velocity: four.dir(b), lift: 0.3)))
        XCTAssertNil(r.follow(CrossBallState(position: four.fromLocal(b, 0.5, 1.0), height: 0.2, velocity: four.dir(b), lift: -0.3)))
        // Short and travelling inward, beyond the side, or past the far end: never reachable again.
        XCTAssertTrue(r.unreachable(CrossBallState(position: four.fromLocal(b, 0, 0.5), height: 0.1, velocity: -four.dir(b), lift: 0.3)))
        XCTAssertTrue(r.unreachable(CrossBallState(position: four.fromLocal(b, 0.66, 1.0), height: 0.2, velocity: four.right(b), lift: 0.3)))
        XCTAssertTrue(r.unreachable(CrossBallState(position: four.fromLocal(b, 0, 0.9), height: 0, velocity: MPPoint(0, 0), lift: 0, stopped: true)))
        XCTAssertEqual(CrossRallyPhase.receivable, r.phase)
        let o = required(r.follow(CrossBallState(position: four.fromLocal(b, 0.1, 1.27), height: 0.3, velocity: four.dir(b), lift: -0.2)))
        XCTAssertEqual(CrossRallyKind.missed, o.kind)
        XCTAssertEqual(d, o.striker)
        XCTAssertEqual(b, o.receiver)
        XCTAssertEqual([0, 0, 0, 1], o.deltas)
        XCTAssertTrue(o.floored)
        // Nothing to follow outside RECEIVABLE.
        let fresh = CrossReferee(four, target: 11)
        let dead = CrossBallState(position: MPPoint(9, 9), height: 0, velocity: MPPoint(0, 0), lift: 0, stopped: true)
        XCTAssertFalse(fresh.unreachable(dead))
        fresh.legalServe()
        XCTAssertNil(fresh.follow(dead))
    }

    // Kotlin: eachRallyResolvesExactlyOnce
    func testEachRallyResolvesExactlyOnce() {
        let r = CrossReferee(four, target: 11).withScores(2, 2, 2, 2)
        let o = r.missedBy(b, a)
        let after = r.exportState()
        XCTAssertNil(r.ball(r.bounceAt(c)))
        XCTAssertNil(r.ball(away))
        XCTAssertNil(r.ball(.net(point: MPPoint(0, 0), height: 0)))
        XCTAssertNil(r.verdict(away))
        XCTAssertNil(r.miss())
        XCTAssertNil(r.follow(CrossBallState(position: MPPoint(5, 5), height: 0, velocity: MPPoint(0, 0), lift: 0, stopped: true)))
        XCTAssertFalse(r.strike(b))
        XCTAssertFalse(r.serve(r.server))
        XCTAssertNil(r.serveFault(r.server))
        XCTAssertEqual(after, r.exportState())
        XCTAssertEqual(o, r.lastOutcome)
        XCTAssertEqual([3, 1, 2, 2], r.scores)
        // Stray events before the serve are ignored as well.
        XCTAssertTrue(r.nextRally())
        XCTAssertNil(r.ball(away))
        XCTAssertNil(r.ball(r.bounceAt(a)))
        XCTAssertEqual(CrossRallyPhase.awaitingServe, r.phase)
    }

    // Kotlin: theFirstToReachTheTargetWinsOnceWithoutAWinByTwo
    func testTheFirstToReachTheTargetWinsOnceWithoutAWinByTwo() {
        let r = CrossReferee(four, target: 3)
        r.play { $0.missedBy(self.b, self.a) }
        r.play { $0.missedBy(self.c, self.b) }
        r.play { $0.missedBy(self.c, self.a) }
        r.play { $0.missedBy(self.d, self.b) }
        XCTAssertEqual([2, 2, 0, 0], r.scores)
        XCTAssertNil(r.winner)
        // Faults never lift anybody to the target (rally 6 is served by B, whose bad serve costs B a point).
        r.play { $0.outBy(self.c) }
        XCTAssertEqual(b, r.server)
        r.play { required($0.serveFault($0.server)) }
        XCTAssertEqual([2, 1, 0, 0], r.scores)
        XCTAssertNil(r.winner)
        let o = r.missedBy(d, a)
        XCTAssertEqual(a, o.winner)
        XCTAssertEqual(a, r.winner)
        XCTAssertEqual([3, 1, 0, 0], o.scoresAfter)
        XCTAssertFalse(r.nextRally())
        XCTAssertFalse(r.serve(r.server))
        XCTAssertNil(r.serveFault(r.server))
        XCTAssertNil(r.ball(away))
        XCTAssertEqual(a, r.winner)
        XCTAssertEqual(o, r.lastOutcome)
    }

    // Kotlin: theServeRotatesThroughEverySeatEveryRallyWhateverTheOutcome
    func testTheServeRotatesThroughEverySeatEveryRallyWhateverTheOutcome() {
        for g in [three, four] {
            for first in g.seats {
                let r = CrossReferee(g, target: 50, firstServer: first + g.players)
                var servers: [Int] = []
                for i in 0..<(3 * g.players) {
                    servers.append(r.server)
                    XCTAssertEqual(i + 1, r.rallyId)
                    let o: CrossRallyOutcome
                    switch i % 3 {
                    case 0: o = required(r.serveFault(r.server))
                    case 1: o = r.missedBy(g.wrap(r.server + 1), r.server)
                    default: o = r.outBy(g.wrap(r.server + 2))
                    }
                    XCTAssertEqual(g.wrap(first + i + 1), o.nextServer)
                    XCTAssertTrue(r.nextRally())
                }
                XCTAssertEqual((0..<(3 * g.players)).map { g.wrap(first + $0) }, servers)
            }
        }
    }

    // Kotlin: onlyTheServerServesAndOnlyTheReceiverStrikes
    func testOnlyTheServerServesAndOnlyTheReceiverStrikes() {
        let r = CrossReferee(three, target: 5)
        XCTAssertFalse(r.strike(a))
        XCTAssertFalse(r.mayStrike(a))
        XCTAssertTrue(r.mayServe(a))
        XCTAssertFalse(r.mayServe(b))
        XCTAssertTrue(r.serve(a))
        XCTAssertEqual(CrossRallyPhase.serveOwn, r.phase)
        XCTAssertTrue(r.serving)
        XCTAssertEqual(0, r.hits)
        XCTAssertFalse(r.serve(a))
        XCTAssertFalse(r.strike(a))
        XCTAssertFalse(r.strike(b))
        XCTAssertNil(r.ball(r.bounceAt(a, 0, 0.7)))
        XCTAssertEqual(CrossRallyPhase.toReceiver, r.phase)
        XCTAssertFalse(r.strike(b)) // no volley before the receiving bounce
        XCTAssertNil(r.ball(r.bounceAt(c)))
        XCTAssertTrue(r.mayStrike(c))
        XCTAssertFalse(r.mayStrike(b))
    }

    // Kotlin: exportAndRestoreRoundTrip
    func testExportAndRestoreRoundTrip() throws {
        let r = CrossReferee(four, target: 9, firstServer: 1)
        r.play { $0.missedBy(self.c, self.a) }
        r.play { $0.outBy(self.b) }
        XCTAssertEqual(d, r.server)
        r.legalServe(a)
        let state = r.exportState()
        let copy = CrossReferee(four, target: 9, firstServer: 1)
        try copy.restore(state)
        XCTAssertEqual(state, copy.exportState())
        let missed = r.ball(r.bounceAt(a, 0.1, 1.0))
        XCTAssertEqual(CrossRallyKind.missed, missed?.kind)
        XCTAssertEqual(missed, copy.ball(copy.bounceAt(a, 0.1, 1.0)))
        XCTAssertEqual(r.exportState(), copy.exportState())

        var shortScores = state
        shortScores.scores = [1, 2, 3]
        XCTAssertThrowsError(try copy.restore(shortScores))
        var badServer = state
        badServer.server = 4
        XCTAssertThrowsError(try copy.restore(badServer))
        var overTarget = state
        overTarget.scores = [10, 0, 0, 0]
        XCTAssertThrowsError(try copy.restore(overTarget))
        // Inconsistent snapshots that could never resolve are rejected.
        var noReceiver = state
        noReceiver.receiver = nil
        XCTAssertThrowsError(try copy.restore(noReceiver))
        var wrongPhase = state
        wrongPhase.phase = .toReceiver
        XCTAssertThrowsError(try copy.restore(wrongPhase))
        var liveWinner = state
        liveWinner.winner = 0
        XCTAssertThrowsError(try copy.restore(liveWinner))
        var lowWinner = state
        lowWinner.phase = .resolved
        lowWinner.receiver = nil
        lowWinner.winner = 1
        XCTAssertThrowsError(try copy.restore(lowWinner))
        var won = state
        won.phase = .resolved
        won.scores = [1, 9, 0, 0]
        won.winner = 1
        won.receiver = nil
        try copy.restore(won)
        XCTAssertEqual(1, copy.winner)
        XCTAssertFalse(copy.nextRally())
    }

    // Kotlin: randomInputSequencesKeepTheScoringInvariants
    func testRandomInputSequencesKeepTheScoringInvariants() {
        var random = MPKotlinRandom(intSeed: 77)
        var resolutions = 0
        var misses = 0
        for g in [three, four] {
            for _ in 0..<150 {
                let target = 3 + random.nextIndex(5)
                let r = CrossReferee(g, target: target, firstServer: random.nextIndex(g.players))
                func pick(_ preferred: Int?) -> Int {
                    if let preferred, random.nextIndex(3) > 0 { return preferred }
                    return random.nextIndex(g.players)
                }
                var winner: Int? = nil
                for _ in 0..<600 {
                    let before = r.exportState()
                    var outcome: CrossRallyOutcome? = nil
                    switch random.nextIndex(8) {
                    case 0:
                        let seat = pick(r.server)
                        r.serve(seat)
                    case 1:
                        let seat = pick(r.receiver)
                        r.strike(seat)
                    case 2, 3:
                        var preferred: Int? = r.receiver
                        if r.phase == .serveOwn { preferred = r.server }
                        let seat = pick(preferred)
                        let u = random.nextDouble(-0.5, 0.5)
                        let v = random.nextDouble(0.3, 1.1)
                        outcome = r.ball(.bounce(point: g.fromLocal(seat, u, v), owner: seat))
                    case 4:
                        let event: CrossBallEvent = random.nextBoolean() ? away : .net(point: MPPoint(0, 0), height: 0)
                        outcome = r.ball(event)
                    case 5:
                        let seat = pick(r.server)
                        outcome = r.serveFault(seat)
                    case 6:
                        let px = random.nextDouble(-1.5, 1.5)
                        let py = random.nextDouble(-1.5, 1.5)
                        let vx = random.nextDouble(-1.0, 1.0)
                        let vy = random.nextDouble(-1.0, 1.0)
                        outcome = r.follow(CrossBallState(position: MPPoint(px, py), height: 0.2, velocity: MPPoint(vx, vy), lift: 0))
                    default:
                        r.nextRally()
                    }
                    if let outcome {
                        resolutions += 1
                        if outcome.kind == .missed { misses += 1 }
                        XCTAssertNotEqual(CrossRallyPhase.resolved, before.phase)
                        XCTAssertEqual(before.rallyId, outcome.rallyId)
                        XCTAssertEqual(before.ralliesPlayed + 1, r.ralliesPlayed)
                        XCTAssertEqual(outcome.kind == .missed ? 1 : 0, outcome.deltas.filter { $0 > 0 }.count)
                        XCTAssertTrue(outcome.deltas.allSatisfy { (-1...1).contains($0) } && outcome.deltas.filter { $0 < 0 }.count <= 1)
                        XCTAssertEqual(zip(before.scores, outcome.deltas).map { $0 + $1 }, outcome.scoresAfter)
                        if let loser = outcome.loser { XCTAssertEqual(before.scores[loser] == 0, outcome.floored) } else { XCTFail("no loser") }
                        XCTAssertEqual(g.wrap(r.firstServer + r.ralliesPlayed), outcome.nextServer)
                        XCTAssertEqual(outcome, r.lastOutcome)
                    } else if before.phase == .resolved && r.phase == .resolved {
                        XCTAssertEqual(before, r.exportState())
                    }
                    XCTAssertTrue(r.scores.allSatisfy { (0...target).contains($0) })
                    if r.phase != .resolved {
                        XCTAssertEqual(g.wrap(r.firstServer + r.ralliesPlayed), r.server)
                        XCTAssertEqual(r.ralliesPlayed + 1, r.rallyId)
                    } else {
                        XCTAssertEqual(r.ralliesPlayed, r.rallyId)
                    }
                    if let w = r.winner {
                        if let previous = winner { XCTAssertEqual(previous, w) }
                        winner = w
                        XCTAssertEqual(target, r.score(w))
                        XCTAssertEqual(1, r.scores.filter { $0 >= target }.count)
                    }
                }
            }
        }
        XCTAssertTrue(resolutions > 2000 && misses > 200, "The random walk must exercise real rallies: \(resolutions) / \(misses)")
    }

    // Kotlin: outcomesCompareByContent
    func testOutcomesCompareByContent() {
        let one = CrossRallyOutcome(rallyId: 1, kind: .missed, striker: 0, receiver: 1, faultOwner: nil, deltas: [1, -1, 0],
                                    scoresAfter: [1, 0, 0], floored: true, nextServer: 1, winner: nil)
        var two = one
        two.deltas = [1, -1, 0]
        two.scoresAfter = [1, 0, 0]
        XCTAssertEqual(one, two)
        // Kotlin also compares hashCode(); CrossRallyOutcome is a value type compared by content (not Hashable).
        var different = two
        different.deltas = [1, 0, 0]
        XCTAssertNotEqual(one, different)
        XCTAssertTrue(String(describing: one).contains("[1, -1, 0]"))
    }
}
