import XCTest
@testable import MinikMultiPingPong

// Android cross/CrossBallTest.kt (MinikCrossPong 828c6fc). Android `Tuning.forDifficulty(STARTER)` = iOS `MPTuning.values(.easy)`.
final class CrossBallTests: XCTestCase {
    private let tuning = MPTuning.values(.easy)
    private let four = CrossGeometry(4)
    private let three = CrossGeometry(3)

    private func ball(_ g: CrossGeometry, _ p: MPPoint, _ h: Double, _ v: MPPoint, _ lift: Double, _ rebound: CrossLaunch? = nil) -> CrossBall {
        CrossBall(g, tuning: tuning, initial: CrossBallState(position: p, height: h, velocity: v, lift: lift, rebound: rebound))
    }

    private func bounceOf(_ event: CrossBallEvent?) -> (point: MPPoint, owner: Int)? {
        if let event, case let .bounce(point, owner) = event { return (point: point, owner: owner) }
        return nil
    }

    private func netOf(_ event: CrossBallEvent?) -> (point: MPPoint, height: Double)? {
        if let event, case let .net(point, height) = event { return (point: point, height: height) }
        return nil
    }

    private func landedOf(_ event: CrossBallEvent?) -> MPPoint? {
        if let event, case let .landed(point) = event { return point }
        return nil
    }

    private func kindOf(_ event: CrossBallEvent) -> String {
        switch event {
        case .bounce: return "bounce"
        case .net: return "net"
        case .landed: return "landed"
        }
    }

    // Kotlin: usesTheTuningConstants
    func testUsesTheTuningConstants() {
        let b = ball(four, MPPoint(0, 0.8), 0.1, MPPoint(0, 0), 0)
        XCTAssertEqual(3.6, b.gravity)
        XCTAssertEqual(0.54, b.restitution)
        XCTAssertEqual(0.075, b.netHeight)
    }

    // Kotlin: bouncesOnTheTableAtTheExactSubStepTimeAndKeepsTheRestOfTheStep
    func testBouncesOnTheTableAtTheExactSubStepTimeAndKeepsTheRestOfTheStep() {
        let b = ball(four, MPPoint(0.1, 0.9), 0.25, MPPoint(0.2, -0.5), 0)
        let ground: Double = sqrt(2 * 0.25 / tuning.gravity)
        let result = b.firstEvent()
        guard let bounce = bounceOf(result.event) else { return XCTFail("\(String(describing: result.event))") }
        XCTAssertEqual(0, bounce.owner)
        assertNear(MPPoint(0.1 + 0.2 * ground, 0.9 - 0.5 * ground), bounce.point, 1e-12)
        XCTAssertEqual(Int(ceil(ground * 120)), result.steps)
        let rest: Double = Double(result.steps) / 120.0 - ground
        let rebound: Double = tuning.gravity * ground * tuning.bounceRestitution
        XCTAssertEqual(rebound - tuning.gravity * rest, b.lift, accuracy: 1e-9)
        let expectedHeight: Double = rebound * rest - 0.5 * tuning.gravity * rest * rest
        XCTAssertEqual(expectedHeight, b.height, accuracy: 1e-12)
        assertNear(bounce.point + MPPoint(0.2, -0.5) * rest, b.position, 1e-12)
        XCTAssertFalse(b.stopped)
        // The next bounce is again on the table, further along the same straight line.
        guard let next = bounceOf(b.firstEvent().event) else { return XCTFail("no second bounce") }
        let flight: Double = 2 * rebound / tuning.gravity
        assertNear(bounce.point + MPPoint(0.2, -0.5) * flight, next.point, 1e-9)
    }

    // Kotlin: aLowBallStopsAtTheNetAtTheInterpolatedHeightAndAHighBallClearsIt
    func testALowBallStopsAtTheNetAtTheInterpolatedHeightAndAHighBallClearsIt() {
        // The net between seats 0 and 1 runs from the centre to (0.5, 0.5) along x = y.
        let low = ball(four, MPPoint(0.2, 0.35), 0.05, MPPoint(1, 0), 0.1)
        guard let net = netOf(low.firstEvent().event) else { return XCTFail("no net contact") }
        assertNear(MPPoint(0.35, 0.35), net.point, 1e-12)
        let expected: Double = 0.05 + 0.1 * 0.15 - 0.5 * tuning.gravity * 0.15 * 0.15
        XCTAssertEqual(expected, net.height, accuracy: 1e-12)
        XCTAssertTrue(low.stopped)
        XCTAssertEqual(net.point, low.position)
        XCTAssertEqual(MPPoint(0, 0), low.velocity)
        XCTAssertNil(low.step(CrossBall.substep))
        XCTAssertNil(low.forecast())
        let high = ball(four, MPPoint(0.2, 0.35), 0.3, MPPoint(1, 0), 0.6)
        let over = high.firstEvent().event
        XCTAssertNotNil(bounceOf(over), "\(String(describing: over))")
        XCTAssertEqual(1, bounceOf(over)?.owner)
    }

    // Kotlin: theCentrePostIsPartOfTheNet
    func testTheCentrePostIsPartOfTheNet() {
        let b = ball(four, MPPoint(0, 0.3), 0.06, MPPoint(0, -1), 0.5)
        guard let net = netOf(b.firstEvent().event) else { return XCTFail("no post contact") }
        assertNear(MPPoint(0, CrossGeometry.post), net.point, 1e-12)
        let t: Double = 0.3 - CrossGeometry.post
        let expected: Double = 0.06 + 0.5 * t - 0.5 * tuning.gravity * t * t
        XCTAssertEqual(expected, net.height, accuracy: 1e-12)
        // High enough, the same line passes over the post and the centre.
        let over = ball(four, MPPoint(0, 0.3), 0.3, MPPoint(0, -1), 0.5).firstEvent().event
        XCTAssertEqual(2, bounceOf(over)?.owner, "\(String(describing: over))")
        // Dropping onto the post top from above is a net contact too.
        guard let drop = netOf(ball(four, MPPoint(0.01, 0.01), 0.3, MPPoint(0, 0), 0).firstEvent().event) else {
            return XCTFail("no drop contact")
        }
        XCTAssertEqual(tuning.netHeight, drop.height, accuracy: 1e-9)
        assertNear(MPPoint(0.01, 0.01), drop.point, 0)
    }

    // Kotlin: travellingAlongANetLineStopsOnTheNetTop
    func testTravellingAlongANetLineStopsOnTheNetTop() {
        // Three players: the net between seats 1 and 2 lies on the -y axis.
        let b = ball(three, MPPoint(0, -0.1), 0.2, MPPoint(0, -1), 0)
        guard let net = netOf(b.firstEvent().event) else { return XCTFail("no net contact") }
        let t: Double = sqrt(2 * (0.2 - tuning.netHeight) / tuning.gravity)
        assertNear(MPPoint(0, -0.1 - t), net.point, 1e-9)
        XCTAssertEqual(tuning.netHeight, net.height, accuracy: 1e-9)
    }

    // Kotlin: flightOverTheGapBetweenArmsIsFreeAndLandsOnTheNextArm
    func testFlightOverTheGapBetweenArmsIsFreeAndLandsOnTheNextArm() {
        let from = MPPoint(0.3, 0.9)
        let to = MPPoint(0.9, 0.3)
        let time = 0.8
        let h = 0.1
        let lift: Double = (0.5 * tuning.gravity * time * time - h) / time
        let b = ball(four, from, h, (to - from) * (1 / time), lift)
        var overGap = false
        var event: CrossBallEvent? = nil
        for _ in 0..<200 {
            event = b.step(CrossBall.substep)
            if event != nil { break }
            if !four.onTable(b.position) { overGap = true }
        }
        XCTAssertTrue(overGap, "The flight must pass over the notch")
        guard let bounce = bounceOf(event) else { return XCTFail("no bounce") }
        XCTAssertEqual(1, bounce.owner)
        assertNear(to, bounce.point, 1e-9)
        // Three players: from seat 0's arm over the notch beyond the hub into seat 1's arm.
        let start = three.fromLocal(0, 0.4, 1.0)
        let target = three.fromLocal(1, -0.4, 1.0)
        XCTAssertTrue((0...20).contains { !three.onTable(start + (target - start) * (Double($0) / 20.0)) })
        let c = ball(three, start, h, (target - start) * (1 / time), lift)
        guard let landing = bounceOf(c.firstEvent().event) else { return XCTFail("no landing bounce") }
        XCTAssertEqual(1, landing.owner)
        assertNear(target, landing.point, 1e-9)
    }

    // Kotlin: landingOffTheTableIsLandedAndStopsTheBall
    func testLandingOffTheTableIsLandedAndStopsTheBall() {
        // Comes down in the notch between the bottom and right arms of the plus.
        let notch = ball(four, MPPoint(0.3, 0.9), 0.1, MPPoint(0.8, -0.4), 0.4)
        guard let landed = landedOf(notch.firstEvent().event) else { return XCTFail("not landed") }
        let t: Double = (0.4 + sqrt(0.16 + 2 * tuning.gravity * 0.1)) / tuning.gravity
        assertNear(MPPoint(0.3 + 0.8 * t, 0.9 - 0.4 * t), landed, 1e-12)
        XCTAssertFalse(four.onTable(landed))
        XCTAssertTrue(notch.stopped)
        XCTAssertEqual(0.0, notch.height)
        XCTAssertEqual(landed, notch.position)
        for _ in 0..<10 { XCTAssertNil(notch.step(CrossBall.substep)) }
        // Beyond the end of an arm.
        let long = ball(three, three.fromLocal(2, 0, 0.9), 0.2, three.dir(2), 0.5)
        XCTAssertNotNil(landedOf(long.firstEvent().event))
    }

    // Kotlin: forecastSimulatesACopyAndNeverMovesTheLiveBall
    func testForecastSimulatesACopyAndNeverMovesTheLiveBall() {
        let from = MPPoint(0.3, 0.9)
        let to = MPPoint(0.9, 0.3)
        let lift: Double = (0.5 * tuning.gravity * 0.64 - 0.1) / 0.8
        let b = ball(four, from, 0.1, (to - from) * 1.25, lift)
        let before = b.state
        guard let forecast = b.forecast() else { return XCTFail("no forecast") }
        XCTAssertEqual(before, b.state)
        guard let bounce = bounceOf(forecast.event) else { return XCTFail("forecast is not a bounce") }
        XCTAssertEqual(1, bounce.owner)
        assertNear(to, bounce.point, 1e-12)
        XCTAssertEqual(0.8, forecast.seconds, accuracy: 1e-12)
        let incoming: Double = (0.5 * tuning.gravity * 0.64 + 0.1) / 0.8
        XCTAssertEqual(0.0, forecast.state.height)
        XCTAssertEqual(incoming * tuning.bounceRestitution, forecast.state.lift, accuracy: 1e-9)
        let result = b.firstEvent()
        guard let live = result.event else { return XCTFail("no live event") }
        XCTAssertTrue(live.isBounce)
        assertNear(bounce.point, live.point, 1e-12)
        XCTAssertTrue((96...97).contains(result.steps), "\(result.steps)")
        // A limited horizon reports nothing.
        XCTAssertNil(ball(four, from, 0.1, (to - from) * 1.25, 1.2).forecast(0.1))
    }

    // Kotlin: aServeTakesItsPlannedReboundAtItsOwnBounceOnly
    func testAServeTakesItsPlannedReboundAtItsOwnBounceOnly() {
        let rebound = CrossLaunch(velocity: MPPoint(0, -0.5), lift: 1.2)
        let b = ball(four, MPPoint(0, 1.16), 0.055, MPPoint(0, -0.8), 0.9, rebound)
        guard let own = b.forecast() else { return XCTFail("no forecast") }
        XCTAssertEqual(rebound, CrossLaunch(velocity: own.state.velocity, lift: own.state.lift))
        XCTAssertNil(own.state.rebound)
        XCTAssertEqual(rebound, b.rebound) // the forecast did not consume the live plan
        guard let first = bounceOf(b.firstEvent().event) else { return XCTFail("no own bounce") }
        XCTAssertEqual(0, first.owner)
        XCTAssertNil(b.rebound)
        XCTAssertEqual(rebound.velocity, b.velocity)
        guard let second = bounceOf(b.firstEvent().event) else { return XCTFail("no second bounce") }
        let flight: Double = 2 * rebound.lift / tuning.gravity
        assertNear(first.point + rebound.velocity * flight, second.point, 1e-9)
        // The plan is used once; the second bounce is ordinary restitution on the same line.
        XCTAssertEqual(rebound.velocity, b.velocity)
        XCTAssertNil(b.rebound)
        guard let third = b.forecast() else { return XCTFail("no third forecast") }
        let expected: Double = 2 * rebound.lift * tuning.bounceRestitution / tuning.gravity
        let travelled: Double = (b.position - second.point).length / rebound.velocity.length
        XCTAssertEqual(expected, third.seconds + travelled, accuracy: 1e-9)
    }

    // Kotlin: aBounceAndANetContactInOneStepAreReportedOnConsecutiveSteps
    func testABounceAndANetContactInOneStepAreReportedOnConsecutiveSteps() {
        // Lands just left of the 0|1 net line and crosses it right after the bounce.
        let b = ball(four, MPPoint(0.2985, 0.3), 0, MPPoint(1.2, 0), -0.5)
        let first = b.step(CrossBall.substep)
        XCTAssertEqual(0, bounceOf(first)?.owner, "\(String(describing: first))")
        XCTAssertFalse(b.stopped)
        XCTAssertTrue(b.position.x < 0.3 && b.position.x > 0.2985, "The ball waits just before the net")
        let second = b.step(CrossBall.substep)
        XCTAssertNotNil(netOf(second), "\(String(describing: second))")
        if let point = second?.point { assertNear(MPPoint(0.3, 0.3), point, 1e-9) }
        XCTAssertTrue(b.stopped)
    }

    // Kotlin: aDeadBounceStopsTheBallInsteadOfBouncingInPlace
    func testADeadBounceStopsTheBallInsteadOfBouncingInPlace() {
        let b = ball(four, MPPoint(0, 0.8), 0, MPPoint(0.1, 0), -0.05)
        let event = b.step(CrossBall.substep)
        XCTAssertNotNil(bounceOf(event))
        XCTAssertTrue(b.stopped)
        XCTAssertNil(b.step(CrossBall.substep))
    }

    // Kotlin: randomFlightsEndWithOneEventThatMatchesTheirForecast
    func testRandomFlightsEndWithOneEventThatMatchesTheirForecast() {
        var random = MPKotlinRandom(intSeed: 2024)
        for g in [three, four] {
            for _ in 0..<3000 {
                let px = random.nextDouble(-1.4, 1.4)
                let py = random.nextDouble(-1.4, 1.4)
                let height = random.nextDouble(0.0, 0.6)
                let vx = random.nextDouble(-3.0, 3.0)
                let vy = random.nextDouble(-3.0, 3.0)
                let lift = random.nextDouble(-1.0, 4.0)
                let state = CrossBallState(position: MPPoint(px, py), height: height, velocity: MPPoint(vx, vy), lift: lift)
                let live = CrossBall(g, tuning: tuning, initial: state)
                guard let forecast = live.forecast(10.0) else {
                    XCTFail("no forecast for \(state)")
                    continue
                }
                XCTAssertEqual(state, live.state)
                let limit = Int(ceil(live.groundTime() * 120)) + 1
                var steps = 0
                var first: CrossBallEvent? = nil
                while first == nil && steps <= limit {
                    first = live.step(CrossBall.substep)
                    steps += 1
                }
                XCTAssertTrue(steps <= limit, "\(state)")
                guard let event = first else {
                    XCTFail("no event for \(state)")
                    continue
                }
                XCTAssertEqual(kindOf(forecast.event), kindOf(event), "\(state)")
                assertNear(forecast.event.point, event.point, 1e-9, "\(state)")
                switch event {
                case let .bounce(point, owner):
                    XCTAssertTrue(g.onTable(point))
                    XCTAssertEqual(g.owner(point), owner)
                case let .landed(point):
                    XCTAssertFalse(g.onTable(point))
                    XCTAssertTrue(live.stopped)
                case let .net(_, netHeight):
                    XCTAssertTrue(netHeight <= tuning.netHeight + 1e-12)
                    XCTAssertTrue(live.stopped)
                }
                XCTAssertTrue(live.state.valid())
            }
        }
    }

    // Kotlin: launchRestoreAndCopyAreIndependent
    func testLaunchRestoreAndCopyAreIndependent() {
        let b = ball(four, MPPoint(0, 0.8), 0.1, MPPoint(0, 0), 0)
        b.launch(MPPoint(0.2, 1.1), 0.1, CrossLaunch(velocity: MPPoint(-0.2, -0.9), lift: 1.0),
                 rebound: CrossLaunch(velocity: MPPoint(0.1, -0.5), lift: 0.8))
        let expected = CrossBallState(position: MPPoint(0.2, 1.1), height: 0.1, velocity: MPPoint(-0.2, -0.9), lift: 1.0,
                                      rebound: CrossLaunch(velocity: MPPoint(0.1, -0.5), lift: 0.8))
        XCTAssertEqual(expected, b.state)
        let copy = b.copy()
        copy.step(CrossBall.substep)
        XCTAssertEqual(MPPoint(0.2, 1.1), b.position)
        b.restore(copy.state)
        XCTAssertEqual(copy.state, b.state)
        XCTAssertTrue(b.state.valid())
        var broken = b.state
        broken.height = Double.nan
        XCTAssertFalse(broken.valid())
        var fast = b.state
        fast.velocity = MPPoint(99, 0)
        XCTAssertFalse(fast.valid())
        // A dt above one engine frame is capped, a negative or zero dt does nothing.
        let before = b.state
        XCTAssertNil(b.step(0.0))
        XCTAssertNil(b.step(-1.0))
        XCTAssertEqual(before, b.state)
    }
}
