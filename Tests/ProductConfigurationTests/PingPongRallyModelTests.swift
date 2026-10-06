import CoreGraphics
import XCTest
@testable import MinikPlus

final class PingPongRallyModelTests: XCTestCase {
    func testFourTuningsAreDistinctAndHardRemainsImperfect() {
        let starter = PingPongTuning.values(for: .starter)
        let easy = PingPongTuning.values(for: .easy)
        let medium = PingPongTuning.values(for: .medium)
        let hard = PingPongTuning.values(for: .hard)

        XCTAssertGreaterThan(starter.tapSpatialTolerance, easy.tapSpatialTolerance)
        XCTAssertGreaterThan(easy.tapSpatialTolerance, medium.tapSpatialTolerance)
        XCTAssertGreaterThan(medium.tapSpatialTolerance, hard.tapSpatialTolerance)
        XCTAssertLessThan(starter.ballBaseSpeed, easy.ballBaseSpeed)
        XCTAssertLessThan(easy.ballBaseSpeed, medium.ballBaseSpeed)
        XCTAssertLessThan(medium.ballBaseSpeed, hard.ballBaseSpeed)
        XCTAssertGreaterThan(hard.minikErrorProbability, 0)
        XCTAssertGreaterThan(hard.minikServeFaultProbability, 0)
    }

    func testPaddleSideMappingUsesForehandAtCenter() {
        XCTAssertEqual(PingPongPaddleSide.side(forNormalizedX: 0.2), .backhand)
        XCTAssertEqual(PingPongPaddleSide.side(forNormalizedX: 0.5), .forehand)
        XCTAssertEqual(PingPongPaddleSide.side(forNormalizedX: 0.8), .forehand)
    }

    func testTapRequiresLegalZoneSpatialAndTimingTolerance() {
        let tuning = PingPongTuning.values(for: .medium)
        let ball = CGPoint(x: 0.5, y: 0.82)
        XCTAssertNotNil(PingPongContactEvaluator.tapContact(
            at: CGPoint(x: 0.51, y: 0.82),
            ballPosition: ball,
            secondsFromIdealContact: 0.02,
            tuning: tuning
        ))
        XCTAssertNil(PingPongContactEvaluator.tapContact(
            at: CGPoint(x: 0.8, y: 0.82),
            ballPosition: ball,
            secondsFromIdealContact: 0,
            tuning: tuning
        ))
        XCTAssertNil(PingPongContactEvaluator.tapContact(
            at: CGPoint(x: 0.5, y: 0.6),
            ballPosition: ball,
            secondsFromIdealContact: 0,
            tuning: tuning
        ))
        XCTAssertNil(PingPongContactEvaluator.tapContact(
            at: ball,
            ballPosition: ball,
            secondsFromIdealContact: tuning.tapTimingWindow + 0.01,
            tuning: tuning
        ))
    }

    func testTapOffsetAndSwipeVelocityFeedSharedShotSolver() throws {
        let tuning = PingPongTuning.values(for: .easy)
        let ball = CGPoint(x: 0.5, y: 0.82)
        let left = try XCTUnwrap(PingPongContactEvaluator.tapContact(
            at: CGPoint(x: 0.45, y: 0.82),
            ballPosition: ball,
            secondsFromIdealContact: 0,
            tuning: tuning
        ))
        let right = try XCTUnwrap(PingPongContactEvaluator.tapContact(
            at: CGPoint(x: 0.55, y: 0.82),
            ballPosition: ball,
            secondsFromIdealContact: 0,
            tuning: tuning
        ))
        let leftShot = PingPongShotSolver.solve(
            contact: left,
            striker: .child,
            tuning: tuning,
            rallyLength: 0
        )
        let rightShot = PingPongShotSolver.solve(
            contact: right,
            striker: .child,
            tuning: tuning,
            rallyLength: 0
        )
        XCTAssertLessThan(leftShot.planarVelocity.dx, rightShot.planarVelocity.dx)

        let slow = try XCTUnwrap(PingPongContactEvaluator.swipeContact(
            paddlePosition: ball,
            ballPosition: ball,
            paddleVelocity: CGVector(dx: 0, dy: -0.3),
            tuning: tuning
        ))
        let fast = try XCTUnwrap(PingPongContactEvaluator.swipeContact(
            paddlePosition: ball,
            ballPosition: ball,
            paddleVelocity: CGVector(dx: 0.5, dy: -20),
            tuning: tuning
        ))
        let slowShot = PingPongShotSolver.solve(
            contact: slow,
            striker: .child,
            tuning: tuning,
            rallyLength: 0
        )
        let fastShot = PingPongShotSolver.solve(
            contact: fast,
            striker: .child,
            tuning: tuning,
            rallyLength: 0
        )
        XCTAssertGreaterThan(hypot(fastShot.planarVelocity.dx, fastShot.planarVelocity.dy),
                             hypot(slowShot.planarVelocity.dx, slowShot.planarVelocity.dy))
        XCTAssertLessThanOrEqual(hypot(fast.paddleVelocity.dx, fast.paddleVelocity.dy),
                                 tuning.maximumSwipeSpeed + 0.0001)
    }

    func testSwipeOutsideStrikeZoneDisablesContactAndStarterOverlapIsAssisted() {
        let tuning = PingPongTuning.values(for: .starter)
        XCTAssertNil(PingPongContactEvaluator.swipeContact(
            paddlePosition: CGPoint(x: 0.5, y: 0.6),
            ballPosition: CGPoint(x: 0.5, y: 0.6),
            paddleVelocity: CGVector(dx: 0, dy: -0.4),
            tuning: tuning
        ))
        let assisted = PingPongContactEvaluator.starterAssistedContact(
            paddlePosition: CGPoint(x: 0.5, y: 0.82),
            ballPosition: CGPoint(x: 0.51, y: 0.82),
            tuning: tuning
        )
        XCTAssertNotNil(assisted)
        XCTAssertGreaterThanOrEqual(assisted?.normalizedSpatialQuality ?? 0, 0.86)

        var model = PingPongRallyModel()
        model.startReturn(contact: assisted!, striker: .child, tuning: tuning)
        var sawLegalMinikBounce = false
        for _ in 0..<300 where !sawLegalMinikBounce {
            sawLegalMinikBounce = model.advance(by: 1.0 / 120.0, tuning: tuning)
                .contains(.legalReceiverBounce(.minik))
        }
        XCTAssertTrue(sawLegalMinikBounce)
    }

    func testTapAndSwipeServePlansUseOwnThenOpponentSide() throws {
        let tuning = PingPongTuning.values(for: .medium)
        let tap = PingPongServePlanner.tapPlan(
            at: CGPoint(x: 0.3, y: 0.25),
            server: .child,
            tuning: tuning
        )
        XCTAssertTrue(PingPongTableGeometry.isOnSide(tap.firstBounce, of: .child))
        XCTAssertTrue(PingPongTableGeometry.isOnSide(tap.secondBounce, of: .minik))

        let contact = PingPongContact(
            contactPoint: CGPoint(x: 0.5, y: 0.87),
            normalizedTimingQuality: 1,
            normalizedSpatialQuality: 1,
            paddleVelocity: CGVector(dx: 0.2, dy: -0.8),
            intendedHorizontalDirection: 0.2,
            mode: .swipe
        )
        let swipe = try XCTUnwrap(PingPongServePlanner.swipePlan(
            contact: contact,
            server: .child,
            tuning: tuning
        ))
        XCTAssertTrue(PingPongTableGeometry.isOnSide(swipe.firstBounce, of: .child))
        XCTAssertTrue(PingPongTableGeometry.isOnSide(swipe.secondBounce, of: .minik))
        XCTAssertNil(PingPongServePlanner.swipePlan(
            contact: PingPongContact(
                contactPoint: contact.contactPoint,
                normalizedTimingQuality: 1,
                normalizedSpatialQuality: 1,
                paddleVelocity: CGVector(dx: 0, dy: 0.01),
                intendedHorizontalDirection: 0,
                mode: .swipe
            ),
            server: .child,
            tuning: tuning
        ))
    }

    func testTapServeCenterAndHorizontalAimMapToThePrimaryBounce() {
        let tuning = PingPongTuning.values(for: .medium)
        let ownCenter = PingPongServePlanner.tapPlan(
            at: CGPoint(x: 0.5, y: 0.78),
            server: .child,
            tuning: tuning
        )
        let receiverCenter = PingPongServePlanner.tapPlan(
            at: CGPoint(x: 0.5, y: 0.22),
            server: .child,
            tuning: tuning
        )

        XCTAssertEqual(ownCenter.firstBounce.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(ownCenter.firstBounce.y, 0.78, accuracy: 0.0001)
        XCTAssertEqual(ownCenter.secondBounce.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(receiverCenter.secondBounce.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(receiverCenter.secondBounce.y, 0.22, accuracy: 0.0001)

        for y in [CGFloat(0.78), CGFloat(0.22)] {
            let left = PingPongServePlanner.tapPlan(
                at: CGPoint(x: 0.25, y: y),
                server: .child,
                tuning: tuning
            )
            let right = PingPongServePlanner.tapPlan(
                at: CGPoint(x: 0.75, y: y),
                server: .child,
                tuning: tuning
            )
            let leftPrimary = y > PingPongTableGeometry.netY
                ? left.firstBounce
                : left.secondBounce
            let rightPrimary = y > PingPongTableGeometry.netY
                ? right.firstBounce
                : right.secondBounce

            XCTAssertLessThan(leftPrimary.x, 0.5)
            XCTAssertGreaterThan(rightPrimary.x, 0.5)
            XCTAssertEqual(leftPrimary.y, y, accuracy: 0.0001)
            XCTAssertEqual(rightPrimary.y, y, accuracy: 0.0001)
            if y > PingPongTableGeometry.netY {
                XCTAssertEqual(left.firstBounce.x, left.secondBounce.x, accuracy: 0.0001)
                XCTAssertEqual(right.firstBounce.x, right.secondBounce.x, accuracy: 0.0001)
            } else {
                XCTAssertLessThan(left.firstBounce.x, 0.5)
                XCTAssertGreaterThan(right.firstBounce.x, 0.5)
                XCTAssertGreaterThan(left.firstBounce.x, left.secondBounce.x)
                XCTAssertLessThan(right.firstBounce.x, right.secondBounce.x)
            }
        }
    }

    func testTapServeDerivesTheOtherBounceOnTheRequiredSide() {
        let tuning = PingPongTuning.values(for: .medium)
        let ownSideTap = PingPongServePlanner.tapPlan(
            at: CGPoint(x: 0.3, y: 0.8),
            server: .child,
            tuning: tuning
        )
        let receiverSideTap = PingPongServePlanner.tapPlan(
            at: CGPoint(x: 0.7, y: 0.2),
            server: .child,
            tuning: tuning
        )

        XCTAssertTrue(PingPongTableGeometry.isOnSide(ownSideTap.firstBounce, of: .child))
        XCTAssertTrue(PingPongTableGeometry.isOnSide(ownSideTap.secondBounce, of: .minik))
        XCTAssertTrue(PingPongTableGeometry.isOnSide(receiverSideTap.firstBounce, of: .child))
        XCTAssertTrue(PingPongTableGeometry.isOnSide(receiverSideTap.secondBounce, of: .minik))
        XCTAssertEqual(ownSideTap.firstBounce.y, 0.8, accuracy: 0.0001)
        XCTAssertEqual(receiverSideTap.secondBounce.y, 0.2, accuracy: 0.0001)
    }

    func testFasterSwipeProducesFasterActualServeFlight() throws {
        let tuning = PingPongTuning.values(for: .medium)
        func plan(speed: CGFloat) throws -> PingPongServePlan {
            try XCTUnwrap(PingPongServePlanner.swipePlan(
                contact: PingPongContact(
                    contactPoint: CGPoint(x: 0.5, y: 0.87),
                    normalizedTimingQuality: 1,
                    normalizedSpatialQuality: 1,
                    paddleVelocity: CGVector(dx: 0, dy: -speed),
                    intendedHorizontalDirection: 0,
                    mode: .swipe
                ),
                server: .child,
                tuning: tuning
            ))
        }
        let slowPlan = try plan(speed: 0.4)
        let fastPlan = try plan(speed: 1.8)
        XCTAssertGreaterThan(fastPlan.speed, slowPlan.speed)

        func receivingSpeed(for plan: PingPongServePlan) -> CGFloat {
            var flight = PingPongBallFlight(serve: plan, tuning: tuning)
            for _ in 0..<300 {
                if flight.advance(by: 1.0 / 120.0, tuning: tuning).contains(.serveOwnBounce) {
                    return hypot(flight.planarVelocity.dx, flight.planarVelocity.dy)
                }
            }
            return 0
        }
        XCTAssertGreaterThan(receivingSpeed(for: fastPlan), receivingSpeed(for: slowPlan))
    }
    func testEasyAssistsEdgeTapServeWhileHardCanPreserveAnOutAim() {
        let point = CGPoint(x: PingPongTableGeometry.tableXRange.lowerBound, y: 0.25)
        let easy = PingPongServePlanner.tapPlan(
            at: point,
            server: .child,
            tuning: .values(for: .easy)
        )
        let hard = PingPongServePlanner.tapPlan(
            at: point,
            server: .child,
            tuning: .values(for: .hard)
        )

        XCTAssertTrue(PingPongTableGeometry.isInsideTable(easy.secondBounce))
        XCTAssertFalse(PingPongTableGeometry.isInsideTable(hard.secondBounce))
    }

    func testServeFlightBouncesOnServerThenReceiverSide() {
        let tuning = PingPongTuning.values(for: .easy)
        let plan = PingPongServePlanner.tapPlan(
            at: CGPoint(x: 0.5, y: 0.25),
            server: .child,
            tuning: tuning
        )
        var model = PingPongRallyModel()
        model.startServe(plan, tuning: tuning)
        var events: [PingPongFlightEvent] = []

        for _ in 0..<240 where !events.contains(.legalReceiverBounce(.minik)) {
            events.append(contentsOf: model.advance(by: 1.0 / 120.0, tuning: tuning))
        }

        XCTAssertTrue(events.contains(.serveOwnBounce))
        XCTAssertTrue(events.contains(.legalReceiverBounce(.minik)))
        XCTAssertFalse(events.contains { event in
            if case .resolved = event { return true }
            return false
        })
    }

    func testBallFlightHasNoSideWallRecoveryAndNetAwardsReceiver() {
        let tuning = PingPongTuning.values(for: .medium)
        var sideOut = PingPongBallFlight(
            position: CGPoint(x: 0.99, y: 0.7),
            height: 0.2,
            planarVelocity: CGVector(dx: 0.8, dy: -0.2),
            verticalVelocity: 0.2,
            striker: .child
        )
        let sideEvents = sideOut.advance(by: 1.0 / 30.0, tuning: tuning)
        XCTAssertEqual(
            sideEvents,
            [.resolved(PingPongRallyResolution(pointWinner: .minik, fault: .leftTable))]
        )

        var net = PingPongBallFlight(
            position: CGPoint(x: 0.5, y: 0.51),
            height: 0.01,
            planarVelocity: CGVector(dx: 0, dy: -0.8),
            verticalVelocity: 0.01,
            striker: .child
        )
        let netEvents = net.advance(by: 1.0 / 30.0, tuning: tuning)
        XCTAssertEqual(
            netEvents,
            [.resolved(PingPongRallyResolution(pointWinner: .minik, fault: .net))]
        )
    }

    func testLegalShotOpensReturnOnlyAfterOpponentBounceThenSecondBounceScores() {
        let tuning = PingPongTuning.values(for: .easy)
        var model = PingPongRallyModel()
        model.startReturn(
            contact: PingPongContact(
                contactPoint: CGPoint(x: 0.5, y: 0.82),
                normalizedTimingQuality: 1,
                normalizedSpatialQuality: 1,
                paddleVelocity: .zero,
                intendedHorizontalDirection: 0,
                mode: .tap
            ),
            striker: .child,
            tuning: tuning
        )

        var sawBounce = false
        var resolution: PingPongRallyResolution?
        for _ in 0..<240 {
            for event in model.advance(by: 1.0 / 120.0, tuning: tuning) {
                if event == .legalReceiverBounce(.minik) { sawBounce = true }
                if case .resolved(let value) = event { resolution = value }
            }
            if resolution != nil { break }
        }
        XCTAssertTrue(sawBounce)
        XCTAssertEqual(resolution?.pointWinner, .child)
        XCTAssertEqual(resolution?.fault, .secondBounce)
    }

    func testFirstBounceOutAndIllegalServeAwardTheReceiver() {
        let tuning = PingPongTuning.values(for: .hard)
        var shot = PingPongBallFlight(
            position: CGPoint(x: 0.9, y: 0.56),
            height: 0.01,
            planarVelocity: CGVector(dx: 0, dy: -0.4),
            verticalVelocity: -0.3,
            striker: .child
        )
        XCTAssertEqual(
            shot.advance(by: 1.0 / 30.0, tuning: tuning),
            [.resolved(PingPongRallyResolution(pointWinner: .minik, fault: .firstBounceOut))]
        )

        let illegalPlan = PingPongServePlan(
            server: .child,
            start: CGPoint(x: 0.5, y: 0.87),
            firstBounce: CGPoint(x: 0.5, y: 0.28),
            secondBounce: CGPoint(x: 0.5, y: 0.72),
            speed: 0.5,
            verticalVelocity: 1.2
        )
        var serve = PingPongRallyModel()
        serve.startServe(illegalPlan, tuning: tuning)
        var resolution: PingPongRallyResolution?
        for _ in 0..<240 {
            for event in serve.advance(by: 1.0 / 120.0, tuning: tuning) {
                if case .resolved(let value) = event { resolution = value }
            }
            if resolution != nil { break }
        }
        XCTAssertEqual(resolution?.pointWinner, .minik)
        XCTAssertEqual(resolution?.fault, .illegalServe)
    }

    func testIncomingSpeedContributesToSharedReturnSpeed() {
        let tuning = PingPongTuning.values(for: .medium)
        let contact = PingPongContact(
            contactPoint: CGPoint(x: 0.5, y: 0.82),
            normalizedTimingQuality: 1,
            normalizedSpatialQuality: 1,
            paddleVelocity: CGVector(dx: 0, dy: -0.4),
            intendedHorizontalDirection: 0,
            mode: .swipe
        )
        let slowIncoming = PingPongShotSolver.solve(
            contact: contact,
            striker: .child,
            tuning: tuning,
            rallyLength: 0,
            incomingVelocity: CGVector(dx: 0, dy: 0.2)
        )
        let fastIncoming = PingPongShotSolver.solve(
            contact: contact,
            striker: .child,
            tuning: tuning,
            rallyLength: 0,
            incomingVelocity: CGVector(dx: 0, dy: 0.9)
        )
        XCTAssertGreaterThan(
            hypot(fastIncoming.planarVelocity.dx, fastIncoming.planarVelocity.dy),
            hypot(slowIncoming.planarVelocity.dx, slowIncoming.planarVelocity.dy)
        )
    }

    func testMinikDecisionDependsOnIncomingShotAndHardStillHasError() {
        let central = PingPongIncomingShot(predictedLandingX: 0.5, speed: 0.45, depth: 0.2)
        let hardAngle = PingPongIncomingShot(predictedLandingX: 0.92, speed: 1.1, depth: 0.06)

        XCTAssertEqual(PingPongMinikAI.decision(
            for: central,
            difficulty: .hard,
            randomUnit: 0.8
        ).kind, .soundContact)
        XCTAssertEqual(PingPongMinikAI.decision(
            for: hardAngle,
            difficulty: .easy,
            randomUnit: 0.8
        ).kind, .unreachable)
        XCTAssertEqual(PingPongMinikAI.decision(
            for: central,
            difficulty: .hard,
            randomUnit: 0.01
        ).kind, .unreachable)
        XCTAssertEqual(PingPongMinikAI.decision(
            for: central,
            difficulty: .easy,
            randomUnit: 0.1
        ).kind, .unreachable)
    }

    func testSwipeServeAssistancePreservesDifficultyAppropriateAimErrors() throws {
        func plan(
            difficulty: PingPongDifficulty,
            x: CGFloat,
            dx: CGFloat,
            dy: CGFloat
        ) throws -> PingPongServePlan {
            try XCTUnwrap(PingPongServePlanner.swipePlan(
                contact: PingPongContact(
                    contactPoint: CGPoint(x: x, y: 0.87),
                    normalizedTimingQuality: 1,
                    normalizedSpatialQuality: 1,
                    paddleVelocity: CGVector(dx: dx, dy: dy),
                    intendedHorizontalDirection: dx,
                    mode: .swipe
                ),
                server: .child,
                tuning: .values(for: difficulty)
            ))
        }

        let easyEdge = try plan(difficulty: .easy, x: 0.98, dx: 2, dy: -1)
        XCTAssertTrue(PingPongTableGeometry.isInsideTable(easyEdge.firstBounce))
        XCTAssertTrue(PingPongTableGeometry.isInsideTable(easyEdge.secondBounce))

        let mediumEdge = try plan(difficulty: .medium, x: 0.98, dx: 2, dy: -1)
        XCTAssertTrue(PingPongTableGeometry.isInsideTable(mediumEdge.firstBounce))
        XCTAssertGreaterThan(mediumEdge.secondBounce.x, 1)

        let hardLong = try plan(
            difficulty: .hard,
            x: 0.5,
            dx: 0,
            dy: -PingPongTuning.values(for: .hard).maximumSwipeSpeed
        )
        XCTAssertLessThan(hardLong.secondBounce.y, 0)

        let centered = try plan(difficulty: .medium, x: 0.5, dx: 0, dy: -0.7)
        func serveEvents(
            _ plan: PingPongServePlan,
            difficulty: PingPongDifficulty
        ) -> [PingPongFlightEvent] {
            let tuning = PingPongTuning.values(for: difficulty)
            var model = PingPongRallyModel()
            model.startServe(plan, tuning: tuning)
            var events: [PingPongFlightEvent] = []
            for _ in 0..<300 {
                events.append(contentsOf: model.advance(by: 1.0 / 120.0, tuning: tuning))
                let isResolved = events.contains { event in
                    if case .resolved = event { return true }
                    return false
                }
                if events.contains(.legalReceiverBounce(.minik))
                    || isResolved {
                    break
                }
            }
            return events
        }

        let easyEvents = serveEvents(easyEdge, difficulty: .easy)
        XCTAssertTrue(easyEvents.contains(.legalReceiverBounce(.minik)))

        let centeredEvents = serveEvents(centered, difficulty: .medium)
        XCTAssertTrue(centeredEvents.contains(.serveOwnBounce))
        XCTAssertTrue(centeredEvents.contains(.legalReceiverBounce(.minik)))
        XCTAssertFalse(centeredEvents.contains {
            if case .resolved = $0 { return true }
            return false
        })

        let hardEvents = serveEvents(hardLong, difficulty: .hard)
        XCTAssertTrue(hardEvents.contains {
            guard case .resolved(let resolution) = $0 else { return false }
            return resolution.pointWinner == .minik
                && (resolution.fault == .leftTable || resolution.fault == .firstBounceOut)
        })
    }

    func testMinikDecisionSeparatesMissSoundAndImperfectContact() throws {
        let easyCenter = PingPongIncomingShot(
            predictedLandingX: 0.5,
            speed: 0.45,
            depth: 0.2
        )
        XCTAssertEqual(PingPongMinikAI.decision(
            for: easyCenter,
            difficulty: .easy,
            randomUnit: 0.05
        ).kind, .unreachable)
        let imperfect = PingPongMinikAI.decision(
            for: easyCenter,
            difficulty: .easy,
            randomUnit: 0.20
        )
        XCTAssertEqual(imperfect.kind, .imperfectContact)
        XCTAssertEqual(PingPongMinikAI.decision(
            for: easyCenter,
            difficulty: .easy,
            randomUnit: 0.80
        ).kind, .soundContact)

        let hardShot = PingPongIncomingShot(
            predictedLandingX: 0.9,
            speed: 1.05,
            depth: 0.06
        )
        XCTAssertEqual(PingPongMinikAI.decision(
            for: hardShot,
            difficulty: .hard,
            randomUnit: 0.25
        ).kind, .imperfectContact)

        let contact = try XCTUnwrap(imperfect.contact)
        let tuning = PingPongTuning.values(for: .easy)
        var model = PingPongRallyModel()
        model.startReturn(contact: contact, striker: .minik, tuning: tuning)
        var resolution: PingPongRallyResolution?
        for _ in 0..<300 {
            for event in model.advance(by: 1.0 / 120.0, tuning: tuning) {
                if case .resolved(let value) = event { resolution = value }
            }
            if resolution != nil { break }
        }
        XCTAssertEqual(resolution?.pointWinner, .child)
        XCTAssertNotNil(resolution)
    }
}
