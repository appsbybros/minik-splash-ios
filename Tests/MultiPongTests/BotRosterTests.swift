import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../BotRosterTest.kt (MinikCrossPong 828c6fc): the house-player roster (MPRoster), localized names,
// the bot codec, per-character tuning and seeded play with the classic engine.
//
// Name map: Kotlin `BotRoster.selected(id)` -> `MPRoster.find(id) ?? MPRoster.all[0]`; `Participant.displayName(he)` ->
// `MPParticipant.name(hebrew:)`; `BotProfile.tuning(d)` -> `MPBot.tuning(d, houseControls: false)`; Difficulty
// STARTER/EASY/MEDIUM/HARD/BEGINNER -> MPLevel .easy/.medium/.hard/.superHard/.beginner; `minikProfile` -> `profile`;
// `returnChance(zone, cross)` -> `chance(zone, cross:)`; `PongCodec.bot` -> MPCodec encode/decode of the Codable MPBot.

final class BotRosterTests: XCTestCase {
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
    /// Kotlin `MinikZone.entries`.
    private static let zones: [MPZone] = [.backhand, .middle, .forehand]

    /// Kotlin `ordered`: Minik, then the four stronger characters in strength order.
    private var ordered: [MPHousePlayer] { ["minik", "mia", "gaya", "flare", "kyra"].compactMap { MPRoster.find($0) } }

    /// Kotlin data-class equality of `Chance` (MPChance is not Equatable).
    private func assertSameChance(_ expected: MPChance, _ actual: MPChance, _ label: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(expected.answer, actual.answer, accuracy: 0, "\(label).answer", file: file, line: line)
        XCTAssertEqual(expected.good, actual.good, accuracy: 0, "\(label).good", file: file, line: line)
    }

    /// Kotlin data-class equality of `Tuning` (MPTuning and MPProfile are not Equatable).
    private func assertSameTuning(_ expected: MPTuning, _ actual: MPTuning, _ label: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        for (name, path) in BotRosterTests.tuningFields {
            XCTAssertEqual(expected[keyPath: path], actual[keyPath: path], accuracy: 0, "\(label) \(name)", file: file, line: line)
        }
        let p = expected.profile
        let q = actual.profile
        for (name, path) in BotRosterTests.profileNumbers {
            XCTAssertEqual(p[keyPath: path], q[keyPath: path], accuracy: 0, "\(label) profile.\(name)", file: file, line: line)
        }
        for (name, path) in BotRosterTests.profileChances {
            assertSameChance(p[keyPath: path], q[keyPath: path], "\(label) profile.\(name)", file: file, line: line)
        }
        for (name, path) in BotRosterTests.profileRanges {
            XCTAssertEqual(p[keyPath: path], q[keyPath: path], "\(label) profile.\(name)", file: file, line: line)
        }
        XCTAssertEqual(p.serveReceive.count, q.serveReceive.count, "\(label) profile.serveReceive", file: file, line: line)
        for (index, pair) in zip(p.serveReceive, q.serveReceive).enumerated() {
            assertSameChance(pair.0, pair.1, "\(label) profile.serveReceive[\(index)]", file: file, line: line)
        }
    }

    private static func isHouseContact(_ event: MPEvent) -> Bool {
        if case .contact(.minik, _, _, _) = event { return true }
        return false
    }

    private static func isPoint(_ event: MPEvent) -> Bool {
        if case .point = event { return true }
        return false
    }

    // Kotlin: stableDefaultAndLanguageNames
    func testStableDefaultAndLanguageNames() {
        XCTAssertEqual("minik", (MPRoster.find("") ?? MPRoster.all[0]).id)                    // Kotlin selected(null)
        XCTAssertEqual("minik", (MPRoster.find("deleted_character") ?? MPRoster.all[0]).id)
        // Not ported: assertNull(BotRoster.localProfile("minik")) — Swift has no localProfile.
        XCTAssertEqual(11, Set(MPRoster.all.map { $0.id }).count)
        XCTAssertEqual("Flare", MPRoster.find("flare")?.name(hebrew: true))
        XCTAssertEqual("ספיר", MPRoster.find("kyra")?.name(hebrew: true))
        XCTAssertEqual("Kyra", MPRoster.find("kyra")?.name(hebrew: false))
        let p = MPParticipant(identity: MPIdentity(id: "bot_a", name: "Old host-language name"), bot: MPRoster.find("gaya")?.profile)
        XCTAssertEqual("גאיה", p.name(hebrew: true))
        XCTAssertEqual("Gaya", p.name(hebrew: false))
        XCTAssertEqual("Sam", MPParticipant(identity: MPIdentity(id: "a", name: "Sam")).name(hebrew: true))
    }

    // Kotlin: profilesAndOldRoomsRoundTripWithoutLosingCustomNamesOrStats
    func testProfilesAndOldRoomsRoundTripWithoutLosingCustomNamesOrStats() throws {
        for c in MPRoster.all {
            let wire = try MPCodec.encode(c.profile)
            XCTAssertEqual(c.profile, try MPCodec.decode(MPBot.self, wire))
        }
        // Kotlin PongCodec.bot reads a legacy record with defaults (characterId "", skills = accuracy).
        let legacy: MPWire = ["speed": 3, "reaction": 7, "accuracy": 4, "power": 9, "agility": 5]
        do {
            let b = try MPCodec.decode(MPBot.self, legacy)
            XCTAssertEqual("", b.characterId)
            XCTAssertEqual(4, b.forehandSkill)
            XCTAssertEqual(4, b.backhandSkill)
            XCTAssertEqual(4, b.serveSkill)
            XCTAssertEqual("Old Bot", MPParticipant(identity: MPIdentity(id: "bot_old", name: "Old Bot"), bot: b).name(hebrew: true))
        } catch {
            XCTFail("A legacy bot record (no characterId or skills) must decode like Kotlin PongCodec.bot: \(error)")
        }
        var room = MPSession(code: "ABC234", kind: .tournament, host: MPIdentity(id: "a", name: "A"), capacity: 2, legs: 1,
                             winPoints: 3, difficulty: 0, target: 7)
        room.createdAt = 0
        room.lastActivityAt = 0
        let flare = try XCTUnwrap(MPRoster.find("flare"))
        let s = try MPRules.addBot(room, actor: "a", bot: MPParticipant(identity: MPIdentity(id: "bot_new", name: "Flare"), bot: flare.profile))
        let wire: MPWire = try MPCodec.session(s)
        let decoded: MPSession = try MPCodec.session(wire)
        XCTAssertEqual(s, decoded)
    }

    // Kotlin: minikAndHumanControlsKeepExistingTuning
    func testMinikAndHumanControlsKeepExistingTuning() throws {
        let minik = try XCTUnwrap(MPRoster.find("minik"))
        for d in MPLevel.allCases {
            let base = MPTuning.values(d)
            assertSameTuning(base, minik.profile.tuning(d, houseControls: false), "minik \(d)")
            for c in MPRoster.all {
                let t = c.profile.tuning(d, houseControls: false)
                XCTAssertEqual(base.gravity, t.gravity, accuracy: 0, "\(c.id) \(d)")
                XCTAssertEqual(base.tapSpatialTolerance, t.tapSpatialTolerance, accuracy: 0, "\(c.id) \(d)")
                XCTAssertEqual(base.swipeCollisionForgiveness, t.swipeCollisionForgiveness, accuracy: 0, "\(c.id) \(d)")
                XCTAssertEqual(base.maximumBallSpeed, t.maximumBallSpeed, accuracy: 0, "\(c.id) \(d)")
            }
        }
    }

    // Kotlin: eachSkillChangesItsOwnBehavior
    func testEachSkillChangesItsOwnBehavior() throws {
        let b = try XCTUnwrap(MPRoster.find("mia")).profile
        let base = b.tuning(.medium, houseControls: false)
        var forehandBot = b
        forehandBot.forehandSkill = 10
        let fh = forehandBot.tuning(.medium, houseControls: false)
        var backhandBot = b
        backhandBot.backhandSkill = 10
        let bh = backhandBot.tuning(.medium, houseControls: false)
        var serveBot = b
        serveBot.serveSkill = 10
        let serve = serveBot.tuning(.medium, houseControls: false)
        var powerBot = b
        powerBot.power = 10
        let power = powerBot.tuning(.medium, houseControls: false)
        XCTAssertTrue(fh.profile.forehandCross.good > base.profile.forehandCross.good)
        assertSameChance(base.profile.backhandSame, fh.profile.backhandSame, "forehand skill: backhandSame")
        XCTAssertTrue(bh.profile.backhandCross.good > base.profile.backhandCross.good)
        assertSameChance(base.profile.forehandSame, bh.profile.forehandSame, "backhand skill: forehandSame")
        XCTAssertTrue(serve.profile.serveSuccess > base.profile.serveSuccess)
        assertSameChance(base.profile.forehandSame, serve.profile.forehandSame, "serve skill: forehandSame")
        XCTAssertTrue(power.profile.firstForehandSpeed > base.profile.firstForehandSpeed)
        assertSameChance(base.profile.forehandSame, power.profile.forehandSame, "power: forehandSame")
    }

    // Kotlin: topFourAreStrictlyOrderedAboveMinikAtEveryDifficulty
    func testTopFourAreStrictlyOrderedAboveMinikAtEveryDifficulty() {
        let players = ordered
        XCTAssertEqual(5, players.count)
        for d in MPLevel.allCases {
            for (a, b) in zip(players, players.dropFirst()) {
                let low = a.profile.tuning(d, houseControls: false)
                let high = b.profile.tuning(d, houseControls: false)
                let label = "\(a.id) < \(b.id) at \(d)"
                XCTAssertTrue(high.minikReactionInterval < low.minikReactionInterval, label)
                XCTAssertTrue(high.profile.serveSuccess > low.profile.serveSuccess, label)
                XCTAssertTrue(high.profile.firstForehandSpeed > low.profile.firstForehandSpeed, label)
                XCTAssertTrue(high.profile.firstBackhandSpeed > low.profile.firstBackhandSpeed, label)
                let cap: Double = low.profile.maxSpeed * 1.04
                XCTAssertTrue(high.profile.maxSpeed < cap, label)
                for zone in BotRosterTests.zones {
                    for cross in [false, true] {
                        let better = high.profile.chance(zone, cross: cross).good
                        let worse = low.profile.chance(zone, cross: cross).good
                        XCTAssertTrue(better > worse, "\(label) \(zone) cross \(cross)")
                    }
                }
                XCTAssertTrue(b.profile.strength > a.profile.strength, label)
            }
        }
    }

    /// Kotlin `legalReturns(c, d)`: 4000 seeded house returns from real AI contacts; counts those that bounce legally on the
    /// player's side.
    private func legalReturns(_ c: MPHousePlayer, _ d: MPLevel) -> Int {
        let t = c.profile.tuning(d, houseControls: false)
        var random = MPKotlinRandom(intSeed: 4902)
        var good = 0
        // MPFlight has no free initializer: a serve flight is reshaped into Kotlin's
        // Flight(Vec(x, depth), .055, Vec(0, ballBaseSpeed), 0, MINIK).
        let template = MPShots.serve(MPPoint(0.5, 0.13), side: .minik, tuning: t)
        for i in 0..<4000 {
            let x: Double = 0.1 + random.nextDouble() * 0.8
            let depth: Double = 0.15 + random.nextDouble() * 0.2
            let p = t.profile
            let zone = MPZone.at(x)
            let previousX: Double = i % 2 == 0 ? 1 - x : x
            let answerRoll = random.nextDouble()
            let qualityRoll = random.nextDouble()
            let pace: Double = t.ballBaseSpeed * p.firstForehandSpeed
            guard var shot = MPShots.aiContact(x: x, speed: t.ballBaseSpeed, depth: depth, tuning: t, base: p.chance(zone, cross: false),
                                               cross: p.chance(zone, cross: true), previousX: previousX, response: i % 5,
                                               answerRoll: answerRoll, qualityRoll: qualityRoll, pace: pace) else { continue }
            var flight = MPFlight(template, t)
            flight.position = MPPoint(x, depth)
            flight.height = 0.055
            flight.velocity = MPPoint(0, t.ballBaseSpeed)
            flight.lift = 0
            flight.striker = .minik
            flight.receiver = false
            flight.resolved = false
            flight.spin = 0
            flight.serve = nil
            shot.point = flight.position
            flight.hit(shot, side: .minik, tuning: t, rally: 0)
            for _ in 0...480 {
                let event = flight.advance(1.0 / 120, t)
                if event?.recipient == MPSide.child {
                    good += 1
                    break
                }
                if event?.resolution != nil { break }
            }
        }
        return good
    }

    // Kotlin: seededRealShotPhysicsShowsOrderedLegalReturns
    func testSeededRealShotPhysicsShowsOrderedLegalReturns() {
        let players = ordered
        XCTAssertEqual(5, players.count)
        for d in MPLevel.allCases {
            var result: [Int] = []
            for c in players { result.append(legalReturns(c, d)) }
            print("Roster legal returns /4000 \(d): \(Array(zip(players.map { $0.id }, result)))")
            XCTAssertTrue(zip(result, result.dropFirst()).allSatisfy { pair in pair.1 > pair.0 }, "\(d) \(result)")
        }
    }

    // Kotlin: seededTournamentSimulationFavorsEachStrongerPlayerWithoutGuaranteeingWins
    func testSeededTournamentSimulationFavorsEachStrongerPlayerWithoutGuaranteeingWins() {
        let players = ordered
        XCTAssertEqual(5, players.count)
        for (a, b) in zip(players, players.dropFirst()) {
            let sa = MPParticipant(identity: MPIdentity(id: "bot_a", name: a.english), bot: a.profile)
            let sb = MPParticipant(identity: MPIdentity(id: "bot_b", name: b.english), bot: b.profile)
            // Kotlin Session("ABC234", TOURNAMENT, "human", participants = both bots, target = 7): the host is no participant.
            var s = MPSession(code: "ABC234", kind: .tournament, host: MPIdentity(id: "human", name: "human"), target: 7)
            s.participants = [sa.id: sa, sb.id: sb]
            var wins = 0
            for seed in 0..<3000 {
                let m = MPFixture(id: "m", a: sa.id, b: sb.id, seed: Int64(seed))
                let result = MPRules.simulate(s, m)
                XCTAssertEqual(result, MPRules.simulate(s, m))
                guard let r = result else {
                    XCTFail("no simulation for seed \(seed)")
                    continue
                }
                if r.scores[1] > r.scores[0] { wins += 1 }
            }
            print("\(b.id) over \(a.id): \(wins) /3000")
            XCTAssertTrue((1700...2900).contains(wins), "\(b.id) over \(a.id): \(wins)")
        }
    }

    // Not ported: everyPoseIsInAtlasAndBothHandsHaveOwnContacts — Kotlin BotArt.cell(CatFrame, left); the Swift atlas cell
    // mapping is CrossScene's `private static func cell(_:left:)`, unreachable from tests.

    // Kotlin: nativeEngineReceivesLegalServesWithBothHandsForEveryCharacter
    // Kotlin seeds `kotlin.random.Random(seed)`; MPEngine draws from its own MPRandom(seed:), so the 96 games per character are
    // different seeded games with the same statistical thresholds.
    func testNativeEngineReceivesLegalServesWithBothHandsForEveryCharacter() {
        for c in MPRoster.all {
            var hands = Set<Bool>()
            var contacted = 0
            for x in [0.15, 0.50, 0.85] {
                for seed in 0..<32 {
                    let e = MPEngine(level: .medium, target: 7, bot: c.profile, houseControls: false, seed: UInt64(seed))
                    e.touch(MPPoint(x, 0.28))
                    e.endTouch(cancelled: false)
                    for _ in 0...960 {
                        e.advance(1.0 / 120)
                        let events = e.drainEvents()
                        if events.contains(where: BotRosterTests.isHouseContact) {
                            hands.insert(e.motion.left)
                            contacted += 1
                            break
                        }
                        if events.contains(where: BotRosterTests.isPoint) { break }
                    }
                }
            }
            print("Native engine \(c.id): \(contacted) /96 serve contacts; hands=\(hands)")
            XCTAssertTrue(contacted > 30, "\(c.id) must be able to play")
            XCTAssertEqual(Set([false, true]), hands, "\(c.id) must use forehand and backhand")
        }
    }
}
