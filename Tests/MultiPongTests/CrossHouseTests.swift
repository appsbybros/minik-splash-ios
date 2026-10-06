import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../cross/CrossHouseTest.kt (MinikCrossPong 828c6fc).
final class CrossHouseTests: XCTestCase {
    /// Kotlin `Tuning.forDifficulty(Difficulty.STARTER)`.
    private let physics = MPTuning.values(.easy)
    private let tables = [CrossGeometry(3), CrossGeometry(4)]

    /// Kotlin `CrossHouse(g, physics, seat, BotRoster.find(character)!!.profile, Difficulty.BEGINNER, seed)`.
    private func house(_ g: CrossGeometry, _ character: String, seat: Int = 0, seed: Int64 = 7) -> CrossHouse {
        CrossHouse(g, physics: physics, seat: seat, profile: MPRoster.find(character)!.profile, control: .beginner, seed: seed)
    }

    private func skill(_ character: String) -> Double {
        let p = MPRoster.find(character)!.profile
        return Double(p.forehandSkill + p.backhandSkill + p.accuracy) / 3.0
    }

    /// Kotlin `first(g, state)`: the forecast first event (nil where Kotlin's `!!` would throw).
    private func first(_ g: CrossGeometry, _ state: CrossBallState) -> CrossBallEvent? {
        CrossBall(g, tuning: physics, initial: state).forecast()?.event
    }

    /// Kotlin data-class equality of `Tuning` (MPTuning is not Equatable): every number, profile included.
    private func tuningNumbers(_ t: MPTuning) -> [Double] {
        var v: [Double] = [t.tapSpatialTolerance, t.tapTimingWindow, t.tapTimingQualityExponent, t.swipeCollisionForgiveness]
        v += [t.swipeVelocityScale, t.minimumSwipeSpeed, t.maximumSwipeSpeed, t.serveAssistance, t.ballBaseSpeed]
        v += [t.rallySpeedGrowth, t.maximumBallSpeed, t.gravity, t.bounceRestitution, t.netHeight]
        v += [t.netClearanceVelocityTarget, t.maximumArcVelocity, t.incomingVelocityInfluence, t.minikReactionInterval]
        v += [t.minikMaximumReach, t.minikPredictionAmount, t.minikAimError, t.minikErrorProbability]
        v += [t.minikPoorContactProbability, t.minikCornerPreference, t.minikReturnSpeedMultiplier]
        v += [t.minikForehandPreference, t.minikServeFaultProbability]
        return v + profileNumbers(t.profile)
    }

    /// Kotlin data-class equality of `MinikProfile` (MPProfile is not Equatable).
    private func profileNumbers(_ p: MPProfile) -> [Double] {
        var v: [Double] = [p.forehandServe, p.serveSuccess, p.serveMiddle, p.serveSpeed, p.serveVariation]
        v.append(Double(p.serveReceive.count))
        for c in p.serveReceive { v += [c.answer, c.good] }
        let chances: [MPChance] = [p.forehandSame, p.forehandCross, p.backhandSame, p.backhandCross]
        for c in chances { v += [c.answer, c.good] }
        v += [p.answerDrop, p.goodDrop, p.backhandCrossGoodDrop, p.firstForehandSpeed, p.firstBackhandSpeed, p.accelerateChance]
        v += [p.forehandSpeedUp.lowerBound, p.forehandSpeedUp.upperBound, p.backhandSpeedUp.lowerBound, p.backhandSpeedUp.upperBound]
        v += [p.speedDown.lowerBound, p.speedDown.upperBound, p.maxSpeed]
        return v
    }

    // Kotlin: everyCharacterKeepsItsOwnTuningAndRelativeStrength
    func testEveryCharacterKeepsItsOwnTuningAndRelativeStrength() {
        let g = CrossGeometry(4)
        for character in MPRoster.all {
            let h = house(g, character.id)
            // Kotlin `profile.controlTuning(Difficulty.BEGINNER)`.
            XCTAssertEqual(tuningNumbers(character.profile.tuning(.beginner, houseControls: true)), tuningNumbers(h.tuning), character.id)
            XCTAssertEqual(1.13 * character.profile.movement, h.speedLimit, accuracy: 1e-12)
        }
        let kyra = house(g, "kyra")
        let bob = house(g, "moshiko")
        XCTAssertEqual("ספיר", MPRoster.find("kyra")?.hebrew)
        let strong = kyra.tuning.profile
        let weakProfile = bob.tuning.profile
        XCTAssertTrue(strong.forehandSame.answer > weakProfile.forehandSame.answer && strong.backhandSame.good > weakProfile.backhandSame.good)
        XCTAssertTrue(strong.serveSuccess > weakProfile.serveSuccess)
        XCTAssertTrue(kyra.speedLimit > bob.speedLimit)
        XCTAssertTrue(kyra.reactionTicks < bob.reactionTicks)
        // The control level changes only input forgiveness, never a character's skill.
        let pro = CrossHouse(g, physics: physics, seat: 0, profile: MPRoster.find("kyra")!.profile, control: .superHard, seed: 7)
        XCTAssertEqual(profileNumbers(kyra.tuning.profile), profileNumbers(pro.tuning.profile))
        XCTAssertEqual(kyra.tuning.minikReactionInterval, pro.tuning.minikReactionInterval)
    }

    // Kotlin: targetsNeverRepeatMoreThanThreeTimesInARowAndAvoidStraightLanes
    func testTargetsNeverRepeatMoreThanThreeTimesInARowAndAvoidStraightLanes() {
        for g in tables {
            for character in MPRoster.all {
                let strategy = CrossStrategy(g, seat: 1, skill: skill(character.id))
                var random = MPKotlinRandom(intSeed: 42)
                var run = 0
                var last = -1
                for i in 0..<800 {
                    var sender: Int? = nil
                    if i % 5 != 0 { sender = random.element(strategy.opponents) }
                    let lane: Int? = i % 7 == 0 ? sender : nil
                    let forced = strategy.repeats >= CrossStrategy.maxRepeats
                    let previous = strategy.lastTarget
                    let target = strategy.target(sender, random: &random, lane: { $0 == lane })
                    XCTAssertTrue(strategy.opponents.contains(target))
                    // A lane is always left when a third opponent allows it; on a 3-seat table the repeat limit can win.
                    if let laneSeat = lane, g.players == 4 || !forced || previous == laneSeat {
                        XCTAssertNotEqual(laneSeat, target)
                    }
                    run = target == last ? run + 1 : 1
                    last = target
                    XCTAssertTrue(run <= CrossStrategy.maxRepeats, "\(character.id) picked \(target) \(run) times in a row")
                }
            }
        }
    }

    /// Kotlin local `sample(character)` of weakerPlayersStaySimpleAndStrongerOnesVaryTargetWidthAndDepth.
    private func sample(_ g: CrossGeometry, _ character: String) -> (back: Double, width: Double, depth: Double) {
        let strategy = CrossStrategy(g, seat: 0, skill: skill(character))
        var random = MPKotlinRandom(intSeed: 9)
        var back = 0
        var width = 0.0
        var depths: [Double] = []
        for i in 0..<900 {
            let sender = strategy.opponents[i % 3]
            if strategy.target(sender, random: &random) == sender { back += 1 }
            if i % 4 == 0 { strategy.newRally() }
            let incoming: Double = Double(i % 3 - 1) * 0.3
            let placed = strategy.place(2, incomingU: incoming, random: &random)
            let local = g.toLocal(2, placed.point)
            width += abs(local.u)
            depths.append(local.v)
            let far: Double = CrossGeometry.reach - 0.15 + 1e-12
            XCTAssertTrue(abs(local.u) <= CrossAimMap.edgeU + 1e-12 && local.v >= CrossAimMap.sideNear - 1e-12 && local.v <= far)
            XCTAssertTrue(placed.pace >= 0.98 && placed.pace <= 1.22)
        }
        let deepest = depths.max() ?? 0
        let shortest = depths.min() ?? 0
        return (back: Double(back) / 900.0, width: width / 900, depth: deepest - shortest)
    }

    // Kotlin: weakerPlayersStaySimpleAndStrongerOnesVaryTargetWidthAndDepth
    func testWeakerPlayersStaySimpleAndStrongerOnesVaryTargetWidthAndDepth() {
        let g = CrossGeometry(4)
        let bob = sample(g, "moshiko")
        let mia = sample(g, "mia")
        let kyra = sample(g, "kyra")
        XCTAssertTrue(bob.back > 0.5, "weak players mostly return to the sender: \(bob)")
        XCTAssertTrue(kyra.back < 0.3, "strong players switch opponents: \(kyra)")
        XCTAssertTrue(bob.width < mia.width && mia.width < kyra.width)
        XCTAssertTrue(bob.depth < kyra.depth)
    }

    // Kotlin: houseServesBounceInTheOwnServeZoneThenInAnOpponentsTerritoryOrAreGenuineFaults
    func testHouseServesBounceInTheOwnServeZoneThenInAnOpponentsTerritoryOrAreGenuineFaults() throws {
        for g in tables {
            var faults: [String: Int] = [:]
            for character in ["kyra", "moshiko"] {
                for seat in g.seats {
                    let h = house(g, character, seat: seat, seed: Int64(100 + seat))
                    let start = g.fromLocal(seat, 0, CrossEngine.serveDepth)
                    var targets = Set<Int>()
                    for _ in 0..<150 {
                        let plan = h.serve(start)
                        let state = CrossBallState(position: plan.start, height: plan.height, velocity: plan.launch.velocity,
                                                   lift: plan.launch.lift, rebound: plan.rebound)
                        let ball = CrossBall(g, tuning: physics, initial: state)
                        guard let own = ball.firstEvent().event else {
                            XCTFail("\(character) \(seat): the serve has no first event")
                            continue
                        }
                        guard case let .bounce(ownPoint, ownOwner) = own, g.inServeZone(seat, ownPoint) else {
                            faults[character, default: 0] += 1
                            continue
                        }
                        XCTAssertEqual(seat, ownOwner)
                        let second = ball.firstEvent().event
                        guard case let .bounce(_, secondOwner)? = second, secondOwner != seat else {
                            XCTFail("\(String(describing: second))")
                            continue
                        }
                        targets.insert(secondOwner)
                    }
                    XCTAssertEqual(g.players - 1, targets.count, "\(character) serves to every opponent")
                }
            }
            XCTAssertTrue((faults["moshiko"] ?? 0) > (faults["kyra"] ?? 0), "\(faults)")
            // A drill serve is never a fault and goes to the requested seat.
            let h = house(g, "moshiko", seat: 1)
            for _ in 0..<40 {
                let plan = h.serve(g.fromLocal(1, 0, CrossEngine.serveDepth), target: 0, allowFault: false)
                XCTAssertTrue(g.inServeZone(1, plan.first))
                let second = try XCTUnwrap(plan.second)
                XCTAssertEqual(0, g.owner(second))
            }
        }
    }

    // Kotlin: goodShotsLandWhereChosenAndBadShotsAreGenuineOwnFaults
    func testGoodShotsLandWhereChosenAndBadShotsAreGenuineOwnFaults() {
        for g in tables {
            for seat in g.seats {
                let h = house(g, "mia", seat: seat, seed: 5)
                let from = g.fromLocal(seat, 0.1, 1.0)
                var kinds = Set<String>()
                for _ in 0..<120 {
                    let goodContact = MPContact(point: from, timing: 0.9, spatial: 0.9, velocity: MPPoint(0, 0.42), direction: 0)
                    let good = h.shot(goodContact, from: from, height: 0.15, sender: g.wrap(seat + 1))
                    XCTAssertFalse(good.fault)
                    let event = first(g, CrossBallState(position: from, height: 0.15, velocity: good.launch.velocity, lift: good.launch.lift))
                    var owner: Int? = nil
                    if case let .bounce(_, bounceOwner)? = event { owner = bounceOwner }
                    XCTAssertTrue(owner == good.target && good.target != seat, "\(String(describing: event))")
                    if let landed = event { assertNear(good.point, landed.point, 1e-9) } else { XCTFail("no event") }
                    let badContact = MPContact(point: from, timing: 0.05, spatial: 0.05, velocity: MPPoint(0, 0.42), direction: 0)
                    let bad = h.shot(badContact, from: from, height: 0.15, sender: g.wrap(seat + 1))
                    XCTAssertTrue(bad.fault)
                    let badEvent = first(g, CrossBallState(position: from, height: 0.15, velocity: bad.launch.velocity, lift: bad.launch.lift))
                    switch badEvent {
                    case .net?:
                        kinds.insert("net")
                    case .landed?:
                        kinds.insert("out")
                    case let .bounce(_, badOwner)?:
                        XCTAssertEqual(seat, badOwner, "a bad shot never reaches an opponent")
                        kinds.insert("own side")
                    case nil:
                        XCTFail("a bad shot without an event")
                    }
                }
                XCTAssertEqual(Set(["net", "out", "own side"]), kinds)
            }
        }
    }

    // Kotlin: plansRespectTheSpeedLimitAndArriveBeforeTheWindup
    func testPlansRespectTheSpeedLimitAndArriveBeforeTheWindup() {
        let g = CrossGeometry(4)
        let h = house(g, "moshiko", seat: 2)
        // Reachable: the racket arrives WINDUP before contact and stays planted.
        let nearBall = CrossBallState(position: g.fromLocal(2, 0.2, 1.0), height: 0.2, velocity: MPPoint(0, 0), lift: 0)
        let near = CrossReach(ticks: 120, state: nearBall, inZone: true)
        let motion = CrossMotion(home: CrossLocal(0, CrossGeometry.homeDepth), speedLimit: h.speedLimit)
        let plan = h.makePlan(near, now: 1000, motion: motion)
        XCTAssertTrue(plan.reachable)
        XCTAssertEqual(1120, plan.tick)
        XCTAssertFalse(plan.left)
        for _ in 0..<(120 - Int(CrossEngine.windupTicks)) { motion.advance(CrossBall.substep) }
        XCTAssertFalse(motion.moving)
        assertNear(MPPoint(0.2, 1.0), MPPoint(motion.racket.u, motion.racket.v), 1e-9)
        // Unreachable: no teleport, the racket covers at most speedLimit x time and the plan is a miss.
        let farBall = CrossBallState(position: g.fromLocal(2, -0.6, 0.75), height: 0.2, velocity: MPPoint(0, 0), lift: 0)
        let far = CrossReach(ticks: 40, state: farBall, inZone: true)
        let from = CrossLocal(0.6, 1.2)
        let slow = CrossMotion(home: CrossLocal(0, CrossGeometry.homeDepth), speedLimit: h.speedLimit)
        slow.place(from)
        let miss = h.makePlan(far, now: 0, motion: slow)
        XCTAssertFalse(miss.reachable)
        XCTAssertTrue(miss.left)
        let available: Double = 40 * CrossBall.substep - CrossActor.windup
        XCTAssertEqual(h.speedLimit * available, CrossMotion.distance(from, slow.destination), accuracy: 1e-9)
        var previous = slow.racket
        let limit: Double = 1.5 * h.speedLimit * CrossBall.substep + 1e-9
        while slow.moving {
            slow.advance(CrossBall.substep)
            // Smoothstep peaks at 1.5x the average speed.
            XCTAssertTrue(CrossMotion.distance(previous, slow.racket) <= limit)
            previous = slow.racket
        }
        XCTAssertEqual(CrossGeometry.strikeNear, CrossGeometry.reach - 0.42, accuracy: 1e-12)
    }

    // Kotlin: forecastsAndInterceptsNeverMoveTheLiveBallAndWaitForTheBallToRise
    func testForecastsAndInterceptsNeverMoveTheLiveBallAndWaitForTheBallToRise() throws {
        for g in tables {
            let launch = CrossShots.targeted(g, physics, from: g.home(1), height: 0.1, target: g.fromLocal(0, 0.1, 0.78), pace: 0.88)
            let live = CrossBall(g, tuning: physics, initial: CrossBallState(position: g.home(1), height: 0.1, velocity: launch.velocity, lift: launch.lift))
            let before = live.state
            let r = try XCTUnwrap(CrossForecast.receiving(g, live, striker: 1))
            XCTAssertEqual(0, r.owner)
            XCTAssertEqual(before, live.state)
            let reach = CrossForecast.intercept(g, seat: 0, r, earliest: 0)
            XCTAssertEqual(before, live.state)
            XCTAssertTrue(reach.inZone && reach.ticks > r.ticks)
            XCTAssertTrue(reach.state.height >= CrossForecast.rise || reach.state.lift <= 0.0)
            // The live ball, stepped the same number of substeps, is exactly where the plan expects it.
            for _ in 0..<max(0, reach.ticks) { live.step(CrossBall.substep) }
            XCTAssertEqual(reach.state, live.state)
            // Flights that end in a fault have no receiver.
            let dead = CrossBall(g, tuning: physics, initial: CrossBallState(position: g.home(1), height: 0.1, velocity: MPPoint(0, 0), lift: 0))
            XCTAssertNil(CrossForecast.receiving(g, dead, striker: 1))
        }
    }

    // Kotlin: straightRepeatedLanesAreCountedFromEverySeatAndChangedOnTheFifthHit
    func testStraightRepeatedLanesAreCountedFromEverySeatAndChangedOnTheFifthHit() {
        let v = CrossVariation()
        v.hit(0, 2, 0.1)
        v.hit(2, 0, -0.05)
        v.hit(0, 2, 0.12)
        v.hit(2, 0, -0.02)
        XCTAssertEqual(4, v.straight)
        XCTAssertTrue(v.due(0, 2, 0.15))
        XCTAssertFalse(v.due(0, 1, 0.15))
        XCTAssertFalse(v.due(0, 2, 0.3))
        v.hit(0, 1, 0.15)
        XCTAssertEqual(1, v.straight)
        v.reset()
        XCTAssertEqual(0, v.straight)
        XCTAssertFalse(v.due(1, 0, 0.0))
    }
}
