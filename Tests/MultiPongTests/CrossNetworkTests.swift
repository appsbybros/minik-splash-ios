import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../cross/CrossNetworkTest.kt (MinikCrossPong 828c6fc): engine state for checkpoints, remote strikes,
// authority and peers.
final class CrossNetworkTests: XCTestCase {
    /// Seat 0 local, seat 1 a remote human, the rest house players.
    private func room(_ players: Int = 4) -> [CrossSeat] {
        var seats = [humanSeat(0), humanSeat(1, .remote)]
        let characters = ["mia", "june"]
        for (i, character) in characters.prefix(players - 2).enumerated() { seats.append(houseSeat(i + 2, character)) }
        return seats
    }

    /// The other phone's view of the room: seat 0 remote, seat 1 local, the house seats unchanged.
    private func peerRoom() -> [CrossSeat] {
        var seats = room()
        seats[0].kind = .remote
        seats[1].kind = .local
        return seats
    }

    private func networked(_ players: Int = 4, firstServer: Int = 0, authority: Bool = true) -> CrossEngine {
        let e = CrossEngine(seats: room(players), control: .beginner, target: 7, seed: 4, networked: true, firstServer: firstServer)
        e.authoritative = authority
        return e
    }

    /// Checkpoint maps hold only numbers, strings, booleans, lists and maps (what RTDB stores).
    private func assertPlain(_ value: Any?, _ path: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let present = value else { return }
        let mirror = Mirror(reflecting: present)
        if mirror.displayStyle == .optional {
            if let inner = mirror.children.first { assertPlain(inner.value, path, file: file, line: line) }
            return
        }
        let number = present is Int || present is Int64 || present is Double || present is NSNumber
        if present is NSNull || present is String || present is Bool || number { return }
        if let map = present as? [String: Any] {
            for (key, inner) in map { assertPlain(inner, "\(path).\(key)", file: file, line: line) }
            return
        }
        if let list = present as? [Any] {
            for (i, inner) in list.enumerated() { assertPlain(inner, "\(path)[\(i)]", file: file, line: line) }
            return
        }
        XCTFail("\(path) holds \(type(of: present))", file: file, line: line)
    }

    /// Kotlin `null` inside a map (RTDB drops it).
    private func isNull(_ value: Any) -> Bool {
        if value is NSNull { return true }
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }

    /// RTDB returns whole numbers as Long and drops nulls; lists may come back as index maps.
    private func stored(_ value: Any) -> Any {
        if type(of: value) == Int.self, let whole = value as? Int { return Int64(whole) }
        if let map = value as? [String: Any] {
            var out: [String: Any] = [:]
            for (key, inner) in map where !isNull(inner) { out[key] = stored(inner) }
            return out
        }
        if let list = value as? [Any] {
            var out: [String: Any] = [:]
            for (i, inner) in list.enumerated() { out[String(i)] = stored(inner) }
            return out
        }
        return value
    }

    private func servedSeats(_ events: [CrossEvent]) -> [Int] {
        var seats: [Int] = []
        for event in events {
            if case let .served(seat) = event { seats.append(seat) }
        }
        return seats
    }

    private func isRally(_ event: CrossEvent) -> Bool {
        if case .rally = event { return true }
        return false
    }

    private func isRallyOrVictory(_ event: CrossEvent) -> Bool {
        switch event {
        case .rally, .victory: return true
        default: return false
        }
    }

    private func isServedOrContact(_ event: CrossEvent) -> Bool {
        switch event {
        case .served, .contact: return true
        default: return false
        }
    }

    /// A house player is planning to receive the flight in the air.
    private func houseReceiverPlanning(_ e: CrossEngine) -> Bool {
        guard e.referee.phase == .toReceiver, let receiver = e.predictedReceiver else { return false }
        return receiver != 0 && e.plan(receiver) != nil
    }

    // Kotlin: exportAndRestoreMidRallyPreserveScoresRallyAndBall
    func testExportAndRestoreMidRallyPreserveScoresRallyAndBall() throws {
        let seats = localTable("kyra", "mia", "amber")
        let e = CrossEngine(seats: seats, control: .beginner, target: 7, seed: 3, firstServer: 1)
        let script = BeginnerScript(e, seed: 1)
        // Play a few rallies, then stop while a ball is in the air.
        var steps = 0
        while (e.referee.ralliesPlayed < 3 || e.referee.phase != .toReceiver) && steps < 7200 * 10 {
            steps += 1
            script.step()
            e.advance(CrossEngine.step)
        }
        XCTAssertEqual(.toReceiver, e.referee.phase)
        let state = e.exportState()
        let wire = state.wire()
        assertPlain(wire)
        XCTAssertEqual(Int64(CrossState.protocolVersion), (wire["protocol"] as? NSNumber)?.int64Value)
        let restored = try CrossState.read(wire)
        XCTAssertEqual(state, restored)
        let twin = CrossEngine(seats: seats, control: .beginner, target: 7, seed: 3, firstServer: 1)
        try twin.restoreState(restored)
        XCTAssertEqual(state.referee, twin.referee.exportState())
        XCTAssertEqual(e.referee.scores, twin.referee.scores)
        XCTAssertEqual(e.referee.rallyId, twin.referee.rallyId)
        XCTAssertEqual(state.ball, twin.ballState)
        XCTAssertEqual(e.predictedReceiver, twin.predictedReceiver)
        XCTAssertEqual(state.strike, twin.lastCommittedStrike)
        XCTAssertEqual(e.referee.lastOutcome, twin.referee.lastOutcome)
        // The same physics continue identically from the restored state.
        for _ in 0..<20 {
            e.advance(CrossEngine.step)
            twin.advance(CrossEngine.step)
            XCTAssertEqual(e.ballState, twin.ballState)
            XCTAssertEqual(e.referee.exportState(), twin.referee.exportState())
        }
    }

    // Kotlin: aReopenedAuthorityPlansItsHouseReceiverAgainFromTheRestoredRacket
    func testAReopenedAuthorityPlansItsHouseReceiverAgainFromTheRestoredRacket() throws {
        let seats = localTable("kyra", "flare", "gaya")
        let pauses: [Double] = [0.25, 0.9]
        for pause in pauses {
            let e = CrossEngine(seats: seats, control: .beginner, target: 7, seed: 6, firstServer: 1)
            // Run until a house player is planning to receive a flight, then a little longer (mid-approach).
            e.play(20, until: { self.houseReceiverPlanning(e) })
            let receiver = try XCTUnwrap(e.predictedReceiver)
            let plan = try XCTUnwrap(e.plan(receiver))
            XCTAssertTrue(plan.reachable)
            e.play(pause, until: { e.referee.phase != .toReceiver })
            let twin = CrossEngine(seats: seats, control: .beginner, target: 7, seed: 6, firstServer: 1)
            try twin.restoreState(e.exportState())
            XCTAssertEqual(e.motion(receiver).racket, twin.motion(receiver).racket)
            let again = try XCTUnwrap(twin.plan(receiver))
            XCTAssertTrue(again.reachable, "\(pause) \(again)")
            assertNear(plan.point, again.point, 1e-9)
        }
    }

    // Kotlin: restartStartsAFreshMatchWithTheSameSeatsAndControl
    func testRestartStartsAFreshMatchWithTheSameSeatsAndControl() {
        let e = CrossEngine(seats: localTable("mia", "june"), control: .standard, target: 3, seed: 8, firstServer: 1)
        let script = BeginnerScript(e, seed: 2)
        var steps = 0
        while e.referee.ralliesPlayed < 2 && steps < 7200 * 5 {
            steps += 1
            script.step()
            e.advance(CrossEngine.step)
        }
        e.restart()
        XCTAssertEqual(1, e.referee.rallyId)
        XCTAssertEqual(0, e.referee.ralliesPlayed)
        XCTAssertEqual(1, e.referee.server)
        XCTAssertEqual([0, 0, 0], e.referee.scores)
        XCTAssertNil(e.localStrike())
        XCTAssertNil(e.lastCommittedStrike)
        XCTAssertTrue(e.drainEvents().isEmpty)
        XCTAssertEqual(.standard, e.control)
        XCTAssertEqual(.otherServe, e.status)
        let served = e.play(1, until: { e.referee.phase == .serveOwn })
        XCTAssertEqual([1], servedSeats(served))
    }

    // Kotlin: checkpointsReadBackFromStoredNumbersAndRejectOtherProtocols
    func testCheckpointsReadBackFromStoredNumbersAndRejectOtherProtocols() throws {
        let e = networked()
        e.incoming(from: 2, to: 1, scores: [1, 2, 0, 3])
        let state = e.exportState()
        // RTDB returns whole numbers as Long and drops nulls; lists may come back as index maps.
        let storedWire = try XCTUnwrap(stored(state.wire()) as? MPWire)
        let back = try CrossState.read(storedWire)
        XCTAssertEqual(state, back)
        var otherProtocol = state.wire()
        otherProtocol["protocol"] = 1
        XCTAssertThrowsError(try CrossState.read(otherProtocol))
        XCTAssertThrowsError(try CrossState.read([:]))
        let strike = CrossStrike(seat: 1, point: MPPoint(0.1, -1.0), height: 0.2, ball: e.ballState, serve: false, rallyId: 3, hitIndex: 4)
        XCTAssertEqual(strike, CrossStrike.read(strike.wire()))
        assertPlain(strike.wire())
    }

    /// The remote human (seat 1) serves: a two-bounce serve to `receiver`.
    private func remoteServe(_ e: CrossEngine, _ receiver: Int, rallyId: Int? = nil) -> CrossStrike {
        let g = e.geometry
        let plan = CrossShots.serve(g, e.physics, server: 1, start: e.serveSpot(1), first: g.fromLocal(1, 0, 0.78),
                                    second: g.fromLocal(receiver, 0, 0.85), pace: CrossShots.basePace(e.physics))
        let ball = CrossBallState(position: plan.start, height: plan.height, velocity: plan.launch.velocity, lift: plan.launch.lift,
                                  rebound: plan.rebound)
        return CrossStrike(seat: 1, point: plan.start, height: plan.height, ball: ball, serve: true, rallyId: rallyId ?? e.referee.rallyId,
                           hitIndex: 0)
    }

    // Kotlin: remoteStrikesAreAppliedOnceAndStaleOrForeignOnesRefused
    func testRemoteStrikesAreAppliedOnceAndStaleOrForeignOnesRefused() {
        let e = networked(firstServer: 1)
        XCTAssertEqual(.otherServe, e.status)
        let serve = remoteServe(e, 0)
        // Wrong seat (a house seat, the local seat, a seat that does not match the strike), stale rally, wrong hit index.
        var asHouse = serve
        asHouse.seat = 2
        XCTAssertFalse(e.applyRemoteStrike(2, asHouse, rallyId: 1, hitIndex: 0))
        var asLocal = serve
        asLocal.seat = 0
        XCTAssertFalse(e.applyRemoteStrike(0, asLocal, rallyId: 1, hitIndex: 0))
        var mismatched = serve
        mismatched.seat = 3
        XCTAssertFalse(e.applyRemoteStrike(1, mismatched, rallyId: 1, hitIndex: 0))
        var stale = serve
        stale.rallyId = 2
        XCTAssertFalse(e.applyRemoteStrike(1, stale, rallyId: 2, hitIndex: 0))
        var wrongHit = serve
        wrongHit.hitIndex = 1
        XCTAssertFalse(e.applyRemoteStrike(1, wrongHit, rallyId: 1, hitIndex: 1))
        var outside = serve
        outside.point = e.geometry.fromLocal(1, 0, 0.3)
        XCTAssertFalse(e.applyRemoteStrike(1, outside, rallyId: 1, hitIndex: 0)) // outside its strike zone
        let offline = CrossEngine(seats: room(), control: .beginner, target: 7, seed: 4, firstServer: 1)
        XCTAssertFalse(offline.applyRemoteStrike(1, serve, rallyId: 1, hitIndex: 0)) // not networked
        XCTAssertEqual(.awaitingServe, e.referee.phase)
        // Accepted exactly once.
        XCTAssertTrue(e.applyRemoteStrike(1, serve, rallyId: 1, hitIndex: 0))
        let events = e.drainEvents()
        XCTAssertEqual(1, events.contacts(1).count)
        XCTAssertEqual(1, events.swings(1).count)
        XCTAssertEqual([1], servedSeats(events))
        XCTAssertEqual(.serveOwn, e.referee.phase)
        XCTAssertEqual(serve, e.lastCommittedStrike)
        XCTAssertEqual(0, e.predictedReceiver)
        XCTAssertFalse(e.applyRemoteStrike(1, serve, rallyId: 1, hitIndex: 0))
        XCTAssertTrue(e.drainEvents().isEmpty)
        // The local seat returns the serve; a remote "return" before it is the receiver is refused.
        e.play(4, until: { e.referee.phase == .receivable })
        XCTAssertEqual(0, e.referee.receiver)
        var ball = e.ballState
        ball.position = e.geometry.home(1)
        let early = CrossStrike(seat: 1, point: e.geometry.home(1), height: 0.1, ball: ball, serve: false, rallyId: 1, hitIndex: 1)
        XCTAssertFalse(e.applyRemoteStrike(1, early, rallyId: 1, hitIndex: 1))
    }

    // Kotlin: aRemoteReceiverGetsAGraceBeforeItsMissAndALateStrikeStillCounts
    func testARemoteReceiverGetsAGraceBeforeItsMissAndALateStrikeStillCounts() {
        for strikes in [false, true] {
            let e = networked()
            e.incoming(from: 2, to: 1, scores: [0, 1, 1, 0])
            // The ball passes the remote seat; the authority waits graceTime seconds before calling missed.
            let missedAt = e.play(5, until: { e.referee.unreachable(e.ballState) })
            XCTAssertTrue(e.referee.unreachable(e.ballState))
            XCTAssertTrue(missedAt.rallies().isEmpty)
            let waited = e.play(CrossEngine.graceTime - 0.05)
            XCTAssertTrue(waited.rallies().isEmpty)
            XCTAssertEqual(.receivable, e.referee.phase)
            if !strikes {
                let outcomes = e.play(0.2).rallies()
                XCTAssertEqual(1, outcomes.count)
                guard outcomes.count == 1, let outcome = outcomes.first else { continue }
                XCTAssertEqual(.missed, outcome.kind)
                XCTAssertEqual(1, outcome.receiver)
                XCTAssertEqual(2, outcome.striker)
                XCTAssertEqual([0, 0, 2, 0], e.referee.scores)
            } else {
                // The remote phone hit it in time: its strike arrives inside the grace and wins over the timeout.
                let g = e.geometry
                let at = g.fromLocal(1, 0.1, 1.0)
                let launch = CrossShots.targeted(g, e.physics, from: at, height: 0.15, target: g.fromLocal(3, 0, 0.8), pace: 0.9)
                let ball = CrossBallState(position: at, height: 0.15, velocity: launch.velocity, lift: launch.lift)
                let strike = CrossStrike(seat: 1, point: at, height: 0.15, ball: ball, serve: false, rallyId: e.referee.rallyId, hitIndex: 2)
                XCTAssertTrue(e.applyRemoteStrike(1, strike, rallyId: e.referee.rallyId, hitIndex: 2))
                XCTAssertEqual(1, e.referee.striker)
                XCTAssertEqual(3, e.predictedReceiver)
                XCTAssertTrue(e.play(1).rallies().isEmpty)
            }
        }
    }

    // Kotlin: aRemoteStrikeArrivingBeforeTheAuthoritySawTheBounceCatchesUp
    func testARemoteStrikeArrivingBeforeTheAuthoritySawTheBounceCatchesUp() {
        let e = networked()
        e.approaching(from: 2, to: 1)
        XCTAssertEqual(1, e.predictedReceiver)
        XCTAssertEqual(.toReceiver, e.referee.phase)
        let g = e.geometry
        let at = g.fromLocal(1, 0, 1.0)
        let launch = CrossShots.targeted(g, e.physics, from: at, height: 0.15, target: g.fromLocal(0, 0, 0.8), pace: 0.9)
        let ball = CrossBallState(position: at, height: 0.15, velocity: launch.velocity, lift: launch.lift)
        let strike = CrossStrike(seat: 1, point: at, height: 0.15, ball: ball, serve: false, rallyId: 1, hitIndex: 2)
        XCTAssertTrue(e.applyRemoteStrike(1, strike, rallyId: 1, hitIndex: 2))
        XCTAssertEqual(1, e.referee.striker)
        XCTAssertEqual(2, e.referee.hits)
        XCTAssertEqual(0, e.predictedReceiver)
    }

    // Kotlin: aNetworkedPeerNeverResolvesRalliesOrRunsHousePlayers
    func testANetworkedPeerNeverResolvesRalliesOrRunsHousePlayers() throws {
        // The local seat serves on a peer: the ball flies and lands, but only the authority may score it.
        let peer = networked(firstServer: 0, authority: false)
        let g = peer.geometry
        peer.touch(g.fromLocal(0, 0, 0.8))
        peer.touch(g.fromLocal(0, 0, 0.8), drag: MPPoint(60, 0), down: false)
        peer.endTouch()
        let events = peer.play(20)
        XCTAssertEqual(1, events.contacts(0).count)
        let own = try XCTUnwrap(peer.localStrike())
        XCTAssertTrue(own.serve)
        XCTAssertFalse(events.contains(where: { self.isRallyOrVictory($0) }))
        XCTAssertEqual([0, 0, 0, 0], peer.referee.scores)
        XCTAssertEqual(0, peer.referee.ralliesPlayed)
        XCTAssertNotEqual(.resolved, peer.referee.phase)
        let houseIdle = (2...3).allSatisfy({ events.contacts($0).isEmpty && events.swings($0).isEmpty })
        XCTAssertTrue(houseIdle, "house players never strike on a peer")
        // A house server never serves on a peer either; a Pro peer's weak serve is left to the authority as well.
        let houseServes = networked(firstServer: 2, authority: false)
        let houseEvents = houseServes.play(10)
        XCTAssertFalse(houseEvents.contains(where: { self.isServedOrContact($0) }))
        let pro = CrossEngine(seats: room(), control: .pro, target: 7, seed: 4, networked: true)
        pro.authoritative = false
        let spot = pro.geometry.toView(0, pro.serveSpot(0))
        pro.touch(pro.geometry.fromView(0, spot - MPPoint(0, 0.08)))
        pro.touch(pro.geometry.fromView(0, spot + MPPoint(0, 0.08)), velocity: MPPoint(0, 0.5), down: false)
        let weakServe = pro.play(5)
        XCTAssertFalse(weakServe.contains(where: { self.isRally($0) }))
        XCTAssertEqual([0, 0, 0, 0], pro.referee.scores)
        let dropped = try XCTUnwrap(pro.localStrike())
        XCTAssertTrue(dropped.serve)
        // ... which judges the published dropped ball as the server's bad serve.
        let authority = CrossEngine(seats: peerRoom(), control: .pro, target: 7, seed: 4, networked: true)
        XCTAssertTrue(authority.applyRemoteStrike(0, dropped, rallyId: 1, hitIndex: 0))
        let judged = authority.play(3, until: { authority.referee.resolved })
        let outcomes = judged.rallies()
        XCTAssertEqual(1, outcomes.count)
        let outcome = try XCTUnwrap(outcomes.first)
        XCTAssertEqual(.badServe, outcome.kind)
        XCTAssertEqual(0, outcome.faultOwner)
    }

    // Kotlin: peersFollowCheckpointsAnimatingNewStrikesOnceAndKeepingTheirOwnPredictedHit
    func testPeersFollowCheckpointsAnimatingNewStrikesOnceAndKeepingTheirOwnPredictedHit() throws {
        let authority = networked(firstServer: 2)
        let peer = CrossEngine(seats: peerRoom(), control: .beginner, target: 7, seed: 4, networked: true, firstServer: 2)
        peer.authoritative = false
        // The authority's house player serves; the peer animates that serve once from the checkpoint.
        authority.play(1, until: { authority.referee.phase == .serveOwn })
        let checkpoint = authority.exportState()
        try peer.restoreState(checkpoint, preserveInput: true)
        let animated = peer.drainEvents()
        XCTAssertEqual(1, animated.contacts(2).count)
        XCTAssertEqual([2], servedSeats(animated))
        XCTAssertEqual(checkpoint.ball, peer.ballState)
        try peer.restoreState(checkpoint, preserveInput: true)
        XCTAssertTrue(peer.drainEvents().isEmpty, "the same strike is never replayed")
        // The peer predicts its own return at once; the authority applies it; the acknowledging checkpoint never rewinds it.
        authority.incoming(from: 2, to: 1)
        try peer.restoreState(authority.exportState(), preserveInput: true)
        XCTAssertEqual(.yourReturn, peer.status)
        peer.touch(peer.ballAfter(20))
        peer.endTouch()
        peer.play(1.5, until: { peer.referee.striker == 1 })
        let hit = try XCTUnwrap(peer.localStrike())
        XCTAssertEqual(2, hit.hitIndex)
        XCTAssertEqual(1, hit.seat)
        XCTAssertTrue(authority.applyRemoteStrike(1, hit, rallyId: hit.rallyId, hitIndex: hit.hitIndex))
        XCTAssertFalse(authority.applyRemoteStrike(1, hit, rallyId: hit.rallyId, hitIndex: hit.hitIndex))
        for _ in 0..<6 { peer.advance(CrossEngine.step) }
        let live = peer.ballState
        peer.discardEvents()
        try peer.restoreState(authority.exportState(), preserveInput: true)
        XCTAssertEqual(live, peer.ballState)
        XCTAssertTrue(peer.drainEvents().isEmpty)
        // A resolution reaches the peer as one Rally event with the authority's scores.
        authority.play(30, until: { authority.referee.resolved })
        let settledState = authority.exportState()
        try peer.restoreState(settledState, preserveInput: true)
        let outcomes = peer.drainEvents().rallies()
        XCTAssertEqual(1, outcomes.count)
        let outcome = try XCTUnwrap(outcomes.first)
        XCTAssertEqual(settledState.referee.lastOutcome, outcome)
        XCTAssertEqual(settledState.referee.scores, peer.referee.scores)
        try peer.restoreState(settledState, preserveInput: true)
        XCTAssertTrue(peer.drainEvents().rallies().isEmpty)
    }
}
