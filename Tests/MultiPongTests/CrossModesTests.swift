import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../cross/CrossModesTest.kt (MinikCrossPong 828c6fc): the user's game types: winner takes all
// (unchanged), elimination (drop-outs, shrinking table, classic duel), top-two tournament tables and tie-breaks.
final class CrossModesTests: XCTestCase {
    /// Kotlin `error(...)` in the stepping helpers.
    private struct NoProgress: Error, CustomStringConvertible {
        let description: String
    }

    /// Seat 0 is an idle local human (Standard: it never taps, so it never hits), the rest house players.
    private func match(_ players: Int, target: Int = 3, mode: CrossMode = .elimination, goal: CrossGoal = .win,
                       seed: Int64 = 11) -> CrossMatch {
        let characters = ["mia", "june", "amber"]
        var seats = [humanSeat(0)]
        for (i, character) in characters.prefix(players - 1).enumerated() { seats.append(houseSeat(i + 1, character)) }
        return CrossMatch(roster: seats, control: .standard, target: target, seed: seed, mode: mode, goal: goal)
    }

    /// Kotlin `houseTable(*lineup)` for a lineup built at run time.
    private func houseRoster(_ characters: [String]) -> [CrossSeat] {
        var seats: [CrossSeat] = []
        for (i, character) in characters.enumerated() { seats.append(houseSeat(i, character)) }
        return seats
    }

    /// Plays until the next resolved rally (seat 0 never returns, so a ball sent to it is missed).
    private func nextOutcome(_ m: CrossMatch, seconds: Double = 8) throws -> (outcome: CrossRallyOutcome, events: [CrossEvent]) {
        var seen: [CrossEvent] = []
        var steps = 0
        while Double(steps) < seconds * 120 {
            steps += 1
            m.advance(CrossEngine.step)
            let drained = m.drainEvents()
            seen += drained
            if let outcome = drained.rallies().first { return (outcome, seen) }
        }
        throw NoProgress(description: "no rally resolved; events=\(seen)")
    }

    @discardableResult
    private func untilNextStage(_ m: CrossMatch) throws -> [CrossEvent] {
        var seen: [CrossEvent] = []
        var steps = 0
        while steps < 10 * 120 {
            steps += 1
            m.advance(CrossEngine.step)
            seen += m.drainEvents()
            if seen.contains(where: { self.isStage($0) }) { return seen }
        }
        throw NoProgress(description: "no new stage; events=\(seen)")
    }

    private func isStage(_ event: CrossEvent) -> Bool {
        if case .stage = event { return true }
        return false
    }

    private func isEliminated(_ event: CrossEvent) -> Bool {
        if case .eliminated = event { return true }
        return false
    }

    // Kotlin: classicScoringGivesEveryErrorToTheOpponent
    func testClassicScoringGivesEveryErrorToTheOpponent() throws {
        let r = CrossReferee(CrossGeometry(2), target: 3, scoring: .classic)
        XCTAssertTrue(r.serve(0))
        XCTAssertNil(r.ball(.bounce(point: r.geometry.fromLocal(0, 0.1, 0.75), owner: 0)))
        // A serve that lands off the table: the server errs, the opponent scores (nobody loses a point).
        let o = try XCTUnwrap(r.ball(.landed(point: MPPoint(3, 3))))
        XCTAssertEqual(.badServe, o.kind)
        XCTAssertEqual([0, 1], o.scoresAfter)
        XCTAssertFalse(o.floored)
        // Swift clamps instead of throwing: classic scoring at a three-player table falls back to multi.
        let three = CrossReferee(CrossGeometry(3), target: 3, scoring: .classic)
        XCTAssertEqual(.multi, three.scoring)
    }

    // Kotlin: belowZeroIsOutAndTheOthersKeepTheirScores
    func testBelowZeroIsOutAndTheOthersKeepTheirScores() throws {
        let m = match(4)
        m.engine.incoming(from: 1, to: 0, scores: [0, 1, 2, 1])
        let (o, events) = try nextOutcome(m)
        XCTAssertEqual(.missed, o.kind)
        XCTAssertEqual(0, o.eliminated)
        XCTAssertNil(o.targetReached)
        XCTAssertTrue(events.contains(.eliminated(seat: 0, lowest: false)))
        XCTAssertEqual([0], m.eliminated)
        XCTAssertNotNil(m.transition)
        XCTAssertTrue(m.localOut)
        try untilNextStage(m)
        XCTAssertEqual(1, m.stage)
        XCTAssertEqual([1, 2, 3], m.active)
        XCTAssertEqual(3, m.engine.players)
        XCTAssertEqual(.elimination, m.engine.scoring)
        // Kept, not reset: 1 gained a point (2), 2 and 3 unchanged.
        XCTAssertEqual([2, 2, 1], m.engine.referee.scores)
        XCTAssertNil(m.engine.localSeat) // the eliminated human watches
    }

    // Kotlin: reachingTheTargetRemovesTheFewestPointsAndResetsEveryone
    func testReachingTheTargetRemovesTheFewestPointsAndResetsEveryone() throws {
        let m = match(4)
        m.engine.incoming(from: 1, to: 0, scores: [2, 2, 1, 0])
        let (o, events) = try nextOutcome(m)
        XCTAssertEqual(1, o.targetReached)
        XCTAssertNil(o.eliminated)
        XCTAssertNil(o.winner)
        XCTAssertTrue(events.contains(.eliminated(seat: 3, lowest: true)))
        try untilNextStage(m)
        XCTAssertEqual([0, 1, 2], m.active)
        XCTAssertEqual([0, 0, 0], m.engine.referee.scores)
    }

    // Kotlin: aTieForTheFewestPointsPlaysOnUntilItBreaks
    func testATieForTheFewestPointsPlaysOnUntilItBreaks() throws {
        let m = match(4)
        m.engine.incoming(from: 1, to: 0, scores: [2, 2, 0, 0])
        let (o, events) = try nextOutcome(m)
        XCTAssertEqual(1, o.targetReached)
        XCTAssertTrue(m.pending)
        XCTAssertFalse(events.contains(where: { self.isEliminated($0) }))
        XCTAssertNil(m.transition)
        XCTAssertEqual(4, m.engine.players)
        // The tie breaks when one of the two lowest gains or loses a point: 0 (now 1) misses 2's ball and drops to 0 → 2 gains.
        m.engine.incoming(from: 2, to: 0, scores: m.engine.referee.scores)
        let (o2, e2) = try nextOutcome(m)
        XCTAssertEqual([0, 3, 1, 0], o2.scoresAfter)
        // Lowest is now shared by seats 0 and 3 again → still pending; scores never went negative.
        XCTAssertTrue(m.pending || e2.contains(where: { self.isEliminated($0) }))
        XCTAssertTrue(o2.scoresAfter.allSatisfy({ $0 >= 0 }))
    }

    // Kotlin: theLastTwoPlayAClassicDuelFromZero
    func testTheLastTwoPlayAClassicDuelFromZero() throws {
        let m = match(3)
        m.engine.incoming(from: 1, to: 0, scores: [0, 1, 1])
        let (o, _) = try nextOutcome(m)
        XCTAssertEqual(0, o.eliminated)
        try untilNextStage(m)
        XCTAssertTrue(m.duel)
        XCTAssertEqual([1, 2], m.active)
        XCTAssertEqual(.classic, m.engine.scoring)
        XCTAssertEqual([0, 0], m.engine.referee.scores)
    }

    // Kotlin: eliminationMatchesFinishWithOneWinnerAndAFullPlacement
    func testEliminationMatchesFinishWithOneWinnerAndAFullPlacement() {
        let characters = ["kyra", "mia", "june", "amber"]
        for players in 3...4 {
            for seed in 1...6 {
                let m = CrossMatch(roster: houseRoster(Array(characters.prefix(players))), control: .beginner, target: 3,
                                   seed: Int64(seed), mode: .elimination)
                var steps = 0
                var events: [CrossEvent] = []
                while !m.finished && steps < 120 * 60 * 30 {
                    steps += 1
                    m.advance(CrossEngine.step)
                    events += m.drainEvents()
                }
                XCTAssertTrue(m.finished, "players=\(players) seed=\(seed) finished")
                XCTAssertEqual(players - 2, m.eliminated.count)
                XCTAssertEqual(Set(0..<players), Set(m.placement))
                XCTAssertEqual(players, m.placement.count)
                XCTAssertEqual(m.winner, m.placement.first)
                XCTAssertEqual(Array(m.eliminated.reversed()), Array(m.placement.dropFirst(2)))
                let stages = events.filter({ self.isStage($0) })
                XCTAssertEqual(players - 2, stages.count)
                let outcomes = events.rallies()
                XCTAssertTrue(outcomes.allSatisfy({ outcome in outcome.scoresAfter.allSatisfy({ $0 >= 0 }) }))
                if let first = m.placement.first {
                    XCTAssertEqual(3, m.scores()[first])
                } else {
                    XCTFail("players=\(players) seed=\(seed) has no placement")
                }
            }
        }
    }

    // Kotlin: aTopTwoTableEndsWhenTwoRemainWithBothQualified
    func testATopTwoTableEndsWhenTwoRemainWithBothQualified() {
        let m = CrossMatch(roster: houseTable("kyra", "mia", "june", "amber"), control: .beginner, target: 3, seed: 5,
                           mode: .elimination, goal: .topTwo)
        var steps = 0
        while !m.finished && steps < 120 * 60 * 30 {
            steps += 1
            m.advance(CrossEngine.step)
            _ = m.drainEvents()
        }
        XCTAssertTrue(m.finished)
        XCTAssertNil(m.winner)
        XCTAssertEqual(2, m.eliminated.count)
        XCTAssertEqual(Set(0...3).subtracting(m.eliminated), Set(m.placement.prefix(2)))
        // Swift clamps instead of throwing: a top-two goal outside an elimination table of 3 or 4 becomes a plain win.
        let plain = CrossMatch(roster: houseTable("kyra", "mia", "june"), control: .beginner, target: 3, seed: 5, goal: .topTwo)
        XCTAssertEqual(.win, plain.goal)
    }

    // Kotlin: tieBreaksGoToTheFirstPointForThreeOrTwoPlayers
    func testTieBreaksGoToTheFirstPointForThreeOrTwoPlayers() throws {
        let three = match(3, target: 1, mode: .winnerTakesAll, goal: .tiebreak)
        XCTAssertEqual(.multi, three.engine.scoring)
        three.engine.incoming(from: 1, to: 0)
        let (o, _) = try nextOutcome(three)
        XCTAssertEqual(1, o.winner)
        XCTAssertTrue(three.finished)
        XCTAssertEqual(1, three.placement.first)
        let two = match(2, target: 1, mode: .winnerTakesAll, goal: .tiebreak)
        XCTAssertEqual(.classic, two.engine.scoring)
        two.engine.incoming(from: 1, to: 0)
        let (o2, _) = try nextOutcome(two)
        XCTAssertEqual(1, o2.winner)
        XCTAssertEqual([1, 0], two.placement)
    }

    // Kotlin: winnerTakesAllIsUnchangedAndSingleStage
    func testWinnerTakesAllIsUnchangedAndSingleStage() throws {
        let m = match(4, mode: .winnerTakesAll)
        m.engine.incoming(from: 1, to: 0, scores: [0, 2, 1, 1])
        let (o, events) = try nextOutcome(m)
        XCTAssertTrue(o.floored)
        XCTAssertNil(o.eliminated)
        XCTAssertEqual(1, o.winner)
        XCTAssertFalse(events.contains(where: { self.isEliminated($0) || self.isStage($0) }))
        XCTAssertTrue(m.finished)
        XCTAssertEqual(1, m.placement.first)
        XCTAssertEqual(0, m.stage)
    }

    // Kotlin: aCheckpointFromALaterStageRebuildsThePeersTable
    func testACheckpointFromALaterStageRebuildsThePeersTable() throws {
        let authority = match(4)
        authority.engine.incoming(from: 1, to: 0, scores: [0, 1, 2, 1])
        _ = try nextOutcome(authority)
        try untilNextStage(authority)
        let peer = CrossMatch(roster: localTable("mia", "june", "amber"), control: .standard, target: 3, seed: 11, networked: true,
                              mode: .elimination)
        peer.authoritative = false
        let state = try CrossMatchState.read(authority.exportState().wire())
        try peer.restoreState(state)
        XCTAssertEqual(1, peer.stage)
        XCTAssertEqual([1, 2, 3], peer.active)
        XCTAssertEqual(3, peer.engine.players)
        XCTAssertEqual([0], peer.eliminated)
        XCTAssertTrue(peer.drainEvents().contains(.eliminated(seat: 0, lowest: true)))
        XCTAssertEqual(authority.engine.referee.exportState(), peer.engine.referee.exportState())
        // A strike made in an earlier stage is refused.
        let strike = CrossStrike(seat: 0, point: authority.engine.ballPosition, height: 0.1, ball: authority.engine.ballState, serve: true,
                                 rallyId: authority.engine.referee.rallyId, hitIndex: 0)
        XCTAssertFalse(peer.applyRemoteStrike(stage: 0, fixtureSeat: 1, strike, rallyId: strike.rallyId, hitIndex: 0))
    }
}
