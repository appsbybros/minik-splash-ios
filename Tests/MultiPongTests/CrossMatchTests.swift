import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../cross/CrossMatchTest.kt (MinikCrossPong 828c6fc): whole matches driven through the public engine API.
final class CrossMatchTests: XCTestCase {
    private struct MatchLog {
        var outcomes: [CrossRallyOutcome]
        var events: [CrossEvent]
        var servers: [Int]
    }

    /// Kotlin `StrokePhase` ordinals: READY 0, ANTICIPATION 1, CONTACT 2, FOLLOW_THROUGH 3, RECOVERY 4.
    private static let readyPhase = 0
    private static let recoveryPhase = 4

    /// Kotlin `Stroke.phase` (ModernEvents.kt) from the iOS stroke's timing.
    private func strokePhase(_ s: MPStroke) -> Int {
        if s.age >= s.total { return 0 }
        if s.age < s.contactAt { return 1 }
        if s.age <= s.windowEnd { return 2 }
        if s.age < s.followEnd { return 3 }
        return 4
    }

    /// Kotlin `houseTable(*lineup)` for a lineup built at run time.
    private func seatsFor(_ characters: [String]) -> [CrossSeat] {
        var seats: [CrossSeat] = []
        for (i, character) in characters.enumerated() { seats.append(houseSeat(i, character)) }
        return seats
    }

    private func victories(_ events: [CrossEvent]) -> [Int] {
        var seats: [Int] = []
        for event in events {
            if case let .victory(seat) = event { seats.append(seat) }
        }
        return seats
    }

    private func isRallyOrServed(_ event: CrossEvent) -> Bool {
        switch event {
        case .rally, .served: return true
        default: return false
        }
    }

    private func isContactOrRally(_ event: CrossEvent) -> Bool {
        switch event {
        case .contact, .rally: return true
        default: return false
        }
    }

    /// Plays `e` to its end with the optional scripted human, checking the scoring invariants on every substep.
    private func playToEnd(_ e: CrossEngine, _ script: BeginnerScript?, minutes: Double = 90,
                           file: StaticString = #filePath, line: UInt = #line) -> MatchLog {
        var events: [CrossEvent] = []
        var servers = [e.referee.server]
        var rally = e.referee.rallyId
        var steps = 0
        let limit: Double = minutes * 7200
        while e.referee.winner == nil && Double(steps) < limit {
            steps += 1
            script?.step()
            e.advance(CrossEngine.step)
            events += e.drainEvents()
            let scores = e.referee.scores
            if !scores.allSatisfy({ $0 >= 0 }) {
                XCTFail("Scores never go below zero: \(scores)", file: file, line: line)
            }
            if e.referee.rallyId != rally {
                XCTAssertEqual(rally + 1, e.referee.rallyId, "The rally identity advances by one", file: file, line: line)
                rally = e.referee.rallyId
                servers.append(e.referee.server)
            }
        }
        XCTAssertNotNil(e.referee.winner, "The match must end", file: file, line: line)
        return MatchLog(outcomes: events.rallies(), events: events, servers: servers)
    }

    private func checkScoring(_ e: CrossEngine, _ played: MatchLog, _ target: Int, file: StaticString = #filePath, line: UInt = #line) {
        let n = e.players
        guard let winner = e.referee.winner else {
            XCTFail("The match has no winner", file: file, line: line)
            return
        }
        // Every rally resolved exactly once, in order, and the serve rotated every rally whatever the outcome.
        XCTAssertEqual(Array(1...e.referee.rallyId), played.outcomes.map { $0.rallyId }, file: file, line: line)
        XCTAssertEqual(e.referee.ralliesPlayed, played.outcomes.count, file: file, line: line)
        for (r, server) in played.servers.enumerated() {
            XCTAssertEqual(crossMod(e.firstServer + r, n), server, "rally \(r + 1)", file: file, line: line)
        }
        for (r, o) in played.outcomes.enumerated() {
            XCTAssertEqual(crossMod(e.firstServer + r + 1, n), o.nextServer, file: file, line: line)
        }
        // Exactly one winner, at the target; everybody else below it; the deltas add up to the scoreboard.
        XCTAssertEqual([winner], victories(played.events), file: file, line: line)
        XCTAssertEqual(target, e.referee.score(winner), file: file, line: line)
        let scores = e.referee.scores
        for (i, s) in scores.enumerated() where i != winner {
            XCTAssertTrue(s >= 0 && s < target, "seat \(i) scored \(s)", file: file, line: line)
        }
        var totals = Array(repeating: 0, count: n)
        for o in played.outcomes {
            for (i, d) in o.deltas.enumerated() { totals[i] += d }
        }
        XCTAssertEqual(scores, totals, file: file, line: line)
        XCTAssertEqual(played.outcomes.last?.winner, winner, file: file, line: line)
        for o in played.outcomes {
            if o.kind == .missed {
                XCTAssertNil(o.faultOwner, file: file, line: line)
                XCTAssertEqual(1, o.deltas[o.striker], file: file, line: line)
            } else {
                XCTAssertNil(o.receiver, file: file, line: line)
                XCTAssertTrue(o.deltas.allSatisfy({ $0 <= 0 }), file: file, line: line)
                XCTAssertEqual(o.faultOwner, o.striker, file: file, line: line)
            }
        }
        // A finished match never starts another rally.
        let after = e.play(10)
        XCTAssertFalse(after.contains(where: { self.isRallyOrServed($0) }), file: file, line: line)
    }

    // Kotlin: oneHumanAndTwoHousePlayersPlayAFullMatch
    func testOneHumanAndTwoHousePlayersPlayAFullMatch() {
        let e = CrossEngine(seats: localTable("mia", "june"), control: .beginner, target: 5, seed: 11)
        let script = BeginnerScript(e, seed: 3)
        let played = playToEnd(e, script)
        checkScoring(e, played, 5)
        XCTAssertTrue(played.events.contacts(0).count >= 5, "The human served and played: \(script.serves)")
        XCTAssertTrue(!played.events.contacts(1).isEmpty && !played.events.contacts(2).isEmpty)
        XCTAssertEqual(e.referee.winner == 0, e.status == .youWon)
    }

    // Kotlin: oneHumanAndThreeHousePlayersPlayAFullMatch
    func testOneHumanAndThreeHousePlayersPlayAFullMatch() {
        let e = CrossEngine(seats: localTable("flare", "amber", "comet"), control: .beginner, target: 5, seed: 12, firstServer: 2)
        let played = playToEnd(e, BeginnerScript(e, seed: 4))
        checkScoring(e, played, 5)
        XCTAssertTrue(played.outcomes.contains(where: { $0.kind == .missed }))
        for seat in 0...3 {
            XCTAssertTrue(!played.events.contacts(seat).isEmpty, "seat \(seat) played")
        }
    }

    // Kotlin: allHouseMatchesFollowTheSameRules
    func testAllHouseMatchesFollowTheSameRules() {
        let fixtures: [(seed: Int64, characters: [String])] = [
            (21, ["gaya", "miniko", "coach67"]),
            (22, ["mia", "june", "amber", "minik"]),
        ]
        for fixture in fixtures {
            let e = CrossEngine(seats: seatsFor(fixture.characters), control: .standard, target: 7, seed: fixture.seed,
                                firstServer: Int(fixture.seed))
            XCTAssertNil(e.localSeat)
            checkScoring(e, playToEnd(e, nil), 7)
        }
    }

    // Kotlin: houseServesAndRallyFaultsIncludeEveryKind
    func testHouseServesAndRallyFaultsIncludeEveryKind() {
        var kinds = Set<CrossRallyKind>()
        for seed in 30...33 {
            let e = CrossEngine(seats: houseTable("moshiko", "comet", "amber", "june"), control: .beginner, target: 7, seed: Int64(seed))
            kinds.formUnion(playToEnd(e, nil).outcomes.map { $0.kind })
        }
        // House players' bad shots are genuine faults: into the net, short on their own side; serves can fail.
        XCTAssertEqual(Set(CrossRallyKind.allCases), kinds)
    }

    // Kotlin: strongerCharactersWinMoreOftenThanWeakOnes
    func testStrongerCharactersWinMoreOftenThanWeakOnes() {
        var wins: [String: Int] = [:]
        for seed in 1...9 {
            // Rotate the seats so no position favours anybody.
            let base = ["kyra", "moshiko", "amber"]
            let lineup = (0..<3).map { base[($0 + seed) % 3] }
            let e = CrossEngine(seats: seatsFor(lineup), control: .beginner, target: 5, seed: Int64(seed))
            _ = playToEnd(e, nil)
            if let winner = e.referee.winner {
                wins[lineup[winner], default: 0] += 1
            } else {
                XCTFail("seed \(seed) ended without a winner")
            }
        }
        let kyra = wins["kyra"] ?? 0
        let moshiko = wins["moshiko"] ?? 0
        let amber = wins["amber"] ?? 0
        XCTAssertTrue(kyra > moshiko && kyra > amber && kyra >= 6, "\(wins)")
        var middle: [String: Int] = [:]
        for seed in 1...8 {
            let base = ["mia", "moshiko", "comet", "amber"]
            let lineup = (0..<4).map { base[($0 + seed) % 4] }
            let e = CrossEngine(seats: seatsFor(lineup), control: .standard, target: 5, seed: 100 + Int64(seed))
            _ = playToEnd(e, nil)
            if let winner = e.referee.winner {
                middle[lineup[winner], default: 0] += 1
            } else {
                XCTFail("seed \(100 + seed) ended without a winner")
            }
        }
        XCTAssertTrue((middle["mia"] ?? 0) > (middle["moshiko"] ?? 0), "\(middle)")
    }

    // Kotlin: housePlayersReceiveFromDifferentDirectionsAndChooseDifferentTargets
    func testHousePlayersReceiveFromDifferentDirectionsAndChooseDifferentTargets() {
        let e = CrossEngine(seats: localTable("kyra", "mia", "june"), control: .beginner, target: 7, seed: 5)
        let script = BeginnerScript(e, seed: 8)
        var senders: [Int: Set<Int>] = [:]
        var targets: [Int: Set<Int>] = [:]
        var last: Int? = nil
        var steps = 0
        while e.referee.winner == nil && steps < 7200 * 60 {
            steps += 1
            script.step()
            e.advance(CrossEngine.step)
            for event in e.drainEvents() {
                switch event {
                case let .contact(seat, _, _, _):
                    let sender = last
                    if seat != 0 {
                        if let sender { senders[seat, default: []].insert(sender) }
                        if let receiver = e.predictedReceiver, receiver != seat { targets[seat, default: []].insert(receiver) }
                    }
                    last = seat
                case .rally:
                    last = nil
                default:
                    break
                }
            }
        }
        for seat in 1...3 {
            let received = senders[seat] ?? []
            let sent = targets[seat] ?? []
            XCTAssertTrue(received.count >= 2, "seat \(seat) received from \(received)")
            XCTAssertTrue(sent.count >= 2, "seat \(seat) sent to \(sent)")
        }
    }

    // Kotlin: idleHousePlayersKeepAStablePoseAndStrokesRecoverSmoothly
    func testIdleHousePlayersKeepAStablePoseAndStrokesRecoverSmoothly() {
        let e = CrossEngine(seats: houseTable("kyra", "flare", "mia", "gaya"), control: .beginner, target: 7, seed: 77)
        let n = e.players
        var poseIds: [Int] = []
        var poseLeft: [Bool] = []
        var phase: [Int] = []
        for seat in 0..<n {
            let s = e.stroke(seat)
            poseIds.append(s.id)
            poseLeft.append(s.left)
            phase.append(strokePhase(s))
        }
        var blend: [Double] = Array(repeating: 1.0, count: n)
        var swingsSinceContact: [Int] = Array(repeating: 0, count: n)
        var recovered = 0
        var idleMoves = 0
        for _ in 0..<(7200 * 3) {
            // Kotlin returns from every remaining iteration once there is a winner: nothing changes after it.
            if e.referee.winner != nil { break }
            e.advance(CrossEngine.step)
            let events = e.drainEvents()
            if events.contains(where: { self.isContactOrRally($0) }) { swingsSinceContact = Array(repeating: 0, count: n) }
            for seat in 0..<n {
                let s = e.stroke(seat)
                let seatSwings = events.swings(seat).count
                let swung = seatSwings > 0
                swingsSinceContact[seat] += seatSwings
                if swingsSinceContact[seat] > 1 { XCTFail("At most one swing per incoming ball (seat \(seat))") }
                // Without a new swing the hand and the stroke never change, however the player moves.
                if !swung && (poseIds[seat] != s.id || poseLeft[seat] != s.left) {
                    XCTFail("seat \(seat) pose (\(poseIds[seat]), \(poseLeft[seat])) -> (\(s.id), \(s.left))")
                }
                if !swung && !s.active && e.motion(seat).moving { idleMoves += 1 }
                poseIds[seat] = s.id
                poseLeft[seat] = s.left
                // Within one stroke the phases only move forward and the recovery blend only grows.
                let b = s.recoveryBlend
                let now = strokePhase(s)
                if !swung {
                    if !(now >= phase[seat] || now == CrossMatchTests.readyPhase) {
                        XCTFail("seat \(seat) phase \(phase[seat]) -> \(now)")
                    }
                    if s.active && !(b >= blend[seat] - 1e-12 || phase[seat] < CrossMatchTests.recoveryPhase) {
                        XCTFail("seat \(seat) recovery blend \(blend[seat]) -> \(b)")
                    }
                    if !s.active && phase[seat] == CrossMatchTests.recoveryPhase { recovered += 1 }
                }
                blend[seat] = b
                phase[seat] = now
            }
        }
        XCTAssertTrue(recovered > 20, "strokes must recover to the ready pose: \(recovered)")
        XCTAssertTrue(idleMoves > 100, "house players moved while idle: \(idleMoves)")
    }
}
