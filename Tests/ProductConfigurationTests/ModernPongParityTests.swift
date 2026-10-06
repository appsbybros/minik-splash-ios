import XCTest
@testable import MinikPlus

final class ModernPongParityTests: XCTestCase {
    private func contact(_ x: Double = 0.5, aim: Double = 0) -> MPContact { .init(point: .init(x, 0.82), timing: 1, spatial: 1, velocity: .zero, direction: aim) }
    private func landing(_ shot: MPShot, from point: MPPoint, t: MPTuning) -> MPPoint? {
        var flight = MPFlight(MPShots.serve(point, side: .child, tuning: t), t)
        flight.position = point; flight.height = 0.055; flight.velocity = shot.velocity; flight.lift = shot.arc; flight.serve = nil
        for _ in 0..<1200 { let event = flight.advance(1.0 / 120, t); if event?.recipient == .minik { return event?.point }; if flight.resolved { return nil } }
        return nil
    }
    /// Android BeginnerAndStrategyTest.engine: a networked engine restored to an incoming Minik ball at (x, 0.80).
    private func incomingRally(_ level: MPLevel, x: Double) -> MPEngine {
        let engine = MPEngine(level: level, networked: true)
        var flight = MPFlight(MPShots.serve(.init(0.5, 0.2), side: .minik, tuning: engine.tuning), engine.tuning)
        flight.position = .init(x, 0.80); flight.height = 0.10; flight.velocity = .init(0, 0.45); flight.lift = 0.25
        flight.striker = .minik; flight.receiver = true; flight.resolved = false; flight.spin = 0; flight.serve = nil
        var state = engine.snapshot(); state.flight = flight; state.rally = 1; state.status = "RETURN_BALL"
        engine.restore(state); return engine
    }
    private func childContacts(_ events: [MPEvent]) -> Int {
        events.filter { if case .contact(.child, _, _, _) = $0 { return true }; return false }.count
    }
    func testControlMappingAndForgiveness() {
        XCTAssertFalse(MPLevel.easy.pro); XCTAssertFalse(MPLevel.medium.pro); XCTAssertFalse(MPLevel.hard.pro); XCTAssertTrue(MPLevel.superHard.pro)
        XCTAssertFalse(MPLevel.beginner.pro); XCTAssertTrue(MPLevel.beginner.automaticContact); XCTAssertFalse(MPLevel.easy.automaticContact)
        let hard = MPTuning.values(.superHard)
        for level in [MPLevel.easy, .medium] {
            let t = MPTuning.values(level)
            XCTAssertGreaterThan(t.tapSpatialTolerance, hard.swipeCollisionForgiveness)
            XCTAssertGreaterThan(t.tapTimingWindow, hard.tapTimingWindow)
            XCTAssertNotNil(MPShots.tapContact(.init(0.64, 0.82), ball: .init(0.5, 0.82), timing: 0.3, tuning: t))
            XCTAssertNil(MPShots.swipeContact(.init(0.64, 0.82), ball: .init(0.5, 0.82), velocity: .init(0, -0.7), tuning: hard))
        }
    }
    func testBeginnerOrdinalTuningScoringAndRooms() throws {
        XCTAssertEqual(MPLevel.beginner.rawValue, 4); XCTAssertEqual(MPLevel(rawValue: 4), .beginner)
        XCTAssertEqual(MPLevel.allCases.filter(\.needsTwoPointLead), [.hard, .superHard])
        XCTAssertEqual(MPLevel.beginner.targets, [3, 5, 7, 10]); XCTAssertEqual(MPLevel.superHard.targets, [3, 5, 7, 11])
        XCTAssertEqual([0, 1, 2, 3, 4, 7, -1].map(MPLevel.control), [.easy, .easy, .easy, .superHard, .beginner, .beginner, .beginner])
        let beginner = MPTuning.values(.beginner), starter = MPTuning.values(.easy)
        XCTAssertEqual(beginner.tapSpatialTolerance, starter.tapSpatialTolerance); XCTAssertEqual(beginner.minikReactionInterval, starter.minikReactionInterval)
        XCTAssertEqual(beginner.profile.serveSuccess, starter.profile.serveSuccess)
        let engine = MPEngine(level: .beginner)
        XCTAssertEqual(engine.childStroke.windowEnd, 0.40); XCTAssertEqual(engine.childStroke.total, 0.62)
        XCTAssertEqual(MPEngine(level: .easy).childStroke.windowEnd, 0.40); XCTAssertEqual(MPEngine(level: .medium).childStroke.windowEnd, 0.52)
        var score = MPScore(server: .child)
        for side in [MPSide.child, .minik, .child, .minik, .child] { let awarded = score.award(side, level: .beginner, target: 3, first: nil); XCTAssertTrue(awarded) }
        XCTAssertEqual(score.winner, .child); XCTAssertEqual(score.child, 3); XCTAssertEqual(score.minik, 2)
        let host = MPIdentity(id: "a", name: "GreenFrog")
        let room = MPSession(code: "ABC234", kind: .friendly, host: host, difficulty: 4, target: 7)
        let wire: MPWire = try MPCodec.session(room), decoded: MPSession = try MPCodec.session(wire)
        XCTAssertEqual(decoded.difficulty, 4)
        XCTAssertTrue(MPRules.validFinal(room, 7, 6)); XCTAssertFalse(MPRules.validFinal(room, 8, 6))
        let medium = MPSession(code: "ABC234", kind: .friendly, host: host, difficulty: 2, target: 7)
        XCTAssertFalse(MPRules.validFinal(medium, 7, 6)); XCTAssertTrue(MPRules.validFinal(medium, 7, 5)); XCTAssertTrue(MPRules.validFinal(medium, 8, 6))
        XCTAssertEqual(MPSession(code: "ABC234", kind: .friendly, host: host, difficulty: 9).difficulty, 4)
    }
    func testBeginnerAutomaticallyReturnsAtThePositionEvenAfterFingerUp() throws {
        for x in [0.12, 0.5, 0.88] {
            let engine = incomingRally(.beginner, x: x)
            engine.touch(.init(x, 0.86)); engine.endTouch()
            for _ in 0..<90 { engine.advance(1.0 / 120) }
            var flight = try XCTUnwrap(engine.flight)
            XCTAssertEqual(flight.striker, .child)
            XCTAssertEqual(childContacts(engine.drainEvents()), 1)
            var landed = false
            for _ in 0..<600 { if flight.advance(1.0 / 120, engine.tuning)?.recipient == .minik { landed = true; break } }
            XCTAssertTrue(landed, "Beginner positioned returns must clear the net and land")
        }
    }
    func testBeginnerNeedsThePaddleInPlaceAndOtherLevelsNeedAGesture() {
        let wrongSide = incomingRally(.beginner, x: 0.12)
        wrongSide.touch(.init(0.88, 0.86)); wrongSide.endTouch()
        for _ in 0..<150 { wrongSide.advance(1.0 / 120) }
        XCTAssertEqual(childContacts(wrongSide.drainEvents()), 0)
        for level in [MPLevel.easy, .superHard] {
            let engine = incomingRally(level, x: 0.5)
            for _ in 0..<100 { engine.advance(1.0 / 120) }
            XCTAssertEqual(childContacts(engine.drainEvents()), 0, "\(level)")
        }
    }
    func testDraggingStandardPaddleTracksFingerAndRetargetsPendingTap() {
        let engine = incomingRally(.easy, x: 0.5)
        engine.touch(.init(0.5, 0.86))
        engine.touch(.init(0.65, 0.82), movement: .init(0.6, -0.2), down: false)
        XCTAssertEqual(engine.paddle, MPPoint(0.65, 0.82)); XCTAssertEqual(engine.restingPaddle, MPPoint(0.65, 0.82))
        XCTAssertNotEqual(engine.paddleTilt, 0)
    }
    func testAcknowledgementCannotRewindPredictedLocalShotOrReplayContact() throws {
        let engine = MPEngine(level: .easy, networked: true)
        engine.touch(.init(0.5, 0.28)); for _ in 0..<15 { engine.advance(0.01) }
        let sent = engine.snapshot(); _ = engine.drainEvents()
        for _ in 0..<30 { engine.advance(0.01) }
        let before = try XCTUnwrap(engine.flight)
        engine.restore(sent, preserveInput: true)
        XCTAssertEqual(engine.flight, before)
        XCTAssertFalse(engine.drainEvents().contains { if case .contact = $0 { return true }; return false })
        let repeated = incomingRally(.easy, x: 0.4), checkpoint = repeated.snapshot()
        for _ in 0..<8 { repeated.advance(0.01) }
        let moved = repeated.flight
        repeated.restore(checkpoint, preserveInput: true)
        XCTAssertEqual(repeated.flight, moved)
    }
    func testNonAuthorityCannotAwardASpeculativeNetworkPoint() {
        let engine = MPEngine(level: .easy, target: 3, networked: true)
        engine.authoritative = false; engine.touch(.init(0.5, 0.28))
        for _ in 0..<2000 { engine.advance(1.0 / 120) }
        XCTAssertEqual(engine.score.rallies, 0)
        XCTAssertFalse(engine.drainEvents().contains { if case .point = $0 { return true }; return false })
    }
    func testLateNetworkReturnGraceIsTwoSeconds() {
        let engine = MPEngine(level: .easy, target: 3, networked: true)
        engine.touch(.init(0.5, 0.28))
        var steps = 0
        while engine.snapshot().pendingFault == nil && steps < 5000 { engine.advance(1.0 / 120); steps += 1 }
        XCTAssertNotNil(engine.snapshot().pendingFault)
        for _ in 0..<228 { engine.advance(1.0 / 120) }
        XCTAssertEqual(engine.score.rallies, 0, "Still inside the 2.0 s grace")
        for _ in 0..<30 { engine.advance(1.0 / 120) }
        XCTAssertEqual(engine.score.rallies, 1)
    }
    @MainActor func testMatchLinkSetsEngineAuthority() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "modern-link-" + UUID().uuidString)), repo = MPLocalRepository(defaults: defaults)
        for friendID in ["zzz_friend", "aaa_friend"] {
            let host = MPIdentity(id: repo.uid, name: "GreenFrog"), friend = MPIdentity(id: friendID, name: "BlueFox")
            let s = try MPRules.start(MPRules.join(MPSession(code: "ABC234", kind: .friendly, host: host, target: 3), friend), actor: repo.uid)
            let match = try XCTUnwrap(s.matches.values.first), engine = MPEngine(networked: true)
            let link = MPMatchLink(repo: repo, session: s, record: match, engine: engine, preferences: MPPreferences(defaults)) { _ in }
            XCTAssertEqual(engine.authoritative, s.authority(match) == repo.uid)
            link.close()
        }
    }
    func testPlainTapKeepsLateralDirection() throws {
        for level in [MPLevel.easy, .medium, .hard] {
            let t = MPTuning.values(level), c = contact()
            for incoming in [-0.15, 0, 0.15] {
                let shot = MPShots.tap(c, t, rally: 0, height: 0.055, incoming: .init(incoming, 0.45))
                let target = try XCTUnwrap(landing(shot, from: c.point, t: t))
                XCTAssertLessThan(shot.velocity.y, 0)
                if incoming < 0 { XCTAssertLessThan(target.x, c.point.x) }
                else if incoming > 0 { XCTAssertGreaterThan(target.x, c.point.x) }
                else { XCTAssertEqual(target.x, c.point.x, accuracy: 0.0001) }
            }
        }
    }
    /// A flight with explicit state (Android tests construct `Flight(position, height, velocity, lift, striker)`).
    private func flight(_ position: MPPoint, height: Double, velocity: MPPoint, lift: Double, striker: MPSide, receiver: Bool = false, tuning t: MPTuning) -> MPFlight {
        var f = MPFlight(MPShots.serve(.init(0.5, 0.2), side: .minik, tuning: t), t)
        f.position = position; f.height = height; f.velocity = velocity; f.lift = lift
        f.striker = striker; f.receiver = receiver; f.resolved = false; f.spin = 0; f.serve = nil
        return f
    }
    /// Android ControlAndCompletionRegressionTest.incoming: FlightState(Vec(x,.79),.12,Vec(0,.44),.20,MINIK,receiver).
    private func androidIncoming(_ level: MPLevel, x: Double = 0.5) -> MPEngine {
        let engine = MPEngine(level: level, networked: true)
        var state = engine.snapshot()
        state.flight = flight(.init(x, 0.79), height: 0.12, velocity: .init(0, 0.44), lift: 0.20, striker: .minik, receiver: true, tuning: engine.tuning)
        state.rally = 1; state.status = "RETURN_BALL"
        engine.restore(state); return engine
    }
    /// Android ModernFollowupTest.controlledHybridShotsRemainReachableWhileWideAnglesCanMiss.
    func testControlledHybridShotsRemainReachableWhileWideAnglesCanMiss() {
        for level in [MPLevel.easy, .medium, .hard] { for x in [0.15, 0.5, 0.85] {
            let t = MPTuning.values(level), aim = (0.5 - x) / (0.70 * (0.85 - 0.26))
            var f = flight(.init(x, 0.85), height: 0.15, velocity: .init(0, 0.5), lift: 0, striker: .minik, tuning: t)
            f.hit(.init(point: .init(x, 0.85), timing: 1, spatial: 1, velocity: .zero, direction: aim), side: .child, tuning: t, rally: 0)
            XCTAssertEqual(MPIntercept.predict(f, t)?.reachable, true, "Controlled cross-court shot remains answerable: \(level) x=\(x)")
        } }
    }
    /// Android ControlAndCompletionRegressionTest.assistedShotsCanReallyGoOutAtEitherEdge: no sideline clamp.
    func testAssistedShotsCanReallyGoOutAtEitherEdge() {
        let t = MPTuning.values(.beginner)
        for sign in [-1.0, 1.0] {
            var f = flight(.init(sign < 0 ? 0.06 : 0.94, 0.84), height: 0.12, velocity: .init(0, 0.4), lift: 0.1, striker: .minik, tuning: t)
            f.hit(.init(point: f.position, timing: 1, spatial: 1, velocity: .zero, direction: sign * 0.6), side: .child, tuning: t, rally: 0)
            var result: MPResolution?
            for _ in 0..<600 { if let resolution = f.advance(1.0 / 120, t)?.resolution { result = resolution } }
            XCTAssertEqual(result, MPResolution(winner: .minik, fault: .leftTable))
        }
    }
    /// Android ControlAndCompletionRegressionTest.longSwipeCanReachFromLeftToRightAndViceVersaWithoutAnEdgeClamp.
    func testLongSwipeCanReachFromLeftToRightAndBackWithoutAnEdgeClamp() throws {
        let t = MPTuning.values(.easy)
        for sign in [-1.0, 1.0] {
            var f = flight(.init(sign > 0 ? 0.10 : 0.90, 0.84), height: 0.12, velocity: .init(0, 0.4), lift: 0.1, striker: .minik, tuning: t)
            f.hit(.init(point: f.position, timing: 1, spatial: 1, velocity: .zero, direction: sign * 1.85), side: .child, tuning: t, rally: 0)
            var landing: MPPoint?
            for _ in 0..<600 { let event = f.advance(1.0 / 120, t); if event?.recipient == .minik { landing = event?.point } }
            let point = try XCTUnwrap(landing)
            if sign > 0 { XCTAssertGreaterThan(point.x, 0.8) } else { XCTAssertLessThan(point.x, 0.2) }
        }
    }
    func testProRetainsWeakAndOverpoweredFailures() {
        let t = MPTuning.values(.superHard)
        var c = contact(); c.velocity = .init(0, -0.02)
        XCTAssertNil(landing(MPShots.driven(c, t, height: 0.055, incoming: .init(0, 0.4)), from: c.point, t: t))
        c.velocity = .init(0, -3.6)
        XCTAssertNil(landing(MPShots.driven(c, t, height: 0.055, incoming: .init(0, 0.4)), from: c.point, t: t))
    }
    func testServeSpreadsDiagonalAcrossBothBounces() {
        let t = MPTuning.values(.easy), s = MPShots.serve(.init(0.9, 0.2), side: .child, tuning: t)
        XCTAssertGreaterThan(s.first.x, s.start.x); XCTAssertLessThan(s.first.x, s.second.x)
        XCTAssertLessThan(s.first.y, s.start.y); XCTAssertLessThan(s.second.y, s.first.y)
    }
    func testPaddleNeverFollowsServeTargetAcrossNetAndPersistsOnRelease() {
        let engine = MPEngine(level: .medium)
        engine.touch(.init(0.9, 0.2)); engine.endTouch()
        XCTAssertTrue(engine.restingPaddle.strikeZone); XCTAssertTrue(engine.childStroke.point.strikeZone)
        let saved = engine.restingPaddle; for _ in 0..<30 { engine.advance(1.0 / 120) }
        engine.release(); XCTAssertEqual(saved, engine.restingPaddle)
    }
    func testCheckpointReflectionIsInvolutive() throws {
        let engine = MPEngine(level: .easy, networked: true)
        engine.touch(.init(0.8, 0.2)); for _ in 0..<25 { engine.advance(1.0 / 120) }
        let original = engine.snapshot(), reflected = original.reflected
        XCTAssertEqual(reflected.reflected.flight, original.flight)
        XCTAssertEqual(reflected.score.child, original.score.minik)
        let wire = try MPCodec.encode(original), decoded = try MPCodec.decode(MPState.self, wire)
        XCTAssertEqual(decoded.flight, original.flight); XCTAssertEqual(decoded.score, original.score)
    }
    func testRestoringOnlineCheckpointDoesNotJumpLocalPaddle() {
        let engine = MPEngine(level: .easy, networked: true)
        engine.touch(.init(0.18, 0.88)); let saved = engine.restingPaddle
        engine.restore(engine.snapshot(), preserveInput: true)
        XCTAssertEqual(saved, engine.restingPaddle)
    }
    func testRequestedAIProbabilitiesUseAllAttempts() {
        let t = MPTuning.values(.easy), chance = MPChance(0.8, 0.7)
        var hits = 0, good = 0
        for a in 0..<100 { for b in 0..<100 {
            let c = MPShots.aiContact(x: 0.8, speed: 0.4, depth: 0.2, tuning: t, base: chance, cross: chance, previousX: nil, response: 0, answerRoll: (Double(a) + 0.5) / 100, qualityRoll: (Double(b) + 0.5) / 100, pace: 0.4)
            if let c { hits += 1; if c.quality >= 0.14 { good += 1 } }
        } }
        XCTAssertEqual(hits, 8000); XCTAssertEqual(Double(good) / 10000, 0.70, accuracy: 0.005)
    }
    func testStatisticalAIOrderingAcrossZonesAndFatigue() {
        var rates: [Double] = []
        // Beginner shares Easy's AI profile; the four distinct opponent profiles must be ordered.
        for level in [MPLevel.easy, .medium, .hard, .superHard] {
            let t = MPTuning.values(level); var good = 0, attempts = 0
            for response in 0..<6 { for x in [0.2, 0.5, 0.8] { for previous in [0.2, 0.8] { for roll in 0..<200 {
                attempts += 1; var rng = MPRandom(seed: UInt64(roll + response * 200 + 1))
                let zone = MPZone.at(x)
                if let c = MPShots.aiContact(x: x, speed: 0.5, depth: 0.2, tuning: t, base: t.profile.chance(zone, cross: false), cross: t.profile.chance(zone, cross: true), previousX: previous, response: response, answerRoll: rng.unit(), qualityRoll: rng.unit(), pace: 0.4), c.quality >= 0.14 { good += 1 }
            } } } }
            rates.append(Double(good) / Double(attempts))
        }
        for i in 1..<rates.count { XCTAssertGreaterThan(rates[i], rates[i - 1], "AI return effectiveness \(rates)") }
    }
    func testSpeedCapsAndStrongerHousePlayers() throws {
        for level in MPLevel.allCases {
            let t = MPTuning.values(level); var random = MPRandom(seed: 84), speed: Double?
            for _ in 0..<10000 {
                let next = t.profile.speed(base: t.ballBaseSpeed, previous: speed, forehand: true, random: &random)
                XCTAssertLessThanOrEqual(next, t.ballBaseSpeed * t.profile.maxSpeed + 1e-10); speed = next
            }
        }
        // Android BotRosterTest: Sapir (kyra) 10, Flare 9, Gaya 8, Mia 7, Minik 6.
        let ids = ["minik", "mia", "gaya", "flare", "kyra"]
        for i in 1..<ids.count {
            let prior = try XCTUnwrap(MPRoster.find(ids[i - 1])), next = try XCTUnwrap(MPRoster.find(ids[i]))
            XCTAssertGreaterThan(next.profile.strength, prior.profile.strength)
            XCTAssertGreaterThan(next.profile.tuning(.easy, houseControls: true).profile.forehandSame.good, prior.profile.tuning(.easy, houseControls: true).profile.forehandSame.good)
        }
    }
    func testKyraIsSapirStrongestAndBeginnerDoesNotWeakenHer() throws {
        let kyra = try XCTUnwrap(MPRoster.find("kyra")), flare = try XCTUnwrap(MPRoster.find("flare"))
        XCTAssertEqual(kyra.name(hebrew: true), "ספיר"); XCTAssertEqual(kyra.name(hebrew: false), "Kyra"); XCTAssertEqual(flare.name(hebrew: true), "Flare")
        XCTAssertEqual(kyra.profile.speed, 10); XCTAssertEqual(flare.profile.speed, 9)
        XCTAssertTrue(MPRoster.all.filter { $0.id != "kyra" }.allSatisfy { $0.profile.strength < kyra.profile.strength })
        let p = kyra.profile.tuning(.beginner, houseControls: true).profile
        XCTAssertGreaterThanOrEqual(p.forehandSame.good, 0.98); XCTAssertGreaterThanOrEqual(p.serveSuccess, 0.98)
        XCTAssertTrue(MPNames.candidate(1, hebrew: true, character: "kyra").hasPrefix("ספיר"))
    }
    func testHousePlayerLevelComesFromSkillAndInputFromControls() throws {
        let expected: [String: MPLevel] = ["minik": .easy, "mia": .medium, "gaya": .hard, "flare": .superHard, "kyra": .superHard, "amber": .easy, "coach67": .easy]
        for (id, level) in expected { XCTAssertEqual(MPRoster.find(id)?.profile.opponentLevel, level, id) }
        let gaya = try XCTUnwrap(MPRoster.find("gaya")).profile, t = gaya.tuning(.beginner, houseControls: true)
        XCTAssertEqual(t.minikReactionInterval, MPTuning.values(.hard).minikReactionInterval * (1 - Double(gaya.reaction - 6) * 0.09), accuracy: 1e-12)
        XCTAssertEqual(t.ballBaseSpeed, 0.40); XCTAssertEqual(t.gravity, 3.6); XCTAssertEqual(t.bounceRestitution, 0.54); XCTAssertEqual(t.netHeight, 0.075)
        XCTAssertEqual(t.tapSpatialTolerance, MPTuning.values(.beginner).tapSpatialTolerance)
        XCTAssertEqual(t.swipeCollisionForgiveness, MPTuning.values(.beginner).swipeCollisionForgiveness)
        let minik = try XCTUnwrap(MPRoster.find("minik")).profile
        XCTAssertEqual(minik.tuning(.superHard, houseControls: false).minikReactionInterval, MPTuning.values(.superHard).minikReactionInterval)
    }
    func testHouseStrategyNeverRepeatsAThirdAndStrongerPlayersGoWider() {
        for bot in MPRoster.all { for incoming in [0.12, 0.50, 0.88] {
            var strategy = MPHouseStrategy(skill: bot.profile.tacticalSkill), random = MPRandom(seed: 442), previous = -1, count = 0
            for _ in 0..<600 {
                let shot = strategy.aim(incoming, random: &random), zone = MPHouseStrategy.zone(shot.x)
                count = zone == previous ? count + 1 : 1; previous = zone
                XCTAssertLessThanOrEqual(count, 2, "\(bot.id) repeats the same third")
                XCTAssertTrue((0.08...0.92).contains(shot.x)); XCTAssertTrue(((0.98 - 1e-9)...(1.22 + 1e-9)).contains(shot.pace))
            }
        } }
        func sample(_ skill: Double) -> (width: Double, bursts: Int) {
            var strategy = MPHouseStrategy(skill: skill), random = MPRandom(seed: 442), width = 0.0, bursts = 0
            for _ in 0..<600 { let shot = strategy.aim(0.22, random: &random); width += abs(shot.x - 0.5); if shot.pace > 1.1 { bursts += 1 } }
            return (width, bursts)
        }
        let minik = sample(6), mia = sample(7), kyra = sample(10)
        XCTAssertEqual(minik.bursts, 0); XCTAssertGreaterThan(kyra.bursts, 120)
        XCTAssertGreaterThan(mia.width, minik.width); XCTAssertGreaterThan(kyra.width, mia.width)
        var strategy = MPHouseStrategy(skill: 10), random = MPRandom(seed: 8), first: [Double] = [], again: [Double] = []
        for _ in 0..<20 { first.append(strategy.aim(0.22, random: &random).x) }
        strategy.reset(); random = MPRandom(seed: 8)
        for _ in 0..<20 { again.append(strategy.aim(0.22, random: &random).x) }
        XCTAssertEqual(again, first)
    }
    func testServeReliabilityKeepsRatesWithoutBackToBackFaults() {
        for rate in [0.15, 0.10, 0.05, 0.01, 0.24] {
            var random = MPRandom(seed: 221), sampler = MPServeReliability(), misses = 0, last = -100
            for i in 0..<20000 {
                let fault = sampler.fault(rate, random: &random)
                guard fault else { continue }
                if rate < 0.2 { XCTAssertGreaterThanOrEqual(i - last, 5) }
                last = i; misses += 1
            }
            XCTAssertEqual(Double(misses) / 20000, rate, accuracy: 0.012)
        }
    }
    func testTutorialOrderAndRealLandingFeedback() {
        XCTAssertEqual(MPTutorialStep.allCases.count, 9)
        XCTAssertEqual(MPTutorialStep.allCases.prefix(3).map(\.serve), [true, true, true])
        XCTAssertEqual(MPTutorialStep.allCases[3], .autoReturn); XCTAssertEqual(MPTutorialStep.autoReturn.level, .beginner)
        for step in MPTutorialStep.allCases {
            let engine = MPEngine(level: step.level, exercise: step.exercise, seed: 42); var gestured = false
            for _ in 0..<5000 {
                if step.serve && engine.awaitingServe && engine.trainingTime > 0.7 { engine.touch(step.servePoint); engine.endTouch() }
                else if !step.serve, let f = engine.flight, f.receiver, f.striker == .minik, f.position.y >= 0.78, !gestured {
                    // Android ModernTutorialTest (2026-10): per-lesson demonstrated distance and swipe speed.
                    gestured = true; engine.touch(f.position)
                    if let direction = step.swipeDirection { engine.touch(.init(f.position.x + direction * step.demoDistance, f.position.y - 0.075), movement: .init(direction * 1.8, -1.7), down: false) }
                    engine.endTouch()
                }
                engine.advance(1.0 / 120); if engine.trainingResult != nil { break }
            }
            XCTAssertEqual(engine.trainingResult, true, "Exercise \(step)")
            XCTAssertEqual(engine.score.child + engine.score.minik, 0)
        }
    }
    func testGuideRejectsWrongServeSide() {
        let engine = MPEngine(level: .medium, exercise: MPTutorialStep.serveLeft.exercise)
        engine.touch(.init(0.9, 0.2)); for _ in 0..<1000 { engine.advance(1.0 / 120) }
        XCTAssertEqual(engine.trainingResult, false)
    }
    func testAndroidIdentityWithoutOptionalCharacterDecodes() throws {
        let identity = try MPCodec.decode(MPIdentity.self, ["id": "a", "name": "GreenFrog", "avatar": 2])
        XCTAssertEqual(identity.characterId, ""); XCTAssertEqual(identity.avatar, 2)
        XCTAssertNil(try MPCodec.encode(identity)["characterId"])
    }
    func testFirebaseNumericPresenceSlotsDecode() throws {
        let s = MPSession(code: "ABC234", kind: .friendly, host: .init(id: "a", name: "GreenFrog"))
        var wire = try MPCodec.session(s); wire["connections"] = ["a": [true, NSNull(), true]]
        let read = try MPCodec.session(wire); XCTAssertEqual(read.connections["a"], ["0": true, "2": true])
        XCTAssertEqual((wire["roster"] as? [String]), ["a"])
    }
    private func room() throws -> MPSession {
        let a = MPIdentity(id: "a", name: "HappyJune", characterId: "june"), b = MPIdentity(id: "b", name: "GreenFrog")
        var s = try MPRules.join(MPSession(code: "ABC234", kind: .friendly, host: a, target: 3), b)
        s.connections = ["a": ["0": true], "b": ["0": true]]; return try MPRules.start(s, actor: "a")
    }
    /// Android LobbyPauseTest (7f5dd0a): a lobby visit never counts as an active court connection.
    func testLobbyPresenceIsDroppedWhileThePlayersMatchIsPlaying() throws {
        var s = try room(); let id = try XCTUnwrap(s.matches.keys.first)
        XCTAssertTrue(s.needsLobbyPresence("a")); XCTAssertTrue(s.needsLobbyPresence("b")); XCTAssertFalse(s.needsLobbyPresence("outsider"))
        for uid in ["a", "b"] { s = try MPRules.ready(s, match: id, uid: uid, value: true) }
        XCTAssertTrue(s.needsLobbyPresence("a")); XCTAssertTrue(s.needsLobbyPresence("b"))
        s = MPRules.startReady(s, match: id)
        XCTAssertEqual(s.matches[id]?.starts, 1)
        XCTAssertFalse(s.needsLobbyPresence("a")); XCTAssertFalse(s.needsLobbyPresence("b"))
        s = try MPRules.finish(s, match: id, actor: "a", a: 3, b: 0)
        XCTAssertTrue(s.needsLobbyPresence("a")); XCTAssertTrue(s.needsLobbyPresence("b"))
    }
    func testAnotherPlayersMatchKeepsAnIdleTournamentPlayersLobbyPresence() throws {
        var s = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "a", name: "A"), capacity: 3, target: 3)
        for uid in ["b", "c"] { s = try MPRules.join(s, .init(id: uid, name: uid)) }
        s.connections = Dictionary(uniqueKeysWithValues: s.roster.map { ($0, ["0": true]) })
        s = try MPRules.start(s, actor: "a")
        let id = try XCTUnwrap(s.matches.values.first(where: { $0.contains("a") && $0.contains("b") })?.id)
        for uid in ["a", "b"] { s = try MPRules.ready(s, match: id, uid: uid, value: true) }
        s = MPRules.startReady(s, match: id)
        XCTAssertFalse(s.needsLobbyPresence("a")); XCTAssertFalse(s.needsLobbyPresence("b")); XCTAssertTrue(s.needsLobbyPresence("c"))
    }
    func testReadyStartsExactlyOnceAndOnlyAuthorityFinishes() throws {
        var s = try room(); let id = try XCTUnwrap(s.matches.keys.first)
        s = try MPRules.ready(s, match: id, uid: "a", value: true)
        XCTAssertEqual(MPRules.startReady(s, match: id), s)
        s = try MPRules.ready(s, match: id, uid: "b", value: true); s = MPRules.startReady(s, match: id)
        XCTAssertEqual(s.matches[id]?.starts, 1); XCTAssertEqual(MPRules.startReady(s, match: id), s)
        XCTAssertThrowsError(try MPRules.finish(s, match: id, actor: "b", a: 3, b: 1))
        s = try MPRules.finish(s, match: id, actor: "a", a: 3, b: 1)
        XCTAssertEqual(try MPRules.finish(s, match: id, actor: "a", a: 3, b: 1), s)
        XCTAssertTrue(s.complete); XCTAssertEqual(MPRules.standings(s).first?.points, 3)
    }
    func testEitherFriendlyParticipantMayFinishAndScheduledRoomsTakeNoNewSeat() throws {
        var s = try room(); let id = try XCTUnwrap(s.matches.keys.first)
        s = try MPRules.ready(s, match: id, uid: "a", value: true); s = try MPRules.ready(s, match: id, uid: "b", value: true)
        s = MPRules.startReady(s, match: id); XCTAssertEqual(s.matches[id]?.phase, .playing)
        XCTAssertTrue(MPRules.canFinishFriendly(s, actor: "a")); XCTAssertTrue(MPRules.canFinishFriendly(s, actor: "b"))
        XCTAssertFalse(MPRules.canFinishFriendly(s, actor: "eve"))
        var tournament = s; tournament.kind = .tournament; XCTAssertFalse(MPRules.canFinishFriendly(tournament, actor: "a"))
        var open = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "a", name: "GreenFrog"), capacity: 3)
        XCTAssertTrue(MPRules.acceptsNewPlayer(open))
        open.matches["x"] = MPFixture(id: "x", a: "a", b: "b", seed: 1)
        XCTAssertFalse(MPRules.acceptsNewPlayer(open))
        XCTAssertThrowsError(try MPRules.join(open, .init(id: "c", name: "BlueFox")))
    }
    func testTournamentUniqueHousePlayersAndDurableResults() throws {
        var s = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "human", name: "GreenFrog"), capacity: 3)
        let flare = try XCTUnwrap(MPRoster.find("flare")), kyra = try XCTUnwrap(MPRoster.find("kyra"))
        s = try MPRules.add(s, actor: "human", player: flare, hebrew: false)
        XCTAssertThrowsError(try MPRules.add(s, actor: "human", player: flare, hebrew: false))
        s = try MPRules.add(s, actor: "human", player: kyra, hebrew: false); s = try MPRules.start(s, actor: "human")
        XCTAssertEqual(s.matches.count, 3); XCTAssertEqual(s.matches.values.filter { $0.phase == .finished }.count, 1)
        XCTAssertEqual(try MPRules.start(s, actor: "human"), s)
        XCTAssertEqual(try MPCodec.session(MPCodec.session(s)), s)
    }
    func testTournamentWinPointsAndRemovingHousePlayers() throws {
        var s = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "human", name: "GreenFrog"), capacity: 3, winPoints: 5)
        XCTAssertEqual(s.winPoints, 5)
        XCTAssertEqual(MPSession(code: "ABC234", kind: .tournament, host: .init(id: "h", name: "GreenFrog"), winPoints: 40).winPoints, 10)
        let flare = try XCTUnwrap(MPRoster.find("flare")), kyra = try XCTUnwrap(MPRoster.find("kyra")), gaya = try XCTUnwrap(MPRoster.find("gaya"))
        s = try MPRules.add(s, actor: "human", player: flare, hebrew: false)
        XCTAssertThrowsError(try MPRules.removeHouse(s, actor: "someone", id: "bot_flare"))
        XCTAssertThrowsError(try MPRules.removeHouse(s, actor: "human", id: "human"))
        s = try MPRules.removeHouse(s, actor: "human", id: "bot_flare"); XCTAssertNil(s.participants["bot_flare"])
        s = try MPRules.add(s, actor: "human", player: kyra, hebrew: false); s = try MPRules.add(s, actor: "human", player: gaya, hebrew: false)
        s = try MPRules.start(s, actor: "human")
        XCTAssertThrowsError(try MPRules.removeHouse(s, actor: "human", id: "bot_kyra"))
        let finished = try XCTUnwrap(s.matches.values.first(where: { $0.phase == .finished }))
        XCTAssertEqual(MPRules.standings(s).first(where: { $0.id == finished.winner })?.points, 5)
        let wire: MPWire = try MPCodec.session(s), decoded: MPSession = try MPCodec.session(wire)
        XCTAssertEqual(decoded.winPoints, 5)
    }
    func testHundredCuratedNamesPerLanguageAndAvatarNames() {
        for he in [false, true] { XCTAssertEqual(Set((0..<100).map { MPNames.candidate($0, hebrew: he) }).count, 100) }
        XCTAssertTrue(MPNames.candidate(1, hebrew: false, character: "june").contains("June"))
        XCTAssertEqual(MPRoster.find("moshiko")?.english, "Bouncy Bob")
    }
    func testAdsDeduplicationFirstTwoFreeAndCadence() {
        var p = MPAdPolicy(); XCTAssertTrue(p.completion("a")); XCTAssertFalse(p.due(now: 1_000_000))
        XCTAssertTrue(p.completion("b")); XCTAssertFalse(p.due(now: 1_000_000))
        XCTAssertFalse(p.completion("b")); XCTAssertTrue(p.completion("c")); XCTAssertTrue(p.due(now: 1_000_000))
        p.shown(now: 1_000_000); XCTAssertFalse(p.due(now: 999_000)); _ = p.completion("d"); _ = p.completion("e")
        XCTAssertFalse(p.due(now: 1_119_000)); XCTAssertTrue(p.due(now: 1_120_000))
        p.history = Array(repeating: 900_000, count: 5); XCTAssertFalse(p.due(now: 2_000_000))
        _ = p.completion("f"); p.activeMillis = 300_000; XCTAssertTrue(p.due(now: 2_000_000))
    }
    func testAdPolicyRejectsMalformedIdentifiersAndIdleTime() {
        var p = MPAdPolicy()
        XCTAssertFalse(p.completion("")); XCTAssertFalse(p.completion("a,b")); XCTAssertFalse(p.completion(String(repeating: "x", count: 201)))
        XCTAssertEqual(p.total, 0)
        p.active(0, now: 5_000); p.active(-3, now: 6_000); XCTAssertEqual(p.lastActive, 0); XCTAssertEqual(p.activeMillis, 0)
        p.active(60_000, now: 7_000); XCTAssertEqual(p.activeMillis, 5_000)
    }
    @MainActor func testSimpleExperienceNeverRequestsModernAds() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "modern-ads-test-" + UUID().uuidString))
        XCTAssertFalse(MPAds(preferences: MPPreferences(defaults), experience: .simple).configured)
        // The Plus test host is not the standalone Ping Pong product, so Full does not request Modern ads here either.
        XCTAssertFalse(MPAds(preferences: MPPreferences(defaults), experience: .full).configured)
    }
    @MainActor func testFailureSoundOnlyForPlayerNetAndOutShots() {
        XCTAssertEqual([MPFault.net, .leftTable, .firstBounceOut, .secondBounce, .illegalServe, .unreturned].map(MPAudio.audibleFault), [true, true, true, false, false, false])
    }
    @MainActor func testOldControlPreferenceIgnoredAndSimpleCapabilities() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "modern-test-" + UUID().uuidString))
        defaults.set("swipe", forKey: "pingPong.controlMode")
        let preferences = MPPreferences(defaults)
        XCTAssertEqual(preferences.control, .beginner, "Android's default control is Beginner")
        preferences.control = .superHard; XCTAssertEqual(MPPreferences(defaults).control, .superHard)
        preferences.control = .medium; XCTAssertEqual(MPPreferences(defaults).control, .easy)
        let legacy = try XCTUnwrap(UserDefaults(suiteName: "modern-legacy-" + UUID().uuidString))
        legacy.set(true, forKey: "modern.pong.v2.pro"); XCTAssertEqual(MPPreferences(legacy).control, .superHard)
        legacy.set(false, forKey: "modern.pong.v2.pro"); XCTAssertEqual(MPPreferences(legacy).control, .easy)
        XCTAssertFalse(ModernPongExperience.simple.online); XCTAssertFalse(ModernPongExperience.simple.tournaments); XCTAssertFalse(ModernPongExperience.simple.profiles); XCTAssertTrue(ModernPongExperience.simple.closesAfterMatch)
    }
    @MainActor func testLocalOpenGameLimitAndPersistence() async throws {
        let defaults = UserDefaults(suiteName: "modern-rooms-test-" + UUID().uuidString)!, repo = MPLocalRepository(defaults: defaults)
        let uid = try await repo.connect(), identity = MPIdentity(id: uid, name: "GreenFrog")
        for code in ["ABC234", "ABC235", "ABC236"] { _ = try await repo.create(MPSession(code: code, kind: .friendly, host: identity)) }
        do { _ = try await repo.create(MPSession(code: "ABC237", kind: .friendly, host: identity)); XCTFail("Fourth room must be rejected") } catch { XCTAssertEqual(error as? MPError, .limit) }
        let restored = MPLocalRepository(defaults: defaults), rooms = try await restored.openRooms()
        XCTAssertEqual(rooms.count, 3)
    }
    func testLeavingTournamentTransfersHostAndPreservesFinishedResults() throws {
        var s = try room(); s.kind = .tournament
        let id = try XCTUnwrap(s.matches.keys.first)
        s = try MPRules.ready(s, match: id, uid: "a", value: true); s = try MPRules.ready(s, match: id, uid: "b", value: true)
        s = MPRules.startReady(s, match: id); s = try MPRules.finish(s, match: id, actor: "a", a: 3, b: 1)
        let match = s.matches[id]; s = try MPRules.leave(s, actor: "a")
        XCTAssertEqual(s.host, "b"); XCTAssertTrue(s.departed["a"] == true)
        XCTAssertEqual(s.matches[id]?.scoreA, match?.scoreA); XCTAssertEqual(s.matches[id]?.winner, match?.winner)
    }
    @MainActor func testSimpleMatchDoesNotConnectAndClosesOnce() async throws {
        let defaults = UserDefaults(suiteName: "modern-simple-test-" + UUID().uuidString)!, preferences = MPPreferences(defaults)
        preferences.skipGuide = true
        let repo = MPLocalRepository(defaults: defaults); var results: [ModernPongResult?] = []
        let model = MPController(experience: .simple, preferences: preferences, repository: repo) { results.append($0) }
        await model.start(hebrew: false, removeAds: true)
        XCTAssertFalse(model.connected); XCTAssertNil(model.identity)
        // Standard: Minik serves every point, so an idle player loses and the match ends.
        model.level = .easy; model.target = 3; model.startSingle()
        let scene = try XCTUnwrap(model.scene)
        for _ in 0..<20000 { scene.engine.advance(1.0 / 120); scene.onFrame?(scene.engine.drainEvents()); if !results.isEmpty { break } }
        XCTAssertEqual(results.count, 1); XCTAssertNotNil(results.first!)
        scene.onFrame?([]); XCTAssertEqual(results.count, 1)
        let rooms = try await repo.openRooms(); XCTAssertTrue(rooms.isEmpty)
    }
    @MainActor func testGuideOpensBeforeFirstLocalMatchUnlessHidden() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "modern-guide-test-" + UUID().uuidString))
        let model = MPController(experience: .simple, preferences: MPPreferences(defaults), repository: MPLocalRepository(defaults: defaults)) { _ in }
        XCTAssertFalse(model.skipGuide)
        model.startSingle()
        XCTAssertEqual(model.route, .guide); XCTAssertNil(model.scene)
        model.skipGuide = true; XCTAssertTrue(MPPreferences(defaults).skipGuide)
        model.guideToGame()
        XCTAssertEqual(model.route, .game); XCTAssertNotNil(model.scene)
        let next = MPController(experience: .simple, preferences: MPPreferences(defaults), repository: MPLocalRepository(defaults: defaults)) { _ in }
        XCTAssertTrue(next.skipGuide)
        next.startSingle()
        XCTAssertEqual(next.route, .game)
        model.close(); next.close()
    }
    @MainActor func testOfflineSmokeLaunchUsesLocalRepository() {
        UserDefaults.standard.set(true, forKey: "MinikOfflineSmoke")
        defer { UserDefaults.standard.removeObject(forKey: "MinikOfflineSmoke") }
        XCTAssertTrue(MPController.offlineSmoke)
        let model = MPController(experience: .full) { _ in }
        XCTAssertFalse(model.online)
        model.close()
    }
    func testPracticeDoesNotInheritHousePlayerEasyAssistance() throws {
        let minik = try XCTUnwrap(MPRoster.find("minik"))
        let practice = MPEngine(level: .hard, bot: minik.profile, houseControls: false)
        let house = MPEngine(level: .superHard, bot: minik.profile, houseControls: true)
        XCTAssertFalse(practice.houseControls); XCTAssertTrue(house.houseControls)
        XCTAssertEqual(practice.tuning.profile.forehandServe, 0.60)
        XCTAssertEqual(house.tuning.profile.forehandServe, 0.80)
        XCTAssertEqual(house.tuning.swipeCollisionForgiveness, MPTuning.values(.superHard).swipeCollisionForgiveness)
    }
    @MainActor func testSelectingHousePlayerStartsFriendlyOnceWithoutExtraScreen() async throws {
        let defaults = UserDefaults(suiteName: "modern-house-start-" + UUID().uuidString)!
        let repo = MPLocalRepository(defaults: defaults)
        let model = MPController(experience: .full, preferences: MPPreferences(defaults), repository: repo) { _ in }
        await model.start(hebrew: false, removeAds: true)
        await model.create(.friendly, house: try XCTUnwrap(MPRoster.find("june")))
        for _ in 0..<100 { await Task.yield(); if model.fixture != nil { break } }
        XCTAssertEqual(model.fixture?.starts, 1)
        XCTAssertEqual(model.fixture?.phase, .playing)
        XCTAssertNotNil(model.scene)
        XCTAssertEqual(model.session?.difficulty, MPLevel.beginner.rawValue, "Beginner is the default room control")
        model.close()
    }

    // MARK: Android 2026-10-01 controls, rally variation, presentation and completion (ControlAndCompletionRegressionTest)

    func testEachRoomTypeKeepsItsSelectedControlsThroughCreationWireAndEngine() throws {
        let minik = try XCTUnwrap(MPRoster.find("minik"))
        for kind in MPSessionKind.allCases { for value in [4, 0, 3] { for house in [false, true] {
            var s = MPSession(code: "ABC234", kind: kind, host: .init(id: "a", name: "A"), capacity: 2, legs: 1, winPoints: 3, difficulty: value, target: 3)
            if house { s = try MPRules.add(s, actor: "a", player: minik, hebrew: false) } else { s = try MPRules.join(s, .init(id: "b", name: "B")) }
            s = try MPCodec.session(MPCodec.session(MPRules.start(s, actor: "a")))
            let bot = s.participants.values.first(where: { $0.bot != nil })?.bot
            let engine = MPEngine(level: MPLevel.control(s.difficulty), target: 3, bot: bot, houseControls: true)
            XCTAssertEqual(s.difficulty, value); XCTAssertEqual(engine.automaticContact, value == 4); XCTAssertEqual(engine.level.pro, value == 3)
            XCTAssertEqual(MPControlChoice.title(s.difficulty, hebrew: false), value == 4 ? "Beginner" : value == 0 ? "Standard" : "Pro")
        } } }
        XCTAssertEqual([0, 1, 2, 3, 4].map { MPControlChoice.title($0, hebrew: true) }, ["רגילה", "רגילה", "רגילה", "מקצועני", "מתחילים"])
    }
    func testBeginnerAcceptsSmallHorizontalAndBackwardDiagonalSwipes() throws {
        for sign in [-1.0, 1.0] { for dy in [-0.01, 0, 0.03] {
            let engine = androidIncoming(.beginner)
            engine.touch(.init(0.5, 0.84))
            engine.touch(.init(0.5 + sign * 0.025, 0.84 + dy), movement: .init(sign * 0.4, 0.1), down: false)
            engine.endTouch()
            for _ in 0..<40 { engine.advance(1.0 / 120) }
            let flight = try XCTUnwrap(engine.flight)
            XCTAssertEqual(flight.striker, .child)
            XCTAssertGreaterThan(sign * flight.velocity.x, 0.05, "Small sideways movement must influence the shot")
            XCTAssertEqual(childContacts(engine.drainEvents()), 1)
        } }
    }
    func testStandardSwipeSpeedAddsModeratePowerWithoutProContactPrecision() throws {
        func hit(_ speed: Double) -> MPEngine {
            let engine = androidIncoming(.easy)
            engine.touch(.init(0.5, 0.84)); engine.touch(.init(0.52, 0.82), movement: .init(speed, -speed), down: false); engine.endTouch()
            for _ in 0..<40 { engine.advance(1.0 / 120) }
            XCTAssertEqual(engine.flight?.striker, .child); return engine
        }
        let slow = hit(0.1), fast = hit(1.1)
        let slowFlight = try XCTUnwrap(slow.flight)
        var fastFlight = try XCTUnwrap(fast.flight)
        XCTAssertGreaterThan(abs(fastFlight.velocity.y), abs(slowFlight.velocity.y) * 1.12)
        XCTAssertLessThan(abs(fastFlight.velocity.y), abs(slowFlight.velocity.y) * 1.4)
        XCTAssertGreaterThan(fast.tuning.tapSpatialTolerance, MPTuning.values(.superHard).swipeCollisionForgiveness)
        var landed = false
        for _ in 0..<500 { if fastFlight.advance(1.0 / 120, fast.tuning)?.recipient == .minik { landed = true } }
        XCTAssertTrue(landed)
    }
    func testFifthStraightReturnVariesOnceAcrossAlternatingPlayers() {
        var v = MPRallyVariation()
        for i in 0..<4 { XCTAssertEqual(v.hit(.init(0.1, i % 2 == 0 ? 0.1 : 0.8), .init(0, i % 2 == 0 ? 0.4 : -0.4)).x, 0) }
        XCTAssertEqual(v.hit(.init(0.1, 0.1), .init(0, 0.4)).x, 0.112, accuracy: 1e-9)
        XCTAssertEqual(v.hit(.init(0.1, 0.8), .init(0, -0.4)).x, 0)
        v.reset()
        for _ in 0..<4 { v.hit(.init(0.9, 0.1), .init(0, 0.4)) }
        XCTAssertLessThan(v.hit(.init(0.9, 0.8), .init(0, -0.4)).x, 0)
    }
    func testDeliberateAnglesAndRemoteFlightsAreNotAltered() {
        var v = MPRallyVariation()
        for _ in 0..<12 { XCTAssertEqual(v.hit(.init(0.5, 0.1), .init(0.1, 0.4)), MPPoint(0.1, 0.4)) }
        for _ in 0..<10 { XCTAssertEqual(v.hit(.init(0.5, 0.1), .init(0, 0.4), adjust: false), MPPoint(0, 0.4)) }
    }
    func testFingerFollowThroughCannotRestartMinikFootworkAfterContact() {
        let a = MPEngine(level: .easy, seed: 73), b = MPEngine(level: .easy, seed: 73)
        for engine in [a, b] {
            var state = engine.snapshot()
            state.flight = flight(.init(0.5, 0.8), height: 0.12, velocity: .init(0.04, -0.4), lift: 1.2, striker: .child, tuning: engine.tuning)
            state.rally = 1; engine.restore(state)
        }
        for _ in 0..<20 {
            a.advance(0.01); b.advance(0.01); a.touch(.init(0.55, 0.83), movement: .init(0.4, 0), down: false)
            XCTAssertEqual(a.motion.body, b.motion.body)
        }
    }
    func testMinikRecoveryFadesSmoothlyFromFollowThroughToReady() {
        var stroke = MPStroke(contactAt: 0.20, windowEnd: 0.27, followEnd: 0.44, total: 0.68)
        stroke.start(1, .init(0.5, 0.1), 0, false)
        stroke.advance(0.44); XCTAssertEqual(stroke.recoveryBlend, 0, accuracy: 1e-8)
        stroke.advance(0.08); XCTAssertEqual(stroke.recoveryBlend, 0.5, accuracy: 1e-8)
        stroke.advance(0.16); XCTAssertEqual(stroke.recoveryBlend, 1)
        XCTAssertEqual(MPStroke().recoveryBlend, 1)
    }
    func testCompletedTournamentAnnouncesWinnerAndThirdPlaceInBothLanguages() throws {
        var s = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "a", name: "A"), capacity: 3, legs: 1, winPoints: 3, difficulty: 4, target: 3)
        s = try MPRules.join(MPRules.join(s, .init(id: "b", name: "B")), .init(id: "c", name: "C"))
        s = try MPRules.start(s, actor: "a")
        for m in s.matches.values.sorted(by: { $0.id < $1.id }) {
            s.matches[m.id]?.phase = .playing
            s = try MPRules.finish(s, match: m.id, actor: s.authority(m), a: 3, b: 0)
        }
        XCTAssertTrue(s.complete); XCTAssertTrue(MPCompletionText.won(s, "a"))
        XCTAssertEqual(MPCompletionText.headline(s, "a", hebrew: false), "You won the tournament!")
        XCTAssertEqual(MPCompletionText.headline(s, "a", hebrew: true), "ניצחתם בטורניר!")
        XCTAssertEqual(MPCompletionText.headline(s, "c", hebrew: false), "Tournament finished. You placed 3rd.")
        XCTAssertTrue(MPCompletionText.headline(s, "c", hebrew: true).contains("3"))
        XCTAssertFalse(MPCompletionText.won(s, "c"))
    }
    func testCompletedRoomsAreNeverKeptAsHistoryAndCelebrateOnce() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "modern-completed-" + UUID().uuidString)), preferences = MPPreferences(defaults)
        let open = try room()
        preferences.remember(open); XCTAssertEqual(preferences.rooms.map(\.id), [open.id])
        var s = open
        let id = try XCTUnwrap(s.matches.keys.first)
        s = try MPRules.ready(s, match: id, uid: "a", value: true); s = try MPRules.ready(s, match: id, uid: "b", value: true)
        s = MPRules.startReady(s, match: id); s = try MPRules.finish(s, match: id, actor: "a", a: 3, b: 1)
        XCTAssertTrue(s.complete); XCTAssertTrue(MPCompletionText.won(s, "a")); XCTAssertFalse(MPCompletionText.won(s, "b"))
        XCTAssertEqual(MPCompletionText.headline(s, "a", hebrew: false), "You won the match!")
        XCTAssertEqual(MPCompletionText.headline(s, "b", hebrew: true), "המשחק הסתיים")
        preferences.remember(s); XCTAssertTrue(preferences.rooms.isEmpty); XCTAssertTrue(preferences.completionKnown(s))
        preferences.remember(open); XCTAssertTrue(preferences.rooms.isEmpty, "A completed room never returns to Your games")
        XCTAssertTrue(preferences.firstCelebration(s)); XCTAssertFalse(preferences.firstCelebration(s))
        XCTAssertEqual(MPMatchText.result("A", 3, 1, "B"), "\u{2066}\u{2068}A\u{2069}  3 : 1  \u{2068}B\u{2069}\u{2069}")
    }
    @MainActor func testCompletedLocalRoomsAreDiscarded() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "modern-local-complete-" + UUID().uuidString))
        let repo = MPLocalRepository(defaults: defaults)
        let uid = try await repo.connect()
        let minik = try XCTUnwrap(MPRoster.find("minik"))
        var s = try MPRules.add(MPSession(code: "ABC234", kind: .friendly, host: .init(id: uid, name: "GreenFrog"), target: 3), actor: uid, player: minik, hebrew: false)
        s = try MPRules.start(s, actor: uid)
        _ = try await repo.create(s)
        let id = try XCTUnwrap(s.matches.keys.first)
        _ = try await repo.mutate(.friendly, "ABC234") { old in
            var next = old
            next.matches[id]?.phase = .finished; next.matches[id]?.scoreA = 3; next.matches[id]?.winner = uid
            return next
        }
        try await repo.cleanup()
        let remaining = try await repo.get(.friendly, "ABC234")
        XCTAssertNil(remaining)
    }

    // MARK: Android 2026-10-01 knockout tournaments (KnockoutTest)

    private func knockoutRoom(_ n: Int, seed: Int64 = 1) throws -> MPSession {
        var s = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "u0", name: "Player0"), capacity: n, legs: 2, winPoints: 3, difficulty: 4, target: 3, format: .knockout)
        s.createdAt = seed
        for i in 1..<n { s = try MPRules.join(s, .init(id: "u\(i)", name: "Player\(i)")) }
        for id in s.participants.keys { s.connections[id] = ["0": true] }
        return s
    }
    private func finishKnockout(_ s: MPSession, _ m: MPFixture, winner: String? = nil) throws -> MPSession {
        var next = s
        for uid in [m.a, m.b] where s.human(uid) { next = try MPRules.ready(next, match: m.id, uid: uid, value: true) }
        next = MPRules.startReady(next, match: m.id)
        let won = winner ?? m.a
        return try MPRules.finish(next, match: m.id, actor: next.authority(m), a: won == m.a ? 3 : 0, b: won == m.b ? 3 : 0)
    }
    private func finishRound(_ s: MPSession) throws -> MPSession {
        var next = s
        for m in MPKnockout.matches(s, MPKnockout.current(s)) where !m.terminal { next = try finishKnockout(next, m) }
        return next
    }
    func testKnockoutExactRoundSizesForEvenAndOddExamples() throws {
        for (size, expected) in [(3, [3, 2]), (5, [5, 3, 2]), (8, [8, 4, 2]), (9, [9, 5, 3, 2])] {
            var s = try MPRules.start(knockoutRoom(size), actor: "u0")
            var counts: [Int] = []
            while !s.complete && counts.count < 10 { counts.append(s.rounds[MPKnockout.current(s)]?.players.count ?? 0); s = try finishRound(s) }
            XCTAssertEqual(counts, expected); XCTAssertEqual(s.matches.count, size - 1)
            XCTAssertNotNil(MPKnockout.winner(s)); XCTAssertEqual(s.legs, 1); XCTAssertEqual(s.state, "FINISHED")
        }
    }
    func testEveryKnockoutSizeHasUniquePlayersOneByeAndOnlyWinnersAdvance() throws {
        for n in 2...9 { for seed in Int64(1)...25 {
            var s = try MPRules.start(knockoutRoom(n, seed: seed), actor: "u0")
            var steps = 0
            while !s.complete && steps < 10 {
                steps += 1
                let r = MPKnockout.current(s)
                let round = try XCTUnwrap(s.rounds[r])
                let games = MPKnockout.matches(s, r)
                let bye = round.bye.map { [$0] } ?? []
                XCTAssertEqual(round.players.count, Set(round.players).count)
                XCTAssertEqual(round.players.count / 2, games.count)
                XCTAssertEqual(round.players.count % 2, bye.count)
                XCTAssertEqual(Set(round.players), Set(games.flatMap { [$0.a, $0.b] } + bye))
                let before = s
                s = try finishRound(s)
                if !s.complete { XCTAssertEqual(Set(s.rounds[r + 1]?.players ?? []), Set(games.map(\.a) + bye)) }
                XCTAssertEqual(before.rounds[r], s.rounds[r])
            }
            XCTAssertTrue(s.complete); XCTAssertEqual(s.matches.count, n - 1)
        } }
    }
    func testKnockoutLastResultCreatesTheNextRoundOnlyOnceAndNeverEarly() throws {
        var s = try MPRules.start(knockoutRoom(8), actor: "u0")
        let first = MPKnockout.matches(s, 0)
        for m in first.dropLast() { s = try finishKnockout(s, m); XCTAssertEqual(s.rounds.count, 1) }
        let last = try XCTUnwrap(first.last)
        s = try finishKnockout(s, last)
        XCTAssertEqual(s.rounds.count, 2)
        XCTAssertEqual(try MPRules.finish(s, match: last.id, actor: s.authority(last), a: 3, b: 0), s)
    }
    func testKnockoutRetriesAndWireRoundTripsKeepTheExactDraw() throws {
        for n in 2...9 {
            let base = try knockoutRoom(n, seed: 381)
            let a = try MPRules.start(base, actor: "u0")
            XCTAssertEqual(a, try MPRules.start(base, actor: "u0"))
            XCTAssertEqual(a, try MPRules.start(a, actor: "u0"))
            let decoded: MPSession = try MPCodec.session(MPCodec.session(a))
            XCTAssertEqual(a, decoded)
            XCTAssertEqual(try finishRound(a), try finishRound(decoded))
        }
    }
    /// Reference values produced on Windows by the real Kotlin stdlib 1.9.23 (`kotlin.random.Random(seed)` and
    /// `shuffled`) with Android `Knockout.draw`'s seed, so iOS and Android draw identical rounds for the same room.
    func testKnockoutDrawEqualsAndroidKotlinRandom() throws {
        var random = MPKotlinRandom(seed: 1)
        XCTAssertEqual((0..<4).map { _ in random.nextInt() }, [600123930, -1531902544, -527218591, -1598672019])
        XCTAssertEqual(([2, 3, 5, 8, 9, 7] as [Int32]).map { random.nextInt(until: $0) }, [1, 2, 1, 4, 8, 4])
        var zero = MPKotlinRandom(seed: 0)
        XCTAssertEqual((0..<4).map { _ in zero.nextInt() }, [-1934310868, 1409199696, -649160781, -1454478562])
        var negative = MPKotlinRandom(seed: Int64.min)
        XCTAssertEqual((0..<4).map { _ in negative.nextInt() }, [-1399536436, 67022416, 138246747, -1507543906])
        let expected: [(Int, Int64, [String])] = [
            (8, 1, ["u7", "u1", "u0", "u5", "u2", "u3", "u6", "u4"]),
            (9, 44, ["u3", "u2", "u4", "u1", "u7", "u8", "u0", "u6", "u5"]),
            (5, 381, ["u0", "u3", "u1", "u2", "u4"]),
            (9, 1727800000123, ["u1", "u2", "u7", "u4", "u8", "u3", "u0", "u5", "u6"]),
        ]
        for (n, createdAt, players) in expected {
            let s = try MPRules.start(knockoutRoom(n, seed: createdAt), actor: "u0")
            XCTAssertEqual(s.rounds[0]?.players, players, "\(n) players, createdAt \(createdAt)")
        }
        let nine = try MPRules.start(knockoutRoom(9, seed: 44), actor: "u0")
        XCTAssertEqual(nine.matches["ABC234_K0_0"]?.seed, -3108893640429508958)
        XCTAssertEqual(nine.rounds[0]?.bye, "u5")
        XCTAssertEqual(try finishRound(nine).rounds[1]?.players, ["u4", "u5", "u0", "u3", "u7"])
        XCTAssertEqual(try finishRound(MPRules.start(knockoutRoom(8, seed: 44), actor: "u0")).rounds[1]?.players, ["u5", "u6", "u1", "u7"])
    }
    func testKnockoutWireFormatMatchesAndroidAndReadsFirebaseArrays() throws {
        let s = try MPRules.start(knockoutRoom(5, seed: 44), actor: "u0")
        let wire: MPWire = try MPCodec.session(s)
        XCTAssertEqual(wire["format"] as? String, "KNOCKOUT")
        let first = MPCodec.map(MPCodec.map(wire["rounds"])["0"])
        XCTAssertEqual((first["count"] as? NSNumber)?.intValue, 5)
        XCTAssertEqual(first["players"] as? [String], ["u0", "u2", "u1", "u3", "u4"])
        XCTAssertEqual(Set(MPCodec.map(wire["matches"]).keys), ["ABC234_K0_0", "ABC234_K0_1"])
        XCTAssertEqual(MPCodec.map(MPCodec.map(wire["matches"])["ABC234_K0_1"])["a"] as? String, "u1")
        // RTDB materializes dense numeric keys as arrays; keyed maps must read the same way.
        let listed: [String: Any] = ["count": 5, "players": ["u0", "u2", "u1", "u3", "u4"]]
        var firebase = wire
        firebase["rounds"] = [listed]
        let fromArrays = try MPCodec.session(firebase)
        XCTAssertEqual(fromArrays.rounds[0]?.players, ["u0", "u2", "u1", "u3", "u4"]); XCTAssertEqual(fromArrays.rounds[0]?.bye, "u4")
        let keyedPlayers: [String: Any] = ["1": "u2", "0": "u0", "4": "u4", "2": "u1", "3": "u3"]
        let keyedRound: [String: Any] = ["count": 5, "players": keyedPlayers]
        var keyed = wire
        keyed["rounds"] = ["0": keyedRound]
        let fromMaps = try MPCodec.session(keyed)
        XCTAssertEqual(fromMaps.rounds[0]?.players, ["u0", "u2", "u1", "u3", "u4"])
        XCTAssertEqual(fromMaps, s)
    }
    func testKnockoutByesAreFreshRandomChoicesAndCanRepeatAcrossRounds() throws {
        var firstByes = Set<String>(), repeated = false, changed = false
        for seed in Int64(1)...400 {
            var s = try MPRules.start(knockoutRoom(9, seed: seed), actor: "u0")
            let bye = try XCTUnwrap(s.rounds[0]?.bye)
            firstByes.insert(bye)
            s = try finishRound(s)
            if s.rounds[1]?.bye == bye { repeated = true } else { changed = true }
        }
        XCTAssertEqual(firstByes.count, 9); XCTAssertTrue(repeated); XCTAssertTrue(changed)
    }
    func testKnockoutInitialPairingsVaryAndTheNextRoundIsRedrawn() throws {
        var firstPairs = Set<String>(), secondPairs = Set<String>()
        for seed in Int64(1)...100 {
            var s = try MPRules.start(knockoutRoom(8, seed: seed), actor: "u0")
            firstPairs.insert(MPKnockout.matches(s, 0).map { $0.a + $0.b }.joined(separator: ","))
            s = try finishRound(s)
            secondPairs.insert(MPKnockout.matches(s, 1).map { $0.a + $0.b }.joined(separator: ","))
        }
        XCTAssertGreaterThan(firstPairs.count, 50); XCTAssertGreaterThan(secondPairs.count, 20)
    }
    func testKnockoutHumanEliminationLetsRemainingHousePlayersFinish() throws {
        var s = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "u0", name: "Player"), capacity: 9, legs: 1, winPoints: 3, difficulty: 4, target: 3, format: .knockout)
        s.createdAt = 44
        for player in MPRoster.all.prefix(8) { s = try MPRules.add(s, actor: "u0", player: player, hebrew: false) }
        s.connections = ["u0": ["0": true]]
        s = try MPRules.start(s, actor: "u0")
        let m = try XCTUnwrap(s.matches.values.first(where: { $0.contains("u0") && !$0.terminal }))
        s = try finishKnockout(s, m, winner: m.a == "u0" ? m.b : m.a)
        XCTAssertTrue(s.complete); XCTAssertEqual(MPKnockout.winner(s)?.hasPrefix("bot_"), true); XCTAssertEqual(s.matches.count, 8)
        XCTAssertFalse(MPCompletionText.won(s, "u0"))
        XCTAssertEqual(MPKnockout.playerStatus(s, "u0", hebrew: false).hasPrefix("Tournament finished. Winner: "), true)
    }
    func testKnockoutWinnerIsTheFinalWinnerRatherThanStandingsPoints() throws {
        var s = try MPRules.start(knockoutRoom(3), actor: "u0")
        var steps = 0
        while !s.complete && steps < 10 { s = try finishRound(s); steps += 1 }
        let winner = try XCTUnwrap(MPKnockout.winner(s))
        XCTAssertTrue(MPCompletionText.won(s, winner))
        for id in s.participants.keys where id != winner { XCTAssertFalse(MPCompletionText.won(s, id)) }
        XCTAssertTrue(MPCompletionText.headline(s, winner, hebrew: false).contains("won"))
        let other = try XCTUnwrap(s.participants.keys.first(where: { $0 != winner }))
        XCTAssertTrue(MPCompletionText.headline(s, other, hebrew: false).contains("Winner:"))
    }
    func testLeavingAKnockoutGivesTheOpponentAWalkoverWithoutAnInventedScore() throws {
        var s = try MPRules.start(knockoutRoom(8), actor: "u0")
        let m = try XCTUnwrap(MPKnockout.matches(s, 0).first(where: { $0.contains("u0") }))
        let other = m.a == "u0" ? m.b : m.a
        s = try MPRules.leave(s, actor: "u0")
        XCTAssertNotEqual(s.host, "u0")
        let cancelled = try XCTUnwrap(s.matches[m.id])
        XCTAssertEqual(cancelled.phase, .cancelled); XCTAssertEqual(cancelled.winner, other)
        XCTAssertEqual(cancelled.scoreA, 0); XCTAssertEqual(cancelled.scoreB, 0)
        s = try finishRound(s)
        let next = try XCTUnwrap(s.rounds[1])
        XCTAssertFalse(next.players.contains("u0")); XCTAssertTrue(next.players.contains(other))
    }
    func testKnockoutWinnerWhoLeavesBeforeTheRoundEndsDoesNotAdvance() throws {
        var s = try MPRules.start(knockoutRoom(8), actor: "u0")
        let m = try XCTUnwrap(MPKnockout.matches(s, 0).first(where: { $0.contains("u0") }))
        s = try finishKnockout(s, m, winner: "u0")
        s = try MPRules.leave(s, actor: "u0")
        XCTAssertEqual(s.matches[m.id]?.phase, .finished)
        s = try finishRound(s)
        XCTAssertEqual(s.rounds[1]?.players.contains("u0"), false)
    }
    func testRoundRobinWireOmitsKnockoutFieldsAndRetainsAllPairs() throws {
        var s = try knockoutRoom(8)
        s.format = .roundRobin; s.legs = 2
        let wire: MPWire = try MPCodec.session(s)
        XCTAssertNil(wire["format"]); XCTAssertNil(wire["rounds"])
        s = try MPRules.start(MPCodec.session(wire), actor: "u0")
        XCTAssertFalse(s.knockout); XCTAssertEqual(s.matches.count, 56); XCTAssertTrue(s.rounds.isEmpty)
        let friendly = MPSession(code: "ABC234", kind: .friendly, host: .init(id: "a", name: "A"), capacity: 9, legs: 2, format: .knockout)
        XCTAssertEqual(friendly.format, .roundRobin); XCTAssertEqual(friendly.capacity, 2)
        let knockout = MPSession(code: "ABC234", kind: .tournament, host: .init(id: "a", name: "A"), capacity: 12, legs: 2, format: .knockout)
        XCTAssertEqual(knockout.capacity, MPKnockout.maxPlayers); XCTAssertEqual(knockout.legs, 1)
        XCTAssertEqual(MPSession(code: "ABC234", kind: .tournament, host: .init(id: "a", name: "A"), capacity: 12).capacity, 8)
    }
    func testKnockoutStageNamesAndAdvancementAreLocalized() throws {
        XCTAssertEqual(MPKnockout.stage(players: 8, hebrew: false), "Quarterfinals")
        XCTAssertEqual(MPKnockout.stage(players: 3, hebrew: false), "Semifinals")
        XCTAssertEqual(MPKnockout.stage(players: 2, hebrew: false), "Final")
        XCTAssertEqual(MPKnockout.stage(players: 9, hebrew: false), "Round of 9")
        XCTAssertEqual(MPKnockout.stage(players: 2, hebrew: true), "הגמר")
        var s = try MPRules.start(knockoutRoom(8), actor: "u0")
        let m = try XCTUnwrap(MPKnockout.matches(s, 0).first)
        s = try finishKnockout(s, m)
        XCTAssertEqual(MPKnockout.advanceText(s, m, hebrew: false), "You reached the semifinals!")
        XCTAssertEqual(MPKnockout.advanceText(s, m, hebrew: true), "העפלת לחצי הגמר!")
        XCTAssertEqual(MPKnockout.playerStatus(s, m.a, hebrew: false), "You reached the semifinals! Waiting for the other matches.")
        XCTAssertEqual(MPKnockout.playerStatus(s, m.b, hebrew: false), "You have been eliminated. You can follow the remaining rounds.")
        XCTAssertEqual(MPTournamentFormat.roundRobin.title(false), "Round robin")
        XCTAssertEqual(MPTournamentFormat.knockout.title(true), "נוקאאוט")
    }
    func testKnockoutBracketColumnsFollowTheDraws() throws {
        let nine = try knockoutRoom(9)
        XCTAssertEqual(MPKnockout.bracketColumns(nine), [9, 5, 3, 2])
        var s = try MPRules.start(nine, actor: "u0")
        XCTAssertEqual(MPKnockout.bracketColumns(s), [9, 5, 3, 2])
        var steps = 0
        while !s.complete && steps < 10 { s = try finishRound(s); steps += 1 }
        XCTAssertEqual(MPKnockout.bracketColumns(s), [9, 5, 3, 2])
        XCTAssertEqual(MPKnockout.bracketColumns(try knockoutRoom(3)), [3, 2])
    }
}
