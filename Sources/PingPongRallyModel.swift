import CoreGraphics
import Foundation

struct PingPongContact: Equatable {
    let contactPoint: CGPoint
    let normalizedTimingQuality: CGFloat
    let normalizedSpatialQuality: CGFloat
    let paddleVelocity: CGVector
    let intendedHorizontalDirection: CGFloat
    let mode: PingPongControlMode?

    var combinedQuality: CGFloat {
        ((normalizedTimingQuality + normalizedSpatialQuality) / 2).clamped(to: 0...1)
    }
}

struct PingPongShotSolution: Equatable {
    let planarVelocity: CGVector
    let verticalVelocity: CGFloat
}

struct PingPongServePlan: Equatable {
    let server: PingPongParticipant
    let start: CGPoint
    let firstBounce: CGPoint
    let secondBounce: CGPoint
    let speed: CGFloat
    let verticalVelocity: CGFloat
}

enum PingPongRallyFault: Equatable, Sendable {
    case net
    case firstBounceOut
    case secondBounce
    case leftTable
    case illegalServe
}

struct PingPongRallyResolution: Equatable, Sendable {
    let pointWinner: PingPongParticipant
    let fault: PingPongRallyFault
}

enum PingPongFlightEvent: Equatable {
    case serveOwnBounce
    case legalReceiverBounce(PingPongParticipant)
    case resolved(PingPongRallyResolution)
}

enum PingPongShotSolver {
    static func solve(
        contact: PingPongContact,
        striker: PingPongParticipant,
        tuning: PingPongTuning,
        rallyLength: Int,
        incomingVelocity: CGVector = .zero
    ) -> PingPongShotSolution {
        let quality = contact.combinedQuality
        let paddleSpeed = hypot(contact.paddleVelocity.dx, contact.paddleVelocity.dy)
        let velocityContribution = min(
            paddleSpeed * tuning.swipeVelocityScale,
            tuning.maximumSwipeSpeed
        )
        let incomingSpeed = hypot(incomingVelocity.dx, incomingVelocity.dy)
        let growth = min(
            CGFloat(rallyLength) * tuning.rallySpeedGrowth,
            tuning.maximumBallSpeed - tuning.ballBaseSpeed
        )
        let speed = min(
            tuning.ballBaseSpeed
                + growth
                + velocityContribution * 0.28
                + incomingSpeed * tuning.incomingVelocityInfluence,
            tuning.maximumBallSpeed
        )
        let verticalDirection: CGFloat = striker == .child ? -1 : 1
        let horizontal = (
            contact.intendedHorizontalDirection * 0.34
                + contact.paddleVelocity.dx * tuning.swipeVelocityScale * 0.16
                + incomingVelocity.dx * tuning.incomingVelocityInfluence * 0.12
        ).clamped(to: -0.52...0.52)
        let forward = max(speed * 0.82, 0.34) * verticalDirection

        // Poor contact can realistically find the net; sound contact receives a
        // safe but not excessive arc. Both Tap and Swipe feed this same solver.
        let verticalVelocity = quality < 0.14
            ? tuning.netHeight * 1.6
            : (tuning.netClearanceVelocityTarget + quality * 0.48)
                .clamped(to: tuning.netClearanceVelocityTarget...tuning.maximumArcVelocity)

        return PingPongShotSolution(
            planarVelocity: CGVector(dx: horizontal, dy: forward),
            verticalVelocity: verticalVelocity
        )
    }
}

enum PingPongServePlanner {
    static func tapPlan(
        at point: CGPoint,
        server: PingPongParticipant,
        tuning: PingPongTuning
    ) -> PingPongServePlan {
        let rawX = point.x.clamped(to: 0...1)
        let startY: CGFloat = server == .child ? 0.87 : 0.13
        let pointIsOnServerSide = PingPongTableGeometry.isOnSide(point, of: server)
        let edgeScale = tuning.serveAssistance >= 0.6
            ? 1 - tuning.serveAssistance * 0.35
            : 1 + (0.6 - tuning.serveAssistance) * 0.55
        let assistedX = 0.5 + (rawX - 0.5) * edgeScale
        // Keep the tap-selected lane visible through the serve. A receiver-side
        // tap still derives the earlier own-side bounce from center, while an
        // own-side tap carries that lane through to the receiver bounce.
        let derivedX = 0.5 + (assistedX - 0.5) * 0.5

        let firstBounce: CGPoint
        let secondBounce: CGPoint
        if server == .child {
            firstBounce = CGPoint(
                x: pointIsOnServerSide ? assistedX : derivedX,
                y: pointIsOnServerSide ? point.y.clamped(to: 0.61...0.83) : 0.72
            )
            secondBounce = CGPoint(
                x: assistedX,
                y: pointIsOnServerSide ? 0.28 : point.y.clamped(to: 0.17...0.39)
            )
        } else {
            firstBounce = CGPoint(
                x: pointIsOnServerSide ? assistedX : derivedX,
                y: pointIsOnServerSide ? point.y.clamped(to: 0.17...0.39) : 0.28
            )
            secondBounce = CGPoint(
                x: assistedX,
                y: pointIsOnServerSide ? 0.72 : point.y.clamped(to: 0.61...0.83)
            )
        }

        return PingPongServePlan(
            server: server,
            start: CGPoint(x: 0.5, y: startY),
            firstBounce: firstBounce,
            secondBounce: secondBounce,
            speed: tuning.ballBaseSpeed,
            verticalVelocity: 1.05 + tuning.serveAssistance * 0.22
        )
    }

    static func swipePlan(
        contact: PingPongContact,
        server: PingPongParticipant,
        tuning: PingPongTuning
    ) -> PingPongServePlan? {
        let speed = hypot(contact.paddleVelocity.dx, contact.paddleVelocity.dy)
        let correctDirection = server == .child
            ? contact.paddleVelocity.dy < -tuning.minimumSwipeSpeed
            : contact.paddleVelocity.dy > tuning.minimumSwipeSpeed
        guard speed >= tuning.minimumSwipeSpeed, correctDirection else {
            return nil
        }

        // Clamp only touch-noise extremes, then blend raw aim toward a safe
        // serve according to difficulty. Medium/Hard deliberately retain
        // enough error for the flight model to resolve wide/long/net faults.
        let rawDirection = (contact.paddleVelocity.dx * 0.28).clamped(to: -0.55...0.55)
        let safeXRange: ClosedRange<CGFloat> = 0.16...0.84
        let assistance = tuning.serveAssistance.clamped(to: 0...1)
        func assisted(_ raw: CGFloat, safe: CGFloat) -> CGFloat {
            raw * (1 - assistance) + safe * assistance
        }

        let rawFirstX = contact.contactPoint.x + rawDirection * 0.35
        let rawSecondX = contact.contactPoint.x + rawDirection
        let firstX = assisted(rawFirstX, safe: rawFirstX.clamped(to: safeXRange))
        let secondX = assisted(rawSecondX, safe: rawSecondX.clamped(to: safeXRange))

        let forwardSpeed = abs(contact.paddleVelocity.dy).clamped(
            to: tuning.minimumSwipeSpeed...tuning.maximumSwipeSpeed
        )
        let speedRange = max(tuning.maximumSwipeSpeed - tuning.minimumSwipeSpeed, 0.01)
        let normalizedPower = (forwardSpeed - tuning.minimumSwipeSpeed) / speedRange
        let rawChildSecondY = 0.55 - normalizedPower * 0.90
        let safeChildSecondY: CGFloat = 0.28
        let childSecondY = assisted(rawChildSecondY, safe: safeChildSecondY)
        let firstY: CGFloat = server == .child ? 0.72 : 0.28
        let secondY: CGFloat = server == .child ? childSecondY : 1 - childSecondY
        let startY: CGFloat = server == .child ? 0.87 : 0.13
        return PingPongServePlan(
            server: server,
            start: CGPoint(x: contact.contactPoint.x, y: startY),
            firstBounce: CGPoint(x: firstX, y: firstY),
            secondBounce: CGPoint(x: secondX, y: secondY),
            speed: min(
                tuning.ballBaseSpeed + speed * tuning.swipeVelocityScale * 0.35,
                tuning.maximumBallSpeed
            ),
            verticalVelocity: 1.15 + min(speed, 1) * 0.22
        )
    }
}

enum PingPongContactEvaluator {
    static func tapContact(
        at point: CGPoint,
        ballPosition: CGPoint,
        secondsFromIdealContact: TimeInterval,
        tuning: PingPongTuning
    ) -> PingPongContact? {
        guard PingPongTableGeometry.isInsideChildStrikeZone(point) else {
            return nil
        }
        let distance = hypot(point.x - ballPosition.x, point.y - ballPosition.y)
        guard distance <= tuning.tapSpatialTolerance,
              abs(secondsFromIdealContact) <= tuning.tapTimingWindow else {
            return nil
        }

        let spatialQuality = 1 - distance / tuning.tapSpatialTolerance
        let linearTimingQuality = 1 - CGFloat(abs(secondsFromIdealContact) / tuning.tapTimingWindow)
        let timingQuality = pow(linearTimingQuality, tuning.tapTimingQualityExponent)
        return PingPongContact(
            contactPoint: point,
            normalizedTimingQuality: timingQuality,
            normalizedSpatialQuality: spatialQuality,
            paddleVelocity: .zero,
            intendedHorizontalDirection: ((point.x - ballPosition.x) * 4).clamped(to: -1...1),
            mode: .tap
        )
    }

    static func swipeContact(
        paddlePosition: CGPoint,
        ballPosition: CGPoint,
        paddleVelocity: CGVector,
        tuning: PingPongTuning,
        mode: PingPongControlMode? = .swipe
    ) -> PingPongContact? {
        guard PingPongTableGeometry.isInsideChildStrikeZone(paddlePosition) else {
            return nil
        }
        let distance = hypot(
            paddlePosition.x - ballPosition.x,
            paddlePosition.y - ballPosition.y
        )
        guard distance <= tuning.swipeCollisionForgiveness else {
            return nil
        }

        let speed = hypot(paddleVelocity.dx, paddleVelocity.dy)
        let clampedSpeed = speed.clamped(
            to: tuning.minimumSwipeSpeed...tuning.maximumSwipeSpeed
        )
        let safeVelocity: CGVector
        if speed > 0 {
            let scale = clampedSpeed / speed
            safeVelocity = CGVector(
                dx: paddleVelocity.dx * scale,
                dy: paddleVelocity.dy * scale
            )
        } else {
            safeVelocity = CGVector(dx: 0, dy: -tuning.minimumSwipeSpeed)
        }

        return PingPongContact(
            contactPoint: paddlePosition,
            normalizedTimingQuality: 1,
            normalizedSpatialQuality: 1 - distance / tuning.swipeCollisionForgiveness,
            paddleVelocity: safeVelocity,
            intendedHorizontalDirection: safeVelocity.dx.clamped(to: -1...1),
            mode: mode
        )
    }

    static func starterAssistedContact(
        paddlePosition: CGPoint,
        ballPosition: CGPoint,
        tuning: PingPongTuning
    ) -> PingPongContact? {
        guard let contact = swipeContact(
            paddlePosition: paddlePosition,
            ballPosition: ballPosition,
            paddleVelocity: CGVector(dx: 0, dy: -0.32),
            tuning: tuning,
            mode: nil
        ) else {
            return nil
        }
        return PingPongContact(
            contactPoint: contact.contactPoint,
            normalizedTimingQuality: 1,
            normalizedSpatialQuality: max(contact.normalizedSpatialQuality, 0.86),
            paddleVelocity: CGVector(dx: 0, dy: -0.32),
            intendedHorizontalDirection: ((0.5 - ballPosition.x) * 0.55).clamped(to: -0.35...0.35),
            mode: nil
        )
    }
}

struct PingPongBallFlight: Equatable {
    private enum Stage: Equatable {
        case normal
        case serveToOwnBounce(PingPongServePlan)
    }

    private(set) var position: CGPoint
    private(set) var height: CGFloat
    private(set) var planarVelocity: CGVector
    private(set) var verticalVelocity: CGFloat
    private(set) var striker: PingPongParticipant
    private(set) var receiverMayReturn: Bool
    private(set) var isResolved: Bool

    private var receiverBounceCount: Int
    private var stage: Stage

    init(
        position: CGPoint,
        height: CGFloat,
        planarVelocity: CGVector,
        verticalVelocity: CGFloat,
        striker: PingPongParticipant
    ) {
        self.position = position
        self.height = height
        self.planarVelocity = planarVelocity
        self.verticalVelocity = verticalVelocity
        self.striker = striker
        self.receiverMayReturn = false
        self.isResolved = false
        self.receiverBounceCount = 0
        self.stage = .normal
    }

    init(serve plan: PingPongServePlan, tuning: PingPongTuning) {
        self.position = plan.start
        self.height = 0.055
        let openingSegment = Self.segment(
            from: plan.start,
            to: plan.firstBounce,
            requestedSpeed: plan.speed,
            minimumArcVelocity: plan.verticalVelocity,
            startHeight: 0.055,
            gravity: tuning.gravity
        )
        self.planarVelocity = openingSegment.planarVelocity
        self.verticalVelocity = openingSegment.verticalVelocity
        self.striker = plan.server
        self.receiverMayReturn = false
        self.isResolved = false
        self.receiverBounceCount = 0
        self.stage = .serveToOwnBounce(plan)
    }

    mutating func advance(
        by deltaTime: TimeInterval,
        tuning: PingPongTuning
    ) -> [PingPongFlightEvent] {
        guard !isResolved else {
            return []
        }

        let dt = CGFloat(min(max(deltaTime, 0), 1.0 / 30.0))
        let previous = position
        position.x += planarVelocity.dx * dt
        position.y += planarVelocity.dy * dt
        height += verticalVelocity * dt
        verticalVelocity -= tuning.gravity * dt

        if crossedNet(from: previous.y, to: position.y),
           height <= tuning.netHeight {
            return [resolve(winner: striker.opponent, fault: .net)]
        }

        if !PingPongTableGeometry.isInsideTable(position), height > 0 {
            let winner = receiverMayReturn ? striker : striker.opponent
            return [resolve(winner: winner, fault: .leftTable)]
        }

        guard height <= 0, verticalVelocity < 0 else {
            return []
        }
        height = 0

        switch stage {
        case .serveToOwnBounce(let plan):
            guard PingPongTableGeometry.isInsideTable(position),
                  PingPongTableGeometry.isOnSide(position, of: striker) else {
                return [resolve(winner: striker.opponent, fault: .illegalServe)]
            }
            position = plan.firstBounce
            let receivingSegment = Self.segment(
                from: plan.firstBounce,
                to: plan.secondBounce,
                requestedSpeed: plan.speed,
                minimumArcVelocity: plan.verticalVelocity,
                startHeight: 0,
                gravity: tuning.gravity
            )
            planarVelocity = receivingSegment.planarVelocity
            verticalVelocity = receivingSegment.verticalVelocity
            stage = .normal
            return [.serveOwnBounce]

        case .normal:
            let receiver = striker.opponent
            if receiverBounceCount == 0 {
                guard PingPongTableGeometry.isInsideTable(position),
                      PingPongTableGeometry.isOnSide(position, of: receiver) else {
                    return [resolve(winner: receiver, fault: .firstBounceOut)]
                }
                receiverBounceCount = 1
                receiverMayReturn = true
                verticalVelocity = abs(verticalVelocity) * tuning.bounceRestitution
                return [.legalReceiverBounce(receiver)]
            }

            return [resolve(winner: striker, fault: .secondBounce)]
        }
    }

    mutating func replaceWithReturn(
        contact: PingPongContact,
        by newStriker: PingPongParticipant,
        tuning: PingPongTuning,
        rallyLength: Int
    ) {
        let solution = PingPongShotSolver.solve(
            contact: contact,
            striker: newStriker,
            tuning: tuning,
            rallyLength: rallyLength,
            incomingVelocity: planarVelocity
        )
        striker = newStriker
        position = contact.contactPoint
        height = max(height, 0.055)
        planarVelocity = solution.planarVelocity
        verticalVelocity = solution.verticalVelocity
        receiverBounceCount = 0
        receiverMayReturn = false
        stage = .normal
        isResolved = false
    }

    private mutating func resolve(
        winner: PingPongParticipant,
        fault: PingPongRallyFault
    ) -> PingPongFlightEvent {
        isResolved = true
        return .resolved(PingPongRallyResolution(pointWinner: winner, fault: fault))
    }

    private func crossedNet(from oldY: CGFloat, to newY: CGFloat) -> Bool {
        (oldY < PingPongTableGeometry.netY && newY >= PingPongTableGeometry.netY)
            || (oldY > PingPongTableGeometry.netY && newY <= PingPongTableGeometry.netY)
    }

    private struct FlightSegment {
        let planarVelocity: CGVector
        let verticalVelocity: CGFloat
    }

    private static func segment(
        from start: CGPoint,
        to target: CGPoint,
        requestedSpeed: CGFloat,
        minimumArcVelocity: CGFloat,
        startHeight: CGFloat,
        gravity: CGFloat
    ) -> FlightSegment {
        let distance = hypot(target.x - start.x, target.y - start.y)
        let speedTime = distance / max(requestedSpeed, 0.05)
        let minimumArcTime = max((2 * minimumArcVelocity / gravity) * 0.55, 0.16)
        let flightTime = max(speedTime, minimumArcTime)
        let verticalVelocity = (
            0.5 * gravity * flightTime * flightTime - startHeight
        ) / flightTime
        return FlightSegment(
            planarVelocity: CGVector(
                dx: (target.x - start.x) / flightTime,
                dy: (target.y - start.y) / flightTime
            ),
            verticalVelocity: max(verticalVelocity, 0.05)
        )
    }
}

struct PingPongIncomingShot: Equatable, Sendable {
    let predictedLandingX: CGFloat
    let speed: CGFloat
    let depth: CGFloat
}

enum PingPongMinikDecisionKind: Equatable, Sendable {
    case unreachable
    case soundContact
    case imperfectContact
}

struct PingPongMinikDecision: Equatable {
    let kind: PingPongMinikDecisionKind
    let paddleSide: PingPongPaddleSide
    let contact: PingPongContact?
}

enum PingPongMinikAI {
    static func decision(
        for incoming: PingPongIncomingShot,
        difficulty: PingPongDifficulty,
        randomUnit: Double
    ) -> PingPongMinikDecision {
        let tuning = PingPongTuning.values(for: difficulty)
        let landingX = incoming.predictedLandingX
        let side = PingPongPaddleSide.side(forNormalizedX: landingX)
        let lateralDistance = abs(landingX - 0.5)
        let speedChallenge = max(0, incoming.speed - tuning.ballBaseSpeed)
        let depthChallenge = abs(incoming.depth - 0.2)
        let challenge = lateralDistance * 0.95 + speedChallenge * 0.48 + depthChallenge * 0.34
        let reachable = lateralDistance <= tuning.minikMaximumReach + tuning.minikPredictionAmount * 0.12
        let missThreshold = min(
            0.78,
            tuning.minikErrorProbability + Double(challenge * 0.24)
        )
        guard reachable, randomUnit >= missThreshold else {
            return PingPongMinikDecision(
                kind: .unreachable,
                paddleSide: side,
                contact: nil
            )
        }

        let poorContactThreshold = min(
            0.94,
            missThreshold
                + tuning.minikPoorContactProbability
                + Double(challenge * 0.28)
        )
        let kind: PingPongMinikDecisionKind = randomUnit < poorContactThreshold
            ? .imperfectContact
            : .soundContact

        let targetBias = landingX < 0.5 ? tuning.minikCornerPreference : -tuning.minikCornerPreference
        let trackingError = CGFloat(randomUnit * 2 - 1) * tuning.minikAimError
        let soundDirection = (targetBias + trackingError).clamped(to: -0.52...0.52)
        let poorProgress = CGFloat(
            (randomUnit - missThreshold)
                / max(poorContactThreshold - missThreshold, 0.001)
        ).clamped(to: 0...1)
        let poorDirection: CGFloat = landingX < 0.5 ? -0.52 : 0.52
        let intendedDirection = kind == .imperfectContact
            ? poorDirection
            : soundDirection
        let contactQuality: CGFloat = kind == .imperfectContact
            ? (poorProgress < 0.55 ? 0.08 : 0.30)
            : max(0.45, 1 - challenge)
        let returnSpeedScale: CGFloat = kind == .imperfectContact ? 0.62 : 1
        let contact = PingPongContact(
            contactPoint: CGPoint(x: landingX, y: 0.26),
            normalizedTimingQuality: contactQuality,
            normalizedSpatialQuality: kind == .imperfectContact
                ? contactQuality
                : max(0.45, 1 - challenge * 0.8),
            paddleVelocity: CGVector(
                dx: intendedDirection,
                dy: tuning.ballBaseSpeed
                    * tuning.minikReturnSpeedMultiplier
                    * returnSpeedScale
            ),
            intendedHorizontalDirection: intendedDirection,
            mode: nil
        )
        return PingPongMinikDecision(kind: kind, paddleSide: side, contact: contact)
    }
}

struct PingPongRallyModel: Equatable {
    private(set) var flight: PingPongBallFlight?
    private(set) var rallyLength = 0

    mutating func startServe(_ plan: PingPongServePlan, tuning: PingPongTuning) {
        flight = PingPongBallFlight(serve: plan, tuning: tuning)
        rallyLength = 0
    }

    mutating func startReturn(
        contact: PingPongContact,
        striker: PingPongParticipant,
        tuning: PingPongTuning
    ) {
        if flight == nil {
            let solution = PingPongShotSolver.solve(
                contact: contact,
                striker: striker,
                tuning: tuning,
                rallyLength: rallyLength
            )
            flight = PingPongBallFlight(
                position: contact.contactPoint,
                height: 0.055,
                planarVelocity: solution.planarVelocity,
                verticalVelocity: solution.verticalVelocity,
                striker: striker
            )
        } else {
            flight?.replaceWithReturn(
                contact: contact,
                by: striker,
                tuning: tuning,
                rallyLength: rallyLength
            )
        }
        rallyLength += 1
    }

    mutating func advance(
        by deltaTime: TimeInterval,
        tuning: PingPongTuning
    ) -> [PingPongFlightEvent] {
        guard flight != nil else {
            return []
        }
        return flight?.advance(by: deltaTime, tuning: tuning) ?? []
    }
}
