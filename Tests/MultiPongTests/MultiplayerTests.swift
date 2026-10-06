import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../MultiplayerTest.kt (MinikCrossPong 828c6fc): room rules (MPRules), the wire codec (MPCodec), the
// sequence gate and the classic networked engine (Kotlin ModernEngine/Match/Flight -> Swift MPEngine/MPScore/MPFlight).
//
// Name map: Kotlin Difficulty STARTER/EASY/MEDIUM/HARD/BEGINNER -> MPLevel .easy/.medium/.hard/.superHard/.beginner;
// `Tuning.forDifficulty(d)` -> `MPTuning.values(d)`; `BotProfile.tuning(d)` -> `MPBot.tuning(d, houseControls: false)`;
// Kotlin `Control.forDifficulty(d)` (SWIPE only on HARD) -> `MPLevel.pro`; `exportState().wire()` + `read` -> MPCodec
// encode/decode of the Codable state.

final class MultiplayerTests: XCTestCase {
    private static let tuningFields: [(String, KeyPath<MPTuning, Double>)] = [
        ("tapSpatialTolerance", \MPTuning.tapSpatialTolerance), ("tapTimingWindow", \MPTuning.tapTimingWindow),
        ("tapTimingQualityExponent", \MPTuning.tapTimingQualityExponent), ("swipeCollisionForgiveness", \MPTuning.swipeCollisionForgiveness),
        ("swipeVelocityScale", \MPTuning.swipeVelocityScale), ("minimumSwipeSpeed", \MPTuning.minimumSwipeSpeed),
        ("maximumSwipeSpeed", \MPTuning.maximumSwipeSpeed), ("serveAssistance", \MPTuning.serveAssistance),
        ("ballBaseSpeed", \MPTuning.ballBaseSpeed), ("rallySpeedGrowth", \MPTuning.rallySpeedGrowth),
        ("maximumBallSpeed", \MPTuning.maximumBallSpeed), ("gravity", \MPTuning.gravity),
        ("bounceRestitution", \MPTuning.bounceRestitution), ("netHeight", \MPTuning.netHeight),
        ("netClearanceVelocityTarget", \MPTuning.netClearanceVelocityTarget), ("maximumArcVelocity", \MPTuning.maximumArcVelocity),
        ("incomingVelocityInfluence", \MPTuning.incomingVelocityInfluence), ("minikReactionInterval", \MPTuning.minikReactionInterval),
        ("minikMaximumReach", \MPTuning.minikMaximumReach), ("minikPredictionAmount", \MPTuning.minikPredictionAmount),
        ("minikAimError", \MPTuning.minikAimError), ("minikErrorProbability", \MPTuning.minikErrorProbability),
        ("minikPoorContactProbability", \MPTuning.minikPoorContactProbability), ("minikCornerPreference", \MPTuning.minikCornerPreference),
        ("minikReturnSpeedMultiplier", \MPTuning.minikReturnSpeedMultiplier), ("minikForehandPreference", \MPTuning.minikForehandPreference),
        ("minikServeFaultProbability", \MPTuning.minikServeFaultProbability),
    ]
    private static let profileNumbers: [(String, KeyPath<MPProfile, Double>)] = [
        ("forehandServe", \MPProfile.forehandServe), ("serveSuccess", \MPProfile.serveSuccess), ("serveMiddle", \MPProfile.serveMiddle),
        ("serveSpeed", \MPProfile.serveSpeed), ("serveVariation", \MPProfile.serveVariation), ("answerDrop", \MPProfile.answerDrop),
        ("goodDrop", \MPProfile.goodDrop), ("backhandCrossGoodDrop", \MPProfile.backhandCrossGoodDrop),
        ("firstForehandSpeed", \MPProfile.firstForehandSpeed), ("firstBackhandSpeed", \MPProfile.firstBackhandSpeed),
        ("accelerateChance", \MPProfile.accelerateChance), ("maxSpeed", \MPProfile.maxSpeed),
    ]
    private static let profileChances: [(String, KeyPath<MPProfile, MPChance>)] = [
        ("forehandSame", \MPProfile.forehandSame), ("forehandCross", \MPProfile.forehandCross),
        ("backhandSame", \MPProfile.backhandSame), ("backhandCross", \MPProfile.backhandCross),
    ]
    private static let profileRanges: [(String, KeyPath<MPProfile, ClosedRange<Double>>)] = [
        ("forehandSpeedUp", \MPProfile.forehandSpeedUp), ("backhandSpeedUp", \MPProfile.backhandSpeedUp), ("speedDown", \MPProfile.speedDown),
    ]

    /// Kotlin data-class equality of `Tuning` (MPTuning and MPProfile are not Equatable).
    private func assertSameTuning(_ expected: MPTuning, _ actual: MPTuning, _ label: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        for (name, path) in MultiplayerTests.tuningFields {
            XCTAssertEqual(expected[keyPath: path], actual[keyPath: path], accuracy: 0, "\(label) \(name)", file: file, line: line)
        }
        let p = expected.profile
        let q = actual.profile
        for (name, path) in MultiplayerTests.profileNumbers {
            XCTAssertEqual(p[keyPath: path], q[keyPath: path], accuracy: 0, "\(label) profile.\(name)", file: file, line: line)
        }
        for (name, path) in MultiplayerTests.profileChances {
            let a = p[keyPath: path]
            let b = q[keyPath: path]
            XCTAssertEqual(a.answer, b.answer, accuracy: 0, "\(label) profile.\(name).answer", file: file, line: line)
            XCTAssertEqual(a.good, b.good, accuracy: 0, "\(label) profile.\(name).good", file: file, line: line)
        }
        for (name, path) in MultiplayerTests.profileRanges {
            XCTAssertEqual(p[keyPath: path], q[keyPath: path], "\(label) profile.\(name)", file: file, line: line)
        }
        XCTAssertEqual(p.serveReceive.count, q.serveReceive.count, "\(label) profile.serveReceive", file: file, line: line)
        for (index, pair) in zip(p.serveReceive, q.serveReceive).enumerated() {
            XCTAssertEqual(pair.0.answer, pair.1.answer, accuracy: 0, "\(label) serveReceive[\(index)].answer", file: file, line: line)
            XCTAssertEqual(pair.0.good, pair.1.good, accuracy: 0, "\(label) serveReceive[\(index)].good", file: file, line: line)
        }
    }

    /// Kotlin `BotProfile(...)` defaults: every stat 5, no character, the three skills default to `accuracy`.
    private func kotlinBot(speed: Int = 5, reaction: Int = 5, accuracy: Int = 5, power: Int = 5, agility: Int = 5) -> MPBot {
        MPBot(speed: speed, reaction: reaction, accuracy: accuracy, power: power, agility: agility, characterId: "",
              forehandSkill: accuracy, backhandSkill: accuracy, serveSkill: accuracy)
    }

    /// Kotlin `PongRules.create(code, kind, host, capacity, legs, win, loss, difficulty, target)`: Swift's init has no loss
    /// argument and stamps the clock, where Kotlin leaves createdAt/lastActivityAt at 0.
    private func created(_ host: MPIdentity, _ capacity: Int, _ legs: Int, _ win: Int, _ loss: Int, _ difficulty: Int,
                         _ target: Int) -> MPSession {
        var s = MPSession(code: "ABC234", kind: .tournament, host: host, capacity: capacity, legs: legs, winPoints: win,
                          difficulty: difficulty, target: target)
        s.lossPoints = min(10, max(0, loss))
        s.createdAt = 0
        s.lastActivityAt = 0
        return s
    }

    /// Kotlin `session(n, legs, difficulty)`: a round robin of humans "a", "b", ... with one point per loss, all connected.
    private func room(_ n: Int = 2, _ legs: Int = 1, _ difficulty: Int = 0) throws -> MPSession {
        var s = created(MPIdentity(id: "a", name: "A"), n, legs, 3, 1, difficulty, 3)
        let letters = Array("abcdefghij")
        for i in 1..<n { s = try MPRules.join(s, MPIdentity(id: String(letters[i]), name: "Player \(i)")) }
        var connections: [String: [String: Bool]] = [:]
        for uid in s.participants.keys { connections[uid] = ["phone": true] }
        s.connections = connections
        return s
    }

    /// Kotlin `playing()`: the pair's only fixture, both Ready and PLAYING.
    private func playing() throws -> MPSession {
        let base = try room()
        let s = try MPRules.start(base, actor: "a")
        let id = try XCTUnwrap(s.matches.keys.first)
        let readyA = try MPRules.ready(s, match: id, uid: "a", value: true)
        let readyB = try MPRules.ready(readyA, match: id, uid: "b", value: true)
        return MPRules.startReady(readyB, match: id)
    }

    // Kotlin: codesAreSixUnambiguousCharactersAndNormalized
    func testCodesAreSixUnambiguousCharactersAndNormalized() throws {
        for _ in 0..<500 { XCTAssertEqual(6, MPRules.code().count) }
        XCTAssertEqual("ABC234", try MPRules.normalize(" abc234 "))
        XCTAssertThrowsError(try MPRules.normalize("../../bad"))
    }

    // Kotlin: joinsPreserveIdentityAndEnforceCapacity
    func testJoinsPreserveIdentityAndEnforceCapacity() throws {
        let s = try room()
        XCTAssertEqual(2, try MPRules.join(s, MPIdentity(id: "a", name: "New name")).participants.count)
        XCTAssertThrowsError(try MPRules.join(s, MPIdentity(id: "c", name: "C")))
    }

    // Kotlin: scheduleAllSizesAndLegsHaveExactUniquePairCounts
    func testScheduleAllSizesAndLegsHaveExactUniquePairCounts() throws {
        for n in 2...8 {
            for legs in 1...2 {
                let s = try room(n, legs)
                let matches = Array(MPRules.schedule(s).values)
                let pairCount = n * (n - 1) / 2
                XCTAssertEqual(pairCount * legs, matches.count)
                XCTAssertEqual(matches.count, Set(matches.map { $0.id }).count)
                let pairs = Dictionary(grouping: matches, by: { [$0.a, $0.b].sorted() })
                XCTAssertEqual(pairCount, pairs.count)
                XCTAssertTrue(pairs.values.allSatisfy { $0.count == legs })
                XCTAssertFalse(matches.contains(where: { $0.a == $0.b }))
                XCTAssertEqual(MPRules.schedule(s), MPRules.schedule(s))
            }
        }
    }

    // Kotlin: doubleLegsReverseHomeAway
    func testDoubleLegsReverseHomeAway() throws {
        let s = try room(8, 2)
        let groups = Dictionary(grouping: Array(MPRules.schedule(s).values), by: { [$0.a, $0.b].sorted() })
        XCTAssertTrue(groups.values.allSatisfy { $0.count == 2 && $0[0].a == $0[1].b && $0[0].b == $0[1].a })
    }

    // Kotlin: readyPersistsWhileOfflineButDoesNotStart
    func testReadyPersistsWhileOfflineButDoesNotStart() throws {
        let base = try room()
        let s = try MPRules.start(base, actor: "a")
        let id = try XCTUnwrap(s.matches.keys.first)
        var ready = try MPRules.ready(s, match: id, uid: "a", value: true)
        ready.connections = [:]
        let wire: MPWire = try MPCodec.session(ready)
        let decoded: MPSession = try MPCodec.session(wire)
        XCTAssertEqual(Set(["a"]), decoded.matches[id]?.readySet)
        XCTAssertEqual(ready, MPRules.startReady(ready, match: id))
    }

    // Kotlin: bothConnectedReadyStartsExactlyOnce
    func testBothConnectedReadyStartsExactlyOnce() throws {
        let s = try playing()
        let id = try XCTUnwrap(s.matches.keys.first)
        XCTAssertEqual(1, s.matches[id]?.starts)
        for _ in 0..<10 { XCTAssertEqual(s, MPRules.startReady(s, match: id)) }
        XCTAssertEqual(MPMatchPhase.playing, s.matches[id]?.phase)
    }

    // Kotlin: readyCanBeCancelled
    func testReadyCanBeCancelled() throws {
        let base = try room()
        let s = try MPRules.start(base, actor: "a")
        let id = try XCTUnwrap(s.matches.keys.first)
        let ready = try MPRules.ready(s, match: id, uid: "a", value: true)
        let cancelled = try MPRules.ready(ready, match: id, uid: "a", value: false)
        XCTAssertTrue(cancelled.matches[id]?.readySet.isEmpty ?? false)
    }

    // Kotlin: playerCannotStartTwoConcurrentMatches
    func testPlayerCannotStartTwoConcurrentMatches() throws {
        let base = try room(3)
        var s = try MPRules.start(base, actor: "a")
        let fixtures = Array(s.matches.values)
        for m in fixtures {
            s = try MPRules.ready(s, match: m.id, uid: m.a, value: true)
            s = try MPRules.ready(s, match: m.id, uid: m.b, value: true)
            s = MPRules.startReady(s, match: m.id)
        }
        XCTAssertEqual(1, s.matches.values.filter { $0.phase == .playing }.count)
    }

    // Kotlin: resultsAreIdempotentAndStandingsCountOnce
    func testResultsAreIdempotentAndStandingsCountOnce() throws {
        let s = try playing()
        let id = try XCTUnwrap(s.matches.keys.first)
        let done = try MPRules.finish(s, match: id, actor: "a", a: 3, b: 1)
        XCTAssertEqual(done, try MPRules.finish(done, match: id, actor: "a", a: 0, b: 3))
        let rows = MPRules.standings(done)
        XCTAssertEqual(2, rows.reduce(0) { $0 + $1.played })
        XCTAssertEqual(1, rows.first?.wins)
        XCTAssertEqual(3, rows.first?.points)
        XCTAssertEqual(1, rows.last?.points)
    }

    // Kotlin: resultRejectsNonAuthorityAndInvalidScores
    func testResultRejectsNonAuthorityAndInvalidScores() throws {
        let s = try playing()
        let id = try XCTUnwrap(s.matches.keys.first)
        XCTAssertThrowsError(try MPRules.finish(s, match: id, actor: "b", a: 3, b: 0))
        XCTAssertThrowsError(try MPRules.finish(s, match: id, actor: "a", a: 1, b: 0))
    }

    // Kotlin: authorityUsesStableIdNotNicknameOrHost
    func testAuthorityUsesStableIdNotNicknameOrHost() throws {
        var s = try room()
        s.host = "b"
        let first = try XCTUnwrap(MPRules.schedule(s).values.first)
        XCTAssertEqual("a", s.authority(first))
        var renamed = s
        renamed.participants = s.participants.mapValues { p in
            var q = p
            q.identity.name = "Same name"
            return q
        }
        XCTAssertEqual("a", renamed.authority(first))
    }

    // Kotlin: hostDisconnectDoesNotDeleteTournamentOrReady
    func testHostDisconnectDoesNotDeleteTournamentOrReady() throws {
        let s = try playing()
        var away = s
        away.connections = [:]
        XCTAssertEqual(s.matches, away.matches)
        XCTAssertEqual("ACTIVE", away.state)
    }

    // Kotlin: botSimulationDeterministicAndAllBotFixturesCompleteAtStart
    func testBotSimulationDeterministicAndAllBotFixturesCompleteAtStart() throws {
        var s = created(MPIdentity(id: "a", name: "A"), 4, 2, 3, 0, 3, 3)
        for i in 1...3 {
            let house = MPParticipant(identity: MPIdentity(id: "bot_\(i)", name: "Bot \(i)"), bot: kotlinBot(accuracy: i * 3))
            s = try MPRules.addBot(s, actor: "a", bot: house)
        }
        let started = try MPRules.start(s, actor: "a")
        XCTAssertEqual(6, started.matches.values.filter { $0.phase == .finished }.count)
        for m in started.matches.values where !m.winner.isEmpty {
            XCTAssertEqual(MPRules.simulate(started, m), MPRules.simulate(started, m))
            XCTAssertTrue(MPRules.validFinal(started, m.scoreA, m.scoreB))
        }
    }

    // Kotlin: botMappingPreservesPlayerPhysicsAndMonotonicSkills
    // Kotlin BotProfile(1,1,1,1,1) has no roster character, so Kotlin takes its generic accuracy formula; Swift MPBot.tuning
    // has no such branch and applies the roster formula (see report). The asserted properties are the same.
    func testBotMappingPreservesPlayerPhysicsAndMonotonicSkills() {
        let weakBot = kotlinBot(speed: 1, reaction: 1, accuracy: 1, power: 1, agility: 1)
        let strongBot = kotlinBot(speed: 10, reaction: 10, accuracy: 10, power: 10, agility: 10)
        for d in MPLevel.allCases {
            let low = weakBot.tuning(d, houseControls: false)
            let high = strongBot.tuning(d, houseControls: false)
            let local = MPTuning.values(d)
            XCTAssertEqual(local.gravity, high.gravity, accuracy: 0)
            XCTAssertEqual(local.tapSpatialTolerance, high.tapSpatialTolerance, accuracy: 0)
            XCTAssertEqual(local.maximumSwipeSpeed, high.maximumSwipeSpeed, accuracy: 0)
            XCTAssertTrue(high.minikReactionInterval < low.minikReactionInterval, "\(d)")
            XCTAssertTrue(high.profile.forehandSame.good > low.profile.forehandSame.good, "\(d)")
            XCTAssertTrue(high.profile.maxSpeed > low.profile.maxSpeed, "\(d)")
            XCTAssertTrue(strongBot.movement > weakBot.movement)
        }
    }

    // Kotlin: sequenceRejectsDuplicateOutOfOrderAndRestoresAck
    func testSequenceRejectsDuplicateOutOfOrderAndRestoresAck() {
        var gate = MPSequenceGate()
        XCTAssertTrue(gate.accept("a", 4))
        XCTAssertFalse(gate.accept("a", 4))
        XCTAssertFalse(gate.accept("a", 3))
        XCTAssertTrue(gate.accept("b", 1))
        var restored = MPSequenceGate()
        restored.restore(gate.snapshot())
        XCTAssertFalse(restored.accept("a", 4))
        XCTAssertTrue(restored.accept("a", 5))
    }

    // Kotlin: matchDataRoundTripsAcrossFirebaseNumericRepresentations
    func testMatchDataRoundTripsAcrossFirebaseNumericRepresentations() throws {
        let s = try playing()
        let wire: MPWire = try MPCodec.session(s)
        let decoded: MPSession = try MPCodec.session(wire)
        XCTAssertEqual(s, decoded)
        XCTAssertEqual("Player", MPIdentity(id: "a", name: " ", avatar: 99).safe().name)
    }

    // Kotlin: noBotPlaysForRemoteHumanAndServeAlternates
    func testNoBotPlaysForRemoteHumanAndServeAlternates() {
        let remote = MPEngine(level: .easy, target: 3, networked: true, first: .minik)
        for _ in 0..<1000 { remote.advance(1.0 / 120) }
        XCTAssertNil(remote.flight)
        XCTAssertEqual(0, remote.score.rallies)
        // Kotlin Match(STARTER, 3, CHILD): the network rotation starts with the child.
        var m = MPScore(server: .child)
        _ = m.award(.child, level: .easy, target: 3, first: .child)
        _ = m.award(.minik, level: .easy, target: 3, first: .child)
        XCTAssertEqual(MPSide.minik, m.server)
    }

    // Kotlin: actualServeFlightMirrorsAndReplaysExactly
    func testActualServeFlightMirrorsAndReplaysExactly() throws {
        let t = MPTuning.values(.easy)
        var f = MPFlight(MPShots.serve(MPPoint(0.83, 0.28), side: .child, tuning: t), t)
        for _ in 0..<31 { _ = f.advance(1.0 / 120, t) }
        let wire = try MPCodec.encode(f)
        let snapshot = try MPCodec.decode(MPFlight.self, wire)
        var mirrored = snapshot.reflected
        for _ in 0..<80 {
            _ = f.advance(1.0 / 120, t)
            _ = mirrored.advance(1.0 / 120, t)
            XCTAssertEqual(1 - f.position.x, mirrored.position.x, accuracy: 1e-10)
            XCTAssertEqual(1 - f.position.y, mirrored.position.y, accuracy: 1e-10)
            XCTAssertEqual(f.height, mirrored.height, accuracy: 1e-10)
        }
    }

    // Kotlin: engineCheckpointRestoresScoreServeBounceAndRejectsDuplicateStrike
    func testEngineCheckpointRestoresScoreServeBounceAndRejectsDuplicateStrike() throws {
        let a = MPEngine(level: .easy, target: 3, networked: true)
        let b = MPEngine(level: .easy, target: 3, networked: true, first: .minik)
        a.touch(MPPoint(0.55, 0.28))
        for _ in 0..<18 { a.advance(1.0 / 120) }
        let wire = try MPCodec.encode(a.snapshot())
        let state = try MPCodec.decode(MPState.self, wire)
        b.restore(state.reflected)
        let flightA = try XCTUnwrap(a.flight)
        let flightB = try XCTUnwrap(b.flight)
        XCTAssertEqual(flightA.height, flightB.height, accuracy: 1e-9)
        let remote = MPEngine(level: .easy, target: 3, networked: true, first: .minik)
        XCTAssertTrue(remote.remoteStrike(flightA.reflected, rallies: 0, hit: 0))
        XCTAssertFalse(remote.remoteStrike(flightA.reflected, rallies: 0, hit: 0))
        XCTAssertFalse(remote.remoteStrike(flightA.reflected, rallies: 1, hit: 0))
    }

    // Kotlin: adapterDefaultsDoNotChangeLocalDifficultyOrControl
    func testAdapterDefaultsDoNotChangeLocalDifficultyOrControl() {
        for d in MPLevel.allCases {
            let e = MPEngine(level: d, target: 7, seed: 1)
            assertSameTuning(MPTuning.values(d), e.tuning, "\(d)")
            // Kotlin Control.forDifficulty(d) == e.control: the control is the level's (swipe only on Kotlin HARD).
            XCTAssertEqual(d, e.level)
            XCTAssertEqual(d == .superHard, e.level.pro)
            XCTAssertFalse(e.networked)
        }
    }
}
