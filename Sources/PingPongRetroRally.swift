import CoreGraphics
import Foundation

/// 80s Style ball kinematics: a flat Pong-style ball that travels between the
/// fixed paddle lines and rebounds off the top/bottom field walls. Contact is
/// only ever made on a paddle line, so the ball always meets the paddle face
/// before it reverses. Shot speed and direction come from the shared
/// `PingPongShotSolver`; everything else about the rally stays shared too.
struct PingPongRetroRally: Equatable {
    enum Event: Equatable {
        case crossedNet
        case reachedContactLine(PingPongParticipant)
        case resolved(PingPongRallyResolution)
    }

    /// Mirrors the shared solver's net threshold: a contact this poor would
    /// find the net in Modern, so in 80s Style it dies at the center line.
    static let netFaultQuality: CGFloat = 0.14

    private(set) var position: CGPoint
    private(set) var velocity: CGVector
    private(set) var striker: PingPongParticipant
    private(set) var rallyLength: Int
    private(set) var isResolved = false
    private var faultsAtNet: Bool

    init(
        position: CGPoint,
        velocity: CGVector,
        striker: PingPongParticipant,
        faultsAtNet: Bool = false
    ) {
        self.position = position
        self.velocity = velocity
        self.striker = striker
        self.rallyLength = 0
        self.faultsAtNet = faultsAtNet
    }

    var receiver: PingPongParticipant { striker.opponent }

    static func contactDepth(
        for participant: PingPongParticipant,
        geometry: PingPongRetroGeometry
    ) -> CGFloat {
        participant == .child ? geometry.childContactDepth : geometry.minikContactDepth
    }

    mutating func advance(
        by deltaTime: TimeInterval,
        geometry: PingPongRetroGeometry
    ) -> [Event] {
        guard !isResolved else { return [] }

        let dt = CGFloat(min(max(deltaTime, 0), 1.0 / 30.0))
        let previous = position
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        let lateral = geometry.ballLateralRange
        if position.x < lateral.lowerBound {
            position.x = lateral.lowerBound + (lateral.lowerBound - position.x)
            velocity.dx = abs(velocity.dx)
        } else if position.x > lateral.upperBound {
            position.x = lateral.upperBound - (position.x - lateral.upperBound)
            velocity.dx = -abs(velocity.dx)
        }
        position.x = position.x.clamped(to: lateral)

        var events: [Event] = []
        let netY = PingPongTableGeometry.netY
        if (previous.y < netY) != (position.y < netY) {
            if faultsAtNet {
                isResolved = true
                return [.resolved(PingPongRallyResolution(pointWinner: receiver, fault: .net))]
            }
            events.append(.crossedNet)
        }

        let line = Self.contactDepth(for: receiver, geometry: geometry)
        let reachedLine = receiver == .child
            ? previous.y < line && position.y >= line
            : previous.y > line && position.y <= line
        if reachedLine {
            events.append(.reachedContactLine(receiver))
        }

        if position.y < 0 || position.y > 1 {
            isResolved = true
            events.append(.resolved(PingPongRallyResolution(pointWinner: striker, fault: .leftTable)))
        }
        return events
    }

    /// The receiver returns the ball from its paddle face.
    mutating func returnBall(
        contact: PingPongContact,
        by newStriker: PingPongParticipant,
        tuning: PingPongTuning,
        geometry: PingPongRetroGeometry
    ) {
        let solution = PingPongShotSolver.solve(
            contact: contact,
            striker: newStriker,
            tuning: tuning,
            rallyLength: rallyLength,
            incomingVelocity: velocity
        )
        striker = newStriker
        position.y = Self.contactDepth(for: newStriker, geometry: geometry)
        velocity = solution.planarVelocity
        faultsAtNet = contact.combinedQuality < Self.netFaultQuality
        rallyLength += 1
        isResolved = false
    }

    /// Lateral position at which the ball will reach the receiver's contact
    /// line, including wall rebounds.
    func predictedArrivalLateral(geometry: PingPongRetroGeometry) -> CGFloat {
        let line = Self.contactDepth(for: receiver, geometry: geometry)
        guard velocity.dy != 0 else { return position.x }
        let time = (line - position.y) / velocity.dy
        guard time > 0 else { return position.x }
        return Self.reflect(position.x + velocity.dx * time, within: geometry.ballLateralRange)
    }

    private static func reflect(_ value: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }
        var offset = (value - range.lowerBound).truncatingRemainder(dividingBy: 2 * span)
        if offset < 0 {
            offset += 2 * span
        }
        return offset <= span
            ? range.lowerBound + offset
            : range.lowerBound + 2 * span - offset
    }
}

/// Runs an 80s Style rally inside `PingPongScene`. Serve rules, contact
/// acceptance (`PingPongContactEvaluator`), Minik's decisions
/// (`PingPongMinikAI`), tuning and point resolution are the shared ones;
/// only where the ball travels and where contact happens are 80s specific.
final class PingPongRetroGame {
    var onStatusChanged: ((String) -> Void)?
    var onPointResolved: ((PingPongRallyResolution) -> Void)?

    /// Ball position in normalized table units, nil while hidden.
    private(set) var ballPosition: CGPoint?
    private(set) var childLateral: CGFloat = 0.5
    private(set) var minikLateral: CGFloat = 0.5

    private var difficulty: PingPongDifficulty = .starter
    private var controlMode: PingPongControlMode?
    private var tuning = PingPongTuning.values(for: .starter)
    private var geometry = PingPongRetroGeometry()

    private var rally: PingPongRetroRally?
    private var isRallyActive = false
    private var awaitingChildServe = false
    private var minikServeCountdown: TimeInterval?
    private var minikDecision: PingPongMinikDecision?
    private var minikTargetLateral: CGFloat = 0.5

    private var clock: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    private var childReturnIsOpen = false
    private var childLineReachedAt: TimeInterval?
    private var childHasAttemptedTap = false
    private var pendingTap: (time: TimeInterval, lateral: CGFloat)?

    private var activeTouchID: ObjectIdentifier?
    private var lastTouchPoint: CGPoint?
    private var lastTouchTimestamp: TimeInterval?
    private var latestPaddleVelocity = CGVector.zero
    private var lastPaddleMoveClock: TimeInterval = 0

    func configure(difficulty: PingPongDifficulty, controlMode: PingPongControlMode?) {
        cancel()
        self.difficulty = difficulty
        self.controlMode = controlMode
        self.tuning = .values(for: difficulty)
        childLateral = 0.5
        minikLateral = 0.5
        minikTargetLateral = 0.5
    }

    func updateGeometry(_ geometry: PingPongRetroGeometry) {
        self.geometry = geometry
    }

    func startRally(server: PingPongParticipant) {
        resetRallyState()
        isRallyActive = true
        let actualServer: PingPongParticipant = difficulty == .starter ? .minik : server
        if actualServer == .minik {
            minikTargetLateral = 0.5
            ballPosition = CGPoint(x: minikLateral, y: geometry.minikContactDepth)
            minikServeCountdown = difficulty == .starter ? 0.52 : 0.68
            onStatusChanged?(difficulty == .starter
                ? String(localized: "Get your paddle ready")
                : String(localized: "Minik is serving"))
        } else {
            awaitingChildServe = true
            ballPosition = CGPoint(x: childLateral, y: geometry.childContactDepth)
            onStatusChanged?(controlMode == .tap
                ? String(localized: "Tap anywhere on the table to serve")
                : String(localized: "Swipe through the ball to serve"))
        }
    }

    func cancel() {
        resetRallyState()
        isRallyActive = false
        ballPosition = nil
        activeTouchID = nil
        lastTouchPoint = nil
        lastTouchTimestamp = nil
        latestPaddleVelocity = .zero
    }

    func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime.map { min(max(currentTime - $0, 0), 1.0 / 30.0) } ?? 1.0 / 60.0
        lastUpdateTime = currentTime
        clock += delta
        minikLateral += (minikTargetLateral - minikLateral) * CGFloat(min(1, 6 * delta))

        guard isRallyActive else { return }

        if let countdown = minikServeCountdown {
            let remaining = countdown - delta
            if remaining <= 0 {
                minikServeCountdown = nil
                beginMinikServe()
            } else {
                minikServeCountdown = remaining
            }
        }

        if awaitingChildServe {
            ballPosition = CGPoint(x: childLateral, y: geometry.childContactDepth)
            return
        }

        guard var current = rally else { return }
        let events = current.advance(by: delta, geometry: geometry)
        rally = current
        ballPosition = current.position

        eventLoop: for event in events {
            switch event {
            case .crossedNet:
                if current.receiver == .child {
                    onStatusChanged?(difficulty == .starter
                        ? String(localized: "Move your paddle to the ball")
                        : String(localized: "Return the ball"))
                }
            case .reachedContactLine(.child):
                childReturnIsOpen = true
                childLineReachedAt = clock
                if attemptChildReturn() { break eventLoop }
            case .reachedContactLine(.minik):
                if performMinikReturn() { break eventLoop }
            case .resolved(let resolution):
                resolve(resolution)
                break eventLoop
            }
        }

        // Starter/Swipe keep trying while the ball is still at the paddle.
        if childReturnIsOpen, controlMode != .tap, activeTouchID != nil {
            _ = attemptChildReturn()
        }
    }

    // MARK: Input (normalized table points; lateral follows the finger's height)

    func touchBegan(id: ObjectIdentifier, at point: CGPoint, timestamp: TimeInterval) {
        guard isRallyActive, activeTouchID == nil else { return }
        moveChildPaddle(to: point.x)

        if difficulty != .starter, controlMode == .tap {
            if awaitingChildServe {
                beginTapServe(at: point)
            } else {
                registerTap(lateral: childLateral)
            }
            return
        }

        activeTouchID = id
        lastTouchPoint = point
        lastTouchTimestamp = timestamp
        latestPaddleVelocity = .zero
        lastPaddleMoveClock = clock
    }

    func touchMoved(id: ObjectIdentifier, at point: CGPoint, timestamp: TimeInterval) {
        guard activeTouchID == id else { return }
        let oldPoint = lastTouchPoint ?? point
        let elapsed = max(timestamp - (lastTouchTimestamp ?? timestamp), 1.0 / 120.0)
        latestPaddleVelocity = CGVector(
            dx: (point.x - oldPoint.x) / elapsed,
            dy: (point.y - oldPoint.y) / elapsed
        )
        lastTouchPoint = point
        lastTouchTimestamp = timestamp
        lastPaddleMoveClock = clock
        moveChildPaddle(to: point.x)

        if awaitingChildServe, controlMode == .swipe {
            attemptSwipeServe()
        }
    }

    func touchEnded(id: ObjectIdentifier) {
        guard activeTouchID == id else { return }
        activeTouchID = nil
        lastTouchPoint = nil
        lastTouchTimestamp = nil
        latestPaddleVelocity = .zero
    }

    func performAccessibilityReturn(side: PingPongPaddleSide) {
        guard isRallyActive else { return }
        if awaitingChildServe {
            let x: CGFloat = side == .backhand ? 0.34 : 0.66
            beginTapServe(at: CGPoint(x: x, y: 0.32))
            return
        }
        guard let current = rally, current.receiver == .child else { return }
        let arrival = current.predictedArrivalLateral(geometry: geometry)
        moveChildPaddle(to: arrival + (side == .backhand ? -0.03 : 0.03))
        if difficulty == .starter {
            if childReturnIsOpen { _ = attemptChildReturn() }
        } else {
            registerTap(lateral: childLateral)
        }
    }

    // MARK: Serves (shared serve planner and serve rules)

    private func beginMinikServe() {
        guard isRallyActive else { return }
        if Double.random(in: 0...1) < tuning.minikServeFaultProbability {
            launch(
                from: .minik,
                lateral: minikLateral,
                toward: CGPoint(x: 0.5, y: 0.72),
                speed: tuning.ballBaseSpeed,
                faultsAtNet: true
            )
            onStatusChanged?(String(localized: "Minik served"))
            return
        }
        let spread = difficulty == .starter ? 0.08 : tuning.minikCornerPreference
        let targetX = (0.5 + CGFloat.random(in: -spread...spread))
            .clamped(to: PingPongTableGeometry.tableXRange)
        let plan = PingPongServePlanner.tapPlan(
            at: CGPoint(x: targetX, y: difficulty == .starter ? 0.80 : 0.75),
            server: .minik,
            tuning: tuning
        )
        launch(from: .minik, lateral: minikLateral, toward: plan.secondBounce, speed: plan.speed)
        onStatusChanged?(String(localized: "Minik served"))
    }

    private func beginTapServe(at point: CGPoint) {
        guard awaitingChildServe else { return }
        awaitingChildServe = false
        let plan = PingPongServePlanner.tapPlan(at: point, server: .child, tuning: tuning)
        launch(from: .child, lateral: childLateral, toward: plan.secondBounce, speed: plan.speed)
        onStatusChanged?(String(localized: "Serve in play"))
    }

    private func attemptSwipeServe() {
        let velocity = latestPaddleVelocity
        // Only a swipe toward Minik (screen-right) serves; vertical drags just
        // move the paddle.
        guard velocity.dy < -tuning.minimumSwipeSpeed,
              abs(velocity.dy) >= abs(velocity.dx) else { return }
        let contact = PingPongContact(
            contactPoint: CGPoint(x: childLateral, y: 0.87),
            normalizedTimingQuality: 1,
            normalizedSpatialQuality: 1,
            paddleVelocity: velocity,
            intendedHorizontalDirection: velocity.dx.clamped(to: -1...1),
            mode: .swipe
        )
        awaitingChildServe = false
        guard let plan = PingPongServePlanner.swipePlan(
            contact: contact,
            server: .child,
            tuning: tuning
        ) else {
            resolve(PingPongRallyResolution(pointWinner: .minik, fault: .illegalServe))
            return
        }
        launch(from: .child, lateral: childLateral, toward: plan.secondBounce, speed: plan.speed)
        onStatusChanged?(String(localized: "Serve in play"))
    }

    private func launch(
        from server: PingPongParticipant,
        lateral: CGFloat,
        toward target: CGPoint,
        speed: CGFloat,
        faultsAtNet: Bool = false
    ) {
        let startDepth = PingPongRetroRally.contactDepth(for: server, geometry: geometry)
        let start = CGPoint(x: lateral.clamped(to: geometry.ballLateralRange), y: startDepth)
        let forward = max(speed * 0.82, 0.34)
        let depthDistance = max(abs(target.y - startDepth), 0.05)
        let lateralSpeed = ((target.x - start.x) * forward / depthDistance).clamped(to: -0.52...0.52)
        rally = PingPongRetroRally(
            position: start,
            velocity: CGVector(dx: lateralSpeed, dy: server == .child ? -forward : forward),
            striker: server,
            faultsAtNet: faultsAtNet
        )
        ballPosition = start
        if server == .child {
            prepareMinikDecision()
        } else {
            resetChildReturnWindow()
        }
    }

    // MARK: Returns (shared contact evaluators, shot solver and Minik AI)

    private func registerTap(lateral: CGFloat) {
        guard let current = rally, current.receiver == .child, !childHasAttemptedTap else { return }
        pendingTap = (time: clock, lateral: lateral)
        if childReturnIsOpen {
            _ = attemptChildReturn()
        }
    }

    /// Contact is always evaluated on the child's paddle line.
    private func attemptChildReturn() -> Bool {
        guard childReturnIsOpen, var current = rally, current.receiver == .child,
              // Only while the ball still overlaps the paddle, never from behind it.
              current.position.y <= geometry.childPaddleDepth else { return false }
        let line = geometry.childContactDepth
        let ball = CGPoint(x: current.position.x, y: line)
        let candidate: PingPongContact?
        let status: String

        if difficulty == .starter {
            candidate = PingPongContactEvaluator.starterAssistedContact(
                paddlePosition: CGPoint(x: childLateral, y: line),
                ballPosition: ball,
                tuning: tuning
            )
            status = String(localized: "Nice return!")
        } else if controlMode == .tap {
            guard let tap = pendingTap, let reachedAt = childLineReachedAt else { return false }
            pendingTap = nil
            // A tap far outside the timing window only moved the paddle.
            guard abs(reachedAt - tap.time) <= tuning.tapTimingWindow else { return false }
            childHasAttemptedTap = true
            candidate = PingPongContactEvaluator.tapContact(
                at: CGPoint(x: tap.lateral, y: line),
                ballPosition: ball,
                secondsFromIdealContact: reachedAt - tap.time,
                tuning: tuning
            )
            if candidate == nil {
                onStatusChanged?(String(localized: "Swing missed"))
                return false
            }
            status = String(localized: "Good return")
        } else {
            let isMoving = clock - lastPaddleMoveClock <= 0.12
            candidate = PingPongContactEvaluator.swipeContact(
                paddlePosition: CGPoint(x: childLateral, y: line),
                ballPosition: ball,
                paddleVelocity: isMoving ? latestPaddleVelocity : .zero,
                tuning: tuning
            )
            status = String(localized: "Return in play")
        }

        guard let contact = candidate else { return false }
        current.returnBall(contact: contact, by: .child, tuning: tuning, geometry: geometry)
        rally = current
        ballPosition = current.position
        // The paddle meets the ball on its line.
        moveChildPaddle(to: current.position.x)
        resetChildReturnWindow()
        prepareMinikDecision()
        onStatusChanged?(status)
        return true
    }

    /// Minik decides as soon as the ball heads its way, so its paddle visibly
    /// reaches the ball, or visibly falls short, on the paddle line.
    private func prepareMinikDecision() {
        guard let current = rally, current.receiver == .minik else { return }
        let arrival = current.predictedArrivalLateral(geometry: geometry)
        let incoming = PingPongIncomingShot(
            predictedLandingX: arrival,
            speed: hypot(current.velocity.dx, current.velocity.dy),
            // Modern's AI reference depth, so 80s Style does not add challenge.
            depth: 0.2
        )
        let decision = PingPongMinikAI.decision(
            for: incoming,
            difficulty: difficulty,
            randomUnit: Double.random(in: 0...1)
        )
        minikDecision = decision
        if decision.kind == .unreachable {
            let shortfall = geometry.paddleHalfLength + geometry.ballLateralRadius + 0.03
            minikTargetLateral = arrival < 0.5 ? arrival + shortfall : arrival - shortfall
        } else {
            minikTargetLateral = arrival
        }
        minikTargetLateral = minikTargetLateral.clamped(to: geometry.paddleLateralRange)
    }

    private func performMinikReturn() -> Bool {
        guard var current = rally, current.receiver == .minik else { return false }
        let pendingDecision = minikDecision
        minikDecision = nil
        guard let decision = pendingDecision, decision.kind != .unreachable, let base = decision.contact else {
            onStatusChanged?(String(localized: "Minik missed"))
            return false
        }
        let contact = PingPongContact(
            contactPoint: current.position,
            normalizedTimingQuality: base.normalizedTimingQuality,
            normalizedSpatialQuality: base.normalizedSpatialQuality,
            paddleVelocity: base.paddleVelocity,
            intendedHorizontalDirection: base.intendedHorizontalDirection,
            mode: nil
        )
        current.returnBall(contact: contact, by: .minik, tuning: tuning, geometry: geometry)
        rally = current
        ballPosition = current.position
        minikTargetLateral = current.position.x.clamped(to: geometry.paddleLateralRange)
        minikLateral = minikTargetLateral
        resetChildReturnWindow()
        onStatusChanged?(
            decision.kind == .imperfectContact
                ? String(localized: "Minik made a difficult return")
                : String(localized: "Minik returned")
        )
        return true
    }

    private func resolve(_ resolution: PingPongRallyResolution) {
        guard isRallyActive else { return }
        isRallyActive = false
        awaitingChildServe = false
        ballPosition = nil
        resetChildReturnWindow()
        onStatusChanged?(String(
            format: String(localized: "%@ won the point"),
            resolution.pointWinner.displayName
        ))
        onPointResolved?(resolution)
    }

    private func moveChildPaddle(to lateral: CGFloat) {
        childLateral = lateral.clamped(to: geometry.paddleLateralRange)
    }

    private func resetChildReturnWindow() {
        childReturnIsOpen = false
        childLineReachedAt = nil
        childHasAttemptedTap = false
        pendingTap = nil
    }

    private func resetRallyState() {
        rally = nil
        awaitingChildServe = false
        minikServeCountdown = nil
        minikDecision = nil
        resetChildReturnWindow()
    }
}
