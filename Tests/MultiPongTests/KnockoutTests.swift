import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../KnockoutTest.kt (MinikCrossPong 828c6fc): the classic pair knockout (MPKnockout) — seeded draws,
// byes, walkovers and completion text.
//
// Kotlin `PongRules.create(...).copy(createdAt=seed)` -> `MPSession(...)` with `createdAt = seed`; Swift's init also stamps
// `lastActivityAt` with the clock, which Kotlin's create leaves at 0, so the helpers reset it.

final class KnockoutTests: XCTestCase {
    /// Kotlin `room(n, seed)`: a full knockout of humans u0...u(n-1), every one connected.
    private func room(_ n: Int, _ seed: Int64 = 1) throws -> MPSession {
        var s = MPSession(code: "ABC234", kind: .tournament, host: MPIdentity(id: "u0", name: "Player0"), capacity: n, legs: 2,
                          winPoints: 3, difficulty: 4, target: 3, format: .knockout)
        s.createdAt = seed
        s.lastActivityAt = 0
        for i in 1..<n { s = try MPRules.join(s, MPIdentity(id: "u\(i)", name: "Player\(i)")) }
        var connections: [String: [String: Bool]] = [:]
        for uid in s.participants.keys { connections[uid] = ["0": true] }
        s.connections = connections
        return s
    }

    /// Kotlin `finish(s, m, winner = m.a)`: the fixture's humans say Ready, it starts, and its authority stores 3:0.
    private func finishMatch(_ s: MPSession, _ m: MPFixture, _ winner: String? = nil) throws -> MPSession {
        let chosen = winner ?? m.a
        var next = s
        for uid in [m.a, m.b] where s.human(uid) { next = try MPRules.ready(next, match: m.id, uid: uid, value: true) }
        next = MPRules.startReady(next, match: m.id)
        let a = chosen == m.a ? 3 : 0
        let b = chosen == m.b ? 3 : 0
        return try MPRules.finish(next, match: m.id, actor: next.authority(m), a: a, b: b)
    }

    /// Kotlin `finishRound`: every open fixture of the current round, won by its first player.
    private func finishRound(_ s: MPSession) throws -> MPSession {
        var next = s
        for m in MPKnockout.matches(s, MPKnockout.current(s)) where !m.terminal { next = try finishMatch(next, m) }
        return next
    }

    // Kotlin: exactRoundSizesForEvenAndOddExamples
    func testExactRoundSizesForEvenAndOddExamples() throws {
        let cases: [(Int, [Int])] = [(3, [3, 2]), (5, [5, 3, 2]), (8, [8, 4, 2]), (9, [9, 5, 3, 2])]
        for (size, expected) in cases {
            let base = try room(size)
            var s = try MPRules.start(base, actor: "u0")
            var counts: [Int] = []
            var rounds = 0
            while !s.complete && rounds < 20 {
                rounds += 1
                counts.append(s.rounds[MPKnockout.current(s)]?.players.count ?? -1)
                s = try finishRound(s)
            }
            XCTAssertEqual(expected, counts, "size \(size)")
            XCTAssertEqual(size - 1, s.matches.count, "size \(size)")
            XCTAssertNotNil(MPKnockout.winner(s), "size \(size)")
            XCTAssertEqual(1, s.legs)
        }
    }

    // Kotlin: everySizeHasUniquePlayersOneByeAndOnlyWinnersAdvance
    func testEverySizeHasUniquePlayersOneByeAndOnlyWinnersAdvance() throws {
        for n in 2...9 {
            for seed in Int64(1)...Int64(25) {
                let base = try room(n, seed)
                var s = try MPRules.start(base, actor: "u0")
                var rounds = 0
                while !s.complete && rounds < 20 {
                    rounds += 1
                    let r = MPKnockout.current(s)
                    guard let drawn = s.rounds[r] else {
                        XCTFail("n \(n) seed \(seed): round \(r) is missing")
                        break
                    }
                    let games = MPKnockout.matches(s, r)
                    XCTAssertEqual(drawn.players.count, Set(drawn.players).count)
                    XCTAssertEqual(drawn.players.count / 2, games.count)
                    XCTAssertEqual(drawn.players.count % 2, drawn.bye == nil ? 0 : 1)
                    let resting: [String] = [drawn.bye].compactMap { $0 }
                    let seated: [String] = games.flatMap { [$0.a, $0.b] } + resting
                    XCTAssertEqual(Set(drawn.players), Set(seated))
                    let before = s
                    s = try finishRound(s)
                    let expected: [String] = games.map { $0.a } + resting
                    if !s.complete { XCTAssertEqual(Set(expected), Set(s.rounds[r + 1]?.players ?? [])) }
                    XCTAssertEqual(before.rounds[r], s.rounds[r])
                }
                XCTAssertEqual(n - 1, s.matches.count, "n \(n) seed \(seed)")
            }
        }
    }

    // Kotlin: lastResultCreatesNextRoundOnlyOnceAndNeverEarly
    func testLastResultCreatesNextRoundOnlyOnceAndNeverEarly() throws {
        let base = try room(8)
        var s = try MPRules.start(base, actor: "u0")
        let first = MPKnockout.matches(s, 0)
        for m in first.dropLast() {
            s = try finishMatch(s, m)
            XCTAssertEqual(1, s.rounds.count)
        }
        let m = try XCTUnwrap(first.last)
        s = try finishMatch(s, m)
        XCTAssertEqual(2, s.rounds.count)
        XCTAssertEqual(s, try MPRules.finish(s, match: m.id, actor: s.authority(m), a: 3, b: 0))
    }

    // Kotlin: retriesAndWireRoundTripsKeepTheExactDraw
    func testRetriesAndWireRoundTripsKeepTheExactDraw() throws {
        for n in 2...9 {
            let base = try room(n, 381)
            let a = try MPRules.start(base, actor: "u0")
            XCTAssertEqual(a, try MPRules.start(base, actor: "u0"))
            XCTAssertEqual(a, try MPRules.start(a, actor: "u0"))
            let wire: MPWire = try MPCodec.session(a)
            let decoded: MPSession = try MPCodec.session(wire)
            XCTAssertEqual(a, decoded)
            XCTAssertEqual(try finishRound(a), try finishRound(decoded))
        }
    }

    // Kotlin: byesAreFreshRandomChoicesAndCanRepeatAcrossRounds
    func testByesAreFreshRandomChoicesAndCanRepeatAcrossRounds() throws {
        var firstByes = Set<String>()
        var repeated = false
        var changed = false
        for seed in Int64(1)...Int64(400) {
            let base = try room(9, seed)
            var s = try MPRules.start(base, actor: "u0")
            let bye = try XCTUnwrap(s.rounds[0]?.bye)
            firstByes.insert(bye)
            s = try finishRound(s)
            let next = s.rounds[1]?.bye
            if next == bye { repeated = true } else { changed = true }
        }
        XCTAssertEqual(9, firstByes.count)
        XCTAssertTrue(repeated)
        XCTAssertTrue(changed)
    }

    // Kotlin: initialPairingsVaryAndNextRoundDoesNotUseFixedBracketSlots
    func testInitialPairingsVaryAndNextRoundDoesNotUseFixedBracketSlots() throws {
        var firstPairs = Set<String>()
        var secondPairs = Set<String>()
        for seed in Int64(1)...Int64(100) {
            let base = try room(8, seed)
            var s = try MPRules.start(base, actor: "u0")
            firstPairs.insert(MPKnockout.matches(s, 0).map { $0.a + $0.b }.joined(separator: ", "))
            s = try finishRound(s)
            secondPairs.insert(MPKnockout.matches(s, 1).map { $0.a + $0.b }.joined(separator: ", "))
        }
        XCTAssertTrue(firstPairs.count > 50, "\(firstPairs.count)")
        XCTAssertTrue(secondPairs.count > 20, "\(secondPairs.count)")
    }

    // Kotlin: humanEliminationLetsRemainingHousePlayersFinishTheTournament
    func testHumanEliminationLetsRemainingHousePlayersFinishTheTournament() throws {
        var s = MPSession(code: "ABC234", kind: .tournament, host: MPIdentity(id: "u0", name: "Player"), capacity: 9, legs: 1,
                          winPoints: 3, difficulty: 4, target: 3, format: .knockout)
        s.createdAt = 44
        s.lastActivityAt = 0
        // Kotlin BotProfile(): every stat 5, no character.
        let profile = MPBot(speed: 5, reaction: 5, accuracy: 5, power: 5, agility: 5, characterId: "",
                            forehandSkill: 5, backhandSkill: 5, serveSkill: 5)
        for i in 1...8 {
            let house = MPParticipant(identity: MPIdentity(id: "bot_\(i)", name: "House\(i)"), bot: profile)
            s = try MPRules.addBot(s, actor: "u0", bot: house)
        }
        s.connections = ["u0": ["0": true]]
        s = try MPRules.start(s, actor: "u0")
        let m = try XCTUnwrap(s.matches.values.first(where: { $0.contains("u0") && !$0.terminal }))
        s = try finishMatch(s, m, m.a == "u0" ? m.b : m.a)
        XCTAssertTrue(s.complete)
        XCTAssertTrue(MPKnockout.winner(s)?.hasPrefix("bot_") ?? false)
        XCTAssertEqual(8, s.matches.count)
        XCTAssertFalse(MPCompletionText.won(s, "u0"))
    }

    // Kotlin: winnerIsFinalWinnerRatherThanStandingsPoints
    func testWinnerIsFinalWinnerRatherThanStandingsPoints() throws {
        let base = try room(3)
        var s = try MPRules.start(base, actor: "u0")
        var rounds = 0
        while !s.complete && rounds < 20 {
            rounds += 1
            s = try finishRound(s)
        }
        let winner = try XCTUnwrap(MPKnockout.winner(s))
        XCTAssertTrue(MPCompletionText.won(s, winner))
        for id in s.participants.keys where id != winner { XCTAssertFalse(MPCompletionText.won(s, id)) }
        XCTAssertTrue(MPCompletionText.headline(s, winner, hebrew: false).contains("won"))
        let other = try XCTUnwrap(s.participants.keys.first(where: { $0 != winner }))
        XCTAssertTrue(MPCompletionText.headline(s, other, hebrew: false).contains("Winner:"))
    }

    // Kotlin: leavingGivesOpponentWalkoverWithoutInventedScore
    func testLeavingGivesOpponentWalkoverWithoutInventedScore() throws {
        let base = try room(8)
        var s = try MPRules.start(base, actor: "u0")
        let m = try XCTUnwrap(MPKnockout.matches(s, 0).first(where: { $0.contains("u0") }))
        let other = m.a == "u0" ? m.b : m.a
        s = try MPRules.leave(s, actor: "u0")
        XCTAssertNotEqual("u0", s.host)
        let cancelled = try XCTUnwrap(s.matches[m.id])
        XCTAssertEqual(MPMatchPhase.cancelled, cancelled.phase)
        XCTAssertEqual(other, cancelled.winner)
        XCTAssertEqual(0, cancelled.scoreA)
        XCTAssertEqual(0, cancelled.scoreB)
        s = try finishRound(s)
        let next = try XCTUnwrap(s.rounds[1])
        XCTAssertFalse(next.players.contains("u0"))
        XCTAssertTrue(next.players.contains(other))
    }

    // Kotlin: winnerWhoLeavesBeforeOtherMatchesFinishDoesNotAdvance
    func testWinnerWhoLeavesBeforeOtherMatchesFinishDoesNotAdvance() throws {
        let base = try room(8)
        var s = try MPRules.start(base, actor: "u0")
        let m = try XCTUnwrap(MPKnockout.matches(s, 0).first(where: { $0.contains("u0") }))
        s = try finishMatch(s, m, "u0")
        s = try MPRules.leave(s, actor: "u0")
        XCTAssertEqual(MPMatchPhase.finished, s.matches[m.id]?.phase)
        s = try finishRound(s)
        let next = try XCTUnwrap(s.rounds[1])
        XCTAssertFalse(next.players.contains("u0"))
    }

    // Kotlin: legacyRoundRobinRemainsCompatibleAndRetainsAllPairs
    func testLegacyRoundRobinRemainsCompatibleAndRetainsAllPairs() throws {
        var s = try room(8)
        s.format = .roundRobin
        s.legs = 2
        let wire: MPWire = try MPCodec.session(s)
        XCTAssertNil(wire["format"])
        XCTAssertNil(wire["rounds"])
        let decoded: MPSession = try MPCodec.session(wire)
        s = try MPRules.start(decoded, actor: "u0")
        XCTAssertFalse(s.knockout)
        XCTAssertEqual(56, s.matches.count)
        XCTAssertTrue(s.rounds.isEmpty)
    }

    // Kotlin: properStageNamesAndAdvancementAreLocalized
    func testProperStageNamesAndAdvancementAreLocalized() throws {
        XCTAssertEqual("Quarterfinals", MPKnockout.stage(players: 8, hebrew: false))
        XCTAssertEqual("Semifinals", MPKnockout.stage(players: 3, hebrew: false))
        XCTAssertEqual("Final", MPKnockout.stage(players: 2, hebrew: false))
        let base = try room(8)
        var s = try MPRules.start(base, actor: "u0")
        let m = try XCTUnwrap(MPKnockout.matches(s, 0).first)
        s = try finishMatch(s, m)
        XCTAssertEqual("You reached the semifinals!", MPKnockout.advanceText(s, m, hebrew: false))
        XCTAssertEqual("העפלת לחצי הגמר!", MPKnockout.advanceText(s, m, hebrew: true))
        XCTAssertEqual("Round robin", MPTournamentFormat.roundRobin.title(false))
    }
}
